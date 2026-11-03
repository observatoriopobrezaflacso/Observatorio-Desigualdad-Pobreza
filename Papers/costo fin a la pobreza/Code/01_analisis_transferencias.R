# =============================================================================
# ¿Cuánto costaría eliminar la pobreza con un bono uniforme por hogar?
# ENEMDU anual 2025 (INEC) - Observatorio de Desigualdad y Pobreza (FLACSO)
#
# Diseño analizado: TODOS los hogares beneficiarios reciben EL MISMO monto.
# El monto de referencia es el mínimo que garantiza sacar de la pobreza a un
# hogar de 4 personas (dos adultos y dos niños): 4 x línea de pobreza.
#
# Unidad de análisis: el HOGAR. Produce resultados.json (insumo del tablero).
# Base: los doce meses de 2025 juntos. Sus factores de expansión están hechos para el
# año completo, así que ninguna cifra se calcula para un mes por separado.
# =============================================================================

suppressPackageStartupMessages({
  library(haven); library(dplyr); library(survey); library(jsonlite)
})

options(survey.lonely.psu = "adjust")

RUTA_SAV <- path.expand("~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Originales/Anuales/2025/BDDenemdu_personas_2025_anual.sav")
SALIDA   <- "resultados.json"

# Líneas oficiales INEC, diciembre 2025 (USD per cápita mensual). Todos los ingresos se
# expresan a precios de diciembre de 2025 (sección 1), así que una sola línea sirve para el año.
LP  <- 92.40
LPE <- 52.07

# Hogar de referencia para fijar el monto del bono: 4 personas
TAM_REF <- 4

# Efecto inflacionario del programa: el tablero permite al usuario elegirlo (0 a 40%).
INFL_MAX <- 0.40
INFL_DEFECTO <- 0.05

# Filtración: la probabilidad de que un hogar NO pobre reciba el bono cae con su
# ingreso per cápita. Se modela como una caída exponencial cuya vida media se expresa
# como fracción de la línea (0,85 = la probabilidad se reduce a la mitad cada vez que
# el ingreso supera la línea en un 85% adicional). El tablero calibra el nivel de la
# curva para que el total de personas no pobres alcanzadas cumpla el parámetro elegido.
# Valores por defecto tomados del BDH observado en esta misma ENEMDU (sección 6):
# 1,06 personas no pobres por persona pobre receptora (IC 95%: 0,94-1,18) y una vida
# media de 87% de la línea, redondeados a los pasos de los deslizadores del tablero.
FILTRACION_DEFECTO    <- 1.1
VIDA_MEDIA_FILTRACION <- 0.85

# ---------------------------------------------------------------- 1. Datos ---
d <- read_sav(RUTA_SAV, col_select = c(periodo, id_hogar, upm, estrato, fexp, ingpc,
                                       pobreza, epobreza, p03, p75, p76)) |>
  mutate(across(everything(), zap_labels))
stopifnot(setequal(unique(d$periodo), 202501:202512))

d <- d |>
  mutate(edad = as.numeric(p03), ingpc = as.numeric(ingpc), fexp = as.numeric(fexp),
         pobreza = as.numeric(pobreza), epobreza = as.numeric(epobreza),
         p75 = as.numeric(p75), p76 = as.numeric(p76)) |>
  filter(!is.na(ingpc), !is.na(fexp))

# Precios de diciembre de 2025. El INEC actualiza las líneas cada mes con el IPC; la línea
# del mes se recupera de la clasificación oficial: queda entre el mayor ingreso de los pobres
# y el menor de los no pobres de ese mes. Se intersecan los rangos de las dos líneas
# (la extrema llevada a la escala de la de pobreza) y se toma el extremo superior, que
# reproduce exactamente `pobreza` y `epobreza` y en diciembre da la línea oficial (92,40).
lineas_mes <- d |>
  group_by(periodo) |>
  summarise(desde = max(max(ingpc[pobreza == 1]),  max(ingpc[epobreza == 1]) * LP / LPE),
            hasta = min(min(ingpc[pobreza == 0]),  min(ingpc[epobreza == 0]) * LP / LPE),
            .groups = "drop") |>
  mutate(linea = hasta)
stopifnot(all(lineas_mes$desde < lineas_mes$hasta),
          abs(lineas_mes$linea[lineas_mes$periodo == 202512] - LP) < 1e-6)

d <- d |>
  left_join(select(lineas_mes, periodo, linea_mes = linea), by = "periodo") |>
  mutate(deflactor = LP / linea_mes,
         ingpc_nominal = ingpc,
         ingpc = round(ingpc_nominal * deflactor, 2))
stopifnot(all((d$ingpc < LP)  == (d$pobreza  == 1)),
          all((d$ingpc < LPE) == (d$epobreza == 1)))

# ------------------------------------------------ 2. Base de hogares --------
h <- d |>
  group_by(id_hogar) |>
  summarise(
    estrato = first(estrato), upm = first(upm), fexp = first(fexp),
    deflactor = first(deflactor),
    n         = n(),
    ingpc     = first(ingpc),
    n_menor5  = sum(edad < 5, na.rm = TRUE),
    n_may65   = sum(edad >= 65 & edad <= 98, na.rm = TRUE),
    n_menor18 = sum(edad < 18, na.rm = TRUE),
    n_adulto18= sum(edad >= 18 & edad <= 98, na.rm = TRUE),
    # Bono de Desarrollo Humano (p75/p76; incluye las pensiones no contributivas del MIES)
    bdh       = as.integer(any(p75 == 1, na.rm = TRUE)),
    monto_bdh = sum(ifelse(p75 %in% 1, p76, 0), na.rm = TRUE) * first(deflactor),
    .groups = "drop"
  ) |>
  mutate(
    ingreso_hogar = ingpc * n,
    pobre    = as.integer(ingpc < LP),
    pobre_e  = as.integer(ingpc < LPE),
    # brecha del hogar: lo que le falta al hogar completo para llegar a la línea
    brecha_lp  = pmax(0, LP  - ingpc) * n,
    brecha_lpe = pmax(0, LPE - ingpc) * n,
    hay_menor5 = as.integer(n_menor5 > 0),
    hay_may65  = as.integer(n_may65  > 0),
    personas   = n,
    # ingpc ya incluye el BDH: para medir la focalización se usa el ingreso sin el bono
    ingpc_sin_bdh = ingpc - monto_bdh / n
  )

# Diseños muestrales: hogares y personas
dh <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)
dp <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = d, nest = TRUE)
gl <- degf(dh)

ic <- function(obj) {
  est <- as.numeric(coef(obj)); se <- as.numeric(SE(obj)); t <- qt(0.975, gl)
  list(est = est, se = se, li = max(0, est - t * se), ls = est + t * se)
}

# Conteos y totales: proporción (o media por persona/hogar) × total nacional conocido.
# Los factores de expansión están calibrados a la población proyectada, así que la
# población y el número de hogares se tratan como conocidos: el error estándar del
# conteo es el de la proporción multiplicado por el total.
conteo <- function(num, den, design, total) {
  r <- svyratio(num, den, design)
  est <- as.numeric(coef(r)) * total; se <- as.numeric(SE(r)) * total; t <- qt(0.975, gl)
  list(est = est, se = se, li = max(0, est - t * se), ls = est + t * se)
}
conocido <- function(x) list(est = x, se = 0, li = x, ls = x)
POB <- sum(d$fexp)   # personas (= suma de fexp × miembros en la base de hogares)
HOG <- sum(h$fexp)   # hogares

# --------------------------------------------------- 3. Contexto nacional ---
d$uno <- 1
dp <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = d, nest = TRUE)
d$pobre    <- as.integer(d$ingpc < LP)
d$pobre_e  <- as.integer(d$ingpc < LPE)
d$fgt1_lp  <- pmax(0, LP - d$ingpc)/LP
d$fgt2_lp  <- (pmax(0, LP - d$ingpc)/LP)^2
d$fgt1_lpe <- pmax(0, LPE - d$ingpc)/LPE
d$fgt2_lpe <- (pmax(0, LPE - d$ingpc)/LPE)^2
dp <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = d, nest = TRUE)

pob_total  <- conocido(POB)
inc_pob    <- ic(svymean(~pobre, dp))
inc_pobe   <- ic(svymean(~pobre_e, dp))
n_pobres   <- conteo(~pobre,   ~uno, dp, POB)
n_pobres_e <- conteo(~pobre_e, ~uno, dp, POB)
ing_medio  <- ic(svymean(~ingpc, dp))
fgt1_lp    <- ic(svymean(~fgt1_lp, dp));  fgt2_lp  <- ic(svymean(~fgt2_lp, dp))
fgt1_lpe   <- ic(svymean(~fgt1_lpe, dp)); fgt2_lpe <- ic(svymean(~fgt2_lpe, dp))

gini_w <- function(x, w) {
  o <- order(x); x <- x[o]; w <- w[o]
  wm <- sum(w * x)/sum(w)
  sum(w * (2*(cumsum(w) - w/2)/sum(w) - 1) * x)/(sum(w)*wm)
}
gini <- gini_w(d$ingpc, d$fexp)

h$uno <- 1
dh <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)
hog_total   <- conocido(HOG)
hog_pobres  <- conteo(~pobre,   ~uno, dh, HOG)
hog_pobres_e<- conteo(~pobre_e, ~uno, dh, HOG)
tam_medio   <- ic(svymean(~personas, dh))

# Tamaño medio de los hogares NO pobres (para traducir filtración de personas a hogares)
tam_nopobre    <- sum(h$fexp*h$personas*(1-h$pobre))   / sum(h$fexp*(1-h$pobre))
tam_nopobre_e  <- sum(h$fexp*h$personas*(1-h$pobre_e)) / sum(h$fexp*(1-h$pobre_e))
personas_nopobres   <- sum(h$fexp*h$personas*(1-h$pobre))
personas_nopobres_e <- sum(h$fexp*h$personas*(1-h$pobre_e))
hogares_nopobres    <- sum(h$fexp*(1-h$pobre))
hogares_nopobres_e  <- sum(h$fexp*(1-h$pobre_e))

# ------------------------- 4. Hogar de referencia: 2 adultos + 2 niños ------
h$ref <- as.integer(h$n == 4 & h$n_adulto18 == 2 & h$n_menor18 == 2)
dh <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)

ref_hogares <- conteo(~ref, ~uno, dh, HOG)
h$ref_pobre <- h$ref * h$pobre
dh <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)
ref_pobres  <- conteo(~ref_pobre, ~uno, dh, HOG)

sub_ref <- h[h$ref == 1 & h$pobre == 1, ]
brecha_ref_media <- sum(sub_ref$fexp*sub_ref$brecha_lp)/sum(sub_ref$fexp)
brecha_ref_med   <- {
  o <- order(sub_ref$brecha_lp); x <- sub_ref$brecha_lp[o]; w <- sub_ref$fexp[o]
  x[which(cumsum(w)/sum(w) >= 0.5)[1]]
}
brecha_ref_max <- max(sub_ref$brecha_lp)

MONTO_REF_LP  <- TAM_REF * LP    # 369,60 : saca de la pobreza a CUALQUIER hogar de 4
MONTO_REF_LPE <- TAM_REF * LPE   # 208,28

# ------------------------------------- 5. Grupos objetivo x línea (hogares) --
grupos <- list(
  total   = list(nombre = "Todos los hogares",
                 detalle = "Sin condicionar por composición del hogar",
                 filtro = rep(TRUE, nrow(h))),
  menor5  = list(nombre = "Hogares con niñas/os menores de 5 años",
                 detalle = "Al menos una persona menor de 5 años en el hogar",
                 filtro = h$hay_menor5 == 1),
  mayor65 = list(nombre = "Hogares con personas de 65 años o más",
                 detalle = "Al menos una persona de 65 años o más en el hogar",
                 filtro = h$hay_may65 == 1)
)

lineas <- list(
  pobreza = list(nombre = "Pobreza", z = LP,  vp = "pobre",   vb = "brecha_lp",
                 monto_ref = MONTO_REF_LP,  tam_nopobre = tam_nopobre,
                 personas_nopobres = personas_nopobres, hogares_nopobres = hogares_nopobres),
  extrema = list(nombre = "Pobreza extrema", z = LPE, vp = "pobre_e", vb = "brecha_lpe",
                 monto_ref = MONTO_REF_LPE, tam_nopobre = tam_nopobre_e,
                 personas_nopobres = personas_nopobres_e, hogares_nopobres = hogares_nopobres_e)
)

resultados <- list()

for (gk in names(grupos)) for (lk in names(lineas)) {
  g <- grupos[[gk]]; L <- lineas[[lk]]

  h$.eng   <- as.integer(g$filtro)
  h$.pobre <- h[[L$vp]]
  h$.br    <- h[[L$vb]]

  h$.hog_g   <- h$.eng                       # hogares del grupo
  h$.hog_p   <- h$.eng * h$.pobre            # hogares pobres del grupo
  h$.per_g   <- h$.eng * h$personas          # personas del grupo
  h$.per_p   <- h$.eng * h$.pobre * h$personas
  h$.br_g    <- h$.eng * h$.pobre * h$.br    # brecha agregada del grupo
  h$.hog_np  <- h$.eng * (1 - h$.pobre)
  h$.per_np  <- h$.eng * (1 - h$.pobre) * h$personas

  ds <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)

  hogares_grupo   <- conteo(~.hog_g,  ~uno,      ds, HOG)
  hogares_pobres_g<- conteo(~.hog_p,  ~uno,      ds, HOG)
  personas_grupo  <- conteo(~.per_g,  ~personas, ds, POB)
  personas_pobres <- conteo(~.per_p,  ~personas, ds, POB)
  brecha_total    <- conteo(~.br_g,   ~personas, ds, POB)
  hogares_nopob_g <- conteo(~.hog_np, ~uno,      ds, HOG)
  personas_nopob_g<- conteo(~.per_np, ~personas, ds, POB)
  incidencia_hog  <- ic(svyratio(~.hog_p, ~.hog_g, ds))
  incidencia_per  <- ic(svyratio(~.per_p, ~.per_g, ds))

  resultados[[paste0(gk, "__", lk)]] <- list(
    grupo = gk, grupo_nombre = g$nombre, grupo_detalle = g$detalle,
    linea = lk, linea_nombre = L$nombre, z = L$z,
    monto_referencia = L$monto_ref,
    hogares_grupo = hogares_grupo, hogares_pobres = hogares_pobres_g,
    hogares_nopobres = hogares_nopob_g,
    personas_grupo = personas_grupo, personas_pobres = personas_pobres,
    personas_nopobres = personas_nopob_g,
    incidencia_hogares = incidencia_hog, incidencia_personas = incidencia_per,
    brecha_mensual = brecha_total,
    brecha_media_hogar = brecha_total$est / hogares_pobres_g$est,
    tamano_hogar_pobre = personas_pobres$est / hogares_pobres_g$est,
    tamano_hogar_nopobre_nacional = L$tam_nopobre
  )
}

# ----------------------------- 6. Filtración observada del BDH ---------------
# Referencia empírica para la filtración del tablero: entre los hogares que reciben el
# BDH, cuántas personas no pobres hay por cada persona pobre, y cómo cae la probabilidad
# de recibirlo con el ingreso per cápita (sin el bono) por encima de la línea.
# El BDH no cubre a todos los pobres (el bono simulado sí), así que lo comparable con el
# tablero es la forma del perfil, no su nivel.
TRAMOS <- c(1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3)
bdh_obs <- list()
for (lk in names(lineas)) {
  z <- lineas[[lk]]$z
  rel <- h$ingpc_sin_bdh / z
  # vida media: ajuste exponencial log p = a + b (y/z - 1) en los hogares no pobres hasta 3z
  s <- h[rel >= 1 & rel < 3, ]; s$x <- s$ingpc_sin_bdh / z - 1
  aj <- glm(bdh ~ x, family = quasipoisson(link = "log"), weights = fexp / mean(fexp), data = s)
  por_grupo <- list()
  for (gk in names(grupos)) {
    en <- grupos[[gk]]$filtro
    h$.rnp <- en * h$bdh * (rel >= 1) * h$personas
    h$.rp  <- en * h$bdh * (rel <  1) * h$personas
    h$.hp  <- en * (rel < 1)
    h$.hpr <- en * (rel < 1) * h$bdh
    ds <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = h, nest = TRUE)
    tr <- cut(rel, TRAMOS, right = FALSE)
    perfil <- lapply(levels(tr), function(t) {
      k <- en & !is.na(tr) & tr == t
      list(prob = sum(h$fexp[k] * h$bdh[k]) / sum(h$fexp[k]), n = sum(k))
    })
    por_grupo[[gk]] <- list(
      filtracion = ic(svyratio(~.rnp, ~.rp, ds)),
      cobertura_pobres = ic(svyratio(~.hpr, ~.hp, ds)),
      tramos = list(desde = head(TRAMOS, -1), hasta = TRAMOS[-1],
                    prob = sapply(perfil, `[[`, "prob"), n = sapply(perfil, `[[`, "n"))
    )
  }
  bdh_obs[[lk]] <- list(vida_media = as.numeric(-log(2) / coef(aj)[2]), grupos = por_grupo)
}
cat(sprintf("BDH: filtración %.2f [%.2f - %.2f] personas no pobres por pobre | vida media %.0f%% de la línea\n",
            bdh_obs$pobreza$grupos$total$filtracion$est, bdh_obs$pobreza$grupos$total$filtracion$li,
            bdh_obs$pobreza$grupos$total$filtracion$ls, 100 * bdh_obs$pobreza$vida_media))

# ------------------------------- 7. Microdatos de todos los hogares ---------
# El tablero los necesita completos: los hogares pobres definen quién sale de la
# pobreza con cada monto e inflación, y los NO pobres definen el perfil de la
# filtración (probabilidad decreciente con el ingreso) y quiénes caen bajo la
# línea encarecida. No contienen identificadores ni ubicación geográfica.
micro <- h |>
  transmute(y = round(ingpc, 2), n = personas, w = signif(fexp, 6),
            m5 = hay_menor5, m65 = hay_may65)
cat(sprintf("Microdatos exportados: %d hogares\n", nrow(micro)))

# ------------------------------------------------------- 8. Exportar JSON ---
out <- list(
  meta = list(
    fuente = "ENEMDU anual 2025 (INEC)",
    periodo = "enero a diciembre de 2025",
    precios = "Ingresos de cada mes a precios de diciembre de 2025",
    lineas_mensuales = list(periodo = lineas_mes$periodo, linea_pobreza = round(lineas_mes$linea, 4),
                            linea_extrema = round(lineas_mes$linea * LPE / LP, 4)),
    n_personas = nrow(d), n_hogares = nrow(h), gl_diseno = gl,
    linea_pobreza = LP, linea_pobreza_extrema = LPE,
    tam_referencia = TAM_REF,
    inflacion_defecto = INFL_DEFECTO,
    inflacion_max = INFL_MAX,
    filtracion_defecto = FILTRACION_DEFECTO,
    vida_media_filtracion = VIDA_MEDIA_FILTRACION,
    monto_referencia_pobreza = MONTO_REF_LP,
    monto_referencia_extrema = MONTO_REF_LPE,
    fecha_procesamiento = as.character(Sys.Date())
  ),
  nacional = list(
    poblacion = pob_total, hogares = hog_total, tamano_hogar_medio = tam_medio,
    incidencia_pobreza = inc_pob, incidencia_extrema = inc_pobe,
    pobres = n_pobres, pobres_extremos = n_pobres_e,
    hogares_pobres = hog_pobres, hogares_pobres_extremos = hog_pobres_e,
    ingreso_pc_medio = ing_medio,
    fgt1_pobreza = fgt1_lp, fgt2_pobreza = fgt2_lp,
    fgt1_extrema = fgt1_lpe, fgt2_extrema = fgt2_lpe,
    gini = gini,
    tamano_hogar_nopobre = tam_nopobre, tamano_hogar_nopobre_extrema = tam_nopobre_e
  ),
  hogar_referencia = list(
    descripcion = "Hogar de 4 personas: dos adultos (18 años o más) y dos niñas/os menores de 18",
    tamano = TAM_REF,
    monto_pobreza = MONTO_REF_LP,
    monto_extrema = MONTO_REF_LPE,
    hogares = ref_hogares, hogares_pobres = ref_pobres,
    brecha_media = brecha_ref_media, brecha_mediana = brecha_ref_med, brecha_maxima = brecha_ref_max
  ),
  macro = list(
    pib_2025 = 130320000000,
    pib_fuente = "BCE, resultados preliminares 2025",
    pge_2025 = 36063017083.08
  ),
  gasto_publico = list(
    list(nombre = "Presupuesto General del Estado 2025", monto = 36063017083.08,
         fuente = "MEF, PGE 2025, consolidado por sectorial", tipo = "total"),
    list(nombre = "Servicio de la deuda pública", monto = 9286514086.58,
         fuente = "MEF, PGE 2025 (entidad 0997 Deuda Pública)", tipo = "partida"),
    list(nombre = "Educación (todo el sector)", monto = 5585240616.82,
         fuente = "MEF, PGE 2025, sectorial Educación", tipo = "partida"),
    list(nombre = "Salud (todo el sector)", monto = 2884072024.01,
         fuente = "MEF, PGE 2025, sectorial Salud", tipo = "partida"),
    list(nombre = "Subsidio a combustibles", monto = 2504000000,
         fuente = "Proforma 2025, MEF (reportado en prensa)", tipo = "subsidio"),
    list(nombre = "Seguridad interna y policía", monto = 1963908916.21,
         fuente = "MEF, PGE 2025, sectorial Asuntos Internos", tipo = "partida"),
    list(nombre = "Bonos y subvenciones sociales", monto = 1955000000,
         fuente = "Proforma 2025, MEF (reportado en prensa)", tipo = "subsidio"),
    list(nombre = "MIES (presupuesto total)", monto = 1667999647.49,
         fuente = "MEF, PGE 2025, Ministerio de Inclusión Económica y Social", tipo = "partida"),
    list(nombre = "Defensa nacional", monto = 1624801000.29,
         fuente = "MEF, PGE 2025, sectorial Defensa", tipo = "partida"),
    list(nombre = "Subsidio al diésel", monto = 1194000000,
         fuente = "Proforma 2025, MEF (reportado en prensa)", tipo = "subsidio"),
    list(nombre = "Subsidio al gas doméstico (GLP)", monto = 870000000,
         fuente = "Proforma 2025, MEF (reportado en prensa)", tipo = "subsidio"),
    list(nombre = "Gasto tributario total (2025, proyectado)", monto = 7230000000,
         fuente = "SRI, informe de gasto tributario; proyección 2025 (5,6% del PIB)", tipo = "tributario"),
    list(nombre = "Gasto tributario en IVA (2023)", monto = 4180170000,
         fuente = "SRI, gasto tributario 2023 (tarifa 0% y devoluciones)", tipo = "tributario"),
    list(nombre = "Gasto tributario en impuesto a la renta (2023)", monto = 1795790000,
         fuente = "SRI, gasto tributario 2023 (sociedades y personas naturales)", tipo = "tributario")
  ),
  escenarios = resultados,
  bdh_observado = list(
    descripcion = "Bono de Desarrollo Humano en la ENEMDU (p75/p76, incluye pensiones no contributivas del MIES). Hogares clasificados por su ingreso per cápita sin el bono.",
    lineas = bdh_obs
  ),
  microdatos = list(
    descripcion = "Todos los hogares de la muestra. y = ingreso per cápita, n = miembros, w = factor de expansión, m5/m65 = presencia de menores de 5 y de personas de 65 años o más.",
    y = micro$y, n = micro$n, w = micro$w, m5 = micro$m5, m65 = micro$m65
  )
)

# R corre en locale C: se marcan los textos como UTF-8 para conservar las tildes.
marcar_utf8 <- function(x) {
  if (is.character(x)) { Encoding(x) <- "UTF-8"; return(x) }
  if (is.list(x)) { y <- lapply(x, marcar_utf8); names(y) <- names(x); return(y) }
  x
}
out <- marcar_utf8(out)

write_json(out, SALIDA, auto_unbox = TRUE, digits = 8, pretty = TRUE)
cat("OK ->", normalizePath(SALIDA), "\n\n")

# --------------------------------------------------------- 9. Resumen log ---
cat(sprintf("Pobreza personas: %.1f%% [%.1f - %.1f] | hogares pobres: %.0f de %.0f\n",
            100*inc_pob$est, 100*inc_pob$li, 100*inc_pob$ls, hog_pobres$est, hog_total$est))
cat(sprintf("Monto de referencia (4 x LP): USD %.2f | extrema: USD %.2f\n", MONTO_REF_LP, MONTO_REF_LPE))
cat(sprintf("Hogares 2 adultos + 2 niños: %.0f (pobres %.0f) | brecha media USD %.1f, mediana %.1f, máxima %.1f\n",
            ref_hogares$est, ref_pobres$est, brecha_ref_media, brecha_ref_med, brecha_ref_max))
cat(sprintf("Tamaño medio hogar no pobre: %.2f personas\n\n", tam_nopobre))
for (gk in names(grupos)) for (lk in names(lineas)) {
  r <- resultados[[paste0(gk,"__",lk)]]; L <- lineas[[lk]]
  sel <- grupos[[gk]]$filtro & h[[L$vp]] == 1
  for (infl in c(0, INFL_DEFECTO)) {
    monto <- TAM_REF * L$z * (1 + infl)
    br_infl <- (L$z*(1+infl) - h$ingpc[sel]) * h$personas[sel]
    salen <- sum(h$fexp[sel][br_infl <= monto])/sum(h$fexp[sel])
    cat(sprintf("%-38s | %-16s inflación %2.0f%% -> monto %6.2f  costo s/filtración %6.0f MM  salen %.0f%% de los hogares pobres\n",
                r$grupo_nombre, r$linea_nombre, 100*infl, monto,
                12*monto*r$hogares_pobres$est/1e6, 100*salen))
  }
}

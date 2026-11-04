# =============================================================================
# Expansión recursiva de accionistas hasta personas naturales (REBEFICS / anexo APS)
#
# Para cada sociedad informante, reemplaza a sus accionistas que son sociedades por los
# accionistas de esas sociedades (multiplicando porcentajes), hasta que solo queden
# personas naturales o nodos que no se pueden resolver.
#
#  - Sociedades nacionales accionistas (siempre nivel_aps = 1): se buscan como informantes
#    en la misma base y se expanden recursivamente.
#  - Sociedades extranjeras accionistas: no presentan anexo; su cadena viene declarada en el
#    anexo del propio informante (nivel_aps 2, 3, ...). Se usan las personas naturales (y
#    sociedades nacionales) de esas filas con su porcentaje_efectivo_r (% sobre el informante).
#    La parte del % extranjero que la cadena no cubre queda como EXT_SIN_CADENA.
#  - Lo que el informante no declara (total de nivel 1 < 100%) queda como NO_DECLARADO.
#  - Ciclos de propiedad cruzada: la cadena se corta y ese % queda como CICLO.
#
# Uso: Rscript expandir_accionistas_PN.R [base_entrada.dta] [carpeta_salida] [sufijo]
# =============================================================================
suppressPackageStartupMessages({
  library(data.table); library(haven); library(stringi); library(Matrix)
})
args    <- commandArgs(trailingOnly = TRUE)
ENTRADA <- if (length(args) >= 1) args[1] else "BDD_PN_accionistas_falsa.dta"
SALIDA  <- if (length(args) >= 2) args[2] else dirname(ENTRADA)
SUFIJO  <- if (length(args) >= 3) args[3] else "_falsa"
UMBRAL  <- 1e-10   # peso mínimo (fracción) para seguir expandiendo una cadena
MAX_IT  <- 100     # tope de saltos entre sociedades
TOL     <- 1e-6    # tolerancia para residuos (fracción)
MAX_LEON <- 200    # tope de términos de la serie A^k B

t0 <- Sys.time()
cols <- c("codigo_registro_anexo", "numero_ruc", "registro_actual", "periodo_procesado",
          "tipo_id_accionista", "id_accionista", "tipo_accionista", "tipo_relacion_accionista",
          "nivel_aps", "porcentaje_participacion_r", "porcentaje_efectivo_r")
d <- as.data.table(zap_labels(read_dta(ENTRADA, col_select = tidyselect::all_of(cols))))
chr <- names(d)[vapply(d, is.character, TRUE)]
d[, (chr) := lapply(.SD, trimws), .SDcols = chr]
n_filas_original <- nrow(d)

# ---------------------------------------------------------------------------
# 1. Un solo registro por informante: el vigente (registro_actual = S); si no hay,
#    el de periodo procesado más reciente.
# ---------------------------------------------------------------------------
reg <- unique(d[, .(numero_ruc, codigo_registro_anexo, registro_actual, periodo_procesado)])
reg[, `:=`(es_s = registro_actual == "S", cod = as.numeric(codigo_registro_anexo))]
setorder(reg, numero_ruc, -es_s, -periodo_procesado, -cod)
vig <- reg[!duplicated(numero_ruc)]
d <- d[codigo_registro_anexo %chin% vig$codigo_registro_anexo]
informantes <- vig$numero_ruc

# ---------------------------------------------------------------------------
# 2. Relaciones de propiedad
# ---------------------------------------------------------------------------
d <- d[tipo_relacion_accionista %chin% c("TITULARES DE DERECHO", "SOCIO FUNDADOR")]
d[, nivel := as.integer(nivel_aps)]
d[, clase := fcase(tipo_accionista == "PERSONAS NATURALES",  "PN",
                   tipo_accionista == "SOCIEDADES",          "SOC_NAC",
                   tipo_accionista == "SOCIEDAD EXTRANJERA", "SOC_EXT",
                   default = "OTRO")]
# persona natural con RUC (cédula + 001) -> misma persona que su cédula
d[clase == "PN" & tipo_id_accionista == "R" & nchar(id_accionista) == 13 &
    endsWith(id_accionista, "001"),
  `:=`(id_accionista = substr(id_accionista, 1, 10), tipo_id_accionista = "C")]

# tenencias directas de nivel 1 (personas y sociedades nacionales)
h_dir <- d[nivel == 1 & clase %chin% c("PN", "SOC_NAC"),
           .(inf = numero_ruc, holder = id_accionista, tipo_id = tipo_id_accionista, clase,
             peso = porcentaje_participacion_r / 100, directo = TRUE)]
# cadenas declaradas bajo sociedades extranjeras (niveles 2+): % efectivo sobre el informante
h_cad <- d[nivel > 1 & clase %chin% c("PN", "SOC_NAC"),
           .(inf = numero_ruc, holder = id_accionista, tipo_id = tipo_id_accionista, clase,
             peso = porcentaje_efectivo_r / 100, directo = FALSE)]
# cuadre por informante
cuadre <- d[, .(tot1      = sum(porcentaje_participacion_r[nivel == 1]) / 100,
                ext1      = sum(porcentaje_participacion_r[nivel == 1 & clase == "SOC_EXT"]) / 100,
                n_ext1    = sum(nivel == 1 & clase == "SOC_EXT"),
                cad       = sum(porcentaje_efectivo_r[nivel > 1 & clase %chin% c("PN", "SOC_NAC")]) / 100,
                n_cadena  = sum(nivel > 1)),
            by = .(inf = numero_ruc)]
cuadre <- merge(data.table(inf = informantes), cuadre, by = "inf", all.x = TRUE)
for (v in c("tot1", "ext1", "cad")) set(cuadre, which(is.na(cuadre[[v]])), v, 0)
for (v in c("n_ext1", "n_cadena")) set(cuadre, which(is.na(cuadre[[v]])), v, 0L)
cuadre[, `:=`(residuo_ext = pmax(0, ext1 - cad), no_decl = pmax(0, 1 - tot1))]
# tolerancia: los % vienen redondeados a 0.01 pp; residuos menores a 1e-6 son ruido numérico
cuadre[residuo_ext < TOL, residuo_ext := 0][no_decl < TOL, no_decl := 0]

h <- rbindlist(list(
  h_dir, h_cad,
  cuadre[residuo_ext > 0, .(inf, holder = "EXT_SIN_CADENA", tipo_id = "", clase = "EXT_SIN_CADENA",
                            peso = residuo_ext, directo = TRUE)],
  cuadre[no_decl > 0, .(inf, holder = "NO_DECLARADO", tipo_id = "", clase = "NO_DECLARADO",
                        peso = no_decl, directo = TRUE)]))
h <- h[peso > 0, .(peso = sum(peso)), by = .(inf, holder, tipo_id, clase, directo)]
h[clase == "SOC_NAC" & !(holder %chin% informantes), clase := "SOC_NAC_NO_ENCONTRADA"]
setkey(h, inf)

# ---------------------------------------------------------------------------
# 3. Expansión recursiva (joins iterativos con control de ciclos)
# ---------------------------------------------------------------------------
front <- h[, .(raiz = inf, holder, tipo_id, clase, peso, directo, salto = 1L,
               ruta = paste0("|", inf, "|"))]
res <- vector("list", MAX_IT); it <- 0L
repeat {
  it <- it + 1L
  es_soc <- front$clase == "SOC_NAC"
  if (any(es_soc)) {
    ciclo <- es_soc & stri_detect_fixed(front$ruta, paste0("|", front$holder, "|"))
    trunc <- es_soc & !ciclo & front$peso < UMBRAL
    front[ciclo, clase := "CICLO"]
    front[trunc, clase := "TRUNCADO"]
  }
  if (it == MAX_IT) front[clase == "SOC_NAC", clase := "TRUNCADO"]
  res[[it]] <- front[clase != "SOC_NAC"]
  sig <- front[clase == "SOC_NAC", .(raiz, soc = holder, peso_p = peso, salto, ruta)]
  if (!nrow(sig)) break
  front <- h[sig, on = .(inf = soc), allow.cartesian = TRUE, nomatch = 0L,
             .(raiz, holder, tipo_id, clase, peso = peso_p * peso, directo = FALSE,
               salto = salto + 1L, ruta = paste0(ruta, inf, "|"))]
  cat(sprintf("  salto %2d: %9d cadenas por expandir\n", it + 1L, nrow(front)))
}
r <- rbindlist(res)
saltos_max <- it

final <- r[, .(pct_total     = 100 * sum(peso),
               pct_directo   = 100 * sum(peso[directo & salto == 1L]),
               n_caminos     = .N,
               saltos_min    = min(salto),
               saltos_max    = max(salto)),
           by = .(numero_ruc = raiz, id_final = holder, tipo_id, clase)]
final[, pct_indirecto := pct_total - pct_directo]
setcolorder(final, c("numero_ruc", "clase", "id_final", "tipo_id", "pct_total",
                     "pct_directo", "pct_indirecto", "n_caminos", "saltos_min", "saltos_max"))
setorder(final, numero_ruc, clase, -pct_total)

# ---------------------------------------------------------------------------
# 4. Validación: solución matricial exacta  P = (I - A)^-1 B  =  sum_k A^k B
#    (en empresas sin ciclos ni truncamientos debe coincidir con la expansión)
# ---------------------------------------------------------------------------
ii <- setNames(seq_along(informantes), informantes)
hA <- h[clase == "SOC_NAC"]
A <- sparseMatrix(i = ii[hA$inf], j = ii[hA$holder], x = hA$peso,
                  dims = c(length(ii), length(ii)))
hB <- h[clase != "SOC_NAC"][, nodo := paste(clase, holder, sep = ":")]
kk <- setNames(seq_along(unique(hB$nodo)), unique(hB$nodo))
B <- sparseMatrix(i = ii[hB$inf], j = kk[hB$nodo], x = hB$peso,
                  dims = c(length(ii), length(kk)))
P <- B; Tk <- B; k <- 0L
while (k < MAX_LEON) {
  k <- k + 1L
  Tk <- A %*% Tk
  Tk@x[abs(Tk@x) < 1e-14] <- 0; Tk <- drop0(Tk)
  if (!length(Tk@x)) break
  P <- P + Tk
}
converge <- !length(Tk@x)
Pt <- as(P, "TsparseMatrix")
leon <- data.table(numero_ruc = informantes[Pt@i + 1L], nodo = names(kk)[Pt@j + 1L], pct_leon = 100 * Pt@x)
con_ciclo <- final[clase %chin% c("CICLO", "TRUNCADO"), unique(numero_ruc)]
comp <- merge(final[!numero_ruc %chin% con_ciclo, .(numero_ruc, nodo = paste(clase, id_final, sep = ":"), pct_total)],
              leon[!numero_ruc %chin% con_ciclo], by = c("numero_ruc", "nodo"), all = TRUE)
comp[is.na(pct_total), pct_total := 0][is.na(pct_leon), pct_leon := 0]
dif_max <- comp[, max(abs(pct_total - pct_leon))]
# en empresas con ciclos: % de personas naturales según cada método
pn_ciclo <- merge(final[numero_ruc %chin% con_ciclo & clase == "PN", .(exp = sum(pct_total)), by = numero_ruc],
                  leon[numero_ruc %chin% con_ciclo & startsWith(nodo, "PN:"), .(leo = sum(pct_leon)), by = numero_ruc],
                  by = "numero_ruc", all = TRUE)

# ---------------------------------------------------------------------------
# 5. Sociedades accionistas que no están como informantes en el REBEFICS
# ---------------------------------------------------------------------------
soc_acc <- d[clase %chin% c("SOC_NAC", "SOC_EXT"),
             .(n_relaciones = .N, n_informantes = uniqueN(numero_ruc),
               pct_promedio = mean(fifelse(nivel == 1, porcentaje_participacion_r, porcentaje_efectivo_r))),
             by = .(id_accionista, clase)]
soc_acc[, en_rebefics := id_accionista %chin% informantes]
# extranjeras sin ninguna cadena declarada en el informante
ext_sin <- d[nivel == 1 & clase == "SOC_EXT"][cuadre[n_cadena == 0], on = .(numero_ruc = inf), nomatch = 0L]
soc_acc[, extranjera_sin_cadena := clase == "SOC_EXT" & id_accionista %chin% ext_sin$id_accionista]
no_enc <- soc_acc[en_rebefics == FALSE]
setorder(no_enc, clase, -n_relaciones)

# ---------------------------------------------------------------------------
# 6. Guardar
# ---------------------------------------------------------------------------
f_final <- file.path(SALIDA, paste0("BDD_PN_accionistas_finales", SUFIJO, ".dta"))
f_noenc <- file.path(SALIDA, paste0("sociedades_accionistas_no_encontradas", SUFIJO, ".dta"))
f_rep   <- file.path(SALIDA, paste0("reporte_expansion_accionistas", SUFIJO, ".txt"))
lab <- c(numero_ruc = "RUC de la sociedad informante",
         clase = "PN / SOC_NAC_NO_ENCONTRADA / EXT_SIN_CADENA / NO_DECLARADO / CICLO / TRUNCADO",
         id_final = "Identificación del dueño final (cédula/pasaporte) o del nodo no resuelto",
         tipo_id = "Tipo de identificación del dueño final",
         pct_total = "% final sobre la sociedad (directo + indirecto)",
         pct_directo = "% como accionista directo (nivel 1)",
         pct_indirecto = "% a través de otras sociedades",
         n_caminos = "Número de cadenas de propiedad que llegan a este dueño",
         saltos_min = "Mínimo de sociedades recorridas (1 = directo)",
         saltos_max = "Máximo de sociedades recorridas")
out <- copy(final); for (v in names(lab)) attr(out[[v]], "label") <- lab[[v]]
write_dta(as.data.frame(out), f_final, version = 14)
write_dta(as.data.frame(no_enc), f_noenc, version = 14)

pc <- function(x) sprintf("%.2f%%", x)
comp_clase <- final[, .(pct = sum(pct_total)), by = .(numero_ruc, clase)][
  , .(pct_promedio = mean(c(pct, rep(0, length(informantes) - .N))),
      n_sociedades = .N), by = clase][order(-pct_promedio)]
nac <- soc_acc[clase == "SOC_NAC"]; ext <- soc_acc[clase == "SOC_EXT"]
rel_nac <- d[nivel == 1 & clase == "SOC_NAC"]
rep <- c(
  "REPORTE - EXPANSIÓN RECURSIVA DE ACCIONISTAS", strrep("=", 70),
  sprintf("Base de entrada: %s", basename(ENTRADA)),
  sprintf("Filas originales: %s | registros no vigentes descartados: %s",
          format(n_filas_original, big.mark = ","), format(nrow(reg) - nrow(vig), big.mark = ",")),
  sprintf("Sociedades informantes (registro vigente): %s", format(length(informantes), big.mark = ",")),
  sprintf("Relaciones de propiedad usadas (titulares / socios fundadores): %s", format(nrow(d), big.mark = ",")),
  "",
  "SOCIEDADES ACCIONISTAS QUE NO ESTÁN EN EL REBEFICS COMO INFORMANTES", strrep("-", 70),
  sprintf("Nacionales: %s de %s sociedades únicas (%s) | %s de %s relaciones",
          format(sum(!nac$en_rebefics), big.mark = ","), format(nrow(nac), big.mark = ","),
          pc(100 * mean(!nac$en_rebefics)),
          format(sum(nac[en_rebefics == FALSE, n_relaciones]), big.mark = ","),
          format(sum(nac$n_relaciones), big.mark = ",")),
  sprintf("Extranjeras: %s de %s sociedades únicas (%s) — se resuelven con la cadena declarada",
          format(sum(!ext$en_rebefics), big.mark = ","), format(nrow(ext), big.mark = ","),
          pc(100 * mean(!ext$en_rebefics))),
  sprintf("   de ellas, sin ninguna cadena declarada en el informante: %s",
          format(sum(ext$extranjera_sin_cadena), big.mark = ",")),
  sprintf("TOTAL no encontradas como informantes: %s sociedades únicas",
          format(nrow(no_enc), big.mark = ",")),
  sprintf("Informantes con al menos una sociedad nacional no encontrada (directa): %s",
          format(h[clase == "SOC_NAC_NO_ENCONTRADA" & directo == TRUE, uniqueN(inf)], big.mark = ",")),
  sprintf("Informantes con %% extranjero sin cadena, total o parcial (> 0.05 pp): %s",
          format(cuadre[residuo_ext > 0.0005, .N], big.mark = ",")),
  sprintf("Informantes con cadena declarada mayor que su %% extranjero (> 0.05 pp): %s",
          format(cuadre[cad - ext1 > 0.0005, .N], big.mark = ",")),
  "",
  "COMPOSICIÓN FINAL (promedio simple entre informantes, % del capital)", strrep("-", 70),
  sprintf("  %-24s %10s  %s", comp_clase$clase, pc(comp_clase$pct_promedio),
          paste("en", format(comp_clase$n_sociedades, big.mark = ","), "sociedades")),
  "",
  "EXPANSIÓN", strrep("-", 70),
  sprintf("Saltos entre sociedades: máximo %d", saltos_max),
  sprintf("Filas en la base final: %s (personas naturales: %s, únicas: %s)",
          format(nrow(final), big.mark = ","), format(final[clase == "PN", .N], big.mark = ","),
          format(final[clase == "PN", uniqueN(id_final)], big.mark = ",")),
  sprintf("Informantes con %% que vuelve a ellas mismas (ciclos): %s", format(length(con_ciclo), big.mark = ",")),
  sprintf("Informantes con total declarado de nivel 1 > 100%%: %s", format(cuadre[tot1 > 1 + TOL, .N], big.mark = ",")),
  "",
  sprintf("VALIDACIÓN CONTRA LA SOLUCIÓN MATRICIAL (I - A)^-1 B  (%d términos, %s)", k,
          if (converge) "converge" else "NO converge: hay ciclos con participaciones cruzadas >= 100%"),
  strrep("-", 70),
  sprintf("Empresas sin ciclos: diferencia máxima = %.2e puntos porcentuales", dif_max),
  sprintf("Empresas con ciclos (%d): %% en personas naturales, expansión = %s vs matricial = %s (promedios)",
          nrow(pn_ciclo), pc(mean(pn_ciclo$exp, na.rm = TRUE)), pc(mean(pn_ciclo$leo, na.rm = TRUE))),
  "  (la matricial reparte el % del ciclo entre los dueños finales; la expansión lo deja en CICLO)",
  "",
  sprintf("Tiempo: %.1f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))),
  sprintf("Salidas: %s, %s", basename(f_final), basename(f_noenc)))
writeLines(rep, f_rep)
cat(rep, sep = "\n")

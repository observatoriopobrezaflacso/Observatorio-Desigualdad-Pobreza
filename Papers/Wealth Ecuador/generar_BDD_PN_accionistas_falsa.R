# =============================================================================
# Base FALSA de accionistas (REBEFICS / anexo APS) - BDD_PN_accionistas
# Replica la estructura y los descriptivos de:
#   descriptivos/REBEFICS/BDD_PN_accionistas.docx  (codebook Stata, 933,131 obs, 53 vars)
# Todos los datos son sintéticos. Los identificadores (cédulas, RUC) tienen
# formato y dígito verificador válidos pero se generan al azar.
#
# Estructura de propiedad (para probar expandir_accionistas_PN.do):
#  - ~75% de las filas con sociedades nacionales accionistas apuntan al RUC de otro
#    informante (grupos y cadenas jerárquicas); el resto no está como informante.
#  - 1% de enlaces aleatorios + 70 ciclos explícitos (A<->B, A->B->C->A).
#  - nivel_aps > 1 solo en cadenas bajo accionistas sociedades extranjeras: el
#    informante declara a los dueños de su accionista extranjero hasta personas
#    naturales (porcentaje_efectivo_r = % sobre el informante). 85% de los
#    extranjeros tienen cadena; 15% de las cadenas son incompletas.
#  - 70% de las personas naturales con RUC usan la cédula de alguien con tipo "C".
# Se escribe en formato Stata 118 (version = 14), legible por Stata SE/MP >= 14.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(haven) })
set.seed(20261104)

args  <- commandArgs(trailingOnly = TRUE)
N     <- if (length(args) >= 1) as.integer(args[1]) else 933131L
OUT   <- if (length(args) >= 2) args[2] else "BDD_PN_accionistas_falsa.dta"
escala <- N / 933131

n_emp <- round(175368 * escala)          # informantes únicos (numero_ruc)
n_reg <- round(176236 * escala)          # registros de anexo únicos
n_acc <- round(691698 * escala)          # accionistas únicos (id_accionista)

# ---------------------------------------------------------------- utilidades
pick <- function(n, vals, freq) sample(vals, n, replace = TRUE, prob = freq)
uniq_digits <- function(n, ndig, lo = 10^(ndig - 1)) {
  # n códigos numéricos únicos de ndig dígitos
  x <- unique(floor(runif(ceiling(n * 1.3), lo, 10^ndig)))
  while (length(x) < n) x <- unique(c(x, floor(runif(n, lo, 10^ndig))))
  sprintf(paste0("%0", ndig, ".0f"), sample(x, n))
}
cedula <- function(n) {  # cédula ecuatoriana válida (módulo 10)
  prov <- sample(c(1:24, 30), n, TRUE, prob = c(rep(1, 24), .3) *
                   c(3,2,1,1,1,1,3,1,15,2,3,2,5,1,1,1,25,3,1,1,1,1,2,2,1))
  d3 <- sample(0:5, n, TRUE)
  rest <- matrix(sample(0:9, n * 6, TRUE), n)
  m <- cbind(prov %/% 10, prov %% 10, d3, rest)
  coef <- c(2,1,2,1,2,1,2,1,2)
  p <- sweep(m, 2, coef, `*`); p[p > 9] <- p[p > 9] - 9
  ver <- (10 - rowSums(p) %% 10) %% 10
  do.call(paste0, as.data.frame(cbind(m, ver)))
}
ruc_sociedad <- function(n, publica = FALSE) {  # RUC sociedad (módulo 11)
  if (n == 0) return(character(0))
  prov <- sample(1:24, n, TRUE, prob = c(3,2,1,1,1,1,3,1,30,2,3,2,5,1,1,1,40,3,1,1,1,1,2,2))
  m <- cbind(prov %/% 10, prov %% 10, if (publica) 6 else 9,
             matrix(sample(0:9, n * 6, TRUE), n))
  s <- as.vector(m %*% c(4,3,2,7,6,5,4,3,2)) %% 11
  ver <- ifelse(s == 0, 0, 11 - s)
  ok <- ver < 10
  out <- paste0(do.call(paste0, as.data.frame(cbind(m, ver))), "001")
  out[!ok] <- ruc_sociedad(sum(!ok), publica)
  out
}
uniq_gen <- function(f, n, ...) {  # n identificadores únicos (evita colisiones)
  x <- unique(f(ceiling(n * 1.15), ...))
  while (length(x) < n) x <- unique(c(x, f(n, ...)))
  x[seq_len(n)]
}
alnum <- function(n, len) do.call(paste0, as.data.frame(matrix(sample(c(LETTERS, 0:9), n * len, TRUE), n)))

# ---------------------------------------------------------------- catálogos
paises <- c("ECUADOR","COLOMBIA","ESTADOS UNIDOS","VENEZUELA","ESPAÑA","PERU","PANAMA",
  "CHINA","ITALIA","CHILE","ARGENTINA","MEXICO","ALEMANIA","FRANCIA","CANADA","CUBA",
  "BRASIL","SUIZA","PAISES BAJOS","REINO UNIDO","ISLAS VIRGENES BRITANICAS","URUGUAY",
  "BOLIVIA","COSTA RICA","REPUBLICA DOMINICANA","BELGICA","PORTUGAL","ISRAEL","JAPON",
  "COREA DEL SUR","INDIA","RUSIA","AUSTRIA","SUECIA","NORUEGA","DINAMARCA","FINLANDIA",
  "IRLANDA","LUXEMBURGO","ISLAS CAIMAN","BAHAMAS","BARBADOS","BERMUDAS","BELICE",
  "GUATEMALA","HONDURAS","EL SALVADOR","NICARAGUA","PARAGUAY","PUERTO RICO","TURQUIA",
  "LIBANO","SIRIA","JORDANIA","EGIPTO","MARRUECOS","SUDAFRICA","NIGERIA","AUSTRALIA",
  "NUEVA ZELANDA","TAIWAN","HONG KONG","SINGAPUR","FILIPINAS","VIETNAM","TAILANDIA",
  "INDONESIA","MALASIA","PAKISTAN","IRAN","UCRANIA","POLONIA","RUMANIA","HUNGRIA",
  "REPUBLICA CHECA","GRECIA","CROACIA","SERBIA","BULGARIA","ESLOVAQUIA","ESLOVENIA",
  "LITUANIA","LETONIA","ESTONIA","BIELORRUSIA","GEORGIA","ARMENIA","KAZAJISTAN",
  "EMIRATOS ARABES UNIDOS","ARABIA SAUDITA","QATAR","KUWAIT","CHIPRE","MALTA","MONACO",
  "LIECHTENSTEIN","ANDORRA","GIBRALTAR","ISLA DE MAN","JERSEY","GUERNSEY","CURAZAO",
  "ARUBA","ANGUILA","ANTIGUA Y BARBUDA","SAN VICENTE Y LAS GRANADINAS","SANTA LUCIA",
  "GRANADA","DOMINICA","SAN CRISTOBAL Y NIEVES","TRINIDAD Y TOBAGO","JAMAICA","HAITI",
  "GUYANA","SURINAM","ISLAS TURCAS Y CAICOS","ISLAS MARSHALL","SEYCHELLES","MAURICIO",
  "SAMOA","VANUATU","NIUE","ISLAS COOK","LIBERIA","GHANA","CAMERUN","SENEGAL","COSTA DE MARFIL",
  "ANGOLA","KENIA","ETIOPIA","TUNEZ","ARGELIA","BANGLADESH","SRI LANKA","NEPAL","MONGOLIA",
  "ISLANDIA","ALBANIA","MOLDAVIA","UZBEKISTAN","AZERBAIYAN")
paises <- paises[1:139]
cod_pais <- setNames(sprintf("%03d", c(233, sample(setdiff(101:599, 233), 138))), paises)
peso_ext <- c(0, 30, 18, 14, 10, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 1.5, 1.2, 1.2, 1,
              rep(.6, 8), rep(.25, 110))
peso_ext <- peso_ext[1:139]
paraisos <- c("PANAMA","ISLAS VIRGENES BRITANICAS","ISLAS CAIMAN","BAHAMAS","BARBADOS",
  "BERMUDAS","BELICE","LUXEMBURGO","CHIPRE","MALTA","MONACO","LIECHTENSTEIN","ANDORRA",
  "GIBRALTAR","ISLA DE MAN","JERSEY","GUERNSEY","CURAZAO","ARUBA","ANGUILA",
  "ANTIGUA Y BARBUDA","SAN VICENTE Y LAS GRANADINAS","SANTA LUCIA","GRANADA",
  "ISLAS TURCAS Y CAICOS","ISLAS MARSHALL","SEYCHELLES","SAMOA","VANUATU","NIUE")

sector_lbl <- c("SIN ACTIVIDAD ECONÓMICA",
  "AGRICULTURA, GANADERÍA, SILVICULTURA Y PESCA","EXPLOTACIÓN DE MINAS Y CANTERAS",
  "INDUSTRIAS MANUFACTURERAS","SUMINISTRO DE ELECTRICIDAD, GAS, VAPOR Y AIRE ACONDICIONADO",
  "DISTRIBUCIÓN DE AGUA; ALCANTARILLADO, GESTIÓN DE DESECHOS Y ACTIVIDADES DE SANEAMIENTO",
  "CONSTRUCCIÓN","COMERCIO AL POR MAYOR Y AL POR MENOR; REPARACIÓN DE VEHÍCULOS AUTOMOTORES Y MOTOCICLETAS",
  "TRANSPORTE Y ALMACENAMIENTO","ACTIVIDADES DE ALOJAMIENTO Y DE SERVICIO DE COMIDAS",
  "INFORMACIÓN Y COMUNICACIÓN","ACTIVIDADES FINANCIERAS Y DE SEGUROS","ACTIVIDADES INMOBILIARIAS",
  "ACTIVIDADES PROFESIONALES, CIENTÍFICAS Y TÉCNICAS","ACTIVIDADES DE SERVICIOS ADMINISTRATIVOS Y DE APOYO",
  "ADMINISTRACIÓN PÚBLICA Y DEFENSA; PLANES DE SEGURIDAD SOCIAL DE AFILIACIÓN OBLIGATORIA",
  "ENSEÑANZA","ACTIVIDADES DE ATENCIÓN DE LA SALUD HUMANA Y DE ASISTENCIA SOCIAL",
  "ARTES, ENTRETENIMIENTO Y RECREACIÓN","OTRAS ACTIVIDADES DE SERVICIOS",
  "ACTIVIDADES DE LOS HOGARES COMO EMPLEADORES","ACTIVIDADES DE ORGANIZACIONES Y ÓRGANOS EXTRATERRITORIALES",
  "ACTIVIDADES NO CLASIFICADAS")
# 23 letras (A-U, V, Z) -> sector 1..22 (Z comparte 22). 0 = sin CIIU
letras <- c(LETTERS[1:21], "V", "Z"); sec_de_letra <- setNames(c(1:22, 22), letras)
# rangos de división CIIU Rev.4 por sección
div <- list(A=1:3,B=5:9,C=10:33,D=35,E=36:39,F=41:43,G=45:47,H=49:53,I=55:56,J=58:63,
  K=64:66,L=68,M=69:75,N=77:82,O=84,P=85,Q=86:88,R=90:93,S=94:96,T=97:98,U=99,V=99,Z=0)
peso_letra <- c(A=6,B=1.5,C=9,D=.8,E=.5,F=7,G=22,H=7,I=3,J=3.5,K=10,L=9,M=8,N=5,O=.3,
                P=2,Q=3,R=.8,S=1.5,T=.08,U=.08,V=.06,Z=.06)
ciiu_pool <- unique(unlist(lapply(letras, function(l) {
  k <- max(4, round(1700 * peso_letra[l] / sum(peso_letra)))
  paste0(l, sprintf("%02d", sample(div[[l]], k, TRUE)), sprintf("%04d", sample(0:9999, k)))
})))
ciiu_pool <- c(ciiu_pool[!duplicated(substr(ciiu_pool, 1, 1))],
               sample(ciiu_pool[duplicated(substr(ciiu_pool, 1, 1))]))[1:1533]
ciiu_w <- peso_letra[substr(ciiu_pool, 1, 1)] * (rexp(length(ciiu_pool)) + .2)
ciiu_w <- pmax(ciiu_w, 3 / 175368)

# parroquias: región(1 costa/2 sierra/3 amazonía/4 insular) + prov + cantón + parroquia
prov_reg <- c(`01`=2,`02`=2,`03`=2,`04`=2,`05`=2,`06`=2,`07`=1,`08`=1,`09`=1,`10`=2,`11`=2,
  `12`=1,`13`=1,`14`=3,`15`=3,`16`=3,`17`=2,`18`=2,`19`=3,`20`=4,`21`=3,`22`=3,`23`=1,`24`=1)
prov_w  <- c(2,.5,.6,.5,.8,1,2,.7,30,1,1.5,1.5,4,.3,.3,.3,40,2,.2,.4,.4,.3,1.5,1.2)
parr <- unique(unlist(lapply(seq_along(prov_reg), function(i) {
  k <- max(15, round(1186 * prov_w[i] / sum(prov_w) * 3))
  paste0(prov_reg[i], names(prov_reg)[i], sprintf("%02d", sample(1:15, k, TRUE)),
         sprintf("%02d", sample(1:60, k, TRUE)))
})))
parr <- sample(parr, 1186)
parr_w <- pmax(prov_w[match(substr(parr, 2, 3), names(prov_reg))] * (rexp(1186) + .3), .05)
parr_pk <- setNames(as.character(sample(1:1300, 1186)), parr)
areas <- unique(c("21101", paste0(sample(1:2, 60, TRUE), sprintf("%04d", sample(1001:9999, 60)))))[1:41]
areas[sample(41, 5)] <- sprintf("%06d", sample(100000:299999, 5))   # algunas de 6 dígitos

tipos_emp <- c("COMPANIA DE ECONOMIA MIXTA","COMPANIAS ANONIMAS","FIDEICOMISOS",
  "FONDOS DE INVERSIÓN","MISIONES Y ORGANISMOS INTERNACIONALES","OTRAS","SECTOR PUBLICO",
  "SUCESIONES INDIVISAS")
tipos_frq <- c(706,394547,125782,8792,45,403003,24,232)

# ---------------------------------------------------- 1. REGISTROS (empresas)
# Número de filas por registro: cola pesada (pocos fideicomisos/bancos muy grandes)
nr <- pmin(floor(runif(n_reg)^(-1 / 1.3)), 30000)
nr <- pmax(1L, as.integer(round(nr * N / sum(nr))))
dif <- N - sum(nr)
while (dif != 0) {                         # ajuste exacto a N
  i <- sample(which(nr > 1 | dif > 0), abs(dif), TRUE)
  tab <- table(i); nr[as.integer(names(tab))] <- nr[as.integer(names(tab))] + sign(dif) * as.integer(tab)
  nr <- pmax(1L, nr); dif <- N - sum(nr)
}

emp <- data.table(ruc = uniq_gen(ruc_sociedad, n_emp))
emp[, publica := runif(.N) < 0.0006]
emp[publica == TRUE, ruc := uniq_gen(ruc_sociedad, .N, publica = TRUE)]
emp <- unique(emp, by = "ruc")
n_emp <- nrow(emp)
emp[, tipo_sociedad := pick(.N, c("SOCIEDAD EXTRANJERA","SOCIEDADES"), c(32000, 898735))]
emp[, pais_sociedad := "ECUADOR"]
ext <- emp$tipo_sociedad == "SOCIEDAD EXTRANJERA"
emp[ext & runif(.N) < 0.9, pais_sociedad := pick(.N, paises[2:106], peso_ext[2:106] + .3)]
emp[sample(.N, max(1, round(4 * escala))), pais_sociedad := ""]
emp[, `:=`(
  tipo = pick(.N, tipos_emp, tipos_frq),
  declaracion_anticipada = pick(.N, c("", "NO", "SI"), c(287, 923582, 9262)),
  codigo_opera_clase_contrib = pick(.N, c("ESP","OTR","RMP"), c(192460, 683584, 57087)),
  codigo_opera_estado_contrib = pick(.N, c("ACT","PAS","SDE"), c(919581, 12429, 1121)),
  codigoarea = pick(.N, areas, c(40, rexp(40))),
  ciiu = pick(.N, ciiu_pool, ciiu_w),
  parroquia = pick(.N, parr, parr_w))]
emp[publica == TRUE, tipo := "SECTOR PUBLICO"]
emp[sample(.N, max(1, round(6 * escala))), ciiu := ""]
emp[sample(.N, max(1, round(20 * escala))), parroquia := ""]

# registros: ~868 empresas tienen 2 registros (uno histórico N y uno actual S)
reg <- data.table(reg_id = seq_len(n_reg), nfilas = nr,
                  ruc = c(emp$ruc, sample(emp$ruc, n_reg - n_emp)))
reg <- reg[sample(.N)]
reg[, dup := seq_len(.N), by = ruc]
reg[, ndup := .N, by = ruc]
reg[, registro_actual := fifelse(ndup > 1, fifelse(dup == 1, "N", "S"),
                                 fifelse(runif(.N) < 0.18, "N", "S"))]
reg[, codigo_registro_anexo := as.character(sample(70000000:99999999, .N))]
# total de participación declarado por la sociedad (rango 0-200)
u <- runif(n_reg)
reg[, total_decl := fcase(
  u < 0.40, 100,
  u < 0.52, 100 - rexp(.N, 1 / 0.6),
  u < 0.93, runif(.N, 35, 99),
  u < 0.975, runif(.N, 100.01, 200),
  u < 0.995, runif(.N, 0, 35),
  default = 0)]
reg[, total_decl := pmin(pmax(total_decl, 0), 200)]
reg[, cobertura := fifelse(runif(.N) < .8, 1, runif(.N, .4, 1))]

# ---------------------------------------------------- 2. FILAS (accionistas)
d <- reg[rep(seq_len(.N), nfilas)]
d <- merge(d, emp, by = "ruc", sort = FALSE)
d <- d[sample(.N)]
setorder(d, reg_id)

# tipo de identificación / tipo de accionista (consistentes entre sí)
d[, tipo_id_accionista := pick(.N, c("C","E","P","R"), c(815320, 32060, 14653, 71098))]
d[, codigo_tipo_sociedad_ext := ""]
d[tipo_id_accionista == "E", codigo_tipo_sociedad_ext :=
    pick(.N, c("103564","116","117","118","120","121"), c(421,16410,13858,840,327,204))]
d[, tipo_accionista := "PERSONAS NATURALES"]
d[tipo_id_accionista == "E" & codigo_tipo_sociedad_ext != "116", tipo_accionista := "SOCIEDAD EXTRANJERA"]
d[tipo_id_accionista == "R" & runif(.N) < 37257 / 71098, tipo_accionista := "SOCIEDADES"]

# país del accionista
d[, pais_accionista := "ECUADOR"]
d[tipo_id_accionista %in% c("E","P") & runif(.N) < 44375 / 46713,
  pais_accionista := pick(.N, paises[-1], peso_ext[-1])]
d[, codigo_pais_accionista := cod_pais[pais_accionista]]
d[, pais_accionista_nac_ext := as.numeric(pais_accionista == "ECUADOR")]

# identificador del accionista: pool con repeticiones (mismas personas en varias empresas)
d[, grp := fifelse(tipo_id_accionista == "R",
                   fifelse(tipo_accionista == "SOCIEDADES", "RS", "RP"), tipo_id_accionista)]
cnt <- d[, .N, by = grp]
cnt[, npool := pmax(1L, round(n_acc * N / sum(N)))]
for (g in cnt$grp) {
  k <- cnt[grp == g, npool]
  pool <- switch(g,
    C  = uniq_gen(cedula, k),
    RP = paste0(uniq_gen(cedula, k), "001"),
    RS = uniq_gen(ruc_sociedad, k),
    P  = alnum(k, 9),
    E  = alnum(k, 12))
  pool <- unique(pool)
  idx <- d$grp == g
  m <- sum(idx)
  # cada id del pool aparece al menos una vez; el resto con cola pesada
  rep_ids <- c(pool, sample(pool, m - length(pool), TRUE, prob = rexp(length(pool))^2))
  set(d, which(idx), "id_accionista", sample(rep_ids[seq_len(m)]))
}

# ---- Enlaces entre sociedades (para probar la expansión recursiva) ----
# Cada empresa recibe un rango aleatorio; una sociedad nacional accionista se elige entre las
# empresas de rango mayor -> estructura jerárquica (grupos, cadenas de varios niveles).
# 1% de los enlaces ignora el rango y genera propiedad cruzada (ciclos).
# ~25% de las sociedades nacionales accionistas NO está en la base como informante.
filas_emp <- reg[, .(nf = sum(nfilas)), by = ruc]
emp[filas_emp, nf := i.nf, on = "ruc"]
emp[, rango := sample(.N)]
setorder(emp, rango)
emp[, pop := rexp(.N)^3 / sqrt(nf)]          # holdings dueñas de varias empresas
cw <- cumsum(emp$pop)
enlazar <- function(r_desde, ciclico = rep(FALSE, length(r_desde))) {
  lo <- fifelse(ciclico, 0, cw[pmin(r_desde, n_emp)])
  pos <- pmin(n_emp, findInterval(runif(length(r_desde), lo, cw[n_emp]), cw) + 1L)
  out <- emp$ruc[pos]
  out[(!ciclico & r_desde >= n_emp) | pos == r_desde] <- NA_character_
  out
}
d[emp, rango := i.rango, on = "ruc"]
idx_rs <- which(d$grp == "RS")
enl <- enlazar(d$rango[idx_rs], ciclico = runif(length(idx_rs)) < 0.01)
enl[runif(length(idx_rs)) > 0.75] <- NA
set(d, idx_rs[!is.na(enl)], "id_accionista", enl[!is.na(enl)])
# las no enlazadas no deben coincidir por azar con un informante
repetir <- function() idx_rs[is.na(enl)][d$id_accionista[idx_rs[is.na(enl)]] %in% emp$ruc]
while (length(malas <- repetir())) {
  ids_malos <- unique(d$id_accionista[malas])
  nuevos <- setNames(ruc_sociedad(length(ids_malos)), ids_malos)
  set(d, malas, "id_accionista", unname(nuevos[d$id_accionista[malas]]))
}
# ciclos explícitos de propiedad cruzada: 2-ciclos (A <-> B) y 3-ciclos (A -> B -> C -> A).
# Fila (informante i, accionista j) = j es dueña de i. Para cerrar el ciclo, en el anexo de
# X se cambia un accionista persona natural por la sociedad Y.
enl_rows <- d[idx_rs][id_accionista %chin% emp$ruc, .(i = ruc, j = id_accionista)]
pares <- enl_rows[sample(.N, min(.N, 40))]
tri <- merge(enl_rows, enl_rows, by.x = "j", by.y = "i", suffixes = c("", ".k"))[j.k != i]
tri <- tri[sample(.N, min(.N, 30))]
ciclos <- unique(rbind(pares[, .(X = j, Y = i)], tri[, .(X = j.k, Y = i)]))
d[, fila_tmp := .I]
fil <- d[tipo_id_accionista == "C"][ciclos, on = .(ruc = X), mult = "first", nomatch = 0L, .(fila_tmp, Y)]
fil <- fil[!duplicated(fila_tmp)]
d[fil$fila_tmp, `:=`(tipo_id_accionista = "R", tipo_accionista = "SOCIEDADES", grp = "RS",
                     id_accionista = fil$Y)]
d[, fila_tmp := NULL]
# 70% de las personas naturales con RUC usan la cédula de alguien que también figura con "C"
rp  <- unique(d[grp == "RP", id_accionista])
ced <- unique(d[grp == "C", id_accionista])
mapa <- setNames(rp, rp)
cambia <- runif(length(rp)) < 0.7
mapa[cambia] <- paste0(sample(ced, sum(cambia)), "001")
d[grp == "RP", id_accionista := unname(mapa[id_accionista])]

d[, tipo_relacion_accionista := pick(.N,
  c("ADMINISTRADOR","APODERADO GENERAL","BENEFICIARIO","MIEMBRO DE DIRECTORIO","SOCIO FUNDADOR","TITULARES DE DERECHO"),
  c(115012, 2755, 62311, 35271, 2979, 714803))]
d[tipo_accionista != "PERSONAS NATURALES", tipo_relacion_accionista :=
    fifelse(runif(.N) < .97, "TITULARES DE DERECHO", "SOCIO FUNDADOR")]

d[, marca_soc_publica_extranjera := "NO"]
d[tipo_accionista == "SOCIEDAD EXTRANJERA", marca_soc_publica_extranjera :=
    fifelse(runif(.N) < 620 / 15650, "SI", "NO")]
d[, marca_empresa_publica := fifelse(runif(.N) < 488 / N, "SI", "NO")]

# nivel en la cadena de propiedad: 1 = accionista directo. Los niveles 2+ solo existen en las
# cadenas declaradas bajo accionistas que son sociedades extranjeras (se agregan más abajo).
d[, nivel := 1L]

# régimen fiscal / paraísos fiscales (solo accionistas extranjeros)
ext_acc <- d$pais_accionista_nac_ext == 0
d[, tipo_regimen_fiscal := "01"]
d[ext_acc, tipo_regimen_fiscal := pick(.N, c("01","02","03"), c(39894, 3479, 1002))]
d[, paraiso_fiscal_accionista := fifelse(tipo_regimen_fiscal == "02" & runif(.N) < 3169 / 3479, "S", "")]
d[, cod_pais_rel_par_fiscal := ""]
d[tipo_regimen_fiscal == "02", cod_pais_rel_par_fiscal := cod_pais[pick(.N, paraisos, rexp(30))]]
tipos_reg <- c("SOCIEDAD DE RESPONSABILIDAD LIMITADA","INTERNATIONAL BUSINESS COMPANY",
  "LIMITED LIABILITY COMPANY","SOCIEDAD ANONIMA OFFSHORE","TRUST","FUNDACION PRIVADA",
  "EXEMPTED COMPANY","HOLDING COMPANY","REGIMEN DE ZONA FRANCA","PARTNERSHIP")
den_pool <- unique(paste(sample(tipos_reg, 300, TRUE), "-", sample(paraisos, 300, TRUE)))[1:133]
d[, den_reg_fiscal_preferente := ""]
d[tipo_regimen_fiscal == "03" & runif(.N) < 935 / 1002,
  den_reg_fiscal_preferente := pick(.N, den_pool, rexp(133) + .5)]
d[, pais_rel_otro_regimen_fiscal := ""]
d[ext_acc, pais_rel_otro_regimen_fiscal := codigo_pais_accionista]
d[!ext_acc & runif(.N) < (95119 - 44375) / 888756, pais_rel_otro_regimen_fiscal := "233"]

ciudades <- c("MIAMI","NUEVA YORK","MADRID","BARCELONA","BOGOTA","MEDELLIN","CALI","LIMA",
  "CARACAS","PANAMA","SANTIAGO","BUENOS AIRES","CIUDAD DE MEXICO","HOUSTON","LOS ANGELES",
  "TORONTO","ROMA","MILAN","PARIS","BERLIN","ZURICH","GINEBRA","LONDRES","AMSTERDAM",
  "SHANGHAI","BEIJING","SHENZHEN","TORTOLA","GEORGE TOWN","NASSAU","LUXEMBURGO","VALENCIA",
  "SEVILLA","PASTO","CUCUTA","MARACAIBO","PIURA","MONTEVIDEO","SAO PAULO","SAN JOSE")
jur_pool <- unique(paste0("AV. ", sample(c("PRINCIPAL","CENTRAL","DEL MAR","LIBERTAD","BOLIVAR",
  "INDEPENDENCIA","LAS PALMAS","OCEAN DRIVE","BRICKELL","COLON"), 6000, TRUE), " ",
  sample(1:9999, 6000, TRUE), ", ", sample(ciudades, 6000, TRUE)))[1:2602]
d[, ubicacion_jurisdiccion := ""]
d[ext_acc & runif(.N) < 44263 / 44375, ubicacion_jurisdiccion := pick(.N, jur_pool, rexp(2602) + .1)]

# porcentajes de bolsa (sociedades extranjeras)
pct_str <- function(x) sub("\\.?0+$", "", formatC(x, format = "f", digits = 2)) |>
  (\(s) ifelse(grepl("\\.", s), s, paste0(s, ".0")))()
bolsa_vals <- c(round(runif(60, 0, 100), 2), seq(5, 95, by = 2))[1:105]
d[, `:=`(porcentaje_bolsa_ext = "0.0", porcentaje_no_bolsa_ext = "0.0")]
d[tipo_accionista == "SOCIEDAD EXTRANJERA", c("porcentaje_bolsa_ext","porcentaje_no_bolsa_ext") := {
  b <- fifelse(runif(.N) < .7, 0, sample(bolsa_vals, .N, TRUE))
  b <- fifelse(runif(.N) < .1, 100, b)
  list(pct_str(b), pct_str(100 - b))
}]
d[, porcentaje_no_bolsa := "0.0"]
d[marca_soc_publica_extranjera == "SI", porcentaje_no_bolsa :=
    pick(.N, c("100.0","50.0","25.0","10.0","5.0","1.0","0.5","75.0","90.0","99.0"), c(10, 3, 2, 2, 2, 1, 1, 1, 1, 1))]

# participación: solo titulares / socios fundadores tienen % > 0;
# se reparte el total declarado (con cobertura parcial) con pesos de Dirichlet
d[, titular := tipo_relacion_accionista %in% c("TITULARES DE DERECHO","SOCIO FUNDADOR")]
d[, w := fifelse(titular, rgamma(.N, shape = 0.5), 0)]
d[, sw := sum(w), by = reg_id]
d[, porcentaje_participacion_r := fifelse(sw > 0, round(total_decl * cobertura * w / sw, 2), 0)]
d[, porcentaje_efectivo_r := porcentaje_participacion_r]

# ---- Cadenas bajo accionistas que son sociedades extranjeras (niveles 2..18) ----
# La sociedad ecuatoriana declara en su propio anexo a los dueños de su accionista extranjero,
# hasta llegar a personas naturales:
#   porcentaje_participacion_r = % dentro de la sociedad intermedia
#   porcentaje_efectivo_r      = % efectivo sobre el informante (producto de la cadena)
# 85% de los accionistas extranjeros tienen cadena; 15% de las cadenas quedan incompletas.
# Dentro de una cadena puede aparecer una sociedad ecuatoriana (se expande con su propio anexo).
cols_acc <- c("tipo_id_accionista","codigo_tipo_sociedad_ext","tipo_accionista","pais_accionista",
  "codigo_pais_accionista","pais_accionista_nac_ext","grp","id_accionista","marca_soc_publica_extranjera",
  "tipo_regimen_fiscal","paraiso_fiscal_accionista","cod_pais_rel_par_fiscal",
  "den_reg_fiscal_preferente","pais_rel_otro_regimen_fiscal","ubicacion_jurisdiccion",
  "porcentaje_bolsa_ext","porcentaje_no_bolsa_ext","porcentaje_no_bolsa")
d[, fila := .I]
don_pn  <- d[tipo_accionista == "PERSONAS NATURALES" & pais_accionista_nac_ext == 0, fila]
don_pc  <- d[tipo_id_accionista == "C", fila]
don_ext <- d[tipo_accionista == "SOCIEDAD EXTRANJERA", fila]
don_nac <- d[grp == "RS", fila]
front <- d[tipo_accionista == "SOCIEDAD EXTRANJERA" & porcentaje_participacion_r > 0 & runif(.N) < .85,
           .(raiz = fila, ef = porcentaje_participacion_r, rango)]
front[, profundo := FALSE][sample(.N, min(.N, 12)), profundo := TRUE]   # pocas cadenas muy largas
hijos <- list()
for (L in 2:18) {
  if (!nrow(front)) break
  k <- pmin(8L, 1L + rpois(nrow(front), 0.6))
  h <- front[rep(seq_len(.N), k)]
  h[, padre := rep(seq_len(nrow(front)), k)]
  h[, tipo_h := pick(.N, c("PN","EXT","NAC"), c(.78, .16, .06))]
  h[, primero := !duplicated(padre)]
  h[primero & profundo, tipo_h := "EXT"]
  h[, profundo := profundo & primero]
  h[, wsh := rgamma(.N, 0.8)]
  h[, part := round(100 * wsh / sum(wsh) * (if (runif(1) < .85) 1 else runif(1, .4, .95)), 2), by = padre]
  h[, `:=`(ef_h = ef * part / 100, nivel = L)]
  h[, donante := fcase(
    tipo_h == "PN",  fifelse(runif(.N) < .85, sample(don_pn, .N, TRUE), sample(don_pc, .N, TRUE)),
    tipo_h == "EXT", sample(don_ext, .N, TRUE),
    default = sample(don_nac, .N, TRUE))]
  hijos[[L]] <- h[, .(raiz, donante, tipo_h, part, ef_h, nivel, rango)]
  front <- h[tipo_h == "EXT", .(raiz, ef = ef_h, rango, profundo)]
}
ch <- rbindlist(hijos)
comp_cols <- setdiff(names(d), cols_acc)
nuevas <- cbind(d[ch$raiz, ..comp_cols], d[ch$donante, ..cols_acc])
nuevas[, `:=`(nivel = ch$nivel, porcentaje_participacion_r = ch$part,
              porcentaje_efectivo_r = round(ch$ef_h, 2),
              tipo_relacion_accionista = "TITULARES DE DERECHO", titular = TRUE)]
nac_idx <- which(ch$tipo_h == "NAC")
enl <- enlazar(ch$rango[nac_idx]); ok <- !is.na(enl) & runif(length(enl)) < .9
set(nuevas, nac_idx[ok], "id_accionista", enl[ok])
# mantener N: se eliminan tantas filas de administradores/directores de empresas grandes
cand <- d[nivel == 1 & !titular & nfilas > 20, fila]
stopifnot(length(cand) >= nrow(nuevas))
d <- rbind(d[!fila %in% sample(cand, nrow(nuevas))], nuevas, use.names = TRUE)
d[, nivel_aps := as.character(nivel)]

d[, total_porcentaje_participacion := total_decl]
d[, total_porcentaje_participacion_r := pmin(200, round(sum(porcentaje_participacion_r[nivel == 1]), 2)), by = reg_id]
d[, marca_participacion := fcase(
  total_porcentaje_participacion == 0, 1,
  total_porcentaje_participacion < 5, 2,
  total_porcentaje_participacion < 20, 3,
  total_porcentaje_participacion < 50, 4,
  total_porcentaje_participacion < 75, 5,
  total_porcentaje_participacion < 95, 6,
  total_porcentaje_participacion < 99.99, 7,
  total_porcentaje_participacion <= 100.01, 9,
  total_porcentaje_participacion <= 150, 8,
  default = 10)]
# (orden de etiquetas: 8 = >100%-150%, 9 = 100%, 10 = >150%)

# ---------------------------------------------------- 3. ARMAR BASE FINAL
d[, `:=`(
  codigo_anexo_aps_grp_eco = uniq_digits(.N, 10, 8e9),
  codigo_accionista_anexo  = uniq_digits(.N, 9, 6e8),
  codigo_ubicacion_residencia_f = uniq_digits(.N, 9, 2.6e8),
  anio_fiscal = "2025",
  numero_ruc = ruc, id_informante = ruc,
  codigo_pais_sociedad = fifelse(pais_sociedad == "", "", cod_pais[pais_sociedad]),
  pais_sociedad_nac_ext = as.numeric(pais_sociedad == "ECUADOR"),
  ultimo_anexo = "S", estado_carga_f = "CDEF",
  figura_juridica_ext = "",
  periodo_procesado = fifelse(registro_actual == "S", "2026", "2025"),
  obligado = "S",
  codigo_opera_actividad_eco = ciiu, CIIU_6D = ciiu, CIIU_1D = substr(ciiu, 1, 1),
  codigo_opera_parroquia = parroquia,
  ubicacion_geografica_pk = fifelse(parroquia == "", "", parr_pk[parroquia]))]
fig_pool <- sprintf("%d", sample(1:99999, 307))
d[tipo_accionista == "SOCIEDAD EXTRANJERA", figura_juridica_ext := pick(.N, fig_pool, rexp(307) + .2)]
d[, codigo_pais_sociedad := unname(codigo_pais_sociedad)]
d[, codigo_pais_accionista := unname(codigo_pais_accionista)]
d[, sector := fifelse(CIIU_1D == "", 0, unname(sec_de_letra[CIIU_1D]))]
# una única empresa informante figura como PERSONAS NATURALES
d[reg_id == d[nfilas == 1][1, reg_id], tipo_sociedad := "PERSONAS NATURALES"]

vars <- c("codigo_anexo_aps_grp_eco","codigo_registro_anexo","codigo_accionista_anexo",
  "anio_fiscal","numero_ruc","tipo_sociedad","pais_sociedad","codigo_pais_sociedad",
  "tipo_id_accionista","id_accionista","tipo_accionista","pais_accionista",
  "codigo_pais_accionista","tipo_relacion_accionista","marca_soc_publica_extranjera",
  "marca_empresa_publica","nivel_aps","ultimo_anexo","paraiso_fiscal_accionista",
  "codigo_ubicacion_residencia_f","ubicacion_jurisdiccion","cod_pais_rel_par_fiscal",
  "den_reg_fiscal_preferente","pais_rel_otro_regimen_fiscal","estado_carga_f",
  "codigo_tipo_sociedad_ext","figura_juridica_ext","porcentaje_no_bolsa_ext",
  "porcentaje_bolsa_ext","tipo_regimen_fiscal","id_informante","porcentaje_no_bolsa",
  "declaracion_anticipada","periodo_procesado","registro_actual","pais_sociedad_nac_ext",
  "pais_accionista_nac_ext","porcentaje_participacion_r","porcentaje_efectivo_r",
  "total_porcentaje_participacion","total_porcentaje_participacion_r","marca_participacion",
  "obligado","codigo_opera_actividad_eco","codigo_opera_clase_contrib",
  "codigo_opera_estado_contrib","codigoarea","codigo_opera_parroquia",
  "ubicacion_geografica_pk","CIIU_1D","CIIU_6D","sector","tipo")
d <- d[sample(.N), ..vars]
stopifnot(length(vars) == 53, nrow(d) == N)

# etiquetas (como en el original)
vlab <- c(codigo_anexo_aps_grp_eco="CODIGO_ANEXO_APS_GRP_ECO", codigo_registro_anexo="CODIGO_REGISTRO_ANEXO",
  codigo_accionista_anexo="CODIGO_ACCIONISTA_ANEXO", anio_fiscal="ANIO_FISCAL",
  numero_ruc="IDENTIFICACION_INFORMANTE", tipo_sociedad="TIPO_SOCIEDAD", pais_sociedad="PAIS_SOCIEDAD",
  codigo_pais_sociedad="CODIGO_PAIS_SOCIEDAD", tipo_id_accionista="TIPO_ID_ACCIONISTA",
  id_accionista="ID_ACCIONISTA", tipo_accionista="TIPO_ACCIONISTA", pais_accionista="PAIS_ACCIONISTA",
  codigo_pais_accionista="CODIGO_PAIS_ACCIONISTA", tipo_relacion_accionista="TIPO_RELACION_ACCIONISTA",
  marca_soc_publica_extranjera="MARCA_SOC_PUBLICA_EXTRANJERA", marca_empresa_publica="MARCA_EMPRESA_PUBLICA",
  nivel_aps="NIVEL_APS", ultimo_anexo="ULTIMO_ANEXO", paraiso_fiscal_accionista="PARAISO_FISCAL_ACCIONISTA",
  codigo_ubicacion_residencia_f="CODIGO_UBICACION_RESIDENCIA_F", ubicacion_jurisdiccion="UBICACION_JURISDICCION",
  cod_pais_rel_par_fiscal="COD_PAIS_REL_PAR_FISCAL", den_reg_fiscal_preferente="DEN_REG_FISCAL_PREFERENTE",
  pais_rel_otro_regimen_fiscal="PAIS_REL_OTRO_REGIMEN_FISCAL", estado_carga_f="ESTADO_CARGA_F",
  codigo_tipo_sociedad_ext="CODIGO_TIPO_SOCIEDAD_EXT", figura_juridica_ext="FIGURA_JURIDICA_EXT",
  porcentaje_no_bolsa_ext="PORCENTAJE_NO_BOLSA_EXT", porcentaje_bolsa_ext="PORCENTAJE_BOLSA_EXT",
  tipo_regimen_fiscal="TIPO_REGIMEN_FISCAL", id_informante="ID_INFORMANTE",
  porcentaje_no_bolsa="PORCENTAJE_NO_BOLSA", declaracion_anticipada="DECLARACION_ANTICIPADA",
  periodo_procesado="PERIODO_PROCESADO", registro_actual="REGISTRO_ACTUAL",
  pais_sociedad_nac_ext="pais_sociedad_nac_ext", pais_accionista_nac_ext="pais_accionista_nac_ext",
  marca_participacion="marca_participacion", obligado="OBLIGADO",
  codigo_opera_actividad_eco="CODIGO_OPERA_ACTIVIDAD_ECO", codigo_opera_clase_contrib="CODIGO_OPERA_CLASE_CONTRIB",
  codigo_opera_estado_contrib="CODIGO_OPERA_ESTADO_CONTRIB", codigoarea="CODIGO_OPERA_AREA",
  codigo_opera_parroquia="CODIGO_OPERA_PARROQUIA", ubicacion_geografica_pk="UBICACION_GEOGRAFICA_PK")
for (v in names(vlab)) attr(d[[v]], "label") <- vlab[[v]]
nac <- c(`Otro país` = 0, Ecuador = 1)
d[, pais_sociedad_nac_ext := labelled(pais_sociedad_nac_ext, nac, label = "pais_sociedad_nac_ext")]
d[, pais_accionista_nac_ext := labelled(pais_accionista_nac_ext, nac, label = "pais_accionista_nac_ext")]
d[, marca_participacion := labelled(marca_participacion, setNames(as.numeric(1:10),
  c("0%","0% - <5%","5% - <20%","20% - <50%","50% - <75%","75% - <95%","95% - <100%",
    ">100% - 150%","100%",">150%")), label = "marca_participacion")]
d[, sector := labelled(sector, setNames(as.numeric(0:22), sector_lbl))]

write_dta(as.data.frame(d), OUT, version = 14)
cat("Escrito:", OUT, "-", nrow(d), "obs x", ncol(d), "vars\n")

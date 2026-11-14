# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Piso, agua, servicio higiénico y electricidad por provincia, 1962-2022
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Serie de cuatro carencias de la vivienda que se pueden medir desde el censo
# de 1962. Con 1962 no se puede calcular el NBI: la muestra de IPUMS es de
# personas (3%, factor 33), no de hogares, y los datos de la vivienda solo los
# tiene el jefe. Por eso la serie es de hogares (porcentaje de hogares en
# viviendas particulares), no de personas.
#
# Fuentes: 1962 y 1974, muestras de IPUMS (extracto 2 de 05_ipums_extracto.R);
# 1982-2022, censos completos (hogares de 01_nbi_armonizado.R).
#
# Indicadores (porcentaje de hogares con la carencia):
#   - piso: de tierra u otros materiales (la regla del NBI).
#   - agua: no llega por tubería dentro de la vivienda (la parte de agua del
#     NBI). En 1962 la pregunta no distingue dentro y fuera de la vivienda:
#     se cuenta como sin carencia la tubería de uso exclusivo del hogar.
#   - ssh: letrina o sin servicio higiénico (la parte de servicio higiénico del
#     NBI, sin la eliminación de aguas servidas, que 1962 no pregunta).
#   - luz: sin electricidad de ninguna fuente.
# Los hogares sin dato en una pregunta no entran en su porcentaje.
#
# Provincias: las 19 de 1962. Galápagos va con Guayas (IPUMS lo agrupa con
# Santa Elena en 1962), Santa Elena con Guayas, Santo Domingo con Pichincha, y
# Sucumbíos y Orellana con Napo. Las zonas no delimitadas de 1982-2010 y las
# zonas en discusión de 1974 (empadronadas en Pichincha) solo entran en el
# total nacional o quedan en la provincia donde se empadronaron. La Concordia
# pasa de Esmeraldas (2010) a Pichincha (2022, por Santo Domingo).
#
# Las provincias amazónicas tienen muy pocos jefes en la muestra de 1962
# (Pastaza y Zamora Chinchipe, unos 70; Napo y Morona Santiago, 100 a 140):
# ver la columna hogares_muestra.
#
# Resultado en Resultados/NBI: servicios_provincial_1962_2022.csv
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

library(ipumsr)
options(censo.solo_funciones = TRUE)
source("01_nbi_armonizado.R")

ipums_servicios_ddi <- file.path(censo_dir, "IPUMS", "ipumsi_00002.xml")

provincias <- data.frame(
  cod = sprintf("%02d", 1:19),
  provincia = c("Azuay", "Bolívar", "Cañar", "Carchi", "Cotopaxi", "Chimborazo", "El Oro", "Esmeraldas", "Guayas",
                "Imbabura", "Loja", "Los Ríos", "Manabí", "Morona Santiago", "Napo", "Pastaza", "Pichincha",
                "Tungurahua", "Zamora Chinchipe"))
# provincia de GEO2_EC1974 (dos primeros dígitos) -> código de provincia
provincia_1974 <- c(`10` = "04", `11` = "10", `12` = "17", `13` = "05", `14` = "18", `15` = "02", `16` = "06",
                    `17` = "03", `18` = "01", `19` = "11", `20` = "08", `21` = "13", `22` = "12", `23` = "09",
                    `24` = "07", `30` = "15", `31` = "16", `32` = "14", `33` = "19")

indicadores <- c("piso", "agua", "ssh", "luz")

# Resumen de una tabla de hogares (cod, peso, piso, agua, ssh, luz): una fila
# nacional y una por provincia
servicios_resumen <- function(h, anio, muestra) {
  uno <- function(d, cod) {
    pct <- sapply(indicadores, function(v) round(100 * weighted.mean(d[[v]], d$peso, na.rm = TRUE), 1))
    data.frame(anio = anio, cod = cod, hogares = round(sum(d$peso)), hogares_muestra = if (muestra) nrow(d) else NA,
               t(setNames(pct, paste0("pct_", indicadores))))
  }
  conocida <- h[!is.na(h$cod), ]
  rbind(uno(h, "00"), do.call(rbind, lapply(split(conocida, conocida$cod), function(d) uno(d, d$cod[1]))))
}

# 1962 y 1974 (IPUMS) ----

servicios_ipums <- function(ddi = ipums_servicios_ddi) {
  x <- read_ipums_micro(ddi, verbose = FALSE)
  x <- as.data.frame(lapply(x, function(v) if (inherits(v, "haven_labelled")) as.numeric(v) else v))
  na_si <- function(v, desconocido) ifelse(v %in% desconocido, NA, v)

  # 1962: jefes con datos de vivienda; un jefe = un hogar
  a <- x[x$YEAR == 1962 & x$RELATE == 1 & x$FLOOR > 0, ]
  cod62 <- sprintf("%02d", a$GEO2_EC1962 %/% 1000)
  h62 <- data.frame(
    cod = ifelse(cod62 %in% provincias$cod, cod62, NA), peso = a$HHWT,
    piso = as.integer(na_si(a$FLOOR, 999) %in% c(100, 236)) + 0 * na_si(a$FLOOR, 999),
    agua = as.integer(na_si(a$WATSUP, c(0, 99)) != 12),
    ssh = as.integer(na_si(a$TOILET, c(0, 99)) %in% c(10, 22)) + 0 * na_si(a$TOILET, c(0, 99)),
    luz = as.integer(na_si(a$ELECTRIC, c(0, 9)) == 2))

  # 1974: un registro por hogar en vivienda particular ocupada con personas presentes
  b <- x[x$YEAR == 1974 & x$EC1974A_DWTYPE <= 8 & x$EC1974A_OCCUPAN == 1 & x$HHWT > 0, ]
  b <- b[!duplicated(b$SERIAL), ]
  h74 <- data.frame(
    cod = unname(provincia_1974[as.character(b$GEO2_EC1974 %/% 1000)]), peso = b$HHWT,
    piso = as.integer(na_si(b$EC1974A_FLOOR, c(0, 9)) %in% 5:6) + 0 * na_si(b$EC1974A_FLOOR, c(0, 9)),
    agua = as.integer(na_si(b$EC1974A_WATSUP, c(0, 9)) != 1),
    ssh = as.integer(na_si(b$EC1974A_TOILET, c(0, 9)) %in% 3:4) + 0 * na_si(b$EC1974A_TOILET, c(0, 9)),
    luz = as.integer(na_si(b$ELECTRIC, c(0, 9)) == 2))

  rbind(servicios_resumen(h62, 1962, TRUE), servicios_resumen(h74, 1974, TRUE))
}

# 1982-2022 (censos completos; requiere nbi_crear()) ----

servicios_censos <- function() {
  h <- censo_sql("
    SELECT anio, CASE
        WHEN p = '90' OR (anio = 1982 AND p = '22') THEN NULL   -- zonas no delimitadas
        WHEN p IN ('20', '24') THEN '09' WHEN p IN ('21', '22') THEN '15' WHEN p = '23' THEN '17' ELSE p END cod,
      COUNT(*) peso, COUNT(piso) n_piso, COUNT(agua) n_agua, COUNT(ssh) n_ssh, COUNT(luz) n_luz,
      SUM(piso) piso, SUM(agua) agua, SUM(ssh) ssh, SUM(luz) luz
    FROM (SELECT *, substr(dpa_censo, 1, 2) p FROM nbi_hogar) GROUP BY ALL")
  uno <- function(d, cod) data.frame(
    anio = d$anio[1], cod = cod, hogares = sum(d$peso), hogares_muestra = NA,
    pct_piso = round(100 * sum(d$piso, na.rm = TRUE) / sum(d$n_piso), 1),
    pct_agua = round(100 * sum(d$agua, na.rm = TRUE) / sum(d$n_agua), 1),
    pct_ssh = round(100 * sum(d$ssh, na.rm = TRUE) / sum(d$n_ssh), 1),
    pct_luz = round(100 * sum(d$luz, na.rm = TRUE) / sum(d$n_luz), 1))
  do.call(rbind, lapply(split(h, h$anio), function(d) {
    conocida <- d[!is.na(d$cod), ]
    rbind(uno(d, "00"), do.call(rbind, lapply(split(conocida, conocida$cod), function(z) uno(z, z$cod[1]))))
  }))
}

# Ejecución ----

if (!isTRUE(getOption("servicios.solo_funciones"))) {
  censo_conectar()
  nbi_crear()
  censos <- servicios_censos()
  censo_desconectar()
  serie <- rbind(servicios_ipums(), censos)
  serie$provincia <- ifelse(serie$cod == "00", "Nacional", provincias$provincia[match(serie$cod, provincias$cod)])
  serie <- serie[order(serie$cod, serie$anio), c("anio", "cod", "provincia", "hogares", "hogares_muestra",
                                                 paste0("pct_", indicadores))]
  write.csv(serie, file.path(resultados_dir, "servicios_provincial_1962_2022.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  print(serie[serie$cod == "00", ], row.names = FALSE)
  cat("Resultados en", resultados_dir, "\n")
}

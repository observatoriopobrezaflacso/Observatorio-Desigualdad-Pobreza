# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Extracto de IPUMS International: muestras de Ecuador 1974 y 1982
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# 1974: no hay microdatos completos del INEC; la muestra de IPUMS (10%) permite
# extender el NBI cantonal a ese censo. 1982: sirve para comparar la muestra con
# el censo completo que ya procesamos.
#
# Requiere la clave de la API en ~/.Renviron (IPUMS_API_KEY=...). La clave no
# va en el código. Los microdatos se guardan en Drive (Bases/Censo/IPUMS) y no se
# redistribuyen (condiciones de uso de IPUMS).
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

library(ipumsr)

if (Sys.getenv("IPUMS_API_KEY") == "") stop("Falta IPUMS_API_KEY en ~/.Renviron")

ipums_dir <- file.path(path.expand("~"),
                       "Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec",
                       "Mi unidad/Bases/Censo/IPUMS")

# Variables armonizadas para el NBI y la geografía ----
variables <- c(
  # identificación y pesos
  "SERIAL", "PERNUM", "HHWT", "PERWT", "PERSONS",
  # geografía: provincia, cantón armonizado y cantón de cada censo
  "GEO1_EC", "GEO2_EC", "GEO2_EC1974", "GEO2_EC1982",
  # vivienda
  "FLOOR", "WATSUP", "SEWAGE", "TOILET", "ROOMS",
  # variables originales de 1974 (paredes, dormitorios y el resto de insumos del NBI)
  paste0("EC1974A_", c("0017", "0018", "0020", "0021", "0023", "0024", "0027", "0034",
                       "0400", "0402", "0407", "0414", "0415", "0416")),
  # personas
  "RELATE", "AGE", "SCHOOL", "EDATTAIN", "YRSCHOOL", "EDUCEC", "LIT", "EMPSTAT"
)

extracto <- function(vars = variables) {
  define_extract_micro(
    collection = "ipumsi",
    description = "Boletin 5 FLACSO: NBI cantonal Ecuador 1974 y 1982",
    samples = c("ec1974a", "ec1982a"),
    variables = vars,
    data_format = "fixed_width"
  )
}

if (!isTRUE(getOption("ipums.solo_funciones"))) {
  ext <- submit_extract(extracto())
  cat("Extracto enviado:", ext$number, "\n")
  ext <- wait_for_extract(ext)
  dir.create(ipums_dir, showWarnings = FALSE, recursive = TRUE)
  ddi <- download_extract(ext, download_dir = ipums_dir)
  cat("Descargado:", ddi, "\n")
}

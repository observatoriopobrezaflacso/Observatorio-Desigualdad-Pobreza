# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Crear bases duckdb de los censos 1982, 1990, 2001, 2010 y 2022 (ejecutar una vez)
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Cada censo queda en Censo/<anio>/censo<anio>.duckdb. La tabla de personas
# se llama censo<anio>
# y las demás censo<anio>_<tipo>. Además se guardan dos tablas de metadatos:
#   diccionario (tabla, variable, etiqueta)        etiquetas de variable SPSS
#   etiquetas   (tabla, variable, valor, etiqueta) etiquetas de valor SPSS
#
# Cada tabla tiene una columna fila con el orden original del .sav.
# Los valores se guardan como códigos (como en el csv de 2022), incluidos los
# missing definidos por el usuario en SPSS (p. ej. 99 = "No responde").
# Los .sav se leen por bloques de filas para no agotar la memoria.
# Para consultar las bases usar censo_duckdb.R

library(DBI)
library(duckdb)
library(haven)

# directorio de trabajo: Boletín 5/Procesamiento/Codigos
if (!exists("censo_dir")) source("censo_duckdb.R")

# Archivos fuente por censo: nombre de tabla = archivo .sav (o .zip con un .sav)
censo_fuentes <- list(
  `1982` = c(censo1982                   = "CPV1982_Poblacion.sav",
             censo1982_vivienda          = "CPV1982_Vivienda.SAV"),
  `1990` = c(censo1990                   = "CPV_POBLAC.sav",
             censo1990_vivienda_hogar    = "CPV_VIVHOG.sav",
             censo1990_poblacion_trabajo = "CPV_POBLAC_TRABA.sav"),
  `2001` = c(censo2001                   = "CPV_POBLAC.sav",
             censo2001_hogar             = "CPV_HOGAR.sav",
             censo2001_vivienda          = "CPV_VIVIEN.sav",
             censo2001_emigrantes        = "CPV_MIGRAN.sav"),
  `2010` = c(censo2010                   = "CPV2010S_SPSS_Poblacion.zip",
             censo2010_hogar             = "CPV2010S_SPSS_Hogar.zip",
             censo2010_vivienda          = "CPV2010S_SPSS_Vivienda.zip",
             censo2010_emigrantes        = "CPV2010S_SPSS_Emigrantes.zip"),
  `2022` = c(censo2022                   = "CPV_2022_Poblacion_Sector.sav",
             censo2022_vivienda          = "CPV_2022_Vivienda_Sector.sav",
             censo2022_hogar             = "CPV_2022_Hogar_Sector.sav",
             censo2022_emigrantes        = "CPV_2022_Emigracion_Sector.sav",
             censo2022_mortalidad        = "CPV_2022_Mortalidad_Sector.sav")
)

# Funciones ----

# Si la fuente es un .zip, extrae el .sav a una carpeta temporal local
censo_extraer_sav <- function(archivo, tmp) {
  if (!grepl("\\.zip$", archivo, ignore.case = TRUE)) return(archivo)
  sav <- grep("\\.sav$", unzip(archivo, list = TRUE)$Name,
              ignore.case = TRUE, value = TRUE)
  if (length(sav) != 1) stop("Se esperaba un .sav en ", archivo)
  # unzip del sistema: el interno de R no abre zip > 4 GB (Población 2010)
  unzip(archivo, files = sav, exdir = tmp, unzip = Sys.which("unzip"))
  file.path(tmp, sav)
}

censo_metadatos_sav <- function(meta, tabla) {
  dicc <- data.frame(
    tabla = tabla,
    variable = names(meta),
    etiqueta = vapply(meta, function(x) {
      l <- attr(x, "label", exact = TRUE)
      if (is.null(l)) NA_character_ else as.character(l)
    }, character(1)),
    row.names = NULL
  )
  etiq <- do.call(rbind, lapply(names(meta), function(v) {
    l <- attr(meta[[v]], "labels", exact = TRUE)
    if (is.null(l) || !length(l)) return(NULL)
    data.frame(tabla = tabla, variable = v, valor = as.character(unname(l)),
               etiqueta = names(l), row.names = NULL)
  }))
  if (is.null(etiq)) {
    etiq <- data.frame(tabla = character(), variable = character(),
                       valor = character(), etiqueta = character())
  }
  list(diccionario = dicc, etiquetas = etiq)
}

# Quita etiquetas y formatos SPSS: deja códigos numéricos o texto
censo_limpiar_bloque <- function(df) {
  df[] <- lapply(df, function(x) {
    x <- zap_labels(x, user_na = TRUE)
    if (inherits(x, c("Date", "POSIXct", "hms"))) return(zap_formats(zap_label(x)))
    attributes(x) <- NULL
    x
  })
  as.data.frame(df)
}

# Copia un .sav a una tabla duckdb, por bloques de `bloque` filas
censo_sav_a_duckdb <- function(con, sav, tabla, bloque = 1e6, encoding = NULL) {
  meta <- read_sav(sav, n_max = 0, user_na = TRUE, encoding = encoding)
  metadatos <- censo_metadatos_sav(meta, tabla)

  if (dbExistsTable(con, tabla)) dbRemoveTable(con, tabla)
  n <- 0
  repeat {
    df <- read_sav(sav, skip = n, n_max = bloque, user_na = TRUE, encoding = encoding)
    if (nrow(df) == 0) break
    df <- censo_limpiar_bloque(df)
    # fila = orden en el .sav; en 2001 es la única forma de unir personas,
    # hogares y viviendas (no hay manzana y NUMVIV se repite)
    df <- cbind(fila = n + seq_len(nrow(df)), df)
    if (n == 0) dbCreateTable(con, tabla, df)
    duckdb::duckdb_register(con, "bloque_tmp", df)
    dbExecute(con, sprintf("INSERT INTO %s SELECT * FROM bloque_tmp",
                           dbQuoteIdentifier(con, tabla)))
    duckdb::duckdb_unregister(con, "bloque_tmp")
    n <- n + nrow(df)
    message(sprintf("  %s: %s filas", tabla, format(n, big.mark = ",")))
    rm(df); gc(verbose = FALSE)
    if (n %% bloque != 0) break
  }

  for (m in names(metadatos)) {
    dbExecute(con, sprintf("DELETE FROM %s WHERE tabla = ?", m), params = list(tabla))
    dbAppendTable(con, m, metadatos[[m]])
  }
  invisible(n)
}

# Crea Censo/<anio>/censo<anio>.duckdb. La base se arma en una carpeta temporal local
# y luego se copia a Drive (duckdb escribe mal sobre carpetas sincronizadas).
censo_crear_base <- function(anio, fuentes = censo_fuentes[[as.character(anio)]],
                             dir = censo_dir, sobrescribir = FALSE,
                             bloque = 1e6, encoding = NULL) {
  destino <- censo_archivo(anio, dir)
  if (file.exists(destino) && !sobrescribir) {
    message("Ya existe ", destino, " (use sobrescribir = TRUE)")
    return(invisible(destino))
  }

  tmp <- tempfile(paste0("censo", anio, "_"))
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  db_tmp <- file.path(tmp, basename(destino))

  con <- dbConnect(duckdb::duckdb(), dbdir = db_tmp)
  dbExecute(con, "CREATE TABLE diccionario (tabla VARCHAR, variable VARCHAR, etiqueta VARCHAR)")
  dbExecute(con, "CREATE TABLE etiquetas (tabla VARCHAR, variable VARCHAR, valor VARCHAR, etiqueta VARCHAR)")

  for (tabla in names(fuentes)) {
    message("Censo ", anio, " -> ", tabla)
    sav <- censo_extraer_sav(file.path(dir, anio, fuentes[[tabla]]), tmp)
    censo_sav_a_duckdb(con, sav, tabla, bloque = bloque, encoding = encoding)
    if (dirname(sav) == tmp) unlink(sav)
  }
  dbExecute(con, "CHECKPOINT")
  dbDisconnect(con, shutdown = TRUE)

  dir.create(dirname(destino), showWarnings = FALSE, recursive = TRUE)
  if (!file.copy(db_tmp, destino, overwrite = TRUE)) stop("No se pudo copiar a ", destino)
  message("Creada ", destino)
  invisible(destino)
}

# Ejecución ----
# options(censo.solo_funciones = TRUE) antes de source() para cargar solo las funciones

if (!isTRUE(getOption("censo.solo_funciones"))) {
  for (anio in names(censo_fuentes)) censo_crear_base(anio)
}

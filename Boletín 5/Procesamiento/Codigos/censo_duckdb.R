# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Acceso a los censos de población y vivienda (1982-2022) con duckdb
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Cada censo vive en su propia base: Censo/<anio>/censo<anio>.duckdb
# (se crean con 00_crear_bases_censo.R).
# censo_conectar() las adjunta en modo solo lectura y crea vistas con el
# nombre de cada tabla, así se pueden consultar todas con SQL directo:
#
#   source("censo_duckdb.R")
#   censo_conectar()                        # o censo_conectar(c(2010, 2022))
#   censo_tablas()                          # tablas disponibles
#   censo_variables("censo2010", "edad")    # busca por nombre o etiqueta
#   censo_etiquetas("censo2010", "P01")     # códigos de una variable
#   censo_sql("SELECT P01, COUNT(*) AS n FROM censo2010 GROUP BY P01")
#   censo_desconectar()
#
# Tablas: censo<anio> es la de personas; las demás son censo<anio>_<tipo>
# (vivienda, hogar, emigrantes...). Los valores se guardan como códigos
# numéricos; las etiquetas SPSS quedan en las tablas diccionario y etiquetas.

library(DBI)
library(duckdb)

censo_dir <- Sys.getenv(
  "CENSO_DIR",
  file.path(path.expand("~"),
            "Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec",
            "Mi unidad/Bases/Censo")
)

censo_anios <- c(1982, 1990, 2001, 2010, 2022)

.censo <- new.env()

# Archivo de la base de un censo
censo_archivo <- function(anio, dir = censo_dir) {
  file.path(dir, anio, paste0("censo", anio, ".duckdb"))
}

# Conexión ----

censo_conectar <- function(anios = censo_anios, dir = censo_dir) {
  censo_desconectar()
  # base en memoria; los censos se adjuntan en solo lectura (acceso concurrente)
  con <- dbConnect(duckdb::duckdb())

  for (a in anios) {
    db <- censo_archivo(a, dir)
    if (!file.exists(db)) stop("No existe la base del censo ", a, ": ", db)
    catalogo <- paste0("c", a)
    dbExecute(con, sprintf("ATTACH %s AS %s (READ_ONLY)",
                           dbQuoteString(con, db), catalogo))

    tablas <- dbGetQuery(con, sprintf(
      "SELECT table_name FROM information_schema.tables
       WHERE table_catalog = '%s' AND table_schema = 'main'", catalogo))$table_name

    for (t in setdiff(tablas, c("diccionario", "etiquetas"))) {
      dbExecute(con, sprintf("CREATE VIEW %s AS SELECT * FROM %s.main.%s",
                             dbQuoteIdentifier(con, t), catalogo,
                             dbQuoteIdentifier(con, t)))
    }
  }

  .censo$con <- con
  .censo$anios <- anios
  .censo$metadatos <- censo_metadatos_vistas(con, anios)
  invisible(con)
}

censo_desconectar <- function() {
  if (!is.null(.censo$con) && dbIsValid(.censo$con)) {
    dbDisconnect(.censo$con, shutdown = TRUE)
  }
  .censo$con <- NULL
  invisible(TRUE)
}

censo_con <- function() {
  if (is.null(.censo$con) || !dbIsValid(.censo$con)) {
    stop("No hay conexión: ejecute censo_conectar() primero")
  }
  .censo$con
}

# Une diccionario y etiquetas de todos los censos en dos vistas.
# El censo 2022 no tiene diccionario SPSS: sus variables salen sin etiqueta.
censo_metadatos_vistas <- function(con, anios) {
  con_meta <- Filter(function(a) {
    nrow(dbGetQuery(con, sprintf(
      "SELECT 1 FROM information_schema.tables
       WHERE table_catalog = 'c%d' AND table_name = 'diccionario'", a))) > 0
  }, anios)

  dicc <- if (length(con_meta)) {
    paste(sprintf("SELECT * FROM c%d.main.diccionario", con_meta), collapse = " UNION ALL ")
  } else {
    "SELECT NULL::VARCHAR AS tabla, NULL::VARCHAR AS variable, NULL::VARCHAR AS etiqueta LIMIT 0"
  }
  etiq <- if (length(con_meta)) {
    paste(sprintf("SELECT * FROM c%d.main.etiquetas", con_meta), collapse = " UNION ALL ")
  } else {
    "SELECT NULL::VARCHAR AS tabla, NULL::VARCHAR AS variable,
            NULL::VARCHAR AS valor, NULL::VARCHAR AS etiqueta LIMIT 0"
  }

  dbExecute(con, paste("CREATE VIEW diccionario AS", dicc))
  dbExecute(con, paste("CREATE VIEW etiquetas AS", etiq))
  con_meta
}

# Consultas ----

# Ejecuta SQL sobre los censos conectados. params para consultas con ?
censo_sql <- function(sql, params = NULL) {
  dbGetQuery(censo_con(), sql, params = params)
}

censo_tablas <- function() {
  censo_sql("
    SELECT t.table_name AS tabla,
           CAST(regexp_extract(t.table_name, 'censo(\\d{4})', 1) AS INTEGER) AS anio,
           COUNT(c.column_name) AS n_variables
    FROM information_schema.tables t
    JOIN information_schema.columns c
      ON c.table_catalog = t.table_catalog AND c.table_name = t.table_name
    WHERE t.table_catalog = current_database() AND t.table_type = 'VIEW'
      AND t.table_name LIKE 'censo%'
    GROUP BY ALL
    ORDER BY anio, tabla
  ")
}

# Variables de una tabla (o de todas), con su tipo y etiqueta.
# buscar: texto que se busca (sin distinguir mayúsculas) en el nombre o la etiqueta
censo_variables <- function(tabla = NULL, buscar = NULL) {
  sql <- "
    SELECT c.table_name AS tabla, c.column_name AS variable,
           c.data_type AS tipo, d.etiqueta
    FROM information_schema.columns c
    LEFT JOIN diccionario d
      ON d.tabla = c.table_name AND d.variable = c.column_name
    WHERE c.table_catalog = current_database() AND c.table_name LIKE 'censo%'"
  params <- list()
  if (!is.null(tabla)) {
    sql <- paste(sql, "AND c.table_name = ?")
    params <- c(params, tabla)
  }
  if (!is.null(buscar)) {
    sql <- paste(sql, "AND (c.column_name ILIKE ? OR d.etiqueta ILIKE ?)")
    params <- c(params, rep(paste0("%", buscar, "%"), 2))
  }
  sql <- paste(sql, "ORDER BY c.table_name, c.ordinal_position")
  censo_sql(sql, if (length(params)) params)
}

# Códigos y etiquetas de valor de una variable (de SPSS)
censo_etiquetas <- function(tabla, variable) {
  censo_sql("
    SELECT valor, etiqueta FROM etiquetas
    WHERE tabla = ? AND variable = ?
    ORDER BY TRY_CAST(valor AS DOUBLE), valor",
    params = list(tabla, variable))
}

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Pobreza por NBI por cantón armonizado y mapas (1982-2022)
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Usa el NBI armonizado (01_nbi_armonizado.R) y las unidades cantonales
# armonizadas (02_cantones_armonizados.R, archivo cantones_armonizados.csv).
#
# Límites: parroquias del INEC 2024 (HDX, "Ecuador - Subnational Administrative
# Boundaries", licencia CC BY-IGO). Coinciden con las 1.042 parroquias del censo
# 2022. Cada unidad es la unión de sus parroquias de 2022; Manga del Cura se
# separa de El Carmen con sus dos parroquias. Si no existe el archivo de
# unidades (cantones_armonizados.gpkg), se descargan los límites y se arma.
#
# Resultados en Resultados/NBI: nbi_cantonal_armonizado.csv,
# cantones_armonizados.gpkg y mapa_nbi_cantonal.png
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

library(sf)
library(ggplot2)
options(censo.solo_funciones = TRUE)
source("01_nbi_armonizado.R")
source("02_cantones_armonizados.R")

limites_url <- paste0("https://data.humdata.org/dataset/ab3c7592-3b0c-41cd-999a-2919a6b243f2/",
                      "resource/d00145f6-141c-4bf2-a881-c32341ddec75/download/ecu_adm_2024.zip")
unidades_gpkg <- file.path(resultados_dir, "cantones_armonizados.gpkg")

# NBI por unidad ----

nbi_cantonal <- function(cw) {
  con <- censo_con()
  duckdb::duckdb_register(con, "cantones", cw[, c("anio", "parroquia", "unidad", "nombre_unidad")])
  dbExecute(con, "CREATE OR REPLACE TEMP VIEW nbi_hogar_cantonal AS
    SELECT h.*, c.unidad, c.nombre_unidad FROM nbi_hogar h
    JOIN cantones c ON c.anio = h.anio AND c.parroquia = h.dpa_censo
    WHERE c.unidad <> 'excluida'")
  sin <- censo_sql("SELECT h.anio, COUNT(*) hogares FROM nbi_hogar h
    LEFT JOIN cantones c ON c.anio = h.anio AND c.parroquia = h.dpa_censo
    WHERE c.unidad IS NULL GROUP BY 1")
  if (nrow(sin)) { message("Hogares sin unidad:"); print(sin) }
  nbi_resumen(c("unidad", "nombre_unidad"), desde = "nbi_hogar_cantonal")
}

# Polígonos de las unidades ----

unidades_poligonos <- function(cw, shp = Sys.getenv("INEC_ADM3")) {
  if (shp == "") {
    tmp <- tempfile("limites_"); dir.create(tmp)
    zip <- file.path(tmp, "ecu_adm_2024.zip")
    download.file(limites_url, zip, mode = "wb")
    unzip(zip, files = paste0("ecu_adm_adm3_2024.", c("shp", "shx", "dbf", "prj", "cpg")), exdir = tmp)
    shp <- file.path(tmp, "ecu_adm_adm3_2024.shp")
  }
  p <- st_read(shp, quiet = TRUE)
  p$parroquia <- substr(p$ADM3_PCODE, 3, 8)
  u22 <- cw[cw$anio == 2022, c("parroquia", "unidad", "nombre_unidad")]
  falta <- setdiff(u22$parroquia, p$parroquia)
  if (length(falta)) stop("Parroquias de 2022 sin polígono: ", paste(falta, collapse = ", "))
  p <- merge(p[, "parroquia"], u22, by = "parroquia")
  # UTM 17S; se unen las parroquias con su detalle completo (los bordes
  # compartidos coinciden) y después se simplifica cada unidad
  p <- st_make_valid(st_transform(p, 32717))
  u <- do.call(rbind, lapply(split(p, p$unidad), function(d) {
    st_sf(unidad = d$unidad[1], nombre_unidad = d$nombre_unidad[1], geometry = st_union(d))
  }))
  u <- st_simplify(u, preserveTopology = TRUE, dTolerance = 250)
  st_write(u, unidades_gpkg, delete_dsn = TRUE, quiet = TRUE)
  u
}

# Mapa ----

# Galápagos se acerca al continente para el mapa
acercar_galapagos <- function(u) {
  gal <- grepl("^U20", u$unidad)
  bc <- st_bbox(u[!gal, ]); bg <- st_bbox(u[gal, ])
  desp <- unname(c(bc["xmin"] - 60000 - bg["xmax"], bc["ymax"] - 150000 - bg["ymax"]))
  geo <- st_geometry(u)
  movida <- geo[gal] + desp
  st_crs(movida) <- st_crs(u)
  geo[gal] <- movida
  st_geometry(u) <- geo
  u
}

nbi_mapa <- function(nbi, u, archivo) {
  u <- acercar_galapagos(u)
  anios <- sort(unique(nbi$anio))
  d <- do.call(rbind, lapply(anios, function(a) {
    x <- merge(u, nbi[nbi$anio == a, c("unidad", "pct_nbi")], by = "unidad", all.x = TRUE)
    x$anio <- a; x
  }))
  cortes <- c(0, 20, 40, 60, 80, 100)
  d$clase <- cut(d$pct_nbi, cortes, include.lowest = TRUE,
                 labels = c("0-20", "20-40", "40-60", "60-80", "80-100"))
  d$clase <- addNA(d$clase); levels(d$clase)[is.na(levels(d$clase))] <- "Sin dato"
  colores <- c("0-20" = "#b7d3f6", "20-40" = "#6da7ec", "40-60" = "#2a78d6",
               "60-80" = "#1c5cab", "80-100" = "#0d366b", "Sin dato" = "#e4e3df")
  bg <- st_bbox(u[grepl("^U20", u$unidad), ])
  marco <- st_as_sfc(st_bbox(c(bg["xmin"] - 20000, bg["ymin"] - 20000, bg["xmax"] + 20000, bg["ymax"] + 20000),
                             crs = st_crs(u)))
  g <- ggplot(d) +
    geom_sf(aes(fill = clase), colour = "white", linewidth = 0.08) +
    geom_sf(data = marco, fill = NA, colour = "#b5b4ad", linewidth = 0.2) +
    facet_wrap(~anio, nrow = 2, ncol = 3) +
    scale_fill_manual(values = colores, name = "Personas pobres por NBI (%)", drop = FALSE) +
    labs(title = "Pobreza por necesidades básicas insatisfechas por cantón, 1982-2022",
         subtitle = "Cantones armonizados: los cantones que se dividieron entre censos forman una sola unidad",
         caption = paste("Fuente: INEC, Censos de Población y Vivienda 1982-2022; límites INEC 2024 (HDX).",
                         "Elaboración propia. Galápagos desplazado.",
                         "Sin dato: zonas no delimitadas en 1982 y Alausí en 1982 (base incompleta).", sep = "\n")) +
    theme_void(base_family = "Arial", base_size = 10) +
    theme(legend.position = "inside", legend.position.inside = c(0.84, 0.25), legend.title.position = "top",
          strip.text = element_text(face = "bold", size = 11, margin = margin(b = 4)),
          plot.title = element_text(face = "bold", size = 13), plot.subtitle = element_text(colour = "#52514e"),
          plot.caption = element_text(colour = "#52514e", size = 7.5, hjust = 0),
          plot.background = element_rect(fill = "white", colour = NA), plot.margin = margin(10, 10, 10, 10)) +
    guides(fill = guide_legend(ncol = 1, keywidth = unit(0.8, "cm"), keyheight = unit(0.5, "cm")))
  ggsave(archivo, g, width = 10, height = 6.6, dpi = 220)
  invisible(g)
}

# Ejecución ----

if (!isTRUE(getOption("nbi_mapa.solo_funciones"))) {
  cw <- read.csv(cantones_archivo, colClasses = c(parroquia = "character", canton = "character"), encoding = "UTF-8")
  censo_conectar()
  nbi_crear()
  nbi <- nbi_cantonal(cw)
  censo_desconectar()
  write.csv(nbi, file.path(resultados_dir, "nbi_cantonal_armonizado.csv"), row.names = FALSE, fileEncoding = "UTF-8")

  u <- if (file.exists(unidades_gpkg)) st_read(unidades_gpkg, quiet = TRUE) else unidades_poligonos(cw)
  nbi_mapa(nbi, u, file.path(resultados_dir, "mapa_nbi_cantonal.png"))
  cat("Resultados en", resultados_dir, "\n")
}

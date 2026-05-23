# ==============================================================================
# PROCESAMIENTO ENEMDU DICIEMBRES - Indicadores de Pobreza para Tableau
# ==============================================================================
# Genera 5 archivos Excel en formato largo para visualización en Tableau
# Datos: ENEMDU diciembre 2007-2024
# Indicadores disponibles: Pobreza por ingresos, Pobreza extrema
# Nota: NBI y Pobreza multidimensional NO están disponibles en estas bases
# ==============================================================================

library(tidyverse)
library(haven)
library(survey)
library(writexl)

# --- Configuración -----------------------------------------------------------
base_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Boletín 1/Procesamiento/Bases/enemdu_diciembres"
output_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Dashboards/Data final"

dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

anio_min <- 2007

# Diccionario de provincias
prov_labels <- c(
  "1" = "Azuay", "2" = "Bolívar", "3" = "Cañar", "4" = "Carchi",
  "5" = "Cotopaxi", "6" = "Chimborazo", "7" = "El Oro", "8" = "Esmeraldas",
  "9" = "Guayas", "10" = "Imbabura", "11" = "Loja", "12" = "Los Ríos",
  "13" = "Manabí", "14" = "Morona Santiago", "15" = "Napo", "16" = "Pastaza",
  "17" = "Pichincha", "18" = "Tungurahua", "19" = "Zamora Chinchipe",
  "20" = "Galápagos", "21" = "Sucumbíos", "22" = "Orellana",
  "23" = "Santo Domingo de los Tsáchilas", "24" = "Santa Elena",
  "90" = "Zonas No Delimitadas"
)

# --- 1. Identificar y cargar archivos ----------------------------------------
archivos <- list.files(base_path, pattern = "^empleo\\d{4}\\.dta$", full.names = TRUE)
anios <- as.integer(str_extract(basename(archivos), "\\d{4}"))
archivos <- archivos[anios >= anio_min]
anios <- anios[anios >= anio_min]

cat("Archivos a procesar:", length(archivos), "\n")
cat("Años:", paste(sort(anios), collapse = ", "), "\n\n")

# --- 2. Cargar y consolidar --------------------------------------------------
cargar_base <- function(archivo, anio) {
  cat("Cargando", anio, "...")
  d <- read_dta(archivo)

  # Seleccionar y homogeneizar variables
  vars_base <- c("p02", "p15", "fexp", "pobreza", "epobreza")

  # Verificar que todas las variables existen
  vars_faltantes <- setdiff(vars_base, names(d))
  if (length(vars_faltantes) > 0) {
    cat(" ADVERTENCIA: faltan variables:", paste(vars_faltantes, collapse = ", "), "\n")
    return(NULL)
  }

  # Provincia: usar prov si existe, derivar de ciudad si no
  if ("prov" %in% names(d)) {
    d$provincia_cod <- as.integer(d$prov)
  } else if ("ciudad" %in% names(d)) {
    d$provincia_cod <- as.integer(substr(sprintf("%06d", as.integer(d$ciudad)), 1, 2))
  } else {
    d$provincia_cod <- NA_integer_
    cat(" ADVERTENCIA: sin variable de provincia\n")
  }

  resultado <- d %>%
    select(all_of(vars_base), provincia_cod) %>%
    mutate(
      anio = anio,
      # Estandarizar sexo
      sexo = case_when(
        as.integer(p02) == 1 ~ "Hombre",
        as.integer(p02) == 2 ~ "Mujer",
        TRUE ~ NA_character_
      ),
      # Estandarizar etnia
      etnia = case_when(
        as.integer(p15) == 1 ~ "Indígena",
        as.integer(p15) == 2 ~ "Afroecuatoriano",
        as.integer(p15) == 3 ~ "Negro",
        as.integer(p15) == 4 ~ "Mulato",
        as.integer(p15) == 5 ~ "Montubio",
        as.integer(p15) == 6 ~ "Mestizo",
        as.integer(p15) == 7 ~ "Blanco",
        as.integer(p15) == 8 ~ "Otro",
        TRUE ~ NA_character_
      ),
      # Indicadores binarios (0 = no pobre, 1 = pobre, NA = missing)
      es_pobre = as.integer(pobreza),
      es_extremo = as.integer(epobreza),
      # Provincia etiqueta
      provincia = prov_labels[as.character(provincia_cod)],
      peso = as.numeric(fexp)
    ) %>%
    select(anio, sexo, etnia, provincia_cod, provincia, es_pobre, es_extremo, peso)

  cat(" OK (", nrow(resultado), "obs)\n")
  return(resultado)
}

datos <- map2_dfr(archivos, anios, cargar_base)

cat("\nDataset consolidado:", nrow(datos), "observaciones,",
    length(unique(datos$anio)), "años\n")

# --- Validaciones básicas ----------------------------------------------------
cat("\n--- Validaciones ---\n")
cat("Años:", paste(sort(unique(datos$anio)), collapse = ", "), "\n")
cat("Missings pobreza:", sum(is.na(datos$es_pobre)),
    "(", round(100*mean(is.na(datos$es_pobre)), 2), "%)\n")
cat("Missings sexo:", sum(is.na(datos$sexo)),
    "(", round(100*mean(is.na(datos$sexo)), 2), "%)\n")
cat("Missings etnia:", sum(is.na(datos$etnia)),
    "(", round(100*mean(is.na(datos$etnia)), 2), "%)\n")
cat("Missings provincia:", sum(is.na(datos$provincia)),
    "(", round(100*mean(is.na(datos$provincia)), 2), "%)\n")

# --- 3. Calcular indicadores con ponderaciones -------------------------------

# Función auxiliar: media ponderada segura
wmean_safe <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (sum(ok) == 0) return(NA_real_)
  weighted.mean(x[ok], w[ok]) * 100
}

# --- A. Scorecards (último año disponible) ------------------------------------
cat("\n--- Generando scorecards ---\n")
ultimo_anio <- max(datos$anio)

scorecards <- datos %>%
  filter(anio == ultimo_anio) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso)
  ) %>%
  pivot_longer(everything(), names_to = "indicador", values_to = "valor") %>%
  mutate(anio = ultimo_anio) %>%
  select(anio, indicador, valor)

cat("Scorecards OK - Año:", ultimo_anio, "\n")
print(scorecards)

# --- B. Series históricas ----------------------------------------------------
cat("\n--- Generando series históricas ---\n")

series <- datos %>%
  group_by(anio) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso),
    .groups = "drop"
  ) %>%
  pivot_longer(-anio, names_to = "indicador", values_to = "valor") %>%
  arrange(indicador, anio)

cat("Series históricas OK -", nrow(series), "filas\n")

# --- C. Indicadores por sexo y etnia -----------------------------------------
cat("\n--- Generando indicadores por sexo y etnia ---\n")

ind_sexo_etnia <- datos %>%
  filter(!is.na(sexo), !is.na(etnia)) %>%
  group_by(anio, sexo, etnia) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso),
    .groups = "drop"
  ) %>%
  pivot_longer(c(Pobreza, `Pobreza extrema`),
               names_to = "indicador", values_to = "valor")

cat("Indicadores sexo/etnia OK -", nrow(ind_sexo_etnia), "filas\n")

# --- D. Mapa de pobreza provincial -------------------------------------------
cat("\n--- Generando pobreza provincial ---\n")

pobreza_prov <- datos %>%
  filter(!is.na(provincia), provincia != "Zonas No Delimitadas") %>%
  group_by(anio, provincia) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso),
    .groups = "drop"
  ) %>%
  pivot_longer(c(Pobreza, `Pobreza extrema`),
               names_to = "indicador", values_to = "valor") %>%
  arrange(anio, provincia, indicador)

cat("Pobreza provincial OK -", nrow(pobreza_prov), "filas,",
    length(unique(pobreza_prov$provincia)), "provincias\n")

# --- E. Pobreza por sexo y por etnia (formato separado) ----------------------
cat("\n--- Generando pobreza por sexo y etnia (formato grupo) ---\n")

pob_sexo <- datos %>%
  filter(!is.na(sexo)) %>%
  group_by(anio, grupo = sexo) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso),
    .groups = "drop"
  ) %>%
  mutate(tipo_grupo = "sexo")

pob_etnia <- datos %>%
  filter(!is.na(etnia)) %>%
  group_by(anio, grupo = etnia) %>%
  summarise(
    Pobreza = wmean_safe(es_pobre, peso),
    `Pobreza extrema` = wmean_safe(es_extremo, peso),
    .groups = "drop"
  ) %>%
  mutate(tipo_grupo = "etnia")

pobreza_sexo_etnia <- bind_rows(pob_sexo, pob_etnia) %>%
  pivot_longer(c(Pobreza, `Pobreza extrema`),
               names_to = "indicador", values_to = "valor") %>%
  select(anio, grupo, tipo_grupo, indicador, valor) %>%
  arrange(tipo_grupo, anio, grupo, indicador)

cat("Pobreza sexo/etnia OK -", nrow(pobreza_sexo_etnia), "filas\n")

# --- 4. Exportar archivos Excel ----------------------------------------------
cat("\n--- Exportando archivos Excel ---\n")

write_xlsx(scorecards, file.path(output_path, "scorecards_indicadores.xlsx"))
cat("  scorecards_indicadores.xlsx\n")

write_xlsx(series, file.path(output_path, "series_historicas_indicadores.xlsx"))
cat("  series_historicas_indicadores.xlsx\n")

write_xlsx(ind_sexo_etnia, file.path(output_path, "indicadores_sexo_etnia.xlsx"))
cat("  indicadores_sexo_etnia.xlsx\n")

write_xlsx(pobreza_prov, file.path(output_path, "pobreza_provincial.xlsx"))
cat("  pobreza_provincial.xlsx\n")

write_xlsx(pobreza_sexo_etnia, file.path(output_path, "pobreza_sexo_etnia.xlsx"))
cat("  pobreza_sexo_etnia.xlsx\n")

# --- Resumen final -----------------------------------------------------------
cat("\n===== RESUMEN FINAL =====\n")
cat("Años procesados:", paste(sort(unique(datos$anio)), collapse = ", "), "\n")
cat("Total observaciones:", format(nrow(datos), big.mark = ","), "\n")
cat("Archivos generados en:", output_path, "\n")
cat("  1. scorecards_indicadores.xlsx\n")
cat("  2. series_historicas_indicadores.xlsx\n")
cat("  3. indicadores_sexo_etnia.xlsx\n")
cat("  4. pobreza_provincial.xlsx\n")
cat("  5. pobreza_sexo_etnia.xlsx\n")
cat("\nNOTA TÉCNICA:\n")
cat("  - NBI y Pobreza Multidimensional NO están disponibles en las bases ENEMDU.\n")
cat("  - Estas bases contienen solo pobreza por ingresos y pobreza extrema\n")
cat("    (precalculadas por INEC).\n")
cat("  - Para NBI se requieren variables de vivienda/servicios del Censo o ENIGHUR.\n")
cat("  - Los indicadores fueron calculados con factores de expansión (fexp).\n")
cat("========================\n")

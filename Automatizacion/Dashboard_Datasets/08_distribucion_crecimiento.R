# ============================================================================
# Script: Generate Growth Distribution Datasets from ENEMDU
# Purpose: Growth incidence curves (GIC) and employment growth by sector
# Reference: Based on Boletín 1/Procesamiento/Codigos/GIC methodology
# Output: crecimiento_deciles.xlsx, crecimiento_empleo_sector.xlsx
# ============================================================================

library(haven)
library(dplyr)
library(writexl)

# Paths
enemdu_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Procesamiento/Bases/ENEMDU/ENEMDU - copia"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

# ========== Growth Incidence Curves (GIC) by Deciles ==========
# Following methodology from GIC/IGC base 1991.do
# Calculate growth by percentile/decile between political periods

# Key periods for Ecuador (based on existing GIC code):
# 2000-2006: Early dollarization
# 2007-2017: Correísmo
# 2017-2021: Moreno
# 2021-2024: Lasso/Noboa

periods <- list(
  list(inicio = 2007, fin = 2017, nombre = "2007-2017 (Correísmo)"),
  list(inicio = 2017, fin = 2021, nombre = "2017-2021 (Moreno)"),
  list(inicio = 2021, fin = 2024, nombre = "2021-2024 (Lasso/Noboa)"),
  list(inicio = 2007, fin = 2024, nombre = "2007-2024 (Completo)")
)

gic_all <- list()

for (period in periods) {
  year_ini <- period$inicio
  year_fin <- period$fin

  cat("Processing GIC for period:", period$nombre, "\n")

  # Read initial year
  file_ini <- file.path(enemdu_path, "Merged", paste0(year_ini, "_12_merged.dta"))
  file_fin <- file.path(enemdu_path, "Merged", paste0(year_fin, "_12_merged.dta"))

  if (file.exists(file_ini) && file.exists(file_fin)) {
    # Initial year
    df_ini <- read_dta(file_ini) %>%
      filter(!is.na(ingrl) & ingrl > 0) %>%
      mutate(ingreso = ingrl, peso = fexp) %>%
      select(ingreso, peso)

    # Final year
    df_fin <- read_dta(file_fin) %>%
      filter(!is.na(ingrl) & ingrl > 0) %>%
      mutate(ingreso = ingrl, peso = fexp) %>%
      select(ingreso, peso)

    # Calculate percentiles for both years
    percentiles <- 1:99

    gic_data <- data.frame(percentil = percentiles)

    # Initial year percentiles
    quantiles_ini <- Hmisc::wtd.quantile(df_ini$ingreso, weights = df_ini$peso,
                                          probs = percentiles/100)
    # Final year percentiles
    quantiles_fin <- Hmisc::wtd.quantile(df_fin$ingreso, weights = df_fin$peso,
                                          probs = percentiles/100)

    # Calculate growth rate
    gic_data <- gic_data %>%
      mutate(
        ingreso_inicial = quantiles_ini,
        ingreso_final = quantiles_fin,
        crecimiento_anualizado = ((ingreso_final / ingreso_inicial)^(1/(year_fin - year_ini)) - 1) * 100,
        periodo = period$nombre,
        anio_inicial = year_ini,
        anio_final = year_fin
      )

    gic_all[[period$nombre]] <- gic_data
  }
}

# Combine all GIC curves
crecimiento_percentiles <- bind_rows(gic_all)

# Also create decile version for simpler visualizations
crecimiento_deciles <- crecimiento_percentiles %>%
  mutate(decil = ceiling(percentil / 10)) %>%
  group_by(periodo, anio_inicial, anio_final, decil) %>%
  summarise(
    crecimiento_anualizado = mean(crecimiento_anualizado, na.rm = TRUE),
    ingreso_inicial = mean(ingreso_inicial, na.rm = TRUE),
    ingreso_final = mean(ingreso_final, na.rm = TRUE),
    .groups = "drop"
  )

write_xlsx(
  list(
    percentiles = crecimiento_percentiles,
    deciles = crecimiento_deciles
  ),
  path = file.path(output_path, "crecimiento_percentiles.xlsx")
)

# ========== Growth by Demographics (etnia, area, education) ==========
# Compare income growth across different groups

years_demo <- c(2007, 2017, 2024)
data_list_demo <- list()

for (year in years_demo) {
  file_path <- file.path(enemdu_path, "Merged", paste0(year, "_12_merged.dta"))

  if (file.exists(file_path)) {
    cat("Reading", year, "for demographic growth analysis...\n")
    df <- read_dta(file_path)

    df_processed <- df %>%
      mutate(
        anio = year,
        ingreso = ifelse(!is.na(ingrl) & ingrl > 0, ingrl, NA_real_),
        etnia = case_when(
          p15 == 1 ~ "Indígena",
          p15 %in% c(2, 3, 4, 5, 6) ~ "No indígena",
          TRUE ~ NA_character_
        ),
        area = ifelse(area == 1, "Urbano", "Rural"),
        nivel_educativo = ifelse(p03 >= 9, "Universitario", "No universitario")
      ) %>%
      filter(!is.na(ingreso)) %>%
      select(anio, ingreso, etnia, area, nivel_educativo, fexp)

    data_list_demo[[as.character(year)]] <- df_processed
  }
}

data_demo <- bind_rows(data_list_demo)

# Calculate average income by group and year
crecimiento_demografico <- data_demo %>%
  group_by(anio, etnia) %>%
  summarise(ingreso = weighted.mean(ingreso, w = fexp, na.rm = TRUE), .groups = "drop") %>%
  filter(!is.na(etnia)) %>%
  mutate(dimension = "etnia", categoria = etnia) %>%
  bind_rows(
    data_demo %>%
      group_by(anio, area) %>%
      summarise(ingreso = weighted.mean(ingreso, w = fexp, na.rm = TRUE), .groups = "drop") %>%
      mutate(dimension = "area", categoria = area)
  ) %>%
  bind_rows(
    data_demo %>%
      group_by(anio, nivel_educativo) %>%
      summarise(ingreso = weighted.mean(ingreso, w = fexp, na.rm = TRUE), .groups = "drop") %>%
      mutate(dimension = "educacion", categoria = nivel_educativo)
  ) %>%
  select(anio, dimension, categoria, ingreso)

write_xlsx(
  list(Data = crecimiento_demografico),
  path = file.path(output_path, "crecimiento_demografico.xlsx")
)

# ========== Employment Growth by Economic Sector ==========
# Based on rama de actividad (branch of economic activity)
# Using processed income files which have rama1 variable

income_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc"
years_sector <- 2007:2024
data_sector_list <- list()

for (year in years_sector) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    df <- read_dta(file_path)

    # Convert haven_labelled variables
    df <- haven::zap_labels(df)

    # Add condact if it doesn't exist (older years)
    if (!"condact" %in% names(df)) {
      df$condact <- NA_real_
    }

    # rama1 variable contains economic sector (in processed income files)
    df_sector <- df %>%
      mutate(
        anio = year,
        sector = case_when(
          rama1 %in% 1:3 ~ "Agricultura, ganadería, pesca",
          rama1 %in% 4:9 ~ "Manufactura",
          rama1 %in% 10:11 ~ "Construcción",
          rama1 %in% 12:14 ~ "Comercio",
          rama1 %in% 15:21 ~ "Servicios",
          TRUE ~ "Otros"
        ),
        # Use condact if available, otherwise use empleo variable
        empleado = case_when(
          !is.na(condact) & condact <= 4 ~ 1,
          is.na(condact) & !is.na(empleo) & empleo == 1 ~ 1,
          TRUE ~ 0
        )
      ) %>%
      filter(!is.na(sector) & empleado == 1) %>%
      select(anio, sector, fw)

    data_sector_list[[as.character(year)]] <- df_sector
  }
}

data_sector <- bind_rows(data_sector_list)

# Calculate employment by sector (in thousands)
crecimiento_empleo_sector <- data_sector %>%
  group_by(anio, sector) %>%
  summarise(
    empleo_miles = sum(fw, na.rm = TRUE) / 1000,
    .groups = "drop"
  ) %>%
  arrange(sector, anio)

write_xlsx(
  list(Data = crecimiento_empleo_sector),
  path = file.path(output_path, "crecimiento_empleo_sector.xlsx")
)

cat("✓ Generated growth distribution datasets:\n")
cat("  - crecimiento_percentiles.xlsx (GIC curves)\n")
cat("    Periods:", length(periods), "\n")
cat("  - crecimiento_demografico.xlsx (", nrow(crecimiento_demografico), "rows )\n")
cat("  - crecimiento_empleo_sector.xlsx (", nrow(crecimiento_empleo_sector), "rows )\n")

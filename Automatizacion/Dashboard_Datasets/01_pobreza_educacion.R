# ============================================================================
# Script: Generate Poverty by Education Level Dataset
# Purpose: Create poverty indicators disaggregated by education level
# Output: pobreza_educacion.xlsx (latest year + time series)
# ============================================================================

library(haven)
library(dplyr)
library(readxl)
library(writexl)

# Paths
income_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc"
poverty_lines_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Automatizacion/Bases/Pobreza Extrema Histórica Ecuador.xlsx"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

# Read poverty lines
poverty_lines <- read_excel(poverty_lines_path) %>%
  mutate(
    anio = Año,
    linea_pobreza = as.numeric(gsub("[^0-9.]", "", gsub(",", ".", `Línea de Pobreza (USD)`))),
    linea_extrema = as.numeric(gsub("[^0-9.]", "", gsub(",", ".", `Línea de Pobreza Extrema (USD)`)))
  ) %>%
  select(anio, linea_pobreza, linea_extrema)

cat("Poverty lines available for years:", min(poverty_lines$anio), "-", max(poverty_lines$anio), "\n")

# Read processed income files for available years
years <- poverty_lines$anio[poverty_lines$anio >= 2007 & poverty_lines$anio <= 2024]
data_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Reading", year, "data...\n")
    df <- read_dta(file_path)

    # Get poverty lines for this year
    pov_line <- poverty_lines %>% filter(anio == year)

    if (nrow(pov_line) > 0) {
      df <- haven::zap_labels(df)

      df_processed <- df %>%
        mutate(
          anio = year,
          ingreso_pc = ingtot_per,
          pobreza = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_pobreza, 1, 0),
          pobreza_extrema = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_extrema, 1, 0),
          # p10a: 1-7=below superior, 8-10=superior+
          nivel_educativo = case_when(
            p10a >= 8 ~ "Superior",
            p10a %in% 1:7 ~ "Menos que superior",
            TRUE ~ NA_character_
          )
        ) %>%
        filter(!is.na(nivel_educativo) & !is.na(ingreso_pc)) %>%
        select(anio, nivel_educativo, pobreza, pobreza_extrema, fw)

      data_list[[as.character(year)]] <- df_processed
    }
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# Calculate weighted poverty rates by education level
pobreza_educacion <- data_combined %>%
  group_by(anio, nivel_educativo) %>%
  summarise(
    Pobreza = weighted.mean(pobreza, w = fw, na.rm = TRUE) * 100,
    `Pobreza extrema` = weighted.mean(pobreza_extrema, w = fw, na.rm = TRUE) * 100,
    .groups = "drop"
  )

# Reshape to long format for dashboard
pobreza_educacion_long <- pobreza_educacion %>%
  tidyr::pivot_longer(
    cols = c(Pobreza, `Pobreza extrema`),
    names_to = "indicador",
    values_to = "valor"
  ) %>%
  select(anio, nivel_educativo, indicador, valor)

# Save to Excel
write_xlsx(
  list(Sheet1 = pobreza_educacion_long),
  path = file.path(output_path, "pobreza_educacion.xlsx")
)

cat("✓ Generated: pobreza_educacion.xlsx\n")
cat("  Rows:", nrow(pobreza_educacion_long), "\n")
cat("  Years:", min(pobreza_educacion_long$anio), "-", max(pobreza_educacion_long$anio), "\n")

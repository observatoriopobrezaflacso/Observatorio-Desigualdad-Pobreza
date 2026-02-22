# ============================================================================
# Script: Generate Poverty by Age Group Dataset
# Purpose: Create poverty indicators by age groups (niños, jóvenes, adultos, adultos mayores)
# Output: pobreza_edad.xlsx
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
    df <- haven::zap_labels(df)

    # Get poverty lines for this year
    pov_line <- poverty_lines %>% filter(anio == year)

    if (nrow(pov_line) > 0) {
      # p03 is the age variable in processed ENEMDU files
      df$edad <- as.numeric(df$p03)

      df_processed <- df %>%
        mutate(
          anio = year,
          ingreso_pc = ingtot_per,
          pobreza = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_pobreza, 1, 0),
          pobreza_extrema = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_extrema, 1, 0),
          grupo_etario = case_when(
            edad < 18 ~ "Niños (0-17)",
            edad >= 18 & edad < 30 ~ "Jóvenes (18-29)",
            edad >= 30 & edad < 65 ~ "Adultos (30-64)",
            edad >= 65 ~ "Adultos mayores (65+)",
            TRUE ~ NA_character_
          )
        ) %>%
        filter(!is.na(grupo_etario) & !is.na(ingreso_pc)) %>%
        select(anio, grupo_etario, pobreza, pobreza_extrema, fw)

      data_list[[as.character(year)]] <- df_processed
    }
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# Calculate weighted poverty rates by age group
pobreza_edad <- data_combined %>%
  group_by(anio, grupo_etario) %>%
  summarise(
    Pobreza = weighted.mean(pobreza, w = fw, na.rm = TRUE) * 100,
    `Pobreza extrema` = weighted.mean(pobreza_extrema, w = fw, na.rm = TRUE) * 100,
    .groups = "drop"
  )

# Reshape to long format
pobreza_edad_long <- pobreza_edad %>%
  tidyr::pivot_longer(
    cols = c(Pobreza, `Pobreza extrema`),
    names_to = "indicador",
    values_to = "valor"
  ) %>%
  select(anio, grupo_etario, indicador, valor)

# Save to Excel
write_xlsx(
  list(Sheet1 = pobreza_edad_long),
  path = file.path(output_path, "pobreza_edad.xlsx")
)

cat("✓ Generated: pobreza_edad.xlsx\n")
cat("  Rows:", nrow(pobreza_edad_long), "\n")
cat("  Years:", min(pobreza_edad_long$anio), "-", max(pobreza_edad_long$anio), "\n")

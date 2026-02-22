# ============================================================================
# Script: Generate Poverty by Region Dataset
# Purpose: Create poverty indicators by region (Costa, Sierra, Oriente)
# Output: pobreza_region.xlsx
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
      # Check if region/zona/ciudad variable exists to derive region
      # First, try to identify what geographic variables exist
      has_region <- "region" %in% names(df)
      has_zona <- "zona" %in% names(df)
      has_ciudad <- "ciudad" %in% names(df)

      if (!has_region && !has_zona && !has_ciudad) {
        cat("  WARNING: No region variable found in", year, "data. Skipping this year.\n")
        next
      }

      df_processed <- df %>%
        mutate(
          anio = year,
          # Use nominal per capita income
          ingreso_pc = ingtot_per,
          # Calculate poverty status
          pobreza = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_pobreza, 1, 0),
          pobreza_extrema = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_extrema, 1, 0)
        )

      # Add region mapping based on available variables
      if (has_region) {
        df_processed <- df_processed %>%
          mutate(region = case_when(
            region == 1 ~ "Sierra",
            region == 2 ~ "Costa",
            region == 3 | region == 4 ~ "Oriente",
            TRUE ~ NA_character_
          ))
      } else if (has_zona) {
        df_processed <- df_processed %>%
          mutate(region = case_when(
            zona == 1 ~ "Sierra",
            zona == 2 ~ "Costa",
            zona == 3 | zona == 4 ~ "Oriente",
            TRUE ~ NA_character_
          ))
      } else if (has_ciudad) {
        # Derive region from ciudad code (first digit often indicates region)
        # This is a simplified mapping - adjust based on actual ENEMDU codebook
        df_processed <- df_processed %>%
          mutate(
            ciudad_code = as.numeric(ciudad),
            region = case_when(
              ciudad_code >= 1 & ciudad_code <= 10 ~ "Sierra",
              ciudad_code >= 11 & ciudad_code <= 20 ~ "Costa",
              ciudad_code >= 21 & ciudad_code <= 30 ~ "Oriente",
              TRUE ~ NA_character_
            )
          ) %>%
          select(-ciudad_code)
      }

      df_processed <- df_processed %>%
        filter(!is.na(region) & !is.na(ingreso_pc)) %>%
        select(anio, region, pobreza, pobreza_extrema, fw)

      data_list[[as.character(year)]] <- df_processed
    }
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# Calculate weighted poverty rates by region
pobreza_region <- data_combined %>%
  group_by(anio, region) %>%
  summarise(
    Pobreza = weighted.mean(pobreza, w = fw, na.rm = TRUE) * 100,
    `Pobreza extrema` = weighted.mean(pobreza_extrema, w = fw, na.rm = TRUE) * 100,
    .groups = "drop"
  )

# Reshape to long format
pobreza_region_long <- pobreza_region %>%
  tidyr::pivot_longer(
    cols = c(Pobreza, `Pobreza extrema`),
    names_to = "indicador",
    values_to = "valor"
  ) %>%
  select(anio, region, indicador, valor)

# Save to Excel
write_xlsx(
  list(Sheet1 = pobreza_region_long),
  path = file.path(output_path, "pobreza_region.xlsx")
)

cat("✓ Generated: pobreza_region.xlsx\n")
cat("  Rows:", nrow(pobreza_region_long), "\n")
cat("  Years:", min(pobreza_region_long$anio), "-", max(pobreza_region_long$anio), "\n")

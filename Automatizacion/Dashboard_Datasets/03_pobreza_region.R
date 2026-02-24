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

# Province -> Region mapping (Ecuador official classification)
# Sierra: Azuay(1), Bolívar(2), Cañar(3), Carchi(4), Cotopaxi(5), Chimborazo(6),
#          Imbabura(10), Loja(11), Pichincha(17), Tungurahua(18), Sto.Domingo(23)
# Costa:  El Oro(7), Esmeraldas(8), Guayas(9), Los Ríos(12), Manabí(13), Sta.Elena(24)
# Oriente: Morona Santiago(14), Napo(15), Pastaza(16), Zamora Chinchipe(19),
#          Sucumbíos(21), Orellana(22)
# Galápagos(20), Zonas No Delimitadas(90) -> excluded

prov_to_region <- function(prov_code) {
  case_when(
    prov_code %in% c(1, 2, 3, 4, 5, 6, 10, 11, 17, 18, 23) ~ "Sierra",
    prov_code %in% c(7, 8, 9, 12, 13, 24) ~ "Costa",
    prov_code %in% c(14, 15, 16, 19, 21, 22) ~ "Oriente",
    TRUE ~ NA_character_
  )
}

# Read poverty lines (needed for years without precomputed pobreza, e.g. 2014)
poverty_lines <- read_excel(poverty_lines_path) %>%
  mutate(
    anio = Año,
    linea_pobreza = as.numeric(gsub("[^0-9.]", "", gsub(",", ".", `Línea de Pobreza (USD)`))),
    linea_extrema = as.numeric(gsub("[^0-9.]", "", gsub(",", ".", `Línea de Pobreza Extrema (USD)`)))
  ) %>%
  select(anio, linea_pobreza, linea_extrema)

cat("Poverty lines available for years:", min(poverty_lines$anio), "-", max(poverty_lines$anio), "\n")

# Read processed income files for available years
years <- 2007:2024
data_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Reading", year, "data...\n")
    df <- read_dta(file_path)
    df <- haven::zap_labels(df)

    # --- Derive province code ---
    has_prov <- "prov" %in% names(df)
    has_ciudad <- "ciudad" %in% names(df)

    if (has_prov) {
      df$prov_code <- as.numeric(df$prov)
    } else if (has_ciudad) {
      # First 2 digits of ciudad code = province
      # ciudad codes are 5-6 digits: PPCCCC
      df$prov_code <- as.numeric(df$ciudad) %/% 10000
      # Handle 6-digit codes (some may be PPPCCC -> divide by 1000)
      # Check if any codes > 24 (max province)
      if (any(df$prov_code > 90, na.rm = TRUE)) {
        df$prov_code <- as.numeric(df$ciudad) %/% 10000
      }
    } else {
      cat("  WARNING: No province/ciudad variable found in", year, "data. Skipping.\n")
      next
    }

    # Map province to region
    df$region <- prov_to_region(df$prov_code)

    # --- Derive poverty status ---
    has_pobreza <- "pobreza" %in% names(df) && "epobreza" %in% names(df)

    if (has_pobreza) {
      # Use precomputed poverty variables
      df$pov <- as.numeric(df$pobreza)
      df$epov <- as.numeric(df$epobreza)
    } else {
      # Compute from poverty lines (fallback for 2014)
      pov_line <- poverty_lines %>% filter(anio == year)
      if (nrow(pov_line) == 0) {
        cat("  WARNING: No poverty line found for", year, ". Skipping.\n")
        next
      }
      df$pov <- ifelse(!is.na(df$ingtot_per) & df$ingtot_per < pov_line$linea_pobreza, 1, 0)
      df$epov <- ifelse(!is.na(df$ingtot_per) & df$ingtot_per < pov_line$linea_extrema, 1, 0)
    }

    df_processed <- df %>%
      mutate(anio = year) %>%
      filter(!is.na(region)) %>%
      select(anio, region, pov, epov, fw)

    data_list[[as.character(year)]] <- df_processed
    cat("  ✓", year, "- rows:", nrow(df_processed), "\n")
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# Calculate weighted poverty rates by region
pobreza_region <- data_combined %>%
  group_by(anio, region) %>%
  summarise(
    Pobreza = weighted.mean(pov, w = fw, na.rm = TRUE) * 100,
    `Pobreza extrema` = weighted.mean(epov, w = fw, na.rm = TRUE) * 100,
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
cat("  Regions:", paste(unique(pobreza_region_long$region), collapse = ", "), "\n")

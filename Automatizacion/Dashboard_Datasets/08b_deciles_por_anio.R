# ============================================================================
# Script: Compute income by decile for each year (for dynamic GIC curves)
# Output: deciles_ingreso_anual.xlsx
# ============================================================================

library(haven)
library(dplyr)
library(writexl)

income_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

years <- 2007:2024
all_results <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))
  if (!file.exists(file_path)) next

  cat("Processing", year, "...\n")
  df <- read_dta(file_path)
  df <- haven::zap_labels(df)

  # Use ingrl (labor income) or ing_lab
  if (!"ingrl" %in% names(df) && "ing_lab" %in% names(df)) df$ingrl <- df$ing_lab
  if (!"fw" %in% names(df) && "fexp" %in% names(df)) df$fw <- df$fexp

  df <- df %>%
    filter(!is.na(ingrl) & ingrl > 0 & !is.na(fw)) %>%
    select(ingrl, fw)

  # Compute weighted decile boundaries and mean income per decile
  decile_breaks <- Hmisc::wtd.quantile(df$ingrl, weights = df$fw, probs = seq(0, 1, 0.1))

  df$decil <- cut(df$ingrl,
    breaks = decile_breaks, labels = 1:10,
    include.lowest = TRUE, right = TRUE
  )
  df$decil <- as.integer(as.character(df$decil))

  decile_stats <- df %>%
    filter(!is.na(decil)) %>%
    group_by(decil) %>%
    summarise(
      ingreso_promedio = weighted.mean(ingrl, w = fw, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(anio = year)

  all_results[[as.character(year)]] <- decile_stats
}

deciles_anuales <- bind_rows(all_results) %>%
  select(anio, decil, ingreso_promedio) %>%
  arrange(anio, decil)

write_xlsx(
  list(Sheet1 = deciles_anuales),
  path = file.path(output_path, "deciles_ingreso_anual.xlsx")
)

cat("✓ Generated: deciles_ingreso_anual.xlsx\n")
cat("  Rows:", nrow(deciles_anuales), "\n")
cat("  Years:", min(deciles_anuales$anio), "-", max(deciles_anuales$anio), "\n")

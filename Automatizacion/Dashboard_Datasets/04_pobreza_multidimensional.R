# ============================================================================
# Script: Generate Multidimensional Poverty Dataset
# Purpose: Create multidimensional poverty indicators for scorecards and time series
# Output: pobreza_multidimensional_scorecard.xlsx, pobreza_multidimensional_series.xlsx
# Note: Uses TOY DATA - real multidimensional poverty requires deprivation indicators
# ============================================================================

library(dplyr)
library(writexl)

output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

# ============================================================================
# TOY DATA - Multidimensional Poverty
# Real calculation requires: health, education, housing, social security,
# employment indicators per INEC methodology
# ============================================================================

years <- 2007:2024

# Scorecard data for latest year (2024)
# Typically multidimensional poverty is higher than monetary poverty
multidim_scorecard <- data.frame(
  anio = 2024,
  indicador = c("Pobreza Multidimensional", "Pobreza Extrema Multidimensional"),
  valor = c(28.5, 10.2)  # Example values - replace with actual INEC data
)

# Time series showing declining trend
multidim_series <- data.frame(
  anio = years,
  indicador = "Pobreza Multidimensional",
  valor = seq(45.2, 28.5, length.out = length(years))  # Declining trend
)

# Save scorecard data
write_xlsx(
  list(Sheet1 = multidim_scorecard),
  path = file.path(output_path, "pobreza_multidimensional_scorecard.xlsx")
)

# Save time series
write_xlsx(
  list(Sheet1 = multidim_series),
  path = file.path(output_path, "pobreza_multidimensional_series.xlsx")
)

cat("✓ Generated: pobreza_multidimensional_scorecard.xlsx (TOY DATA)\n")
cat("✓ Generated: pobreza_multidimensional_series.xlsx (TOY DATA)\n")
cat("  NOTE: Replace with actual INEC multidimensional poverty data\n")
cat("  Real calculation requires deprivation indicators from ENEMDU\n")

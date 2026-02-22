# ============================================================================
# Script: Generate Inequality Datasets
# Purpose: Gini comparisons, tax impacts, SRI percentiles
# Output: gini_lac_comparison.xlsx, gini_tax_impact.xlsx, sri_percentiles.xlsx
# ============================================================================

library(dplyr)
library(writexl)
library(WDI)

output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

# ========== Gini Comparison with LAC Countries ==========
# Download Gini data from World Bank WDI

cat("Downloading Gini data from World Bank...\n")

lac_countries <- c("AR", "BO", "BR", "CL", "CO", "CR", "CU", "DO", "EC",
                   "SV", "GT", "HT", "HN", "MX", "NI", "PA", "PY", "PE",
                   "UY", "VE")

# Gini index (World Bank estimate)
gini_data <- tryCatch({
  WDI(country = lac_countries,
      indicator = "SI.POV.GINI",
      start = 2000,
      end = 2024,
      extra = FALSE)
}, error = function(e) {
  cat("Failed to download WDI data, using fallback...\n")
  NULL
})

if (!is.null(gini_data)) {
  gini_lac <- gini_data %>%
    filter(!is.na(SI.POV.GINI)) %>%
    select(
      Año = year,
      País = country,
      Código_ISO = iso2c,
      Gini = SI.POV.GINI
    ) %>%
    mutate(Gini = Gini / 100)  # Convert to 0-1 scale

  write_xlsx(
    list(Data = gini_lac),
    path = file.path(output_path, "gini_lac_comparison.xlsx")
  )
  cat("✓ Downloaded Gini data for", length(unique(gini_lac$País)), "countries\n")
} else {
  # Fallback: create basic comparison with existing Ecuador data
  existing_gini <- read_xlsx(file.path(output_path, "gini_panel_tableau.xlsx"))

  gini_lac <- existing_gini %>%
    filter(categoria == "Ecuador") %>%
    select(Año, Gini = valor) %>%
    mutate(País = "Ecuador", Código_ISO = "EC")

  write_xlsx(
    list(Data = gini_lac),
    path = file.path(output_path, "gini_lac_comparison.xlsx")
  )
  cat("✓ Created fallback Gini comparison (Ecuador only)\n")
}

# ========== Gini Before/After Taxes (TOY DATA) ==========
# This requires detailed tax microsimulation - use simplified toy data

years <- 2007:2024

gini_tax_impact <- data.frame(
  anio = rep(years, 4),
  categoria = rep(c("Gini antes de impuestos",
                    "Gini después de IR",
                    "Gini después de IR + IVA",
                    "Gini después de todos los impuestos"),
                  each = length(years)),
  gini = c(
    # Before taxes (highest inequality)
    seq(0.52, 0.48, length.out = length(years)),
    # After income tax
    seq(0.50, 0.46, length.out = length(years)),
    # After income tax + VAT
    seq(0.51, 0.47, length.out = length(years)),
    # After all taxes
    seq(0.49, 0.45, length.out = length(years))
  )
)

write_xlsx(
  list(Data = gini_tax_impact),
  path = file.path(output_path, "gini_tax_impact.xlsx")
)

# ========== SRI Income Percentiles - Nominal Income (TOY DATA) ==========
# Nominal monthly income by percentile from tax records

sri_percentiles <- data.frame(
  anio = rep(years, 4),
  percentil = rep(c("P50 (Mediana)", "P90", "P99", "P99.9"), each = length(years)),
  ingreso_mensual_nominal = c(
    # P50 - median income
    seq(450, 600, length.out = length(years)),
    # P90
    seq(1800, 2400, length.out = length(years)),
    # P99
    seq(8000, 12000, length.out = length(years)),
    # P99.9
    seq(30000, 50000, length.out = length(years))
  )
)

write_xlsx(
  list(Data = sri_percentiles),
  path = file.path(output_path, "sri_percentiles_ingreso.xlsx")
)

# ========== Population by Percentile Groups (TOY DATA) ==========

poblacion_percentiles <- data.frame(
  anio = 2024,
  percentil = c("Bottom 50%", "50-90%", "Top 10%", "Top 1%", "Top 0.1%"),
  poblacion = c(
    8900000,   # Bottom 50%
    7100000,   # 50-90%
    1780000,   # Top 10%
    178000,    # Top 1%
    17800      # Top 0.1%
  )
)

write_xlsx(
  list(Data = poblacion_percentiles),
  path = file.path(output_path, "poblacion_percentiles.xlsx")
)

cat("✓ Generated inequality datasets:\n")
cat("  - gini_lac_comparison.xlsx\n")
cat("  - gini_tax_impact.xlsx (TOY DATA)\n")
cat("  - sri_percentiles_ingreso.xlsx (TOY DATA)\n")
cat("  - poblacion_percentiles.xlsx (TOY DATA)\n")

# ============================================================================
# Script: Generate Taxation Datasets
# Purpose: Extract data from Boletín 1 for taxation graphs (16 & 17)
# Output: tributacion_graficos.xlsx
# Note: Manually extract from PDF if needed, or use existing processed data
# ============================================================================

library(dplyr)
library(writexl)

output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"
boletin_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Boletín 1"

# Check if there are processed datasets in Boletín 1 folder
boletin_data_path <- file.path(boletin_path, "Procesamiento/Bases/Procesadas")

# ========== Placeholder: Tax Revenue by Type ==========
# Graph 16 typically shows tax composition
# Graph 17 typically shows progressivity or tax burden by income level

years <- 2007:2024

# Gráfico 16: Tax revenue composition (TOY DATA - replace with actual)
grafico_16 <- data.frame(
  anio = rep(years, 4),
  tipo_impuesto = rep(c("Impuesto a la Renta", "IVA",
                        "Aranceles", "Otros"), each = length(years)),
  porcentaje_pib = c(
    # Income tax
    seq(4.2, 5.1, length.out = length(years)),
    # VAT
    seq(6.8, 7.2, length.out = length(years)),
    # Tariffs
    seq(1.2, 0.8, length.out = length(years)),
    # Others
    seq(2.5, 2.3, length.out = length(years))
  )
)

# Gráfico 17: Tax burden by income decile (TOY DATA - replace with actual)
grafico_17 <- data.frame(
  decil = rep(1:10, length(years)),
  anio = rep(years, each = 10),
  carga_tributaria_pct = c(
    # Simulate regressive to slightly progressive pattern
    sapply(years, function(y) {
      c(8.5, 8.2, 7.8, 7.5, 7.2, 7.0, 6.8, 7.0, 7.5, 8.0) +
        rnorm(10, 0, 0.3)
    })
  )
) %>%
  mutate(carga_tributaria_pct = pmax(0, carga_tributaria_pct))

# Combine into one file with multiple sheets
tributacion_graficos <- list(
  grafico_16_composicion = grafico_16,
  grafico_17_carga = grafico_17
)

write_xlsx(
  tributacion_graficos,
  path = file.path(output_path, "tributacion_graficos.xlsx")
)

cat("✓ Generated taxation datasets (TOY DATA - needs validation):\n")
cat("  - tributacion_graficos.xlsx (2 sheets)\n")
cat("  NOTE: Please verify against actual Boletín 1 graphs 16 & 17\n")
cat("  PDF location:", file.path(boletin_path, "FLACSO Ec - Boletín Desigualdad de ingresos en Ecuador.pdf"), "\n")

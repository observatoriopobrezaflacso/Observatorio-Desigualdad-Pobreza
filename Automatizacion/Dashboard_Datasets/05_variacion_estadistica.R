# ============================================================================
# Script: Generate Statistical Variation Tables with T-tests
# Purpose: Year-over-year changes with proper statistical significance tests
# Output: variacion_pobreza_significancia.xlsx
# ============================================================================

library(haven)
library(dplyr)
library(readxl)
library(writexl)
library(survey)

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

years <- poverty_lines$anio[poverty_lines$anio >= 2007 & poverty_lines$anio <= 2024]

# Function to create survey design (varies by year)
create_survey_design <- function(df, year) {
  # Survey design variables differ across years
  # 2007-2019: Only weights available (estrato/upm not consistently available)
  # 2020+: Full design with estrato and upm

  has_estrato <- "estrato" %in% names(df)
  has_upm <- "upm" %in% names(df)

  if (has_estrato && has_upm) {
    # Full complex survey design
    design <- svydesign(
      ids = ~upm,           # Primary sampling units (clusters)
      strata = ~estrato,    # Strata
      weights = ~fw,        # Survey weights
      data = df,
      nest = TRUE           # Allow same PSU codes in different strata
    )
  } else {
    # Simple design with only weights (for earlier years)
    design <- svydesign(
      ids = ~1,             # No clustering information
      weights = ~fw,
      data = df
    )
  }

  return(design)
}

# Read data and calculate poverty rates with SE for all years
results_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Processing", year, "...\n")
    df <- read_dta(file_path)
    df <- haven::zap_labels(df)

    pov_line <- poverty_lines %>% filter(anio == year)

    if (nrow(pov_line) > 0) {
      # Calculate poverty and demographics
      df <- haven::zap_labels(df)
      df <- df %>%
        mutate(
          anio = year,
          ingreso_pc = ingtot_per,
          pobreza = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_pobreza, 1, 0),
          pobreza_extrema = ifelse(!is.na(ingreso_pc) & ingreso_pc < pov_line$linea_extrema, 1, 0),
          # Education: p10a (1-7=below superior, 8-10=superior+)
          nivel_educativo = case_when(
            p10a >= 8 ~ "Superior",
            p10a %in% 1:7 ~ "Menos que superior",
            TRUE ~ NA_character_
          ),
          # Age: p03 is age variable
          grupo_etario = case_when(
            p03 < 18 ~ "Niños (0-17)",
            p03 >= 18 & p03 < 30 ~ "Jóvenes (18-29)",
            p03 >= 30 & p03 < 65 ~ "Adultos (30-64)",
            p03 >= 65 ~ "Adultos mayores (65+)",
            TRUE ~ NA_character_
          )
        ) %>%
        filter(!is.na(ingreso_pc))

      # Create survey design
      svy_design <- create_survey_design(df, year)

      # Calculate poverty rates by education with SE
      if (any(!is.na(df$nivel_educativo))) {
        educ_stats <- svyby(~pobreza, ~nivel_educativo, svy_design, svymean, na.rm = TRUE)
        educ_stats_ext <- svyby(~pobreza_extrema, ~nivel_educativo, svy_design, svymean, na.rm = TRUE)

        results_list[[paste0(year, "_educ_pob")]] <- data.frame(
          anio = year,
          dimension = "Educación",
          nivel = educ_stats$nivel_educativo,
          indicador = "Pobreza",
          valor = educ_stats$pobreza * 100,
          se = educ_stats$se * 100
        )

        results_list[[paste0(year, "_educ_ext")]] <- data.frame(
          anio = year,
          dimension = "Educación",
          nivel = educ_stats_ext$nivel_educativo,
          indicador = "Pobreza extrema",
          valor = educ_stats_ext$pobreza_extrema * 100,
          se = educ_stats_ext$se * 100
        )
      }

      # Calculate poverty rates by age with SE
      if (any(!is.na(df$grupo_etario))) {
        age_stats <- svyby(~pobreza, ~grupo_etario, svy_design, svymean, na.rm = TRUE)
        age_stats_ext <- svyby(~pobreza_extrema, ~grupo_etario, svy_design, svymean, na.rm = TRUE)

        results_list[[paste0(year, "_age_pob")]] <- data.frame(
          anio = year,
          dimension = "Edad",
          nivel = age_stats$grupo_etario,
          indicador = "Pobreza",
          valor = age_stats$pobreza * 100,
          se = age_stats$se * 100
        )

        results_list[[paste0(year, "_age_ext")]] <- data.frame(
          anio = year,
          dimension = "Edad",
          nivel = age_stats_ext$grupo_etario,
          indicador = "Pobreza extrema",
          valor = age_stats_ext$pobreza_extrema * 100,
          se = age_stats_ext$se * 100
        )
      }
    }
  }
}

# Combine all results
all_results <- bind_rows(results_list)

# Calculate year-over-year changes with t-tests
variacion_pobreza <- all_results %>%
  arrange(dimension, nivel, indicador, anio) %>%
  group_by(dimension, nivel, indicador) %>%
  mutate(
    valor_anterior = lag(valor),
    se_anterior = lag(se),
    anio_anterior = lag(anio),
    variacion_pp = valor - valor_anterior,
    variacion_pct = (valor - valor_anterior) / valor_anterior * 100,
    # T-test for difference: t = (p1 - p2) / sqrt(se1^2 + se2^2)
    se_diff = sqrt(se^2 + se_anterior^2),
    t_stat = variacion_pp / se_diff,
    # Two-tailed p-value (approximate, assuming normal distribution)
    p_value = 2 * (1 - pnorm(abs(t_stat))),
    # Statistical significance
    significativo = case_when(
      is.na(p_value) ~ NA_character_,
      p_value < 0.01 ~ "Sí (p<0.01)",
      p_value < 0.05 ~ "Sí (p<0.05)",
      p_value < 0.10 ~ "Marginal (p<0.10)",
      TRUE ~ "No"
    )
  ) %>%
  filter(!is.na(variacion_pp)) %>%
  select(anio, anio_anterior, dimension, nivel, indicador,
         valor, se, valor_anterior, se_anterior,
         variacion_pp, variacion_pct, t_stat, p_value, significativo) %>%
  ungroup()

# Save to Excel
write_xlsx(
  list(Data = variacion_pobreza),
  path = file.path(output_path, "variacion_pobreza_significancia.xlsx")
)

cat("✓ Generated: variacion_pobreza_significancia.xlsx with proper t-tests\n")
cat("  Rows:", nrow(variacion_pobreza), "\n")
cat("  Latest year comparisons:", max(variacion_pobreza$anio, na.rm = TRUE), "\n")
cat("  Significant changes (p<0.05):", sum(variacion_pobreza$p_value < 0.05, na.rm = TRUE), "\n")

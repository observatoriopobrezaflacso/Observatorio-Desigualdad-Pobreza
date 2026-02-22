# ============================================================================
# Script: Generate Wage and Wage Gap Datasets from ENEMDU
# Purpose: Create wage indicators and wage gaps by demographics
# Output: salarios_series.xlsx, brechas_salariales.xlsx
# ============================================================================

library(haven)
library(dplyr)
library(writexl)

# Paths
income_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

# Read processed income files (2007-2024)
years <- 2007:2024
data_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Reading", year, "wage data...\n")
    df <- read_dta(file_path)

    # Extract wage/income variables
    # Labor income: ingrl (2015+) or ing_lab (2007-2014)
    # Convert haven_labelled variables by removing labels first
    df <- haven::zap_labels(df)

    # Handle different labor income variable names across years
    if (!"ingrl" %in% names(df) && "ing_lab" %in% names(df)) {
      df$ingrl <- df$ing_lab
    }

    df_processed <- df %>%
      mutate(
        anio = year,
        # Income variable
        ingreso_laboral = ifelse(!is.na(ingrl) & ingrl > 0, ingrl, NA_real_),
        # Demographics
        sexo = ifelse(p01 == 1, "Hombre", "Mujer"),
        # Handle p05 variable (marital status) - may be p05a or p05b depending on year
        p05_combined = coalesce(p05a, p05b),
        estado_civil = case_when(
          p05_combined %in% c(1, 2) ~ "Casado/Unido",
          TRUE ~ "Soltero/Otro"
        ),
        etnia = case_when(
          p15 == 1 ~ "Indígena",
          p15 %in% c(2, 3, 4, 5, 6) ~ "No indígena",
          TRUE ~ NA_character_
        ),
        nivel_educativo = case_when(
          p03 <= 6 ~ "Primaria/Básica",
          p03 %in% 7:8 ~ "Secundaria",
          p03 == 9 ~ "Superior",
          p03 >= 10 ~ "Posgrado",
          TRUE ~ NA_character_
        ),
        grupo_edad = case_when(
          p02 >= 18 & p02 < 30 ~ "Jóvenes (18-29)",
          p02 >= 30 & p02 < 65 ~ "Adultos (30-64)",
          p02 >= 65 ~ "Adultos mayores (65+)",
          TRUE ~ NA_character_
        )
      ) %>%
      filter(!is.na(ingreso_laboral) & ingreso_laboral > 0) %>%
      select(anio, ingreso_laboral, sexo, estado_civil, etnia,
             nivel_educativo, grupo_edad, fw)

    data_list[[as.character(year)]] <- df_processed
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# ========== Salario básico (minimum wage) - external data ==========
# Minimum wage data from official sources
salario_basico <- data.frame(
  anio = years,
  salario_basico = c(170, 170, 200, 218, 240, 264, 292, 318, 340, 354,
                     366, 375, 386, 394, 400, 400, 400, 425)
)

# ========== Average wage from ENEMDU ==========
salario_promedio <- data_combined %>%
  group_by(anio) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Combine wage series
salarios_series <- salario_basico %>%
  left_join(salario_promedio, by = "anio") %>%
  tidyr::pivot_longer(
    cols = -anio,
    names_to = "tipo",
    values_to = "valor"
  ) %>%
  mutate(tipo = recode(tipo,
                       "salario_basico" = "Salario básico",
                       "salario_promedio" = "Salario promedio"))

write_xlsx(
  list(Sheet1 = salarios_series),
  path = file.path(output_path, "salarios_series.xlsx")
)

# ========== Wage Gaps by Demographics ==========

# Wage gap by education level
brecha_educacion <- data_combined %>%
  filter(!is.na(nivel_educativo)) %>%
  group_by(anio, nivel_educativo) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Wage gap by gender
brecha_genero <- data_combined %>%
  group_by(anio, sexo) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Wage gap by gender and marital status
brecha_genero_civil <- data_combined %>%
  mutate(grupo = paste(sexo, estado_civil)) %>%
  group_by(anio, grupo) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Wage gap by ethnicity
brecha_etnia <- data_combined %>%
  filter(!is.na(etnia)) %>%
  group_by(anio, etnia) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Wage gap by age
brecha_edad <- data_combined %>%
  filter(!is.na(grupo_edad)) %>%
  group_by(anio, grupo_edad) %>%
  summarise(
    salario_promedio = weighted.mean(ingreso_laboral, w = fw, na.rm = TRUE),
    .groups = "drop"
  )

# Combine all wage gaps into single file with sheets
brechas_salariales <- list(
  educacion = brecha_educacion,
  genero = brecha_genero,
  genero_civil = brecha_genero_civil,
  etnia = brecha_etnia,
  edad = brecha_edad
)

write_xlsx(
  brechas_salariales,
  path = file.path(output_path, "brechas_salariales.xlsx")
)

cat("✓ Generated wage datasets from ENEMDU:\n")
cat("  - salarios_series.xlsx (", nrow(salarios_series), "rows )\n")
cat("  - brechas_salariales.xlsx (5 sheets)\n")
cat("    Education gaps:", nrow(brecha_educacion), "rows\n")
cat("    Gender gaps:", nrow(brecha_genero), "rows\n")
cat("    Ethnicity gaps:", nrow(brecha_etnia), "rows\n")
cat("    Age gaps:", nrow(brecha_edad), "rows\n")

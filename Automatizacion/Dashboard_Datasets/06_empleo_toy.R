# ============================================================================
# Script: Generate Employment Datasets from ENEMDU
# Purpose: Construct employment indicators following INEC methodology
#          using the official condact/CONDACTN variable from ENEMDU data
#          (PET, PEA, empleo, empleo adecuado, subempleo, desempleo)
# Reference: evolucion_empleo_adecuado.do (uses condact == 1 for adecuado)
# Output: empleo_scorecard.xlsx, empleo_series.xlsx, empleo_demografico.xlsx,
#         variacion_empleo_significancia.xlsx, iess_afiliados.xlsx (toy)
# ============================================================================

library(haven)
library(dplyr)
library(tidyr)
library(writexl)
library(survey)

# Paths
income_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

edadmin <- 15  # Minimum working age

# Helper: find the official condact variable in the data.
# 2007-2013 files use CONDACTN (uppercase), 2014+ use condact (lowercase).
# New INEC classification values:
#   1 = Empleo adecuado/pleno
#   2 = Subempleo por insuficiencia de tiempo de trabajo
#   3 = Subempleo por insuficiencia de ingresos
#   4 = Otro empleo no pleno
#   5 = Empleo no remunerado
#   6 = Empleo no clasificado
#   7 = Desempleo abierto
#   8 = Desempleo oculto
find_condact <- function(df) {
  for (v in c("CONDACTN", "condactn", "condact")) {
    if (v %in% names(df)) return(v)
  }
  return(NULL)
}

years <- 2007:2024
data_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Processing", year, "...\n")
    df <- read_dta(file_path)
    df <- haven::zap_labels(df)

    # Use fexp as weight; some years have fw instead
    if (!"fexp" %in% names(df) && "fw" %in% names(df)) {
      df$fexp <- df$fw
    }
    if (!"fw" %in% names(df) && "fexp" %in% names(df)) {
      df$fw <- df$fexp
    }

    # Ensure numeric types for key variables
    df$p03 <- as.numeric(df$p03)

    # ====================================================================
    # Use official INEC condact/CONDACTN variable for employment classification
    # This variable is pre-computed by INEC in the ENEMDU microdata.
    # New classification: 1=Empleo adecuado/pleno, 2=Subempleo por insuficiencia
    #   de tiempo, 3=Subempleo por insuficiencia de ingresos, 4=Otro empleo no
    #   pleno, 5=Empleo no remunerado, 6=Empleo no clasificado,
    #   7=Desempleo abierto, 8=Desempleo oculto
    # ====================================================================
    condact_var <- find_condact(df)
    if (is.null(condact_var)) {
      cat("  WARNING: No condact variable found for", year, "- skipping\n")
      next
    }

    df$condact_val <- as.numeric(df[[condact_var]])
    cat("  Using variable:", condact_var, "\n")

    # PEA: all persons with condact 1-8 AND age >= edadmin
    df$pean <- ifelse(!is.na(df$condact_val) & df$condact_val %in% 1:8 &
                        !is.na(df$p03) & df$p03 >= edadmin, 1L, 0L)

    # Empleo adecuado: condact == 1 (official INEC classification)
    df$adec <- NA_integer_
    df$adec[df$pean == 1] <- 0L
    df$adec[df$pean == 1 & df$condact_val == 1] <- 1L

    # Empleo (all employed): condact 1-6
    df$empleo <- NA_integer_
    df$empleo[df$pean == 1] <- 0L
    df$empleo[df$pean == 1 & df$condact_val %in% 1:6] <- 1L

    # Empleo no adecuado (subempleo + otro no pleno + no remunerado + no clasificado): condact 2-6
    df$inadec <- NA_integer_
    df$inadec[df$pean == 1 & df$empleo == 1] <- 0L
    df$inadec[df$pean == 1 & df$condact_val %in% 2:6] <- 1L

    # Desempleo (abierto + oculto): condact 7-8
    df$desem <- NA_integer_
    df$desem[df$pean == 1] <- 0L
    df$desem[df$pean == 1 & df$condact_val %in% 7:8] <- 1L

    # ====================================================================
    # Demographics
    # ====================================================================
    df$sexo <- case_when(
      as.numeric(df$p02) == 1 ~ "Hombre",
      as.numeric(df$p02) == 2 ~ "Mujer",
      TRUE ~ NA_character_
    )

    df$grupo_edad <- case_when(
      df$p03 >= 18 & df$p03 < 30 ~ "Jóvenes (18-29)",
      df$p03 >= 30 & df$p03 < 65 ~ "Adultos (30-64)",
      df$p03 >= 65 ~ "Adultos mayores (65+)",
      TRUE ~ NA_character_
    )

    df$nivel_educativo <- case_when(
      as.numeric(df$p10a) >= 8 ~ "Superior",
      as.numeric(df$p10a) %in% 1:7 ~ "Menos que superior",
      TRUE ~ NA_character_
    )

    df$etnia <- case_when(
      as.numeric(df$p15) == 1 ~ "Indígena",
      as.numeric(df$p15) %in% 2:6 ~ "No indígena",
      TRUE ~ NA_character_
    )

    # Filter to PEA only (rates are calculated as % of PEA)
    df_pea <- df %>%
      filter(pean == 1) %>%
      mutate(anio = year) %>%
      select(anio, area, sexo, etnia, nivel_educativo, grupo_edad,
             empleo, adec, inadec, desem, fw)

    data_list[[as.character(year)]] <- df_pea

    # Print diagnostics
    n_pea <- sum(df$pean == 1, na.rm = TRUE)
    n_emp <- sum(df$empleo == 1, na.rm = TRUE)
    n_adec <- sum(df$adec == 1, na.rm = TRUE)
    n_inadec <- sum(df$inadec == 1, na.rm = TRUE)
    n_desem <- sum(df$desem == 1, na.rm = TRUE)
    cat(sprintf("  PEA: %d | Emp: %d | Adec: %d | Inadec: %d | Desem: %d\n",
                n_pea, n_emp, n_adec, n_inadec, n_desem))
  } else {
    cat("  File not found for", year, "\n")
  }
}

# Combine all years
data_combined <- bind_rows(data_list)

# ========== Employment Time Series (rates as % of PEA) ==========
empleo_series <- data_combined %>%
  group_by(anio) %>%
  summarise(
    `Empleo adecuado` = weighted.mean(adec, w = fw, na.rm = TRUE) * 100,
    `Empleo no adecuado` = weighted.mean(inadec, w = fw, na.rm = TRUE) * 100,
    Desempleo = weighted.mean(desem, w = fw, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = -anio,
    names_to = "indicador",
    values_to = "valor"
  )

write_xlsx(
  list(Sheet1 = empleo_series),
  path = file.path(output_path, "empleo_series.xlsx")
)

# ========== Employment Scorecards (latest year) ==========
empleo_scorecard <- empleo_series %>%
  filter(anio == max(anio, na.rm = TRUE))

write_xlsx(
  list(Sheet1 = empleo_scorecard),
  path = file.path(output_path, "empleo_scorecard.xlsx")
)

# ========== Employment by Demographics ==========
# Function to calculate adequate employment rate by group
calc_empleo_group <- function(data, group_var, tipo) {
  data %>%
    filter(!is.na(!!sym(group_var))) %>%
    group_by(anio, categoria = !!sym(group_var)) %>%
    summarise(
      empleo_adecuado = weighted.mean(adec, w = fw, na.rm = TRUE) * 100,
      .groups = "drop"
    ) %>%
    mutate(tipo_categoria = tipo)
}

empleo_area <- data_combined %>%
  mutate(area_label = case_when(
    area == 1 ~ "Urbano",
    area == 2 ~ "Rural",
    TRUE ~ "Nacional"
  )) %>%
  calc_empleo_group("area_label", "area")

empleo_sexo <- calc_empleo_group(data_combined, "sexo", "sexo")
empleo_etnia <- calc_empleo_group(data_combined, "etnia", "etnia")
empleo_educacion <- calc_empleo_group(data_combined, "nivel_educativo", "educacion")
empleo_edad <- calc_empleo_group(data_combined, "grupo_edad", "edad")

empleo_demografico <- bind_rows(empleo_area, empleo_sexo, empleo_etnia,
                                 empleo_educacion, empleo_edad) %>%
  select(anio, tipo_categoria, categoria, empleo_adecuado)

write_xlsx(
  list(Sheet1 = empleo_demografico),
  path = file.path(output_path, "empleo_demografico.xlsx")
)

# ========== Statistical Variation with Survey Design ==========
# Recalculate with standard errors for significance testing
se_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))
  if (!file.exists(file_path)) next

  df <- read_dta(file_path)
  df <- haven::zap_labels(df)

  if (!"fw" %in% names(df) && "fexp" %in% names(df)) df$fw <- df$fexp
  df$p03 <- as.numeric(df$p03)

  # Use official condact variable
  condact_var <- find_condact(df)
  if (is.null(condact_var)) next

  df$condact_val <- as.numeric(df[[condact_var]])

  # PEA: condact 1-8 AND age >= edadmin
  df$pean <- ifelse(!is.na(df$condact_val) & df$condact_val %in% 1:8 &
                      !is.na(df$p03) & df$p03 >= edadmin, 1L, 0L)

  # Empleo adecuado from official classification
  df$adec <- NA_integer_
  df$adec[df$pean == 1] <- 0L
  df$adec[df$pean == 1 & df$condact_val == 1] <- 1L

  # Filter to PEA
  df_pea <- df %>% filter(pean == 1)

  # Survey design
  has_estrato <- "estrato" %in% names(df_pea)
  has_upm <- "upm" %in% names(df_pea)
  if (has_estrato && has_upm) {
    svy <- svydesign(ids = ~upm, strata = ~estrato, weights = ~fw, data = df_pea, nest = TRUE)
  } else {
    svy <- svydesign(ids = ~1, weights = ~fw, data = df_pea)
  }

  adec_mean <- svymean(~adec, svy, na.rm = TRUE)
  se_list[[as.character(year)]] <- data.frame(
    anio = year,
    indicador = "Empleo adecuado",
    valor = as.numeric(coef(adec_mean)) * 100,
    se = as.numeric(SE(adec_mean)) * 100
  )
}

se_results <- bind_rows(se_list)

variacion_empleo <- se_results %>%
  arrange(anio) %>%
  mutate(
    valor_anterior = lag(valor),
    se_anterior = lag(se),
    anio_anterior = lag(anio),
    variacion_pp = valor - valor_anterior,
    se_diff = sqrt(se^2 + se_anterior^2),
    t_stat = variacion_pp / se_diff,
    p_value = 2 * (1 - pnorm(abs(t_stat))),
    significativo = case_when(
      is.na(p_value) ~ NA_character_,
      p_value < 0.01 ~ "Sí (p<0.01)",
      p_value < 0.05 ~ "Sí (p<0.05)",
      p_value < 0.10 ~ "Marginal (p<0.10)",
      TRUE ~ "No"
    )
  ) %>%
  filter(!is.na(variacion_pp)) %>%
  select(anio, anio_anterior, indicador, valor, se, valor_anterior, se_anterior,
         variacion_pp, t_stat, p_value, significativo)

write_xlsx(
  list(Data = variacion_empleo),
  path = file.path(output_path, "variacion_empleo_significancia.xlsx")
)

# ========== IESS Affiliates (TOY DATA - not in ENEMDU) ==========
iess_afiliados <- data.frame(
  anio = years,
  afiliados = round(seq(2.1e6, 3.8e6, length.out = length(years)))
)

write_xlsx(
  list(Sheet1 = iess_afiliados),
  path = file.path(output_path, "iess_afiliados.xlsx")
)

# ========== Summary ==========
cat("\n✓ Generated employment datasets from ENEMDU (INEC methodology):\n")
cat("  - empleo_scorecard.xlsx\n")
cat("  - empleo_series.xlsx (", nrow(empleo_series), "rows )\n")
cat("  - empleo_demografico.xlsx (", nrow(empleo_demografico), "rows )\n")
cat("  - variacion_empleo_significancia.xlsx (", nrow(variacion_empleo), "rows )\n")
cat("  - iess_afiliados.xlsx (TOY DATA)\n")

# Print series for verification
cat("\nEmployment series (verification):\n")
empleo_series %>%
  pivot_wider(names_from = indicador, values_from = valor) %>%
  print(n = 20)

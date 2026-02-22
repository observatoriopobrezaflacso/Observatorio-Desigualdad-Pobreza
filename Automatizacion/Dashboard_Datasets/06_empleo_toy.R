# ============================================================================
# Script: Generate Employment Datasets from ENEMDU
# Purpose: Construct employment indicators following INEC methodology
#          (PET, PEA, empleo, empleo adecuado, subempleo, desempleo)
# Reference: Brechas_educativas/adec07_25_vf.do & condact_update_01-05.do
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

# SBU (Salario Básico Unificado) by year
# Source: BCE https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html
sbu <- data.frame(
  anio = 2007:2024,
  salmin = c(
    170,  # 2007
    200,  # 2008
    218,  # 2009
    240,  # 2010
    264,  # 2011
    292,  # 2012
    318,  # 2013
    340,  # 2014
    354,  # 2015
    366,  # 2016
    375,  # 2017
    386,  # 2018
    394,  # 2019
    400,  # 2020
    400,  # 2021
    425,  # 2022
    450,  # 2023
    460   # 2024
  )
)

edadmin <- 15  # Minimum working age

# Helper: safe subset assignment (wraps conditions in which() to handle NAs)
W <- function(...) {
  cond <- Reduce(`&`, list(...))
  which(cond)
}

years <- 2007:2024
data_list <- list()

for (year in years) {
  file_path <- file.path(income_path, paste0("ing_perca_", year, "_nac_precios2000.dta"))

  if (file.exists(file_path)) {
    cat("Processing", year, "...\n")
    df <- read_dta(file_path)
    df <- haven::zap_labels(df)

    salmin_year <- sbu$salmin[sbu$anio == year]

    # ====================================================================
    # Rename ing_lab -> ingrl if needed (some years use different names)
    # ====================================================================
    if (!"ingrl" %in% names(df) && "ing_lab" %in% names(df)) {
      df$ingrl <- df$ing_lab
    }

    # Use fexp as weight; some years have fw instead
    if (!"fexp" %in% names(df) && "fw" %in% names(df)) {
      df$fexp <- df$fw
    }
    if (!"fw" %in% names(df) && "fexp" %in% names(df)) {
      df$fw <- df$fexp
    }

    # ====================================================================
    # Check variable encoding for this year
    # p27: 2007-2014 has 2 categories (1=yes, 2=no)
    #       2015+ has 4 categories (1-3=yes options, 4=no)
    # p28: exists from 2015+
    # ====================================================================
    has_p28 <- "p28" %in% names(df)

    # Determine p27 encoding: check if max(p27) > 2
    p27_max <- suppressWarnings(max(as.numeric(df$p27), na.rm = TRUE))
    new_p27 <- !is.na(p27_max) && p27_max > 2  # TRUE = new methodology (4 categories)

    # ====================================================================
    # Clean missings (following Stata code)
    # ====================================================================
    df$p24 <- as.numeric(df$p24)
    df$p24[df$p24 == 999] <- NA

    if ("p51a" %in% names(df)) {
      df$p51a <- as.numeric(df$p51a)
      df$p51a[df$p51a == 999] <- NA
    }
    if ("p51b" %in% names(df)) {
      df$p51b <- as.numeric(df$p51b)
      df$p51b[df$p51b == 999] <- NA
    }
    if ("p51c" %in% names(df)) {
      df$p51c <- as.numeric(df$p51c)
      df$p51c[df$p51c == 999] <- NA
    }

    # Ensure numeric types for key variables
    df$p03 <- as.numeric(df$p03)
    df$p20 <- as.numeric(df$p20)
    df$p21 <- as.numeric(df$p21)
    df$p22 <- as.numeric(df$p22)
    df$p27 <- as.numeric(df$p27)
    if ("p32" %in% names(df)) df$p32 <- as.numeric(df$p32)
    if ("p34" %in% names(df)) df$p34 <- as.numeric(df$p34)
    if ("p35" %in% names(df)) df$p35 <- as.numeric(df$p35)
    if (has_p28) df$p28 <- as.numeric(df$p28)
    if ("p25" %in% names(df)) df$p25 <- as.numeric(df$p25)

    # Labor income
    df$ila <- as.numeric(df$ingrl)
    df$ila[df$ila == -1 | df$ila == 999999] <- NA

    # ====================================================================
    # 1. PET (Población en Edad de Trabajar): age >= 15
    # ====================================================================
    df$petn <- ifelse(!is.na(df$p03) & df$p03 >= edadmin, 1L, 0L)

    # ====================================================================
    # 2. PEA (Población Económicamente Activa)
    # Following INEC methodology from adec07_25_vf.do
    # ====================================================================
    df$pean <- NA_integer_
    df$pean[W(df$petn == 1)] <- 0L
    df$pean[W(df$petn == 1, df$p20 == 1)] <- 1L
    df$pean[W(df$petn == 1, df$p20 == 2, df$p21 <= 11)] <- 1L
    df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)] <- 1L
    if ("p32" %in% names(df)) {
      df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 <= 10)] <- 1L
      if ("p34" %in% names(df) && "p35" %in% names(df)) {
        df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 == 11, df$p34 <= 7, df$p35 == 1)] <- 1L
      }
    }

    # ====================================================================
    # 3. EMPLEO (Employed population within PEA)
    # ====================================================================
    df$empleo <- NA_integer_
    df$empleo[W(df$pean == 1)] <- 0L
    df$empleo[W(df$pean == 1, df$p20 == 1)] <- 1L
    df$empleo[W(df$pean == 1, df$p20 == 2, df$p21 <= 11)] <- 1L
    df$empleo[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)] <- 1L

    # ====================================================================
    # 4. DESEMPLEO (Unemployed = PEA - Empleo)
    # ====================================================================
    df$desem <- NA_integer_
    df$desem[W(df$pean == 1)] <- 0L
    if ("p32" %in% names(df)) {
      df$desem[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 <= 10)] <- 1L
      if ("p34" %in% names(df) && "p35" %in% names(df)) {
        df$desem[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 == 11, df$p34 <= 7, df$p35 == 1)] <- 1L
      }
    }

    # ====================================================================
    # 5. INCOME THRESHOLD (w): labor income >= SBU
    # ====================================================================
    df$w <- NA_integer_
    df$w[W(df$empleo == 1, !is.na(df$ila), df$ila < salmin_year)] <- 0L
    df$w[W(df$empleo == 1, !is.na(df$ila), df$ila >= salmin_year)] <- 1L

    # ====================================================================
    # 6. HOURS THRESHOLD (t): hours >= 40 (or >= 30 for ages 12-17)
    # ====================================================================
    df$horas <- NA_real_
    df$horas[W(df$empleo == 1)] <- 0

    # Effective hours: employed and working
    i1 <- W(df$pean == 1, df$p20 == 1)
    df$horas[i1] <- df$p24[i1]
    i2 <- W(df$pean == 1, df$p20 == 2, df$p21 <= 11)
    df$horas[i2] <- df$p24[i2]

    # Habitual hours: employed but not working this week (has job but absent)
    if (all(c("p51a", "p51b", "p51c") %in% names(df))) {
      df$hh <- rowSums(df[, c("p51a", "p51b", "p51c")], na.rm = FALSE)
      df$hh[!is.na(df$hh) & df$hh < 0] <- NA
      i3 <- W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)
      df$horas[i3] <- df$hh[i3]
    }

    # Time threshold
    df$t <- NA_integer_
    df$t[W(df$empleo == 1, !is.na(df$horas), df$horas < 40)] <- 0L
    df$t[W(df$empleo == 1, !is.na(df$horas), df$horas >= 40)] <- 1L
    # Adjustment for minors (12-17): threshold is 30 hours
    df$t[W(df$empleo == 1, !is.na(df$horas), df$horas < 30, df$p03 >= 12, df$p03 <= 17)] <- 0L
    df$t[W(df$empleo == 1, !is.na(df$horas), df$horas >= 30, df$p03 >= 12, df$p03 <= 17)] <- 1L

    # ====================================================================
    # 7. DESIRE AND AVAILABILITY (d_d)
    # ====================================================================
    df$d_d <- NA_integer_
    df$d_d[W(df$empleo == 1)] <- 0L

    if (new_p27) {
      # New methodology (2015+): p27 has 4 categories, p28 exists
      if ("p25" %in% names(df)) {
        df$d_d[W(df$empleo == 1, df$p25 == 9 | df$p27 == 4)] <- 0L
      } else {
        df$d_d[W(df$empleo == 1, df$p27 == 4)] <- 0L
      }
      if (has_p28) {
        df$d_d[W(df$empleo == 1, df$p27 <= 3, df$p28 == 1)] <- 1L
      } else {
        df$d_d[W(df$empleo == 1, df$p27 <= 3)] <- 1L
      }
    } else {
      # Old methodology (2007-2014): p27 has 2 categories (1=yes, 2=no)
      df$d_d[W(df$empleo == 1, df$p27 == 2)] <- 0L
      df$d_d[W(df$empleo == 1, df$p27 == 1)] <- 1L
    }

    # ====================================================================
    # 8. EMPLEO ADECUADO
    # Adequate = employed AND income >= SBU AND (hours >= 40 OR doesn't want more)
    # ====================================================================
    df$adec <- NA_integer_
    df$adec[W(df$pean == 1, df$p03 >= edadmin)] <- 0L
    df$adec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1, df$w == 1, df$t == 1)] <- 1L
    df$adec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1, df$w == 1, df$t == 0, df$d_d == 0)] <- 1L

    # ====================================================================
    # 9. EMPLEO NO ADECUADO (inadequate = employed - adequate)
    # ====================================================================
    df$inadec <- NA_integer_
    df$inadec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1)] <- 0L
    df$inadec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1, df$adec == 0)] <- 1L

    # ====================================================================
    # Demographics (correct variable mappings)
    # ====================================================================
    df$sexo <- case_when(
      df$p02 == 1 ~ "Hombre",
      df$p02 == 2 ~ "Mujer",
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
      filter(pean == 1 & p03 >= edadmin) %>%
      mutate(anio = year) %>%
      select(anio, area, sexo, etnia, nivel_educativo, grupo_edad,
             empleo, adec, inadec, desem, fw)

    data_list[[as.character(year)]] <- df_pea

    # Print diagnostics
    n_pea <- sum(df$pean == 1 & df$p03 >= edadmin, na.rm = TRUE)
    n_emp <- sum(df$empleo == 1 & df$p03 >= edadmin, na.rm = TRUE)
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

  salmin_year <- sbu$salmin[sbu$anio == year]

  # Same processing as above (abbreviated)
  if (!"ingrl" %in% names(df) && "ing_lab" %in% names(df)) df$ingrl <- df$ing_lab
  if (!"fw" %in% names(df) && "fexp" %in% names(df)) df$fw <- df$fexp

  has_p28 <- "p28" %in% names(df)
  p27_max <- suppressWarnings(max(as.numeric(df$p27), na.rm = TRUE))
  new_p27 <- !is.na(p27_max) && p27_max > 2

  df$p24 <- as.numeric(df$p24); df$p24[df$p24 == 999] <- NA
  df$p03 <- as.numeric(df$p03); df$p20 <- as.numeric(df$p20)
  df$p21 <- as.numeric(df$p21); df$p22 <- as.numeric(df$p22)
  df$p27 <- as.numeric(df$p27)
  if ("p32" %in% names(df)) df$p32 <- as.numeric(df$p32)
  if ("p34" %in% names(df)) df$p34 <- as.numeric(df$p34)
  if ("p35" %in% names(df)) df$p35 <- as.numeric(df$p35)
  if (has_p28) df$p28 <- as.numeric(df$p28)
  if ("p25" %in% names(df)) df$p25 <- as.numeric(df$p25)
  if ("p51a" %in% names(df)) { df$p51a <- as.numeric(df$p51a); df$p51a[df$p51a == 999] <- NA }
  if ("p51b" %in% names(df)) { df$p51b <- as.numeric(df$p51b); df$p51b[df$p51b == 999] <- NA }
  if ("p51c" %in% names(df)) { df$p51c <- as.numeric(df$p51c); df$p51c[df$p51c == 999] <- NA }

  df$ila <- as.numeric(df$ingrl); df$ila[df$ila == -1 | df$ila == 999999] <- NA

  # PET, PEA, Empleo (same methodology as main loop, using W() for safe indexing)
  df$petn <- ifelse(!is.na(df$p03) & df$p03 >= edadmin, 1L, 0L)
  df$pean <- NA_integer_; df$pean[W(df$petn == 1)] <- 0L
  df$pean[W(df$petn == 1, df$p20 == 1)] <- 1L
  df$pean[W(df$petn == 1, df$p20 == 2, df$p21 <= 11)] <- 1L
  df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)] <- 1L
  if ("p32" %in% names(df)) {
    df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 <= 10)] <- 1L
    if ("p34" %in% names(df) && "p35" %in% names(df))
      df$pean[W(df$petn == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 == 11, df$p34 <= 7, df$p35 == 1)] <- 1L
  }
  df$empleo <- NA_integer_; df$empleo[W(df$pean == 1)] <- 0L
  df$empleo[W(df$pean == 1, df$p20 == 1)] <- 1L
  df$empleo[W(df$pean == 1, df$p20 == 2, df$p21 <= 11)] <- 1L
  df$empleo[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)] <- 1L

  df$desem <- NA_integer_; df$desem[W(df$pean == 1)] <- 0L
  if ("p32" %in% names(df)) {
    df$desem[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 <= 10)] <- 1L
    if ("p34" %in% names(df) && "p35" %in% names(df))
      df$desem[W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 2, df$p32 == 11, df$p34 <= 7, df$p35 == 1)] <- 1L
  }

  # Income, hours, desire thresholds
  df$w <- NA_integer_
  df$w[W(df$empleo == 1, !is.na(df$ila), df$ila < salmin_year)] <- 0L
  df$w[W(df$empleo == 1, !is.na(df$ila), df$ila >= salmin_year)] <- 1L

  df$horas <- NA_real_; df$horas[W(df$empleo == 1)] <- 0
  i1 <- W(df$pean == 1, df$p20 == 1); df$horas[i1] <- df$p24[i1]
  i2 <- W(df$pean == 1, df$p20 == 2, df$p21 <= 11); df$horas[i2] <- df$p24[i2]
  if (all(c("p51a", "p51b", "p51c") %in% names(df))) {
    df$hh <- rowSums(df[, c("p51a", "p51b", "p51c")], na.rm = FALSE)
    df$hh[!is.na(df$hh) & df$hh < 0] <- NA
    i3 <- W(df$pean == 1, df$p20 == 2, df$p21 == 12, df$p22 == 1)
    df$horas[i3] <- df$hh[i3]
  }

  df$t <- NA_integer_
  df$t[W(df$empleo == 1, !is.na(df$horas), df$horas < 40)] <- 0L
  df$t[W(df$empleo == 1, !is.na(df$horas), df$horas >= 40)] <- 1L
  df$t[W(df$empleo == 1, !is.na(df$horas), df$horas < 30, df$p03 >= 12, df$p03 <= 17)] <- 0L
  df$t[W(df$empleo == 1, !is.na(df$horas), df$horas >= 30, df$p03 >= 12, df$p03 <= 17)] <- 1L

  df$d_d <- NA_integer_; df$d_d[W(df$empleo == 1)] <- 0L
  if (new_p27) {
    if ("p25" %in% names(df)) df$d_d[W(df$empleo == 1, df$p25 == 9 | df$p27 == 4)] <- 0L
    else df$d_d[W(df$empleo == 1, df$p27 == 4)] <- 0L
    if (has_p28) df$d_d[W(df$empleo == 1, df$p27 <= 3, df$p28 == 1)] <- 1L
    else df$d_d[W(df$empleo == 1, df$p27 <= 3)] <- 1L
  } else {
    df$d_d[W(df$empleo == 1, df$p27 == 2)] <- 0L
    df$d_d[W(df$empleo == 1, df$p27 == 1)] <- 1L
  }

  df$adec <- NA_integer_
  df$adec[W(df$pean == 1, df$p03 >= edadmin)] <- 0L
  df$adec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1, df$w == 1, df$t == 1)] <- 1L
  df$adec[W(df$pean == 1, df$p03 >= edadmin, df$empleo == 1, df$w == 1, df$t == 0, df$d_d == 0)] <- 1L

  # Filter to PEA age 15+
  df_pea <- df %>% filter(pean == 1 & p03 >= edadmin)

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

# ============================================================================
# Script: Generate National-Level Poverty Significance (Pobreza, Extrema, NBI)
# Purpose: Year-over-year t-tests for poverty indicators at national level
# Output: variacion_pobreza_significancia.xlsx (overwrites existing)
# ============================================================================

library(haven)
library(dplyr)
library(readxl)
library(writexl)
library(survey)

# --- Paths ---
enemdu_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/enemdu_diciembres"
nbi_base_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Procesamiento/Bases/ENEMDU/ENEMDU - copia"
output_path <- "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final"

years <- 2008:2024

# --- Helper: create survey design ---
create_survey_design <- function(df) {
  has_estrato <- "estrato" %in% names(df)
  has_upm <- "upm" %in% names(df)

  if (has_estrato && has_upm) {
    svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = df, nest = TRUE)
  } else {
    svydesign(ids = ~1, weights = ~fexp, data = df)
  }
}

# ====================================================================
# PART 1: Pobreza & Pobreza Extrema (national level)
# ====================================================================
cat("=== PART 1: Pobreza & Pobreza Extrema ===\n")

pov_results <- list()

for (year in years) {
  file <- file.path(enemdu_path, paste0("empleo", year, ".dta"))
  if (!file.exists(file)) {
    cat("  File not found:", file, "\n")
    next
  }

  cat("  Processing", year, "...\n")
  df <- read_dta(file)
  df <- haven::zap_labels(df)

  # Ensure required variables exist
  if (!all(c("pobreza", "fexp") %in% names(df))) {
    cat("    Missing pobreza/fexp variables, skipping\n")
    next
  }

  # Poverty indicator (already coded as 0/1 in the data)
  df <- df %>%
    filter(!is.na(pobreza), !is.na(fexp), fexp > 0)

  # Also get epobreza if available
  has_epobreza <- "epobreza" %in% names(df)

  svy <- create_survey_design(df)

  # National poverty rate
  pov_mean <- svymean(~pobreza, svy, na.rm = TRUE)
  pov_results[[paste0(year, "_pob")]] <- data.frame(
    anio = year,
    indicador = "Pobreza",
    valor = as.numeric(coef(pov_mean)) * 100,
    se = as.numeric(SE(pov_mean)) * 100
  )

  # National extreme poverty rate
  if (has_epobreza) {
    df_ext <- df %>% filter(!is.na(epobreza))
    svy_ext <- create_survey_design(df_ext)
    ext_mean <- svymean(~epobreza, svy_ext, na.rm = TRUE)
    pov_results[[paste0(year, "_ext")]] <- data.frame(
      anio = year,
      indicador = "Pobreza extrema",
      valor = as.numeric(coef(ext_mean)) * 100,
      se = as.numeric(SE(ext_mean)) * 100
    )
  }
}

pov_df <- bind_rows(pov_results)
cat("  Poverty/Extreme poverty records:", nrow(pov_df), "\n")

# ====================================================================
# PART 2: NBI (national level, person-level analysis per INEC methodology)
# Reference: Sintaxis_ NBI 2010 FINAL_CPV.spc (Census syntax adapted for ENEMDU)
# NBI is identified at household level, analyzed at person level
# Dimensions (Census → ENEMDU mapping):
#   1. MATERIAL: vi04a >= 7 (tierra/otro) OR vi05a >= 6 (caña no revestida/estera, otro)
#   2. HACINAMIENTO: n_personas/vi07 > 3; vi07=0 & n>3
#   3. SERVICIO: vi09 >= 3 (pozo ciego/letrina/no tiene) OR vi10 >= agua_thresh
#      Water threshold: >= 5 for 2008-2010 (old questionnaire), >= 4 for 2011+
#   4. ESCOLAR: p03 6-12 AND p07=2 (child not attending school)
#   5. DEPENDENCIA: condactn 1-6 (employed, new classification); escolaridad <= 2 for head
# ====================================================================
cat("\n=== PART 2: NBI ===\n")

# Helper to find files by pattern in a directory
find_file <- function(dir_path, patterns) {
  for (pat in patterns) {
    matches <- list.files(dir_path, pattern = pat, full.names = TRUE, ignore.case = TRUE)
    if (length(matches) > 0) return(matches[1])
  }
  return(NULL)
}

# Compute years of schooling from p10a (nivel) and p10b (año aprobado)
# Mapped from Census ESCONBI: Census ESCONBI <= 3 ≈ ENEMDU escolaridad <= 2
compute_schooling_years <- function(p10a, p10b) {
  p10b_safe <- ifelse(is.na(p10b) | p10b == 99, 0, p10b)
  case_when(
    is.na(p10a) ~ NA_real_,
    p10a == 1 ~ 0,                         # Ninguno
    p10a == 2 ~ pmin(p10b_safe, 3),         # Centro alfabetización
    p10a == 3 ~ 0,                         # Jardín de infantes
    p10a == 4 ~ p10b_safe,                  # Primaria (1-6 years)
    p10a == 5 ~ p10b_safe,                  # Educación Básica (1-10 years)
    p10a == 6 ~ 6 + p10b_safe,              # Secundaria (6 primary + years)
    p10a == 7 ~ 10 + p10b_safe,             # Educación Media (10 básica + years)
    p10a %in% c(8, 9) ~ 12 + p10b_safe,    # Superior
    p10a == 10 ~ 16 + p10b_safe,            # Post-grado
    TRUE ~ NA_real_
  )
}

# Detect servicio higiénico and agua variable names by label
# (handles 2017 where variable numbering shifted: vi13=sanitario, vi16=agua)
detect_service_vars <- function(vh_file) {
  vh_raw <- read_dta(vh_file)
  sanitario_var <- NULL
  agua_var <- NULL
  for (v in names(vh_raw)) {
    lbl <- tolower(as.character(attr(vh_raw[[v]], "label")))
    if (is.null(lbl) || length(lbl) == 0) next
    if (grepl("tipo.*servicio higi", lbl) && is.null(sanitario_var)) sanitario_var <- tolower(v)
    if (grepl("d[oó]nde.*obtiene.*agua|obtiene.*agua.*principal", lbl) && is.null(agua_var)) agua_var <- tolower(v)
  }
  list(sanitario = sanitario_var, agua = agua_var)
}

nbi_results <- list()

for (year in years) {
  dec_dir <- file.path(nbi_base_path, year, "12")
  if (!dir.exists(dec_dir)) {
    cat("  Directory not found:", dec_dir, "\n")
    next
  }

  cat("  Processing NBI", year, "...\n")

  # --- Find vivienda_hogar file ---
  vh_patterns <- c(
    paste0("^", year, "12_EnemduBDD_viviendahogar\\.dta$"),
    paste0("^", year, "12.*vivi[v]?endahogar.*\\.dta$"),
    paste0("^enemdu_viv_hog_", year, "12\\.dta$"),
    paste0("^enemdu_vivienda_hogar_", year, "_12\\.dta$"),
    "vivienda.*hogar.*\\.dta$",
    "viv.*hog.*\\.dta$"
  )
  vh_file <- find_file(dec_dir, vh_patterns)

  # --- Find persona file ---
  per_patterns <- c(
    paste0("^", year, "12_EnemduBDD_15anios\\.dta$"),
    paste0("^", year, "12_EnemduBDD_per\\.dta$"),
    paste0("^12", year, "_EnemduBDD_per\\.dta$"),
    paste0("^enemdu_persona_", year, "12\\.dta$"),
    paste0("^enemdu_persona_", year, "_12\\.dta$"),
    "persona.*\\.dta$",
    "15anios.*\\.dta$"
  )
  per_file <- find_file(dec_dir, per_patterns)

  if (is.null(vh_file)) {
    cat("    VH file not found in", dec_dir, "\n")
    next
  }
  if (is.null(per_file)) {
    cat("    Persona file not found in", dec_dir, "\n")
    next
  }

  cat("    VH:", basename(vh_file), "\n")
  cat("    Persona:", basename(per_file), "\n")

  tryCatch({
    # Detect variable names for servicios BEFORE zapping labels
    svc_vars <- detect_service_vars(vh_file)
    san_col <- ifelse(!is.null(svc_vars$sanitario), svc_vars$sanitario, "vi09")
    agua_col <- ifelse(!is.null(svc_vars$agua), svc_vars$agua, "vi10")
    cat("    Servicios vars: san=", san_col, " agua=", agua_col, "\n")

    vh <- read_dta(vh_file) %>% haven::zap_labels()
    per <- read_dta(per_file) %>% haven::zap_labels()

    names(vh) <- tolower(names(vh))
    names(per) <- tolower(names(per))
    names(vh) <- make.unique(names(vh))
    names(per) <- make.unique(names(per))

    # Determine merge keys
    if ("id_hogar" %in% names(vh) && "id_hogar" %in% names(per)) {
      merge_keys <- "id_hogar"
    } else {
      merge_keys <- intersect(
        intersect(names(per), names(vh)),
        c("ciudad", "zona", "sector", "panelm", "vivienda", "hogar")
      )
      if (length(merge_keys) < 3) {
        cat("    Cannot determine merge keys, skipping\n")
        next
      }
    }

    # Drop overlapping columns from vh (keep merge keys + vi* + fexp)
    overlap <- setdiff(intersect(names(per), names(vh)), merge_keys)
    if ("fexp" %in% overlap) {
      names(vh)[names(vh) == "fexp"] <- "fexp_vh"
      overlap <- setdiff(overlap, "fexp")
    }
    vh_slim <- vh[, !(names(vh) %in% overlap), drop = FALSE]

    merged <- merge(as.data.frame(per), as.data.frame(vh_slim),
                     by = merge_keys, all.x = TRUE, suffixes = c("", "_vh2"))
    names(merged) <- make.unique(names(merged))

    # --- Determine fexp ---
    fexp_col <- if ("fexp" %in% names(merged)) "fexp"
                else if ("fexp_vh" %in% names(merged)) "fexp_vh"
                else NULL
    if (is.null(fexp_col)) {
      cat("    No fexp found, skipping\n")
      next
    }
    merged$fw <- merged[[fexp_col]]
    merged <- merged %>% filter(!is.na(fw), fw > 0)

    # --- Household ID columns ---
    hh_id_cols <- if ("id_hogar" %in% names(merged)) "id_hogar"
                  else intersect(names(merged), c("ciudad", "zona", "sector", "panelm", "vivienda", "hogar"))

    # === NBI DIMENSIONS (Census CPV syntax adapted for ENEMDU) ===

    # 1. MATERIAL: floor deficient if tierra (7) or otro (8); walls if caña/estera (6) or otro (7)
    merged$nbi_vivienda <- 0
    if ("vi04a" %in% names(merged)) {
      merged$nbi_vivienda <- ifelse(!is.na(merged$vi04a) & merged$vi04a >= 7, 1, 0)
    }
    if ("vi05a" %in% names(merged)) {
      merged$nbi_vivienda <- ifelse(
        merged$nbi_vivienda == 1 | (!is.na(merged$vi05a) & merged$vi05a >= 6),
        1, merged$nbi_vivienda
      )
    }

    # 2. HACINAMIENTO: Census TOTPER / H01 > 3; if H01=0: deficient only if TOTPER > 3
    #    ENEMDU: vi07 = dormitorios (NOT vi06 = cuartos)
    if ("vi07" %in% names(merged)) {
      hh_size <- merged %>%
        group_by(across(all_of(hh_id_cols))) %>%
        mutate(n_personas = n()) %>%
        ungroup()

      merged$n_personas <- hh_size$n_personas
      merged$nbi_hacinamiento <- ifelse(
        !is.na(merged$vi07) & merged$vi07 != 99 & (
          (merged$vi07 > 0 & (merged$n_personas / merged$vi07) > 3) |
          (merged$vi07 == 0 & merged$n_personas > 3)
        ),
        1, 0
      )
    } else {
      merged$nbi_hacinamiento <- 0
    }

    # 3. SERVICIO: Census V07 > 1 (sanitation) OR V08 > 1 (water)
    #    ENEMDU adaptation (Census has coarser coding):
    #    Sanitation: vi09 >= 3 (pozo ciego, letrina, no tiene = deficient)
    #    Water: vi10 >= threshold (varies by period: >= 5 for 2007-2010, >= 4 for 2011+)
    #    2017 uses vi13 for sanitation and vi16 for water (detected by label)
    agua_threshold <- ifelse(year <= 2010, 5, 4)
    merged$nbi_servicios <- 0
    if (san_col %in% names(merged)) {
      merged$nbi_servicios <- ifelse(
        !is.na(merged[[san_col]]) & merged[[san_col]] >= 3,
        1, merged$nbi_servicios
      )
    }
    if (agua_col %in% names(merged)) {
      merged$nbi_servicios <- ifelse(
        merged$nbi_servicios == 1 | (!is.na(merged[[agua_col]]) & merged[[agua_col]] >= agua_threshold),
        1, merged$nbi_servicios
      )
    }

    # 4. ESCOLAR: Census P03 > 5 AND P03 <= 12 AND P21 = 2
    #    ENEMDU: p03 >= 6 & p03 <= 12 & p07 == 2
    if (all(c("p03", "p07") %in% names(merged))) {
      child_not_attending <- merged %>%
        mutate(child_not_school = ifelse(
          !is.na(p03) & p03 >= 6 & p03 <= 12 & !is.na(p07) & p07 == 2, 1, 0
        )) %>%
        group_by(across(all_of(hh_id_cols))) %>%
        mutate(nbi_escolar = max(child_not_school, na.rm = TRUE)) %>%
        ungroup()

      merged$nbi_escolar <- child_not_attending$nbi_escolar
    } else {
      merged$nbi_escolar <- 0
    }

    # 5. DEPENDENCIA: head has <= 2 years schooling AND (members/employed > 3 OR no employed)
    #    Employment: use condactn (new classification, values 1-6) when available.
    #    Pre-2017 files have both CONDACT (old) and CONDACTN (new) — the old CONDACT
    #    uses different value coding (0-3 = employed) that doesn't match the new one.
    if (all(c("p04", "p10a") %in% names(merged))) {
      p10b_col <- if ("p10b" %in% names(merged)) merged$p10b else rep(0, nrow(merged))
      merged$escolaridad <- compute_schooling_years(merged$p10a, p10b_col)

      if ("condactn" %in% names(merged)) {
        merged$is_employed <- ifelse(!is.na(merged$condactn) & merged$condactn %in% 1:6, 1, 0)
      } else if ("condact" %in% names(merged)) {
        merged$is_employed <- ifelse(!is.na(merged$condact) & merged$condact %in% 1:6, 1, 0)
      } else {
        merged$is_employed <- 0
        for (inc_var in c("ingrl", "p63", "p66", "p69")) {
          if (inc_var %in% names(merged)) {
            merged$is_employed <- ifelse(
              merged$is_employed == 1 | (!is.na(merged[[inc_var]]) & merged[[inc_var]] > 0),
              1, merged$is_employed
            )
          }
        }
      }

      dep_data <- merged %>%
        group_by(across(all_of(hh_id_cols))) %>%
        mutate(
          head_low_educ = any(p04 == 1 & !is.na(escolaridad) & escolaridad <= 2, na.rm = TRUE),
          n_members = n(),
          n_employed = sum(is_employed, na.rm = TRUE),
          dep_ratio = ifelse(n_employed > 0, n_members / n_employed, n_members),
          nbi_dependencia = ifelse(head_low_educ & (dep_ratio > 3 | n_employed == 0), 1, 0)
        ) %>%
        ungroup()

      merged$nbi_dependencia <- dep_data$nbi_dependencia
    } else {
      merged$nbi_dependencia <- 0
    }

    # NBI = at least 1 unsatisfied need (Census: NBIFIN = 1 if NBI1 >= 1)
    merged$nbi <- ifelse(
      merged$nbi_vivienda == 1 | merged$nbi_hacinamiento == 1 |
      merged$nbi_servicios == 1 | merged$nbi_escolar == 1 |
      merged$nbi_dependencia == 1,
      1, 0
    )

    # Person-level analysis (Census: TALLY HOGAR.TOTPER)
    merged$fexp <- merged$fw
    svy_per <- create_survey_design(merged)

    nbi_mean <- svymean(~nbi, svy_per, na.rm = TRUE)
    nbi_results[[as.character(year)]] <- data.frame(
      anio = year,
      indicador = "NBI",
      valor = as.numeric(coef(nbi_mean)) * 100,
      se = as.numeric(SE(nbi_mean)) * 100
    )
    cat("    NBI rate:", round(as.numeric(coef(nbi_mean)) * 100, 1), "%\n")

  }, error = function(e) {
    cat("    ERROR:", conditionMessage(e), "\n")
  })
}

nbi_df <- bind_rows(nbi_results)
cat("  NBI records:", nrow(nbi_df), "\n")

# ====================================================================
# PART 3: Combine & compute year-over-year significance
# ====================================================================
cat("\n=== Computing year-over-year significance ===\n")

all_results <- bind_rows(pov_df, nbi_df) %>%
  mutate(dimension = "Nacional", nivel = "Nacional")

variacion <- all_results %>%
  arrange(indicador, anio) %>%
  group_by(indicador) %>%
  mutate(
    valor_anterior = lag(valor),
    se_anterior = lag(se),
    anio_anterior = lag(anio),
    variacion_pp = valor - valor_anterior,
    variacion_pct = (valor - valor_anterior) / valor_anterior * 100,
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
  select(anio, anio_anterior, dimension, nivel, indicador,
         valor, se, valor_anterior, se_anterior,
         variacion_pp, variacion_pct, t_stat, p_value, significativo) %>%
  ungroup()

# Also keep the existing education/age results from 05_variacion_estadistica.R
# by reading the existing file and appending our Nacional rows
existing_file <- file.path(output_path, "variacion_pobreza_significancia.xlsx")
if (file.exists(existing_file)) {
  existing <- read_excel(existing_file)
  # Remove any existing Nacional rows
  existing <- existing %>% filter(!(dimension == "Nacional" & nivel == "Nacional"))
  # Combine
  final <- bind_rows(existing, variacion)
} else {
  final <- variacion
}

write_xlsx(list(Data = final), path = existing_file)

cat("\n✓ Generated:", existing_file, "\n")
cat("  Total rows:", nrow(final), "\n")
cat("  Nacional rows:", nrow(variacion), "\n")
cat("  Indicators:", paste(unique(variacion$indicador), collapse = ", "), "\n")
cat("  Years:", paste(range(variacion$anio), collapse = "-"), "\n")

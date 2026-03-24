library(haven)
library(dplyr)
library(survey)

create_survey_design <- function(df) {
  has_estrato <- "estrato" %in% names(df)
  has_upm <- "upm" %in% names(df)
  if (has_estrato && has_upm) {
    svydesign(ids = ~upm, strata = ~estrato, weights = ~fexp, data = df, nest = TRUE)
  } else {
    svydesign(ids = ~1, weights = ~fexp, data = df)
  }
}
find_file <- function(dir_path, patterns) {
  for (pat in patterns) {
    m <- list.files(dir_path, pattern = pat, full.names = TRUE, ignore.case = TRUE)
    if (length(m) > 0) return(m[1])
  }; return(NULL)
}
compute_schooling_years <- function(p10a, p10b) {
  p10b_safe <- ifelse(is.na(p10b) | p10b == 99, 0, p10b)
  case_when(is.na(p10a) ~ NA_real_, p10a == 1 ~ 0, p10a == 2 ~ pmin(p10b_safe, 3), p10a == 3 ~ 0,
    p10a == 4 ~ p10b_safe, p10a == 5 ~ p10b_safe, p10a == 6 ~ 6 + p10b_safe, p10a == 7 ~ 10 + p10b_safe,
    p10a %in% c(8, 9) ~ 12 + p10b_safe, p10a == 10 ~ 16 + p10b_safe, TRUE ~ NA_real_)
}
detect_service_vars <- function(vh_file) {
  vh_raw <- read_dta(vh_file); sanitario_var <- NULL; agua_var <- NULL
  for (v in names(vh_raw)) {
    lbl <- tolower(as.character(attr(vh_raw[[v]], "label")))
    if (is.null(lbl) || length(lbl) == 0) next
    if (grepl("tipo.*servicio higi", lbl) && is.null(sanitario_var)) sanitario_var <- tolower(v)
    if (grepl("d[oó]nde.*obtiene.*agua|obtiene.*agua.*principal", lbl) && is.null(agua_var)) agua_var <- tolower(v)
  }; list(sanitario = sanitario_var, agua = agua_var)
}

nbi_base_path <- "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Procesamiento/Bases/ENEMDU/ENEMDU - copia"
official <- c("2010"=41.8, "2011"=39.4, "2012"=36.8, "2013"=38.7, "2014"=35.4, "2015"=32.9, "2016"=32.0,
  "2017"=31.8, "2018"=33.5, "2019"=34.2, "2020"=33.2, "2021"=33.2, "2022"=31.4, "2023"=30.8, "2024"=32.4)

cat(sprintf("%-6s %-10s %-10s %-10s\n", "Year", "Mine", "Official", "Diff"))

for (year in 2007:2024) {
  dec_dir <- file.path(nbi_base_path, year, "12")
  if (!dir.exists(dec_dir)) next
  vh_patterns <- c(paste0("^", year, "12_EnemduBDD_viviendahogar\\.dta$"), paste0("^", year, "12.*vivi[v]?endahogar.*\\.dta$"),
    paste0("^enemdu_viv_hog_", year, "12\\.dta$"), paste0("^enemdu_vivienda_hogar_", year, "_12\\.dta$"),
    "vivienda.*hogar.*\\.dta$", "viv.*hog.*\\.dta$")
  per_patterns <- c(paste0("^", year, "12_EnemduBDD_15anios\\.dta$"), paste0("^", year, "12_EnemduBDD_per\\.dta$"),
    paste0("^12", year, "_EnemduBDD_per\\.dta$"), paste0("^enemdu_persona_", year, "12\\.dta$"),
    paste0("^enemdu_persona_", year, "_12\\.dta$"), "persona.*\\.dta$", "15anios.*\\.dta$")
  vh_file <- find_file(dec_dir, vh_patterns); per_file <- find_file(dec_dir, per_patterns)
  if (is.null(vh_file) || is.null(per_file)) next

  tryCatch({
    svc_vars <- detect_service_vars(vh_file)
    san_col <- ifelse(!is.null(svc_vars$sanitario), svc_vars$sanitario, "vi09")
    agua_col <- ifelse(!is.null(svc_vars$agua), svc_vars$agua, "vi10")
    vh <- read_dta(vh_file) %>% haven::zap_labels(); per <- read_dta(per_file) %>% haven::zap_labels()
    names(vh) <- tolower(names(vh)); names(per) <- tolower(names(per))
    names(vh) <- make.unique(names(vh)); names(per) <- make.unique(names(per))
    if ("id_hogar" %in% names(vh) && "id_hogar" %in% names(per)) { merge_keys <- "id_hogar"
    } else { merge_keys <- intersect(intersect(names(per), names(vh)), c("ciudad","zona","sector","panelm","vivienda","hogar")) }
    overlap <- setdiff(intersect(names(per), names(vh)), merge_keys)
    if ("fexp" %in% overlap) { names(vh)[names(vh) == "fexp"] <- "fexp_vh"; overlap <- setdiff(overlap, "fexp") }
    vh_slim <- vh[, !(names(vh) %in% overlap), drop = FALSE]
    merged <- merge(as.data.frame(per), as.data.frame(vh_slim), by = merge_keys, all.x = TRUE, suffixes = c("", "_vh2"))
    names(merged) <- make.unique(names(merged))
    fexp_col <- ifelse("fexp" %in% names(merged), "fexp", "fexp_vh")
    merged$fw <- merged[[fexp_col]]; merged <- merged %>% filter(!is.na(fw), fw > 0)
    hh_id_cols <- if ("id_hogar" %in% names(merged)) { "id_hogar" } else { intersect(names(merged), c("ciudad","zona","sector","panelm","vivienda","hogar")) }

    # 1. MATERIAL
    merged$nbi_vivienda <- 0
    if ("vi04a" %in% names(merged)) merged$nbi_vivienda <- ifelse(!is.na(merged$vi04a) & merged$vi04a > 5, 1, 0)
    if ("vi05a" %in% names(merged)) merged$nbi_vivienda <- ifelse(merged$nbi_vivienda == 1 | (!is.na(merged$vi05a) & merged$vi05a > 5), 1, merged$nbi_vivienda)

    # 2. HACINAMIENTO
    if ("vi07" %in% names(merged)) {
      hh_size <- merged %>% group_by(across(all_of(hh_id_cols))) %>% mutate(n_personas = n()) %>% ungroup()
      merged$n_personas <- hh_size$n_personas
      merged$nbi_hacinamiento <- ifelse(!is.na(merged$vi07) & merged$vi07 != 99 &
        ((merged$vi07 > 0 & (merged$n_personas / merged$vi07) > 3) | (merged$vi07 == 0 & merged$n_personas > 3)), 1, 0)
    } else { merged$nbi_hacinamiento <- 0 }

    # 3. SERVICIOS
    # Water threshold: >= 5 for 2007-2010, >= 4 for 2011+
    agua_threshold <- ifelse(year <= 2010, 5, 4)
    merged$nbi_servicios <- 0
    if (san_col %in% names(merged)) merged$nbi_servicios <- ifelse(!is.na(merged[[san_col]]) & merged[[san_col]] >= 3, 1, 0)
    if (agua_col %in% names(merged)) merged$nbi_servicios <- ifelse(merged$nbi_servicios == 1 | (!is.na(merged[[agua_col]]) & merged[[agua_col]] >= agua_threshold), 1, merged$nbi_servicios)

    # 4. ESCOLAR
    if (all(c("p03", "p07") %in% names(merged))) {
      child_data <- merged %>% mutate(cns = ifelse(!is.na(p03) & p03 >= 6 & p03 <= 12 & !is.na(p07) & p07 == 2, 1, 0)) %>%
        group_by(across(all_of(hh_id_cols))) %>% mutate(nbi_escolar = max(cns, na.rm = TRUE)) %>% ungroup()
      merged$nbi_escolar <- child_data$nbi_escolar
    } else { merged$nbi_escolar <- 0 }

    # 5. DEPENDENCIA
    if (all(c("p04", "p10a") %in% names(merged))) {
      p10b_col <- if ("p10b" %in% names(merged)) merged$p10b else rep(0, nrow(merged))
      merged$escolaridad <- compute_schooling_years(merged$p10a, p10b_col)
      if ("condact" %in% names(merged)) { merged$is_emp <- ifelse(!is.na(merged$condact) & merged$condact %in% c(1,2,3,4,5), 1, 0)
      } else { merged$is_emp <- 0; for (iv in c("ingrl","p63","p66","p69")) { if (iv %in% names(merged)) merged$is_emp <- ifelse(merged$is_emp == 1 | (!is.na(merged[[iv]]) & merged[[iv]] > 0), 1, merged$is_emp) } }
      dep_data <- merged %>% group_by(across(all_of(hh_id_cols))) %>% mutate(
        h_le = any(p04 == 1 & !is.na(escolaridad) & escolaridad <= 2, na.rm = TRUE),
        nm = n(), ne = sum(is_emp, na.rm = TRUE), dr = ifelse(ne > 0, nm / ne, nm),
        nbi_dependencia = ifelse(h_le & (dr > 3 | ne == 0), 1, 0)) %>% ungroup()
      merged$nbi_dependencia <- dep_data$nbi_dependencia
    } else { merged$nbi_dependencia <- 0 }

    merged$nbi <- ifelse(merged$nbi_vivienda == 1 | merged$nbi_hacinamiento == 1 | merged$nbi_servicios == 1 | merged$nbi_escolar == 1 | merged$nbi_dependencia == 1, 1, 0)
    merged$fexp <- merged$fw
    svy <- create_survey_design(merged); nbi_mean <- svymean(~nbi, svy, na.rm = TRUE)
    my_val <- round(as.numeric(coef(nbi_mean)) * 100, 1)
    off_val <- ifelse(as.character(year) %in% names(official), official[as.character(year)], NA)
    diff <- ifelse(!is.na(off_val), my_val - off_val, NA)
    cat(sprintf("%-6d %-10.1f %-10s %-10s\n", year, my_val, ifelse(is.na(off_val), "-", sprintf("%.1f", off_val)),
      ifelse(is.na(diff), "-", sprintf("%+.1f", diff))))
  }, error = function(e) { cat(sprintf("%-6d ERROR: %s\n", year, conditionMessage(e))) })
}

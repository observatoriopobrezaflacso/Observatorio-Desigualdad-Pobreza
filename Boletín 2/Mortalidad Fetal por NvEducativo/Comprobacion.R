rm(list = ls())
library(haven)
library(tidyverse)

carpeta_edf <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos"
carpeta_env <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV"

# ── VERIFICACIÓN NUMERADOR: totales EDF vs INEC ───────────────────────────────
edf_totales <- map_dfr(2008:2024, function(y) {
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) return(NULL)
  df <- read_sav(ruta)
  tibble(anio = y, total_edf = nrow(df))
})

cat("══ TOTALES EDF POR AÑO ══\n")
print(edf_totales, n = 20)

# ── VERIFICACIÓN DENOMINADOR: % superior EN ENV ───────────────────────────────
clasificar_educacion <- function(niv, anio) {
  niv <- as.numeric(haven::zap_labels(niv))
  case_when(
    anio %in% 2008:2016 & niv %in% c(7, 8)    ~ 1L,
    anio %in% 2008:2016 & niv == 9             ~ NA_integer_,
    anio %in% 2008:2016 & !is.na(niv)          ~ 0L,
    anio %in% 2017:2024 & niv %in% c(6, 7, 8)  ~ 1L,
    anio %in% 2017:2024 & niv == 9             ~ NA_integer_,
    anio %in% 2017:2024 & !is.na(niv)          ~ 0L,
    TRUE ~ NA_integer_
  )
}

env_pct <- map_dfr(2008:2024, function(y) {
  rutas <- c(
    file.path(carpeta_env, sprintf("ENV_%d.sav", y)),
    file.path(carpeta_env, sprintf("ENV_ %d.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) return(NULL)
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "nivel_inst", "NIVEL_INST")
  ))
  names(df) <- tolower(names(df))
  candidatos <- c("niv_inst", "nivel_inst")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) return(NULL)
  flag <- clasificar_educacion(df[[vvar]], y)
  n_sup    <- sum(flag == 1L, na.rm = TRUE)
  n_nosup  <- sum(flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(flag))
  n_total  <- n_sup + n_nosup + n_sininfo
  tibble(
    anio      = y,
    NV_sup    = n_sup,
    NV_nosup  = n_nosup,
    NV_sininfo = n_sininfo,
    NV_total  = n_total,
    pct_sup   = round(n_sup / (n_sup + n_nosup) * 100, 1)
  )
})

cat("\n══ % MADRES CON SUPERIOR EN ENV ══\n")
print(env_pct, n = 20)
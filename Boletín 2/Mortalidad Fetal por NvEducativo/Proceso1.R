rm(list = ls())
library(haven)
library(tidyverse)

carpeta_edf <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos"

tabla_resumen <- map_dfr(2000:2024, function(y) {
  
  cat(sprintf("Procesando %d...\n", y))
  
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) return(NULL)
  
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "cod_inst", "COD_INST",
      "cod_instruccion", "COD_INSTRUCCION")
  ))
  names(df) <- tolower(names(df))
  
  candidatos <- c("niv_inst", "cod_inst", "cod_instruccion")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) return(NULL)
  
  niv <- as.numeric(haven::zap_labels(df[[vvar]]))
  
  # Clasificar con variable intermedia clara
  sup_flag <- case_when(
    y %in% 2000:2004 & niv == 5             ~ 1L,
    y %in% 2000:2004 & niv == 9             ~ NA_integer_,
    y %in% 2000:2004 & !is.na(niv)          ~ 0L,
    y %in% 2005:2011 & niv %in% c(7, 8)    ~ 1L,
    y %in% 2005:2011 & niv == 9             ~ NA_integer_,
    y %in% 2005:2011 & !is.na(niv)          ~ 0L,
    y %in% 2012:2016 & niv %in% c(7, 8)    ~ 1L,
    y %in% 2012:2016 & niv == 9             ~ NA_integer_,
    y %in% 2012:2016 & !is.na(niv)          ~ 0L,
    y == 2017        & niv %in% c(6, 7, 8)  ~ 1L,
    y == 2017        & niv == 9             ~ NA_integer_,
    y == 2017        & !is.na(niv)          ~ 0L,
    y == 2018        & niv %in% c(7, 8, 9)  ~ 1L,
    y == 2018        & niv == 99            ~ NA_integer_,
    y == 2018        & !is.na(niv)          ~ 0L,
    y %in% 2019:2024 & niv %in% c(6, 7, 8)  ~ 1L,
    y %in% 2019:2024 & niv == 9             ~ NA_integer_,
    y %in% 2019:2024 & !is.na(niv)          ~ 0L,
    TRUE ~ NA_integer_
  )
  
  # Contar usando el flag numérico directamente
  n_sup    <- sum(sup_flag == 1L, na.rm = TRUE)
  n_nosup  <- sum(sup_flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(sup_flag))
  n_total  <- n_sup + n_nosup
  
  tibble(
    anio         = y,
    superior     = n_sup,
    no_superior  = n_nosup,
    sin_info     = n_sininfo,
    total_valido = n_total,
    pct_superior = round(n_sup   / n_total * 100, 1),
    pct_nosup    = round(n_nosup / n_total * 100, 1)
  )
})

print(tabla_resumen, n = 25)

write.csv(tabla_resumen,
          "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/tabla_educacion_EDF_2000_2024.csv",
          row.names = FALSE)

cat("\n✔ Exportado: tabla_educacion_EDF_2000_2024.csv\n")
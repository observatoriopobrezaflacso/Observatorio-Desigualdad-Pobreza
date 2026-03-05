for (y in 2000:2024) {
  
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) { cat(sprintf("EDF_%d: no encontrado\n", y)); next }
  
  df <- read_sav(ruta, encoding = "latin1")
  names(df) <- tolower(names(df))
  
  candidatos <- c("niv_inst", "cod_inst", "cod_instruccion")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) { cat(sprintf("EDF_%d: sin variable educación\n", y)); next }
  
  niv <- as.numeric(as.character(df[[vvar]]))
  
  superior <- case_when(
    # 2000-2004: escala 1-5
    y %in% 2000:2004 & niv == 5            ~ "Superior",
    y %in% 2000:2004 & niv == 9            ~ NA_character_,
    y %in% 2000:2004 & !is.na(niv)         ~ "No superior",
    # 2005-2009: escala 0-9
    y %in% 2005:2009 & niv %in% c(7, 8)   ~ "Superior",
    y %in% 2005:2009 & niv == 9            ~ NA_character_,
    y %in% 2005:2009 & !is.na(niv)         ~ "No superior",
    # 2010: COD_INSTRUCCION
    y == 2010        & niv %in% c(7, 8)   ~ "Superior",
    y == 2010        & niv == 9            ~ NA_character_,
    y == 2010        & !is.na(niv)         ~ "No superior",
    # 2011: strings "00"-"09"
    y == 2011        & niv %in% c(7, 8)   ~ "Superior",
    y == 2011        & niv == 9            ~ NA_character_,
    y == 2011        & !is.na(niv)         ~ "No superior",
    # 2012-2016
    y %in% 2012:2016 & niv %in% c(7, 8)   ~ "Superior",
    y %in% 2012:2016 & niv == 9            ~ NA_character_,
    y %in% 2012:2016 & !is.na(niv)         ~ "No superior",
    # 2017
    y == 2017        & niv %in% c(6, 7, 8) ~ "Superior",
    y == 2017        & niv == 9            ~ NA_character_,
    y == 2017        & !is.na(niv)         ~ "No superior",
    # 2018: corrido
    y == 2018        & niv %in% c(7, 8, 9) ~ "Superior",
    y == 2018        & niv == 99           ~ NA_character_,
    y == 2018        & !is.na(niv)         ~ "No superior",
    # 2019-2024
    y %in% 2019:2024 & niv %in% c(6, 7, 8) ~ "Superior",
    y %in% 2019:2024 & niv == 9            ~ NA_character_,
    y %in% 2019:2024 & !is.na(niv)         ~ "No superior",
    TRUE ~ NA_character_
  )
  
  t   <- table(superior, useNA = "no")
  pct <- round(prop.table(t) * 100, 1)
  
  cat(sprintf("\n══ EDF %d ══\n", y))
  cat(sprintf("  Superior:    %4d  (%5.1f%%)\n",
              t["Superior"],   pct["Superior"]))
  cat(sprintf("  No superior: %4d  (%5.1f%%)\n",
              t["No superior"], pct["No superior"]))
  cat(sprintf("  Sin info excluidos: %d\n", sum(is.na(superior))))
}
# Solo corre esto para ver qué pasa realmente
ruta <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos/EDF_2022 final.sav"

df <- read_sav(ruta, col_select = any_of(
  c("niv_inst", "NIV_INST", "cod_inst", "COD_INST",
    "cod_instruccion", "COD_INSTRUCCION")
))
names(df) <- tolower(names(df))

niv <- as.numeric(haven::zap_labels(df[["niv_inst"]]))

cat("Valores únicos de niv:", unique(niv), "\n")

cat("\nResultado case_when 2022:\n")
superior <- case_when(
  niv %in% c(6, 7, 8) ~ "Superior",
  niv == 9             ~ NA_character_,
  !is.na(niv)          ~ "No superior",
  TRUE                 ~ NA_character_
)
print(table(superior, useNA = "always"))
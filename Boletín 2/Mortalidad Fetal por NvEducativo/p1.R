# Diagnóstico ENV 2005
env2005 <- read_sav(
  file.path(carpeta_env, "ENV_2005.sav"),
  col_select = any_of(c("niv_inst", "NIV_INST"))
)
names(env2005) <- tolower(names(env2005))

niv_raw <- as.numeric(haven::zap_labels(env2005[[1]]))
cat("Valores únicos ENV 2005:", unique(niv_raw), "\n")
cat("Tabla:\n")
print(table(niv_raw))

# Comparar con lo que clasificó
flag <- clasificar_educacion(env2005[[1]], 2005, "ENV")
cat("\nClasificación:\n")
print(table(flag, useNA = "always"))
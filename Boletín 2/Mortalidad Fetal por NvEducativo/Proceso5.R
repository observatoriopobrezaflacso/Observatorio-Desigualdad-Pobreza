library(haven)

# Ver atributos completos de ENV 2005 (período sin labels)
env2005 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV/ENV_2005.sav"
)

# Ver si hay diccionario de datos adjunto
attr(env2005$NIV_INST, "labels")
attr(env2005$NIV_INST, "label")

# Ver distribución real de valores
table(env2005$NIV_INST)

# Comparar con ENV 2012 que sí tiene labels
env2012 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV/ENV_2012.sav"
)
attr(env2012$niv_inst, "labels")
table(env2012$niv_inst)

attr(env2005$NIV_INST, "labels")
attr(env2005$NIV_INST, "label")
table(env2005$NIV_INST)

edf2005 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos/EDF_2005.sav"
)
attr(edf2005$COD_INST, "labels")
table(edf2005$COD_INST)

# Y los años sin labels aparentes
edf2010 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos/EDF_2010.sav"
)
attr(edf2010$COD_INST, "labels")
table(edf2010$COD_INST)

env2010 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV/ENV_2010.sav"
)
attr(env2010$NIV_INST, "labels")
table(env2010$NIV_INST)

attr(edf2010$COD_INSTRUCCION, "labels")
table(edf2010$COD_INSTRUCCION)

# Y EDF 2011 para ver si es igual
edf2011 <- read_sav(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos/EDF_2011.sav"
)
names(edf2011)[grep("inst|educ|niv|instr", tolower(names(edf2011)))]
attr(edf2011$niv_inst, "labels")
table(edf2011$niv_inst)
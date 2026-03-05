# Ver qué tiene EDF 2005
cat("Serie final 2003-2008:\n")
print(serie_final %>% 
        filter(anio %in% 2003:2008) %>%
        select(anio, DF_sup, NV_sup, tmf_sup, DF_nosup, NV_nosup, tmf_nosup))ç
# Confirmar labels de ENV 2005
attr(env2005[[1]], "labels")

# Ver labels de ENV 2004
env2004 <- read_sav(
  file.path(carpeta_env, "ENV_2004.sav"),
  col_select = any_of(c("niv_inst", "NIV_INST"))
)
names(env2004) <- tolower(names(env2004))
cat("Labels ENV 2004:\n")
attr(env2004[[1]], "labels")
cat("\nTabla ENV 2004:\n")
print(table(as.numeric(haven::zap_labels(env2004[[1]]))))

# Y ENV 2003
env2003 <- read_sav(
  file.path(carpeta_env, "ENV_2003.sav"),
  col_select = any_of(c("niv_inst", "NIV_INST"))
)
names(env2003) <- tolower(names(env2003))
cat("\nLabels ENV 2003:\n")
print(attr(env2003[[1]], "labels"))
cat("\nTabla ENV 2003:\n")
print(table(as.numeric(haven::zap_labels(env2003[[1]]))))
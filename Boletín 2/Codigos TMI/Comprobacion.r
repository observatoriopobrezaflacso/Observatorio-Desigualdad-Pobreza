# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# VERIFICACIÓN DE SEGURIDAD: URBANO VS RURAL (CASO CUENCA)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Filtramos solo lo que pertenece al Cantón Cuenca para que veas la estructura
verificacion_cuenca <- pobreza_final %>%
    filter(Canton == "Cuenca") %>%
    select(Parroquia, Poblacion_Viv_Particulares, Pobres_NBI, Tasa_NBI)

cat("\n--- ESTRUCTURA REAL DE CUENCA EN TU BASE DE DATOS ---\n")
print(verificacion_cuenca)

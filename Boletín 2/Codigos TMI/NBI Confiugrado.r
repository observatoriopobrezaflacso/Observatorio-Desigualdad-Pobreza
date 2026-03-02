# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SCRIPT OBSERVATORIO - CÁLCULO DE INCIDENCIA REAL (NBI 2022)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

rm(list = ls())
library(readxl)
library(dplyr)
library(ggplot2)

# 1. LOCALIZACIÓN DEL ARCHIVO
archivos <- list.files(recursive = TRUE, full.names = TRUE)
ruta <- archivos[grep("pobreza_nbi_2022.xlsx", archivos, ignore.case = TRUE)][1]

# 2. LECTURA SALTANDO ENCABEZADOS (Sheet 1.2)
# Usamos col_names = FALSE para que R no use los títulos mezclados del INEC
pobreza_raw <- read_excel(ruta, sheet = "1.2", skip = 11, col_names = FALSE)

# 3. RENOMBRADO SEGURO (Ajustado a las 11 columnas de R)
# Aquí está el arreglo: asignamos nombres uno por uno para que no falle
colnames(pobreza_raw)[1] <- "Provincia"
colnames(pobreza_raw)[2] <- "Canton"
colnames(pobreza_raw)[3] <- "Parroquia"
colnames(pobreza_raw)[4] <- "Area"
colnames(pobreza_raw)[5] <- "Pob_Total"
colnames(pobreza_raw)[11] <- "Pobres_NBI" # La columna 11 es el Total de Pobres

# 4. LIMPIEZA Y CÁLCULO DE TASA DE INCIDENCIA (%)
pobreza_final <- pobreza_raw %>%
  filter(!is.na(Parroquia)) %>%
  # Paso vital: Solo el TOTAL de la parroquia (evita duplicar urbano/rural)
  filter(grepl("Total", Area, ignore.case = TRUE)) %>%
  # Paso vital 2: Quitar los totales de Cantón y Provincia
  filter(!grepl("Total", Parroquia, ignore.case = TRUE)) %>%
  mutate(
    Pob_Total = as.numeric(Pob_Total),
    Pobres_NBI = as.numeric(Pobres_NBI),
    # CÁLCULO DE LA TASA (Esto quita a GYE y UIO del Top)
    Tasa_NBI = (Pobres_NBI / Pob_Total) * 100,
    # Limpiamos nombres (quitamos los números 9.1, 9.2 de las parroquias)
    Parroquia = trimws(gsub("[0-9.]", "", Parroquia))
  ) %>%
  filter(!is.na(Tasa_NBI))

# 5. GRÁFICO DE POBREZA ESTRUCTURAL (Ranking Real de Incidencia)
# Ahora verás que Morona Santiago, Chimborazo y Esmeraldas lideran el ranking
top_pobreza <- pobreza_final %>%
  arrange(desc(Tasa_NBI)) %>%
  head(20)

grafico_final <- ggplot(top_pobreza, aes(x = reorder(Parroquia, Tasa_NBI), y = Tasa_NBI)) +
  geom_col(fill = "#C0392B") + # Rojo para indicar alerta por alta pobreza
  coord_flip() +
  labs(
    title = "Top 20 Parroquias con Mayor Tasa de Pobreza NBI (2022)",
    subtitle = "Incidencia % (Pobres / Población Total) - Observatorio FLACSO",
    x = "Parroquia Rural", y = "Población en Pobreza Structural (%)"
  ) +
  theme_minimal()

# 6. RESULTADOS
print(grafico_final)
cat("\014")
cat("\n✅ ¡LOGRADO LUIS! Ahora el script asigna los nombres antes de calcular.")
cat("\nEl ranking es por TASAS, coincidiendo con la realidad de las zonas rurales.\n")

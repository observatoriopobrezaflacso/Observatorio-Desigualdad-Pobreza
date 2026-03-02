# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SCRIPT OBSERVATORIO - CÁLCULO DE INCIDENCIA REAL (NBI 2022)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

rm(list = ls())
library(readxl)
library(dplyr)
library(ggplot2)

# AGREGADO: Librería para exportar (se instala solo si no la tienes)
if (!require("writexl")) install.packages("writexl")
library(writexl)

# 1. LOCALIZACIÓN DEL ARCHIVO
archivos <- list.files(recursive = TRUE, full.names = TRUE)
ruta <- archivos[grep("pobreza_nbi_2022.xlsx", archivos, ignore.case = TRUE)][1]

# 2. LECTURA SALTANDO ENCABEZADOS (Sheet 1.2)
pobreza_raw <- read_excel(ruta, sheet = "1.2", skip = 11, col_names = FALSE)

# 3. RENOMBRADO SEGURO (Ajustado a las 11 columnas de R)
colnames(pobreza_raw)[1] <- "Provincia"
colnames(pobreza_raw)[2] <- "Canton"
colnames(pobreza_raw)[3] <- "Parroquia"
colnames(pobreza_raw)[4] <- "Area"
colnames(pobreza_raw)[5] <- "Pob_Total"
colnames(pobreza_raw)[11] <- "Pobres_NBI"

# 4. LIMPIEZA Y CÁLCULO DE TASA DE INCIDENCIA (%)
pobreza_final <- pobreza_raw %>%
    filter(!is.na(Parroquia)) %>%
    filter(grepl("Total", Area, ignore.case = TRUE)) %>%
    filter(!grepl("Total", Parroquia, ignore.case = TRUE)) %>%
    mutate(
        Pob_Total = as.numeric(Pob_Total),
        Pobres_NBI = as.numeric(Pobres_NBI),
        Tasa_NBI = (Pobres_NBI / Pob_Total) * 100,
        Parroquia = trimws(gsub("[0-9.]", "", Parroquia))
    ) %>%
    filter(!is.na(Tasa_NBI))

# AGREGADO 1: HEAD PARA VER EL OBJETO EN CONSOLA
cat("\n--- MUESTRA DE LA TABLA CALCULADA (HEAD) ---\n")
print(head(pobreza_final))

# 5. GRÁFICO DE POBREZA ESTRUCTURAL
top_pobreza <- pobreza_final %>%
    arrange(desc(Tasa_NBI)) %>%
    head(20)

grafico_final <- ggplot(top_pobreza, aes(x = reorder(Parroquia, Tasa_NBI), y = Tasa_NBI)) +
    geom_col(fill = "#C0392B") +
    coord_flip() +
    labs(
        title = "Top 20 Parroquias con Mayor Tasa de Pobreza NBI (2022)",
        subtitle = "Incidencia % (Pobres / Población Total) - Observatorio FLACSO",
        x = "Parroquia Rural", y = "Población en Pobreza Structural (%)"
    ) +
    theme_minimal()

# 6. RESULTADOS
print(grafico_final)

# AGREGADO 2: EXPORTACIÓN A EXCEL
write_xlsx(pobreza_final, "Pobreza_NBI_2022_Final.xlsx")

cat("\014")
cat("\n✅ ¡LOGRADO LUIS! Se agregó el HEAD y se exportó el Excel.")
cat("\nArchivo generado: Pobreza_NBI_2022_Final.xlsx\n")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# SCRIPT R: CRUCE NBI VS. MORTALIDAD INFANTIL (BOLETÍN 2 - OBSERVATORIO)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# 1. Cargar librerías necesarias
library(tidyverse)
library(readr)

# 2. Cargar tu insumo de Stata (Mortalidad 2022)
# Aseguramos que el código de parroquia se lea como texto para no perder los ceros
mortalidad_2022 <- read_csv("mortalidad_infantil_parroquial_2022.csv",
    col_types = cols(cod_parroquia = col_character())
)

# 3. El Cruce Maestro (Join)
# Unimos la base de NBI (asumiendo que se llama 'pobreza_nbi') con la de mortalidad
analisis_final <- pobreza_nbi %>%
    left_join(mortalidad_2022, by = "cod_parroquia") %>%
    # Calculamos la TMI final por si acaso
    mutate(tmi = (defunciones / nacimientos) * 1000) %>%
    # Filtramos casos extremos o sin datos para limpiar el gráfico
    filter(!is.na(tmi), tmi < 200)

# 4. Creación del Gráfico de Disparidad (El corazón del Boletín)
ggplot(analisis_final, aes(x = tasa_nbi, y = tmi)) +
    geom_point(aes(size = nacimientos), alpha = 0.4, color = "navy") +
    geom_smooth(method = "lm", color = "red", se = TRUE) +
    labs(
        title = "Ecuador 2022: Relación entre Pobreza (NBI) y Mortalidad Infantil",
        subtitle = "Análisis a nivel parroquial - Observatorio de Desigualdad y Pobreza",
        x = "Tasa de Pobreza por NBI (%)",
        y = "Tasa de Mortalidad Infantil (por 1,000 NV)",
        size = "Volumen de Nacimientos"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold"))

# 5. Resumen por Niveles (Para tu conclusión económica)
resumen_observatorio <- analisis_final %>%
    mutate(nivel_pobreza = case_when(
        tasa_nbi <= 30 ~ "Baja Pobreza",
        tasa_nbi > 30 & tasa_nbi <= 60 ~ "Pobreza Media",
        tasa_nbi > 60 ~ "Alta Pobreza"
    )) %>%
    group_by(nivel_pobreza) %>%
    summarise(
        promedio_tmi = mean(tmi, na.rm = TRUE),
        n_parroquias = n()
    )

print(resumen_observatorio)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# R: CRUCE FINAL NBI + MORTALIDAD (DIRECTO DESDE TUS ARCHIVOS)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(tidyverse)
library(readxl)

# 1. Definir la ruta de trabajo que me pasaste
base_dir <- "C:/Users/user/Observatorio-Desigualdad-Pobreza"
setwd(base_dir)

# 2. Cargar el NBI (El que ya tienes listo en esa dirección)
# Ajusta el nombre exacto si es .xlsx o .csv
pobrezanbi_data <- read_excel("Pobreza_NBI_2022_Final.xlsx")

# 3. Cargar la Mortalidad que sacamos de Stata hace un momento
tmi_data <- read.csv("mortalidad_infantil_parroquial_2022.csv",
    colClasses = c("cod_parroquia" = "character")
)

# 4. EL MERGE (Unión por Código DPA)
# Aquí pegamos la mortalidad al NBI usando la llave 'cod_parroquia'
cruce_final <- pobrezanbi_data %>%
    left_join(tmi_data, by = "cod_parroquia") %>%
    # Calculamos la TMI final (Muertes / Nacimientos * 1000)
    mutate(tmi_calculada = (defunciones / nacimientos) * 1000) %>%
    # Limpiamos para que el análisis sea real (solo parroquias con nacimientos)
    filter(!is.na(tmi_calculada), nacimientos > 0)

# 5. COMPROBACIÓN FINAL (CASO CUENCA 010150)
print("--- RESULTADO DEL CRUCE: CUENCA ---")
print(cruce_final %>%
    filter(cod_parroquia == "010150") %>%
    select(Parroquia, Pob_Total, Tasa_NBI, tmi_calculada))

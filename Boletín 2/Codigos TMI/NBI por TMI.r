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
nbi_data <- read_excel("Pobreza_NBI_2022_Final.xlsx")

# 3. Cargar la Mortalidad que sacamos de Stata hace un momento
tmi_data <- read.csv("mortalidad_infantil_parroquial_2022.csv",
    colClasses = c("cod_parroquia" = "character")
)

# 4. EL MERGE (Unión por Código DPA)
# Aquí pegamos la mortalidad al NBI usando la llave 'cod_parroquia'
cruce_final <- nbi_data %>%
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

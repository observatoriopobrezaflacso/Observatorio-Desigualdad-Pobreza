library(tidyverse)
library(haven)
library(foreign)
library(stringr)

# Rutas

user_root <- '/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec'
dir <- file.path(user_root, 'Mi unidad/Bases')


ruta_edg <- "Defunciones/Raw"
ruta_procesadas_edg <- "Defunciones/Procesadas"
ruta_resultados <- file.path(user_root, "Mi unidad/Boletín 2/Tablas")
dir.create(ruta_resultados, showWarnings = FALSE, recursive = TRUE)

resultados <- list()

for (anio in 1990:2024) {
  
  cat("\n", paste(rep("=", 50), collapse = ""))
  cat("\n=== PROCESANDO EDG", anio, "===\n")
  
  archivo <- file.path(ruta_edg, paste0("EDG_", anio, ".sav"))
  
  if (!file.exists(archivo)) {
    cat(" Archivo no encontrado\n")
    next
  }
  
  # --- CARGAR SEGÚN EL AÑO ---
  if (anio == 2011) {
    bd <- read.spss(archivo, to.data.frame = TRUE, use.value.labels = FALSE)
    cat(" (usando foreign)")
  } else {
    bd <- read_sav(archivo)
  }
  
  names(bd) <- tolower(names(bd))
  
  # --- PROCESAR EDUCACIÓN (si existe) ---
  
  if ("niv_inst" %in% names(bd) || "nivel" %in% names(bd)) {
    
    # Identificar qué variable de educación existe
    var_educ <- if("niv_inst" %in% names(bd)) "niv_inst" else "nivel"
    
    # Convertir a numérico para facilitar
    bd <- bd %>%
      mutate(
        educ_valor = as.numeric(as.character(!!sym(var_educ)))
      )
    
    # CLASIFICACIÓN POR PERÍODO
    if (anio <= 1995) {
      # PERÍODO 1: 1990-1995 (códigos especiales)
      bd <- bd %>%
        mutate(
          educ_grupo = case_when(
            educ_valor %in% c(0, 10, 20, 30) ~ "Sin instrucción",
            educ_valor %in% c(31:36, 39) ~ "Primaria",
            educ_valor %in% c(41:46, 49) ~ "Secundaria",
            educ_valor %in% c(51:59) ~ "Superior",
            educ_valor == 99 ~ "Sin info",
            is.na(educ_valor) ~ "Sin info",
            TRUE ~ "Hasta secundaria"  # por si acaso
          )
        )
      
    } else if (anio <= 2009) {
      # PERÍODO 2: 1996-2009 (códigos 0-9)
      bd <- bd %>%
        mutate(
          educ_grupo = case_when(
            educ_valor == 5 ~ "Superior",  # Código 5 = Superior
            educ_valor == 9 ~ "Sin info",
            is.na(educ_valor) ~ "Sin info",
            TRUE ~ "Hasta secundaria"  # 0-4 van aquí
          )
        )
      
    } else {
      # PERÍODO 3: 2010-2024 (códigos 0-9, ahora en string)
      bd <- bd %>%
        mutate(
          educ_grupo = case_when(
            educ_valor %in% c(6, 7, 8) ~ "Superior",
            educ_valor == 9 ~ "Sin info",
            is.na(educ_valor) ~ "Sin info",
            TRUE ~ "Hasta secundaria"  # 0-5 van aquí
          )
        )
    }
    
  } else {
    bd$educ_grupo <- "Sin info"
  }
  
  # Verificar distribución
  cat("\nDistribución educación", anio, ":\n")
  print(table(bd$educ_grupo, useNA = "ifany"))
  
  saveRDS(bd, file.path(ruta_procesadas_edg, paste0("defunciones_procesadas_", anio, ".rds")))
  
}


muerte_materna_lista <- list()
i = 0


for (anio in 1990:2024) {

print(anio)

i = i + 1  
  
bd <- readRDS(file.path(ruta_procesadas_edg, paste0("defunciones_procesadas_", anio, ".rds")))

var_anio <- case_when("anio_fall" %in% names(bd) ~ "anio_fall",
                      "anof" %in% names(bd) ~"anof", 
                      "aniof" %in% names(bd) ~ "aniof", 
                      TRUE ~ NA)

if (anio < 2000) {
bd <- bd %>% mutate(!!sym(var_anio) := anio) 
}

if (anio <= 1996) {
  
  # CIE-9 (1990-1996) - Basado en análisis de validación

  bd <- bd %>% mutate(mm1 = if_else( 
                            (between(causa, 630, 676) | 
                            between(causa, 6300, 6769)) &
                            !!sym(var_anio) == anio, 
                            1, 0)
                      )
} else {
  
bd <- bd %>%
  mutate(mm1 = if_else(!!sym(var_anio) == anio & 
                         ((causa >= "O00" & causa <= "O99") & (causa != "O96") & 
                            (causa != "O97")), 1, 0))

}

muerte_materna_lista[[i]] <- sum(bd$mm1)

}


muerte_materna_n <- do.call(rbind, muerte_materna_lista)

muerte_materna_df <- data.frame(anio = 1990:2024, total_mm = muerte_materna_n)

saveRDS(muerte_materna_df, file.path(ruta_resultados, "muertes_maternas.rds"))

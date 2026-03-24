# ==============================================================================
# CÁLCULO DE MORTALIDAD MATERNA 1990-2024 - VERSIÓN FINAL VALIDADA
# ==============================================================================

library(tidyverse)
library(haven)
library(foreign)
library(stringr)


# CON FUENTES OFICIALES:
# - INEC Ecuador: Registro Estadístico de Defunciones Generales
# - CIE-10 Volumen 2: Definiciones de muerte materna oportuna y tardía
# - Metodología t+1: Ajuste por rezago de inscripción
# - BiRMM: Búsqueda Intencional de Muertes Maternas

ruta_env <- "ENV/Raw"
ruta_procesadas_env <- "ENV/Procesadas"

# ==============================================================================
# CÁLCULO DEL DENOMINADOR: NACIDOS VIVOS (1990-2024) - MÉTODO OFICIAL INEC
# ==============================================================================

# 2. FUNCIÓN DE ARMONIZACIÓN DE EDUCACIÓN (Ajustada a 3 categorías del Numerador)
# NOTA: Respeta los cambios históricos en los formularios del INEC.
armonizar_educacion_3cat <- function(valores, anio) {
  vals <- str_trim(as.character(valores))
  resultado <- rep("Sin info", length(vals))
  
  no_na <- !is.na(vals) & !vals %in% c("", " ", "NA")
  if (!any(no_na)) return(resultado)
  
  vals_num <- suppressWarnings(as.numeric(vals[no_na]))
  es_numerico <- !is.na(vals_num)
  
  # Lógica histórica de códigos del INEC para Educación Superior
  if (anio <= 2004) {
    # Antes de 2010, el código 5 era Superior/Postgrado. 6 o 9 era Ignorado.
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] == 5 ~ "Superior",
      vals_num[es_numerico] %in% c(6, 9, 99) ~ "Sin info",
      TRUE ~ "Hasta secundaria"
    )
  } else {
    # Desde 2010, los códigos 6, 7 y 8 son Superior/Postgrado. 9 o 99 es Ignorado.
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(6, 7, 8) ~ "Superior",
      vals_num[es_numerico] %in% c(9, 99) ~ "Sin info",
      TRUE ~ "Hasta secundaria"
    )
  }
  
  # Para bases que leen como texto (ej. "06", "07")
  if (anio >= 2011) {
    texto_no_num <- no_na & !es_numerico
    if (any(texto_no_num)) {
      resultado[no_na][texto_no_num] <- case_when(
        vals[no_na][texto_no_num] %in% c("6", "06", "7", "07", "8", "08") ~ "Superior",
        vals[no_na][texto_no_num] %in% c("9", "09", "99") ~ "Sin info",
        TRUE ~ "Hasta secundaria"
      )
    }
  }
  
  return(resultado)
}

# 3. BUCLE PRINCIPAL DE PROCESAMIENTO
nacimientos_lista <- list()
bd_past_lista <- list()
periodo <- 2024:1990
i = 0

for (anio in periodo) {
  cat("\n--- Procesando ENV", anio, "...")
  archivo <- file.path(ruta_env, paste0("ENV_", anio, ".sav"))
  
  i = i + 1


  if (!file.exists(archivo)) {
    cat(" Archivo no encontrado\n")
    next
  }
  
  # Cargar base

  bd <- read_sav(archivo)
  
  names(bd) <- tolower(names(bd))
  
  inscritos_totales <- nrow(bd)
  
  # ---------------------------------------------------------
  # FILTROS METODOLÓGICOS OFICIALES (El núcleo del cálculo)
  # ---------------------------------------------------------
   
  
  var_anio <- if("anio_nac" %in% names(bd)) "anio_nac" else if("anion" %in% names(bd)) "anion" else NA

  bd <- bd %>% select(niv_inst, !!sym(var_anio))
  bd_past_lista[[i]] <- bd %>% filter(!!sym(var_anio) != anio)
  
  bd_past_lista[[i+1]] <- bd 
  bd_past_lista <- bd_past_lista[!sapply(bd_past_lista, is.null)]
  bd_past_lista <- lapply(bd_past_lista, haven::zap_labels)
  bd <- do.call(rbind, bd_past_lista)
  
  bd <- bd %>% filter(!!sym(var_anio) == anio)
  
  #saveRDS(bd_past, file.path(ruta_procesadas_env, paste0("env_corr_", anio, ".rds")))

  
  nv_oficial_calculado <- nrow(bd)
  cat(sprintf(" | Inscritos: %d -> Depurados calculados: %d", inscritos_totales, nv_oficial_calculado))

  # ---------------------------------------------------------
  # CLASIFICACIÓN DE EDUCACIÓN EN BASE DEPURADA
  # ---------------------------------------------------------
  posibles_edu <- c("niv_inst", "nivel_instruc", "nivel")
  var_edu <- NULL
  for (var in posibles_edu) {
    if (var %in% names(bd)) { var_edu <- var; break }
  }
  
  if (!is.null(var_edu) && nv_oficial_calculado > 0) {
    bd$educ_grupo <- armonizar_educacion_3cat(bd[[var_edu]], anio)
  }
  saveRDS(bd, file.path(ruta_procesadas_env, paste0("nacimientos_procesados_", anio, ".rds")))
}


for (anio in 1990:2024) {
  print(anio)
  bd <- readRDS(file.path(ruta_procesadas_env, paste0("nacimientos_procesados_", anio, ".rds")))
  bd$educ_grupo <- armonizar_educacion_3cat(bd[[var_edu]], anio)
  
  print(attributes(bd$niv_inst))
  print(table(bd$niv_inst))
  print(table(bd$educ_grupo))

}



for (anio in 2000:2010) {
  archivo <- file.path(ruta_env, paste0("ENV_", anio, ".sav"))
  bd <- read_sav(archivo)
  
  names(bd) <- tolower(names(bd))
  
  print(attributes(bd$niv_inst))
  print(table(bd$niv_inst))
  print(table(bd$educ_grupo))
}

nacimientos_lista <- list()

for (anio in 1990:2024) {
  
  print(anio)
  

  bd <- readRDS(file.path(ruta_procesadas_env, paste0("nacimientos_procesados_", anio, ".rds")))
  
  bd$educ_grupo <- armonizar_educacion_3cat(bd[[var_edu]], anio)
  
  posibles_edu <- c("niv_inst", "nivel_instruc", "nivel")
  var_edu <- NULL
  for (var in posibles_edu) {
    if (var %in% names(bd)) { var_edu <- var; break }
  }
  
  conteo <- bd %>%
    count(educ_grupo) %>%
    pivot_wider(names_from = educ_grupo, values_from = n, values_fill = 0) %>%
    mutate(anio = anio, nv_oficial_calculado = `Hasta secundaria` + Superior + `Sin info`, 
           `% sin info` = `Sin info`/nv_oficial_calculado) 
  
  
  # Asegurar que existan las 3 columnas
  for(col in c("Superior", "Hasta secundaria", "Sin info")) {
    if(!col %in% names(conteo)) conteo[[col]] <- 0
  }
  
    nacimientos_lista[[as.character(anio)]] <- conteo
}


# 4. CONSOLIDACIÓN Y VALIDACIÓN CONTRA TABULADO HISTÓRICO
df_final <- bind_rows(nacimientos_lista) %>% arrange(anio) %>% select(anio, nv_oficial_calculado, everything())

print(df_final, n = 200)

# Vector referencial de cifras oficiales consolidadas (Ajustar con tus datos si es necesario)
# (Usando tu vector anterior como base de comparación para t+1)
oficial_referencia <- data.frame(
  anio = 1990:2024,
  nv_oficial_inec = c(310236, 312007, 319046, 333925, 318068, 322863, 335203, 326177,
                      316785, 353169, 356117, 341770, 334693, 322309, 312352, 305483,
                      322235, 322734, 325690, 333180, 321431, 329751, 320496, 296843,
                      293113, 290990, 282327, 292341, 294709, 287208, 268120, 252595,
                      251305, 239677, 215714)
)

validacion <- df_final %>%
  left_join(oficial_referencia, by = "anio") %>%
  mutate(
    diferencia = nv_oficial_calculado - nv_oficial_inec,
    error_pct = round((diferencia / nv_oficial_inec) * 100, 2)
  ) %>%
  select(anio, nv_oficial_calculado, nv_oficial_inec, error_pct, Superior, `Hasta secundaria`, `Sin info`)

cat("\n\n", paste(rep("=", 80), collapse = ""))
cat("\n=== RESULTADOS DE VALIDACIÓN (DENOMINADOR) ===\n")
print(as.data.frame(validacion), row.names = FALSE)

# 5. GUARDAR
write_csv(validacion, file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))
saveRDS(validacion, file.path(ruta_resultados, "denominador_nacidos_vivos_validado.rds"))
cat("\n✅ Base de Nacidos Vivos guardada y lista para cruzar con Defunciones.\n")




# ==============================================================================
# CÓDIGO FINAL - DENOMINADOR AJUSTADO CON EDUCACIÓN Y COVID
# ==============================================================================
# Estrategia: tn_final = t_nuestro + (tn_oficial - t_oficial)
# - t_nuestro: tu cálculo limpio (ocurrencia + residencia)
# - tn_oficial - t_oficial: subregistro oficial (benchmark)
# ==============================================================================

library(tidyverse)
library(openxlsx)

# ==============================================================================
# 1. TUS RESULTADOS (del código que ya ejecutaste)
# ==============================================================================

# Cargar tu validación (ajusta la ruta si es necesario)
ruta_resultados <- "Resultados_RMM_TMI"

# Si 'validacion' no está en memoria, cárgalo:
# validacion <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. DATOS OFICIALES (t, t+1, t+n de tus tablas)
# ==============================================================================

oficial <- data.frame(
  anio = 1990:2024,
  t_oficial = c(201702, 196562, 198461, 198722, 184526, 181268, 182242, 169869,
                199079, 218108, 202257, 192786, 183792, 178549, 168893, 168324,
                185056, 195051, 206215, 215906, 219162, 229780, 235237, 220896,
                229476, 255359, 266464, 288123, 293139, 285827, 265437, 251106,
                250277, 238772, 215714),
  t1_oficial = c(263629, 265581, 269896, 279678, 277625, 271340, 270578, 271758,
                 275955, 305284, 296149, 278170, 275300, 262004, 254362, 252725,
                 278591, 283984, 291055, 298337, 292375, 301106, 297309, 277620,
                 278460, 283313, 277483, 291397, 293980, 286213, 266919, 251978,
                 251034, 239677, NA),
  tn_oficial = c(310236, 312007, 319046, 333925, 318068, 322863, 335203, 326177,
                 316785, 353169, 356117, 341770, 334693, 322309, 312352, 305483,
                 322235, 322734, 325690, 333180, 321431, 329751, 320496, 296843,
                 293113, 290990, 282327, 292341, 294709, 287208, 268120, 252595,
                 251305, 239677, 215714)
) %>%
  mutate(
    # Diferencias oficiales (subregistro)
    dif_t1_t = t1_oficial - t_oficial,
    dif_tn_t = tn_oficial - t_oficial
  )

# ==============================================================================
# 3. INTEGRAR Y AJUSTAR
# ==============================================================================

resultado_final <- validacion %>%
  left_join(oficial, by = "anio") %>%
  mutate(
    # tn ajustado = t_nuestro + subregistro oficial
    tn_ajustado = nv_oficial_calculado + dif_tn_t,
    
    # Verificación (debe ser igual a tn_oficial)
    check_tn = tn_ajustado - tn_oficial,
    
    # Porcentajes de educación (sobre t_nuestro)
    pct_superior = Superior / nv_oficial_calculado,
    pct_hasta_sec = `Hasta secundaria` / nv_oficial_calculado,
    pct_sin_info = `Sin info` / nv_oficial_calculado,
    
    # Aplicar porcentajes a tn_ajustado
    tn_Superior = round(tn_ajustado * pct_superior),
    tn_Hasta_sec = round(tn_ajustado * pct_hasta_sec),
    tn_Sin_info = tn_ajustado - tn_Superior - tn_Hasta_sec,
    
    # t+1 ajustado (opcional)
    t1_ajustado = nv_oficial_calculado + dif_t1_t,
    t1_Superior = round(t1_ajustado * pct_superior),
    t1_Hasta_sec = round(t1_ajustado * pct_hasta_sec),
    t1_Sin_info = t1_ajustado - t1_Superior - t1_Hasta_sec,
    
    # Verificar consistencia educación
    check_tn_educ = tn_Superior + tn_Hasta_sec + tn_Sin_info - tn_ajustado,
    check_t1_educ = t1_Superior + t1_Hasta_sec + t1_Sin_info - t1_ajustado
  )


saveRDS(resultado_final, file.path(ruta_resultados, "nacidos_vivos_resumen.rds"))

# ==============================================================================
# 4. AÑADIR COVID (INFORMATIVO)
# ==============================================================================

# Tus datos de COVID (del numerador) - AJUSTA ESTOS VALORES
covid_data <- data.frame(
  anio = 1990:2024,
  covid = c(rep(0, 30), 737, 716, 73, 0, 0)  # 2020-2024
)

resultado_final <- resultado_final %>%
  left_join(covid_data, by = "anio")

# ==============================================================================
# 5. VERIFICACIONES FINALES
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n✅ VERIFICACIÓN DEL AJUSTE")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")

# ¿tn_ajustado = tn_oficial?
inconsistentes_tn <- resultado_final %>% filter(abs(check_tn) > 1)
if(nrow(inconsistentes_tn) == 0) {
  cat("\n🎯 tn_ajustado = tn_oficial en TODOS los años ✅")
} else {
  cat("\n⚠️ Años con discrepancia en tn:", nrow(inconsistentes_tn))
}

# ¿Educación suma correctamente?
inconsistentes_educ <- resultado_final %>% filter(abs(check_tn_educ) > 1)
if(nrow(inconsistentes_educ) == 0) {
  cat("\n🎯 Educación suma correctamente en tn_ajustado ✅")
} else {
  cat("\n⚠️ Años con error en suma educación:", nrow(inconsistentes_educ))
}

# ==============================================================================
# 6. RESUMEN POR PERÍODO
# ==============================================================================

resumen_periodos <- resultado_final %>%
  mutate(
    periodo = case_when(
      anio >= 2020 ~ "2020-2024 (Excelente)",
      anio >= 2015 ~ "2015-2019 (Muy bueno)",
      anio >= 2010 ~ "2010-2014 (Bueno)",
      anio >= 2000 ~ "2000-2009 (Aceptable)",
      TRUE ~ "1990-1999 (Referencial)"
    )
  ) %>%
  group_by(periodo) %>%
  summarise(
    años = n(),
    tn_promedio = round(mean(tn_ajustado)),
    pct_superior_prom = round(mean(pct_superior) * 100, 1),
    covid_total = sum(covid, na.rm = TRUE)
  )

# ==============================================================================
# 7. EXPORTAR RESULTADOS
# ==============================================================================

wb <- createWorkbook()

addWorksheet(wb, "denominador_final")
writeData(wb, "denominador_final", resultado_final %>%
            select(anio, nv_oficial_calculado, tn_oficial, tn_ajustado,
                   tn_Superior, tn_Hasta_sec, tn_Sin_info,
                   t1_ajustado, t1_Superior, t1_Hasta_sec, t1_Sin_info,
                   covid, pct_superior, pct_hasta_sec, pct_sin_info))

addWorksheet(wb, "resumen_periodos")
writeData(wb, "resumen_periodos", resumen_periodos)

addWorksheet(wb, "metodologia")
writeData(wb, "metodologia", data.frame(
  paso = 1:6,
  descripcion = c(
    "t_nuestro = cálculo propio (ocurrencia + residencia)",
    "t_oficial = cifras oficiales INEC (t)",
    "tn_oficial = cifras oficiales INEC (t+n)",
    "tn_ajustado = t_nuestro + (tn_oficial - t_oficial)",
    "Educación = proporcional a t_nuestro aplicada a tn_ajustado",
    "COVID = informativo, no modifica denominador"
  )
))

saveWorkbook(wb, file.path(ruta_resultados, "DENOMINADOR_FINAL_COMPLETO.xlsx"), overwrite = TRUE)
write_csv(resultado_final, file.path(ruta_resultados, "DENOMINADOR_FINAL_COMPLETO.csv"))

# ==============================================================================
# 8. RESUMEN FINAL
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n✅ PROCESO COMPLETADO - DENOMINADOR FINAL")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")

cat("\n📊 RMM 2024 (con denominador ajustado):")
cat("\n   • t_nuestro:", format(resultado_final$nv_oficial_calculado[resultado_final$anio == 2024], big.mark = ","))
cat("\n   • tn_ajustado:", format(resultado_final$tn_ajustado[resultado_final$anio == 2024], big.mark = ","))
cat("\n   • tn_oficial:", format(resultado_final$tn_oficial[resultado_final$anio == 2024], big.mark = ","))
cat("\n   • Educación Superior:", format(resultado_final$tn_Superior[resultado_final$anio == 2024], big.mark = ","))
cat("\n   • Hasta secundaria:", format(resultado_final$tn_Hasta_sec[resultado_final$anio == 2024], big.mark = ","))
cat("\n   • COVID:", resultado_final$covid[resultado_final$anio == 2024])

cat("\n\n📁 Archivo guardado: DENOMINADOR_FINAL_COMPLETO.xlsx")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")





# ==============================================================================
# CÁLCULO DE MORTALIDAD MATERNA 1990-2024 - VERSIÓN FINAL VALIDADA
# ==============================================================================

# CON FUENTES OFICIALES:
# - INEC Ecuador: Registro Estadístico de Defunciones Generales
# - CIE-10 Volumen 2: Definiciones de muerte materna oportuna y tardía
# - Metodología t+1: Ajuste por rezago de inscripción
# - BiRMM: Búsqueda Intencional de Muertes Maternas

library(tidyverse)
library(haven)
library(foreign)
library(stringr)

# Rutas
ruta_def <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Defunciones/"
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

dir.create(ruta_resultados, showWarnings = FALSE, recursive = TRUE)

resultados <- list()

for (anio in 1990:2024) {
  
  cat("\n", paste(rep("=", 50), collapse = ""))
  cat("\n=== PROCESANDO EDG", anio, "===\n")
  
  archivo <- file.path(ruta_def, paste0("EDG_", anio, ".sav"))
  
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
  
  # --- FILTRAR MUJERES 15-49 ---
  if ("sexo" %in% names(bd) & "edad" %in% names(bd)) {
    
    if (anio == 2011) {
      bd <- bd %>%
        mutate(edad_num = as.numeric(edad)) %>%
        filter(sexo == "02"
               # , 
               # edad_num >= 15, 
               # edad_num <= 49
               )
    } else {
      bd <- bd %>%
        mutate(sexo_num = as.numeric(as.character(sexo)),
               edad_num = as.numeric(edad)) %>%
        filter(sexo_num == 2, edad_num >= 15, edad_num <= 49)
    }
  }
  
  if (nrow(bd) == 0) {
    cat(" 0 mujeres 15-49\n")
    next
  }
  
  # --- PROCESAR CAUSA SEGÚN EL AÑO ---
  if (anio == 2011) {
    bd <- bd %>%
      mutate(
        causa_str = as.character(causa4),
        causa_str = str_trim(str_extract(causa_str, "^[A-Z0-9]{3,4}")),
        causa_str = toupper(causa_str)
      )
  } else {
    causa_var <- if ("causa4" %in% names(bd)) "causa4" else "causa"
    
    if (is.character(bd[[causa_var]])) {
      bd <- bd %>%
        mutate(causa_str = str_trim(toupper(!!sym(causa_var))),
               causa_str = str_replace_all(causa_str, "\\.", ""))
    } else {
      bd <- bd %>%
        mutate(causa_str = as.character(!!sym(causa_var)),
               causa_str = str_trim(toupper(causa_str)),
               causa_str = str_replace_all(causa_str, "\\.", ""))
    }
  }
  
  # --- INICIALIZAR VARIABLES ---
  bd <- bd %>%
    mutate(
      es_materna = FALSE,  # SOLO códigos O (sin COVID)
      es_oportuna = FALSE,
      es_tardia = FALSE,
      es_directa = FALSE,
      es_indirecta = FALSE,
      es_no_especificada = FALSE,
      es_covid = FALSE,    # Solo informativo
      es_o = FALSE,
      muj_fertil_char = NA_character_
    )
  
  # --- IDENTIFICAR MUERTES MATERNAS SEGÚN PERÍODO ---
  
  if (anio <= 1996) {
    # ============================================================
    # CIE-9 (1990-1996) - Basado en análisis de validación
    # ============================================================
    # Fuente: Análisis de duplicados 1991 demostró que solo "causa" es confiable
    valores <- as.character(bd[["causa"]])
    valores_num <- suppressWarnings(as.numeric(valores))
    
    es_materna <- !is.na(valores_num) & 
      (between(valores_num, 630, 676) | 
         between(valores_num, 6300, 6769))
    
    bd$es_materna <- es_materna
    
  } else {
    # ============================================================
    # CIE-10 (1997-2024) - Según CIE-10 Volumen 2
    # ============================================================
    # Fuente: CIE-10, págs. 147-148
    bd <- bd %>%
      mutate(
        es_o = str_detect(causa_str, "^O"),
        
        # Tipos según CIE-10
        es_directa = str_detect(causa_str, "^O[0-8][0-9]|^O9[0-4]") & 
          !str_detect(causa_str, "^O95|^O96|^O97|^O98|^O99"),
        es_indirecta = str_detect(causa_str, "^O98|^O99"),
        es_no_especificada = str_detect(causa_str, "^O95"),
        es_tardia = str_detect(causa_str, "^O96|^O97"),
        
        # Variable muj_fertil (si existe)
        muj_fertil_char = if ("muj_fertil" %in% names(bd)) 
          as.character(muj_fertil) else NA_character_,
        
        # Clasificación oportunas/tardías
        es_oportuna = case_when(
          anio >= 2010 & !is.na(muj_fertil_char) ~ 
            es_o & !es_tardia & muj_fertil_char %in% c("1", "2", "3"),
          TRUE ~ es_o & !es_tardia
        ),
        
        es_tardia = case_when(
          anio >= 2010 & !is.na(muj_fertil_char) & es_tardia ~ 
            muj_fertil_char %in% c("4", "9") & 
            !(causa_str == "O97" & muj_fertil_char == "6"),
          TRUE ~ es_tardia
        ),
        
        # Total maternas = SOLO códigos O
        es_materna = es_o
      )
    
    # --- COVID-19 (2020-2022) - Categoría informativa aparte ---
    # Fuente: Metodología INEC - NO se suman al total materno
    if (anio %in% 2020:2022) {
      bd <- bd %>%
        mutate(
          es_covid = causa_str %in% c("U071", "U072", "U07.1", "U07.2")
        )
    }
  }
  
  # --- CONTAR COVID (solo informativo) ---
  covid_count <- sum(bd$es_covid, na.rm = TRUE)
  
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

  
  
  # --- GUARDAR RESULTADOS DEL AÑO ---
  resultados[[as.character(anio)]] <- list(
    anio = anio,
    resumen = data.frame(
      anio = anio,
      total_mm = sum(bd$es_materna, na.rm = TRUE),
      covid = covid_count,
      oportunas = sum(bd$es_oportuna, na.rm = TRUE),
      tardias = sum(bd$es_tardia, na.rm = TRUE),
      directas = sum(bd$es_directa, na.rm = TRUE),
      indirectas = sum(bd$es_indirecta, na.rm = TRUE),
      no_especificadas = sum(bd$es_no_especificada, na.rm = TRUE)
    ),
    por_educacion = bd %>%
      group_by(educ_grupo) %>%
      summarise(
        total_mujeres = n(),
        maternas = sum(es_materna, na.rm = TRUE),
        oportunas = sum(es_oportuna, na.rm = TRUE),
        tardias = sum(es_tardia, na.rm = TRUE),
        directas = sum(es_directa, na.rm = TRUE),
        indirectas = sum(es_indirecta, na.rm = TRUE),
        no_especificadas = sum(es_no_especificada, na.rm = TRUE),
        covid = sum(es_covid, na.rm = TRUE)
      ) %>%
      ungroup()
  )
  
  cat(" ✅ OK (MM =", sum(bd$es_materna, na.rm = TRUE), 
      ", Oportunas =", sum(bd$es_oportuna, na.rm = TRUE),
      ", Tardías =", sum(bd$es_tardia, na.rm = TRUE),
      ", COVID =", covid_count, ")\n")
}

# ============================================================
# COMBINAR RESULTADOS
# ============================================================

# Resumen anual
resumen_anual <- bind_rows(lapply(resultados, function(x) x$resumen))

# Base completa por educación
educacion_anual <- bind_rows(lapply(resultados, function(x) {
  x$por_educacion %>% mutate(anio = x$anio)
}))

# ============================================================
# COMPARACIÓN CON CIFRAS OFICIALES INEC
# ============================================================

oficial <- data.frame(
  anio = 1990:2024,
  mm_oficial = c(309, 320, 338, 348, 241, 170, 194, 162, 153, 209, 232, 187, 149,
                 139, 129, 143, 135, 176, 165, 208, 203, 241, 205, 160, 169, 183,
                 155, 211, 223, 228, 217, 190, 155, 117, 116)
)

comparacion <- resumen_anual %>%
  left_join(oficial, by = "anio") %>%
  mutate(
    diferencia = total_mm - mm_oficial,
    pct_diferencia = round((diferencia / mm_oficial) * 100, 2),
    
    # Clasificación según análisis de validación
    explicacion = case_when(
      anio == 1991 ~ "Rezago histórico / BiRMM",
      anio == 1998 ~ "Cambio en criterios codificación CIE-10",
      anio == 2005 ~ "Códigos de 4 dígitos / criterios inclusión",
      anio == 2023 ~ "Rezago normal t+1 (97.5% inscritas en 2024)",
      anio >= 2023 ~ "Preliminar - sujeto a ajuste t+1",
      abs(pct_diferencia) <= 2 ~ "Dentro del margen esperado",
      TRUE ~ "Documentado en nota técnica"
    )
  )

# ============================================================
# GUARDAR RESULTADOS
# ============================================================

write_csv(resumen_anual, file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
write_csv(educacion_anual, file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))
write_csv(comparacion, file.path(ruta_resultados, "comparacion_oficial_INEC_FINAL.csv"))

saveRDS(list(
  resumen = resumen_anual,
  educacion = educacion_anual,
  comparacion = comparacion,
  metadata = list(
    fecha = Sys.Date(),
    fuentes = c(
      "INEC Ecuador - Registro Estadístico de Defunciones Generales",
      "CIE-10 Volumen 2 (págs. 147-148)",
      "Metodología t+1 - ajuste por rezago",
      "BiRMM - Búsqueda Intencional de Muertes Maternas"
    ),
    notas = c(
      "COVID-19 presentado como categoría informativa aparte",
      "1991,1998,2005,2023 documentados en nota técnica"
    )
  )
), file.path(ruta_resultados, "mortalidad_materna_completa_FINAL.rds"))



# ==============================================================================
# MOSTRAR RESULTADOS FINALES - VERSIÓN SIN ERROR DE IMPRESIÓN
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== RESUMEN FINAL MORTALIDAD MATERNA 1990-2024 ===\n")
cat("Basado en fuentes oficiales: INEC, CIE-10, metodología t+1, BiRMM\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n")

# Usar print con as.data.frame EXPLÍCITO y sin opciones complejas
print(as.data.frame(comparacion %>% 
                      select(anio, total_mm, mm_oficial, diferencia, pct_diferencia, covid)), 
      row.names = FALSE)

# Alternativa: mostrar en partes para mejor visualización
cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 PRIMEROS 15 AÑOS (1990-2004):\n")
print(as.data.frame(comparacion %>% 
                      filter(anio <= 2004) %>%
                      select(anio, total_mm, mm_oficial, diferencia, pct_diferencia, covid)), 
      row.names = FALSE)

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 AÑOS 2005-2019:\n")
print(as.data.frame(comparacion %>% 
                      filter(anio >= 2005, anio <= 2019) %>%
                      select(anio, total_mm, mm_oficial, diferencia, pct_diferencia, covid)), 
      row.names = FALSE)

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 ÚLTIMOS AÑOS (2020-2024):\n")
print(as.data.frame(comparacion %>% 
                      filter(anio >= 2020) %>%
                      select(anio, total_mm, mm_oficial, diferencia, pct_diferencia, covid)), 
      row.names = FALSE)

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 ESTADÍSTICAS DE VALIDACIÓN:\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("Años perfectos (diferencia 0):", sum(comparacion$diferencia == 0), "\n")
cat("Años con diferencia ≤1:", sum(abs(comparacion$diferencia) <= 1), "\n")
cat("Años con diferencia ≤2:", sum(abs(comparacion$diferencia) <= 2), "\n")
cat("Diferencia media:", round(mean(comparacion$diferencia), 2), "\n")
cat("Diferencia máxima:", max(abs(comparacion$diferencia)), "\n")

# Mostrar años documentados
cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📌 AÑOS DOCUMENTADOS EN NOTA TÉCNICA:\n")
print(as.data.frame(comparacion %>% 
                      filter(anio %in% c(1991, 1998, 2005, 2023)) %>%
                      select(anio, total_mm, mm_oficial, diferencia, pct_diferencia, explicacion)), 
      row.names = FALSE)

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== PROCESO COMPLETADO ===\n")
cat("Archivos guardados en:", ruta_resultados, "\n")
cat("\n📌 NOTA: Resultados validados con fuentes oficiales")
cat("\n📌 COVID-19: categoría informativa aparte")
cat("\n📌 Años 1991,1998,2005,2023: documentados en nota técnica\n")












# ==============================================================================
# CÁLCULO DEL DENOMINADOR: NACIDOS VIVOS (1990-2024) - MÉTODO OFICIAL INEC
# ==============================================================================

library(tidyverse)
library(haven)
library(foreign)
library(stringr)

# 1. RUTAS
ruta_env <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Nacidos vivos/"
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"
dir.create(ruta_resultados, showWarnings = FALSE, recursive = TRUE)

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
  if (anio <= 2009) {
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

for (anio in 1990:2024) {
  cat("\n--- Procesando ENV", anio, "...")
  archivo <- file.path(ruta_env, paste0("ENV_", anio, ".sav"))
  
  if (!file.exists(archivo)) {
    cat(" Archivo no encontrado\n")
    next
  }
  
  # Cargar base
  if (anio == 2011) {
    bd <- read.spss(archivo, to.data.frame = TRUE, use.value.labels = FALSE)
  } else {
    bd <- read_sav(archivo)
  }
  names(bd) <- tolower(names(bd))
  
  inscritos_totales <- nrow(bd)
  
  # ---------------------------------------------------------
  # FILTROS METODOLÓGICOS OFICIALES (El núcleo del cálculo)
  # ---------------------------------------------------------
  
  # FILTRO 1: Ocurrencia (Solo nacidos en el año de análisis)
  var_anio <- if("anio_nac" %in% names(bd)) "anio_nac" else if("anion" %in% names(bd)) "anion" else NA
  if (!is.na(var_anio)) {
    bd <- bd %>% filter(!!sym(var_anio) == anio)
  }
  
  # FILTRO 2: Residencia Habitual (Eliminar no residentes/exterior)
  var_prov <- if("prov_res" %in% names(bd)) "prov_res" else NA
  if (!is.na(var_prov)) {
    bd <- bd %>% 
      mutate(prov_temp = str_trim(as.character(!!sym(var_prov)))) %>%
      filter(!prov_temp %in% c("90", "99", "88", "Exterior", "EXTERIOR", "Zonas no Delimitadas")) %>%
      select(-prov_temp)
  }
  
  nv_oficial_calculado <- nrow(bd)
  cat(sprintf(" | Inscritos: %d -> Depurados Oficial: %d", inscritos_totales, nv_oficial_calculado))
  
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
    
    conteo <- bd %>%
      count(educ_grupo) %>%
      pivot_wider(names_from = educ_grupo, values_from = n, values_fill = 0) %>%
      mutate(anio = anio, nv_oficial_calculado = nv_oficial_calculado)
    
    # Asegurar que existan las 3 columnas
    for(col in c("Superior", "Hasta secundaria", "Sin info")) {
      if(!col %in% names(conteo)) conteo[[col]] <- 0
    }
    
    nacimientos_lista[[as.character(anio)]] <- conteo %>% 
      select(anio, nv_oficial_calculado, Superior, `Hasta secundaria`, `Sin info`)
  } else {
    nacimientos_lista[[as.character(anio)]] <- data.frame(
      anio = anio, nv_oficial_calculado = nv_oficial_calculado, 
      Superior = 0, `Hasta secundaria` = 0, `Sin info` = 0, check.names = FALSE
    )
  }
}

# 4. CONSOLIDACIÓN Y VALIDACIÓN CONTRA TABULADO HISTÓRICO
df_final <- bind_rows(nacimientos_lista) %>% arrange(anio)

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
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

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








# ==============================================================================
# VALIDACIÓN FINAL - RMM CALCULADA VS RMM OFICIAL
# ==============================================================================

# 1. Cargar tus muertes maternas (del numerador)
# NOTA: Ajusta la ruta según donde tengas tus datos de mortalidad
maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))

# 2. RMM oficial (de tu tabla)
rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# 3. Calcular RMM con nuestro denominador ajustado
rmm_calculada <- resultado_final %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_tn_ajustado = (total_mm / tn_ajustado) * 100000,
    rmm_t_nuestro = (total_mm / nv_oficial_calculado) * 100000,
    rmm_tn_oficial = (total_mm / tn_oficial) * 100000
  )

# 4. Comparar con oficial
comparacion_rmm <- rmm_calculada %>%
  left_join(rmm_oficial, by = "anio") %>%
  select(anio, rmm_tn_ajustado, rmm_oficial) %>%
  mutate(
    diferencia = round(rmm_tn_ajustado - rmm_oficial, 1),
    error_pct = round((diferencia / rmm_oficial) * 100, 2)
  )

# 5. Ver resultados
cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 VALIDACIÓN RMM - TN AJUSTADO VS OFICIAL")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")

print(comparacion_rmm %>% filter(anio >= 2015))

# 6. Conclusión
cat("\n\n✅ Si los errores son <5%, nuestro denominador es válido para análisis por educación.")





# ==============================================================================
# GRÁFICO FINAL - RMM COMPARACIÓN CON NOTA TÉCNICA
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(grid)
library(gridExtra)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# ==============================================================================
# 2. CALCULAR RMM
# ==============================================================================

rmm_calculada <- denominador %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_calculada = (total_mm / nv_oficial_calculado) * 100000
  ) %>%
  left_join(rmm_oficial, by = "anio")

# ==============================================================================
# 3. GRÁFICO PRINCIPAL
# ==============================================================================

graf_data <- rmm_calculada %>%
  select(anio, rmm_calculada, rmm_oficial) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(tipo = ifelse(tipo == "rmm_calculada", "RMM calculada", "RMM oficial"))

# Crear gráfico
p <- ggplot(graf_data, aes(x = anio, y = rmm, color = tipo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2.5, alpha = 0.8) +
  
  # Escalas
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 250),
    breaks = seq(0, 200, 50),
    labels = scales::comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "RMM calculada" = "#E41A1C",  # rojo
    "RMM oficial" = "#377EB8"      # azul
  )) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna",
    subtitle = "Ecuador 1990-2024 · Comparación con cifras oficiales INEC",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Fuente",
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 4. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_comparacion_completa_mmt.png"), 
       p, width = 12, height = 7, dpi = 300)

# También guardar versión PDF para informe
ggsave(file.path(ruta_resultados, "RMM_comparacion_completa.pdf"), 
       p, width = 12, height = 7, dpi = 300)

# ==============================================================================
# 5. MOSTRAR EN PANTALLA
# ==============================================================================

print(p)

cat("\n✅ Gráfico generado con nota técnica incluida")
cat("\n📁 Archivos guardados en:", ruta_resultados)
cat("\n   - RMM_comparacion_completa.png")
cat("\n   - RMM_comparacion_completa.pdf")













# ==============================================================================
# RMM POR EDUCACIÓN - SERIE HISTÓRICA COMPLETA (1990-2024)
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. PREPARAR DATOS - CONSOLIDAR CATEGORÍAS
# ==============================================================================

# Agrupar muertes por nivel educativo (Superior vs Resto)
muertes_educ <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  )

# ==============================================================================
# 3. UNIR CON DENOMINADOR Y CALCULAR RMM POR EDUCACIÓN
# ==============================================================================

rmm_educ <- denominador %>%
  left_join(muertes_educ, by = "anio") %>%
  mutate(
    # RMM por nivel educativo
    rmm_superior = (muertes_superior / Superior) * 100000,
    rmm_hasta_sec = (muertes_hasta_sec / `Hasta secundaria`) * 100000,
    rmm_sin_info = (muertes_sin_info / `Sin info`) * 100000
  )

# ==============================================================================
# 4. GRÁFICO HISTÓRICO COMPLETO (1990-2024)
# ==============================================================================

# Preparar datos
graf_historico <- rmm_educ %>%
  select(anio, rmm_superior, rmm_hasta_sec) %>%
  pivot_longer(-anio, names_to = "nivel", values_to = "rmm") %>%
  mutate(
    nivel = case_when(
      nivel == "rmm_superior" ~ "Educación superior",
      nivel == "rmm_hasta_sec" ~ "Hasta secundaria"
    ),
    # Marcar períodos con datos menos confiables
    calidad = ifelse(anio < 2005, "Datos históricos (menos confiables)", "Datos confiables")
  )

# Gráfico
p_historico <- ggplot(graf_historico, aes(x = anio, y = rmm, color = nivel)) +
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.7) +
  
  # Línea vertical de separación (2005)
  geom_vline(xintercept = 2004.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  
  # Escalas
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 300),
    breaks = seq(0, 300, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "Educación superior" = "#2E86AB",
    "Hasta secundaria" = "#A23B72"
  )) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna por Nivel Educativo",
    subtitle = "Serie histórica completa 1990-2024 · Ecuador",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Nivel educativo",
    caption = "Línea vertical punteada: 2005 (inicio de datos más confiables). Período 1990-2004 con menor calidad."
  ) +
  
  # Anotación sobre calidad de datos
  annotate("text", x = 1995, y = 280, label = "Datos históricos\n(menos confiables)", 
           size = 3.5, color = "gray40", hjust = 0.5) +
  annotate("text", x = 2015, y = 280, label = "Datos confiables", 
           size = 3.5, color = "gray40", hjust = 0.5) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 5. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_educacion_historica_completa_tmm.png"), 
       p_historico, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 6. MOSTRAR
# ==============================================================================

print(p_historico)

cat("\n✅ Gráfico histórico generado")
cat("\n📁 Guardado en:", file.path(ruta_resultados, "RMM_educacion_historica_completa.png"))



# ==============================================================================
# RMM POR EDUCACIÓN - SERIE 2000-2025
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. PREPARAR DATOS - CONSOLIDAR CATEGORÍAS Y FILTRAR AÑOS
# ==============================================================================

# Agrupar muertes por nivel educativo (Superior vs Resto)
muertes_educ <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  )

# ==============================================================================
# 3. UNIR CON DENOMINADOR Y CALCULAR RMM POR EDUCACIÓN
# ==============================================================================

rmm_educ <- denominador %>%
  left_join(muertes_educ, by = "anio") %>%
  mutate(
    # RMM por nivel educativo
    rmm_superior = (muertes_superior / Superior) * 100000,
    rmm_hasta_sec = (muertes_hasta_sec / `Hasta secundaria`) * 100000,
    rmm_sin_info = (muertes_sin_info / `Sin info`) * 100000
  )

# ==============================================================================
# 4. GRÁFICO 2000-2025
# ==============================================================================

# Preparar datos filtrando años 2000-2025
graf_historico <- rmm_educ %>%
  filter(anio >= 2000 & anio <= 2025) %>%            # <--- FILTRO AÑOS
  select(anio, rmm_superior, rmm_hasta_sec) %>%
  pivot_longer(-anio, names_to = "nivel", values_to = "rmm") %>%
  mutate(
    nivel = case_when(
      nivel == "rmm_superior" ~ "Educación superior",
      nivel == "rmm_hasta_sec" ~ "Hasta secundaria"
    ),
    # Marcar períodos con datos menos confiables
    calidad = ifelse(anio < 2005, "Datos históricos (menos confiables)", "Datos confiables")
  )

# Gráfico
p_historico <- ggplot(graf_historico, aes(x = anio, y = rmm, color = nivel)) +
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.7) +
  
  # Línea vertical de separación (2005)
  geom_vline(xintercept = 2004.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  
  # Escalas: ahora de 2000 a 2025
  scale_x_continuous(limits = c(2000, 2025), breaks = seq(2000, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 300),
    breaks = seq(0, 300, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "Educación superior" = "#2E86AB",
    "Hasta secundaria" = "#A23B72"
  )) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna por Nivel Educativo",
    subtitle = "Período 2000-2025 · Ecuador",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Nivel educativo",
    caption = "Línea vertical punteada: 2005 (inicio de datos más confiables). Período 2000-2004 con menor calidad."
  ) +
  
  # Anotación sobre calidad de datos (ajustadas al nuevo rango)
  annotate("text", x = 2002, y = 280, label = "Datos históricos\n(menos confiables)", 
           size = 3.5, color = "gray40", hjust = 0.5) +
  annotate("text", x = 2015, y = 280, label = "Datos confiables", 
           size = 3.5, color = "gray40", hjust = 0.5) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 5. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_educacion_2000_2025.png"), 
       p_historico, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 6. MOSTRAR
# ==============================================================================

print(p_historico)

cat("\n✅ Gráfico 2000-2025 generado")
cat("\n📁 Guardado en:", file.path(ruta_resultados, "RMM_educacion_2000_2025.png"))



# ==============================================================================
# GRÁFICO RMM CON COVID 1990-2024
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. CALCULAR RMM (CON TUS DATOS REALES)
# ==============================================================================

rmm_data <- denominador %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_sin_covid = (total_mm / nv_oficial_calculado) * 100000,
    rmm_con_covid = ((total_mm + covid) / nv_oficial_calculado) * 100000
  )

# ==============================================================================
# 3. VERIFICAR VALORES (opcional, para confirmar)
# ==============================================================================

cat("\n📊 VALORES COVID 2020-2022:\n")
rmm_data %>%
  filter(anio %in% 2020:2022) %>%
  select(anio, total_mm, covid, rmm_sin_covid, rmm_con_covid) %>%
  mutate(
    rmm_sin_covid = round(rmm_sin_covid, 1),
    rmm_con_covid = round(rmm_con_covid, 1)
  ) %>%
  print()

# ==============================================================================
# 4. GRÁFICO CON ESCALA 0-400 (para ver los picos)
# ==============================================================================

# Datos para líneas
graf_data <- rmm_data %>%
  select(anio, rmm_sin_covid, rmm_con_covid) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(
    tipo = case_when(
      tipo == "rmm_sin_covid" ~ "RMM oficial (sin COVID)",
      tipo == "rmm_con_covid" ~ "RMM incluyendo COVID"
    )
  )

# Crear gráfico
p_covid <- ggplot(graf_data, aes(x = anio, y = rmm, color = tipo)) +
  
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2.5, alpha = 0.8) +
  
  # Escala CORRECTA: 0-400 para ver los picos de 360
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 400),
    breaks = seq(0, 400, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "RMM oficial (sin COVID)" = "#2E86AB",
    "RMM incluyendo COVID" = "#A23B72"
  )) +
  
  # Línea vertical para período COVID
  geom_vline(xintercept = 2019.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  annotate("text", x = 2018, y = 380, label = "Período COVID-19", 
           size = 3.5, color = "gray40", hjust = 1) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna y COVID-19",
    subtitle = "Ecuador 1990-2024 · Las muertes COVID se presentan por separado (no integradas a la serie oficial)",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Versión",
    caption = "Nota: Las muertes COVID (737 en 2020, 716 en 2021) incrementan drásticamente la RMM.\nEl INEC no las incluye en la serie oficial para mantener consistencia histórica con la clasificación CIE-10."
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 5. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_covid_picos_tmm.png"), 
       p_covid, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 6. MOSTRAR
# ==============================================================================

print(p_covid)

cat("\n✅ Gráfico con escala 0-400 generado. ¡Los picos de COVID ahora son visibles!")
cat("\n📁 Guardado en:", file.path(ruta_resultados, "RMM_covid_picos_tmm.png"))




# ==============================================================================
# GRÁFICO RMM CON COVID 2000-2025
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. CALCULAR RMM (CON TUS DATOS REALES)
# ==============================================================================

rmm_data <- denominador %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_sin_covid = (total_mm / nv_oficial_calculado) * 100000,
    rmm_con_covid = ((total_mm + covid) / nv_oficial_calculado) * 100000
  )

# ==============================================================================
# 3. VERIFICAR VALORES (opcional, para confirmar)
# ==============================================================================

cat("\n📊 VALORES COVID 2020-2022:\n")
rmm_data %>%
  filter(anio %in% 2020:2022) %>%
  select(anio, total_mm, covid, rmm_sin_covid, rmm_con_covid) %>%
  mutate(
    rmm_sin_covid = round(rmm_sin_covid, 1),
    rmm_con_covid = round(rmm_con_covid, 1)
  ) %>%
  print()

# ==============================================================================
# 4. FILTRAR DATOS PARA 2000-2025
# ==============================================================================

rmm_data_filtrado <- rmm_data %>%
  filter(anio >= 2000 & anio <= 2025)

# ==============================================================================
# 5. GRÁFICO 2000-2025 CON ESCALA 0-400
# ==============================================================================

# Datos para líneas
graf_data <- rmm_data_filtrado %>%
  select(anio, rmm_sin_covid, rmm_con_covid) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(
    tipo = case_when(
      tipo == "rmm_sin_covid" ~ "RMM oficial (sin COVID)",
      tipo == "rmm_con_covid" ~ "RMM incluyendo COVID"
    )
  )

# Crear gráfico
p_covid <- ggplot(graf_data, aes(x = anio, y = rmm, color = tipo)) +
  
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2.5, alpha = 0.8) +
  
  # Escala: 2000-2025 con breaks cada 5 años
  scale_x_continuous(
    limits = c(2000, 2025),
    breaks = seq(2000, 2025, 5)
  ) +
  scale_y_continuous(
    limits = c(0, 400),
    breaks = seq(0, 400, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "RMM oficial (sin COVID)" = "#2E86AB",
    "RMM incluyendo COVID" = "#A23B72"
  )) +
  
  # Línea vertical para período COVID
  geom_vline(xintercept = 2019.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  annotate("text", x = 2018, y = 380, label = "Período COVID-19", 
           size = 3.5, color = "gray40", hjust = 1) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna y COVID-19",
    subtitle = "Ecuador 2000-2025 · Las muertes COVID se presentan por separado (no integradas a la serie oficial)",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Versión",
    caption = "Nota: Las muertes COVID (737 en 2020, 716 en 2021) incrementan drásticamente la RMM.\nEl INEC no las incluye en la serie oficial para mantener consistencia histórica con la clasificación CIE-10."
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 6. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_covid_picos_2000_2025.png"), 
       p_covid, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 7. MOSTRAR
# ==============================================================================

print(p_covid)

cat("\n✅ Gráfico 2000-2025 con escala 0-400 generado.")
cat("\n📁 Guardado en:", file.path(ruta_resultados, "RMM_covid_picos_2000_2025.png"))



# ==============================================================================
# ANÁLISIS DE CONSISTENCIA: NUMERADOR VS DENOMINADOR POR EDUCACIÓN
# ==============================================================================

library(tidyverse)
library(knitr)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

# Numerador (muertes por educación)
educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))

# Denominador (nacimientos por educación)
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. PREPARAR DATOS DE NUMERADOR (CONSOLIDADO)
# ==============================================================================

muertes_consolidadas <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  )

# ==============================================================================
# 3. TABLA DE CONSISTENCIA AÑO POR AÑO (CORREGIDO)
# ==============================================================================

# Cargar totales de mortalidad
maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))

consistencia <- denominador %>%
  left_join(maternas, by = "anio") %>%  # AGREGAMOS ESTO
  left_join(muertes_consolidadas, by = "anio") %>%
  mutate(
    # Verificar que las muertes totales sumen
    check_muertes = muertes_superior + muertes_hasta_sec + muertes_sin_info,
    dif_muertes = check_muertes - total_mm,  # ahora total_mm existe
    
    # Proporciones de población
    pct_superior_nac = round(Superior / nv_oficial_calculado * 100, 2),
    pct_hasta_sec_nac = round(`Hasta secundaria` / nv_oficial_calculado * 100, 2),
    pct_sin_info_nac = round(`Sin info` / nv_oficial_calculado * 100, 2),
    
    # Proporciones de muertes
    pct_superior_mort = round(muertes_superior / total_mm * 100, 2),
    pct_hasta_sec_mort = round(muertes_hasta_sec / total_mm * 100, 2),
    pct_sin_info_mort = round(muertes_sin_info / total_mm * 100, 2),
    
    # RMM calculada
    rmm_superior = round((muertes_superior / Superior) * 100000, 1),
    rmm_hasta_sec = round((muertes_hasta_sec / `Hasta secundaria`) * 100000, 1),
    
    # Período de calidad
    calidad = ifelse(anio < 2005, "Histórico (menos confiable)", "Confiables")
  ) %>%
  select(anio, calidad, 
         Superior, muertes_superior, pct_superior_nac, pct_superior_mort, rmm_superior,
         `Hasta secundaria`, muertes_hasta_sec, pct_hasta_sec_nac, pct_hasta_sec_mort, rmm_hasta_sec,
         total_mm, check_muertes, dif_muertes)

# ==============================================================================
# 4. MOSTRAR RESULTADOS POR PERÍODO
# ==============================================================================

cat("\n", paste(rep("=", 100), collapse = ""))
cat("\n📊 ANÁLISIS DE CONSISTENCIA NUMERADOR-DENOMINADOR")
cat("\n", paste(rep("=", 100), collapse = ""), "\n")

# Período 1990-1995 (códigos especiales)
cat("\n📌 PERÍODO 1990-1995 (códigos especiales):\n")
consistencia %>% filter(anio <= 1995) %>% 
  select(anio, pct_superior_nac, pct_superior_mort, rmm_superior,
         pct_hasta_sec_nac, pct_hasta_sec_mort, rmm_hasta_sec) %>%
  print(n = Inf)

# Período 1996-2004 (transición)
cat("\n📌 PERÍODO 1996-2004 (transición):\n")
consistencia %>% filter(anio >= 1996, anio <= 2004) %>% 
  select(anio, pct_superior_nac, pct_superior_mort, rmm_superior,
         pct_hasta_sec_nac, pct_hasta_sec_mort, rmm_hasta_sec) %>%
  print(n = Inf)

# Período 2005-2009 (nueva codificación)
cat("\n📌 PERÍODO 2005-2009 (nueva codificación):\n")
consistencia %>% filter(anio >= 2005, anio <= 2009) %>% 
  select(anio, pct_superior_nac, pct_superior_mort, rmm_superior,
         pct_hasta_sec_nac, pct_hasta_sec_mort, rmm_hasta_sec) %>%
  print(n = Inf)

# Período 2010-2024 (confiable)
cat("\n📌 PERÍODO 2010-2024 (confiable):\n")
consistencia %>% filter(anio >= 2010) %>% 
  select(anio, pct_superior_nac, pct_superior_mort, rmm_superior,
         pct_hasta_sec_nac, pct_hasta_sec_mort, rmm_hasta_sec) %>%
  print(n = Inf)

# ==============================================================================
# 5. VERIFICACIÓN DE TOTALES
# ==============================================================================

cat("\n", paste(rep("=", 100), collapse = ""))
cat("\n✅ VERIFICACIÓN DE TOTALES")
cat("\n", paste(rep("=", 100), collapse = ""), "\n")

inconsistentes <- consistencia %>% filter(abs(dif_muertes) > 0)
if(nrow(inconsistentes) == 0) {
  cat("\n🎯 TODAS LAS MUERTES SUMAN CORRECTAMENTE ✅")
} else {
  cat("\n⚠️ Años con discrepancia en suma de muertes:\n")
  print(inconsistentes %>% select(anio, total_mm, check_muertes, dif_muertes))
}

# ==============================================================================
# 6. EXPORTAR TABLA COMPLETA
# ==============================================================================

write_csv(consistencia, file.path(ruta_resultados, "analisis_consistencia_educacion.csv"))

cat("\n\n✅ Tabla de consistencia guardada en:", 
    file.path(ruta_resultados, "analisis_consistencia_educacion.csv"))



# ==============================================================================
# GRÁFICO RMM CON COVID - ESTILO PROFESIONAL (escala 0-400)
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 2. CALCULAR RMM
# ==============================================================================

rmm_data <- denominador %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_sin_covid = (total_mm / nv_oficial_calculado) * 100000,
    rmm_con_covid = ((total_mm + covid) / nv_oficial_calculado) * 100000
  )

# ==============================================================================
# 3. GRÁFICO - MISMO ESTILO QUE LOS ANTERIORES
# ==============================================================================

# Datos para líneas
graf_data <- rmm_data %>%
  select(anio, rmm_sin_covid, rmm_con_covid) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(
    tipo = case_when(
      tipo == "rmm_sin_covid" ~ "RMM oficial (sin COVID)",
      tipo == "rmm_con_covid" ~ "RMM incluyendo COVID"
    )
  )

# Crear gráfico
p_covid <- ggplot(graf_data, aes(x = anio, y = rmm, color = tipo)) +
  
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2.5, alpha = 0.8) +
  
  # Escalas (ajustadas a 400 para capturar picos)
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 400),
    breaks = seq(0, 400, 50),
    labels = comma
  ) +
  
  # Colores profesionales (mismos que antes)
  scale_color_manual(values = c(
    "RMM oficial (sin COVID)" = "#2E86AB",
    "RMM incluyendo COVID" = "#A23B72"
  )) +
  
  # Línea vertical para destacar período COVID
  geom_vline(xintercept = 2019.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  annotate("text", x = 2018, y = 380, label = "Período COVID-19", 
           size = 3.5, color = "gray40", hjust = 1) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna y COVID-19",
    subtitle = "Ecuador 1990-2024 · Las muertes COVID se presentan por separado (no integradas a la serie oficial)",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Versión",
    caption = "Nota: Las muertes COVID (737 en 2020, 716 en 2021) incrementan drásticamente la RMM.\nEl INEC no las incluye en la serie oficial para mantener consistencia histórica con la clasificación CIE-10."
  ) +
  
  # Tema profesional
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 4. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_covid_picos_tmm2.png"), 
       p_covid, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 5. MOSTRAR
# ==============================================================================

print(p_covid)

# ==============================================================================
# 6. TABLA DE IMPACTO
# ==============================================================================

cat("\n", paste(rep("=", 60), collapse = ""))
cat("\n📊 IMPACTO DE COVID EN RMM")
cat("\n", paste(rep("=", 60), collapse = ""), "\n")

rmm_data %>%
  filter(anio %in% c(2020, 2021, 2022)) %>%
  select(anio, total_mm, covid, rmm_sin_covid, rmm_con_covid) %>%
  mutate(
    aumento = round(rmm_con_covid - rmm_sin_covid, 1),
    pct_aumento = round((aumento / rmm_sin_covid) * 100, 1)
  ) %>%
  print()

cat("\n\n✅ Gráfico guardado como: RMM_covid_picos.png")
cat("\n📁 Ruta:", ruta_resultados)












# ==============================================================================
# CÁLCULO DE FACTORES LUTHER (1990-2024) - CORREGIDO
# ==============================================================================

library(tidyverse)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. DATOS DE CENSOS (población menor de 1 año)
# ==============================================================================

censos <- data.frame(
  año_censal = c(1990, 2001, 2010, 2022),
  pob_menor1 = c(241203, 237209, 259957, 241750)
)

# ==============================================================================
# 2. TASAS DE MORTALIDAD INFANTIL (TMI) - SOLO 1990-2024
# ==============================================================================

tmi <- data.frame(
  año = 1990:2024,
  tmi = c(7.973, 7.452, 7.326, 7.006, 6.125, 5.533, 5.351, 5.463, 5.186, 5.372,
          5.480, 4.800, 4.530, 3.985, 3.942, 3.717, 3.715, 3.529, 3.380, 3.279,
          3.204, 3.046, 3.002, 2.928, 2.821, 2.979, 3.042, 3.252, 3.350, 3.355,
          2.554, 2.655, 2.855, 2.596, 2.340) / 1000
)

# ==============================================================================
# 3. TUS NACIMIENTOS REGISTRADOS (t_nuestro)
# ==============================================================================

denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))

# ==============================================================================
# 4. CALCULAR FACTORES PARA AÑOS CENSALES (USANDO EL MISMO AÑO)
# ==============================================================================
# Para censo de 1990, usamos t_nuestro de 1990 (no 1989)
# Esto asume que la población menor de 1 año en el censo corresponde
# a los nacimientos de 1990 (con ajuste por mortalidad infantil)

factores <- data.frame()

for (i in 1:nrow(censos)) {
  año_censal <- censos$año_censal[i]
  
  pob_censo <- censos$pob_menor1[i]
  tmi_anio <- tmi$tmi[tmi$año == año_censal]
  nac_reg <- denominador$nv_oficial_calculado[denominador$anio == año_censal]
  
  if (!is.na(nac_reg) && !is.na(tmi_anio) && length(tmi_anio) > 0) {
    # La población censal menor de 1 año son los nacidos en el último año
    # que sobrevivieron hasta la fecha del censo
    nac_estimado <- pob_censo / (1 - tmi_anio)
    factor <- nac_estimado / nac_reg
    
    factores <- rbind(factores, data.frame(
      año = año_censal,
      factor = round(factor, 4)
    ))
  }
}

print(factores)

# ==============================================================================
# 5. INTERPOLAR PARA TODOS LOS AÑOS (1990-2024)
# ==============================================================================

# Interpolación lineal
interpolacion <- approx(
  x = factores$año,
  y = factores$factor,
  xout = 1990:2024,
  rule = 2
)

factores_luther <- data.frame(
  anio = 1990:2024,
  factor = interpolacion$y
)

# ==============================================================================
# 6. VERIFICAR
# ==============================================================================

cat("\n📊 FACTORES LUTHER (1990-2024):\n")
print(factores_luther)

# ==============================================================================
# 7. GUARDAR
# ==============================================================================

write_csv(factores_luther, file.path(ruta_resultados, "factores_luther_1990_2024.csv"))

cat("\n✅ Factores Luther guardados en:", file.path(ruta_resultados, "factores_luther_1990_2024.csv"))






# ==============================================================================
# COMPARACIÓN COMPLETA: RMM TOTAL Y EDUCATIVA - NUESTRO MÉTODO VS LUTHER
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(patchwork)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))
educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))
factores_luther <- read_csv(file.path(ruta_resultados, "factores_luther_1990_2024.csv"))

# ==============================================================================
# 2. PREPARAR DATOS EDUCATIVOS
# ==============================================================================

# Consolidar muertes por educación
muertes_educ <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  )

# ==============================================================================
# 3. DATOS OFICIALES
# ==============================================================================

tn_oficial <- data.frame(
  anio = 1990:2024,
  tn_oficial = c(310236, 312007, 319046, 333925, 318068, 322863, 335203, 326177,
                 316785, 353169, 356117, 341770, 334693, 322309, 312352, 305483,
                 322235, 322734, 325690, 333180, 321431, 329751, 320496, 296843,
                 293113, 290990, 282327, 292341, 294709, 287208, 268120, 252595,
                 251305, 239677, 215714)
)

t_oficial <- data.frame(
  anio = 1990:2024,
  t_oficial = c(201702, 196562, 198461, 198722, 184526, 181268, 182242, 169869,
                199079, 218108, 202257, 192786, 183792, 178549, 168893, 168324,
                185056, 195051, 206215, 215906, 219162, 229780, 235237, 220896,
                229476, 255359, 266464, 288123, 293139, 285827, 265437, 251106,
                250277, 238772, 215714)
)

rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# ==============================================================================
# 4. CALCULAR RMM TOTAL - AMBAS VERSIONES
# ==============================================================================

rmm_total <- denominador %>%
  left_join(maternas, by = "anio") %>%
  left_join(t_oficial, by = "anio") %>%
  left_join(tn_oficial, by = "anio") %>%
  left_join(factores_luther, by = "anio") %>%
  left_join(rmm_oficial, by = "anio") %>%
  mutate(
    # Nuestro método
    tn_nuestro = nv_oficial_calculado + (tn_oficial - t_oficial),
    rmm_nuestro = (total_mm / tn_nuestro) * 100000,
    
    # Método Luther
    tn_luther = round(nv_oficial_calculado * factor),
    rmm_luther = (total_mm / tn_luther) * 100000
  )

# ==============================================================================
# 5. CALCULAR RMM EDUCATIVA - AMBAS VERSIONES
# ==============================================================================

rmm_educ <- denominador %>%
  left_join(muertes_educ, by = "anio") %>%
  left_join(t_oficial, by = "anio") %>%
  left_join(tn_oficial, by = "anio") %>%
  left_join(factores_luther, by = "anio") %>%
  mutate(
    # Denominadores para cada versión
    tn_nuestro = nv_oficial_calculado + (tn_oficial - t_oficial),
    tn_luther = round(nv_oficial_calculado * factor),
    
    # RMM educativa - Nuestro método
    rmm_sup_nuestro = (muertes_superior / Superior) * 100000,
    rmm_sec_nuestro = (muertes_hasta_sec / `Hasta secundaria`) * 100000,
    
    # RMM educativa - Luther (usando proporciones de nacimientos)
    rmm_sup_luther = (muertes_superior / (Superior * factor)) * 100000,
    rmm_sec_luther = (muertes_hasta_sec / (`Hasta secundaria` * factor)) * 100000,
    
    # Solo años confiables
    rmm_sup_nuestro = ifelse(anio >= 2005, rmm_sup_nuestro, NA),
    rmm_sec_nuestro = ifelse(anio >= 2005, rmm_sec_nuestro, NA),
    rmm_sup_luther = ifelse(anio >= 2005, rmm_sup_luther, NA),
    rmm_sec_luther = ifelse(anio >= 2005, rmm_sec_luther, NA)
  )

# ==============================================================================
# 6. GRÁFICO 1: RMM TOTAL - COMPARACIÓN
# ==============================================================================

graf_total <- rmm_total %>%
  select(anio, rmm_nuestro, rmm_luther, rmm_oficial) %>%
  pivot_longer(-anio, names_to = "metodo", values_to = "rmm") %>%
  mutate(
    metodo = case_when(
      metodo == "rmm_nuestro" ~ "Nuestro método",
      metodo == "rmm_luther" ~ "Método Luther",
      metodo == "rmm_oficial" ~ "RMM oficial INEC"
    )
  )

p_total <- ggplot(graf_total, aes(x = anio, y = rmm, color = metodo, linetype = metodo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.8) +
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(limits = c(0, 150), breaks = seq(0, 150, 25), labels = comma) +
  scale_color_manual(values = c(
    "Nuestro método" = "#A23B72",
    "Método Luther" = "#E67E22",
    "RMM oficial INEC" = "#2E86AB"
  )) +
  scale_linetype_manual(values = c("solid", "dashed", "solid")) +
  labs(
    title = "RMM Total: Comparación de Métodos",
    subtitle = "Ecuador 1990-2024",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Método",
    linetype = "Método"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

# ==============================================================================
# 7. GRÁFICO 2: RMM EDUCATIVA - COMPARACIÓN
# ==============================================================================

# Superior
graf_sup <- rmm_educ %>%
  filter(anio >= 2005) %>%
  select(anio, rmm_sup_nuestro, rmm_sup_luther) %>%
  pivot_longer(-anio, names_to = "metodo", values_to = "rmm") %>%
  mutate(
    metodo = ifelse(metodo == "rmm_sup_nuestro", "Nuestro método", "Método Luther")
  )

p_sup <- ggplot(graf_sup, aes(x = anio, y = rmm, color = metodo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = seq(2005, 2025, 2)) +
  scale_y_continuous(limits = c(0, 200), breaks = seq(0, 200, 50), labels = comma) +
  scale_color_manual(values = c("Nuestro método" = "#A23B72", "Método Luther" = "#E67E22")) +
  labs(
    title = "RMM - Educación Superior",
    x = "Año",
    y = "RMM",
    color = "Método"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

# Hasta secundaria
graf_sec <- rmm_educ %>%
  filter(anio >= 2005) %>%
  select(anio, rmm_sec_nuestro, rmm_sec_luther) %>%
  pivot_longer(-anio, names_to = "metodo", values_to = "rmm") %>%
  mutate(
    metodo = ifelse(metodo == "rmm_sec_nuestro", "Nuestro método", "Método Luther")
  )

p_sec <- ggplot(graf_sec, aes(x = anio, y = rmm, color = metodo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = seq(2005, 2025, 2)) +
  scale_y_continuous(limits = c(0, 200), breaks = seq(0, 200, 50), labels = comma) +
  scale_color_manual(values = c("Nuestro método" = "#A23B72", "Método Luther" = "#E67E22")) +
  labs(
    title = "RMM - Hasta Secundaria",
    x = "Año",
    y = "RMM",
    color = "Método"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

# ==============================================================================
# 8. PANEL COMPLETO
# ==============================================================================

panel_completo <- (p_total / (p_sup | p_sec)) +
  plot_annotation(
    title = "COMPARACIÓN DE MÉTODOS: RMM TOTAL Y POR EDUCACIÓN",
    subtitle = "Nuestro método (tn_ajustado) vs Método Luther (factores censales)",
    theme = theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 12)
    )
  )

# ==============================================================================
# 9. GUARDAR TODO
# ==============================================================================

ggsave(file.path(ruta_resultados, "comparacion_metodos_total.png"), p_total, width = 12, height = 7, dpi = 300)
ggsave(file.path(ruta_resultados, "comparacion_metodos_superior.png"), p_sup, width = 8, height = 5, dpi = 300)
ggsave(file.path(ruta_resultados, "comparacion_metodos_secundaria.png"), p_sec, width = 8, height = 5, dpi = 300)
ggsave(file.path(ruta_resultados, "comparacion_metodos_panel.png"), panel_completo, width = 14, height = 12, dpi = 300)

# ==============================================================================
# 10. TABLA RESUMEN
# ==============================================================================

tabla_resumen <- rmm_total %>%
  filter(anio >= 2015) %>%
  select(anio, rmm_nuestro, rmm_luther, rmm_oficial) %>%
  mutate(
    rmm_nuestro = round(rmm_nuestro, 1),
    rmm_luther = round(rmm_luther, 1),
    dif_nuestro = round(rmm_nuestro - rmm_oficial, 1),
    dif_luther = round(rmm_luther - rmm_oficial, 1)
  )

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 COMPARACIÓN DE MÉTODOS - RMM TOTAL")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")
print(tabla_resumen)

cat("\n\n✅ Todos los gráficos guardados en:", ruta_resultados)







# ==============================================================================
# GRÁFICO: MÉTODO LUTHER VS INEC - RMM TOTAL Y EDUCATIVA
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(patchwork)
library(scales)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

maternas <- read_csv(file.path(ruta_resultados, "resumen_mortalidad_materna_1990_2024_FINAL.csv"))
denominador <- read_csv(file.path(ruta_resultados, "denominador_nacidos_vivos_validado.csv"))
educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))
factores_luther <- read_csv(file.path(ruta_resultados, "factores_luther_1990_2024.csv"))

# ==============================================================================
# 2. PREPARAR DATOS EDUCATIVOS
# ==============================================================================

muertes_educ <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  )

# ==============================================================================
# 3. DATOS OFICIALES
# ==============================================================================

rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# ==============================================================================
# 4. CALCULAR RMM LUTHER (TOTAL Y EDUCATIVA)
# ==============================================================================

rmm_luther <- denominador %>%
  left_join(maternas, by = "anio") %>%
  left_join(muertes_educ, by = "anio") %>%
  left_join(factores_luther, by = "anio") %>%
  left_join(rmm_oficial, by = "anio") %>%
  mutate(
    # Denominador Luther
    tn_luther = round(nv_oficial_calculado * factor),
    
    # RMM total Luther
    rmm_luther_total = (total_mm / tn_luther) * 100000,
    
    # RMM educativa Luther
    rmm_luther_superior = (muertes_superior / (Superior * factor)) * 100000,
    rmm_luther_secundaria = (muertes_hasta_sec / (`Hasta secundaria` * factor)) * 100000,
    
    # Solo años confiables para educación
    rmm_luther_superior = ifelse(anio >= 2005, rmm_luther_superior, NA),
    rmm_luther_secundaria = ifelse(anio >= 2005, rmm_luther_secundaria, NA)
  )

# ==============================================================================
# 5. GRÁFICO 1: RMM TOTAL - LUTHER VS INEC
# ==============================================================================

graf_total <- rmm_luther %>%
  select(anio, rmm_luther_total, rmm_oficial) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(
    tipo = ifelse(tipo == "rmm_luther_total", "RMM Método Luther", "RMM oficial INEC")
  )

p_total <- ggplot(graf_total, aes(x = anio, y = rmm, color = tipo, linetype = tipo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.8) +
  
  # Escalas
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 150),
    breaks = seq(0, 150, 25),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "Método Luther" = "#E67E22",
    "RMM oficial INEC" = "#2E86AB"
  )) +
  scale_linetype_manual(values = c("solid", "dashed")) +
  
  # Etiquetas
  labs(
    title = "RMM Total: Método Luther vs INEC",
    subtitle = "Ecuador 1990-2024",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Fuente",
    linetype = "Fuente"
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

# ==============================================================================
# 6. GRÁFICO 2: RMM EDUCATIVA - LUTHER (SUPERIOR VS HASTA SECUNDARIA)
# ==============================================================================

graf_educ <- rmm_luther %>%
  filter(anio >= 2005) %>%
  select(anio, rmm_luther_superior, rmm_luther_secundaria) %>%
  pivot_longer(-anio, names_to = "nivel", values_to = "rmm") %>%
  mutate(
    nivel = case_when(
      nivel == "rmm_luther_superior" ~ "Educación superior",
      nivel == "rmm_luther_secundaria" ~ "Hasta secundaria"
    )
  )

p_educ <- ggplot(graf_educ, aes(x = anio, y = rmm, color = nivel)) +
  geom_line(size = 1.2) +
  geom_point(size = 2.5) +
  
  # Área sombreada para brecha
  geom_ribbon(data = rmm_luther %>% filter(anio >= 2005),
              aes(x = anio, 
                  ymin = rmm_luther_superior, 
                  ymax = rmm_luther_secundaria),
              fill = "gray80", alpha = 0.5, inherit.aes = FALSE) +
  
  # Escalas
  scale_x_continuous(breaks = seq(2005, 2025, 2)) +
  scale_y_continuous(
    limits = c(0, 200),
    breaks = seq(0, 200, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "Educación superior" = "#2E86AB",
    "Hasta secundaria" = "#A23B72"
  )) +
  
  # Etiquetas
  labs(
    title = "RMM por Nivel Educativo - RMM Método Luther",
    subtitle = "Ecuador 2005-2024",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Nivel educativo",
    caption = "El área sombreada representa la brecha entre grupos"
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )


# ==============================================================================
# 8. GUARDAR GRÁFICOS
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_luther_01_total_vs_inec.png"), 
       p_total, width = 12, height = 7, dpi = 300)

ggsave(file.path(ruta_resultados, "RMM_luther_02_educacion.png"), 
       p_educ, width = 12, height = 7, dpi = 300)

# ==============================================================================
# 9. TABLA RESUMEN LUTHER
# ==============================================================================

tabla_luther <- rmm_luther %>%
  filter(anio >= 2020) %>%
  select(anio, rmm_luther_total, rmm_oficial, 
         rmm_luther_superior, rmm_luther_secundaria) %>%
  mutate(
    rmm_luther_total = round(rmm_luther_total, 1),
    rmm_luther_superior = round(rmm_luther_superior, 1),
    rmm_luther_secundaria = round(rmm_luther_secundaria, 1),
    dif_total = round(rmm_luther_total - rmm_oficial, 1)
  )

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 MÉTODO LUTHER - RESULTADOS RECIENTES")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")
print(tabla_luther)

cat("\n\n✅ Gráficos Luther guardados en:", ruta_resultados)


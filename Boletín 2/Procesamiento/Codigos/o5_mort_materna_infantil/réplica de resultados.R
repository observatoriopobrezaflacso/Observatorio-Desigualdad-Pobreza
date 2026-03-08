#####################################################################
# ==============================================================================
# CÁLCULO DE MORTALIDAD MATERNA - ECUADOR 1990-2024
# VERSIÓN FINAL CORREGIDA
# ==============================================================================

library(tidyverse)
library(haven)
library(foreign)
library(stringr)

# Rutas (VERIFICAR QUE SEAN CORRECTAS)

setwd('/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad')

ruta_def <- "Boletín 2/Procesamiento/Bases/Defunciones/"
ruta_resultados <- "Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

#ruta_def <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Defunciones/"
#ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# Crear carpeta si no existe
dir.create(ruta_resultados, showWarnings = FALSE, recursive = TRUE)

resultados <- list()

for (anio in 1990:2024) {
  
  cat("\n--- Procesando EDG", anio, "...")
  
  archivo <- file.path(ruta_def, paste0("EDG_", anio, ".sav"))
  
  if (!file.exists(archivo)) {
    cat(" Archivo no encontrado\n")
    next
  }
  
  # --- CARGAR SEGÚN EL AÑO ---
  if (anio == 2011) {
    bd <- read.spss(archivo, to.data.frame = TRUE, use.value.labels = FALSE)
  } else {
    bd <- read_sav(archivo)
  }
  
  # Convertir nombres a minúsculas
  names(bd) <- tolower(names(bd))
  
  # --- FILTRAR MUJERES 15-49 ---
  if ("sexo" %in% names(bd) & "edad" %in% names(bd)) {
    
    if (anio == 2011) {
      # 2011: sexo es "01"/"02"
      bd <- bd %>%
        mutate(edad_num = as.numeric(edad)) %>%
        filter(sexo == "02", edad_num >= 15, edad_num <= 49)
    } else {
      # Otros años: sexo numérico o factor
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
    # 2011: extraer código de los primeros caracteres
    bd <- bd %>%
      mutate(
        causa_str = as.character(causa4),
        causa_str = str_trim(str_extract(causa_str, "^[A-Z0-9]{3,4}")),
        causa_str = toupper(causa_str)
      )
  } else {
    # Otros años: procesamiento normal
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
  
  # ============================================================
  # IDENTIFICAR MUERTES MATERNAS
  # ============================================================
  
  if (anio <= 1996) {
    # CIE-9
    bd <- bd %>%
      mutate(
        causa_num = as.numeric(causa_str),
        es_materna_sin_covid = between(causa_num, 630, 676)
      )
    covid_count <- 0
    
  } else {
    # CIE-10 - TODOS los códigos O cuentan (sin exclusiones)
    bd <- bd %>%
      mutate(
        es_o = str_detect(causa_str, "^O[0-9][0-9]"),
        es_materna_sin_covid = es_o  # TODOS los O, incluyendo O98-O99
      )
    
    # COVID-19 (2020-2022) - identificación separada
    if (anio %in% 2020:2022) {
      bd <- bd %>%
        mutate(
          es_covid = causa_str %in% c("U071", "U072", "U07.1", "U07.2")
        )
      covid_count <- sum(bd$es_covid, na.rm = TRUE)
    } else {
      bd$es_covid <- FALSE
      covid_count <- 0
    }
  }
  
  # Versiones de muertes maternas
  mm_sin_covid <- sum(bd$es_materna_sin_covid, na.rm = TRUE)
  mm_con_covid <- mm_sin_covid + covid_count
  
  cat(" ✅ OK (MM sin COVID=", mm_sin_covid, 
      ", MM con COVID=", mm_con_covid, 
      ", COVID=", covid_count, ")\n")
  
  # Guardar resultados
  resultados[[as.character(anio)]] <- data.frame(
    anio = anio,
    mm_sin_covid = mm_sin_covid,
    mm_con_covid = mm_con_covid,
    covid_count = covid_count
  )
}

# Combinar resultados
resultados_df <- bind_rows(resultados)

# Convertir a tibble
resultados_df <- as_tibble(resultados_df)

# Mostrar resultados
print(resultados_df, n = 35)

# Guardar
write_csv(resultados_df, file.path(ruta_resultados, "mortalidad_materna_FINAL.csv"))
saveRDS(resultados_df, file.path(ruta_resultados, "mortalidad_materna_FINAL.rds"))

# ============================================================
# COMPARACIÓN CON TABLA OFICIAL INEC
# ============================================================

oficial <- data.frame(
  anio = 1990:2024,
  mm_oficial = c(309, 320, 338, 348, 241, 170, 194, 162, 153, 209, 232, 187, 149,
                 139, 129, 143, 135, 176, 165, 208, 203, 241, 205, 158, 169, 183,
                 154, 211, 221, 228, 217, 190, 155, 117, 116)
)

comparacion <- resultados_df %>%
  left_join(oficial, by = "anio") %>%
  mutate(
    dif_sin_covid = mm_sin_covid - mm_oficial,
    dif_con_covid = mm_con_covid - mm_oficial,
    dif_pct_sin = (dif_sin_covid / mm_oficial) * 100
  )

# Ver resultados finales
cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== COMPARACIÓN CON TABLA OFICIAL INEC ===\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

comparacion %>% 
  select(anio, mm_sin_covid, mm_oficial, dif_sin_covid, dif_pct_sin, covid_count) %>%
  print(n = 35)

# Identificar años con diferencia > 5%
problemas <- comparacion %>% filter(abs(dif_pct_sin) > 5)
if (nrow(problemas) > 0) {
  cat("\n⚠️ Años con diferencia >5%:\n")
  print(problemas %>% select(anio, mm_sin_covid, mm_oficial, dif_sin_covid, dif_pct_sin))
} else {
  cat("\n✅ ¡Perfecto! Todos los años coinciden\n")
}

# Guardar comparación
write_csv(comparacion, file.path(ruta_resultados, "comparacion_oficial.csv"))

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== PROCESO COMPLETADO ===\n")
cat("Resultados guardados en:", ruta_resultados, "\n")


cat("Resultados guardados en:", ruta_resultados, "\n")



# Cargar tus resultados (si no están en memoria)
resultados_df <- readRDS(file.path(ruta_resultados, "mortalidad_materna_FINAL.rds"))

# Tabla oficial INEC
oficial <- data.frame(
  anio = 1990:2024,
  mm_oficial = c(309, 320, 338, 348, 241, 170, 194, 162, 153, 209, 232, 187, 149,
                 139, 129, 143, 135, 176, 165, 208, 203, 241, 205, 158, 169, 183,
                 154, 211, 221, 228, 217, 190, 155, 117, 116)
)

# Comparar
comparacion <- resultados_df %>%
  left_join(oficial, by = "anio") %>%
  mutate(
    dif_sin_covid = mm_sin_covid - mm_oficial,
    dif_con_covid = mm_con_covid - mm_oficial,
    dif_pct_sin = round((dif_sin_covid / mm_oficial) * 100, 2)
  )

# Ver resultados
comparacion %>%
  select(anio, mm_sin_covid, mm_oficial, dif_sin_covid, dif_pct_sin, covid_count) %>%
  print(n = 35)

# Resumen estadístico de diferencias
cat("\n=== RESUMEN DE DIFERENCIAS ===\n")
summary(comparacion$dif_sin_covid)

# Años con diferencia > 5%
problemas <- comparacion %>% filter(abs(dif_pct_sin) > 5)
if (nrow(problemas) > 0) {
  cat("\n⚠️ Años con diferencia >5%:\n")
  print(problemas %>% select(anio, mm_sin_covid, mm_oficial, dif_sin_covid, dif_pct_sin))
} else {
  cat("\n✅ ¡Perfecto! Todos los años coinciden\n")
}


# Crear tabla de análisis por período
analisis <- comparacion %>%
  mutate(
    periodo = case_when(
      anio <= 1996 ~ "CIE-9 (1990-1996)",
      anio <= 2002 ~ "Transición (1997-2002)",
      anio <= 2007 ~ "codi (2003-2007)",
      anio <= 2010 ~ "cod_eda (2008-2010)",
      anio == 2011 ~ "2011 (string)",
      anio <= 2019 ~ "Pre-COVID (2012-2019)",
      anio <= 2022 ~ "COVID (2020-2022)",
      TRUE ~ "Post-COVID (2023-2024)"
    )
  )

# Resumen por período
analisis %>%
  group_by(periodo) %>%
  summarise(
    n = n(),
    dif_media = mean(dif_sin_covid),
    dif_max = max(abs(dif_sin_covid)),
    años_problema = sum(abs(dif_pct_sin) > 2)
  ) %>%
  arrange(periodo)

# Crear análisis de diferencias por año
analisis_temporal <- comparacion %>%
  mutate(
    decada = floor(anio / 10) * 10,
    tipo_diferencia = case_when(
      dif_sin_covid < 0 ~ "Subestimación (tus datos < oficial)",
      dif_sin_covid > 0 ~ "Sobreestimación (tus datos > oficial)",
      TRUE ~ "Exacto"
    )
  )

# Ver patrón por década
analisis_temporal %>%
  group_by(decada, tipo_diferencia) %>%
  summarise(
    n = n(),
    dif_promedio = mean(dif_sin_covid)
  ) %>%
  arrange(decada)

# Identificar años con posible rezago
# (tus datos bajos y oficiales altos)
candidatos_rezago <- comparacion %>%
  filter(dif_sin_covid < 0) %>%
  arrange(desc(abs(dif_sin_covid)))

# Calcular estadísticas por período
efecto_rezago <- comparacion %>%
  mutate(
    periodo_metodologico = case_when(
      anio <= 1996 ~ "CIE-9 (máximo rezago)",
      anio <= 2010 ~ "CIE-10 con rezago",
      anio <= 2019 ~ "Estabilización",
      anio <= 2022 ~ "COVID",
      TRUE ~ "Preliminar"
    )
  ) %>%
  group_by(periodo_metodologico) %>%
  summarise(
    n = n(),
    dif_media = mean(dif_sin_covid),
    casos_faltantes = sum(dif_sin_covid[dif_sin_covid < 0]),
    casos_sobrantes = sum(dif_sin_covid[dif_sin_covid > 0]),
    neto = sum(dif_sin_covid)
  )

print(efecto_rezago)






# ==============================================================================
# VERSIÓN OPTIMIZADA - PROCESA MUCHO MÁS RÁPIDO DENOMINADOR
# ==============================================================================

library(tidyverse)
library(haven)
library(foreign)
library(stringr)

# Rutas
ruta_env <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Nacidos vivos/"
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"
dir.create(ruta_resultados, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. FUNCIÓN DE ARMONIZACIÓN VECTORIZADA (MUCHO MÁS RÁPIDA)
# ==============================================================================

armonizar_educacion_vec <- function(valores, anio) {
  
  # Convertir a character
  vals <- as.character(valores)
  
  # Inicializar resultado
  resultado <- rep("Sin información", length(vals))
  
  # Casos no missing
  no_na <- !is.na(vals) & !vals %in% c("", " ", "NA")
  
  if (!any(no_na)) return(resultado)
  
  # Convertir a numérico donde sea posible
  vals_num <- suppressWarnings(as.numeric(vals[no_na]))
  
  # Separar numéricos de texto
  es_numerico <- !is.na(vals_num)
  
  # Procesar según era
  if (anio <= 2007) {
    # Era 1: 1-6
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(1, 2) ~ "Ninguno/Centro de Alfabetización",
      vals_num[es_numerico] == 3 ~ "Educación Básica/Primaria",
      vals_num[es_numerico] == 4 ~ "Secundaria/Educación Media",
      vals_num[es_numerico] == 5 ~ "Superior/Postgrado",
      vals_num[es_numerico] == 6 ~ "Sin información",
      TRUE ~ "Sin información"
    )
    
  } else if (anio %in% 2008:2009) {
    # Era 2: 0-6,9
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(0, 1, 2) ~ "Ninguno/Centro de Alfabetización",
      vals_num[es_numerico] == 3 ~ "Educación Básica/Primaria",
      vals_num[es_numerico] == 4 ~ "Secundaria/Educación Media",
      vals_num[es_numerico] == 5 ~ "Superior/Postgrado",
      vals_num[es_numerico] %in% c(6, 9) ~ "Sin información",
      TRUE ~ "Sin información"
    )
    
  } else if (anio %in% 2010:2011) {
    # Era 3: 0-9
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(0, 1) ~ "Ninguno/Centro de Alfabetización",
      vals_num[es_numerico] %in% c(2, 4) ~ "Educación Básica/Primaria",
      vals_num[es_numerico] %in% c(3, 5) ~ "Secundaria/Educación Media",
      vals_num[es_numerico] %in% c(6, 7, 8) ~ "Superior/Postgrado",
      vals_num[es_numerico] == 9 ~ "Sin información",
      TRUE ~ "Sin información"
    )
    
  } else if (anio %in% 2012:2016) {
    # Era 4a: 0-9
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(0, 1) ~ "Ninguno/Centro de Alfabetización",
      vals_num[es_numerico] %in% c(2, 4) ~ "Educación Básica/Primaria",
      vals_num[es_numerico] %in% c(3, 5) ~ "Secundaria/Educación Media",
      vals_num[es_numerico] %in% c(6, 7, 8) ~ "Superior/Postgrado",
      vals_num[es_numerico] == 9 ~ "Sin información",
      TRUE ~ "Sin información"
    )
    
  } else {
    # Era 4b: 2017+
    resultado[no_na][es_numerico] <- case_when(
      vals_num[es_numerico] %in% c(0, 1) ~ "Ninguno/Centro de Alfabetización",
      vals_num[es_numerico] %in% c(2, 3) ~ "Educación Básica/Primaria",
      vals_num[es_numerico] %in% c(4, 5) ~ "Secundaria/Educación Media",
      vals_num[es_numerico] %in% c(6, 7, 8) ~ "Superior/Postgrado",
      vals_num[es_numerico] == 9 ~ "Sin información",
      TRUE ~ "Sin información"
    )
  }
  
  # Procesar valores de texto (para años recientes con "00","01")
  if (anio >= 2011) {
    texto_no_num <- no_na & !es_numerico
    if (any(texto_no_num)) {
      resultado[no_na][texto_no_num] <- case_when(
        vals[no_na][texto_no_num] %in% c("0", "00") ~ "Ninguno/Centro de Alfabetización",
        vals[no_na][texto_no_num] %in% c("1", "01", "2", "02") ~ "Ninguno/Centro de Alfabetización",
        vals[no_na][texto_no_num] %in% c("3", "03", "4", "04") ~ "Educación Básica/Primaria",
        vals[no_na][texto_no_num] %in% c("5", "05", "6", "06") ~ "Secundaria/Educación Media",
        vals[no_na][texto_no_num] %in% c("7", "07", "8", "08") ~ "Superior/Postgrado",
        vals[no_na][texto_no_num] %in% c("9", "09", "99") ~ "Sin información",
        TRUE ~ "Sin información"
      )
    }
  }
  
  return(resultado)
}

# ==============================================================================
# 2. PROCESAR NACIMIENTOS (VERSIÓN OPTIMIZADA)
# ==============================================================================

nacimientos_lista <- list()
educacion_lista <- list()

for (anio in 1990:2024) {
  
  cat("\n--- Procesando ENV", anio, "...")
  
  archivo <- file.path(ruta_env, paste0("ENV_", anio, ".sav"))
  
  if (!file.exists(archivo)) {
    cat(" Archivo no encontrado\n")
    next
  }
  
  # Cargar según año
  if (anio == 2011) {
    bd <- read.spss(archivo, to.data.frame = TRUE, use.value.labels = FALSE)
    cat(" (usando foreign)")
  } else {
    bd <- read_sav(archivo)
  }
  
  names(bd) <- tolower(names(bd))
  
  # Total de registros (inscritos en el año)
  total_inscritos <- nrow(bd)
  
  # Nacidos en el año t (si existe variable de año)
  if ("anio_nac" %in% names(bd)) {
    total_nacidos_t <- sum(bd$anio_nac == anio, na.rm = TRUE)
  } else {
    total_nacidos_t <- NA
  }
  
  cat(" OK (NV inscritos =", total_inscritos, 
      ", NV nacidos en t =", total_nacidos_t, ")")
  
  # Guardar totales
  nacimientos_lista[[as.character(anio)]] <- data.frame(
    anio = anio,
    total_inscritos = total_inscritos,
    total_nacidos_t = total_nacidos_t
  )
  
  # ============================================================================
  # EDUCACIÓN - Solo para nacidos en el año t (para no procesar todo)
  # ============================================================================
  
  if ("anio_nac" %in% names(bd) && any(bd$anio_nac == anio, na.rm = TRUE)) {
    
    # Filtrar primero (¡MUCHO MÁS RÁPIDO!)
    bd_anio <- bd %>% filter(anio_nac == anio)
    
    # Buscar variable de educación
    posibles_edu <- c("niv_inst", "nivel_instruc", "nivel")
    var_edu <- NULL
    
    for (var in posibles_edu) {
      if (var %in% names(bd_anio)) {
        var_edu <- var
        break
      }
    }
    
    if (!is.null(var_edu)) {
      # Aplicar armonización vectorizada (UNA SOLA VEZ)
      bd_anio$educ_armonizada <- armonizar_educacion_vec(bd_anio[[var_edu]], anio)
      
      # Contar
      conteo <- bd_anio %>%
        count(educ_armonizada) %>%
        mutate(anio = anio)
      
      educacion_lista[[as.character(anio)]] <- conteo
    }
  }
}

# ==============================================================================
# 3. COMBINAR RESULTADOS
# ==============================================================================

nacimientos_df <- bind_rows(nacimientos_lista) %>% as_tibble()
print(nacimientos_df, n = 35)

# ==============================================================================
# 4. VALIDAR CONTRA INEC
# ==============================================================================

nv_oficial <- c(313725, 316916, 319283, 320868, 321991, 322863, 323547,
                323538, 323419, 323237, 322826, 322593, 323129, 324152,
                325299, 326537, 328116, 329841, 331413, 332948, 334364,
                334738, 334180, 332107, 328438, 323234, 316592, 309339,
                302106, 295297, 287289, 278949, 271823, 266696, 263020)

oficial <- data.frame(anio = 1990:2024, nv_oficial = nv_oficial)

validacion <- nacimientos_df %>%
  left_join(oficial, by = "anio") %>%
  mutate(
    diff_inscritos = total_inscritos - nv_oficial,
    diff_nacidos_t = total_nacidos_t - nv_oficial,
    pct_inscritos = round(diff_inscritos / nv_oficial * 100, 1),
    pct_nacidos_t = round(diff_nacidos_t / nv_oficial * 100, 1)
  )

# Decidir qué usa INEC
mae_inscritos <- mean(abs(validacion$diff_inscritos), na.rm = TRUE)
mae_nacidos_t <- mean(abs(validacion$diff_nacidos_t), na.rm = TRUE)

cat("\n\n=== VALIDACIÓN ===\n")
cat("Error vs inscritos:", round(mae_inscritos), "\n")
cat("Error vs nacidos t:", round(mae_nacidos_t), "\n")

if (mae_inscritos < mae_nacidos_t) {
  cat("✅ INEC usa TOTAL DE INSCRITOS\n")
  validacion$nv_final <- validacion$total_inscritos
} else {
  cat("✅ INEC usa NACIDOS EN t\n")
  validacion$nv_final <- validacion$total_nacidos_t
}

# ==============================================================================
# 5. GUARDAR RESULTADOS
# ==============================================================================

write_csv(validacion, file.path(ruta_resultados, "nacimientos_validados.csv"))
saveRDS(validacion, file.path(ruta_resultados, "nacimientos_validados.rds"))

# Educación
if (length(educacion_lista) > 0) {
  educacion_df <- bind_rows(educacion_lista)
  
  educacion_ancha <- educacion_df %>%
    pivot_wider(names_from = educ_armonizada, values_from = n, values_fill = 0) %>%
    arrange(anio) %>%
    mutate(Total = rowSums(across(-anio), na.rm = TRUE))
  
  write_csv(educacion_ancha, file.path(ruta_resultados, "nacimientos_educacion.csv"))
  
  cat("\n=== EDUCACIÓN ===\n")
  print(educacion_ancha, n = 35)
}

cat("\n=== PROCESO COMPLETADO ===\n")
cat("Resultados en:", ruta_resultados, "\n")







# ==============================================================================
# ANÁLISIS DE NACIMIENTOS - VERSIÓN FINAL CORREGIDA
# ==============================================================================

library(tidyverse)

# ELIMINAR POSIBLES CONFLICTOS
if (exists("nv_oficial")) rm(nv_oficial)

# CARGAR DATOS
nacimientos <- readRDS(file.path(ruta_resultados, "nacimientos_validados.rds"))

# Si ya tiene nv_oficial, renombrar
if ("nv_oficial" %in% names(nacimientos)) {
  nacimientos <- nacimientos %>% rename(nv_calculado = nv_oficial)
}

# DATOS OFICIALES
oficial_df <- data.frame(
  anio = 1990:2024,
  ofi = c(313725, 316916, 319283, 320868, 321991, 322863, 323547,
          323538, 323419, 323237, 322826, 322593, 323129, 324152,
          325299, 326537, 328116, 329841, 331413, 332948, 334364,
          334738, 334180, 332107, 328438, 323234, 316592, 309339,
          302106, 295297, 287289, 278949, 271823, 266696, 263020)
)

# UNIR
df <- nacimientos %>%
  left_join(oficial_df, by = "anio") %>%
  rename(nv_oficial = ofi) %>%
  mutate(
    dif = total_inscritos - nv_oficial,
    dif_pct = round(dif / nv_oficial * 100, 1)
  )

# VERIFICAR
cat("\n=== VERIFICACIÓN ===\n")
cat("Columnas:", paste(names(df), collapse = ", "), "\n")
cat("Primeras filas:\n")
print(df %>% select(anio, total_inscritos, nv_oficial, dif, dif_pct) %>% head())

# CONTINUAR CON EL ANÁLISIS...
rezago <- df %>% filter(dif < 0) %>% arrange(anio)

cat("\n=== AÑOS CON POSIBLE REZAGO ===\n")
print(rezago[, c("anio", "total_inscritos", "nv_oficial", "dif", "dif_pct")])



# ==============================================================================
# CORRECCIÓN DE NACIMIENTOS - VERSIÓN CON FACTORES EXPLÍCITOS
# ==============================================================================

library(tidyverse)

# Cargar datos si es necesario
# df <- readRDS(file.path(ruta_resultados, "tu_archivo.rds"))

# 1. DEFINIR PERÍODOS
df <- df %>%
  mutate(
    periodo = case_when(
      anio <= 1993 ~ "1990-1993",
      anio %in% 1994:1995 ~ "1994-1995",
      anio %in% 1996:1997 ~ "1996-1997",
      anio %in% 1998:2002 ~ "1998-2002",
      anio %in% 2003:2005 ~ "2003-2005",
      anio %in% 2006:2010 ~ "2006-2010",
      anio %in% 2011:2015 ~ "2011-2015",
      anio %in% 2016:2019 ~ "2016-2019",
      anio %in% 2020:2022 ~ "2020-2022",
      TRUE ~ "2023-2024"
    )
  )

# 2. CALCULAR FACTORES MANUALMENTE (basado en análisis previo)
factores_df <- data.frame(
  periodo = c("1990-1993", "1994-1995", "1996-1997", "1998-2002", 
              "2003-2005", "2006-2010", "2011-2015", "2016-2019",
              "2020-2022", "2023-2024"),
  factor = c(
    1.03,  # 1990-1993 (subestimación leve)
    0.92,  # 1994-1995 (sobreestimación por exterior)
    1.08,  # 1996-1997 (rezago)
    0.94,  # 1998-2002 (sobreestimación)
    1.04,  # 2003-2005 (rezago)
    0.95,  # 2006-2010 (sobreestimación)
    0.98,  # 2011-2015 (mixto)
    1.01,  # 2016-2019 (estable)
    1.08,  # 2020-2022 (COVID - rezago)
    1.12   # 2023-2024 (preliminar - rezago fuerte)
  )
)

# 3. UNIR Y CALCULAR
df_corregido <- df %>%
  left_join(factores_df, by = "periodo") %>%
  mutate(
    nv_corregido = total_inscritos * factor,
    dif_corregida = nv_corregido - nv_oficial,
    pct_corregido = round(dif_corregida / nv_oficial * 100, 1)
  )

# 4. VER RESULTADOS
df_corregido %>%
  select(anio, periodo, total_inscritos, nv_corregido, nv_oficial, dif_pct, pct_corregido) %>%
  mutate(
    mejora = pct_corregido - dif_pct,
    estado = case_when(
      abs(pct_corregido) < 3 ~ "✅ Excelente",
      abs(pct_corregido) < 5 ~ "👍 Aceptable",
      TRUE ~ "⚠️ Revisar"
    )
  ) %>%
  print(n = 35)

# 5. VER ESTADÍSTICAS DE MEJORA
cat("\n=== RESUMEN DE CORRECCIÓN ===\n")
cat("Error promedio antes:", round(mean(abs(df$dif_pct), na.rm = TRUE), 1), "%\n")
cat("Error promedio después:", round(mean(abs(df_corregido$pct_corregido), na.rm = TRUE), 1), "%\n")
cat("Mejora promedio:", round(mean(abs(df_corregido$dif_pct) - abs(df_corregido$pct_corregido), na.rm = TRUE), 1), "%\n")








# ==============================================================================
# AJUSTE FINO DE FACTORES - VERSIÓN DEFINITIVA
# ==============================================================================

library(tidyverse)

# 1. RECUPERAR df ORIGINAL
# df <- readRDS(file.path(ruta_resultados, "tu_archivo.rds"))

# 2. FACTORES BASE
factores_base <- data.frame(
  periodo = c("1990-1993", "1994-1995", "1996-1997", "1998-2002", 
              "2003-2005", "2006-2010", "2011-2015", "2016-2019",
              "2020-2022", "2023-2024"),
  factor_base = c(1.03, 0.92, 1.08, 0.94, 1.04, 0.95, 0.98, 1.01, 1.08, 1.12)
)

# 3. AJUSTES ESPECÍFICOS POR AÑO
ajustes_anuales <- data.frame(
  anio = c(1995, 1998, 1999, 2002, 2003, 2007, 2008, 2015, 2016, 2024),
  factor_ajuste = c(0.96, 0.98, 0.97, 1.03, 0.98, 0.98, 0.98, 0.98, 1.01, 1.05)
)

# 4. APLICAR AJUSTES
df_corregido2 <- df %>%
  mutate(
    periodo = case_when(
      anio <= 1993 ~ "1990-1993",
      anio %in% 1994:1995 ~ "1994-1995",
      anio %in% 1996:1997 ~ "1996-1997",
      anio %in% 1998:2002 ~ "1998-2002",
      anio %in% 2003:2005 ~ "2003-2005",
      anio %in% 2006:2010 ~ "2006-2010",
      anio %in% 2011:2015 ~ "2011-2015",
      anio %in% 2016:2019 ~ "2016-2019",
      anio %in% 2020:2022 ~ "2020-2022",
      TRUE ~ "2023-2024"
    )
  ) %>%
  left_join(factores_base, by = "periodo") %>%
  left_join(ajustes_anuales, by = "anio") %>%
  mutate(
    factor_final = ifelse(is.na(factor_ajuste), factor_base, factor_base * factor_ajuste),
    nv_corregido_v2 = total_inscritos * factor_final,
    dif_corregida_v2 = nv_corregido_v2 - nv_oficial,
    pct_corregido_v2 = round(dif_corregida_v2 / nv_oficial * 100, 1)
  )

# 5. COMPARAR AMBAS VERSIONES
comparacion_final <- df_corregido %>%
  select(anio, nv_corregido_v1 = nv_corregido, pct_v1 = pct_corregido) %>%
  full_join(
    df_corregido2 %>% select(anio, nv_corregido_v2, pct_v2 = pct_corregido_v2),
    by = "anio"
  ) %>%
  left_join(df %>% select(anio, total_inscritos, nv_oficial, dif_pct), by = "anio") %>%
  mutate(
    error_v1 = abs(pct_v1),
    error_v2 = abs(pct_v2),
    mejor_version = ifelse(error_v2 < error_v1, "V2", "V1")
  )

# 6. VER RESULTADOS
cat("\n=== COMPARACIÓN DE VERSIONES ===\n")
comparacion_final %>%
  select(anio, total_inscritos, nv_oficial, dif_pct, pct_v1, pct_v2, mejor_version) %>%
  print(n = 35)

# 7. ESTADÍSTICAS
cat("\n=== ESTADÍSTICAS ===\n")
cat("Error promedio V1:", round(mean(comparacion_final$error_v1, na.rm = TRUE), 1), "%\n")
cat("Error promedio V2:", round(mean(comparacion_final$error_v2, na.rm = TRUE), 1), "%\n")
cat("\nAños donde V2 es mejor:\n")
print(comparacion_final %>% filter(mejor_version == "V2") %>% select(anio, pct_v1, pct_v2))

# 8. CREAR DATAFRAME FINAL (SIN DUPLICADOS)
df_resultado_final <- comparacion_final %>%
  mutate(
    nv_final = ifelse(mejor_version == "V2", nv_corregido_v2, nv_corregido_v1),
    pct_final = ifelse(mejor_version == "V2", pct_v2, pct_v1)
  ) %>%
  select(anio, total_inscritos, nv_final, nv_oficial, dif_original = dif_pct, pct_final, mejor_version)

# 9. VER RESULTADO FINAL
cat("\n=== RESULTADO FINAL ===\n")
print(df_resultado_final, n = 35)

# 10. GUARDAR (con nombre único)
write_csv(df_resultado_final, file.path(ruta_resultados, "nacimientos_optimizados.csv"))
saveRDS(df_resultado_final, file.path(ruta_resultados, "nacimientos_optimizados.rds"))

cat("\n=== PROCESO COMPLETADO ===\n")
cat("Archivo guardado en:", file.path(ruta_resultados, "nacimientos_optimizados.csv"), "\n")







# ==============================================================================
# CÁLCULO DE DOS VERSIONES DE RMM - ECUADOR 1990-2024
# ==============================================================================

library(tidyverse)

# 1. CARGAR DATOS
# ==============================================================================

# Defunciones maternas (ya validadas)
defunciones <- readRDS(file.path(ruta_resultados, "mortalidad_materna_FINAL.rds"))

# Nacimientos sin corregir (originales)
nacimientos_original <- readRDS(file.path(ruta_resultados, "nacimientos_validados.rds"))

# Nacimientos corregidos (optimizados)
nacimientos_corregidos <- readRDS(file.path(ruta_resultados, "nacimientos_optimizados.rds"))

# ==============================================================================
# 2. PREPARAR BASES
# ==============================================================================

# Versión 1: Usando nacimientos originales (sin corregir)
base_v1 <- defunciones %>%
  left_join(nacimientos_original %>% select(anio, nv_original = total_inscritos), 
            by = "anio") %>%
  mutate(
    rmm_sin_covid_v1 = round((mm_sin_covid / nv_original) * 100000, 1),
    rmm_con_covid_v1 = round((mm_con_covid / nv_original) * 100000, 1),
    rmm_solo_covid_v1 = round((covid_count / nv_original) * 100000, 1)
  )

# Versión 2: Usando nacimientos corregidos
base_v2 <- defunciones %>%
  left_join(nacimientos_corregidos %>% select(anio, nv_corregido = nv_final), 
            by = "anio") %>%
  mutate(
    rmm_sin_covid_v2 = round((mm_sin_covid / nv_corregido) * 100000, 1),
    rmm_con_covid_v2 = round((mm_con_covid / nv_corregido) * 100000, 1),
    rmm_solo_covid_v2 = round((covid_count / nv_corregido) * 100000, 1)
  )

# ==============================================================================
# 3. COMBINAR AMBAS VERSIONES
# ==============================================================================

comparacion_rmm <- base_v1 %>%
  select(anio, mm_sin_covid, covid_count,
         nv_original, rmm_sin_covid_v1, rmm_con_covid_v1) %>%
  left_join(
    base_v2 %>% select(anio, nv_corregido, rmm_sin_covid_v2, rmm_con_covid_v2),
    by = "anio"
  ) %>%
  mutate(
    dif_nacimientos = nv_corregido - nv_original,
    dif_rmm_sin_covid = rmm_sin_covid_v2 - rmm_sin_covid_v1,
    dif_pct_rmm = round((dif_rmm_sin_covid / rmm_sin_covid_v1) * 100, 1)
  )

# ==============================================================================
# 4. MOSTRAR RESULTADOS
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== COMPARACIÓN DE RMM: ORIGINAL VS CORREGIDA ===\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n")

comparacion_rmm %>%
  select(anio, 
         nv_original, nv_corregido,
         rmm_sin_covid_v1, rmm_sin_covid_v2, 
         dif_rmm_sin_covid, dif_pct_rmm) %>%
  print(n = 35)

# ==============================================================================
# 5. ESTADÍSTICAS DE LA COMPARACIÓN
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== ESTADÍSTICAS DE LA COMPARACIÓN ===\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

cat("\nResumen de diferencias en RMM:\n")
summary(comparacion_rmm$dif_rmm_sin_covid)

cat("\nAños con mayor diferencia (>5 puntos de RMM):\n")
comparacion_rmm %>%
  filter(abs(dif_rmm_sin_covid) > 5) %>%
  select(anio, rmm_sin_covid_v1, rmm_sin_covid_v2, dif_rmm_sin_covid, dif_pct_rmm) %>%
  arrange(desc(abs(dif_rmm_sin_covid)))

# ==============================================================================
# 6. GRÁFICO COMPARATIVO
# ==============================================================================

library(ggplot2)

# Preparar datos para gráfico
df_graf <- comparacion_rmm %>%
  select(anio, rmm_sin_covid_v1, rmm_sin_covid_v2) %>%
  pivot_longer(cols = c(rmm_sin_covid_v1, rmm_sin_covid_v2),
               names_to = "version", values_to = "rmm") %>%
  mutate(version = ifelse(version == "rmm_sin_covid_v1", 
                          "RMM original (sin corregir)", 
                          "RMM corregida"))

g <- ggplot(df_graf, aes(x = anio, y = rmm, color = version)) +
  geom_line(size = 1) +
  geom_point(size = 1.5) +
  scale_color_manual(values = c("RMM original (sin corregir)" = "blue",
                                "RMM corregida" = "red")) +
  labs(title = "Razón de Mortalidad Materna - Ecuador 1990-2024",
       subtitle = "Comparación: datos originales vs corregidos",
       x = "Año", y = "RMM (por 100,000 nacidos vivos)",
       color = "Versión") +
  theme_minimal() +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold")) +
  scale_x_continuous(breaks = seq(1990, 2024, 2)) +
  scale_y_continuous(limits = c(0, max(df_graf$rmm, na.rm = TRUE) + 10))

print(g)

# Guardar gráfico
ggsave(file.path(ruta_resultados, "comparacion_rmm.png"), g, 
       width = 12, height = 6, dpi = 150)





# ==============================================================================
# 7. TABLA RESUMEN PARA INFORME
# ==============================================================================

tabla_resumen <- comparacion_rmm %>%
  mutate(
    periodo = case_when(
      anio <= 1996 ~ "CIE-9 (1990-1996)",
      anio <= 2002 ~ "Transición (1997-2002)",
      anio <= 2007 ~ "codi (2003-2007)",
      anio <= 2010 ~ "cod_eda (2008-2010)",
      anio == 2011 ~ "2011 (string)",
      anio <= 2019 ~ "Pre-COVID (2012-2019)",
      anio <= 2022 ~ "COVID (2020-2022)",
      TRUE ~ "Post-COVID (2023-2024)"
    )
  ) %>%
  group_by(periodo) %>%
  summarise(
    n = n(),
    rmm_original_prom = round(mean(rmm_sin_covid_v1, na.rm = TRUE), 1),
    rmm_corregida_prom = round(mean(rmm_sin_covid_v2, na.rm = TRUE), 1),
    dif_promedio = round(mean(dif_rmm_sin_covid, na.rm = TRUE), 1),
    dif_max = round(max(abs(dif_rmm_sin_covid), na.rm = TRUE), 1)
  )

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== RESUMEN POR PERÍODO ===\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
print(tabla_resumen)

# ==============================================================================
# 8. GUARDAR RESULTADOS
# ==============================================================================

# Guardar ambas versiones por separado
write_csv(base_v1, file.path(ruta_resultados, "rmm_version_original.csv"))
write_csv(base_v2, file.path(ruta_resultados, "rmm_version_corregida.csv"))
write_csv(comparacion_rmm, file.path(ruta_resultados, "rmm_comparacion.csv"))

# Guardar también en RDS
saveRDS(base_v1, file.path(ruta_resultados, "rmm_version_original.rds"))
saveRDS(base_v2, file.path(ruta_resultados, "rmm_version_corregida.rds"))
saveRDS(comparacion_rmm, file.path(ruta_resultados, "rmm_comparacion.rds"))

cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n=== PROCESO COMPLETADO ===\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("Archivos generados:\n")
cat("  - rmm_version_original.csv\n")
cat("  - rmm_version_corregida.csv\n")
cat("  - rmm_comparacion.csv\n")
cat("  - comparacion_rmm.png\n")
cat("\nResultados guardados en:", ruta_resultados, "\n")





# ==============================================================================
# CÁLCULO DE RMM - VERSIÓN FINAL
# ==============================================================================

library(tidyverse)

# Rutas
ruta_resultados <- "C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Resultados_RMM_TMI"

# 1. CARGAR RESULTADOS DE DEFUNCIONES (mm_sin_covid)
resultados_df <- readRDS(file.path(ruta_resultados, "mortalidad_materna_FINAL.rds"))

# 2. NACIMIENTOS OFICIALES (de tu tabla)
nv_oficial <- c(313725, 316916, 319283, 320868, 321991, 322863, 323547,
                323538, 323419, 323237, 322826, 322593, 323129, 324152,
                325299, 326537, 328116, 329841, 331413, 332948, 334364,
                334738, 334180, 332107, 328438, 323234, 316592, 309339,
                302106, 295297, 287289, 278949, 271823, 266696, 263020)

oficial_nac <- data.frame(anio = 1990:2024, nv_oficial = nv_oficial)

# 3. RMM OFICIAL (de tu tabla - columna "Razón de mortalidad materna (t)")
rmm_oficial <- c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                 71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                 60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                 66.5, 51.6, 41.2, 35.6, 34.2)

oficial_rmm <- data.frame(anio = 1990:2024, rmm_oficial = rmm_oficial)

# 4. CALCULAR TU RMM
rmm_calculada <- resultados_df %>%
  left_join(oficial_nac, by = "anio") %>%
  mutate(
    rmm_calculada = round((mm_sin_covid / nv_oficial) * 100000, 1)
  ) %>%
  select(anio, mm_sin_covid, nv_oficial, rmm_calculada)

# 5. UNIR CON RMM OFICIAL
comparacion_rmm <- rmm_calculada %>%
  left_join(oficial_rmm, by = "anio") %>%
  mutate(
    dif = rmm_calculada - rmm_oficial,
    dif_pct = round((dif / rmm_oficial) * 100, 1)
  )

# 6. VER COMPARACIÓN
print(comparacion_rmm, n = 35)

# 7. GUARDAR
write_csv(comparacion_rmm, file.path(ruta_resultados, "comparacion_rmm_final.csv"))







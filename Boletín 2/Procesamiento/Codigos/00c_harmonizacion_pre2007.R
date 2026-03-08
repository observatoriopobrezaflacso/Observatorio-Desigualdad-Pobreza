# =============================================================================
# Harmonización de Variables - Datasets de Defunciones (2000-2006)
# Boletín 2 - Observatorio de Políticas Públicas
# =============================================================================
#
# Este script define las funciones para armonizar los nombres de variables
# específicamente para el período 2000-2006, antes de la reestructuración de 2007.
#
# =============================================================================

#' Harmonizar nombres de variables para años 2000-2006
#'
#' @param df Data frame con datos de defunciones de años 2000-2006
#' @param anio Año del dataset (para manejo de casos específicos)
#' @return Data frame con nombres de variables estandarizados al formato moderno
#'
harmonizar_pre2007 <- function(df, anio) {
  
  # PASO 1: Convertir nombres a minúsculas para facilitar el mapeo
  names(df) <- tolower(names(df))
  
  # PASO 2: Mapeo de nombres 2000-2006 a estándar (basado en tu matriz)
  mapa_nombres <- list(
    # Identificación
    codigoen = "codigo_encuesta",
    
    # Fechas de inscripción
    anoi = "anio_insc",
    mesi = "mes_insc",
    acta = "acta_insc",
    estab = "oficina_insc",
    
    # Fechas de nacimiento
    anon = "anio_nac",
    mesn = "mes_nac",
    
    # Fechas de fallecimiento
    anof = "anio_fall",
    mesf = "mes_fall",
    
    # Edad
    edad = "edad",
    codi = "cod_edad",
    
    # Geográficas de residencia
    provr = "prov_res",
    cantr = "cant_res",
    parrr = "parr_res",
    zonar = "area_res",
    
    # Geográficas de fallecimiento
    provf = "prov_fall",
    cantf = "cant_fall",
    parrf = "parr_fall",
    zona = "area_fall",
    
    # Causas (¡ya existen en este período!)
    causa103 = "causa103",
    causa080 = "causa80",
    causa667 = "causa667",
    causa = "causa",
    causa1 = "causa1",
    codcausa = "codcausa",
    
    # Causas específicas para menores (2003-2006)
    caus3671 = "causa3671",
    caus3670 = "causa3670",
    
    # Demográficas
    sexo = "sexo",
    nivel = "niv_inst",
    grado = "grado_inst",
    estado = "est_civil",
    leer = "sabe_leer",
    etnia = "etnia",  # Aparece en algunos años
    
    # Ocupacionales (presentes en 2000-2006)
    trabaja = "trabajaba",
    profe = "profesion",
    ocupa = "ocupacion",
    estab1 = "actividad_estab",
    categori = "categoria_ocup",
    notrabaj = "situacion_no_trabaja",
    
    # Mujeres y mortalidad materna
    embara = "embara",
    meses = "meses_emb",
    semana6 = "semana6",
    atencion = "atencion_emb",
    consulta = "consulta_emb",
    
    # Contexto del fallecimiento
    ocurrio = "lugar_ocur",
    certi = "cert_por",
    resident = "residente",
    
    # Persona que inscribe
    edadso = "edad_solicitante",
    paren = "parentesco",
    
    # Totales y otros
    t = "total",
    d_r = "d_r"  # Aparece en 2001
  )
  
  # Aplicar el mapeo: renombrar columnas que existen en el dataframe
  for (nombre_std in names(mapa_nombres)) {
    if (nombre_std %in% names(df)) {
      names(df)[names(df) == nombre_std] <- mapa_nombres[[nombre_std]]
    }
  }
  
  # PASO 3: Manejo de casos especiales por año
  
  # Para 2003-2006: asegurar que caus3671 y caus3670 estén como numéricas
  if (anio >= 2003 && anio <= 2006) {
    if ("causa3671" %in% names(df)) {
      df$causa3671 <- as.character(df$causa3671)
    }
    if ("causa3670" %in% names(df)) {
      df$causa3670 <- as.character(df$causa3670)
    }
  }
  
  # Para 2000-2002: verificar que causa103 existe (debería, según tu matriz)
  if (anio <= 2002 && !"causa103" %in% names(df)) {
    # Si no existe causa103, intentar crearla desde causa667 u otras
    if ("causa667" %in% names(df)) {
      df$causa103 <- df$causa667  # Placeholder, necesitaríamos mapeo real
      warning("causa103 no encontrada para año ", anio, 
              ". Usando causa667 como aproximación.")
    }
  }
  
  # PASO 4: Convertir tipos de datos para compatibilidad
  for (col in names(df)) {
    # Convertir factores a character
    if (is.factor(df[[col]])) {
      df[[col]] <- as.character(df[[col]])
    }
    # Convertir labelled a character (si existe haven)
    if (requireNamespace("haven", quietly = TRUE) && 
        inherits(df[[col]], "haven_labelled")) {
      df[[col]] <- as.character(df[[col]])
    }
  }
  
  return(df)
}

#' Verificar variables críticas en años 2000-2006
#'
#' @param df Data frame harmonizado
#' @param anio Año del dataset
#'
verificar_pre2007 <- function(df, anio) {
  
  variables_criticas <- c("anio_fall", "mes_fall", "cod_edad", "edad", 
                          "niv_inst", "causa103", "sexo", "prov_res", 
                          "parr_res", "area_res")
  
  presentes <- variables_criticas[variables_criticas %in% names(df)]
  faltantes <- variables_criticas[!variables_criticas %in% names(df)]
  
  cat("\nAño", anio, ":\n")
  cat("  Variables presentes:", paste(presentes, collapse = ", "), "\n")
  if (length(faltantes) > 0) {
    cat("  Variables faltantes:", paste(faltantes, collapse = ", "), "\n")
  }
  
  invisible(list(presentes = presentes, faltantes = faltantes))
}

cat("Funciones de harmonización para 2000-2006 cargadas correctamente.\n")
cat("  - harmonizar_pre2007()\n")
cat("  - verificar_pre2007()\n")



# 1. Primero, asegúrate de estar en el directorio correcto
setwd('C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2')

# 2. Ejecuta el script
source('Procesamiento/Codigos/00c_harmonizacion_pre2007.R')

# 3. Deberías ver:
# "Funciones de harmonización para 2000-2006 cargadas correctamente."
# "  - harmonizar_pre2007()"
# "  - verificar_pre2007()"

# Probar con un dataframe dummy
df_prueba <- data.frame(
  CODIGOEN = 1:3,
  ANOF = c(2000,2000,2000),
  MESF = c(1,2,3),
  EDAD = c(25,30,35),
  CODI = c(4,4,4),
  PROVF = c(1,1,1),
  PARRF = c(101,102,103),
  CAUSA103 = c("001","002","003"),
  SEXO = c(1,2,1),
  NIVEL = c(5,6,7)
)

# Aplicar harmonización
df_harmonizado <- harmonizar_pre2007(df_prueba, 2000)

# Ver resultado
names(df_harmonizado)

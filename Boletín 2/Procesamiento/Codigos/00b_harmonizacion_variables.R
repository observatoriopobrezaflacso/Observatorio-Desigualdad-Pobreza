  # =============================================================================
  # Harmonización de Variables - Datasets de Defunciones (1990-2024)
  # Boletín 2 - Observatorio de Políticas Públicas
  # =============================================================================
  #
  # Este script define las funciones para armonizar los nombres de variables
  # que cambian a lo largo de los años en los datasets de defunciones.
  #
  # =============================================================================

  #' Harmonizar nombres de variables de defunciones
  #'
  #' @param df Data frame con datos de defunciones de cualquier año
  #' @return Data frame con nombres de variables estandarizados
  #'
  harmonizar_variables_defunciones <- function(df) {

    # PASO 1: Convertir haven_labelled a tipos base
    # Convertir TODAS las columnas labelled a tipos base (character)
    # para evitar incompatibilidades entre años
    if (requireNamespace("haven", quietly = TRUE)) {
      for (col in names(df)) {
        # Convertir haven_labelled a sus valores numéricos originales
        if (inherits(df[[col]], "haven_labelled")) {
          df[[col]] <- as.character(df[[col]])
        }
      }
    }

    # Convertir todos los nombres a minúsculas para facilitar el mapeo
    nombres_originales <- names(df)
    names(df) <- tolower(names(df))

    # Manejar nombres duplicados (puede ocurrir al convertir a minúsculas)
    # Mantener solo la primera aparición de cada nombre
    if (any(duplicated(names(df)))) {
      cat("  ADVERTENCIA: Nombres duplicados detectados, manteniendo solo primera aparición\n")
      df <- df[, !duplicated(names(df))]
    }

    # Definir mapeos de variables (de nombre original -> nombre estandarizado)
    mapeos <- list(
      # Año de fallecimiento
      anio_fall = c("anof", "aniof", "anio_fall"),

      # Mes de fallecimiento
      mes_fall = c("mesf", "mes_fall"),

      # Año de nacimiento
      anio_nac = c("anon", "anion", "anio_nac"),

      # Mes de nacimiento
      mes_nac = c("mesn", "mes_nac"),

      # Código de edad
      cod_edad = c("codi", "cod_eda", "cod_edad"),

      # Edad
      edad = c("edad"),

      # Nivel de instrucción/educación
      niv_inst = c("nivel", "niv_inst"),

      # Causa de muerte (103 categorías)
      causa103 = c("causa103"),

      # Causa de muerte (80 categorías)
      causa80 = c("causa080", "causa80"),

      # Causa de muerte (67A)
      causa67a = c("causa67a"),

      # Causa de muerte (67B)
      causa67b = c("causa67b"),

      # Causa de muerte (letra)
      causa = c("causa"),

      # Sexo
      sexo = c("sexo"),

      # Provincia de residencia
      prov_res = c("provr", "prov_res"),

      # Cantón de residencia
      cant_res = c("cantr", "cant_res"),

      # Parroquia de residencia
      parr_res = c("parrr", "parr_res", "parr_resi"),

      # Área de residencia
      area_res = c("zonar", "area_res"),

      # Provincia de fallecimiento
      prov_fall = c("provf", "prov_fall"),

      # Cantón de fallecimiento
      cant_fall = c("cantf", "cant_fall"),

      # Parroquia de fallecimiento
      parr_fall = c("parrf", "parr_fall"),

      # Área de fallecimiento
      area_fall = c("zona", "zonaf", "area_fall"),

      # Etnia/pueblo
      etnia = c("etnia", "p_etnica"),

      # Sabe leer
      sabe_leer = c("leer", "sabe_leer"),

      # Estado civil
      est_civil = c("estado", "est_civ", "est_civil"),

      # Residente
      residente = c("resident", "residente"),

      # Certificado por
      cer_por = c("certi", "cert_por", "cer_por"),

      # Lugar de ocurrencia
      lugar_ocur = c("ocurrio", "lugar_ocur"),

      # Autopsia
      autopsia = c("autopcia", "autopsia"),

      # Muerte violenta
      mor_viol = c("mue_viol", "mu_violen", "mor_viol"),

      # Mujer en edad fértil
      muj_fertil = c("muj_fertil"),

      # Mortalidad materna (preferir mor_mat sobre mu_matern si ambos existen)
      mor_mat = c("mor_mat", "mort_mat", "mu_matern"),

      # Embarazo
      embara = c("embara")
    )

    # Aplicar los mapeos
    for (nombre_std in names(mapeos)) {
      posibles_nombres <- mapeos[[nombre_std]]

      # Si el nombre estándar ya existe en el dataframe, no mapearlo de nuevo
      # Esto evita duplicados cuando múltiples variantes existen en el mismo año
      if (nombre_std %in% names(df)) {
        next
      }

      # Buscar cuál de los posibles nombres existe en el dataframe
      nombre_encontrado <- posibles_nombres[posibles_nombres %in% names(df)]

      # Si se encuentra uno, renombrarlo al estándar
      if (length(nombre_encontrado) > 0) {
        # Usar el primero si hay múltiples coincidencias
        nombre_original <- nombre_encontrado[1]
        names(df)[names(df) == nombre_original] <- nombre_std
      }
    }

    # PASO FINAL: Asegurar que todas las columnas sean del mismo tipo base
    # Convertir a character para máxima compatibilidad entre años
    # (las conversiones numéricas se harán después en el análisis)
    for (col in names(df)) {
      # Convertir TODO a character para máxima compatibilidad
      # Fechas también se convierten porque diferentes años tienen diferentes formatos
      if (is.factor(df[[col]])) {
        df[[col]] <- as.character(df[[col]])
      } else if (is.numeric(df[[col]])) {
        df[[col]] <- as.character(df[[col]])
      } else if (inherits(df[[col]], c("Date", "POSIXct", "POSIXt"))) {
        df[[col]] <- as.character(df[[col]])
      }
    }

    return(df)
  }


  #' Verificar qué variables están disponibles en un dataset
  #'
  #' @param df Data frame
  #' @param año Año del dataset (para logging)
  #' @return Lista con variables presentes y faltantes
  #'
  verificar_variables <- function(df, año = NULL) {

    variables_clave <- c(
      "anio_fall", "mes_fall", "cod_edad", "edad", "niv_inst",
      "causa103", "causa80", "causa67a", "sexo",
      "prov_res", "parr_res", "area_res"
    )

    presentes <- variables_clave[variables_clave %in% names(df)]
    faltantes <- variables_clave[!variables_clave %in% names(df)]

    if (!is.null(año)) {
      cat("\nAño", año, ":\n")
    }
    cat("  Variables presentes:", paste(presentes, collapse = ", "), "\n")
    if (length(faltantes) > 0) {
      cat("  Variables faltantes:", paste(faltantes, collapse = ", "), "\n")
    }

    invisible(list(presentes = presentes, faltantes = faltantes))
  }


  #' Imputar valores faltantes para variables críticas
  #'
  #' @param df Data frame harmonizado
  #' @param año Año del dataset
  #' @return Data frame con valores imputados donde sea posible
  #'
  imputar_valores_faltantes <- function(df, año) {

    # Si falta anio_fall pero tenemos año como parámetro, usarlo
    if (!"anio_fall" %in% names(df)) {
      df$anio_fall <- año
    }

    # Si falta mes_fall, crear como NA
    if (!"mes_fall" %in% names(df)) {
      df$mes_fall <- NA
    }

    # Si falta cod_edad pero tenemos edad, intentar inferir
    # (esto es complejo sin conocer el contexto, por ahora dejarlo como NA)
    if (!"cod_edad" %in% names(df) & "edad" %in% names(df)) {
      # Código 4 generalmente significa años
      df$cod_edad <- 4
      cat("  ADVERTENCIA: cod_edad faltante, asumiendo código 4 (años)\n")
    }

    # Si falta causa103, no podemos hacer mucho
    if (!"causa103" %in% names(df)) {
      df$causa103 <- NA
      cat("  ADVERTENCIA: causa103 faltante para año", año, "\n")
    }

    # Si falta causa80
    if (!"causa80" %in% names(df)) {
      df$causa80 <- NA
    }

    # Si falta causa67a
    if (!"causa67a" %in% names(df)) {
      df$causa67a <- NA
    }

    return(df)
  }

  corregir_niv_inst <- function(df, año) {
    cat("  Corrigiendo niv_inst para año", año, "\n")
    df <- df %>% mutate(niv_inst = as.numeric(as.character(niv_inst)))
    if(año %in% c(2007:2019)) df <- df %>% mutate(niv_inst = case_when(niv_inst == 3 ~ 4, niv_inst == 4 ~ 3, TRUE ~ niv_inst))

    return(df)
  }

  cat("Funciones de harmonización cargadas correctamente.\n")
  cat("  - harmonizar_variables_defunciones()\n")
  cat("  - verificar_variables()\n")
  cat("  - imputar_valores_faltantes()\n")

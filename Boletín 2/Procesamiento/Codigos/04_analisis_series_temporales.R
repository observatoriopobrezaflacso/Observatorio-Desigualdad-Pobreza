# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Analisis de Series Temporales - Defunciones
# Boletin 2 - Observatorio de Politicas Publicas
# Series temporales de mortalidad, homicidios y suicidios
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

options(
  tibble.print_max = Inf,
  tibble.print_min = Inf
)

cat("\n========== ANALISIS DE SERIES TEMPORALES ==========\n")

# Configuracion inicial ----

# Cargar funciones de harmonizacion de variables
source(file.path(base_dir, "Procesamiento/Codigos/00b_harmonizacion_variables.R"))

# Configuracion de anios a analizar
# Los datos historicos estan en Procesamiento/Bases/Defunciones/EDG_{year}.sav
# excepto 2024 que esta en formato .rds
# Se esperan datos desde anios previos hasta 2024

# Directorio de datos historicos
datos_dir <- file.path(base_dir, "Procesamiento/Bases/Defunciones")

# Verificar que exista el directorio
if (!dir.exists(datos_dir)) {
  cat("ADVERTENCIA: No se encontro el directorio", datos_dir, "\n")
  cat("Por favor, coloque los archivos EDG_{year}.sav en ese directorio.\n")
  cat("Este script continuara con la estructura, pero no generara Graficos sin datos.\n")
  datos_disponibles <- FALSE
} else {
  datos_disponibles <- TRUE
}

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# CARGA DE DATOS HISTORICOS ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

# Listar archivos disponibles ----
archivos_sav <- list.files(datos_dir, pattern = "EDG_.*\\.sav$", full.names = TRUE)
archivo_rds <- list.files(datos_dir, pattern = "EDG_2024\\.rds$", full.names = TRUE)

# Extraer anios de los archivos
anios_sav <- as.numeric(gsub(".*EDG_(\\d{4})\\.sav", "\\1", basename(archivos_sav)))

cat("Archivos .sav encontrados:", length(archivos_sav), "\n")
cat("anios disponibles (SPSS):", paste(sort(anios_sav), collapse = ", "), "\n")
if (length(archivo_rds) > 0) cat("anio 2024 (RDS): disponible\n")

# Funcion cargar_anio() ----
cargar_anio <- function(anio) {
  cat("  Cargando anio", anio, "...\n")

  if (anio == 2024) {
    # Cargar archivo RDS
    df <- readRDS(file.path(datos_dir, "EDG_2024.rds"))
  } else {
    # Cargar archivo SPSS
    df <- read_sav(file.path(datos_dir, paste0("EDG_", anio, ".sav")))
  }

  # PASO 1: Harmonizar nombres de variables
  df <- harmonizar_variables_defunciones(df)

  # PASO 2: Imputar valores faltantes cuando sea posible
  df <- imputar_valores_faltantes(df, anio)

  # PASO 3: Verificar variables disponibles (opcional, para debugging)
  # verificar_variables(df, anio)

  # PASO 4 : Corregir niv_inst para años 2007-2019
  df <- corregir_niv_inst(df, anio)

  # PASO 5: Agregar columna de anio
  df$anio <- anio

  # PASO 6: Transformaciones comunes (ahora usando nombres estandarizados)
  df <- df %>%
    mutate(
      # Calcular edad numerica
      edad_num = case_when(
        !is.na(cod_edad) & !is.na(edad) & as.numeric(cod_edad) == 4 ~ as.numeric(edad),
        !is.na(cod_edad) & !is.na(edad) & as.numeric(cod_edad) == 3 ~ as.numeric(edad) / 12,
        !is.na(cod_edad) & !is.na(edad) & as.numeric(cod_edad) == 2 ~ as.numeric(edad) / 365,
        !is.na(cod_edad) & !is.na(edad) & as.numeric(cod_edad) == 1 ~ as.numeric(edad) / 8760,
        TRUE ~ NA_real_
      ),
      # Clasificar grupos de edad
      grupo_edad = case_when(
        !is.na(edad_num) & edad_num >= 20 & edad_num < 30 ~ "20-29",
        !is.na(edad_num) & edad_num >= 30 & edad_num < 65 ~ "30-64",
        !is.na(edad_num) & edad_num >= 65 & edad_num < 120 ~ "65+",
        TRUE ~ NA_character_
      ),
      # Nivel educativo - jovenes (20-29 anios) - actualizado para coincidir con analisis principal
      nivel_educativo_jovenes = case_when(
        !is.na(edad_num) & !is.na(niv_inst) &
          edad_num >= 20 & edad_num < 30 &
          as.numeric(niv_inst) %in% c(4, 5, 6, 7, 8) ~ "Secundaria completa",
        !is.na(edad_num) & !is.na(niv_inst) &
          edad_num >= 20 & edad_num < 30 &
          as.numeric(niv_inst) %in% c(0, 1, 2, 3) ~ "Secundaria incompleta",
        TRUE ~ NA_character_
      ),
      # Nivel educativo - adultos (30+ anios)
      nivel_educativo_adultos = case_when(
        !is.na(edad_num) & !is.na(niv_inst) &
          edad_num >= 30 &
          as.numeric(niv_inst) %in% c(6, 7, 8) ~ "Superior",
        !is.na(edad_num) & !is.na(niv_inst) &
          edad_num >= 30 &
          as.numeric(niv_inst) %in% c(0, 1, 2, 3, 4, 5) ~ "No superior",
        TRUE ~ NA_character_
      )
    )

  # PASO 7: Identificar causas externas especificas (solo si causa103 existe)
  if ("causa103" %in% names(df) && !all(is.na(df$causa103))) {
    df <- df %>%
      mutate(
        causa_externa = case_when(
          grepl("101", as.character(causa103)) ~ "Suicidio",
          grepl("102", as.character(causa103)) ~ "Homicidio",
          grepl("096", as.character(causa103)) ~ "Accidente de transporte",
          grepl("097|098|099|100|103", as.character(causa103)) ~ "Otras externas",
          TRUE ~ NA_character_
        )
      )
  } else {
    df$causa_externa <- NA_character_
    if (anio < 1997) {
      cat("    ADVERTENCIA: causa103 no disponible para anio", anio,
          "(usaba causa307/causa050 antes de 1997)\n")
    }
  }

  # PASO 8: Agregar codigo de parroquia para join con datos de pobreza
  if ("parr_res" %in% names(df)) {
    df <- df %>%
      mutate(cod_parroquia = sprintf("%06d", as.numeric(parr_res)))
  }

  cat("    Registros cargados:", nrow(df), "\n")

  return(df)
}

if(!file.exists(file.path(base_dir, "Procesamiento/Bases/Defunciones/defunciones_historicas.rds"))) {

# Cargar todos los anios disponibles ----
todos_los_anios <- c(2007:2024)
todos_los_anios <- sort(unique(todos_los_anios))


defunciones_historicas <- bind_rows(
  lapply(todos_los_anios, cargar_anio)
)

saveRDS(defunciones_historicas, file.path(base_dir, "Procesamiento/Bases/Defunciones/defunciones_historicas.rds"))

} else {
   defunciones_historicas <- readRDS(file.path(base_dir, "Procesamiento/Bases/Defunciones/defunciones_historicas.rds"))
}



cat("\nTotal de registros cargados:", nrow(defunciones_historicas), "\n")
cat("anios en el dataset:", paste(sort(unique(defunciones_historicas$anio)), collapse = ", "), "\n")

# Agregar datos de pobreza (si estan disponibles)
if (exists("df_parroquias_pobreza")) {
  defunciones_historicas <- defunciones_historicas %>%
    left_join(df_parroquias_pobreza, by = "cod_parroquia")
}




# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# GRAFICO 1: Mortalidad por nivel educativo (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 1: Mortalidad por educacion (serie temporal) ---\n")

# Tasas para jovenes ----
tasas_jovenes_tiempo <- defunciones_historicas %>%
  filter(!is.na(nivel_educativo_jovenes)) %>%
  count(anio, nivel_educativo_jovenes) %>%
  left_join(
    extrapolacion_poblacion_joven_secundaria %>%
      pivot_longer(cols = c(secundaria_completa, secundaria_incompleta),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_jovenes = ifelse(nivel == "secundaria_completa",
                                              "Secundaria completa",
                                              "Secundaria incompleta")) %>%
      select(anio, nivel_educativo_jovenes, poblacion),
    by = c("anio", "nivel_educativo_jovenes")
  ) %>%
  mutate(tasa = (n / poblacion) * 1000) %>%
  filter(!is.na(tasa), anio >= 2005)

# Tasas para adultos ----
tasas_adultos_tiempo <- defunciones_historicas %>%
  filter(!is.na(nivel_educativo_adultos)) %>%
  count(anio, nivel_educativo_adultos) %>%
  left_join(
    extrapolacion_poblacion_adulta_superior %>%
      pivot_longer(cols = c(superior, no_superior),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_adultos = ifelse(nivel == "superior",
                                              "Superior",
                                              "No superior")) %>%
      select(anio, nivel_educativo_adultos, poblacion),
    by = c("anio", "nivel_educativo_adultos")
  ) %>%
  mutate(tasa = (n / poblacion) * 1000) %>%
  filter(!is.na(tasa), anio >= 2005)


# Plot mortalidad jovenes ----
p1 <- ggplot(tasas_jovenes_tiempo, aes(x = anio, y = tasa, color = nivel_educativo_jovenes, group = nivel_educativo_jovenes)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "20-29 años",
    subtitle = NULL,
    x = NULL,
    y = "Mortalidad x 1000 hab.",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

# Plot mortalidad adultos ----
p2 <- ggplot(tasas_adultos_tiempo, aes(x = anio, y = tasa, color = nivel_educativo_adultos, group = nivel_educativo_adultos)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Superior" = "#27AE60", "No superior" = "#E74C3C")) +
  labs(
    title = "30+ años",
    subtitle = NULL,
    x = NULL,
    y = NULL,
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

cat("Graficos guardados.\n")

# Combinar plots mortalidad educacion ----
ylim_mortalidad_educacion <- range(
  c(tasas_jovenes_tiempo$tasa, tasas_adultos_tiempo$tasa),
  na.rm = TRUE
)
ylim_mortalidad_educacion[1] <- 0

xlim_mortalidad_educacion <- c(
  min(c(tasas_jovenes_tiempo$anio, tasas_adultos_tiempo$anio), na.rm = TRUE),
  2024
)

p1 <- p1 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_mortalidad_educacion, ylim = ylim_mortalidad_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

p2 <- p2 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_mortalidad_educacion, ylim = ylim_mortalidad_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

combined_plot <- p1 + p2 +
  plot_annotation(
    
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5))
  ) 

# Guardar plot combinado mortalidad educacion ----
ggsave(file.path(output_dir, "serie_mortalidad_educacion_combinado.png"),
       combined_plot, width = 14, height = 6, dpi = 300, bg = "white")


# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Grafico 2: Mortalidad por nivel de pobreza (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 2: Mortalidad por pobreza (serie temporal) ---\n")

# Calcular tasas mortalidad por pobreza ----
tasas_pobreza_tiempo <- defunciones_historicas %>%
  filter(!is.na(nivel_pobreza) & !is.na(grupo_edad)) %>%
  count(anio, nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa = (n / poblacion) * 1000)

# Plot mortalidad por pobreza ----
p3 <- ggplot(tasas_pobreza_tiempo, aes(x = anio, y = tasa, color = nivel_pobreza, group = nivel_pobreza)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = colores_pobreza) +
  labs(
    
    subtitle = NULL,
    x = NULL,
    y = "Mortalidad x 1000 hab.",
    color = "Nivel de pobreza"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom"
  )

cat("Grafico guardado.\n")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Grafico 3: Homicidios por nivel educativo (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 3: Homicidios por educacion (serie temporal) ---\n")

# Tasas homicidios jovenes ----
tasas_homicidios_jovenes <- defunciones_historicas %>%
  filter(causa_externa == "Homicidio" & !is.na(nivel_educativo_jovenes)) %>%
  count(anio, nivel_educativo_jovenes) %>%
  left_join(
    extrapolacion_poblacion_joven_secundaria %>%
      pivot_longer(cols = c(secundaria_completa, secundaria_incompleta),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_jovenes = ifelse(nivel == "secundaria_completa",
                                              "Secundaria completa",
                                              "Secundaria incompleta")) %>%
      select(anio, nivel_educativo_jovenes, poblacion),
    by = c("anio", "nivel_educativo_jovenes")
  ) %>%
  mutate(tasa = (n / poblacion) * 100000) %>%
  filter(!is.na(tasa), anio >= 2005)

# Tasas homicidios adultos ----
tasas_homicidios_adultos <- defunciones_historicas %>%
  filter(causa_externa == "Homicidio" & !is.na(nivel_educativo_adultos)) %>%
  count(anio, nivel_educativo_adultos) %>%
  left_join(
    extrapolacion_poblacion_adulta_superior %>%
      pivot_longer(cols = c(superior, no_superior),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_adultos = ifelse(nivel == "superior",
                                              "Superior",
                                              "No superior")) %>%
      select(anio, nivel_educativo_adultos, poblacion),
    by = c("anio", "nivel_educativo_adultos")
  ) %>%
  mutate(tasa = (n / poblacion) * 100000) %>%
  filter(!is.na(tasa), anio >= 2005)

# Plot homicidios jovenes ----
p4 <- ggplot(tasas_homicidios_jovenes, aes(x = anio, y = tasa, color = nivel_educativo_jovenes, group = nivel_educativo_jovenes)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "20-29 años",
    subtitle = NULL,
    x = NULL,
    y = "Homicidios x 100 000 habs.",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

# Plot homicidios adultos ----
p5 <- ggplot(tasas_homicidios_adultos, aes(x = anio, y = tasa, color = nivel_educativo_adultos, group = nivel_educativo_adultos)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Superior" = "#27AE60", "No superior" = "#E74C3C")) +
  labs(
    title = "30+ años",
    subtitle = NULL,
    x = NULL,
    y = NULL,
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

cat("Graficos guardados.\n")


# Combinar plots homicidios educacion ----

# Definir limites comunes para facilitar la comparacion visual
ylim_homicidios_educacion <- range(
  c(tasas_homicidios_jovenes$tasa, tasas_homicidios_adultos$tasa),
  na.rm = TRUE
)
ylim_homicidios_educacion[1] <- 0

xlim_homicidios_educacion <- c(
  min(c(tasas_homicidios_jovenes$anio, tasas_homicidios_adultos$anio), na.rm = TRUE),
  2024
)

# Ajustar Grafico de jovenes para el combinado
p4_comb <- p4 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_homicidios_educacion, ylim = ylim_homicidios_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

# Ajustar Grafico de adultos para el combinado
p5_comb <- p5 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_homicidios_educacion, ylim = ylim_homicidios_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

# Combinar con patchwork
combined_plot_homicidios <- p4_comb + p5_comb +
  plot_annotation(
    
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5))
  )

# Guardar plot combinado homicidios educacion ----
ggsave(file.path(output_dir, "serie_homicidios_educacion_combinado.png"),
       combined_plot_homicidios, width = 14, height = 6, dpi = 300, bg = "white")


# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Grafico 4: Homicidios por nivel de pobreza (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 4: Homicidios por pobreza (serie temporal) ---\n")

# Calcular tasas homicidios por pobreza ----
tasas_homicidios_pobreza <- defunciones_historicas %>%
  filter(causa_externa == "Homicidio" & !is.na(nivel_pobreza)) %>%
  count(anio, nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa = (n / poblacion) * 100000) 

# Plot homicidios por pobreza ----
p6 <- ggplot(tasas_homicidios_pobreza, aes(x = anio, y = tasa, color = nivel_pobreza, group = nivel_pobreza)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = colores_pobreza) +
  labs(
    
    subtitle = NULL,
    x = NULL,
    y = "Homicidios x 100 000 habs.",
    color = "Nivel de pobreza"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom"
  )

cat("Grafico guardado.\n")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Grafico 5: Suicidios por nivel educativo (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 5: Suicidios por educacion (serie temporal) ---\n")

# Tasas suicidios jovenes ----
tasas_suicidios_jovenes <- defunciones_historicas %>%
  filter(causa_externa == "Suicidio" & !is.na(nivel_educativo_jovenes)) %>%
  count(anio, nivel_educativo_jovenes) %>%
  left_join(
    extrapolacion_poblacion_joven_secundaria %>%
      pivot_longer(cols = c(secundaria_completa, secundaria_incompleta),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_jovenes = ifelse(nivel == "secundaria_completa",
                                              "Secundaria completa",
                                              "Secundaria incompleta")) %>%
      select(anio, nivel_educativo_jovenes, poblacion),
    by = c("anio", "nivel_educativo_jovenes")
  ) %>%
  mutate(tasa = (n / poblacion) * 100000) %>%
  filter(!is.na(tasa), anio >= 2005) 

# Tasas suicidios adultos ----
tasas_suicidios_adultos <- defunciones_historicas %>%
  filter(causa_externa == "Suicidio" & !is.na(nivel_educativo_adultos)) %>%
  count(anio, nivel_educativo_adultos) %>%
  left_join(
    extrapolacion_poblacion_adulta_superior %>%
      pivot_longer(cols = c(superior, no_superior),
                  names_to = "nivel",
                  values_to = "poblacion") %>%
      mutate(nivel_educativo_adultos = ifelse(nivel == "superior",
                                              "Superior",
                                              "No superior")) %>%
      select(anio, nivel_educativo_adultos, poblacion),
    by = c("anio", "nivel_educativo_adultos")
  ) %>%
  mutate(tasa = (n / poblacion) * 100000) %>%
  filter(!is.na(tasa), anio >= 2005) 

# Plot suicidios jovenes ----
p7 <- ggplot(tasas_suicidios_jovenes, aes(x = anio, y = tasa, color = nivel_educativo_jovenes, group = nivel_educativo_jovenes)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "20-29 años",
    subtitle = NULL,
    x = NULL,
    y = "Suicidios x 100 000 habs.",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

# Plot suicidios adultos ----
p8 <- ggplot(tasas_suicidios_adultos, aes(x = anio, y = tasa, color = nivel_educativo_adultos, group = nivel_educativo_adultos)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Superior" = "#27AE60", "No superior" = "#E74C3C")) +
  labs(
    title = "30+ años",
    subtitle = NULL,
    x = NULL,
    y = NULL,
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

cat("Graficos guardados.\n")


# Combinar plots suicidios educacion ----

# Definir limites comunes
ylim_suicidios_educacion <- range(
  c(tasas_suicidios_jovenes$tasa, tasas_suicidios_adultos$tasa),
  na.rm = TRUE
)
ylim_suicidios_educacion[1] <- 0

xlim_suicidios_educacion <- c(
  min(c(tasas_suicidios_jovenes$anio, tasas_suicidios_adultos$anio), na.rm = TRUE),
  2024
)

# Ajustar Grafico de jovenes para el combinado
p7_comb <- p7 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_suicidios_educacion, ylim = ylim_suicidios_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

# Ajustar Grafico de adultos para el combinado
p8_comb <- p8 + 
  scale_x_continuous(
    breaks = function(x) sort(unique(c(scales::pretty_breaks(n = 8)(x), 2024)))
  ) +
  coord_cartesian(xlim = xlim_suicidios_educacion, ylim = ylim_suicidios_educacion) +
  theme(plot.title = element_text(hjust = 0.5))

# Combinar con patchwork
combined_plot_suicidios <- p7_comb + p8_comb +
  plot_annotation(
    
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5))
  )

# Guardar plot combinado suicidios educacion ----
ggsave(file.path(output_dir, "serie_suicidios_educacion_combinado.png"),
       combined_plot_suicidios, width = 14, height = 6, dpi = 300, bg = "white")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Grafico 6: Suicidios por nivel de pobreza (serie temporal) ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Grafico 6: Suicidios por pobreza (serie temporal) ---\n")

# Calcular tasas suicidios por pobreza ----
tasas_suicidios_pobreza <- defunciones_historicas %>%
  filter(causa_externa == "Suicidio" & !is.na(nivel_pobreza)) %>%
  count(anio, nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa = (n / poblacion) * 100000)

# Plot suicidios por pobreza ----
p9 <- ggplot(tasas_suicidios_pobreza, aes(x = anio, y = tasa, color = nivel_pobreza, group = nivel_pobreza)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = colores_pobreza) +
  labs(
    
    subtitle = NULL,
    x = NULL,
    y = "Suicidios x 100 000 habs.",
    color = "Nivel de pobreza"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "bottom",
    legend.text = element_text(size = 15), 
    y.axis.text = element_text(size = 15)
  )

cat("Grafico guardado.\n")


# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# RESUMEN ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n=============================================================================\n")
cat("ANALISIS DE SERIES TEMPORALES COMPLETADO\n")
cat("=============================================================================\n")

if (datos_disponibles && nrow(defunciones_historicas) > 0) {
  cat("\nGraficos generados:\n")
  cat("  1. Serie temporal - Mortalidad jovenes por educacion\n")
  cat("  2. Serie temporal - Mortalidad adultos por educacion\n")
  cat("  3. Serie temporal - Mortalidad por pobreza\n")
  cat("  4. Serie temporal - Homicidios jovenes por educacion\n")
  cat("  5. Serie temporal - Homicidios adultos por educacion\n")
  cat("  6. Serie temporal - Homicidios por pobreza\n")
  cat("  7. Serie temporal - Suicidios jovenes por educacion\n")
  cat("  8. Serie temporal - Suicidios adultos por educacion\n")
  cat("  9. Serie temporal - Suicidios por pobreza\n")
  cat("\nTodos los Graficos guardados en:", output_dir, "\n")
} else {
  cat("\nNo se generaron Graficos debido a la falta de datos historicos.\n")
  cat("Por favor, coloque los archivos EDG_{year}.sav en:\n")
  cat(" ", file.path(base_dir, "Procesamiento/Bases/Defunciones"), "\n")
}
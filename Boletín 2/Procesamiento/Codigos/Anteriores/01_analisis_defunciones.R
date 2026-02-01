# =============================================================================
# Análisis de Defunciones por Variables Socioeconómicas
# Boletín 2 - Observatorio de Políticas Públicas
# Mortalidad por educación y pobreza
# =============================================================================


cat("\n========== ANÁLISIS DE DEFUNCIONES ==========\n")

library(haven)


# Carga y transformación de datos ----
defunciones <- read_spss(file.path(base_dir, "Procesamiento/Bases/Defunciones/EDG_2022.sav"))

defunciones <- defunciones %>%
  mutate(
    edad_num = case_when(
      as.numeric(cod_edad) == 4 ~ as.numeric(edad),
      as.numeric(cod_edad) == 3 ~ as.numeric(edad) / 12,
      as.numeric(cod_edad) == 2 ~ as.numeric(edad) / 365,
      as.numeric(cod_edad) == 1 ~ as.numeric(edad) / 8760,
      TRUE ~ NA_real_
    ),
    grupo_edad = case_when(
      edad_num >= 20 & edad_num < 30 ~ "20-29",
      edad_num >= 30 & edad_num < 65 ~ "30-64",
      edad_num >= 65 & edad_num < 999 ~ "65+",
      TRUE ~ NA_character_
    ),
    nivel_educativo_jovenes = case_when(
      edad_num >= 20 & edad_num < 30 & as.numeric(niv_inst) %in% c(4, 5, 6, 7, 8) ~ "Secundaria completa",
      edad_num >= 20 & edad_num < 30 & as.numeric(niv_inst) %in% c(0, 1, 2, 3) ~ "Secundaria incompleta",
      TRUE ~ NA_character_
    ),
    nivel_educativo_adultos = case_when(
      edad_num >= 30 & as.numeric(niv_inst) %in% c(7, 8) ~ "Universitario",
      edad_num >= 30 & as.numeric(niv_inst) %in% c(0, 1, 2, 3, 4, 5, 6) ~ "No universitario",
      TRUE ~ NA_character_
    ),
    causa_agrupada = {
      causa_str <- as.character(as_factor(causa67A))
      case_when(
        grepl("^030", causa_str) ~ "Cardiovasculares",
        grepl("^016", causa_str) ~ "Tumores",
        grepl("^031", causa_str) ~ "Respiratorias",
        grepl("^023", causa_str) ~ "Metabolicas/Endocrinas",
        grepl("^060", causa_str) ~ "Causas externas",
        grepl("^035", causa_str) ~ "Digestivas",
        grepl("^001", causa_str) ~ "Infecciosas",
        grepl("^036", causa_str) ~ "Genitales/Urinarias",
        grepl("^026", causa_str) ~ "Sistema nervioso",
        grepl("COVID", causa_str) ~ "COVID-19",
        grepl("^037", causa_str) ~ "Perinatales",
        grepl("^049", causa_str) ~ "Congenitas",
        TRUE ~ "Otras causas"
      )
    }
  )

# Clasificación de causas externas específicas ----
# Caídas, Ahogamiento, Exposición a fuego/humo y Envenenamiento se agrupan en "Otras externas"
defunciones <- defunciones %>%
  mutate(
    causa_externa_especifica = case_when(
      grepl("096", as.character(causa103)) ~ "Accidentes de transporte",
      grepl("101", as.character(causa103)) ~ "Suicidios",
      grepl("102", as.character(causa103)) ~ "Homicidios",
      grepl("097|098|099|100|103", as.character(causa103)) ~ "Otras externas",
      TRUE ~ NA_character_
    )
  )

# Etiquetas con acentos para los graficos ----
causa_labels <- c(
  "Metabolicas/Endocrinas" = "Metabólicas/Endocrinas",
  "Congenitas" = "Congénitas"
)

# Filtrado de datos para analisis ----
defunciones_analisis <- defunciones %>%
  filter(!is.na(grupo_edad) & !is.na(causa_agrupada))

# Orden de causas por frecuencia
orden_causas <- defunciones_analisis %>%
  count(causa_agrupada) %>%
  arrange(desc(n)) %>%
  pull(causa_agrupada)

cat("Registros para análisis (sin niños):", nrow(defunciones_analisis), "\n")

# =============================================================================
# MORTALIDAD POR NIVEL EDUCATIVO
# =============================================================================

cat("\n--- Análisis por nivel educativo ---\n")

# Gráfico: Jóvenes - Tasa total por nivel educativo ----
jovenes_analisis <- defunciones %>%
  filter(grupo_edad == "20-29" & !is.na(nivel_educativo_jovenes))

tasas_jovenes_educ <- jovenes_analisis %>%
  count(nivel_educativo_jovenes) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_1000 = n / poblacion * 1000
  )

# Calcular ratio para jóvenes
ratio_jovenes_educ <- tasas_jovenes_educ %>%
  select(nivel_educativo_jovenes, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_1000) %>%
  mutate(ratio = `Secundaria incompleta` / `Secundaria completa`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_mort_jov_educ <- ggplot(tasas_jovenes_educ, aes(x = nivel_educativo_jovenes, y = tasa_1000, fill = nivel_educativo_jovenes)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio (posicionado encima del texto)
  annotate("segment", x = 1, xend = 2,
           y = max(tasas_jovenes_educ$tasa_1000) * 1.28,
           yend = max(tasas_jovenes_educ$tasa_1000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_jovenes_educ$tasa_1000) * 1.28,
           yend = max(tasas_jovenes_educ$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 2, xend = 2,
           y = max(tasas_jovenes_educ$tasa_1000) * 1.28,
           yend = max(tasas_jovenes_educ$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 1.5, y = max(tasas_jovenes_educ$tasa_1000) * 1.33,
                 label = ratio_jovenes_educ$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de mortalidad en jóvenes (20-29 años) por nivel educativo",
    subtitle = paste0("Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Sec. incompleta / Sec. completa)"),
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "mortalidad_jovenes_educacion.png"), g_mort_jov_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_jovenes_educacion.png\n")

# Gráfico: Jóvenes - Causas por nivel educativo ----
jovenes_con_causa <- defunciones %>%
  filter(grupo_edad == "20-29" & !is.na(nivel_educativo_jovenes) & !is.na(causa_agrupada))

graf_jov_causas_data <- jovenes_con_causa %>%
  count(nivel_educativo_jovenes, causa_agrupada) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_1000 = n / poblacion * 1000
  )

top8_jovenes <- jovenes_con_causa %>%
  count(causa_agrupada) %>%
  arrange(desc(n)) %>%
  slice(1:8) %>%
  pull(causa_agrupada)

graf_jov_causas_data <- graf_jov_causas_data %>% filter(causa_agrupada %in% top8_jovenes)
graf_jov_causas_data$causa_agrupada <- factor(graf_jov_causas_data$causa_agrupada, levels = rev(top8_jovenes))

# Calcular ratios para jóvenes causas
ratios_jov_causas <- graf_jov_causas_data %>%
  select(causa_agrupada, nivel_educativo_jovenes, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_1000) %>%
  mutate(
    ratio = `Secundaria incompleta` / `Secundaria completa`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Secundaria completa`, `Secundaria incompleta`, na.rm = TRUE),
    x_num = as.numeric(causa_agrupada),
    x_comp = x_num - 0.175,
    x_incomp = x_num + 0.175,
    y_pointer = y_max + max(graf_jov_causas_data$tasa_1000) * 0.02,
    y_bracket = y_pointer + max(graf_jov_causas_data$tasa_1000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_mort_jov_causas <- ggplot(graf_jov_causas_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_jov_causas,
               aes(x = x_comp, xend = x_incomp, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_jov_causas,
               aes(x = x_comp, xend = x_comp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_jov_causas,
               aes(x = x_incomp, xend = x_incomp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_jov_causas,
             aes(x = x_num, y = y_bracket + max(graf_jov_causas_data$tasa_1000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_x_discrete(labels = function(x) ifelse(x %in% names(causa_labels), causa_labels[x], x)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Causas de muerte en jóvenes (20-29 años) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Sec. incompleta / Sec. completa)",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 24, face = "bold"),
        plot.subtitle = element_text(size = 18),
        axis.title = element_text(size = 18),
        axis.text = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        legend.title = element_text(size = 18, face = "bold"),
        legend.text = element_text(size = 16))

ggsave(file.path(output_dir, "mortalidad_jovenes_causas_educacion.png"), g_mort_jov_causas, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_jovenes_causas_educacion.png\n")

# Gráfico: Adultos - Tasa total por nivel educativo ----
adultos_analisis <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+") & !is.na(nivel_educativo_adultos))

tasas_adultos_educ <- adultos_analisis %>%
  count(nivel_educativo_adultos) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_1000 = n / poblacion * 1000
  )

# Calcular ratio para adultos
ratio_adultos_educ <- tasas_adultos_educ %>%
  select(nivel_educativo_adultos, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
  mutate(ratio = `No universitario` / Universitario,
         ratio_label = paste0(round(ratio, 1), "x"))

g_mort_adult_educ <- ggplot(tasas_adultos_educ, aes(x = nivel_educativo_adultos, y = tasa_1000, fill = nivel_educativo_adultos)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio (posicionado encima del texto)
  annotate("segment", x = 1, xend = 2,
           y = max(tasas_adultos_educ$tasa_1000) * 1.28,
           yend = max(tasas_adultos_educ$tasa_1000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_adultos_educ$tasa_1000) * 1.28,
           yend = max(tasas_adultos_educ$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 2, xend = 2,
           y = max(tasas_adultos_educ$tasa_1000) * 1.28,
           yend = max(tasas_adultos_educ$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 1.5, y = max(tasas_adultos_educ$tasa_1000) * 1.33,
                 label = ratio_adultos_educ$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de mortalidad en adultos (30+ años) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "mortalidad_adultos_educacion.png"), g_mort_adult_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_adultos_educacion.png\n")

# Gráfico: Adultos - Causas por nivel educativo ----
adultos_con_causa <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+") &
         !is.na(nivel_educativo_adultos) & !is.na(causa_agrupada))

graf_adult_causas_data <- adultos_con_causa %>%
  count(grupo_edad, nivel_educativo_adultos, causa_agrupada) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario / 2,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario / 2
    ),
    tasa_1000 = n / poblacion * 1000
  ) %>%
  filter(causa_agrupada %in% orden_causas[1:8])

graf_adult_causas_data$causa_agrupada <- factor(graf_adult_causas_data$causa_agrupada, levels = rev(orden_causas[1:8]))
graf_adult_causas_data$grupo_edad <- factor(graf_adult_causas_data$grupo_edad, levels = c("30-64", "65+"))

# Calcular ratios para adultos causas (por grupo de edad)
ratios_adult_causas <- graf_adult_causas_data %>%
  select(grupo_edad, causa_agrupada, nivel_educativo_adultos, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
  mutate(
    ratio = `No universitario` / Universitario,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Universitario, `No universitario`, na.rm = TRUE),
    x_num = as.numeric(causa_agrupada),
    x_univ = x_num - 0.175,
    x_no_univ = x_num + 0.175,
    y_pointer = y_max + max(graf_adult_causas_data$tasa_1000) * 0.02,
    y_bracket = y_pointer + max(graf_adult_causas_data$tasa_1000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_mort_adult_causas <- ggplot(graf_adult_causas_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_adult_causas,
               aes(x = x_univ, xend = x_no_univ, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_adult_causas,
               aes(x = x_univ, xend = x_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_adult_causas,
               aes(x = x_no_univ, xend = x_no_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_adult_causas,
             aes(x = x_num, y = y_bracket + max(graf_adult_causas_data$tasa_1000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  facet_wrap(~grupo_edad, ncol = 2) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_x_discrete(labels = function(x) ifelse(x %in% names(causa_labels), causa_labels[x], x)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Causas de muerte en adultos por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 24, face = "bold"),
        plot.subtitle = element_text(size = 18),
        axis.title = element_text(size = 18),
        axis.text = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        legend.title = element_text(size = 18, face = "bold"),
        legend.text = element_text(size = 16),
        strip.text = element_text(face = "bold", size = 16))

ggsave(file.path(output_dir, "mortalidad_adultos_causas_educacion.png"), g_mort_adult_causas, width = 13, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_adultos_causas_educacion.png\n")

# =============================================================================
# Mortalidad por tipo de causa (naturales, externas total, externas desagregadas)
# =============================================================================

cat("\n--- Análisis de causas naturales vs externas por educación ---\n")

# Clasificación para el gráfico con causas externas agregadas + desagregadas
defunciones <- defunciones %>%
  mutate(
    tipo_causa_con_externas = case_when(
      # Causas naturales agrupadas
      causa_agrupada %in% c("Cardiovasculares", "Tumores", "Respiratorias", 
                            "Metabolicas/Endocrinas", "Digestivas", "Infecciosas",
                            "Genitales/Urinarias", "Sistema nervioso", "COVID-19",
                            "Perinatales", "Congenitas") ~ "Causas naturales",
      # Causas externas total
      causa_agrupada == "Causas externas" ~ "Causas externas (total)",
      TRUE ~ "Otras causas"
    )
  )

# Preparar datos para adultos 30+ (sin desagregar por grupo de edad)
adultos_tipo_causa <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+") & 
         !is.na(nivel_educativo_adultos))

# Crear dataset con causas naturales + externas total + externas desagregadas
# Primero: causas naturales y externas total
datos_principales <- adultos_tipo_causa %>%
  filter(tipo_causa_con_externas %in% c("Causas naturales", "Causas externas (total)")) %>%
  count(nivel_educativo_adultos, tipo_causa_con_externas) %>%
  rename(categoria = tipo_causa_con_externas)

# Segundo: causas externas desagregadas
datos_externas <- adultos_tipo_causa %>%
  filter(!is.na(causa_externa_especifica)) %>%
  count(nivel_educativo_adultos, causa_externa_especifica) %>%
  rename(categoria = causa_externa_especifica)

# Combinar
graf_tipo_causa_data <- bind_rows(datos_principales, datos_externas) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_10000 = n / poblacion * 10000
  )

# Orden de categorías y etiquetas con indicador de causas externas
orden_categorias <- c("Causas naturales", "Causas externas (total)", 
                      "Accidentes de transporte", "Homicidios", "Suicidios", 
                      "Otras externas")

# Etiquetas con indicador para subcategorías de causas externas
etiquetas_categorias <- c(
  "Causas naturales" = "Causas naturales",
  "Causas externas (total)" = "Causas externas (total)",
  "Accidentes de transporte" = "   ├ Accidentes tránsito",
  "Homicidios" = "   ├ Homicidios",
  "Suicidios" = "   ├ Suicidios",
  "Otras externas" = "   └ Otras externas"
)

graf_tipo_causa_data <- graf_tipo_causa_data %>%
  filter(categoria %in% orden_categorias)

graf_tipo_causa_data$categoria <- factor(
  graf_tipo_causa_data$categoria, 
  levels = rev(orden_categorias)
)

# Calcular ratios para el bracket conector (posicionado ENCIMA de las barras)
ratios_educacion <- graf_tipo_causa_data %>%
  select(categoria, nivel_educativo_adultos, tasa_10000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_10000) %>%
  mutate(
    ratio = `No universitario` / Universitario,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Universitario, `No universitario`),
    # Posiciones x de las barras (dodge offset = 0.175)
    x_num = as.numeric(categoria),
    x_univ = x_num - 0.175,      # Universitario (arriba en el gráfico)
    x_no_univ = x_num + 0.175,   # No universitario (abajo en el gráfico)
    # Posiciones del bracket (medidas absolutas para altura consistente)
    y_pointer = y_max + 1,       # Donde terminan las líneas que apuntan (1 unidad después de la barra)
    y_bracket = y_pointer + 1    # Línea vertical conectora (1 unidad de altura fija)
  )

g_tipo_causa <- ggplot(graf_tipo_causa_data, aes(x = categoria, y = tasa_10000, fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  # Línea vertical del bracket (conecta las dos barras)
  geom_segment(data = ratios_educacion,
               aes(x = x_univ, xend = x_no_univ,
                   y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra azul (Universitario) - termina al mismo nivel que la otra
  geom_segment(data = ratios_educacion,
               aes(x = x_univ, xend = x_univ,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra roja (No universitario) - termina al mismo nivel
  geom_segment(data = ratios_educacion,
               aes(x = x_no_univ, xend = x_no_univ,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Etiqueta con el ratio posicionada a la derecha del bracket (distancia absoluta)
  geom_label(data = ratios_educacion,
             aes(x = x_num, y = y_bracket + 4, label = ratio_label),
             inherit.aes = FALSE,
             fill = "white", color = "gray20", size = 6, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_x_discrete(labels = etiquetas_categorias) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Mortalidad por tipo de causa y nivel educativo (30+ años)",
    subtitle = "Ecuador 2024 - Tasa por 10,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 10,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 24, face = "bold"),
        plot.subtitle = element_text(size = 18),
        axis.title = element_text(size = 18),
        axis.text = element_text(size = 16),
        axis.text.y = element_text(family = "sans", hjust = 0, color = "black", size = 16),
        legend.title = element_text(size = 18, face = "bold"),
        legend.text = element_text(size = 16))

ggsave(file.path(output_dir, "mortalidad_tipo_causa_educacion.png"), g_tipo_causa, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_tipo_causa_educacion.png\n")

# =============================================================================
# MORTALIDAD POR NIVEL DE POBREZA
# =============================================================================

cat("\n--- Análisis por nivel de pobreza ---\n")

# Preparar defunciones con datos de pobreza ----
defunciones <- defunciones %>%
  mutate(
    cod_parroquia = {
      cod_raw <- as.numeric(as.character(parr_fall))
      cod_str <- sprintf("%06d", cod_raw)
      # Extraer los últimos dos dígitos y forzar a "50" si es menor a 50
      cod_num <- as.numeric(substr(cod_str, 5, 6))
      cod_str2 <- ifelse(cod_num < 50,
                         paste0(substr(cod_str, 1, 4), "50"),
                         cod_str)
      cod_str2
    }
  )

defunciones_pobreza <- defunciones %>%
  left_join(df_parroquias_pobreza, by = "cod_parroquia")

cat("Defunciones con datos de pobreza:", sum(!is.na(defunciones_pobreza$nivel_pobreza)),
    "de", nrow(defunciones_pobreza), "\n")

defunciones_pob_analisis <- defunciones_pobreza %>%
  filter(!is.na(nivel_pobreza) & !is.na(grupo_edad) & !is.na(causa_agrupada))

defunciones_pob_analisis$nivel_pobreza <- factor(
  defunciones_pob_analisis$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

# Gráfico: Tasa de mortalidad por nivel de pobreza ----
tasas_mort_pobreza <- defunciones_pob_analisis %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

tasas_mort_pobreza %>% mutate(percentage = poblacion / sum(poblacion) * 100)


df_parroquias_pobreza <- df_parroquias_pobreza %>%
  mutate(
    provincia = substr(cod_parroquia, 1, 2),
    region = case_when(
      provincia %in% c("07", "08", "09", "12", "13", "23", "24") ~ "Costa",
      provincia %in% c("01", "02", "03", "04", "05", "06",
                        "10", "11", "17", "18") ~ "Sierra",
      provincia %in% c("14", "15", "16", "19", "21", "22") ~ "Amazonía",
      provincia == "20" ~ "Galápagos",
      
      TRUE ~ NA_character_
    )
  )

  df_parroquias_pobreza %>%
  group_by(nivel_pobreza, region) %>%
  count(region)  %>%
  ungroup() %>%
  group_by(nivel_pobreza) %>%
  mutate(percentage = n / sum(n) * 100)


  df_parroquias_pobreza %>% count(region)


# Calcular ratio para pobreza
ratio_mort_pobreza <- tasas_mort_pobreza %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, tasa_1000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000) %>%
  mutate(ratio = `Mayor pobreza` / `Menor pobreza`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_mort_pobreza <- ggplot(tasas_mort_pobreza, aes(x = nivel_pobreza, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio (posicionado encima del texto)
  annotate("segment", x = 1, xend = 3,
           y = max(tasas_mort_pobreza$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza$tasa_1000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_mort_pobreza$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(tasas_mort_pobreza$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(tasas_mort_pobreza$tasa_1000) * 1.33,
                 label = ratio_mort_pobreza$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de mortalidad por nivel de pobreza de la parroquia",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "mortalidad_pobreza.png"), g_mort_pobreza, width = 9, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_pobreza.png\n")

# Gráfico: Top 10 causas de muerte por nivel de pobreza ----
top10_causas_mort <- defunciones_pob_analisis %>%
  filter(causa_agrupada != "Otras causas") %>%
  count(causa_agrupada) %>%
  arrange(desc(n)) %>%
  slice(1:10) %>%
  pull(causa_agrupada)

graf_causas_pob_data <- defunciones_pob_analisis %>%
  filter(causa_agrupada %in% top10_causas_mort) %>%
  count(nivel_pobreza, causa_agrupada) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

graf_causas_pob_data$causa_agrupada <- factor(graf_causas_pob_data$causa_agrupada, levels = rev(top10_causas_mort))

# Calcular ratios para causas por pobreza
ratios_causas_pob <- graf_causas_pob_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(causa_agrupada, nivel_pobreza, tasa_1000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_num = as.numeric(causa_agrupada),
    x_mayor = x_num - 0.233,
    x_menor = x_num + 0.233,
    y_pointer = y_max + max(graf_causas_pob_data$tasa_1000) * 0.02,
    y_bracket = y_pointer + max(graf_causas_pob_data$tasa_1000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_mort_causas_pob <- ggplot(graf_causas_pob_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_causas_pob,
               aes(x = x_mayor, xend = x_menor, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_causas_pob,
               aes(x = x_mayor, xend = x_mayor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_causas_pob,
               aes(x = x_menor, xend = x_menor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_causas_pob,
             aes(x = x_num, y = y_bracket + max(graf_causas_pob_data$tasa_1000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_x_discrete(labels = function(x) ifelse(x %in% names(causa_labels), causa_labels[x], x)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Tasa de mortalidad por causa y nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 24, face = "bold"),
        plot.subtitle = element_text(size = 18),
        axis.title = element_text(size = 18),
        axis.text = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        legend.title = element_text(size = 18, face = "bold"),
        legend.text = element_text(size = 16))

ggsave(file.path(output_dir, "mortalidad_causas_pobreza.png"), g_mort_causas_pob, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_causas_pobreza.png\n")

# =============================================================================
# Mortalidad por tipo de causa (naturales vs externas) por POBREZA
# =============================================================================

cat("\n--- Análisis de causas naturales vs externas por pobreza ---\n")

# Preparar datos con clasificación
defunciones_pobreza <- defunciones_pobreza %>%
  mutate(
    tipo_causa_con_externas = case_when(
      causa_agrupada %in% c("Cardiovasculares", "Tumores", "Respiratorias", 
                            "Metabolicas/Endocrinas", "Digestivas", "Infecciosas",
                            "Genitales/Urinarias", "Sistema nervioso", "COVID-19",
                            "Perinatales", "Congenitas") ~ "Causas naturales",
      causa_agrupada == "Causas externas" ~ "Causas externas (total)",
      TRUE ~ "Otras causas"
    )
  )

adultos_tipo_causa_pob <- defunciones_pobreza %>%
  filter(grupo_edad %in% c("30-64", "65+") & 
         !is.na(nivel_pobreza))

adultos_tipo_causa_pob$nivel_pobreza <- factor(
  adultos_tipo_causa_pob$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

# Crear dataset con causas naturales + externas total + externas desagregadas
datos_principales_pob <- adultos_tipo_causa_pob %>%
  filter(tipo_causa_con_externas %in% c("Causas naturales", "Causas externas (total)")) %>%
  count(nivel_pobreza, tipo_causa_con_externas) %>%
  rename(categoria = tipo_causa_con_externas)

datos_externas_pob <- adultos_tipo_causa_pob %>%
  filter(!is.na(causa_externa_especifica)) %>%
  count(nivel_pobreza, causa_externa_especifica) %>%
  rename(categoria = causa_externa_especifica)

graf_tipo_causa_pob_data <- bind_rows(datos_principales_pob, datos_externas_pob) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_10000 = n / poblacion * 10000)

graf_tipo_causa_pob_data <- graf_tipo_causa_pob_data %>%
  filter(categoria %in% orden_categorias)

graf_tipo_causa_pob_data$categoria <- factor(
  graf_tipo_causa_pob_data$categoria,
  levels = rev(orden_categorias)
)

# Calcular ratios para el bracket conector (Mayor pobreza / Menor pobreza)
ratios_pobreza <- graf_tipo_causa_pob_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(categoria, nivel_pobreza, tasa_10000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_10000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`),
    # Posiciones x de las barras (dodge offset para 3 grupos: -0.233, 0, 0.233)
    x_num = as.numeric(categoria),
    x_mayor = x_num - 0.233,     # Mayor pobreza (arriba en el gráfico)
    x_menor = x_num + 0.233,     # Menor pobreza (abajo en el gráfico)
    # Posiciones del bracket (medidas absolutas para altura consistente)
    y_pointer = y_max + 0.5,     # Donde terminan las líneas que apuntan
    y_bracket = y_pointer + 0.5  # Línea vertical conectora (0.5 unidades de altura fija)
  )

g_tipo_causa_pob <- ggplot(graf_tipo_causa_pob_data, aes(x = categoria, y = tasa_10000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Línea vertical del bracket (conecta las dos barras extremas)
  geom_segment(data = ratios_pobreza,
               aes(x = x_mayor, xend = x_menor,
                   y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra de Mayor pobreza
  geom_segment(data = ratios_pobreza,
               aes(x = x_mayor, xend = x_mayor,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra de Menor pobreza
  geom_segment(data = ratios_pobreza,
               aes(x = x_menor, xend = x_menor,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Etiqueta con el ratio posicionada a la derecha del bracket
  geom_label(data = ratios_pobreza,
             aes(x = x_num, y = y_bracket + 1, label = ratio_label),
             inherit.aes = FALSE,
             fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_x_discrete(labels = etiquetas_categorias) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Mortalidad por tipo de causa y nivel de pobreza (30+ años)",
    subtitle = "Ecuador 2024 - Tasa por 10,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Tasa por 10,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 24, face = "bold"),
        plot.subtitle = element_text(size = 18),
        axis.title = element_text(size = 18),
        axis.text = element_text(size = 16),
        axis.text.y = element_text(family = "sans", hjust = 0, color = "black", size = 16),
        legend.title = element_text(size = 18, face = "bold"),
        legend.text = element_text(size = 16))

ggsave(file.path(output_dir, "mortalidad_tipo_causa_pobreza.png"), g_tipo_causa_pob, width = 12, height = 9, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_tipo_causa_pobreza.png\n")

# Resumen ----
cat("\n--- Resumen de mortalidad por educación ---\n")
cat("Jóvenes:\n")
print(tasas_jovenes_educ)
cat("\nAdultos:\n")
print(tasas_adultos_educ)

cat("\n--- Resumen de mortalidad por pobreza ---\n")
print(tasas_mort_pobreza)

# =============================================================================
# ANÁLISIS DETALLADO DE CAUSAS EXTERNAS Y SUICIDIOS
# =============================================================================

cat("\n========== ANÁLISIS DE CAUSAS EXTERNAS Y SUICIDIOS ==========\n")

# Clasificación de métodos de suicidio ----
defunciones <- defunciones %>%
  mutate(
    metodo_suicidio = case_when(
      grepl("^X70", causa) ~ "Ahorcamiento/estrangulación",
      grepl("^X6[89]", causa) ~ "Envenenamiento (sustancias)",
      grepl("^X64|^X65|^X66|^X67", causa) ~ "Envenenamiento (otras)",
      grepl("^X80", causa) ~ "Saltar desde altura",
      grepl("^X7[234]", causa) ~ "Arma de fuego",
      grepl("^X78", causa) ~ "Objeto cortante",
      grepl("^X71", causa) ~ "Ahogamiento",
      grepl("^X79|^X81|^X82|^X83|^X84", causa) ~ "Otros métodos",
      grepl("^X6[0-3]", causa) ~ "Envenenamiento (medicamentos)",
      TRUE ~ NA_character_
    )
  )

# =============================================================================
# CAUSAS EXTERNAS POR NIVEL EDUCATIVO
# =============================================================================

cat("\n--- Causas externas por nivel educativo ---\n")

# Gráfico: Causas externas en jóvenes por educación ----
jovenes_externas <- defunciones %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_educativo_jovenes))

graf_ext_jov_data <- jovenes_externas %>%
  count(nivel_educativo_jovenes, causa_externa_especifica) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 5)

orden_causas_ext <- jovenes_externas %>%
  count(causa_externa_especifica) %>%
  arrange(desc(n)) %>%
  pull(causa_externa_especifica)

graf_ext_jov_data$causa_externa_especifica <- factor(graf_ext_jov_data$causa_externa_especifica,
                                                levels = rev(orden_causas_ext))

# Calcular ratios para jóvenes externas
ratios_ext_jov <- graf_ext_jov_data %>%
  select(causa_externa_especifica, nivel_educativo_jovenes, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_100000) %>%
  mutate(
    ratio = `Secundaria incompleta` / `Secundaria completa`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Secundaria completa`, `Secundaria incompleta`, na.rm = TRUE),
    x_num = as.numeric(causa_externa_especifica),
    x_comp = x_num - 0.175,
    x_incomp = x_num + 0.175,
    y_pointer = y_max + max(graf_ext_jov_data$tasa_100000) * 0.02,
    y_bracket = y_pointer + max(graf_ext_jov_data$tasa_100000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_ext_jov_educ <- ggplot(graf_ext_jov_data, aes(x = causa_externa_especifica, y = tasa_100000,
                                fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_ext_jov,
               aes(x = x_comp, xend = x_incomp, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_jov,
               aes(x = x_comp, xend = x_comp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_jov,
               aes(x = x_incomp, xend = x_incomp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_ext_jov,
             aes(x = x_num, y = y_bracket + max(graf_ext_jov_data$tasa_100000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Muertes por causas externas en jóvenes (20-29) según nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Sec. incompleta / Sec. completa)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "externas_jovenes_educacion.png"), g_ext_jov_educ, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: externas_jovenes_educacion.png\n")

# Gráfico: Causas externas en adultos por educación ----
adultos_externas <- defunciones %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_educativo_adultos))

graf_ext_adult_data <- adultos_externas %>%
  count(nivel_educativo_adultos, causa_externa_especifica) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 10)

graf_ext_adult_data$causa_externa_especifica <- factor(graf_ext_adult_data$causa_externa_especifica,
                                                levels = rev(orden_causas_ext))

# Calcular ratios para adultos externas
ratios_ext_adult <- graf_ext_adult_data %>%
  select(causa_externa_especifica, nivel_educativo_adultos, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_100000) %>%
  mutate(
    ratio = `No universitario` / Universitario,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Universitario, `No universitario`, na.rm = TRUE),
    x_num = as.numeric(causa_externa_especifica),
    x_univ = x_num - 0.175,
    x_no_univ = x_num + 0.175,
    y_pointer = y_max + max(graf_ext_adult_data$tasa_100000) * 0.02,
    y_bracket = y_pointer + max(graf_ext_adult_data$tasa_100000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_ext_adult_educ <- ggplot(graf_ext_adult_data, aes(x = causa_externa_especifica, y = tasa_100000,
                                fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_ext_adult,
               aes(x = x_univ, xend = x_no_univ, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_adult,
               aes(x = x_univ, xend = x_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_adult,
               aes(x = x_no_univ, xend = x_no_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_ext_adult,
             aes(x = x_num, y = y_bracket + max(graf_ext_adult_data$tasa_100000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Muertes por causas externas en adultos (30+) según nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "externas_adultos_educacion.png"), g_ext_adult_educ, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: externas_adultos_educacion.png\n")

# =============================================================================
# CAUSAS EXTERNAS POR NIVEL DE POBREZA
# =============================================================================

cat("\n--- Causas externas por nivel de pobreza ---\n")

# Actualizar defunciones_pobreza con las clasificaciones de métodos de suicidio
defunciones_pobreza <- defunciones_pobreza %>%
  mutate(
    metodo_suicidio = case_when(
      grepl("^X70", causa) ~ "Ahorcamiento/estrangulación",
      grepl("^X6[89]", causa) ~ "Envenenamiento (sustancias)",
      grepl("^X64|^X65|^X66|^X67", causa) ~ "Envenenamiento (otras)",
      grepl("^X80", causa) ~ "Saltar desde altura",
      grepl("^X7[234]", causa) ~ "Arma de fuego",
      grepl("^X78", causa) ~ "Objeto cortante",
      grepl("^X71", causa) ~ "Ahogamiento",
      grepl("^X79|^X81|^X82|^X83|^X84", causa) ~ "Otros métodos",
      grepl("^X6[0-3]", causa) ~ "Envenenamiento (medicamentos)",
      TRUE ~ NA_character_
    )
  )

externas_pobreza <- defunciones_pobreza %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_pobreza))

externas_pobreza$nivel_pobreza <- factor(
  externas_pobreza$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

cat("Muertes por causas externas con datos de pobreza:", nrow(externas_pobreza), "\n")

# Gráfico: Causas externas por tipo y nivel de pobreza ----
graf_ext_tipo_pob_data <- externas_pobreza %>%
  count(nivel_pobreza, causa_externa_especifica) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_100000 = n / poblacion * 100000)

orden_ext_pob <- externas_pobreza %>%
  count(causa_externa_especifica) %>%
  arrange(desc(n)) %>%
  pull(causa_externa_especifica)

graf_ext_tipo_pob_data$causa_externa_especifica <- factor(graf_ext_tipo_pob_data$causa_externa_especifica,
                                               levels = rev(orden_ext_pob))

# Calcular ratios para externas tipo por pobreza
ratios_ext_tipo_pob <- graf_ext_tipo_pob_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(causa_externa_especifica, nivel_pobreza, tasa_100000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_100000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_num = as.numeric(causa_externa_especifica),
    x_mayor = x_num - 0.233,
    x_menor = x_num + 0.233,
    y_pointer = y_max + max(graf_ext_tipo_pob_data$tasa_100000) * 0.02,
    y_bracket = y_pointer + max(graf_ext_tipo_pob_data$tasa_100000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_ext_tipo_pob <- ggplot(graf_ext_tipo_pob_data, aes(x = causa_externa_especifica, y = tasa_100000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_ext_tipo_pob,
               aes(x = x_mayor, xend = x_menor, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_tipo_pob,
               aes(x = x_mayor, xend = x_mayor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_ext_tipo_pob,
               aes(x = x_menor, xend = x_menor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_ext_tipo_pob,
             aes(x = x_num, y = y_bracket + max(graf_ext_tipo_pob_data$tasa_100000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Muertes por causas externas según tipo y nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "externas_tipo_pobreza.png"), g_ext_tipo_pob, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: externas_tipo_pobreza.png\n")

# =============================================================================
# SUICIDIOS POR NIVEL EDUCATIVO
# =============================================================================

cat("\n--- Suicidios por nivel educativo ---\n")

# Gráfico: Tasa total de suicidio en jóvenes por educación ----
jovenes_suicidios <- defunciones %>%
  filter(!is.na(metodo_suicidio) & !is.na(nivel_educativo_jovenes))

tasa_suicidio_jovenes <- jovenes_suicidios %>%
  count(nivel_educativo_jovenes) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  )

# Calcular ratio para suicidio jóvenes
ratio_suic_jov <- tasa_suicidio_jovenes %>%
  select(nivel_educativo_jovenes, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_100000) %>%
  mutate(ratio = `Secundaria incompleta` / `Secundaria completa`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_suic_jov_educ <- ggplot(tasa_suicidio_jovenes, aes(x = nivel_educativo_jovenes, y = tasa_100000,
                                          fill = nivel_educativo_jovenes)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", n, ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio
  annotate("segment", x = 1, xend = 2,
           y = max(tasa_suicidio_jovenes$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_jovenes$tasa_100000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasa_suicidio_jovenes$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_jovenes$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 2, xend = 2,
           y = max(tasa_suicidio_jovenes$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_jovenes$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 1.5, y = max(tasa_suicidio_jovenes$tasa_100000) * 1.33,
                 label = ratio_suic_jov$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de suicidio en jóvenes (20-29) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Sec. incompleta / Sec. completa)",
    x = NULL,
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "suicidios_jovenes_educacion.png"), g_suic_jov_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_jovenes_educacion.png\n")

# Gráfico: Tasa total de suicidio en adultos por educación ----
adultos_suicidios <- defunciones %>%
  filter(!is.na(metodo_suicidio) & !is.na(nivel_educativo_adultos))

tasa_suicidio_adultos <- adultos_suicidios %>%
  count(nivel_educativo_adultos) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  )

# Calcular ratio para suicidio adultos
ratio_suic_adult <- tasa_suicidio_adultos %>%
  select(nivel_educativo_adultos, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_100000) %>%
  mutate(ratio = `No universitario` / Universitario,
         ratio_label = paste0(round(ratio, 1), "x"))

g_suic_adult_educ <- ggplot(tasa_suicidio_adultos, aes(x = nivel_educativo_adultos, y = tasa_100000,
                                          fill = nivel_educativo_adultos)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", n, ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio
  annotate("segment", x = 1, xend = 2,
           y = max(tasa_suicidio_adultos$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_adultos$tasa_100000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasa_suicidio_adultos$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_adultos$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 2, xend = 2,
           y = max(tasa_suicidio_adultos$tasa_100000) * 1.28,
           yend = max(tasa_suicidio_adultos$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 1.5, y = max(tasa_suicidio_adultos$tasa_100000) * 1.33,
                 label = ratio_suic_adult$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de suicidio en adultos (30+) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "suicidios_adultos_educacion.png"), g_suic_adult_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_adultos_educacion.png\n")

# =============================================================================
# SUICIDIOS POR NIVEL DE POBREZA
# =============================================================================

cat("\n--- Suicidios por nivel de pobreza ---\n")

suicidios_pobreza <- defunciones_pobreza %>%
  filter(!is.na(metodo_suicidio) & !is.na(nivel_pobreza))

suicidios_pobreza$nivel_pobreza <- factor(
  suicidios_pobreza$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

cat("Suicidios con datos de pobreza:", nrow(suicidios_pobreza), "\n")

# Gráfico: Tasa de suicidios por nivel de pobreza ----
tasas_suicidio_pob <- suicidios_pobreza %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_100000 = n / poblacion * 100000)

# Calcular ratio para suicidios por pobreza
ratio_suic_pob <- tasas_suicidio_pob %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, tasa_100000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_100000) %>%
  mutate(ratio = `Mayor pobreza` / `Menor pobreza`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_suic_pobreza <- ggplot(tasas_suicidio_pob, aes(x = nivel_pobreza, y = tasa_100000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio
  annotate("segment", x = 1, xend = 3,
           y = max(tasas_suicidio_pob$tasa_100000) * 1.28,
           yend = max(tasas_suicidio_pob$tasa_100000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_suicidio_pob$tasa_100000) * 1.28,
           yend = max(tasas_suicidio_pob$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(tasas_suicidio_pob$tasa_100000) * 1.28,
           yend = max(tasas_suicidio_pob$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(tasas_suicidio_pob$tasa_100000) * 1.33,
                 label = ratio_suic_pob$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de suicidios por nivel de pobreza de la parroquia",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "suicidios_pobreza.png"), g_suic_pobreza, width = 9, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_pobreza.png\n")

# Gráfico: Comparación suicidios y homicidios por pobreza ----
violentas_comp <- externas_pobreza %>%
  filter(causa_externa_especifica %in% c("Suicidios", "Homicidios")) %>%
  count(nivel_pobreza, causa_externa_especifica) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_100000 = n / poblacion * 100000)

# Calcular ratios para suicidios/homicidios por pobreza
ratios_violentas <- violentas_comp %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(causa_externa_especifica, nivel_pobreza, tasa_100000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_100000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE)
  ) %>%
  filter(!is.na(ratio))

# Preparar datos para anotaciones de ratio
if (nrow(ratios_violentas) > 0) {
  ratio_suic <- ratios_violentas %>% filter(causa_externa_especifica == "Suicidios")
  ratio_hom <- ratios_violentas %>% filter(causa_externa_especifica == "Homicidios")

  g_suic_hom_pob <- ggplot(violentas_comp, aes(x = nivel_pobreza, y = tasa_100000, fill = causa_externa_especifica)) +
    geom_col(position = "dodge", width = 0.6) +
    geom_text(aes(label = round(tasa_100000, 1)),
              position = position_dodge(width = 0.6), vjust = -0.3, size = 3.5) +
    scale_fill_manual(values = c("Suicidios" = "#E74C3C", "Homicidios" = "#8E44AD")) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
    labs(
      title = "Suicidios y homicidios por nivel de pobreza",
      subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
      x = "Nivel de pobreza (NBI)",
      y = "Tasa por 100,000 habitantes",
      fill = "Tipo de muerte"
    ) +
    theme(legend.position = "bottom")

  ggsave(file.path(output_dir, "suicidios_homicidios_pobreza.png"), g_suic_hom_pob, width = 10, height = 7, dpi = 300, bg = "white")
  cat("Gráfico guardado: suicidios_homicidios_pobreza.png\n")
}

cat("\n========== ANÁLISIS COMPLETO FINALIZADO ==========\n")

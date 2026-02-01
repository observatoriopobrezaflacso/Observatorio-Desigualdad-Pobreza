# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Análisis de Defunciones por Nivel Educativo 
# Boletín 2 - Observatorio de Políticas Públicas
# Mortalidad por educación
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


cat("\n========== ANÁLISIS DE DEFUNCIONES POR NIVEL EDUCATIVO ==========\n")

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
      edad_num >= 30 & as.numeric(niv_inst) %in% c(6, 7, 8) ~ "Superior",
      edad_num >= 30 & as.numeric(niv_inst) %in% c(0, 1, 2, 3, 4, 5) ~ "No superior",
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

# Clasificación de causas externas específicas 
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

# Etiquetas con acentos para los graficos 
causa_labels <- c(
  "Metabolicas/Endocrinas" = "Metabólicas/Endocrinas",
  "Congenitas" = "Congénitas"
)

# Filtrado de datos para analisis 
defunciones_analisis <- defunciones %>%
  filter(!is.na(grupo_edad) & !is.na(causa_agrupada))

# Orden de causas por frecuencia
orden_causas <- defunciones_analisis %>%
  count(causa_agrupada) %>%
  arrange(desc(n)) %>%
  pull(causa_agrupada)

cat("Registros para análisis (sin niños):", nrow(defunciones_analisis), "\n")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Mortalidad por nivel educativo ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Análisis por nivel educativo ---\n")

## Gráfico: Jóvenes - Tasa total por nivel educativo ----
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
    
    subtitle = paste0("Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Sec. incompleta / Sec. completa)"),
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

#ggsave(file.path(output_dir, "mortalidad_jovenes_educacion.png"), g_mort_jov_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_jovenes_educacion.png\n")

## Gráfico: Jóvenes - Causas por nivel educativo ----


# jovenes_con_causa <- defunciones %>%
#   filter(grupo_edad == "20-29" & !is.na(nivel_educativo_jovenes) & !is.na(causa_agrupada))

# graf_jov_causas_data <- jovenes_con_causa %>%
#   count(nivel_educativo_jovenes, causa_agrupada) %>%
#   mutate(
#     poblacion = case_when(
#       nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
#       nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
#     ),
#     tasa_1000 = n / poblacion * 1000
#   )

# top8_jovenes <- jovenes_con_causa %>%
#   count(causa_agrupada) %>%
#   arrange(desc(n)) %>%
#   slice(1:8) %>%
#   pull(causa_agrupada)

# graf_jov_causas_data <- graf_jov_causas_data %>% filter(causa_agrupada %in% top8_jovenes)
# graf_jov_causas_data$causa_agrupada <- factor(graf_jov_causas_data$causa_agrupada, levels = rev(top8_jovenes))

# # Calcular ratios para jóvenes causas
# ratios_jov_causas <- graf_jov_causas_data %>%
#   select(causa_agrupada, nivel_educativo_jovenes, tasa_1000) %>%
#   pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_1000) %>%
#   mutate(
#     ratio = `Secundaria incompleta` / `Secundaria completa`,
#     ratio_label = paste0(round(ratio, 1), "x"),
#     y_max = pmax(`Secundaria completa`, `Secundaria incompleta`, na.rm = TRUE),
#     x_num = as.numeric(causa_agrupada),
#     x_comp = x_num - 0.175,
#     x_incomp = x_num + 0.175,
#     y_pointer = y_max + max(graf_jov_causas_data$tasa_1000) * 0.02,
#     y_bracket = y_pointer + max(graf_jov_causas_data$tasa_1000) * 0.02
#   ) %>%
#   filter(!is.na(ratio))

# g_mort_jov_causas <- ggplot(graf_jov_causas_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_jovenes)) +
#   geom_col(position = "dodge", width = 0.7) +
#   # Brackets y ratios
#   geom_segment(data = ratios_jov_causas,
#                aes(x = x_comp, xend = x_incomp, y = y_bracket, yend = y_bracket),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_segment(data = ratios_jov_causas,
#                aes(x = x_comp, xend = x_comp, y = y_bracket, yend = y_pointer),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_segment(data = ratios_jov_causas,
#                aes(x = x_incomp, xend = x_incomp, y = y_bracket, yend = y_pointer),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_label(data = ratios_jov_causas,
#              aes(x = x_num, y = y_bracket + max(graf_jov_causas_data$tasa_1000) * 0.06, label = ratio_label),
#              inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
#              label.padding = unit(0.2, "lines")) +
#   coord_flip() +
#   scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
#   scale_x_discrete(labels = function(x) ifelse(x %in% names(causa_labels), causa_labels[x], x)) +
#   scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
#   labs(
#     
#     subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Sec. incompleta / Sec. completa)",
#     x = NULL,
#     y = "Tasa por 1,000 habitantes",
#     fill = "Nivel educativo"
#   ) +
#   theme(legend.position = "bottom",
#         plot.title = element_text(size = 24, face = "bold"),
#         plot.subtitle = element_text(size = 18),
#         axis.title = element_text(size = 18),
#         axis.text = element_text(size = 16),
#         axis.text.y = element_text(size = 16),
#         legend.title = element_text(size = 18, face = "bold"),
#         legend.text = element_text(size = 16))

# ggsave(file.path(output_dir, "mortalidad_jovenes_causas_educacion.png"), g_mort_jov_causas, width = 11, height = 7, dpi = 300, bg = "white")
# cat("Gráfico guardado: mortalidad_jovenes_causas_educacion.png\n")


## Gráfico: Adultos - Tasa total por nivel educativo ----


adultos_analisis <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+") & !is.na(nivel_educativo_adultos))

tasas_adultos_educ <- adultos_analisis %>%
  count(nivel_educativo_adultos) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Superior" ~ poblacion_educacion_adultos$superior,
      nivel_educativo_adultos == "No superior" ~ poblacion_educacion_adultos$no_superior
    ),
    tasa_1000 = n / poblacion * 1000
  )

# Calcular ratio para adultos
ratio_adultos_educ <- tasas_adultos_educ %>%
  select(nivel_educativo_adultos, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
  mutate(ratio = `No superior` / Superior,
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
  scale_fill_manual(values = c("Superior" = "#2E86AB", "No superior" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = No superior / Superior)",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

#ggsave(file.path(output_dir, "mortalidad_adultos_educacion.png"), g_mort_adult_educ, width = 8, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_adultos_educacion.png\n")

## Gráfico: Adultos - Causas por nivel educativo ----
# adultos_con_causa <- defunciones %>%
#   filter(grupo_edad %in% c("30-64", "65+") &
#          !is.na(nivel_educativo_adultos) & !is.na(causa_agrupada))

# graf_adult_causas_data <- adultos_con_causa %>%
#   count(grupo_edad, nivel_educativo_adultos, causa_agrupada) %>%
#   mutate(
#     poblacion = case_when(
#       nivel_educativo_adultos == "Superior" ~ poblacion_educacion_adultos$superior / 2 BE CAREFULL HERE,
#       nivel_educativo_adultos == "No superior" ~ poblacion_educacion_adultos$no_superior / 2 BE CAREFULL HERE
#     ),
#     tasa_1000 = n / poblacion * 1000
#   ) %>%
#   filter(causa_agrupada %in% orden_causas[1:8])

# graf_adult_causas_data$causa_agrupada <- factor(graf_adult_causas_data$causa_agrupada, levels = rev(orden_causas[1:8]))
# graf_adult_causas_data$grupo_edad <- factor(graf_adult_causas_data$grupo_edad, levels = c("30-64", "65+"))

# # Calcular ratios para adultos causas (por grupo de edad)
# ratios_adult_causas <- graf_adult_causas_data %>%
#   select(grupo_edad, causa_agrupada, nivel_educativo_adultos, tasa_1000) %>%
#   pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
#   mutate(
#     ratio = `No superior` / Superior,
#     ratio_label = paste0(round(ratio, 1), "x"),
#     y_max = pmax(Superior, `No superior`, na.rm = TRUE),
#     x_num = as.numeric(causa_agrupada),
#     x_univ = x_num - 0.175,
#     x_no_univ = x_num + 0.175,
#     y_pointer = y_max + max(graf_adult_causas_data$tasa_1000) * 0.02,
#     y_bracket = y_pointer + max(graf_adult_causas_data$tasa_1000) * 0.02
#   ) %>%
#   filter(!is.na(ratio))

# g_mort_adult_causas <- ggplot(graf_adult_causas_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_adultos)) +
#   geom_col(position = "dodge", width = 0.7) +
#   # Brackets y ratios
#   geom_segment(data = ratios_adult_causas,
#                aes(x = x_univ, xend = x_no_univ, y = y_bracket, yend = y_bracket),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_segment(data = ratios_adult_causas,
#                aes(x = x_univ, xend = x_univ, y = y_bracket, yend = y_pointer),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_segment(data = ratios_adult_causas,
#                aes(x = x_no_univ, xend = x_no_univ, y = y_bracket, yend = y_pointer),
#                inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
#   geom_label(data = ratios_adult_causas,
#              aes(x = x_num, y = y_bracket + max(graf_adult_causas_data$tasa_1000) * 0.06, label = ratio_label),
#              inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
#              label.padding = unit(0.2, "lines")) +
#   coord_flip() +
#   facet_wrap(~grupo_edad, ncol = 2) +
#   scale_fill_manual(values = c("Superior" = "#2E86AB", "No superior" = "#E94F37")) +
#   scale_x_discrete(labels = function(x) ifelse(x %in% names(causa_labels), causa_labels[x], x)) +
#   scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
#   labs(
#     
#     subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = No superior / Superior)",
#     x = NULL,
#     y = "Tasa por 1,000 habitantes",
#     fill = "Nivel educativo"
#   ) +
#   theme(legend.position = "bottom",
#         plot.title = element_text(size = 24, face = "bold"),
#         plot.subtitle = element_text(size = 18),
#         axis.title = element_text(size = 18),
#         axis.text = element_text(size = 16),
#         axis.text.y = element_text(size = 16),
#         legend.title = element_text(size = 18, face = "bold"),
#         legend.text = element_text(size = 16),
#         strip.text = element_text(face = "bold", size = 16))

# ggsave(file.path(output_dir, "mortalidad_adultos_causas_educacion.png"), g_mort_adult_causas, width = 13, height = 8, dpi = 300, bg = "white")
# cat("Gráfico guardado: mortalidad_adultos_causas_educacion.png\n")

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Mortalidad por tipo de causa ----
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## Adultos ----
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

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
# adultos_tipo_causa <- defunciones %>%
#   filter(grupo_edad %in% c("30-64", "65+") &
#          !is.na(nivel_educativo_adultos))

datos_adultos <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+"))


# Crear dataset con causas naturales + externas total + externas desagregadas
# Primero: causas naturales y externas total
datos_principales <- datos_adultos %>%
  filter(tipo_causa_con_externas %in% c("Causas naturales", "Causas externas (total)")) %>%
  count(nivel_educativo_adultos, tipo_causa_con_externas) %>%
  rename(categoria = tipo_causa_con_externas)

# Segundo: causas externas desagregadas
datos_externas_adultos <- datos_adultos %>%
  filter(!is.na(causa_externa_especifica)) %>%
  count(nivel_educativo_adultos, causa_externa_especifica) %>%
  rename(categoria = causa_externa_especifica)

# Combinar
graf_tipo_causa_data <- bind_rows(datos_principales, datos_externas_adultos) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Superior" ~ poblacion_educacion_adultos$superior,
      nivel_educativo_adultos == "No superior" ~ poblacion_educacion_adultos$no_superior
    ),
    tasa_1000 = n / poblacion * 1000
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
  select(categoria, nivel_educativo_adultos, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
  mutate(
    ratio = `No superior` / Superior,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Superior, `No superior`),
    # Posiciones x de las barras (dodge offset = 0.175)
    x_num = as.numeric(categoria),
    x_univ = x_num - 0.175,      # Superior (arriba en el gráfico)
    x_no_univ = x_num + 0.175,   # No superior (abajo en el gráfico)
    # Posiciones del bracket (medidas absolutas para altura consistente)
    y_pointer = y_max + 1,       # Donde terminan las líneas que apuntan (1 unidad después de la barra)
    y_bracket = y_pointer + 1    # Línea vertical conectora (1 unidad de altura fija)
  )

g_tipo_causa <- ggplot(graf_tipo_causa_data, aes(x = categoria, y = tasa_1000, fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  # Línea vertical del bracket (conecta las dos barras)
  geom_segment(data = ratios_educacion,
               aes(x = x_univ, xend = x_no_univ,
                   y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra azul (Superior) - termina al mismo nivel que la otra
  geom_segment(data = ratios_educacion,
               aes(x = x_univ, xend = x_univ,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra roja (No superior) - termina al mismo nivel
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
  scale_fill_manual(values = c("Superior" = "#2E86AB", "No superior" = "#E94F37")) +
  scale_x_discrete(labels = etiquetas_categorias) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    
    subtitle = "Ecuador 2024 - Tasa por 1000 habitantes (ratio = No superior / Superior)",
    x = NULL,
    y = "Tasa por 1000 habitantes",
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

#ggsave(file.path(output_dir, "mortalidad_adultos_causas_educacion2.png"), g_tipo_causa, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_adultos_causas_educacion2.png\n")

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## Jóvenes ----
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Análisis de causas naturales vs externas por educación ---\n")

# Preparar datos para jovenes
datos_jovenes <- defunciones %>%
  filter(grupo_edad == "20-29")

# Crear dataset con causas naturales + externas total + externas desagregadas
# Primero: causas naturales y externas total
datos_principales <- datos_jovenes %>%
  filter(tipo_causa_con_externas %in% c("Causas naturales", "Causas externas (total)")) %>%
  count(nivel_educativo_jovenes, tipo_causa_con_externas) %>%
  rename(categoria = tipo_causa_con_externas)

# Segundo: causas externas desagregadas
datos_externas_jovenes <- datos_jovenes %>%
  filter(!is.na(causa_externa_especifica)) %>%
  count(nivel_educativo_jovenes, causa_externa_especifica) %>%
  rename(categoria = causa_externa_especifica)

# Combinar
graf_tipo_causa_data <- bind_rows(datos_principales, datos_externas_jovenes) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_1000 = n / poblacion * 1000
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
  "Suicidios" =  "   ├ Suicidios",
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
  select(categoria, nivel_educativo_jovenes, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_1000) %>%
  mutate(
    ratio = `Secundaria incompleta` / `Secundaria completa`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Secundaria completa`, `Secundaria incompleta`),
    # Posiciones x de las barras (dodge offset = 0.175)
    x_num = as.numeric(categoria),
    x_sec_completa = x_num - 0.175,      # Secundaria completa (arriba en el gráfico)
    x_sec_incompleta = x_num + 0.175,    # Secundaria incompleta (abajo en el gráfico)
    # Posiciones del bracket (medidas absolutas para altura consistente)
    y_pointer = y_max + 1,       # Donde terminan las líneas que apuntan (1 unidad después de la barra)
    y_bracket = y_pointer + 1    # Línea vertical conectora (1 unidad de altura fija)
  )

g_tipo_causa <- ggplot(graf_tipo_causa_data, aes(x = categoria, y = tasa_1000, fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  # Línea vertical del bracket (conecta las dos barras)
  geom_segment(data = ratios_educacion,
               aes(x = x_sec_completa, xend = x_sec_incompleta,
                   y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra azul (Secundaria completa) - termina al mismo nivel que la otra
  geom_segment(data = ratios_educacion,
               aes(x = x_sec_completa, xend = x_sec_completa,
                   y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  # Línea que apunta hacia barra roja (Secundaria incompleta) - termina al mismo nivel
  geom_segment(data = ratios_educacion,
               aes(x = x_sec_incompleta, xend = x_sec_incompleta,
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
  scale_fill_manual(values = c("Secundaria completa" = "#2E86AB", "Secundaria incompleta" = "#E94F37")) +
  scale_x_discrete(labels = etiquetas_categorias) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    
    subtitle = "Ecuador 2024 - Tasa por 1000 habitantes (ratio = Sec. incompleta / Sec. completa)",
    x = NULL,
    y = "Tasa por 1000 habitantes",
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

#ggsave(file.path(output_dir, "mortalidad_jovenes_causas_educacion2.png"), g_tipo_causa, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_jovenes_causas_educacion2.png\n")





# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Análisis combinado: jóvenes y adultos ----
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

cat("\n--- Gráficos combinados de jóvenes y adultos ---\n")

## Gráfico 1: Mortalidad total combinada (jóvenes y adultos) ----

# Preparar datos de jóvenes
tasas_jovenes_plot <- tasas_jovenes_educ %>%
  mutate(
    grupo = "Jóvenes (20-29 años)",
    nivel_educativo_label = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ "Secundaria\ncompleta",
      nivel_educativo_jovenes == "Secundaria incompleta" ~ "Secundaria\nincompleta"
    )
  ) %>%
  select(grupo, nivel_educativo_label, tasa_1000, n)

# Preparar datos de adultos
tasas_adultos_plot <- tasas_adultos_educ %>%
  mutate(
    grupo = "Adultos (30+ años)",
    nivel_educativo_label = case_when(
      nivel_educativo_adultos == "Superior" ~ "Superior",
      nivel_educativo_adultos == "No superior" ~ "No\nsuperior"
    )
  ) %>%
  select(grupo, nivel_educativo_label, tasa_1000, n)

# Combinar datos
tasas_combinadas <- bind_rows(tasas_jovenes_plot, tasas_adultos_plot)

# Ensure Jóvenes appears on the LEFT and Adultos on the RIGHT
tasas_combinadas$grupo <- factor(tasas_combinadas$grupo,
                                 levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))


# Force consistent order: Low Education (Left) -> High Education (Right)
tasas_combinadas$nivel_educativo_label <- factor(tasas_combinadas$nivel_educativo_label,
                                                 levels = c("Secundaria\nincompleta", "Secundaria\ncompleta", 
                                                            "No\nsuperior", "Superior"))

# Calcular ratios para anotaciones
ratio_jovenes <- tasas_jovenes_educ %>%
  select(nivel_educativo_jovenes, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_1000) %>%
  mutate(
    ratio = `Secundaria incompleta` / `Secundaria completa`,
    ratio_label = paste0(round(ratio, 1), "x"),
    grupo = "Jóvenes (20-29 años)",
    y_max = max(`Secundaria completa`, `Secundaria incompleta`)
  )

ratio_adultos <- tasas_adultos_educ %>%
  select(nivel_educativo_adultos, tasa_1000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_1000) %>%
  mutate(
    ratio = `No superior` / Superior,
    ratio_label = paste0(round(ratio, 1), "x"),
    grupo = "Adultos (30+ años)",
    y_max = max(Superior, `No superior`)
  )

offset1 <- 4
offset2 <- 3.5

# Crear data frames para los brackets y labels
bracket_data <- bind_rows(
  data.frame(
    grupo = "Jóvenes (20-29 años)",
    x = 1, xend = 2,
    y = ratio_jovenes$y_max * 1.15 + offset1,
    yend = ratio_jovenes$y_max * 1.15 + offset1
  ),
  data.frame(
    grupo = "Adultos (30+ años)",
    x = 1, xend = 2,
    y = ratio_adultos$y_max * 1.15 + offset2,
    yend = ratio_adultos$y_max * 1.15 + offset2
  )
)

pointer_left_data <- bind_rows(
  data.frame(
    grupo = "Jóvenes (20-29 años)",
    x = 1, xend = 1,
    y = ratio_jovenes$y_max * 1.12 + offset1,
    yend = ratio_jovenes$y_max * 1.15 + offset1
  ),
  data.frame(
    grupo = "Adultos (30+ años)",
    x = 1, xend = 1,
    y = ratio_adultos$y_max * 1.12 + offset2,
    yend = ratio_adultos$y_max * 1.15 + offset2
  )
)

pointer_right_data <- bind_rows(
  data.frame(
    grupo = "Jóvenes (20-29 años)",
    x = 2, xend = 2,
    y = ratio_jovenes$y_max * 1.12 + offset1,
    yend = ratio_jovenes$y_max * 1.15 + offset1
  ),
  data.frame(
    grupo = "Adultos (30+ años)",
    x = 2, xend = 2,
    y = ratio_adultos$y_max * 1.12 + offset2,
    yend = ratio_adultos$y_max * 1.15 + offset2
  )
)

label_data <- bind_rows(
  data.frame(
    grupo = "Jóvenes (20-29 años)",
    x = 1.5,
    y = ratio_jovenes$y_max * 1.20 + offset1 + 0.5,
    label = ratio_jovenes$ratio_label
  ),
  data.frame(
    grupo = "Adultos (30+ años)",
    x = 1.5,
    y = ratio_adultos$y_max * 1.20 + offset2 + 0.2,
    label = ratio_adultos$ratio_label
  )
)

# Set factor levels for bracket/label data frames to match facet order
bracket_data$grupo <- factor(bracket_data$grupo, 
                             levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))
pointer_left_data$grupo <- factor(pointer_left_data$grupo, 
                                  levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))
pointer_right_data$grupo <- factor(pointer_right_data$grupo, 
                                   levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))
label_data$grupo <- factor(label_data$grupo, 
                           levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))

# Crear gráfico combinado
g_mort_total_combinada <- ggplot(tasas_combinadas,
                                 aes(x = nivel_educativo_label, y = tasa_1000,
                                     fill = nivel_educativo_label)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 5.5) +
  facet_wrap(~ grupo, scales = "free_x", nrow = 1) +
  # Añadir brackets y ratios
  geom_segment(data = bracket_data,
               aes(x = x, xend = xend, y = y, yend = yend),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  geom_segment(data = pointer_left_data,
               aes(x = x, xend = xend, y = y, yend = yend),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  geom_segment(data = pointer_right_data,
               aes(x = x, xend = xend, y = y, yend = yend),
               inherit.aes = FALSE,
               color = "gray40", linewidth = 0.5) +
  geom_label(data = label_data,
             aes(x = x, y = y, label = label),
             inherit.aes = FALSE,
             fill = "white", color = "gray20", size = 4.5, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = c(
    "Secundaria\ncompleta" = "#2E86AB",
    "Secundaria\nincompleta" = "#E94F37",
    "Superior" = "#2E86AB",
    "No\nsuperior" = "#E94F37"
  )) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(
    legend.position = "none",
    strip.text = element_text(size = 12, face = "bold"),
    strip.background = element_rect(fill = "gray90"),
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.text = element_text(size = 15),
    axis.text.x = element_text(size = 15),
    axis.text.y = element_text(size = 15),
    axis.title = element_text(size = 15, face = "bold"),
    axis.title.x = element_text(size = 15, face = "bold"),
    axis.title.y = element_text(size = 15, face = "bold")
  )

g_mort_total_combinada

ggsave(file.path(output_dir, "mortalidad_total_combinada_educacion.png"),
       g_mort_total_combinada, width = 12, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: mortalidad_total_combinada_educacion.png\n")


## Gráfico 2: por causas ----

cat("\n--- Generando gráfico con orden de leyenda actualizado ---\n")

# 1. Definir etiquetas y orden jerárquico de causas

orden_jerarquico <- c(
  "Causas naturales",
  "Causas externas (total)",
  "   ├ Accidentes tránsito",
  "   ├ Homicidios",
  "   ├ Suicidios",
  "   └ Otras externas"
)

# 2. Función de procesamiento (Misma lógica)
procesar_grupo <- function(df, grupo_label, col_educ, niveles_educ, pop_list) {
  
  # A. Agrupados
  df_agrupado <- df %>%
    filter(tipo_causa_con_externas %in% c("Causas naturales", "Causas externas (total)")) %>%
    count(!!sym(col_educ), tipo_causa_con_externas) %>%
    rename(categoria = tipo_causa_con_externas)
  
  # B. Específicos
  df_especifico <- df %>%
    filter(!is.na(causa_externa_especifica)) %>%
    count(!!sym(col_educ), causa_externa_especifica) %>%
    mutate(
      categoria = case_when(

        causa_externa_especifica == "Accidentes de transporte" ~ "   ├ Accidentes tránsito",
        causa_externa_especifica == "Homicidios" ~ "   ├ Homicidios",
        causa_externa_especifica == "Suicidios" ~  "   ├ Suicidios",
        causa_externa_especifica == "Otras externas" ~ "   └ Otras externas",
      )
    ) %>%
    select(-causa_externa_especifica)
  
  # C. Combinar
  bind_rows(df_agrupado, df_especifico) %>%
    mutate(
      grupo = grupo_label,
      nivel_educ = !!sym(col_educ),
      poblacion = case_when(
        nivel_educ == niveles_educ[1] ~ pop_list[[1]], # Nivel Alto (según vector input)
        nivel_educ == niveles_educ[2] ~ pop_list[[2]]  # Nivel Bajo
      ),
      tasa_1000 = n / poblacion * 1000,
      nivel_label = nivel_educ,
      tipo_nivel = case_when(
        nivel_educ == niveles_educ[1] ~ "Alto", 
        TRUE ~ "Bajo"
      )
    )
}

# 3. Procesar datos
# Definimos niveles como [Alto, Bajo] para el cálculo interno de ratios
df_jovenes_hier <- procesar_grupo(
  df = defunciones %>% filter(grupo_edad == "20-29" & !is.na(nivel_educativo_jovenes)),
  grupo_label = "Jóvenes (20-29 años)",
  col_educ = "nivel_educativo_jovenes",
  niveles_educ = c("Secundaria completa", "Secundaria incompleta"), 
  pop_list = c(poblacion_educacion_jovenes$secundaria_completa, poblacion_educacion_jovenes$secundaria_incompleta)
)

df_adultos_hier <- procesar_grupo(
  df = defunciones %>% filter(grupo_edad %in% c("30-64", "65+") & !is.na(nivel_educativo_adultos)),
  grupo_label = "Adultos (30+ años)",
  col_educ = "nivel_educativo_adultos",
  niveles_educ = c("Superior", "No superior"),
  pop_list = c(poblacion_educacion_adultos$superior, poblacion_educacion_adultos$no_superior)
)

# 4. Unir y Configurar Orden
df_total_hier <- bind_rows(df_jovenes_hier, df_adultos_hier) %>%
  filter(categoria %in% orden_jerarquico)

df_total_hier$categoria <- factor(df_total_hier$categoria, levels = rev(orden_jerarquico))
df_total_hier$grupo <- factor(df_total_hier$grupo, levels = c("Jóvenes (20-29 años)", "Adultos (30+ años)"))

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Cambio clave: definir el orden de la leyenda y barras ----
# Solicitado: Sec. Incompleta, Sec. Completa, No Superior, Superior
# Esto pone "Bajo nivel" primero y "Alto nivel" segundo.
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
orden_leyenda <- c("Secundaria incompleta", "Secundaria completa", "No superior", "Superior")
df_total_hier$nivel_label <- factor(df_total_hier$nivel_label, levels = orden_leyenda)

# 5. Calcular Ratios y Coordenadas
# Ajustar lógica de coordenadas X para coincidir con el nuevo orden de las barras
# Como "Bajo" ahora es el primer factor, se grafica a la izquierda (o arriba en coord_flip si dodge)
# "Alto" es el segundo factor.

GAP_BARRA_BRACKET <- 0.15   
ANCHO_TICK_BRACKET <- 0.10  
GAP_BRACKET_LABEL <- 0.65 

ratios_hier <- df_total_hier %>%
  select(grupo, categoria, tipo_nivel, tasa_1000) %>%
  pivot_wider(names_from = tipo_nivel, values_from = tasa_1000) %>%
  mutate(
    ratio = Bajo / Alto,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Alto, Bajo),
    
    x_num = as.numeric(factor(categoria, levels = rev(orden_jerarquico))),
    
    # AJUSTE DE COORDENADAS PARA BRACKETS
    # Dado que cambiamos el orden de los factores, ggplot pone:
    # 1. Secundaria incompleta (Bajo) en x - 0.175
    # 2. Secundaria completa (Alto) en x + 0.175
    # Ajustamos las coordenadas x_alto y x_bajo para que los brackets apunten bien
    x_bajo = x_num - 0.2, # "Bajo" ahora está 'primero' (izquierda/arriba)
    x_alto = x_num + 0.2, # "Alto" ahora está 'segundo' (derecha/abajo)
    
    # Coordenadas Y (Longitud)
    y_inicio_tick = y_max + GAP_BARRA_BRACKET,
    y_bracket = y_inicio_tick + ANCHO_TICK_BRACKET,
    y_label = y_bracket + GAP_BRACKET_LABEL
  )

# 6. Graficar
g_mort_causas_combinado <- ggplot(df_total_hier, aes(x = categoria, y = tasa_1000, fill = nivel_label)) +
  geom_col(position = "dodge", width = 0.7) +
  
  # Brackets y Etiquetas
  geom_segment(data = ratios_hier,
               aes(x = x_alto, xend = x_bajo, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_hier,
               aes(x = x_alto, xend = x_alto, y = y_bracket, yend = y_inicio_tick),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_hier,
               aes(x = x_bajo, xend = x_bajo, y = y_bracket, yend = y_inicio_tick),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_hier,
             aes(x = x_num, y = y_label, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20",     
             size = 5, fontface = "bold", label.padding = unit(0.2, "lines"), label.size = 0.25) +  
  
  coord_flip() +
  facet_wrap(~grupo) + 
  
  # Colores (Mapeo por nombre, el orden en 'values' no altera la leyenda, solo los niveles del factor arriba)
  scale_fill_manual(values = c(
    "Secundaria completa" = "#1ABC9C",   # Turquesa
    "Secundaria incompleta" = "#F39C12", # Naranja
    "Superior" = "#2980B9",         # Azul Fuerte
    "No superior" = "#C0392B"       # Rojo Fuerte
  )) +
  
  scale_y_continuous(expand = c(0, 0), limits = c(0, 11.5),
                    breaks = seq(0, 11.5, by = 2),
                    labels = function(x) format(x, nsmall = 0)) +
  
  labs(
    
    subtitle = "",
    x = NULL,
    y = "Tasa por 1000 habitantes",
    fill = NULL # Título de la leyenda
  ) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 16, face = "bold"),
    strip.background = element_rect(fill = "gray90"),
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.text = element_text(size = 19),
    axis.title = element_text(size = 15, face = "bold"),  
    axis.text.y = element_text( hjust = 0),  # Left-align + monospace 
    legend.text = element_text(size = 18)
   )

g_mort_causas_combinado

ggsave(file.path(output_dir, "mortalidad_combinada_causas.png"), 
       g_mort_causas_combinado, width = 14, height = 9, dpi = 300, bg = "white")

cat("Gráfico guardado: mortalidad_combinada_causas.png\n")

# Resumen ----
cat("\n--- Resumen de mortalidad por educación ---\n")
cat("Jóvenes:\n")
print(tasas_jovenes_educ)
cat("\nAdultos:\n")
print(tasas_adultos_educ)

cat("\n========== ANÁLISIS DE EDUCACIÓN FINALIZADO ==========\n")

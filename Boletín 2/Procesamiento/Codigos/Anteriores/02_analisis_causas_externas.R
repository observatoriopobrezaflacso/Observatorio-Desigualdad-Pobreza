# =============================================================================
# Análisis de Causas Externas y Suicidios por Variables Socioeconómicas
# Boletín 2 - Observatorio de Políticas Públicas
# Causas externas y suicidios por educación y pobreza
# =============================================================================

cat("\n========== ANÁLISIS DE CAUSAS EXTERNAS Y SUICIDIOS ==========\n")

# Clasificación de causas externas (si no existe ya) ----
if (!"causa_externa_especifica" %in% names(defunciones)) {
  defunciones <- defunciones %>%
    mutate(
      causa_externa_especifica = case_when(
        grepl("096", as.character(causa103)) ~ "Accidentes de transporte",
        grepl("097", as.character(causa103)) ~ "Caídas",
        grepl("098", as.character(causa103)) ~ "Ahogamiento",
        grepl("099", as.character(causa103)) ~ "Exposición a fuego/humo",
        grepl("100", as.character(causa103)) ~ "Envenenamiento accidental",
        grepl("101", as.character(causa103)) ~ "Lesiones autoinfligidas",
        grepl("102", as.character(causa103)) ~ "Agresiones (homicidios)",
        grepl("103", as.character(causa103)) ~ "Otras causas externas",
        TRUE ~ NA_character_
      )
    )
}

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

# Crear defunciones_pobreza con las clasificaciones de causas externas
defunciones <- defunciones %>%
  mutate(cod_parroquia = sprintf("%06d", as.numeric(as.character(parr_fall))))

defunciones_pobreza <- defunciones %>%
  left_join(df_parroquias_pobreza, by = "cod_parroquia")

externas_pobreza <- defunciones_pobreza %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_pobreza))

externas_pobreza$nivel_pobreza <- factor(
  externas_pobreza$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

cat("Muertes por causas externas con datos de pobreza:", nrow(externas_pobreza), "\n")

# Gráfico: Tasa de muertes por causas externas según pobreza ----
tasas_externas_pobreza <- externas_pobreza %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_100000 = n / poblacion * 100000)

# Calcular ratio para externas por pobreza
ratio_ext_pobreza <- tasas_externas_pobreza %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, tasa_100000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_100000) %>%
  mutate(ratio = `Mayor pobreza` / `Menor pobreza`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_ext_pobreza <- ggplot(tasas_externas_pobreza, aes(x = nivel_pobreza, y = tasa_100000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  # Bracket y ratio (posicionado encima del texto)
  annotate("segment", x = 1, xend = 3,
           y = max(tasas_externas_pobreza$tasa_100000) * 1.28,
           yend = max(tasas_externas_pobreza$tasa_100000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_externas_pobreza$tasa_100000) * 1.28,
           yend = max(tasas_externas_pobreza$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(tasas_externas_pobreza$tasa_100000) * 1.28,
           yend = max(tasas_externas_pobreza$tasa_100000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(tasas_externas_pobreza$tasa_100000) * 1.33,
                 label = ratio_ext_pobreza$ratio_label),
             fill = "white", color = "gray20", size = 4, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de muertes por causas externas por nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "externas_pobreza.png"), g_ext_pobreza, width = 9, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: externas_pobreza.png\n")

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
  # Bracket y ratio (posicionado encima del texto)
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

# Gráfico: Suicidios en jóvenes por método y educación ----
graf_suic_jov_met_data <- jovenes_suicidios %>%
  count(nivel_educativo_jovenes, metodo_suicidio) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 3)

orden_metodos <- jovenes_suicidios %>%
  count(metodo_suicidio) %>%
  arrange(desc(n)) %>%
  pull(metodo_suicidio)

graf_suic_jov_met_data$metodo_suicidio <- factor(graf_suic_jov_met_data$metodo_suicidio, levels = rev(orden_metodos))

# Calcular ratios para suicidios jóvenes por método
ratios_suic_jov_met <- graf_suic_jov_met_data %>%
  select(metodo_suicidio, nivel_educativo_jovenes, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_jovenes, values_from = tasa_100000) %>%
  mutate(
    ratio = `Secundaria incompleta` / `Secundaria completa`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Secundaria completa`, `Secundaria incompleta`, na.rm = TRUE),
    x_num = as.numeric(metodo_suicidio),
    x_comp = x_num - 0.175,
    x_incomp = x_num + 0.175,
    y_pointer = y_max + max(graf_suic_jov_met_data$tasa_100000) * 0.02,
    y_bracket = y_pointer + max(graf_suic_jov_met_data$tasa_100000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_suic_jov_met <- ggplot(graf_suic_jov_met_data, aes(x = metodo_suicidio, y = tasa_100000,
                                fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_suic_jov_met,
               aes(x = x_comp, xend = x_incomp, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_jov_met,
               aes(x = x_comp, xend = x_comp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_jov_met,
               aes(x = x_incomp, xend = x_incomp, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_suic_jov_met,
             aes(x = x_num, y = y_bracket + max(graf_suic_jov_met_data$tasa_100000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Suicidios en jóvenes (20-29) por método y nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Sec. incompleta / Sec. completa)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "suicidios_jovenes_metodo_educacion.png"), g_suic_jov_met, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_jovenes_metodo_educacion.png\n")

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
  # Bracket y ratio (posicionado encima del texto)
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

# Gráfico: Suicidios en adultos por método y educación ----
graf_suic_adult_met_data <- adultos_suicidios %>%
  count(nivel_educativo_adultos, metodo_suicidio) %>%
  filter(!is.na(metodo_suicidio) & metodo_suicidio != "NA" & n >= 5) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  )

graf_suic_adult_met_data$metodo_suicidio <- factor(graf_suic_adult_met_data$metodo_suicidio, levels = rev(orden_metodos))

# Calcular ratios para suicidios adultos por método
ratios_suic_adult_met <- graf_suic_adult_met_data %>%
  select(metodo_suicidio, nivel_educativo_adultos, tasa_100000) %>%
  pivot_wider(names_from = nivel_educativo_adultos, values_from = tasa_100000) %>%
  mutate(
    ratio = `No universitario` / Universitario,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(Universitario, `No universitario`, na.rm = TRUE),
    x_num = as.numeric(metodo_suicidio),
    x_univ = x_num - 0.175,
    x_no_univ = x_num + 0.175,
    y_pointer = y_max,
    y_bracket = y_max + max(graf_suic_adult_met_data$tasa_100000) * 0.03
  ) %>%
  filter(!is.na(ratio) & is.finite(ratio))

g_suic_adult_met <- ggplot(graf_suic_adult_met_data, aes(x = metodo_suicidio, y = tasa_100000,
                                fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_suic_adult_met,
               aes(x = x_univ, xend = x_no_univ, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_adult_met,
               aes(x = x_univ, xend = x_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_adult_met,
               aes(x = x_no_univ, xend = x_no_univ, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_suic_adult_met,
             aes(x = x_num, y = y_bracket + max(graf_suic_adult_met_data$tasa_100000) * 0.02, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Suicidios en adultos (30+) por método y nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = No universitario / Universitario)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "suicidios_adultos_metodo_educacion.png"), g_suic_adult_met, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_adultos_metodo_educacion.png\n")

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
  # Bracket y ratio (posicionado encima del texto)
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

# Gráfico: Suicidios por método y nivel de pobreza ----
graf_suic_met_pob_data <- suicidios_pobreza %>%
  count(nivel_pobreza, metodo_suicidio) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_100000 = n / poblacion * 100000)

orden_metodos_pob <- suicidios_pobreza %>%
  count(metodo_suicidio) %>%
  arrange(desc(n)) %>%
  pull(metodo_suicidio)

graf_suic_met_pob_data$metodo_suicidio <- factor(graf_suic_met_pob_data$metodo_suicidio, levels = rev(orden_metodos_pob))

# Calcular ratios para suicidios método por pobreza
ratios_suic_met_pob <- graf_suic_met_pob_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(metodo_suicidio, nivel_pobreza, tasa_100000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_100000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_num = as.numeric(metodo_suicidio),
    x_mayor = x_num - 0.233,
    x_menor = x_num + 0.233,
    y_pointer = y_max + max(graf_suic_met_pob_data$tasa_100000) * 0.02,
    y_bracket = y_pointer + max(graf_suic_met_pob_data$tasa_100000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_suic_met_pob <- ggplot(graf_suic_met_pob_data, aes(x = metodo_suicidio, y = tasa_100000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_suic_met_pob,
               aes(x = x_mayor, xend = x_menor, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_met_pob,
               aes(x = x_mayor, xend = x_mayor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_suic_met_pob,
               aes(x = x_menor, xend = x_menor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_suic_met_pob,
             aes(x = x_num, y = y_bracket + max(graf_suic_met_pob_data$tasa_100000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Suicidios por método y nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "suicidios_metodo_pobreza.png"), g_suic_met_pob, width = 11, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_metodo_pobreza.png\n")

# Gráfico: Comparación suicidios y homicidios por pobreza ----
violentas_comp <- externas_pobreza %>%
  filter(causa_externa_especifica %in% c("Lesiones autoinfligidas", "Agresiones (homicidios)")) %>%
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
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_suic = ifelse(causa_externa_especifica == "Lesiones autoinfligidas", 1 - 0.15, 1 + 0.15),
    x_hom = ifelse(causa_externa_especifica == "Agresiones (homicidios)", 1 - 0.15, 1 + 0.15)
  ) %>%
  filter(!is.na(ratio))

# Preparar datos para anotaciones de ratio (uno por cada tipo de muerte)
ratio_suic <- ratios_violentas %>% filter(causa_externa_especifica == "Lesiones autoinfligidas")
ratio_hom <- ratios_violentas %>% filter(causa_externa_especifica == "Agresiones (homicidios)")

g_suic_hom_pob <- ggplot(violentas_comp, aes(x = nivel_pobreza, y = tasa_100000, fill = causa_externa_especifica)) +
  geom_col(position = "dodge", width = 0.6) +
  geom_text(aes(label = round(tasa_100000, 1)),
            position = position_dodge(width = 0.6), vjust = -0.3, size = 3.5) +
  # Bracket suicidios (conecta posiciones 1 y 3 para suicidios)
  annotate("segment", x = 1 - 0.15, xend = 3 - 0.15,
           y = max(violentas_comp$tasa_100000) * 1.15,
           yend = max(violentas_comp$tasa_100000) * 1.15,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1 - 0.15, xend = 1 - 0.15,
           y = max(violentas_comp$tasa_100000) * 1.15,
           yend = max(violentas_comp$tasa_100000) * 1.12,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3 - 0.15, xend = 3 - 0.15,
           y = max(violentas_comp$tasa_100000) * 1.15,
           yend = max(violentas_comp$tasa_100000) * 1.12,
           color = "gray40", linewidth = 0.5) +
  annotate("label", x = 2 - 0.15, y = max(violentas_comp$tasa_100000) * 1.20,
           label = ratio_suic$ratio_label,
           fill = "white", color = "gray20", size = 3.5, fontface = "bold",
           label.padding = unit(0.15, "lines")) +
  # Bracket homicidios (conecta posiciones 1 y 3 para homicidios)
  annotate("segment", x = 1 + 0.15, xend = 3 + 0.15,
           y = max(violentas_comp$tasa_100000) * 1.30,
           yend = max(violentas_comp$tasa_100000) * 1.30,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1 + 0.15, xend = 1 + 0.15,
           y = max(violentas_comp$tasa_100000) * 1.30,
           yend = max(violentas_comp$tasa_100000) * 1.27,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3 + 0.15, xend = 3 + 0.15,
           y = max(violentas_comp$tasa_100000) * 1.30,
           yend = max(violentas_comp$tasa_100000) * 1.27,
           color = "gray40", linewidth = 0.5) +
  annotate("label", x = 2 + 0.15, y = max(violentas_comp$tasa_100000) * 1.35,
           label = ratio_hom$ratio_label,
           fill = "white", color = "gray20", size = 3.5, fontface = "bold",
           label.padding = unit(0.15, "lines")) +
  scale_fill_manual(values = c("Lesiones autoinfligidas" = "#E74C3C",
                               "Agresiones (homicidios)" = "#8E44AD")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Suicidios y homicidios por nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 100,000 habitantes",
    fill = "Tipo de muerte"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "suicidios_homicidios_pobreza.png"), g_suic_hom_pob, width = 10, height = 7, dpi = 300, bg = "white")
cat("Gráfico guardado: suicidios_homicidios_pobreza.png\n")

# Resumen ----
cat("\n--- Resumen de causas externas por pobreza ---\n")
print(tasas_externas_pobreza)

cat("\n--- Resumen de suicidios por pobreza ---\n")
print(tasas_suicidio_pob)

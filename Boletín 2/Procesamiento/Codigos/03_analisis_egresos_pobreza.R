# =============================================================================
# Análisis de Egresos Hospitalarios por Nivel de Pobreza
# Boletín 2 - Observatorio de Políticas Públicas
# Egresos hospitalarios por pobreza
# =============================================================================

cat("\n========== ANÁLISIS DE EGRESOS HOSPITALARIOS ==========\n")

# Carga y transformación de datos ----
egresos <- readRDS(file.path(base_dir, "Procesamiento/Bases/Hospitalarias/egresos_hospitalarios_2024.rds"))

egresos <- egresos %>%
  mutate(
    capitulo_cie10 = case_when(
      grepl("I Ciertas enfermedades infecciosas", as.character(as_factor(cap221rx))) ~ "Infecciosas",
      grepl("II Neoplasias", as.character(as_factor(cap221rx))) ~ "Tumores",
      grepl("III Enfermedades de la sangre", as.character(as_factor(cap221rx))) ~ "Sangre",
      grepl("IV Enfermedades endocrinas", as.character(as_factor(cap221rx))) ~ "Endocrinas",
      grepl("V Trastornos mentales", as.character(as_factor(cap221rx))) ~ "Salud mental",
      grepl("VI Enfermedades del sistema nervioso", as.character(as_factor(cap221rx))) ~ "Sistema nervioso",
      grepl("VII Enfermedades del ojo", as.character(as_factor(cap221rx))) ~ "Ojos",
      grepl("VIII Enfermedades del oído", as.character(as_factor(cap221rx))) ~ "Oído",
      grepl("IX Enfermedades del sistema circulatorio", as.character(as_factor(cap221rx))) ~ "Circulatorias",
      grepl("X Enfermedades del sistema respiratorio", as.character(as_factor(cap221rx))) ~ "Respiratorias",
      grepl("XI Enfermedades del sistema digestivo", as.character(as_factor(cap221rx))) ~ "Digestivas",
      grepl("XII Enfermedades de la piel", as.character(as_factor(cap221rx))) ~ "Piel",
      grepl("XIII Enfermedades del sistema osteomuscular", as.character(as_factor(cap221rx))) ~ "Osteomuscular",
      grepl("XIV Enfermedades del aparato genitourinario", as.character(as_factor(cap221rx))) ~ "Genitales/Urinarias",
      grepl("XV Embarazo", as.character(as_factor(cap221rx))) ~ "Embarazo/Parto",
      grepl("XVI Ciertas afecciones originadas en el periodo perinatal", as.character(as_factor(cap221rx))) ~ "Perinatales",
      grepl("XVII Malformaciones congénitas", as.character(as_factor(cap221rx))) ~ "Congénitas",
      grepl("XVIII Síntomas", as.character(as_factor(cap221rx))) ~ "Síntomas/Signos",
      grepl("XIX Traumatismos", as.character(as_factor(cap221rx))) ~ "Traumatismos",
      grepl("XXI Factores", as.character(as_factor(cap221rx))) ~ "Factores de salud",
      grepl("COVID", as.character(as_factor(cap221rx))) ~ "COVID-19",
      TRUE ~ "Otros"
    )
  )

cat("Total de egresos:", nrow(egresos), "\n")

# =============================================================================
# EGRESOS HOSPITALARIOS POR NIVEL DE POBREZA
# =============================================================================

cat("\n--- Análisis por nivel de pobreza ---\n")

# Preparar egresos con datos de pobreza ----
egresos <- egresos %>%
  mutate(
    cod_parroquia = sprintf("%06d", as.numeric(as.character(parr_res)))
  )

egresos_pobreza <- egresos %>%
  left_join(df_parroquias_pobreza, by = "cod_parroquia")

cat("Egresos con datos de pobreza:", sum(!is.na(egresos_pobreza$nivel_pobreza)), 
    "de", nrow(egresos_pobreza), "\n")

egresos_pob_analisis <- egresos_pobreza %>%
  filter(!is.na(nivel_pobreza))

egresos_pob_analisis$nivel_pobreza <- factor(
  egresos_pob_analisis$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

# Gráfico: Tasa de egresos por nivel de pobreza ----
tasas_egresos_pob <- egresos_pob_analisis %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

# Calcular ratio para egresos por pobreza
ratio_egresos_pob <- tasas_egresos_pob %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, tasa_1000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000) %>%
  mutate(ratio = `Mayor pobreza` / `Menor pobreza`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_egresos_pob <- ggplot(tasas_egresos_pob, aes(x = nivel_pobreza, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 5.5) +
  # Bracket y ratio (posicionado encima del texto)
  annotate("segment", x = 1, xend = 3,
           y = max(tasas_egresos_pob$tasa_1000) * 1.28,
           yend = max(tasas_egresos_pob$tasa_1000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_egresos_pob$tasa_1000) * 1.28,
           yend = max(tasas_egresos_pob$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(tasas_egresos_pob$tasa_1000) * 1.28,
           yend = max(tasas_egresos_pob$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(tasas_egresos_pob$tasa_1000) * 1.33,
                 label = ratio_egresos_pob$ratio_label),
             fill = "white", color = "gray20", size = 5, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(
    title = "Tasa de egresos hospitalarios por nivel de pobreza de la parroquia",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "egresos_pobreza.png"), g_egresos_pob, width = 9, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: egresos_pobreza.png\n")

# Gráfico: Top 10 causas de egreso por nivel de pobreza ----
top10_pob <- egresos_pob_analisis %>%
  filter(capitulo_cie10 != "Otros") %>%
  count(capitulo_cie10) %>%
  arrange(desc(n)) %>%
  slice(1:10) %>%
  pull(capitulo_cie10)

graf_egresos_causas_data <- egresos_pob_analisis %>%
  filter(capitulo_cie10 %in% top10_pob) %>%
  count(nivel_pobreza, capitulo_cie10) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

graf_egresos_causas_data$capitulo_cie10 <- factor(graf_egresos_causas_data$capitulo_cie10, levels = rev(top10_pob))

# Calcular ratios para egresos causas por pobreza
ratios_egresos_causas <- graf_egresos_causas_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(capitulo_cie10, nivel_pobreza, tasa_1000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_num = as.numeric(capitulo_cie10),
    x_mayor = x_num - 0.233,
    x_menor = x_num + 0.233,
    y_pointer = y_max + max(graf_egresos_causas_data$tasa_1000) * 0.02,
    y_bracket = y_pointer + max(graf_egresos_causas_data$tasa_1000) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_egresos_causas <- ggplot(graf_egresos_causas_data, aes(x = capitulo_cie10, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_egresos_causas,
               aes(x = x_mayor, xend = x_menor, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_egresos_causas,
               aes(x = x_mayor, xend = x_mayor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_egresos_causas,
               aes(x = x_menor, xend = x_menor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_egresos_causas,
             aes(x = x_num, y = y_bracket + max(graf_egresos_causas_data$tasa_1000) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Tasa de egresos por causa y nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "egresos_causas_pobreza.png"), g_egresos_causas, width = 12, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: egresos_causas_pobreza.png\n")

# Gráfico: Días de estancia por nivel de pobreza y causa ----
graf_dias_causa_data <- egresos_pob_analisis %>%
  filter(capitulo_cie10 %in% top10_pob) %>%
  group_by(nivel_pobreza, capitulo_cie10) %>%
  summarise(dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE), n = n(), .groups = "drop")

graf_dias_causa_data$capitulo_cie10 <- factor(graf_dias_causa_data$capitulo_cie10, levels = rev(top10_pob))

# Calcular ratios para días de estancia por causa
ratios_dias_causa <- graf_dias_causa_data %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(capitulo_cie10, nivel_pobreza, dias_promedio) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = dias_promedio) %>%
  mutate(
    ratio = `Mayor pobreza` / `Menor pobreza`,
    ratio_label = paste0(round(ratio, 1), "x"),
    y_max = pmax(`Mayor pobreza`, `Menor pobreza`, na.rm = TRUE),
    x_num = as.numeric(capitulo_cie10),
    x_mayor = x_num - 0.233,
    x_menor = x_num + 0.233,
    y_pointer = y_max + max(graf_dias_causa_data$dias_promedio) * 0.02,
    y_bracket = y_pointer + max(graf_dias_causa_data$dias_promedio) * 0.02
  ) %>%
  filter(!is.na(ratio))

g_dias_causa <- ggplot(graf_dias_causa_data, aes(x = capitulo_cie10, y = dias_promedio, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  # Brackets y ratios
  geom_segment(data = ratios_dias_causa,
               aes(x = x_mayor, xend = x_menor, y = y_bracket, yend = y_bracket),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_dias_causa,
               aes(x = x_mayor, xend = x_mayor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_segment(data = ratios_dias_causa,
               aes(x = x_menor, xend = x_menor, y = y_bracket, yend = y_pointer),
               inherit.aes = FALSE, color = "gray40", linewidth = 0.5) +
  geom_label(data = ratios_dias_causa,
             aes(x = x_num, y = y_bracket + max(graf_dias_causa_data$dias_promedio) * 0.06, label = ratio_label),
             inherit.aes = FALSE, fill = "white", color = "gray20", size = 7, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  coord_flip() +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Días de estancia hospitalaria por nivel de pobreza",
    subtitle = "Ecuador 2024 - Promedio de días por causa de egreso (ratio = Mayor pobreza / Menor pobreza)",
    x = NULL,
    y = "Días de estancia promedio",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "egresos_dias_causa_pobreza.png"), g_dias_causa, width = 11, height = 8, dpi = 300, bg = "white")
cat("Gráfico guardado: egresos_dias_causa_pobreza.png\n")

# Gráfico: Días de estancia por nivel de pobreza (total) ----
dias_pob <- egresos_pob_analisis %>%
  group_by(nivel_pobreza) %>%
  summarise(
    dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# Calcular ratio para días de estancia total
ratio_dias_pob <- dias_pob %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, dias_promedio) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = dias_promedio) %>%
  mutate(ratio = `Mayor pobreza` / `Menor pobreza`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_dias_pob <- ggplot(dias_pob, aes(x = nivel_pobreza, y = dias_promedio, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(dias_promedio, 2), " días\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 5.5) +
  # Bracket y ratio
  annotate("segment", x = 1, xend = 3,
           y = max(dias_pob$dias_promedio) * 1.15,
           yend = max(dias_pob$dias_promedio) * 1.15,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(dias_pob$dias_promedio) * 1.15,
           yend = max(dias_pob$dias_promedio) * 1.12,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(dias_pob$dias_promedio) * 1.15,
           yend = max(dias_pob$dias_promedio) * 1.12,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(dias_pob$dias_promedio) * 1.20,
                 label = ratio_dias_pob$ratio_label),
             fill = "white", color = "gray20", size = 5, fontface = "bold",
             label.padding = unit(0.2, "lines")) +
  scale_fill_manual(values = colores_pobreza) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  labs(
    title = "Días de estancia hospitalaria promedio por nivel de pobreza",
    subtitle = "Ecuador 2024 - Promedio general (ratio = Mayor pobreza / Menor pobreza)",
    x = "Nivel de pobreza (NBI)",
    y = "Días de estancia promedio"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "egresos_dias_pobreza.png"), g_dias_pob, width = 9, height = 6, dpi = 300, bg = "white")
cat("Gráfico guardado: egresos_dias_pobreza.png\n")

# Resumen ----
cat("\n--- Resumen de egresos por pobreza ---\n")
print(tasas_egresos_pob)

cat("\n--- Top 5 causas por nivel de pobreza ---\n")
for (nivel in levels(egresos_pob_analisis$nivel_pobreza)) {
  cat("\n", nivel, ":\n")
  top5 <- egresos_pob_analisis %>%
    filter(nivel_pobreza == nivel) %>%
    count(capitulo_cie10) %>%
    left_join(poblacion_pobreza %>% filter(nivel_pobreza == nivel), by = character()) %>%
    mutate(tasa_1000 = n / poblacion * 1000) %>%
    arrange(desc(n)) %>%
    head(5) %>%
    select(capitulo_cie10, n, tasa_1000)
  print(top5)
}

cat("\n--- Días de estancia por pobreza ---\n")
print(dias_pob)





egresos <- egresos %>%
  mutate(
    tipo_establecimiento = case_when(
      as.numeric(entidad) == 1 ~ "MSP (Público)",
      as.numeric(entidad) == 6 ~ "IESS",
      as.numeric(entidad) %in% c(17, 18) ~ "Privados",
      as.numeric(entidad) %in% c(2, 3, 4, 5, 9, 10, 11, 12) ~ "Otros públicos",
      as.numeric(entidad) %in% c(13, 14, 15, 16) ~ "Otros sin fines de lucro",
      TRUE ~ "Otros"
    ),
    capitulo_cie10 = case_when(
      grepl("I Ciertas enfermedades infecciosas", as.character(as_factor(cap221rx))) ~ "Infecciosas",
      grepl("II Neoplasias", as.character(as_factor(cap221rx))) ~ "Tumores",
      grepl("III Enfermedades de la sangre", as.character(as_factor(cap221rx))) ~ "Sangre",
      grepl("IV Enfermedades endocrinas", as.character(as_factor(cap221rx))) ~ "Endocrinas",
      grepl("V Trastornos mentales", as.character(as_factor(cap221rx))) ~ "Salud mental",
      grepl("VI Enfermedades del sistema nervioso", as.character(as_factor(cap221rx))) ~ "Sistema nervioso",
      grepl("VII Enfermedades del ojo", as.character(as_factor(cap221rx))) ~ "Ojos",
      grepl("VIII Enfermedades del oído", as.character(as_factor(cap221rx))) ~ "Oído",
      grepl("IX Enfermedades del sistema circulatorio", as.character(as_factor(cap221rx))) ~ "Circulatorias",
      grepl("X Enfermedades del sistema respiratorio", as.character(as_factor(cap221rx))) ~ "Respiratorias",
      grepl("XI Enfermedades del sistema digestivo", as.character(as_factor(cap221rx))) ~ "Digestivas",
      grepl("XII Enfermedades de la piel", as.character(as_factor(cap221rx))) ~ "Piel",
      grepl("XIII Enfermedades del sistema osteomuscular", as.character(as_factor(cap221rx))) ~ "Osteomuscular",
      grepl("XIV Enfermedades del aparato genitourinario", as.character(as_factor(cap221rx))) ~ "Genitales/Urinarias",
      grepl("XV Embarazo", as.character(as_factor(cap221rx))) ~ "Embarazo/Parto",
      grepl("XVI Ciertas afecciones originadas en el periodo perinatal", as.character(as_factor(cap221rx))) ~ "Perinatales",
      grepl("XVII Malformaciones congénitas", as.character(as_factor(cap221rx))) ~ "Congénitas",
      grepl("XVIII Síntomas", as.character(as_factor(cap221rx))) ~ "Síntomas/Signos",
      grepl("XIX Traumatismos", as.character(as_factor(cap221rx))) ~ "Traumatismos",
      grepl("XXI Factores", as.character(as_factor(cap221rx))) ~ "Factores de salud",
      grepl("COVID", as.character(as_factor(cap221rx))) ~ "COVID-19",
      TRUE ~ "Otros"
    )
  )

# Filtrado de establecimientos principales ----
egresos_3grupos <- egresos %>%
  filter(tipo_establecimiento %in% c("MSP (Público)", "IESS", "Privados"))

cat("Registros en 3 grupos principales:", nrow(egresos_3grupos), "\n")

# Gráfico 12: Tasa de egresos por tipo de establecimiento ----
graf12_egresos <- egresos_3grupos %>%
  count(tipo_establecimiento) %>%
  mutate(tasa_1000 = n / poblacion_total * 1000)

g12_egresos <- ggplot(graf12_egresos, aes(x = reorder(tipo_establecimiento, tasa_1000), y = tasa_1000, fill = tipo_establecimiento)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            hjust = -0.1, size = 5) +
  coord_flip() +
  scale_fill_manual(values = c("MSP (Público)" = "#2E86AB", "IESS" = "#F18F01", "Privados" = "#27AE60")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.3))) +
  labs(
    title = "Tasa de egresos hospitalarios por tipo de establecimiento",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "tasas_egresos_establecimiento.png"), g12_egresos, width = 10, height = 5, dpi = 300)
cat("Gráfico 12 guardado: 12_tasas_egresos_establecimiento.png\n")

# Gráfico 13: Tasas de egreso por causa y establecimiento ----
top10_causas <- egresos_3grupos %>%
  filter(capitulo_cie10 != "Otros") %>%
  count(capitulo_cie10) %>%
  arrange(desc(n)) %>%
  slice(1:10) %>%
  pull(capitulo_cie10)

graf13_egresos <- egresos_3grupos %>%
  filter(capitulo_cie10 %in% top10_causas) %>%
  count(tipo_establecimiento, capitulo_cie10) %>%
  mutate(tasa_1000 = n / poblacion_total * 1000)

graf13_egresos$capitulo_cie10 <- factor(graf13_egresos$capitulo_cie10, levels = rev(top10_causas))

g13_egresos <- ggplot(graf13_egresos, aes(x = capitulo_cie10, y = tasa_1000, fill = tipo_establecimiento)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("MSP (Público)" = "#2E86AB", "IESS" = "#F18F01", "Privados" = "#C73E1D")) +
  labs(
    title = "Tasa de egresos por causa y tipo de establecimiento",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Tipo de establecimiento"
  ) +
  theme(legend.position = "bottom") +
  theme_causas

ggsave(file.path(output_dir, "egresos_causas_establecimiento.png"), g13_egresos, width = 11, height = 8, dpi = 300)
cat("Gráfico guardado: egresos_causas_establecimiento.png\n")


# Gráfico 16: Días de estancia promedio por establecimiento ----
dias_tipo <- egresos_3grupos %>%
  group_by(tipo_establecimiento) %>%
  summarise(
    dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

dias_tipo$tipo_establecimiento <- factor(dias_tipo$tipo_establecimiento,
                                         levels = c("MSP (Público)", "IESS", "Privados"))

g16_egresos <- ggplot(dias_tipo, aes(x = tipo_establecimiento, y = dias_promedio, fill = tipo_establecimiento)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(dias_promedio, 2), " días\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 5.5) +
  scale_fill_manual(values = c("MSP (Público)" = "#2E86AB", "IESS" = "#F18F01", "Privados" = "#27AE60")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Días de estancia promedio por tipo de establecimiento",
    subtitle = "Ecuador 2024 - Promedio general sin desagregar por causa",
    x = NULL,
    y = "Días de estancia promedio"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "egresos_estancia_tipo_total.png"), g16_egresos, width = 9, height = 6, dpi = 300)
cat("Gráfico guardado: egresos_estancia_tipo_total.png\n")

# Resumen ----
cat("\n--- Resumen de egresos por tipo de establecimiento ---\n")
print(egresos_3grupos %>%
        group_by(tipo_establecimiento) %>%
        summarise(
          n_egresos = n(),
          tasa_1000 = n() / poblacion_total * 1000,
          dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE)
        ))



tasas_egresos_pob <- egresos_pob_analisis %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

tasas_egresos_pob <- egresos_pob_analisis %>%
  group_by(nivel_pobreza, con_egrpa) %>%
  summarize(n = n()) %>% 
  mutate(per = n/sum(n))


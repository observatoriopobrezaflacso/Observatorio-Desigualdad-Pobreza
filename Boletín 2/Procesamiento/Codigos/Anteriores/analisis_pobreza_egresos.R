# =============================================================================
# Análisis de Enfermedades por Nivel de Pobreza de las Parroquias
# Observatorio de Políticas Públicas - Boletín 2
# VERSIÓN ACTUALIZADA: Tasas por 1,000 habitantes
# =============================================================================

# Librerías ----
library(haven)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(forcats)
library(stringr)

theme_set(theme_minimal(base_size = 12) +
            theme(
              plot.title = element_text(face = "bold", size = 14),
              plot.subtitle = element_text(color = "gray40"),
              legend.position = "bottom",
              panel.grid.minor = element_blank()
            ))

base_dir <- "/Users/vero/Library/CloudStorage/GoogleDrive-savaldiviesofl@flacso.edu.ec/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 2"
output_dir <- file.path(base_dir,  "Graficos")

cat("\n========== ANÁLISIS POR NIVEL DE POBREZA ==========\n")

# Cargar y preparar datos de pobreza ----

# Leer CSV con códigos DPA para matching directo por código
pobreza_raw <- read.csv(
  file.path(base_dir, "Procesamiento/Bases/Censo/NBI/pobreza_nbi_con_dpa.csv"),
  stringsAsFactors = FALSE
)

# Limpiar valores numéricos (quitar comas)
pobreza_raw <- pobreza_raw %>%
  mutate(across(c(total_personas, no_pobres_total, pobres_total), 
                ~as.numeric(gsub(",", "", .))))

# Calcular porcentaje de pobreza y preparar código DPA
pobreza <- pobreza_raw %>%
  mutate(
    pct_pobreza = pobres_total / total_personas * 100,
    # Asegurar que el código DPA tenga 6 dígitos
    cod_parroquia = sprintf("%06d", as.numeric(dpa_parroquia))
  ) %>%
  select(provincia, canton, parroquia, cod_parroquia, total_pob = total_personas, 
         pobre_total = pobres_total, pct_pobreza)

pobreza <- pobreza %>%
  mutate(
    nivel_pobreza = case_when(
      pct_pobreza <= quantile(pct_pobreza, 0.33, na.rm = TRUE) ~ "Menor pobreza",
      pct_pobreza <= quantile(pct_pobreza, 0.67, na.rm = TRUE) ~ "Pobreza media",
      TRUE ~ "Mayor pobreza"
    )
  )


cat("Distribución de parroquias por nivel de pobreza:\n")
print(table(pobreza$nivel_pobreza))

# Población por nivel de pobreza (sumando población de parroquias)
poblacion_pobreza <- pobreza %>%
  group_by(nivel_pobreza) %>%
  summarise(poblacion = sum(total_pob, na.rm = TRUE), .groups = "drop")

# Ordenar de mayor a menor pobreza
poblacion_pobreza$nivel_pobreza <- factor(
  poblacion_pobreza$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

cat("\nPoblación por nivel de pobreza:\n")
print(poblacion_pobreza)

poblacion_pobreza %>% mutate(percentage = poblacion / sum(poblacion) * 100)

# Cargar y preparar datos de egresos ----

egresos <- readRDS(file.path(base_dir, "Procesamiento/Bases/Hospitalarias/egresos_hospitalarios_2024.rds"))

# Crear dataframe de parroquias con datos de pobreza usando código DPA directo
df_parroquias_pobreza <- pobreza %>%
  select(cod_parroquia, pct_pobreza, nivel_pobreza, total_pob)

cat("\nParroquias con datos de pobreza:", nrow(df_parroquias_pobreza), "\n")

# Preparar datos de egresos con pobreza ----

egresos <- egresos %>%
  mutate(
    # Formatear código de parroquia a 6 dígitos para match con DPA
    # Usar as.character() primero para extraer el valor del haven_labelled
    cod_parroquia = sprintf("%06d", as.numeric(as.character(parr_ubi))),
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

egresos_pobreza <- egresos %>%
  left_join(
    df_parroquias_pobreza %>% select(cod_parroquia, pct_pobreza, nivel_pobreza, total_pob),
    by = "cod_parroquia"
  )

cat("Egresos con datos de pobreza:", sum(!is.na(egresos_pobreza$nivel_pobreza)), "de", nrow(egresos_pobreza), "\n")

egresos_analisis <- egresos_pobreza %>%
  filter(!is.na(nivel_pobreza))

egresos_analisis$nivel_pobreza <- factor(
  egresos_analisis$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

# GRÁFICOS ----

## ==== Gráfico 12: Tasa de egresos por nivel de pobreza =====

tasas_pobreza <- egresos_analisis %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

g12 <- ggplot(tasas_pobreza, aes(x = nivel_pobreza, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c(
    "Menor pobreza" = "#27AE60",
    "Pobreza media" = "#F39C12",
    "Mayor pobreza" = "#E74C3C"
  )) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de egresos hospitalarios por nivel de pobreza de la parroquia",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = "Nivel de pobreza (NBI)",
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "12_tasa_egresos_pobreza.png"), g12, width = 9, height = 6, dpi = 300)
cat("\nGráfico 12 guardado: 12_tasa_egresos_pobreza.png\n")

## Gráfico 13: Top 10 causas de egreso por nivel de pobreza ----

top10 <- egresos_analisis %>%
  filter(capitulo_cie10 != "Otros") %>%
  count(capitulo_cie10) %>%
  arrange(desc(n)) %>%
  slice(1:10) %>%
  pull(capitulo_cie10)

graf13_data <- egresos_analisis %>%
  filter(capitulo_cie10 %in% top10) %>%
  count(nivel_pobreza, capitulo_cie10) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

graf13_data$capitulo_cie10 <- factor(graf13_data$capitulo_cie10, levels = rev(top10))

g13 <- ggplot(graf13_data, aes(x = capitulo_cie10, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Menor pobreza" = "#27AE60",
    "Pobreza media" = "#F39C12",
    "Mayor pobreza" = "#E74C3C"
  )) +
  labs(
    title = "Tasa de egresos por causa y nivel de pobreza",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "13_tasas_causas_pobreza.png"), g13, width = 12, height = 8, dpi = 300)
cat("Gráfico 13 guardado: 13_tasas_causas_pobreza.png\n")

## Gráfico 14: Heatmap de enfermedades por nivel de pobreza ----

graf14_data <- egresos_analisis %>%
  filter(capitulo_cie10 %in% top10) %>%
  count(nivel_pobreza, capitulo_cie10) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

graf14_data$capitulo_cie10 <- factor(graf14_data$capitulo_cie10, levels = rev(top10))

g14 <- ggplot(graf14_data, aes(x = nivel_pobreza, y = capitulo_cie10, fill = tasa_1000)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f", tasa_1000)), size = 3.5, color = "white") +
  scale_fill_gradient(low = "#F5B7B1", high = "#922B21", name = "Tasa por\n1,000 hab") +
  labs(
    title = "Perfil de morbilidad según nivel de pobreza de la parroquia",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = "Nivel de pobreza (NBI)",
    y = NULL
  ) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "right")

ggsave(file.path(output_dir, "14_heatmap_pobreza_causas.png"), g14, width = 11, height = 8, dpi = 300)
cat("Gráfico 14 guardado: 14_heatmap_pobreza_causas.png\n")

## Gráfico 15: Diferencias en causas (pobres vs no pobres) ----

graf15_data <- egresos_analisis %>%
  filter(capitulo_cie10 %in% top10) %>%
  filter(nivel_pobreza != "Pobreza media") %>%
  count(nivel_pobreza, capitulo_cie10) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000) %>%
  select(-n, -poblacion) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000, values_fill = 0) %>%
  mutate(diferencia = `Mayor pobreza` - `Menor pobreza`) %>%
  arrange(diferencia)

graf15_data$capitulo_cie10 <- factor(graf15_data$capitulo_cie10, levels = graf15_data$capitulo_cie10)

g15 <- ggplot(graf15_data, aes(x = capitulo_cie10, y = diferencia, fill = diferencia > 0)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  coord_flip() +
  scale_fill_manual(
    values = c("TRUE" = "#E74C3C", "FALSE" = "#27AE60"),
    labels = c("Mayor en parroquias de menor pobreza", "Mayor en parroquias de mayor pobreza")
  ) +
  labs(
    title = "Diferencia en tasas de egreso: Parroquias pobres vs no pobres",
    subtitle = "Ecuador 2024 - Diferencia en tasas por 1,000 habitantes",
    x = NULL,
    y = "Diferencia en tasa por 1,000 hab",
    fill = "Predominancia"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "15_diferencia_pobreza.png"), g15, width = 10, height = 7, dpi = 300)
cat("Gráfico 15 guardado: 15_diferencia_pobreza.png\n")

## Gráfico 16: Días de estancia por nivel de pobreza ----

graf16_data <- egresos_analisis %>%
  filter(capitulo_cie10 %in% top10) %>%
  group_by(nivel_pobreza, capitulo_cie10) %>%
  summarise(dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE), n = n(), .groups = "drop")

graf16_data$capitulo_cie10 <- factor(graf16_data$capitulo_cie10, levels = rev(top10))

g16 <- ggplot(graf16_data, aes(x = capitulo_cie10, y = dias_promedio, fill = nivel_pobreza)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Menor pobreza" = "#27AE60",
    "Pobreza media" = "#F39C12",
    "Mayor pobreza" = "#E74C3C"
  )) +
  labs(
    title = "Días de estancia hospitalaria por nivel de pobreza",
    subtitle = "Ecuador 2024 - Promedio de días por causa de egreso",
    x = NULL,
    y = "Días de estancia promedio",
    fill = "Nivel de pobreza\n(NBI)"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "16_dias_estancia_pobreza.png"), g16, width = 11, height = 8, dpi = 300)
cat("Gráfico 16 guardado: 16_dias_estancia_pobreza.png\n")

## Gráfico 17: Días de estancia por nivel de pobreza (total) ----

dias_pobreza <- egresos_analisis %>%
  group_by(nivel_pobreza) %>%
  summarise(
    dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )


g17 <- ggplot(dias_pobreza, aes(x = nivel_pobreza, y = dias_promedio, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(dias_promedio, 2), " días\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c(
    "Menor pobreza" = "#27AE60",
    "Pobreza media" = "#F39C12",
    "Mayor pobreza" = "#E74C3C"
  )) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Días de estancia hospitalaria promedio por nivel de pobreza",
    subtitle = "Ecuador 2024 - Promedio general ",
    x = "Nivel de pobreza (NBI)",
    y = "Días de estancia promedio"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "17_dias_estancia_pobreza_total.png"), g17, width = 9, height = 6, dpi = 300)
cat("Gráfico 17 guardado: 17_dias_estancia_pobreza_total.png\n")

# Resumen estadístico ----

cat("\n\n========== RESUMEN ESTADÍSTICO ==========\n")

cat("\n--- Tasas de egreso por nivel de pobreza ---\n")
print(tasas_pobreza)

cat("\n--- Top 5 causas por nivel de pobreza ---\n")
for (nivel in levels(egresos_analisis$nivel_pobreza)) {
  cat("\n", nivel, ":\n")
  top5 <- egresos_analisis %>%
    filter(nivel_pobreza == nivel) %>%
    count(capitulo_cie10) %>%
    left_join(poblacion_pobreza %>% filter(nivel_pobreza == nivel), by = character()) %>%
    mutate(tasa_1000 = n / poblacion * 1000) %>%
    arrange(desc(n)) %>%
    head(5) %>%
    select(capitulo_cie10, n, tasa_1000)
  print(top5)
}

cat("\n========== ANÁLISIS DE POBREZA COMPLETADO ==========\n")

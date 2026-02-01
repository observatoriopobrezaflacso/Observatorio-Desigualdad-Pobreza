# =============================================================================
# Análisis para Boletín 2 - Observatorio de Políticas Públicas
# Defunciones y Egresos Hospitalarios 2024
# VERSIÓN ACTUALIZADA: Tasas por 1,000 habitantes
# =============================================================================

# CONFIGURACIÓN INICIAL ----

# Librerías ----
library(dplyr)
library(haven)
library(ggplot2)
library(tidyr)
library(scales)
library(forcats)
library(DBI)
library(duckdb)
# install.packages(c("duckdb", "DBI"))  # Descomentar si no están instalados

# Opciones globales ----
# Detener ejecución si hay un error
options(error = function() {
  traceback()
  stop("Ejecución detenida por error", call. = FALSE)
})

# Tema de gráficos ----
theme_set(theme_minimal(base_size = 12) +
            theme(
              plot.title = element_text(face = "bold", size = 14),
              plot.subtitle = element_text(color = "gray40"),
              legend.position = "bottom",
              panel.grid.minor = element_blank()
            ))

# Directorios ----
base_dir <- "/Users/vero/Library/CloudStorage/GoogleDrive-savaldiviesofl@flacso.edu.ec/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 2"
output_dir <- file.path(base_dir, "Procesamiento", "Graficos")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# CONSULTAS A BASE DE DATOS CENSAL (DuckDB) ====

# Conexión a base de datos ----
# Requiere que la tabla censo2022 ya esté creada en mydb.duckdb
con <- dbConnect(duckdb::duckdb(), dbdir = "Procesamiento/Bases/Censo/mydb.duckdb")

# Código para crear la tabla censo2022 (ejecutar solo una vez)
dbExecute(con, "
  CREATE TABLE censo2022 AS
  SELECT *
  FROM read_csv_auto(
    'Procesamiento/Bases/Censo/BDD_POB_CPV2022_SECT.csv'
  )
")

# Consultas de población por educación ----
# Población con/sin educación universitaria (toda la población)
# P17R > 8 indica nivel de instrucción superior a secundaria completa
universitario_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R > 8 THEN 'Si'
      ELSE 'No'
    END AS universitario,
    COUNT(*) AS n_personas
  FROM censo2022
  GROUP BY universitario
")

# Población adulta (gedad >= 8) con/sin educación universitaria
# gedad >= 8 corresponde a personas de 30 años o más
universitario_adulto_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R > 8 THEN 'Si'
      ELSE 'No'
    END AS universitario,
    COUNT(*) AS n_personas
  FROM censo2022
  WHERE gedad >= 7  
  GROUP BY universitario
")

secundaria_joven_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R >= 6 THEN 'Si'
      ELSE 'No'
    END AS secundaria_completa,
    COUNT(*) AS n_personas
  FROM censo2022
  WHERE gedad == 6
  GROUP BY secundaria_completa
")


# Consulta de población por grupo de edad ----
grupo_edad_censo <- dbGetQuery(con, "
  SELECT
    GEDAD AS gedad,
    COUNT(*) AS n_personas
  FROM censo2022
  GROUP BY GEDAD
  ORDER BY GEDAD
")


# POBLACIÓN DE REFERENCIA (Censo 2022) ====

# Población total y por grupos de edad ----
poblacion_total <- sum(universitario_censo$n_personas)

# Estimaciones de población por grupo de edad
poblacion_grupos <- list(
  jovenes_20_29 = sum(grupo_edad_censo %>% filter(gedad %in% c(6,7)) %>% pull(n_personas)),
  adultos_30_64 = sum(grupo_edad_censo %>% filter(between(gedad, 8, 14)) %>% pull(n_personas)),
  adultos_mayores_65 = sum(grupo_edad_censo %>% filter(gedad >= 15) %>% pull(n_personas))
)

# Población por nivel educativo ----
# Jóvenes 18-29: ~60% secundaria completa, ~40% incompleta
poblacion_educacion_jovenes <- list(
  secundaria_completa = secundaria_joven_censo[secundaria_joven_censo$secundaria_completa == "Si", "n_personas"],
  secundaria_incompleta = secundaria_joven_censo[secundaria_joven_censo$secundaria_completa == "No", "n_personas"]
)

# Adultos 30+: ~15% universitario, ~85% no universitario
poblacion_educacion_adultos <- list(
  universitario = universitario_adulto_censo[universitario_adulto_censo$universitario == "Si", "n_personas"],
  no_universitario = universitario_adulto_censo[universitario_adulto_censo$universitario == "No", "n_personas"]
)


# ANÁLISIS DE DEFUNCIONES ====

cat("\n========== ANÁLISIS DE DEFUNCIONES ==========\n")

# Carga y transformación de datos ----
defunciones <- readRDS(file.path(base_dir, "Procesamiento/Bases/Defunciones/EDG_2024.rds"))

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

    causa_agrupada = case_when(
      as.character(as_factor(causa67A)) %in% c("030 Enfermedades del sistema circulatorio") ~ "Cardiovasculares",
      as.character(as_factor(causa67A)) %in% c("016 Tumores [neoplasias]") ~ "Tumores",
      as.character(as_factor(causa67A)) %in% c("031 Enfermedades del sistema respiratorio") ~ "Respiratorias",
      as.character(as_factor(causa67A)) %in% c("023 Enfermedades endocrinas, nutricionales y metabólicas") ~ "Metabólicas/Endocrinas",
      as.character(as_factor(causa67A)) %in% c("060 Causas externas de morbilidad y de mortalidad") ~ "Causas externas",
      as.character(as_factor(causa67A)) %in% c("035 Enfermedades del sistema digestivo") ~ "Digestivas",
      as.character(as_factor(causa67A)) %in% c("001 Ciertas enfermedades infecciosas y parasitarias") ~ "Infecciosas",
      as.character(as_factor(causa67A)) %in% c("036 Enfermedades del sistema genitourinario") ~ "Genitales/Urinarias",
      as.character(as_factor(causa67A)) %in% c("026 Enfermedades del sistema nervioso") ~ "Sistema nervioso",
      grepl("COVID", as.character(as_factor(causa67A))) ~ "COVID-19",
      as.character(as_factor(causa67A)) %in% c("037 Ciertas afecciones originadas en el período perinatal") ~ "Perinatales",
      as.character(as_factor(causa67A)) %in% c("049 Malformaciones congénitas, deformidades y anomalías cromosómicas") ~ "Congénitas",
      TRUE ~ "Otras causas"
    )
  )

# Filtrado de datos para análisis ----
defunciones_analisis <- defunciones %>%
  filter(!is.na(grupo_edad) & !is.na(causa_agrupada))

cat("Registros para análisis (sin niños):", nrow(defunciones_analisis), "\n")

## Gráfico 1: Tasas de mortalidad por grupo de edad ----
tasas_grupo_edad <- defunciones_analisis %>%
  count(grupo_edad) %>%
  mutate(
    poblacion = case_when(
      grupo_edad == "20-29" ~ poblacion_grupos$jovenes_20_29,
      grupo_edad == "30-64" ~ poblacion_grupos$adultos_30_64,
      grupo_edad == "65+" ~ poblacion_grupos$adultos_mayores_65
    ),
    tasa_1000 = n / poblacion * 1000
  )

tasas_grupo_edad$grupo_edad <- factor(tasas_grupo_edad$grupo_edad,
                                       levels = c("20-29", "30-64", "65+"))

g1 <- ggplot(tasas_grupo_edad, aes(x = grupo_edad, y = tasa_1000, fill = grupo_edad)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4) +
  scale_fill_manual(values = c("20-29" = "#3498DB",
                               "30-64" = "#E67E22",
                               "65+" = "#9B59B6")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
  labs(
    title = "Tasa de mortalidad por grupo de edad",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "01_tasas_mortalidad_grupo_edad.png"), g1, width = 9, height = 6, dpi = 300)
cat("Gráfico 1 guardado: 01_tasas_mortalidad_grupo_edad.png\n")

## Gráfico 2: Tasas de mortalidad por causa y grupo de edad ----
tasas_edad_causa <- defunciones_analisis %>%
  count(grupo_edad, causa_agrupada) %>%
  mutate(
    poblacion = case_when(
      grupo_edad == "20-29" ~ poblacion_grupos$jovenes_20_29,
      grupo_edad == "30-64" ~ poblacion_grupos$adultos_30_64,
      grupo_edad == "65+" ~ poblacion_grupos$adultos_mayores_65
    ),
    tasa_1000 = n / poblacion * 1000
  )

orden_causas <- tasas_edad_causa %>%
  group_by(causa_agrupada) %>%
  summarise(total = sum(n)) %>%
  arrange(desc(total)) %>%
  pull(causa_agrupada)

tasas_edad_causa$causa_agrupada <- factor(tasas_edad_causa$causa_agrupada, levels = rev(orden_causas))
tasas_edad_causa$grupo_edad <- factor(tasas_edad_causa$grupo_edad,
                                       levels = c("20-29", "30-64", "65+"))

g2 <- ggplot(tasas_edad_causa, aes(x = causa_agrupada, y = tasa_1000, fill = grupo_edad)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("20-29" = "#3498DB",
                               "30-64" = "#E67E22",
                               "65+" = "#9B59B6")) +
  labs(
    title = "Tasa de mortalidad por causa según grupo de edad",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes de cada grupo",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Grupo de edad"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "02_tasas_mortalidad_edad_causa.png"), g2, width = 11, height = 8, dpi = 300)
cat("Gráfico 2 guardado: 02_tasas_mortalidad_edad_causa.png\n")

## Gráfico 3: Jóvenes - Tasa total por nivel educativo ----
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

g3 <- ggplot(tasas_jovenes_educ, aes(x = nivel_educativo_jovenes, y = tasa_1000, fill = nivel_educativo_jovenes)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de mortalidad en jóvenes (18-29 años) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "03_jovenes_tasa_educacion.png"), g3, width = 8, height = 6, dpi = 300)
cat("Gráfico 3 guardado: 03_jovenes_tasa_educacion.png\n")

## Gráfico 4: Jóvenes - Causas por nivel educativo ----
jovenes_con_causa <- defunciones %>%
  filter(grupo_edad == "20-29" & !is.na(nivel_educativo_jovenes) & !is.na(causa_agrupada))

graf4_data <- jovenes_con_causa %>%
  count(nivel_educativo_jovenes, causa_agrupada) %>%
  left_join(
    jovenes_con_causa %>% count(nivel_educativo_jovenes, name = "total_grupo"),
    by = "nivel_educativo_jovenes"
  ) %>%
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

graf4_data <- graf4_data %>% filter(causa_agrupada %in% top8_jovenes)
graf4_data$causa_agrupada <- factor(graf4_data$causa_agrupada, levels = rev(top8_jovenes))

g4 <- ggplot(graf4_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "Causas de muerte en jóvenes (18-29 años) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "04_jovenes_causas_educacion.png"), g4, width = 11, height = 7, dpi = 300)
cat("Gráfico 4 guardado: 04_jovenes_causas_educacion.png\n")

## Gráfico 5: Adultos - Tasa total por nivel educativo ----
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

g5 <- ggplot(tasas_adultos_educ, aes(x = nivel_educativo_adultos, y = tasa_1000, fill = nivel_educativo_adultos)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de mortalidad en adultos (30+ años) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "05_adultos_tasa_educacion.png"), g5, width = 8, height = 6, dpi = 300)
cat("Gráfico 5 guardado: 05_adultos_tasa_educacion.png\n")

## Gráfico 6: Adultos - Causas por nivel educativo ----
adultos_con_causa <- defunciones %>%
  filter(grupo_edad %in% c("30-64", "65+") &
         !is.na(nivel_educativo_adultos) & !is.na(causa_agrupada))

graf6_data <- adultos_con_causa %>%
  count(grupo_edad, nivel_educativo_adultos, causa_agrupada) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario / 2,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario / 2
    ),
    tasa_1000 = n / poblacion * 1000
  ) %>%
  filter(causa_agrupada %in% orden_causas[1:8])

graf6_data$causa_agrupada <- factor(graf6_data$causa_agrupada, levels = rev(orden_causas[1:8]))
graf6_data$grupo_edad <- factor(graf6_data$grupo_edad,
                                 levels = c("30-64", "65+"))

g6 <- ggplot(graf6_data, aes(x = causa_agrupada, y = tasa_1000, fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  facet_wrap(~grupo_edad, ncol = 2) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  labs(
    title = "Causas de muerte en adultos por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = NULL,
    y = "Tasa por 1,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom", strip.text = element_text(face = "bold", size = 11))

ggsave(file.path(output_dir, "06_adultos_causas_educacion.png"), g6, width = 13, height = 8, dpi = 300)
cat("Gráfico 6 guardado: 06_adultos_causas_educacion.png\n")

## Gráfico 7: Heatmap de tasas por grupo de edad ----
graf7_data <- tasas_edad_causa %>%
  filter(causa_agrupada %in% orden_causas[1:10])

g7 <- ggplot(graf7_data, aes(x = grupo_edad, y = causa_agrupada, fill = tasa_1000)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", tasa_1000)), size = 3.5, color = "white") +
  scale_fill_gradient(low = "#FADBD8", high = "#922B21", name = "Tasa por\n1,000 hab") +
  labs(
    title = "Tasas de mortalidad por causa y grupo de edad",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = "Grupo de edad",
    y = NULL
  ) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "right")

ggsave(file.path(output_dir, "07_heatmap_tasas_edad.png"), g7, width = 11, height = 8, dpi = 300)
cat("Gráfico 7 guardado: 07_heatmap_tasas_edad.png\n")

# Resumen
cat("\n--- Resumen de defunciones ---\n")
print(tasas_grupo_edad)


# ANÁLISIS DE CAUSAS EXTERNAS Y SUICIDIOS ====

# Clasificación de causas externas ----
# Clasificar causas externas específicas usando causa103
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

## Gráfico 8: Muertes por causas externas según tipo ----
graf8_data <- defunciones %>%
  filter(!is.na(causa_externa_especifica)) %>%
  count(causa_externa_especifica) %>%
  mutate(
    tasa_100000 = n / poblacion_total * 100000,
    porcentaje = n / sum(n) * 100
  ) %>%
  arrange(desc(n))

graf8_data$causa_externa_especifica <- factor(graf8_data$causa_externa_especifica,
                                               levels = graf8_data$causa_externa_especifica)

g8_violentas <- ggplot(graf8_data, aes(x = reorder(causa_externa_especifica, n), y = tasa_100000, fill = causa_externa_especifica)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Accidentes de transporte" = "#3498DB",
    "Caídas" = "#9B59B6",
    "Ahogamiento" = "#1ABC9C",
    "Exposición a fuego/humo" = "#E67E22",
    "Envenenamiento accidental" = "#F39C12",
    "Lesiones autoinfligidas" = "#E74C3C",
    "Agresiones (homicidios)" = "#C0392B",
    "Otras causas externas" = "#7F8C8D"
  )) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  labs(
    title = "Muertes por causas externas según tipo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "08_muertes_causas_externas.png"), g8_violentas, width = 11, height = 7, dpi = 300)
cat("Gráfico 8 guardado: 08_muertes_causas_externas.png\n")

# Clasificación de métodos de suicidio ----
# Clasificar métodos de suicidio usando código CIE-10
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

## Gráfico 9: Suicidios por método ----
graf9_data <- defunciones %>%
  filter(!is.na(metodo_suicidio)) %>%
  count(metodo_suicidio) %>%
  mutate(
    tasa_100000 = n / poblacion_total * 100000,
    porcentaje = n / sum(n) * 100
  ) %>%
  arrange(desc(n))

graf9_data$metodo_suicidio <- factor(graf9_data$metodo_suicidio,
                                      levels = graf9_data$metodo_suicidio)

g9_suicidios <- ggplot(graf9_data, aes(x = reorder(metodo_suicidio, n), y = n, fill = metodo_suicidio)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = paste0(n, " (", round(porcentaje, 1), "%)")),
            hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Muertes por lesiones autoinfligidas según método",
    subtitle = paste0("Ecuador 2024 - Total: ", sum(graf9_data$n), " defunciones"),
    x = NULL,
    y = "Número de defunciones"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "09_suicidios_por_metodo.png"), g9_suicidios, width = 11, height = 7, dpi = 300)
cat("Gráfico 9 guardado: 09_suicidios_por_metodo.png\n")

## Gráfico 10: Causas externas por grupo de edad ----
graf10_data <- defunciones %>%
  filter(!is.na(causa_externa_especifica) & !is.na(grupo_edad)) %>%
  count(grupo_edad, causa_externa_especifica) %>%
  mutate(
    poblacion = case_when(
      grupo_edad == "20-29" ~ poblacion_grupos$jovenes_20_29,
      grupo_edad == "30-64" ~ poblacion_grupos$adultos_30_64,
      grupo_edad == "65+" ~ poblacion_grupos$adultos_mayores_65
    ),
    tasa_100000 = n / poblacion * 100000
  )

graf10_data$grupo_edad <- factor(graf10_data$grupo_edad,
                                  levels = c("20-29", "30-64", "65+"))

g10_violentas_edad <- ggplot(graf10_data, aes(x = causa_externa_especifica, y = tasa_100000, fill = grupo_edad)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("20-29" = "#3498DB", "30-64" = "#E67E22", "65+" = "#9B59B6")) +
  labs(
    title = "Muertes por causas externas según grupo de edad",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes de cada grupo",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Grupo de edad"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "10_muertes_externas_edad.png"), g10_violentas_edad, width = 12, height = 8, dpi = 300)
cat("Gráfico 10 guardado: 10_muertes_externas_edad.png\n")

## Gráfico 11: Suicidios por grupo de edad y sexo ----
graf11_data <- defunciones %>%
  filter(!is.na(metodo_suicidio) & !is.na(grupo_edad)) %>%
  mutate(sexo_etiq = case_when(
    as.numeric(sexo) == 1 ~ "Hombre",
    as.numeric(sexo) == 2 ~ "Mujer",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(sexo_etiq)) %>%
  count(grupo_edad, sexo_etiq) %>%
  mutate(
    poblacion = case_when(
      grupo_edad == "20-29" ~ poblacion_grupos$jovenes_20_29 / 2,
      grupo_edad == "30-64" ~ poblacion_grupos$adultos_30_64 / 2,
      grupo_edad == "65+" ~ poblacion_grupos$adultos_mayores_65 / 2
    ),
    tasa_100000 = n / poblacion * 100000
  )

graf11_data$grupo_edad <- factor(graf11_data$grupo_edad,
                                  levels = c("20-29", "30-64", "65+"))

g11_suicidios_edad_sexo <- ggplot(graf11_data, aes(x = grupo_edad, y = tasa_100000, fill = sexo_etiq)) +
  geom_col(position = "dodge", width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", n, ")")),
            position = position_dodge(width = 0.6), vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("Hombre" = "#3498DB", "Mujer" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de suicidio por grupo de edad y sexo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = "Grupo de edad",
    y = "Tasa por 100,000 habitantes",
    fill = "Sexo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "11_suicidios_edad_sexo.png"), g11_suicidios_edad_sexo, width = 10, height = 7, dpi = 300)
cat("Gráfico 11 guardado: 11_suicidios_edad_sexo.png\n")


# 5. ANÁLISIS POR NIVEL EDUCATIVO (CAUSAS EXTERNAS Y SUICIDIOS) ====

## Gráfico 12A: Causas externas en jóvenes por educación ----
jovenes_externas <- defunciones %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_educativo_jovenes))

graf12a_data <- jovenes_externas %>%
  count(nivel_educativo_jovenes, causa_externa_especifica) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 5)  # Filtrar causas con pocos casos

# Ordenar por frecuencia total
orden_causas_ext <- jovenes_externas %>%
  count(causa_externa_especifica) %>%
  arrange(desc(n)) %>%
  pull(causa_externa_especifica)

graf12a_data$causa_externa_especifica <- factor(graf12a_data$causa_externa_especifica,
                                                 levels = rev(orden_causas_ext))

g12a_externas_jovenes <- ggplot(graf12a_data, aes(x = causa_externa_especifica, y = tasa_100000,
                                                   fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "Muertes por causas externas en jóvenes (20-29) según nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "12a_externas_jovenes_educacion.png"), g12a_externas_jovenes, width = 11, height = 7, dpi = 300)
cat("Gráfico 12A guardado: 12a_externas_jovenes_educacion.png\n")

## Gráfico 12B: Causas externas en adultos por educación ----
adultos_externas <- defunciones %>%
  filter(!is.na(causa_externa_especifica) & !is.na(nivel_educativo_adultos))

graf12b_data <- adultos_externas %>%
  count(nivel_educativo_adultos, causa_externa_especifica) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 10)

graf12b_data$causa_externa_especifica <- factor(graf12b_data$causa_externa_especifica,
                                                 levels = rev(orden_causas_ext))

g12b_externas_adultos <- ggplot(graf12b_data, aes(x = causa_externa_especifica, y = tasa_100000,
                                                   fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  labs(
    title = "Muertes por causas externas en adultos (30+) según nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "12b_externas_adultos_educacion.png"), g12b_externas_adultos, width = 11, height = 7, dpi = 300)
cat("Gráfico 12B guardado: 12b_externas_adultos_educacion.png\n")

## Gráfico 13A: Suicidios en jóvenes por educación y método ----
jovenes_suicidios <- defunciones %>%
  filter(!is.na(metodo_suicidio) & !is.na(nivel_educativo_jovenes))

graf13a_data <- jovenes_suicidios %>%
  count(nivel_educativo_jovenes, metodo_suicidio) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 3)

# Ordenar por frecuencia total
orden_metodos <- jovenes_suicidios %>%
  count(metodo_suicidio) %>%
  arrange(desc(n)) %>%
  pull(metodo_suicidio)

graf13a_data$metodo_suicidio <- factor(graf13a_data$metodo_suicidio, levels = rev(orden_metodos))

g13a_suicidios_jovenes <- ggplot(graf13a_data, aes(x = metodo_suicidio, y = tasa_100000,
                                                    fill = nivel_educativo_jovenes)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  labs(
    title = "Suicidios en jóvenes (20-29) por método y nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "13a_suicidios_jovenes_educacion.png"), g13a_suicidios_jovenes, width = 11, height = 7, dpi = 300)
cat("Gráfico 13A guardado: 13a_suicidios_jovenes_educacion.png\n")

## Gráfico 13B: Suicidios en adultos por educación y método ----
adultos_suicidios <- defunciones %>%
  filter(!is.na(metodo_suicidio) & !is.na(nivel_educativo_adultos))

graf13b_data <- adultos_suicidios %>%
  count(nivel_educativo_adultos, metodo_suicidio) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  ) %>%
  filter(n >= 5)

graf13b_data$metodo_suicidio <- factor(graf13b_data$metodo_suicidio, levels = rev(orden_metodos))

g13b_suicidios_adultos <- ggplot(graf13b_data, aes(x = metodo_suicidio, y = tasa_100000,
                                                    fill = nivel_educativo_adultos)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  labs(
    title = "Suicidios en adultos (30+) por método y nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes",
    fill = "Nivel educativo"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "13b_suicidios_adultos_educacion.png"), g13b_suicidios_adultos, width = 11, height = 7, dpi = 300)
cat("Gráfico 13B guardado: 13b_suicidios_adultos_educacion.png\n")

## Gráfico 14A: Tasa total de suicidio en jóvenes por educación ----
tasa_suicidio_jovenes <- jovenes_suicidios %>%
  count(nivel_educativo_jovenes) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_jovenes == "Secundaria completa" ~ poblacion_educacion_jovenes$secundaria_completa,
      nivel_educativo_jovenes == "Secundaria incompleta" ~ poblacion_educacion_jovenes$secundaria_incompleta
    ),
    tasa_100000 = n / poblacion * 100000
  )

g14a_suicidio_total_jovenes <- ggplot(tasa_suicidio_jovenes, aes(x = nivel_educativo_jovenes, y = tasa_100000,
                                                                  fill = nivel_educativo_jovenes)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", n, ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c("Secundaria completa" = "#27AE60", "Secundaria incompleta" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de suicidio en jóvenes (20-29) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "14a_suicidio_total_jovenes_educ.png"), g14a_suicidio_total_jovenes, width = 8, height = 6, dpi = 300)
cat("Gráfico 14A guardado: 14a_suicidio_total_jovenes_educ.png\n")

## Gráfico 14B: Tasa total de suicidio en adultos por educación ----
tasa_suicidio_adultos <- adultos_suicidios %>%
  count(nivel_educativo_adultos) %>%
  mutate(
    poblacion = case_when(
      nivel_educativo_adultos == "Universitario" ~ poblacion_educacion_adultos$universitario,
      nivel_educativo_adultos == "No universitario" ~ poblacion_educacion_adultos$no_universitario
    ),
    tasa_100000 = n / poblacion * 100000
  )

g14b_suicidio_total_adultos <- ggplot(tasa_suicidio_adultos, aes(x = nivel_educativo_adultos, y = tasa_100000,
                                                                  fill = nivel_educativo_adultos)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_100000, 1), "\n(n=", n, ")")),
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c("Universitario" = "#2E86AB", "No universitario" = "#E94F37")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Tasa de suicidio en adultos (30+) por nivel educativo",
    subtitle = "Ecuador 2024 - Tasa por 100,000 habitantes",
    x = NULL,
    y = "Tasa por 100,000 habitantes"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "14b_suicidio_total_adultos_educ.png"), g14b_suicidio_total_adultos, width = 8, height = 6, dpi = 300)
cat("Gráfico 14B guardado: 14b_suicidio_total_adultos_educ.png\n")

# Resumen de causas externas y suicidios ----
cat("\n--- Resumen de muertes por causas externas ---\n")
print(graf8_data %>% select(causa_externa_especifica, n, tasa_100000, porcentaje))

cat("\n--- Resumen de suicidios por método ---\n")
print(graf9_data %>% select(metodo_suicidio, n, porcentaje))


# 6. ANÁLISIS DE EGRESOS HOSPITALARIOS ====

cat("\n\n========== ANÁLISIS DE EGRESOS HOSPITALARIOS ==========\n")

# 6.1 Carga y transformación de datos ----
egresos <- readRDS(file.path(base_dir, "Procesamiento/Bases/Hospitalarias/egresos_hospitalarios_2024.rds"))

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

## Gráfico 12: Tasa de egresos por tipo de establecimiento ----
graf12_egresos <- egresos_3grupos %>%
  count(tipo_establecimiento) %>%
  mutate(tasa_1000 = n / poblacion_total * 1000)

g12_egresos <- ggplot(graf12_egresos, aes(x = reorder(tipo_establecimiento, tasa_1000), y = tasa_1000, fill = tipo_establecimiento)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 1), "\n(n=", format(n, big.mark = ","), ")")),
            hjust = -0.1, size = 4) +
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

ggsave(file.path(output_dir, "12_tasas_egresos_tipo.png"), g12_egresos, width = 10, height = 5, dpi = 300)
cat("Gráfico 12 guardado: 12_tasas_egresos_tipo.png\n")

## Gráfico 13: Tasas de egreso por causa y establecimiento ----
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
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "13_tasas_causas_tipo.png"), g13_egresos, width = 11, height = 8, dpi = 300)
cat("Gráfico 13 guardado: 13_tasas_causas_tipo.png\n")

## Gráfico 14: Heatmap tasas por tipo de establecimiento ----
graf14_egresos <- egresos_3grupos %>%
  filter(capitulo_cie10 %in% top10_causas) %>%
  count(tipo_establecimiento, capitulo_cie10) %>%
  mutate(tasa_1000 = n / poblacion_total * 1000)

graf14_egresos$capitulo_cie10 <- factor(graf14_egresos$capitulo_cie10, levels = rev(top10_causas))
graf14_egresos$tipo_establecimiento <- factor(graf14_egresos$tipo_establecimiento,
                                            levels = c("MSP (Público)", "IESS", "Privados"))

g14_egresos <- ggplot(graf14_egresos, aes(x = tipo_establecimiento, y = capitulo_cie10, fill = tasa_1000)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f", tasa_1000)), size = 3.5, color = "white") +
  scale_fill_gradient(low = "#FADBD8", high = "#1A5276", name = "Tasa por\n1,000 hab") +
  labs(
    title = "Tasa de egresos por tipo de establecimiento y causa",
    subtitle = "Ecuador 2024 - Tasa por 1,000 habitantes",
    x = "Tipo de establecimiento",
    y = NULL
  ) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "right")

ggsave(file.path(output_dir, "14_heatmap_tasas_tipo.png"), g14_egresos, width = 10, height = 8, dpi = 300)
cat("Gráfico 14 guardado: 14_heatmap_tasas_tipo.png\n")

## Gráfico 15: Días de estancia promedio por causa ----
graf15_egresos <- egresos_3grupos %>%
  filter(capitulo_cie10 %in% top10_causas) %>%
  group_by(tipo_establecimiento, capitulo_cie10) %>%
  summarise(dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE), n = n(), .groups = "drop")

graf15_egresos$capitulo_cie10 <- factor(graf15_egresos$capitulo_cie10, levels = rev(top10_causas))

g15_egresos <- ggplot(graf15_egresos, aes(x = capitulo_cie10, y = dias_promedio, fill = tipo_establecimiento)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("MSP (Público)" = "#2E86AB", "IESS" = "#F18F01", "Privados" = "#27AE60")) +
  labs(
    title = "Días de estancia promedio por causa y tipo de establecimiento",
    subtitle = "Ecuador 2024",
    x = NULL,
    y = "Días de estancia promedio",
    fill = "Tipo de establecimiento"
  ) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "15_dias_estancia_tipo_causa.png"), g15_egresos, width = 11, height = 8, dpi = 300)
cat("Gráfico 15 guardado: 15_dias_estancia_tipo_causa.png\n")

## Gráfico 16: Días de estancia promedio por establecimiento ----
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
            vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c("MSP (Público)" = "#2E86AB", "IESS" = "#F18F01", "Privados" = "#27AE60")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "Días de estancia promedio por tipo de establecimiento",
    subtitle = "Ecuador 2024 - Promedio general sin desagregar por causa",
    x = NULL,
    y = "Días de estancia promedio"
  ) +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "16_dias_estancia_tipo_total.png"), g16_egresos, width = 9, height = 6, dpi = 300)
cat("Gráfico 16 guardado: 16_dias_estancia_tipo_total.png\n")

# Resumen de egresos hospitalarios ----
cat("\n--- Resumen de egresos por tipo de establecimiento ---\n")
print(egresos_3grupos %>%
        group_by(tipo_establecimiento) %>%
        summarise(
          n_egresos = n(),
          tasa_1000 = n() / poblacion_total * 1000,
          dias_promedio = mean(as.numeric(dia_estad), na.rm = TRUE)
        ))


# FIN DEL ANÁLISIS ====
cat("\n========== ANÁLISIS COMPLETADO ==========\n")


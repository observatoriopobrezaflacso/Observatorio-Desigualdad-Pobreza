# =============================================================================
# Análisis de Defunciones por Nivel de Pobreza
# Boletín 2 - Observatorio de Políticas Públicas
# Mortalidad por pobreza
# =============================================================================

cat("\n========== ANÁLISIS DE DEFUNCIONES POR NIVEL DE POBREZA ==========\n")

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

# Etiquetas con acentos para los graficos ----
causa_labels <- c(
  "Metabolicas/Endocrinas" = "Metabólicas/Endocrinas",
  "Congenitas" = "Congénitas"
)

cat("Total de defunciones:", nrow(defunciones), "\n")

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

cat("Defunciones con datos de pobreza:", sum(!is.na(defunciones_pobreza\$nivel_pobreza)),
    "de", nrow(defunciones_pobreza), "\n")

defunciones_pob_analisis <- defunciones_pobreza %>%
  filter(!is.na(nivel_pobreza) & !is.na(grupo_edad) & !is.na(causa_agrupada))

defunciones_pob_analisis\$nivel_pobreza <- factor(
  defunciones_pob_analisis\$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

# Gráfico: Tasa de mortalidad por nivel de pobreza ----
tasas_mort_pobreza <- defunciones_pob_analisis %>%
  count(nivel_pobreza) %>%
  left_join(poblacion_pobreza, by = "nivel_pobreza") %>%
  mutate(tasa_1000 = n / poblacion * 1000)

# Calcular ratio para pobreza
ratio_mort_pobreza <- tasas_mort_pobreza %>%
  filter(nivel_pobreza %in% c("Mayor pobreza", "Menor pobreza")) %>%
  select(nivel_pobreza, tasa_1000) %>%
  pivot_wider(names_from = nivel_pobreza, values_from = tasa_1000) %>%
  mutate(ratio = \`Mayor pobreza\` / \`Menor pobreza\`,
         ratio_label = paste0(round(ratio, 1), "x"))

g_mort_pobreza <- ggplot(tasas_mort_pobreza, aes(x = nivel_pobreza, y = tasa_1000, fill = nivel_pobreza)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_1000, 2), "\n(n=", format(n, big.mark = ","), ")")),
            vjust = -0.3, size = 4.5) +
  annotate("segment", x = 1, xend = 3,
           y = max(tasas_mort_pobreza\$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza\$tasa_1000) * 1.28,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 1, xend = 1,
           y = max(tasas_mort_pobreza\$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza\$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  annotate("segment", x = 3, xend = 3,
           y = max(tasas_mort_pobreza\$tasa_1000) * 1.28,
           yend = max(tasas_mort_pobreza\$tasa_1000) * 1.25,
           color = "gray40", linewidth = 0.5) +
  geom_label(aes(x = 2, y = max(tasas_mort_pobreza\$tasa_1000) * 1.33,
                 label = ratio_mort_pobreza\$ratio_label),
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

cat("\n========== ANÁLISIS DE POBREZA FINALIZADO ==========\n")

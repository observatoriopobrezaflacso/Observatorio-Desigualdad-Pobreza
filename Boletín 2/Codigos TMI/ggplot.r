# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# R: GENERACIÓN DE GRÁFICO CON PESOS Y CATEGORÍAS (LÓGICA BOLETÍN)
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

library(tidyverse)
library(scales)

# 1. Limpieza de tipos de datos (Corrigiendo lo que vimos en el codebook)
# Convertimos los Strings a Números para poder operar
analisis_grafico <- analisis_final %>%
    mutate(
        # Convertimos a numerico las columnas que Stata exportó como texto
        tmi_num = as.numeric(tmi_tasa),
        nac_num = as.numeric(nacimientos),
        nbi_num = as.numeric(tasa_nbi_num),

        # Clasificación de niveles según la lógica del Observatorio
        nivel_pobreza = case_when(
            nbi_num < 30 ~ "Baja Pobreza",
            nbi_num >= 30 & nbi_num <= 60 ~ "Pobreza Media",
            nbi_num > 60 ~ "Alta Pobreza"
        ),
        nivel_pobreza = factor(nivel_pobreza, levels = c("Baja Pobreza", "Pobreza Media", "Alta Pobreza"))
    ) %>%
    # Limpiamos casos extremos para que el gráfico no se distorsione
    filter(!is.na(tmi_num), nac_num > 0, tmi_num < 150)

# 2. El Gráfico de Trascendencia
ggplot(analisis_grafico, aes(x = nbi_num, y = tmi_num)) +
    # Las burbujas: tamaño según nacimientos, color según nivel de pobreza
    geom_point(aes(size = nac_num, color = nivel_pobreza), alpha = 0.5) +
    # Línea de tendencia (Regresión Lineal) que muestra la desigualdad
    geom_smooth(method = "lm", color = "black", linetype = "dashed", se = FALSE) +
    # Colores semáforo
    scale_color_manual(values = c(
        "Baja Pobreza" = "#27ae60",
        "Pobreza Media" = "#f1c40f",
        "Alta Pobreza" = "#e74c3c"
    )) +
    # Formato de los ejes y leyendas
    scale_size_continuous(range = c(2, 18), labels = comma) +
    labs(
        title = "Ecuador 2022: Pobreza Estructural y Mortalidad Infantil",
        subtitle = "Relación por niveles de NBI a nivel Parroquial",
        x = "Pobreza por NBI (%)",
        y = "Tasa de Mortalidad Infantil (por 1.000 NV)",
        size = "Nacimientos (Peso)",
        color = "Nivel de Pobreza",
        caption = "Nota: El tamaño del punto indica el volumen de nacimientos en la parroquia.\nFuente: Observatorio de Desigualdad y Pobreza (Censo 2022 / EDG 2022)"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom", plot.title = element_text(face = "bold"))

# 3. Resumen estadístico para el texto del Boletín
resumen <- analisis_grafico %>%
    group_by(nivel_pobreza) %>%
    summarise(
        tmi_promedio = mean(tmi_num, na.rm = TRUE),
        total_parroquias = n()
    )
print(resumen)

# Filtro: solo parroquias estadísticamente confiables
analisis_grafico <- analisis_final %>%
    mutate(
        tmi_num = as.numeric(tmi_tasa),
        nac_num = as.numeric(nacimientos),
        nbi_num = as.numeric(tasa_nbi_num),
        nivel_pobreza = case_when(
            nbi_num < 30 ~ "Baja Pobreza",
            nbi_num >= 30 & nbi_num <= 60 ~ "Pobreza Media",
            nbi_num > 60 ~ "Alta Pobreza"
        ),
        nivel_pobreza = factor(nivel_pobreza,
            levels = c("Baja Pobreza", "Pobreza Media", "Alta Pobreza")
        )
    ) %>%
    filter(
        !is.na(tmi_num),
        !is.na(nbi_num),
        nac_num >= 100, # mínimo para que la tasa sea confiable
        tmi_num < 150 # eliminar outliers extremos
    )

cat("Parroquias en el gráfico:", nrow(analisis_grafico), "\n")

# Gráfico corregido con tendencia ponderada
ggplot(analisis_grafico, aes(x = nbi_num, y = tmi_num)) +
    geom_point(aes(size = nac_num, color = nivel_pobreza), alpha = 0.6) +
    # Tendencia ponderada por nacimientos (weight = nac_num)
    geom_smooth(
        method = "lm", aes(weight = nac_num),
        color = "black", linetype = "dashed", se = TRUE
    ) +
    scale_color_manual(values = c(
        "Baja Pobreza"  = "#27ae60",
        "Pobreza Media" = "#f1c40f",
        "Alta Pobreza"  = "#e74c3c"
    )) +
    scale_size_continuous(range = c(2, 18), labels = comma) +
    labs(
        title    = "Ecuador 2022: Pobreza Estructural y Mortalidad Infantil",
        subtitle = paste0("Parroquias con ≥100 nacimientos (n=", nrow(analisis_grafico), ")"),
        x        = "Pobreza por NBI (%)",
        y        = "Tasa de Mortalidad Infantil (por 1.000 NV)",
        size     = "Nacimientos",
        color    = "Nivel de Pobreza",
        caption  = "Nota: Tendencia ponderada por volumen de nacimientos.\nFuente: Observatorio de Desigualdad y Pobreza (Censo 2022 / EDG 2022)"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
# Guarda el gráfico como imagen y ábrelo
ggsave("grafico_tmi_nbi.png", width = 12, height = 8, dpi = 150)

# Excluir Quito y Guayaquil y rehacer el gráfico
analisis_grafico_v2 <- analisis_grafico %>%
    filter(!cod_parroquia %in% c("170150", "090150"))

cat("Parroquias sin Quito/Guayaquil:", nrow(analisis_grafico_v2), "\n")


# Identificar los outliers verdes
analisis_grafico_v2 %>%
    filter(nivel_pobreza == "Baja Pobreza", tmi_num > 20) %>%
    select(Provincia, Canton, Parroquia, cod_parroquia, tmi_num, nac_num, nbi_num) %>%
    arrange(desc(tmi_num))

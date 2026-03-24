
# ==============================================================================
# VALIDACIÓN FINAL - RMM CALCULADA VS RMM OFICIAL
# ==============================================================================

# 1. Cargar tus muertes maternas (del numerador)
# NOTA: Ajusta la ruta según donde tengas tus datos de mortalidad
maternas <- readRDS(file.path(ruta_resultados, "muertes_maternas.rds"))
nv <- readRDS(file.path(ruta_resultados, "nacidos_vivos_resumen.rds"))


# 2. RMM oficial (de tu tabla)
rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# 3. Calcular RMM con nuestro nv ajustado
rmm_calculada <- nv %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_tn_ajustado = (total_mm / tn_ajustado) * 100000,
    rmm_t_nuestro = (total_mm / nv_oficial_calculado) * 100000,
  ) %>% select(anio, total_mm, nv_oficial_calculado, starts_with("rmm"))



# 4. Comparar con oficial
comparacion_rmm <- rmm_calculada %>%
  left_join(rmm_oficial, by = "anio") %>%
  select(anio, rmm_tn_ajustado, rmm_t_nuestro, rmm_oficial) %>%
  mutate(
    diferencia = round(rmm_t_nuestro - rmm_oficial, 1),
    error_pct = round((diferencia / rmm_oficial) * 100, 2)
  )

print(comparacion_rmm, n = 100)

# 4. Comparar con oficial
comparacion_rmm <- rmm_calculada %>%
  left_join(rmm_oficial, by = "anio") %>%
  select(anio, rmm_tn_ajustado, rmm_oficial) %>%
  mutate(
    diferencia = round(rmm_tn_ajustado - rmm_oficial, 1),
    error_pct = round((diferencia / rmm_oficial) * 100, 2)
  )

# 5. Ver resultados
cat("\n", paste(rep("=", 80), collapse = ""))
cat("\n📊 VALIDACIÓN RMM - TN AJUSTADO VS OFICIAL")
cat("\n", paste(rep("=", 80), collapse = ""), "\n")

print(comparacion_rmm %>% filter(anio >= 2015))

# 6. Conclusión
cat("\n\n✅ Si los errores son <5%, nuestro nv es válido para análisis por educación.")





# ==============================================================================
# GRÁFICO FINAL - RMM COMPARACIÓN CON NOTA TÉCNICA
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(grid)
library(gridExtra)


# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================


rmm_oficial <- data.frame(
  anio = 1990:2024,
  rmm_oficial = c(98.5, 101.0, 105.9, 108.5, 74.8, 52.7, 60.0, 50.1, 47.0, 64.3,
                  71.9, 57.7, 46.1, 42.6, 39.7, 43.8, 41.1, 53.4, 49.8, 62.5,
                  60.7, 72.0, 61.0, 46.7, 50.5, 46.4, 42.0, 46.2, 45.3, 41.7,
                  66.5, 51.6, 41.2, 35.6, 34.2)
)

# ==============================================================================
# 2. CALCULAR RMM
# ==============================================================================

rmm_calculada <- nv %>%
  left_join(maternas, by = "anio") %>%
  mutate(
    rmm_calculada = (total_mm / nv_oficial_calculado) * 100000
  ) %>%
  left_join(rmm_oficial, by = "anio")

# ==============================================================================
# 3. GRÁFICO PRINCIPAL
# ==============================================================================

graf_data <- rmm_calculada %>%
  select(anio, rmm_calculada, rmm_oficial) %>%
  pivot_longer(-anio, names_to = "tipo", values_to = "rmm") %>%
  mutate(tipo = ifelse(tipo == "rmm_calculada", "RMM calculada", "RMM oficial"))

# Crear gráfico
p <- ggplot(graf_data, aes(x = anio, y = rmm, color = tipo)) +
  geom_line(size = 1.2) +
  geom_point(size = 2.5, alpha = 0.8) +
  
  # Escalas
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 250),
    breaks = seq(0, 200, 50),
    labels = scales::comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "RMM calculada" = "#E41A1C",  # rojo
    "RMM oficial" = "#377EB8"      # azul
  )) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna",
    subtitle = "Ecuador 1990-2024 · Comparación con cifras oficiales INEC",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Fuente",
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

# ==============================================================================
# 4. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_comparacion_completa.png"), 
       p, width = 12, height = 7, dpi = 300)

# También guardar versión PDF para informe
ggsave(file.path(ruta_resultados, "RMM_comparacion_completa.pdf"), 
       p, width = 12, height = 7, dpi = 300)

# ==============================================================================
# 5. MOSTRAR EN PANTALLA
# ==============================================================================

print(p)

cat("\n✅ Gráfico generado con nota técnica incluida")
cat("\n📁 Archivos guardados en:", ruta_resultados)
cat("\n   - RMM_comparacion_completa.png")
cat("\n   - RMM_comparacion_completa.pdf")













# ==============================================================================
# RMM POR EDUCACIÓN - SERIE HISTÓRICA COMPLETA (1990-2024)
# ==============================================================================

library(tidyverse)
library(ggplot2)
library(scales)


# ==============================================================================
# 1. CARGAR DATOS
# ==============================================================================

educacion_mort <- read_csv(file.path(ruta_resultados, "mortalidad_materna_por_educacion_1990_2024_FINAL.csv"))

# ==============================================================================
# 2. PREPARAR DATOS - CONSOLIDAR CATEGORÍAS
# ==============================================================================

# Agrupar muertes por nivel educativo (Superior vs Resto)
muertes_educ <- educacion_mort %>%
  mutate(
    nivel_grupo = case_when(
      educ_grupo == "Superior" ~ "Superior",
      educ_grupo %in% c("Primaria", "Secundaria", "Hasta secundaria", "Sin instrucción") ~ "Hasta secundaria",
      educ_grupo == "Sin info" ~ "Sin info",
      TRUE ~ "Otro"
    )
  ) %>%
  group_by(anio, nivel_grupo) %>%
  summarise(
    muertes = sum(maternas, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = anio,
    names_from = nivel_grupo,
    values_from = muertes,
    values_fill = 0
  ) %>%
  rename(
    muertes_superior = Superior,
    muertes_hasta_sec = `Hasta secundaria`,
    muertes_sin_info = `Sin info`
  ) %>% 
  mutate(total = muertes_superior + muertes_sin_info + muertes_hasta_sec, 
         sin_info_per = muertes_sin_info/total, 
         hasta_sec_per = muertes_hasta_sec/total, 
         superior_per = muertes_superior/total)

# ==============================================================================
# 3. UNIR CON nv Y CALCULAR RMM POR EDUCACIÓN
# ==============================================================================

nv <- nv %>% mutate(sin_info_per = `Sin info`/nv_oficial_calculado)

nv %>% select(anio, sin_info_per) %>% print(n = 100)

rmm_educ <- nv %>%
  left_join(muertes_educ, by = "anio") %>%
  mutate(
    # RMM por nivel educativo
    rmm_superior = (muertes_superior / Superior) * 100000,
    rmm_hasta_sec = (muertes_hasta_sec / `Hasta secundaria`) * 100000,
    rmm_sin_info = (muertes_sin_info / `Sin info`) * 100000
  )

# ==============================================================================
# 4. GRÁFICO HISTÓRICO COMPLETO (1990-2024)
# ==============================================================================

# Preparar datos 
graf_historico <- rmm_educ %>%
  filter(!(anio %in% c(2005, 2006, 2007))) %>% 
  select(anio, rmm_superior, rmm_hasta_sec) %>%
  pivot_longer(-anio, names_to = "nivel", values_to = "rmm") %>%
  mutate(
    nivel = case_when(
      nivel == "rmm_superior" ~ "Educación superior",
      nivel == "rmm_hasta_sec" ~ "Hasta secundaria"
    ),
    # Marcar períodos con datos menos confiables
    calidad = ifelse(anio < 2005, "", "")
  ) 

# Gráfico
p_historico <- ggplot(graf_historico, aes(x = anio, y = rmm, color = nivel)) +
  # Líneas
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.7) +
  
  # Línea vertical de separación (2005)
  geom_vline(xintercept = 2004.5, linetype = "dashed", color = "gray50", alpha = 0.5) +
  
  # Escalas
  scale_x_continuous(breaks = seq(1990, 2025, 5)) +
  scale_y_continuous(
    limits = c(0, 300),
    breaks = seq(0, 300, 50),
    labels = comma
  ) +
  
  # Colores
  scale_color_manual(values = c(
    "Educación superior" = "#2E86AB",
    "Hasta secundaria" = "#A23B72"
  )) +
  
  # Etiquetas
  labs(
    title = "Razón de Mortalidad Materna por Nivel Educativo",
    subtitle = "Serie histórica completa 1990-2024 · Ecuador",
    x = "Año",
    y = "RMM (por 100,000 nacidos vivos)",
    color = "Nivel educativo",
    caption = "Línea vertical punteada: 2005 (inicio de datos más confiables). Período 1990-2004 con menor calidad."
  ) +
  
  # Tema
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30", size = 11),
    plot.caption = element_text(hjust = 0, color = "gray40", size = 9, face = "italic"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90")
  )

print(p_historico)

writexl::write_xlsx(graf_historico, file.path(graf_datos_dir, "mortalidad_materna_educacion.xlsx"))

# ==============================================================================
# 5. GUARDAR
# ==============================================================================

ggsave(file.path(ruta_resultados, "RMM_educacion_historica_completa.png"), 
       p_historico, width = 14, height = 8, dpi = 300)

# ==============================================================================
# 6. MOSTRAR
# ==============================================================================


cat("\n✅ Gráfico histórico generado")
cat("\n📁 Guardado en:", file.path(ruta_resultados, "RMM_educacion_historica_completa.png"))

























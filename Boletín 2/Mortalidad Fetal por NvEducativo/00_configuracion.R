# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Configuración inicial y datos del Censo
# boletín 2 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

rm(list = ls())

# librerías ----
library(dplyr)
library(haven)
library(ggplot2)
library(tidyr)
library(scales)
library(forcats)
library(DBI)
library(duckdb)
library(haven)
# install.packages("patchwork")
library(patchwork)
library(tibble)

# Tema de gráficos ----
theme_set(theme_minimal(base_size = 12) +
            theme(
              plot.title = element_text(face = "bold", size = 14),
              plot.subtitle = element_text(color = "gray40"),
              legend.position = "bottom",
              panel.grid.minor = element_blank()
            ))

# Tema para gráficos con desglose por causas (fuente 1.5x más grande)
theme_causas <- theme(
  plot.title = element_text(face = "bold", size = 24),
  plot.subtitle = element_text(color = "gray40", size = 18),
  axis.title = element_text(size = 18),
  axis.text = element_text(size = 16),
  axis.text.y = element_text(size = 16),
  legend.title = element_text(size = 18, face = "bold"),
  legend.text = element_text(size = 16)
)


# Directorios ----
base_dir <- 'C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2'
setwd(base_dir)
output_dir <- file.path(base_dir, "Graficos")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Consultas a base de datos censal (duckdb) ----
# Usar read_only = TRUE para permitir acceso concurrente

con <- dbConnect(duckdb::duckdb(), dbdir = 'C:/Users/Wilson/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Boletín 2/Procesamiento/Bases/Censo/mydb.duckdb', read_only = TRUE)

# Código para crear la tabla censo2022 (ejecutar solo una vez)
# dbExecute(con, "
#   CREATE TABLE censo2022 AS
#   SELECT *
#   FROM read_csv_auto(
#     'Procesamiento/Bases/Censo/BDD_POB_CPV2022_SECT.csv'
#   )
# ")


a <- dbGetQuery(con, "
  SELECT *
  FROM censo2022
  LIMIT 1
") 



# Consultas de población por educación ----
superior_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R >= 8 THEN 'Si'
      ELSE 'No'
    END AS superior,
    COUNT(*) AS n_personas
  FROM censo2022
  GROUP BY superior
") 

superior_censo %>% mutate(percentage = n_personas / sum(n_personas) * 100)

superior_adulto_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R >= 8 THEN 'Si'
      ELSE 'No'
    END AS superior,
    COUNT(*) AS n_personas
  FROM censo2022
  WHERE gedad >= 8
  GROUP BY superior
")

secundaria_joven_censo <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN P17R >= 6 THEN 'Si'
      ELSE 'No'
    END AS secundaria_completa,
    COUNT(*) AS n_personas
  FROM censo2022
  WHERE gedad IN (6, 7)
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

dbDisconnect(con)

# Población de referencia (censo 2022) ----
poblacion_total <- sum(superior_censo$n_personas)

poblacion_grupos <- list(
  jovenes_20_29 = sum(grupo_edad_censo %>% filter(gedad %in% c(6, 7)) %>% pull(n_personas)),
  adultos_30_64 = sum(grupo_edad_censo %>% filter(between(gedad, 8, 14)) %>% pull(n_personas)),
  adultos_mayores_65 = sum(grupo_edad_censo %>% filter(gedad >= 15) %>% pull(n_personas))
)

poblacion_educacion_jovenes <- list(
  secundaria_completa = secundaria_joven_censo[secundaria_joven_censo$secundaria_completa == "Si", "n_personas"],
  secundaria_incompleta = secundaria_joven_censo[secundaria_joven_censo$secundaria_completa == "No", "n_personas"]
)

poblacion_educacion_adultos <- list(
  superior = superior_adulto_censo[superior_adulto_censo$superior == "Si", "n_personas"],
  no_superior = superior_adulto_censo[superior_adulto_censo$superior == "No", "n_personas"]
)


# =============================================================================
# EXTRAPOLACIÓN POBLACIÓN ADULTA CON EDUCACIÓN SUPERIOR
# =============================================================================
# Basado en validación de modelos (ver script validacion_modelos.R)
# Modelo seleccionado: CUADRÁTICO con 4 puntos censales (1990,2001,2010,2022)
# =============================================================================

# Datos censales observados
poblacion_adulta_superior <- data.frame(
  superior =    c(362317, 643564, 1087081, 2205068),
  no_superior = c(4068069, 3673916, 4755803, 6644025),
  anio = c(1990, 2001, 2010, 2022)
)

# Predicción para 1990-2024 usando modelo cuadrático
prediction_data <- data.frame(anio = 1990:2024)

# Modelo cuadrático para superior
modelo_sup <- lm(superior ~ anio + I(anio^2), data = poblacion_adulta_superior)

# Modelo cuadrático para no_superior
modelo_no_sup <- lm(no_superior ~ anio + I(anio^2), data = poblacion_adulta_superior)

# Generar extrapolaciones
extrapolacion_poblacion_adulta_superior <- data.frame(
  anio = 1990:2024,
  superior = predict(modelo_sup, newdata = prediction_data),
  no_superior = predict(modelo_no_sup, newdata = prediction_data)
) %>%
  mutate(
    # Reemplazar con valores reales en años censales
    superior = case_when(
      anio == 1990 ~ poblacion_adulta_superior$superior[1],
      anio == 2001 ~ poblacion_adulta_superior$superior[2],
      anio == 2010 ~ poblacion_adulta_superior$superior[3],
      anio == 2022 ~ poblacion_adulta_superior$superior[4],
      TRUE ~ superior
    ),
    no_superior = case_when(
      anio == 1990 ~ poblacion_adulta_superior$no_superior[1],
      anio == 2001 ~ poblacion_adulta_superior$no_superior[2],
      anio == 2010 ~ poblacion_adulta_superior$no_superior[3],
      anio == 2022 ~ poblacion_adulta_superior$no_superior[4],
      TRUE ~ no_superior
    )
  )

# Verificación rápida
cat("\n=== EXTRAPOLACIÓN ADULTOS (primeros años) ===\n")
print(head(extrapolacion_poblacion_adulta_superior, 10))




# =============================================================================
# EXTRAPOLACIÓN POBLACIÓN JOVEN - VERSIÓN PONDERADA (INTEGRADA)
# =============================================================================

# 1. DATOS CENSALES
censos <- data.frame(
  anio = c(1990, 2001, 2010, 2022),
  comp = c(969076, 685649, 1673093, 2544173),
  inc = c(702603, 1430383, 731732, 298907)
)

# 2. MODELOS
m_comp_1 <- lm(comp ~ anio + I(anio^2), data = censos[censos$anio >= 2001, ])
m_comp_2 <- lm(comp ~ anio + I(anio^2), data = censos)
m_inc_1 <- lm(inc ~ anio + I(anio^2), data = censos[censos$anio >= 2001, ])
m_inc_2 <- lm(inc ~ anio + I(anio^2), data = censos)

# 3. PREDICCIONES
anios_pred <- data.frame(anio = 2000:2024)

pred_comp_1 <- predict(m_comp_1, newdata = anios_pred)
pred_comp_2 <- predict(m_comp_2, newdata = anios_pred)
pred_inc_1 <- predict(m_inc_1, newdata = anios_pred)
pred_inc_2 <- predict(m_inc_2, newdata = anios_pred)

# 4. PESOS (60/40 y 95/5)
proyeccion_2000_2024 <- data.frame(
  anio = 2000:2024,
  comp = 0.6 * pred_comp_1 + 0.4 * pred_comp_2,
  inc = 0.95 * pred_inc_1 + 0.05 * pred_inc_2
)

# 5. FORZAR VALORES CENSALES EXACTOS
proyeccion_2000_2024$comp[proyeccion_2000_2024$anio == 2001] <- 685649
proyeccion_2000_2024$comp[proyeccion_2000_2024$anio == 2010] <- 1673093
proyeccion_2000_2024$comp[proyeccion_2000_2024$anio == 2022] <- 2544173

proyeccion_2000_2024$inc[proyeccion_2000_2024$anio == 2001] <- 1430383
proyeccion_2000_2024$inc[proyeccion_2000_2024$anio == 2010] <- 731732
proyeccion_2000_2024$inc[proyeccion_2000_2024$anio == 2022] <- 298907

# 6. CREAR VERSIÓN COMPLETA (1990-2024)
extrapolacion_poblacion_joven_secundaria <- data.frame(
  anio = 1990:2024,
  secundaria_completa = c(
    rep(969076, 11),  # 1990-2000 (11 años)
    proyeccion_2000_2024$comp[2:25]  # 2001-2024
  ),
  secundaria_incompleta = c(
    rep(702603, 11),  # 1990-2000
    proyeccion_2000_2024$inc[2:25]
  )
)


# 8. VERIFICACIÓN
cat("\n=== PROYECCIÓN JÓVENES PONDERADA ===\n")
cat("2000:\n")
print(extrapolacion_poblacion_joven_secundaria %>% filter(anio == 2000))
cat("2024:\n")
print(extrapolacion_poblacion_joven_secundaria %>% filter(anio == 2024))

# =============================================================================
# LIMPIEZA FINAL - ELIMINAR DUPLICADOS
# =============================================================================

# Eliminar filas duplicadas (quedarse con la primera)
extrapolacion_poblacion_joven_secundaria <- extrapolacion_poblacion_joven_secundaria %>%
  distinct(anio, .keep_all = TRUE)

# Verificar que ahora solo hay una fila por año
cat("\n=== VERIFICACIÓN FINAL (sin duplicados) ===\n")
cat("2000:\n")
print(extrapolacion_poblacion_joven_secundaria %>% filter(anio == 2000))
cat("2024:\n")
print(extrapolacion_poblacion_joven_secundaria %>% filter(anio == 2024))



# Datos de pobreza por parroquia (nbi) ----
cat("\nCargando datos de pobreza por parroquia...\n")

pobreza_raw <- read.csv(
  file.path(base_dir, "Procesamiento/Bases/Censo/NBI/pobreza_nbi_con_dpa_2022.csv"),
  stringsAsFactors = FALSE
)

# Limpiar valores numéricos (quitar comas)
pobreza_raw <- pobreza_raw %>%
  mutate(across(c(total_personas, no_pobres_total, pobres_total), 
                ~as.numeric(gsub(",", "", .))))

# Calcular porcentaje de pobreza y preparar código dpa
pobreza <- pobreza_raw %>%
  mutate(
    pct_pobreza = pobres_total / total_personas * 100,
    cod_parroquia = sprintf("%06d", as.numeric(dpa_parroquia))
  ) %>%
  select(provincia, canton, parroquia, cod_parroquia, total_pob = total_personas, 
         pobre_total = pobres_total, pct_pobreza)

# Clasificar parroquias por terciles de pobreza
pobreza <- pobreza %>%
  mutate(
    nivel_pobreza = case_when(
      between(pct_pobreza, 0, 30) ~ "Menor pobreza",
      between(pct_pobreza, 30, 60) ~ "Pobreza media",
      TRUE ~ "Mayor pobreza"
    )
  )

cat("Distribución de parroquias por nivel de pobreza:\n")
print(table(pobreza$nivel_pobreza))

# Población por nivel de pobreza
poblacion_pobreza <- pobreza %>%
  group_by(nivel_pobreza) %>%
  summarise(poblacion = sum(total_pob, na.rm = TRUE), .groups = "drop")


poblacion_pobreza %>%
  mutate(percentage = poblacion / sum(poblacion) * 100)

poblacion_pobreza$nivel_pobreza <- factor(
  poblacion_pobreza$nivel_pobreza,
  levels = c("Mayor pobreza", "Pobreza media", "Menor pobreza")
)

cat("\nPoblación por nivel de pobreza:\n")
print(poblacion_pobreza)

# DataFrame de parroquias con datos de pobreza para joins
df_parroquias_pobreza <- pobreza %>%
  select(cod_parroquia, pct_pobreza, nivel_pobreza, total_pob)

cat("\nParroquias con datos de pobreza:", nrow(df_parroquias_pobreza), "\n")

# Colores para gráficos de pobreza
colores_pobreza <- c(
  "Menor pobreza" = "#27AE60",
  "Pobreza media" = "#F39C12",
  "Mayor pobreza" = "#E74C3C"
)

cat("Población total:", format(poblacion_total, big.mark = ","), "\n")


# AL FINAL DE 00_configuracion.R, después de todo, agrega:

cat("\n=== VERIFICACIÓN DE EXTRAPOLACIONES ===\n")
cat("Rango de años en extrapolacion_poblacion_adulta_superior:\n")
print(range(extrapolacion_poblacion_adulta_superior$anio))

cat("\nValores para 2000:\n")
print(extrapolacion_poblacion_adulta_superior %>% filter(anio == 2000))

cat("\nRango de años en extrapolacion_poblacion_joven_secundaria:\n")
print(range(extrapolacion_poblacion_joven_secundaria$anio))

cat("\nValores para 2000:\n")
print(extrapolacion_poblacion_joven_secundaria %>% filter(anio == 2000))


# =============================================================================
# GUARDAR VARIABLES CORREGIDAS PARA USAR EN GRÁFICOS
# =============================================================================

cat("\n=== GUARDANDO VARIABLES CORREGIDAS ===\n")

saveRDS(extrapolacion_poblacion_joven_secundaria, 
        file.path(base_dir, "Procesamiento", "Bases", "extrapolacion_joven_corregida.rds"))

saveRDS(extrapolacion_poblacion_adulta_superior, 
        file.path(base_dir, "Procesamiento", "Bases", "extrapolacion_adulta_corregida.rds"))

saveRDS(df_parroquias_pobreza, 
        file.path(base_dir, "Procesamiento", "Bases", "pobreza_corregida.rds"))

saveRDS(colores_pobreza, 
        file.path(base_dir, "Procesamiento", "Bases", "colores_pobreza.rds"))

saveRDS(poblacion_pobreza, 
        file.path(base_dir, "Procesamiento", "Bases", "poblacion_pobreza.rds"))

cat("✅ Variables guardadas correctamente\n")

                                                  
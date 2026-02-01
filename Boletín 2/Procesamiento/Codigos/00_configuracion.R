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
base_dir <- '/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 2'
setwd(base_dir)
output_dir <- file.path(base_dir, "Graficos")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Consultas a base de datos censal (duckdb) ----
# Usar read_only = TRUE para permitir acceso concurrente

con <- dbConnect(duckdb::duckdb(), dbdir = 'Procesamiento/Bases/Censo/mydb.duckdb', read_only = TRUE)

# Código para crear la tabla censo2022 (ejecutar solo una vez)
# dbExecute(con, "
#   CREATE TABLE censo2022 AS
#   SELECT *
#   FROM read_csv_auto(
#     'Procesamiento/Bases/Censo/BDD_POB_CPV2022_SECT.csv'
#   )
# ")

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


# Extrapolacion poblacion censal adulta con educacion superior ----

# poblacion adulta de los censos 2001, 2010 y 2022, obtenida de redatam:
# https://redatam.inec.gob.ec/binecu/RpWebEngine.exe/Portal?BASE=CPV2001

poblacion_adulta_superior <- data.frame(superior =    c(643564, 1087081, 2205068),
                                        no_superior = c(3673916, 4755803, 6644025),
                                        anio = c(2001, 2010, 2022))

prediction_data <- data.frame(anio = 2001:2024)

extrapolacion_poblacion_adulta_superior <- 
data.frame(
  anio = c(2001:2024),
superior = predict(
    lm(superior ~ anio + I(anio ^2), data = poblacion_adulta_superior), 
          newdata = prediction_data
          ), 
  no_superior = predict(
    lm(no_superior ~ anio + I(anio ^2), data = poblacion_adulta_superior), 
          newdata = prediction_data
          )
) %>%
 mutate(superior =    case_when(anio == 2001 ~ poblacion_adulta_superior$superior[1],
                                anio == 2010 ~ poblacion_adulta_superior$superior[2],
                                anio == 2022 ~ poblacion_adulta_superior$superior[3],
                                TRUE ~ superior), 
        no_superior = case_when(anio == 2001 ~ poblacion_adulta_superior$no_superior[1],
                                anio == 2010 ~ poblacion_adulta_superior$no_superior[2],
                                anio == 2022 ~ poblacion_adulta_superior$no_superior[3],
                                TRUE ~ no_superior))


# Grafico extrapolacion cuadratica

# First, determine the range of your data
x_limits <- range(poblacion_adulta_superior$anio)
y_limits <- range(poblacion_adulta_superior$superior)


plot1 <- ggplot(poblacion_adulta_superior, aes(x = anio, y = superior)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x + I(x^2), se = TRUE, color = "blue") +
  coord_cartesian(xlim = x_limits, ylim = y_limits) +  # Set fixed limits
  labs(
    x = "Año",
    y = "Educacion superior"
  ) +
  theme_minimal()



plot2 <- ggplot(poblacion_adulta_superior, aes(x = anio, y = no_superior)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x + I(x^2), se = FALSE, color = "blue") +
#  coord_cartesian(xlim = x_limits, ylim = y_limits) +  # Set fixed limits
  labs(
    title = "",
    x = "Año",
    y = "No educacion superior"
  ) +
  theme_minimal()

plot1 + plot2


# Extrapolacion poblacion censal joven con secundaria completa ----

# poblacion joven de los censos 2001, 2010 y 2022, obtenida de redatam:
# https://redatam.inec.gob.ec/binecu/RpWebEngine.exe/Portal?BASE=CPV2001

poblacion_joven_secundaria <- data.frame(secundaria_completa =   c(685649, 1673093, 2544173), 
                                         secundaria_incompleta = c(1430383, 731732, 298907),
                                         anio = c(2001, 2010, 2022))

prediction_data <- data.frame(anio = 2001:2024)

extrapolacion_poblacion_joven_secundaria <- 
data.frame(
  anio = c(2001:2024),
secundaria_completa = predict(
    lm(secundaria_completa ~ anio + I(anio ^2), data = poblacion_joven_secundaria), 
          newdata = prediction_data
          ), 
  secundaria_incompleta = predict(
    lm(secundaria_incompleta ~ anio + I(anio ^2), data = poblacion_joven_secundaria), 
          newdata = prediction_data
          )
) %>%
mutate(secundaria_completa =    case_when(anio == 2001 ~ poblacion_joven_secundaria$secundaria_completa[1],
                                anio == 2010 ~ poblacion_joven_secundaria$secundaria_completa[2],
                                anio == 2022 ~ poblacion_joven_secundaria$secundaria_completa[3],
                                TRUE ~ secundaria_completa), 
        secundaria_incompleta = case_when(anio == 2001 ~ poblacion_joven_secundaria$secundaria_incompleta[1],
                                anio == 2010 ~ poblacion_joven_secundaria$secundaria_incompleta[2],
                                anio == 2022 ~ poblacion_joven_secundaria$secundaria_incompleta[3],
                                TRUE ~ secundaria_incompleta))


# Grafico extrapolacion cuadratica
plot3 <- ggplot(poblacion_joven_secundaria, aes(x = anio, y = secundaria_completa)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x + I(x^2), se = TRUE, color = "blue") +
  labs(
    title = "",
    x = "Año",
    y = "Secundaria Completa"
  ) +
  theme_minimal()


plot4 <- ggplot(poblacion_joven_secundaria, aes(x = anio, y = secundaria_incompleta)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x + I(x^2), se = TRUE, color = "blue") +
  labs(
    title = "",
    x = "Año",
    y = "Secundaria Incompleta"
  ) +
  theme_minimal()

plot3 + plot4


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


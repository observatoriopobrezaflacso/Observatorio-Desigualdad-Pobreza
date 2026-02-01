# =============================================================================
# Regresión parroquial: tasa de mortalidad vs educación (control: pobreza)
# Boletín 2 - Observatorio de Políticas Públicas
#
# Objetivo:
# - Crear un dataframe parroquial con:
#   (i) tasa de mortalidad 2024 (defunciones / población parroquial * 1,000)
#   (ii) pobreza (pct_pobreza y nivel_pobreza) desde df_parroquias_pobreza
#   (iii) educación (porcentaje universitario en 30+ años) desde censo2022 (DuckDB)
# - Estimar regresiones simples y con control por pobreza
# - Guardar tabla y un gráfico de dispersión
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(DBI)
  library(duckdb)
})

cat("\n========== REGRESIÓN PARROQUIAL: EDUCACIÓN Y MORTALIDAD ==========\n")

# Asegurar configuración base (directorios, pobreza, etc.) ----
if (!exists("base_dir") || !exists("output_dir") || !exists("df_parroquias_pobreza")) {
  source("Procesamiento/Codigos/00_configuracion.R")
}

# Cargar defunciones 2024 y construir código parroquial comparable a pobreza ----
defunciones <- readRDS(file.path(base_dir, "Procesamiento/Bases/Defunciones/EDG_2024.rds"))

defunciones <- defunciones %>%
  mutate(
    cod_parroquia = {
      cod_raw <- suppressWarnings(as.numeric(as.character(parr_fall)))
      cod_str <- sprintf("%06d", cod_raw)
      # Extraer los últimos dos dígitos y forzar a "50" si es menor a 50
      # (para compatibilidad con parroquias creadas 2022-2024 no presentes en el censo 2022)
      cod_num <- suppressWarnings(as.numeric(substr(cod_str, 5, 6)))
      ifelse(cod_num < 50, paste0(substr(cod_str, 1, 4), "50"), cod_str)
    }
  )

defunciones_parroquia <- defunciones %>%
  filter(!is.na(cod_parroquia)) %>%
  group_by(cod_parroquia, area_fall) %>%
  count(cod_parroquia, name = "defunciones_2024")

# Educación parroquial desde Censo (DuckDB) ----
con <- dbConnect(
  duckdb::duckdb(),
  dbdir = file.path(base_dir, "Procesamiento/Bases/Censo/mydb.duckdb"),
  read_only = TRUE
)
on.exit(dbDisconnect(con), add = TRUE)

edu_parro <- dbGetQuery(con, "
  SELECT
    CAST(PARROQ AS INTEGER) AS PARROQ,
    SUM(CASE WHEN GEDAD >= 8 THEN 1 ELSE 0 END) AS pob_30plus,
    SUM(CASE WHEN GEDAD >= 8 AND P17R > 8 THEN 1 ELSE 0 END) AS univ_30plus
  FROM censo2022
  GROUP BY PARROQ
")

edu_parro <- edu_parro %>%
  mutate(
    cod_parroquia = sprintf("%06d", PARROQ),
    pct_univ_30plus = ifelse(pob_30plus > 0, univ_30plus / pob_30plus * 100, NA_real_)
  ) %>%
  select(cod_parroquia, pob_30plus, univ_30plus, pct_univ_30plus)

# Panel parroquial: mortalidad + pobreza + educación ----
df_parroquias_panel <- df_parroquias_pobreza %>%
  select(cod_parroquia, total_pob, pct_pobreza, nivel_pobreza) %>%
  left_join(defunciones_parroquia, by = "cod_parroquia") %>%
  left_join(edu_parro, by = "cod_parroquia") %>%
  mutate(
    defunciones_2024 = replace_na(defunciones_2024, 0L),
    tasa_mortalidad_1000 = ifelse(!is.na(total_pob) & total_pob > 0,
                                 defunciones_2024 / total_pob * 1000,
                                 NA_real_)) %>%
  mutate(
    provincia = substr(cod_parroquia, 1, 2),
    region = case_when(
      provincia %in% c("07", "08", "09", "12", "13", "23", "24") ~ "Costa",
      provincia %in% c("01", "02", "03", "04", "05", "06",
                        "10", "11", "17", "18") ~ "Sierra",
      provincia %in% c("14", "15", "16", "19", "21", "22") ~ "Amazonía",
      provincia == "20" ~ "Galápagos",
      
      TRUE ~ NA_character_
    )
  )
  

cat("Parroquias en panel:", nrow(df_parroquias_panel), "\n")
cat("Parroquias con educación (pct_univ_30plus no NA):", sum(!is.na(df_parroquias_panel$pct_univ_30plus)), "\n")
cat("Parroquias con tasa de mortalidad (tasa_mortalidad_1000 no NA):", sum(!is.na(df_parroquias_panel$tasa_mortalidad_1000)), "\n")

# Regresiones ----
df_reg <- df_parroquias_panel %>%
  filter(
    !is.na(tasa_mortalidad_1000),
    !is.na(pct_univ_30plus),
    !is.na(pct_pobreza)
  )

modelo_educ_simple <- lm(
  tasa_mortalidad_1000 ~ pct_univ_30plus,
  data = df_reg,
  weights = total_pob
)

modelo_educ_pobreza <- lm(
  tasa_mortalidad_1000 ~ pct_univ_30plus + pct_pobreza,
  data = df_reg,
  weights = total_pob
)

cat("\n--- Regresión (ponderada por población): tasa ~ educación ---\n")
print(summary(modelo_educ_simple))

cat("\n--- Regresión (ponderada por población): tasa ~ educación + pobreza ---\n")
print(summary(modelo_educ_pobreza))



m3 <- lm(
  tasa_mortalidad_1000 ~  pct_pobreza,
  data = df_reg,
  weights = total_pob
)

summary(m3)

df_reg %>% 
group_by(nivel_pobreza, region) %>% 
summarise(defunciones = sum(defunciones_2024), 
total_pob = sum(total_pob)) %>% 
mutate(tasa_mortalidad_1000 = defunciones / total_pob * 1000) %>%
arrange(region) 

df_reg %>% 
group_by(nivel_pobreza, area_fall, region) %>% 
summarise(defunciones = sum(defunciones_2024), 
total_pob = sum(total_pob)) %>% 
mutate(tasa_mortalidad_1000 = defunciones / total_pob * 1000) %>%
arrange(area_fall, region) 


# Guardar resultados ----
dir_tablas <- file.path(base_dir, "Procesamiento/Tablas")
if (!dir.exists(dir_tablas)) dir.create(dir_tablas, recursive = TRUE)

write.csv(
  df_parroquias_panel,
  file = file.path(dir_tablas, "df_parroquias_panel_mortalidad_pobreza_educacion.csv"),
  row.names = FALSE
)

dir_resultados <- file.path(base_dir, "Procesamiento/Resultados")
if (!dir.exists(dir_resultados)) dir.create(dir_resultados, recursive = TRUE)

writeLines(
  c(
    "REGRESIÓN PARROQUIAL: tasa de mortalidad vs educación (control: pobreza)",
    "",
    "Modelo 1: tasa_mortalidad_1000 ~ pct_univ_30plus (ponderado por total_pob)",
    capture.output(summary(modelo_educ_simple)),
    "",
    "Modelo 2: tasa_mortalidad_1000 ~ pct_univ_30plus + pct_pobreza (ponderado por total_pob)",
    capture.output(summary(modelo_educ_pobreza))
  ),
  con = file.path(dir_resultados, "regresion_parroquial_educacion_pobreza.txt")
)



# Gráfico: dispersión educación vs mortalidad (coloreado por nivel de pobreza) ----
g_reg <- ggplot(df_reg, aes(x = pct_univ_30plus, y = tasa_mortalidad_1000, color = nivel_pobreza)) +
  geom_point(alpha = 0.35, size = 1.8) +
  geom_smooth(method = "lm", se = TRUE, color = "gray20", linewidth = 0.8) +
  scale_color_manual(values = colores_pobreza, drop = FALSE) +
  labs(
    title = "Mortalidad y educación a nivel parroquial",
    subtitle = "Ecuador (Censo 2022 + Defunciones 2024) — línea: regresión OLS (ponderada por población)",
    x = "% de población 30+ con educación universitaria (Censo 2022)",
    y = "Tasa de mortalidad 2024 por 1,000 habitantes (población parroquial Censo 2022)",
    color = "Pobreza (NBI)"
  ) +
  theme(legend.position = "bottom")

ggsave(
  filename = file.path(output_dir, "regresion_mortalidad_educacion_parroquial.png"),
  plot = g_reg,
  width = 10,
  height = 6.5,
  dpi = 300,
  bg = "white"
)

cat("\nGuardado:\n")
cat("- Tabla:", file.path(dir_tablas, "df_parroquias_panel_mortalidad_pobreza_educacion.csv"), "\n")
cat("- Resultados:", file.path(dir_resultados, "regresion_parroquial_educacion_pobreza.txt"), "\n")
cat("- Gráfico:", file.path(output_dir, "regresion_mortalidad_educacion_parroquial.png"), "\n")


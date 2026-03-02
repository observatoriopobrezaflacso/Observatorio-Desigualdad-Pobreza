# ═══════════════════════════════════════════════════════════════════════════════
# OBSERVATORIO DE DESIGUALDAD Y POBREZA - ECUADOR 2022
# Análisis: Mortalidad Infantil (TMI) vs Pobreza por NBI - Nivel Parroquial
# ═══════════════════════════════════════════════════════════════════════════════

library(tidyverse)
library(readxl)
library(scales)

base_dir <- "C:/Users/user/Observatorio-Desigualdad-Pobreza"
setwd(base_dir)

# ── PASO 1: CATÁLOGO DPA INEC 2022 ───────────────────────────────────────────

catalogo_dpa <- read.csv("catalogo_dpa_2022.csv", colClasses = "character") %>%
    mutate(
        nombre_parr_clean = str_to_upper(str_trim(
            iconv(nombre_parroquia, from = "UTF-8", to = "ASCII//TRANSLIT")
        ))
    )

nombres_prov <- tribble(
    ~cod_prov, ~nombre_prov_clean,
    "01", "AZUAY", "02", "BOLIVAR", "03", "CANAR",
    "04", "CARCHI", "05", "COTOPAXI", "06", "CHIMBORAZO",
    "07", "EL ORO", "08", "ESMERALDAS", "09", "GUAYAS",
    "10", "IMBABURA", "11", "LOJA", "12", "LOS RIOS",
    "13", "MANABI", "14", "MORONA SANTIAGO", "15", "NAPO",
    "16", "PASTAZA", "17", "PICHINCHA", "18", "TUNGURAHUA",
    "19", "ZAMORA CHINCHIPE", "20", "GALAPAGOS", "21", "SUCUMBIOS",
    "22", "ORELLANA", "23", "SANTO DOMINGO DE LOS TSACHILAS",
    "24", "SANTA ELENA", "90", "ZONAS NO DELIMITADAS"
)

nombres_canton <- catalogo_dpa %>%
    filter(cod_parr == "50") %>%
    select(cod_prov, cod_cant, nombre_canton_clean = nombre_parr_clean)

catalogo_completo <- catalogo_dpa %>%
    left_join(nombres_prov, by = "cod_prov") %>%
    left_join(nombres_canton, by = c("cod_prov", "cod_cant"))

cat("✔ Catálogo DPA cargado:", nrow(catalogo_dpa), "parroquias\n")

# ── PASO 2: TMI - AGREGAR BARRIOS URBANOS EN CÓDIGO 50 ───────────────────────
# Los barrios urbanos (01-49) se consolidan en código 50 (cabecera cantonal)
# Esto reduce parcialmente el efecto hospital dentro del mismo cantón

tmi_data <- read.csv("mortalidad_infantil_parroquial_2022.csv",
    colClasses = c("cod_parroquia" = "character")
)

tmi_agregada <- tmi_data %>%
    mutate(
        prov = substr(cod_parroquia, 1, 2),
        cant = substr(cod_parroquia, 3, 4),
        parr = substr(cod_parroquia, 5, 6),
        parr_num = suppressWarnings(as.numeric(parr)),
        parr_final = case_when(
            !is.na(parr_num) & parr_num >= 1 & parr_num < 50 ~ "50",
            TRUE ~ parr
        ),
        cod_final = paste0(prov, cant, parr_final)
    ) %>%
    group_by(cod_parroquia = cod_final) %>%
    summarise(
        defunciones = sum(as.numeric(defunciones), na.rm = TRUE),
        nacimientos = sum(as.numeric(nacimientos), na.rm = TRUE),
        .groups = "drop"
    )

cat("✔ TMI procesada:", nrow(tmi_agregada), "parroquias\n")

# ── PASO 3: NBI - NORMALIZAR NOMBRES Y ASIGNAR CÓDIGO DPA ────────────────────

normalizar <- function(x) {
    str_to_upper(str_trim(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")))
}

pobreza_nbi <- read_excel("Pobreza_NBI_2022_Final.xlsx") %>%
    mutate(
        prov_clean = normalizar(Provincia),
        cant_clean = normalizar(Canton),
        parr_clean = normalizar(Parroquia)
    )

# Join triple por provincia + cantón + parroquia (evita duplicados)
nbi_con_codigo <- pobreza_nbi %>%
    left_join(
        catalogo_completo %>%
            select(cod_parroquia, nombre_prov_clean, nombre_canton_clean, nombre_parr_clean),
        by = c(
            "prov_clean" = "nombre_prov_clean",
            "cant_clean" = "nombre_canton_clean",
            "parr_clean" = "nombre_parr_clean"
        )
    )

sin_codigo <- nbi_con_codigo %>% filter(is.na(cod_parroquia))
cat("✔ NBI con código:", sum(!is.na(nbi_con_codigo$cod_parroquia)), "\n")
cat("⚠ NBI sin código:", nrow(sin_codigo), "(revisar correcciones manuales si > 0)\n")

if (nrow(sin_codigo) > 0) {
    cat("\nParroquias sin código:\n")
    print(sin_codigo %>% select(Provincia, Canton, Parroquia))
}

# ── PASO 4: CORRECCIONES MANUALES DE NOMBRES ─────────────────────────────────
# Si el paso anterior mostró parroquias sin código, agrégalas aquí

correcciones <- tribble(
    ~prov_clean, ~cant_clean, ~parr_clean_mal, ~parr_clean_bien
    # Ejemplo:
    # "AZUAY", "CUENCA", "BANOS", "BANOS DE AGUA SANTA"
)

# ── PASO 5: MERGE FINAL TMI + NBI ────────────────────────────────────────────

analisis_final <- nbi_con_codigo %>%
    left_join(tmi_agregada, by = "cod_parroquia") %>%
    mutate(
        defunciones  = as.numeric(defunciones),
        nacimientos  = as.numeric(nacimientos),
        tmi_tasa     = (defunciones / nacimientos) * 1000,
        tasa_nbi_num = as.numeric(Tasa_NBI)
    )

vinculadas <- sum(!is.na(analisis_final$defunciones))
total <- nrow(analisis_final)
cat(sprintf(
    "✔ Parroquias vinculadas: %d de %d (%.1f%%)\n",
    vinculadas, total, vinculadas / total * 100
))

# Control Cuenca
cat("\nControl Cuenca (010150):\n")
print(analisis_final %>%
    filter(cod_parroquia == "010150") %>%
    select(Parroquia, cod_parroquia, tasa_nbi_num, defunciones, nacimientos, tmi_tasa))

# ── PASO 6: PREPARAR DATOS PARA GRÁFICO ──────────────────────────────────────

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
        nac_num >= 100, # mínimo para tasa confiable
        tmi_num < 150 # eliminar outliers extremos
    )

# Excluir Quito y Guayaquil (efecto hospital nacional)
analisis_grafico_final <- analisis_grafico %>%
    filter(!cod_parroquia %in% c("170150", "090150"))

cat(sprintf("\n✔ Parroquias en gráfico: %d\n", nrow(analisis_grafico_final)))

# Resumen por nivel de pobreza
resumen <- analisis_grafico_final %>%
    group_by(nivel_pobreza) %>%
    summarise(
        tmi_promedio = round(mean(tmi_num, na.rm = TRUE), 2),
        total_parroquias = n(),
        .groups = "drop"
    )
cat("\nResumen por nivel de pobreza:\n")
print(resumen)

# ── PASO 7: GRÁFICO FINAL ────────────────────────────────────────────────────

grafico <- ggplot(analisis_grafico_final, aes(x = nbi_num, y = tmi_num)) +
    geom_point(aes(size = nac_num, color = nivel_pobreza), alpha = 0.6) +
    geom_smooth(
        method = "lm", se = TRUE,
        color = "black", linetype = "dashed"
    ) +
    scale_color_manual(values = c(
        "Baja Pobreza"  = "#27ae60",
        "Pobreza Media" = "#f1c40f",
        "Alta Pobreza"  = "#e74c3c"
    )) +
    scale_size_continuous(range = c(2, 18), labels = comma) +
    labs(
        title = "Ecuador 2022: Pobreza Estructural y Mortalidad Infantil",
        subtitle = paste0(
            "Parroquias con ≥100 nacimientos (n=", nrow(analisis_grafico_final),
            ") · Excluye Quito y Guayaquil"
        ),
        x = "Pobreza por NBI (%)",
        y = "Tasa de Mortalidad Infantil (por 1.000 NV)",
        size = "Nacimientos",
        color = "Nivel de Pobreza",
        caption = paste0(
            "Nota: Se excluyen Quito y Guayaquil por concentrar hospitales de referencia nacional\n",
            "que sobreestiman la TMI local. Parroquias urbanas agregadas en código 50 (cabecera cantonal).\n",
            "Fuente: Observatorio de Desigualdad y Pobreza (Censo 2022 / EDG 2022)"
        )
    ) +
    theme_minimal() +
    theme(
        legend.position  = "bottom",
        plot.title       = element_text(face = "bold"),
        plot.caption     = element_text(hjust = 1, size = 8)
    )

print(grafico)
ggsave("grafico_tmi_nbi_FINAL.png", plot = grafico, width = 12, height = 8, dpi = 150)

# ── PASO 8: EXPORTAR BASE FINAL ───────────────────────────────────────────────

write.csv(analisis_final, "analisis_tmi_nbi_2022.csv", row.names = FALSE)
cat("\n✔ Exportado: analisis_tmi_nbi_2022.csv\n")
cat("✔ Exportado: grafico_tmi_nbi_FINAL.png\n")
cat("\n══════════════════════════════════════\n")
cat("PROCESO COMPLETO\n")
cat("══════════════════════════════════════\n")

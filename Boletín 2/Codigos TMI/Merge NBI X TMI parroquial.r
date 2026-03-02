# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT CORREGIDO: MERGE TMI + NBI - ECUADOR 2022
# ═══════════════════════════════════════════════════════════════════════════════
library(tidyverse)
library(readxl)

base_dir <- "C:/Users/user/Observatorio-Desigualdad-Pobreza"
setwd(base_dir)

# ── PASO 1: CATÁLOGO DPA ──────────────────────────────────────────────────────

catalogo_dpa <- read.csv("catalogo_dpa_2022.csv", colClasses = "character") %>%
    mutate(
        nombre_parr_clean = str_to_upper(str_trim(
            iconv(nombre_parroquia, from = "UTF-8", to = "ASCII//TRANSLIT")
        ))
    )

# Tabla de nombres de provincia (manual, son solo 24)
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

# Nombre del cantón = nombre de la cabecera urbana (cod_parr == "50")
nombres_canton <- catalogo_dpa %>%
    filter(cod_parr == "50") %>%
    select(cod_prov, cod_cant, nombre_canton_clean = nombre_parr_clean)

# Catálogo enriquecido con los tres niveles de nombre
catalogo_completo <- catalogo_dpa %>%
    left_join(nombres_prov, by = "cod_prov") %>%
    left_join(nombres_canton, by = c("cod_prov", "cod_cant"))

# ── PASO 2: TMI - AGREGAR BARRIOS URBANOS EN CÓDIGO 50 ───────────────────────

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

# ── PASO 3: NBI - NORMALIZAR NOMBRES Y OBTENER CÓDIGO DPA ────────────────────

normalizar <- function(x) {
    str_to_upper(str_trim(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")))
}

pobreza_nbi <- read_excel("Pobreza_NBI_2022_Final.xlsx") %>%
    mutate(
        prov_clean = normalizar(Provincia),
        cant_clean = normalizar(Canton),
        parr_clean = normalizar(Parroquia)
    )

# Join triple: los tres nombres a la vez → código único garantizado
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

# ── PASO 4: DIAGNÓSTICO DE NOMBRES QUE NO COINCIDIERON ───────────────────────

sin_codigo <- nbi_con_codigo %>% filter(is.na(cod_parroquia))

cat("══════════════════════════════════════\n")
cat("CON código:", sum(!is.na(nbi_con_codigo$cod_parroquia)), "\n")
cat("SIN código:", nrow(sin_codigo), "\n")

if (nrow(sin_codigo) > 0) {
    cat("\nCasos sin código - necesitan corrección manual:\n")
    print(sin_codigo %>% select(Provincia, Canton, Parroquia))

    # Ayuda para identificar la corrección: buscar en el catálogo nombres similares
    cat("\nBúsqueda de coincidencias aproximadas en el catálogo:\n")
    for (i in 1:min(nrow(sin_codigo), 10)) {
        parr_buscar <- sin_codigo$parr_clean[i]
        matches <- catalogo_completo %>%
            filter(str_detect(nombre_parr_clean, substr(parr_buscar, 1, 5))) %>%
            select(cod_parroquia, nombre_prov_clean, nombre_canton_clean, nombre_parr_clean) %>%
            head(3)
        cat(sprintf("  '%s' → posibles matches:\n", parr_buscar))
        print(matches)
    }
}

# ── PASO 5: CORRECCIONES MANUALES ────────────────────────────────────────────
# Después de ver el output del paso 4, llena este tribble.
# La columna "en_nbi" es lo que dice tu archivo, "en_catalogo" es lo que dice el INEC.

correcciones <- tribble(
    ~prov_clean, ~cant_clean, ~parr_clean_mal, ~parr_clean_bien,
    # Ejemplos típicos de Ecuador - ajusta con tu output real:
    # "AZUAY",    "CUENCA",      "BANOS",               "BANOS DE AGUA SANTA",
    # "MANABI",   "PORTOVIEJO",  "SUCRE",               "SUCRE",
)

if (nrow(correcciones) > 0) {
    nbi_con_codigo <- nbi_con_codigo %>%
        left_join(correcciones,
            by = c("prov_clean", "cant_clean", "parr_clean" = "parr_clean_mal")
        ) %>%
        mutate(
            parr_clean = coalesce(parr_clean_bien, parr_clean)
        ) %>%
        select(-parr_clean_bien) %>%
        # Re-hacer join solo para los que siguen sin código
        rows_update(
            filter(., !is.na(parr_clean_bien)) %>% # solo los corregidos
                select(-cod_parroquia) %>%
                left_join(
                    catalogo_completo %>%
                        select(cod_parroquia, nombre_prov_clean, nombre_canton_clean, nombre_parr_clean),
                    by = c(
                        "prov_clean" = "nombre_prov_clean",
                        "cant_clean" = "nombre_canton_clean",
                        "parr_clean" = "nombre_parr_clean"
                    )
                ),
            by = names(pobreza_nbi) # clave de actualización
        )
}

# ── PASO 6: MERGE FINAL ───────────────────────────────────────────────────────

analisis_final <- nbi_con_codigo %>%
    left_join(tmi_agregada, by = "cod_parroquia") %>%
    mutate(
        defunciones  = as.numeric(defunciones),
        nacimientos  = as.numeric(nacimientos),
        tmi_tasa     = (defunciones / nacimientos) * 1000,
        tasa_nbi_num = as.numeric(Tasa_NBI)
    )

# ── PASO 7: CONTROL DE CALIDAD ────────────────────────────────────────────────

cat("\nCONTROL - CUENCA (010150):\n")
print(analisis_final %>%
    filter(cod_parroquia == "010150") %>%
    select(Parroquia, cod_parroquia, tasa_nbi_num, defunciones, nacimientos, tmi_tasa))

vinculadas <- sum(!is.na(analisis_final$defunciones))
total <- nrow(analisis_final)
cat(sprintf(
    "\n✔ Parroquias vinculadas: %d de %d (%.1f%%)\n",
    vinculadas, total, vinculadas / total * 100
))

write.csv(analisis_final, "analisis_tmi_nbi_2022.csv", row.names = FALSE)
cat("Exportado: analisis_tmi_nbi_2022.csv\n")

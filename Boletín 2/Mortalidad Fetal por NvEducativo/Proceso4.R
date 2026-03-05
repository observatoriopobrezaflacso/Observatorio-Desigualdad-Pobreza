# ═══════════════════════════════════════════════════════════════════════════════
# SERIE HISTÓRICA MORTALIDAD FETAL POR EDUCACIÓN 2000-2024
# ═══════════════════════════════════════════════════════════════════════════════

library(tidyverse)
library(haven)

carpeta_edf <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos"
carpeta_env <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV"

# ── FUNCIÓN: Clasificar superior según año y base ─────────────────────────────
es_superior <- function(niv, anio, base) {
  
  # Convertir a character limpio para manejar strings y numéricos igual
  niv <- as.character(niv)
  niv <- str_trim(niv)
  # Quitar ceros a la izquierda para normalizar "07" → "7"
  niv_num <- suppressWarnings(as.numeric(niv))
  
  if (base == "EDF") {
    case_when(
      # 2000-2004: escala 1-5, Superior = 5
      anio %in% 2000:2004 & niv_num == 5                  ~ TRUE,
      anio %in% 2000:2004 & niv_num == 9                  ~ NA,
      anio %in% 2000:2004 & !is.na(niv_num)               ~ FALSE,
      
      # 2005-2009: escala 0-9, Superior = 7,8
      anio %in% 2005:2009 & niv_num %in% c(7, 8)          ~ TRUE,
      anio %in% 2005:2009 & niv_num == 9                  ~ NA,
      anio %in% 2005:2009 & !is.na(niv_num)               ~ FALSE,
      
      # 2010: COD_INSTRUCCION 0-9 sin labels, misma escala que 2009
      anio == 2010        & niv_num %in% c(7, 8)          ~ TRUE,
      anio == 2010        & niv_num == 9                  ~ NA,
      anio == 2010        & !is.na(niv_num)               ~ FALSE,
      
      # 2011: strings "00"-"09", Superior = "07","08"
      anio == 2011        & niv_num %in% c(7, 8)          ~ TRUE,
      anio == 2011        & niv_num == 9                  ~ NA,
      anio == 2011        & !is.na(niv_num)               ~ FALSE,
      
      # 2012-2016: 0-9, Superior = 7,8
      anio %in% 2012:2016 & niv_num %in% c(7, 8)          ~ TRUE,
      anio %in% 2012:2016 & niv_num == 9                  ~ NA,
      anio %in% 2012:2016 & !is.na(niv_num)               ~ FALSE,
      
      # 2017: Superior = 6,7,8
      anio == 2017        & niv_num %in% c(6, 7, 8)       ~ TRUE,
      anio == 2017        & niv_num == 9                  ~ NA,
      anio == 2017        & !is.na(niv_num)               ~ FALSE,
      
      # 2018: códigos corridos, Superior = 7,8,9 (no 99)
      anio == 2018        & niv_num %in% c(7, 8, 9)       ~ TRUE,
      anio == 2018        & niv_num == 99                 ~ NA,
      anio == 2018        & !is.na(niv_num)               ~ FALSE,
      
      # 2019-2024: Superior = 6,7,8
      anio %in% 2019:2024 & niv_num %in% c(6, 7, 8)       ~ TRUE,
      anio %in% 2019:2024 & niv_num == 9                  ~ NA,
      anio %in% 2019:2024 & !is.na(niv_num)               ~ FALSE,
      
      TRUE ~ NA
    )
  } else { # ENV
    case_when(
      # 1997-2007: strings "1"-"6", Superior = "5" (Universidad)
      anio %in% 1997:2007 & niv_num == 5                  ~ TRUE,
      anio %in% 1997:2007 & niv_num == 6                  ~ NA,  # sin info
      anio %in% 1997:2007 & !is.na(niv_num)               ~ FALSE,
      
      # 2008-2011: 0-9 sin labels, misma escala que 2012
      anio %in% 2008:2011 & niv_num %in% c(7, 8)          ~ TRUE,
      anio %in% 2008:2011 & niv_num == 9                  ~ NA,
      anio %in% 2008:2011 & !is.na(niv_num)               ~ FALSE,
      
      # 2012-2016: Superior = 7,8
      anio %in% 2012:2016 & niv_num %in% c(7, 8)          ~ TRUE,
      anio %in% 2012:2016 & niv_num == 9                  ~ NA,
      anio %in% 2012:2016 & !is.na(niv_num)               ~ FALSE,
      
      # 2017-2024: Superior = 6,7,8
      anio %in% 2017:2024 & niv_num %in% c(6, 7, 8)       ~ TRUE,
      anio %in% 2017:2024 & niv_num == 9                  ~ NA,
      anio %in% 2017:2024 & !is.na(niv_num)               ~ FALSE,
      
      TRUE ~ NA
    )
  }
}

# ── FUNCIÓN: Obtener variable de nivel educativo ──────────────────────────────
get_niv_inst <- function(df) {
  candidatos <- c("niv_inst", "NIV_INST", "COD_INST",
                  "COD_INSTRUCCION", "nivel_inst")
  encontrada <- candidatos[candidatos %in% names(df)]
  if (length(encontrada) == 0) return(NULL)
  df[[encontrada[1]]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# PASO 1: PROCESAR EDF 2000-2024
# ═══════════════════════════════════════════════════════════════════════════════

resultados_edf <- map_dfr(2000:2024, function(y) {
  
  cat(sprintf("EDF %d... ", y))
  
  # Intentar variantes de nombre de archivo
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  
  if (is.na(ruta)) {
    cat("NO ENCONTRADO\n")
    return(NULL)
  }
  
  df <- read_sav(ruta, encoding = "latin1")
  names(df) <- tolower(names(df))
  
  niv <- get_niv_inst(df)
  if (is.null(niv)) {
    cat("SIN VARIABLE EDUCACIÓN\n")
    return(NULL)
  }
  
  sup <- es_superior(niv, y, "EDF")
  
  n_sup    <- sum(sup == TRUE,  na.rm = TRUE)
  n_nosup  <- sum(sup == FALSE, na.rm = TRUE)
  n_sininfo <- sum(is.na(sup))
  
  cat(sprintf("Sup: %d | NoSup: %d | SinInfo: %d\n",
              n_sup, n_nosup, n_sininfo))
  
  tibble(anio = y, DF_sup = n_sup, DF_nosup = n_nosup,
         DF_sininfo = n_sininfo, DF_total = n_sup + n_nosup)
})

# ═══════════════════════════════════════════════════════════════════════════════
# PASO 2: PROCESAR ENV 2000-2024
# ═══════════════════════════════════════════════════════════════════════════════

resultados_env <- map_dfr(2000:2024, function(y) {
  
  cat(sprintf("ENV %d... ", y))
  
  rutas <- c(
    file.path(carpeta_env, sprintf("ENV_%d.sav", y)),
    file.path(carpeta_env, sprintf("ENV_ %d.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  
  if (is.na(ruta)) {
    cat("NO ENCONTRADO\n")
    return(NULL)
  }
  
  df <- read_sav(ruta, encoding = "latin1")
  names(df) <- tolower(names(df))
  
  niv <- get_niv_inst(df)
  if (is.null(niv)) {
    cat("SIN VARIABLE EDUCACIÓN\n")
    return(NULL)
  }
  
  sup <- es_superior(niv, y, "ENV")
  
  n_sup     <- sum(sup == TRUE,  na.rm = TRUE)
  n_nosup   <- sum(sup == FALSE, na.rm = TRUE)
  n_sininfo <- sum(is.na(sup))
  
  cat(sprintf("Sup: %d | NoSup: %d | SinInfo: %d\n",
              n_sup, n_nosup, n_sininfo))
  
  tibble(anio = y, NV_sup = n_sup, NV_nosup = n_nosup,
         NV_sininfo = n_sininfo)
})

# ═══════════════════════════════════════════════════════════════════════════════
# PASO 3: MERGE Y TASA
# ═══════════════════════════════════════════════════════════════════════════════

serie_final <- resultados_edf %>%
  inner_join(resultados_env, by = "anio") %>%
  mutate(
    tmf_sup   = (DF_sup   / NV_sup)   * 1000,
    tmf_nosup = (DF_nosup / NV_nosup) * 1000,
    brecha    = tmf_nosup - tmf_sup
  )

cat("\n══════════════════════════════════════\n")
cat("RESULTADO FINAL\n")
cat("══════════════════════════════════════\n")
print(serie_final %>%
        select(anio, DF_sup, NV_sup, tmf_sup,
               DF_nosup, NV_nosup, tmf_nosup, brecha),
      n = 25)

# ═══════════════════════════════════════════════════════════════════════════════
# PASO 4: GRÁFICO
# ═══════════════════════════════════════════════════════════════════════════════

ultimo     <- serie_final %>% filter(anio == max(anio))
brecha_txt <- round(ultimo$brecha, 1)
sup_txt    <- round(ultimo$tmf_sup, 1)
nos_txt    <- round(ultimo$tmf_nosup, 1)

serie_long <- serie_final %>%
  select(anio, tmf_sup, tmf_nosup) %>%
  pivot_longer(
    cols      = c(tmf_sup, tmf_nosup),
    names_to  = "grupo",
    values_to = "tmf"
  ) %>%
  mutate(grupo = recode(grupo,
                        "tmf_sup"   = "Con educación superior",
                        "tmf_nosup" = "Sin educación superior"
  ))

grafico <- ggplot(serie_long, aes(x = anio, y = tmf, color = grupo)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  # Línea vertical marcando cambio de escala en 2005 y 2017
  geom_vline(xintercept = c(2005, 2017),
             linetype = "dotted", color = "grey60", linewidth = 0.7) +
  annotate("text", x = 2005.2, y = Inf,
           label = "Cambio escala\n2005", vjust = 1.5,
           size = 2.8, color = "grey50", hjust = 0) +
  annotate("text", x = 2017.2, y = Inf,
           label = "Cambio escala\n2017", vjust = 1.5,
           size = 2.8, color = "grey50", hjust = 0) +
  scale_color_manual(values = c(
    "Con educación superior" = "#2166ac",
    "Sin educación superior" = "#d73027"
  )) +
  scale_x_continuous(breaks = seq(2000, 2024, 2)) +
  labs(
    title    = "Ecuador 2000–2024: Mortalidad Fetal según Nivel Educativo de la Madre",
    subtitle = "Por cada 1.000 nacidos vivos",
    x        = NULL,
    y        = "Tasa de Mortalidad Fetal (por 1.000 NV)",
    color    = NULL,
    caption  = paste0(
      "Brecha ", max(serie_final$anio), ": ", brecha_txt,
      " puntos  (Sin superior: ", nos_txt,
      "  |  Con superior: ", sup_txt, ")\n",
      "Nota metodológica: Tasa calculada por método de período. ",
      "Numerador y denominador clasificados según\n",
      "nivel de instrucción de la madre. ",
      "Se excluyen registros sin información educativa.\n",
      "Las líneas punteadas indican cambios en la escala de codificación del INEC ",
      "(2005 y 2017).\n",
      "Fuente: EDF y ENV, INEC 2000–2024. ",
      "Elaboración: Observatorio de Desigualdad y Pobreza."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(color = "grey40", size = 10),
    plot.caption     = element_text(color = "grey50", size = 7.5,
                                    hjust = 0, lineheight = 1.4),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    panel.grid.minor = element_blank()
  )

print(grafico)

ggsave(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/TMF_educacion_2000_2024.png",
  plot = grafico, width = 13, height = 7, dpi = 150
)

write.csv(serie_final,
          "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/TMF_educacion_2000_2024.csv",
          row.names = FALSE)

cat("\n✔ Gráfico: TMF_educacion_2000_2024.png\n")
cat("✔ Base:    TMF_educacion_2000_2024.csv\n")

# Filtro 2015

serie_final_filtrada2015 <- serie_final %>%
  filter(anio == 2015)

serie_long <- serie_final_filtrada %>%
  select(anio, tmf_sup, tmf_nosup) %>%
  pivot_longer(
    cols      = c(tmf_sup, tmf_nosup),
    names_to  = "grupo",
    values_to = "tmf"
  ) %>%
  mutate(grupo = recode(grupo,
                        "tmf_sup"   = "Con educación superior",
                        "tmf_nosup" = "Sin educación superior"
  ))

ultimo     <- serie_final_filtrada %>% filter(anio == max(anio))
brecha_txt <- round(ultimo$brecha, 1)
sup_txt    <- round(ultimo$tmf_sup, 1)
nos_txt    <- round(ultimo$tmf_nosup, 1)
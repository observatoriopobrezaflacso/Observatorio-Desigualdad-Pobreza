rm(list = ls())
library(haven)
library(tidyverse)

carpeta_edf <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos"
carpeta_env <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV"

# ── FUNCIÓN ÚNICA DE ARMONIZACIÓN ────────────────────────────────────────────
clasificar_educacion <- function(niv, anio, base) {
  niv <- as.numeric(haven::zap_labels(niv))
  
  if (base == "EDF") {
    case_when(
      anio %in% 2000:2004 & niv == 5             ~ 1L,
      anio %in% 2000:2004 & niv == 9             ~ NA_integer_,
      anio %in% 2000:2004 & !is.na(niv)          ~ 0L,
      anio %in% 2005:2011 & niv %in% c(7, 8)    ~ 1L,
      anio %in% 2005:2011 & niv == 9             ~ NA_integer_,
      anio %in% 2005:2011 & !is.na(niv)          ~ 0L,
      anio %in% 2012:2016 & niv %in% c(7, 8)    ~ 1L,
      anio %in% 2012:2016 & niv == 9             ~ NA_integer_,
      anio %in% 2012:2016 & !is.na(niv)          ~ 0L,
      anio == 2017        & niv %in% c(6, 7, 8)  ~ 1L,
      anio == 2017        & niv == 9             ~ NA_integer_,
      anio == 2017        & !is.na(niv)          ~ 0L,
      anio == 2018        & niv %in% c(7, 8, 9)  ~ 1L,
      anio == 2018        & niv == 99            ~ NA_integer_,
      anio == 2018        & !is.na(niv)          ~ 0L,
      anio %in% 2019:2024 & niv %in% c(6, 7, 8)  ~ 1L,
      anio %in% 2019:2024 & niv == 9             ~ NA_integer_,
      anio %in% 2019:2024 & !is.na(niv)          ~ 0L,
      TRUE ~ NA_integer_
    )
  } else { # ENV
    case_when(
      anio %in% 1997:2007 & niv == 5             ~ 1L,
      anio %in% 1997:2007 & niv == 6             ~ NA_integer_,
      anio %in% 1997:2007 & !is.na(niv)          ~ 0L,
      anio %in% 2008:2016 & niv %in% c(7, 8)    ~ 1L,
      anio %in% 2008:2016 & niv == 9             ~ NA_integer_,
      anio %in% 2008:2016 & !is.na(niv)          ~ 0L,
      anio %in% 2017:2024 & niv %in% c(6, 7, 8)  ~ 1L,
      anio %in% 2017:2024 & niv == 9             ~ NA_integer_,
      anio %in% 2017:2024 & !is.na(niv)          ~ 0L,
      TRUE ~ NA_integer_
    )
  }
}

# ── PASO 1: ARMONIZAR EDF 2000-2024 ──────────────────────────────────────────
cat("══════════════════════════════════════\n")
cat("PROCESANDO EDF\n")
cat("══════════════════════════════════════\n")

edf_armonizado <- map_dfr(2000:2024, function(y) {
  cat(sprintf("EDF %d...\n", y))
  
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) { cat("  ✘ No encontrado\n"); return(NULL) }
  
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "cod_inst", "COD_INST",
      "cod_instruccion", "COD_INSTRUCCION")
  ))
  names(df) <- tolower(names(df))
  
  candidatos <- c("niv_inst", "cod_inst", "cod_instruccion")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) { cat("  ✘ Sin variable educación\n"); return(NULL) }
  
  flag <- clasificar_educacion(df[[vvar]], y, "EDF")
  
  n_sup    <- sum(flag == 1L, na.rm = TRUE)
  n_nosup  <- sum(flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(flag))
  
  cat(sprintf("  ✔ Sup: %d | NoSup: %d | SinInfo: %d\n",
              n_sup, n_nosup, n_sininfo))
  
  tibble(anio = y, DF_sup = n_sup, DF_nosup = n_nosup, DF_sininfo = n_sininfo)
})

# ── PASO 2: ARMONIZAR ENV 2000-2024 ──────────────────────────────────────────
cat("\n══════════════════════════════════════\n")
cat("PROCESANDO ENV\n")
cat("══════════════════════════════════════\n")

env_armonizado <- map_dfr(2000:2024, function(y) {
  cat(sprintf("ENV %d...\n", y))
  
  rutas <- c(
    file.path(carpeta_env, sprintf("ENV_%d.sav", y)),
    file.path(carpeta_env, sprintf("ENV_ %d.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) { cat("  ✘ No encontrado\n"); return(NULL) }
  
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "cod_inst", "COD_INST",
      "nivel_inst", "NIVEL_INST")
  ))
  names(df) <- tolower(names(df))
  
  candidatos <- c("niv_inst", "cod_inst", "nivel_inst")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) { cat("  ✘ Sin variable educación\n"); return(NULL) }
  
  flag <- clasificar_educacion(df[[vvar]], y, "ENV")
  
  n_sup    <- sum(flag == 1L, na.rm = TRUE)
  n_nosup  <- sum(flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(flag))
  
  cat(sprintf("  ✔ Sup: %d | NoSup: %d | SinInfo: %d\n",
              n_sup, n_nosup, n_sininfo))
  
  tibble(anio = y, NV_sup = n_sup, NV_nosup = n_nosup, NV_sininfo = n_sininfo)
})

# ── PASO 3: CALCULAR TASA ─────────────────────────────────────────────────────
serie_final <- edf_armonizado %>%
  inner_join(env_armonizado, by = "anio") %>%
  mutate(
    tmf_sup   = round((DF_sup   / NV_sup)   * 1000, 2),
    tmf_nosup = round((DF_nosup / NV_nosup) * 1000, 2),
    brecha    = round(tmf_nosup - tmf_sup, 2)
  )

cat("\n══════════════════════════════════════\n")
cat("SERIE FINAL\n")
cat("══════════════════════════════════════\n")
print(serie_final %>%
        select(anio, DF_sup, NV_sup, tmf_sup,
               DF_nosup, NV_nosup, tmf_nosup, brecha), n = 25)

# ── PASO 4: GRÁFICO ───────────────────────────────────────────────────────────
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

ultimo     <- serie_final %>% filter(anio == max(anio))
brecha_txt <- round(ultimo$brecha, 1)
sup_txt    <- round(ultimo$tmf_sup, 1)
nos_txt    <- round(ultimo$tmf_nosup, 1)

grafico <- ggplot(serie_long, aes(x = anio, y = tmf, color = grupo)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
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
      "Nota: Tasa por método de período. Se excluyen registros sin información educativa.\n",
      "Líneas punteadas indican cambios en escala de codificación INEC (2005 y 2017).\n",
      "Fuente: EDF y ENV, INEC 2000–2024. Elaboración: Observatorio de Desigualdad y Pobreza."
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
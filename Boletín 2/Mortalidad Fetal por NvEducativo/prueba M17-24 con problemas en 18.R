rm(list = ls())
library(haven)
library(tidyverse)

carpeta_edf <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/Nacidos vivos-20260302T210056Z-3-001/Nacidos vivos"
carpeta_env <- "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/ENV"

# ── FUNCIÓN ARMONIZACIÓN ──────────────────────────────────────────────────────
clasificar_educacion <- function(niv) {
  niv <- as.numeric(haven::zap_labels(niv))
  case_when(
    niv %in% c(6, 7, 8) ~ 1L,
    niv == 9             ~ NA_integer_,
    !is.na(niv)          ~ 0L,
    TRUE                 ~ NA_integer_
  )
}

# ── EDF 2017-2024 ─────────────────────────────────────────────────────────────
edf_armonizado <- map_dfr(2017:2024, function(y) {
  cat(sprintf("EDF %d...\n", y))
  rutas <- c(
    file.path(carpeta_edf, sprintf("EDF_%d.sav", y)),
    file.path(carpeta_edf, sprintf("EDF_%d final.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) return(NULL)
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "cod_inst", "COD_INST",
      "cod_instruccion", "COD_INSTRUCCION")
  ))
  names(df) <- tolower(names(df))
  candidatos <- c("niv_inst", "cod_inst", "cod_instruccion")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) return(NULL)
  flag <- clasificar_educacion(df[[vvar]])
  n_sup     <- sum(flag == 1L, na.rm = TRUE)
  n_nosup   <- sum(flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(flag))
  cat(sprintf("  ✔ Sup: %d | NoSup: %d | SinInfo: %d\n", n_sup, n_nosup, n_sininfo))
  tibble(anio = y, DF_sup = n_sup, DF_nosup = n_nosup, DF_sininfo = n_sininfo)
})

# ── ENV 2017-2024 ─────────────────────────────────────────────────────────────
env_armonizado <- map_dfr(2017:2024, function(y) {
  cat(sprintf("ENV %d...\n", y))
  rutas <- c(
    file.path(carpeta_env, sprintf("ENV_%d.sav", y)),
    file.path(carpeta_env, sprintf("ENV_ %d.sav", y))
  )
  ruta <- rutas[file.exists(rutas)][1]
  if (is.na(ruta)) return(NULL)
  df <- read_sav(ruta, col_select = any_of(
    c("niv_inst", "NIV_INST", "nivel_inst", "NIVEL_INST")
  ))
  names(df) <- tolower(names(df))
  candidatos <- c("niv_inst", "nivel_inst")
  vvar <- candidatos[candidatos %in% names(df)][1]
  if (is.na(vvar)) return(NULL)
  flag <- clasificar_educacion(df[[vvar]])
  n_sup     <- sum(flag == 1L, na.rm = TRUE)
  n_nosup   <- sum(flag == 0L, na.rm = TRUE)
  n_sininfo <- sum(is.na(flag))
  cat(sprintf("  ✔ Sup: %d | NoSup: %d | SinInfo: %d\n", n_sup, n_nosup, n_sininfo))
  tibble(anio = y, NV_sup = n_sup, NV_nosup = n_nosup, NV_sininfo = n_sininfo)
})

# ── TASA ──────────────────────────────────────────────────────────────────────
serie_final <- edf_armonizado %>%
  inner_join(env_armonizado, by = "anio") %>%
  mutate(
    tmf_sup   = round((DF_sup   / NV_sup)   * 1000, 2),
    tmf_nosup = round((DF_nosup / NV_nosup) * 1000, 2),
    brecha    = round(tmf_nosup - tmf_sup, 2)
  )

cat("\n══ SERIE FINAL ══\n")
print(serie_final %>%
        select(anio, DF_sup, NV_sup, tmf_sup,
               DF_nosup, NV_nosup, tmf_nosup, brecha), n = 8)

# ── GRÁFICO ───────────────────────────────────────────────────────────────────
ultimo     <- serie_final %>% filter(anio == max(anio))
brecha_txt <- round(ultimo$brecha, 1)
sup_txt    <- round(ultimo$tmf_sup, 1)
nos_txt    <- round(ultimo$tmf_nosup, 1)

serie_long <- serie_final %>%
  select(anio, tmf_sup, tmf_nosup) %>%
  pivot_longer(c(tmf_sup, tmf_nosup), names_to = "grupo", values_to = "tmf") %>%
  mutate(grupo = recode(grupo,
                        "tmf_sup"   = "Con educación superior",
                        "tmf_nosup" = "Sin educación superior"
  ))

grafico <- ggplot(serie_long, aes(x = anio, y = tmf, color = grupo)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c(
    "Con educación superior" = "#2166ac",
    "Sin educación superior" = "#d73027"
  )) +
  scale_x_continuous(breaks = 2017:2024) +
  labs(
    title    = "Ecuador 2017–2024: Mortalidad Fetal según Nivel Educativo de la Madre",
    subtitle = "Por cada 1.000 nacidos vivos",
    x        = NULL,
    y        = "Tasa de Mortalidad Fetal (por 1.000 NV)",
    color    = NULL,
    caption  = paste0(
      "Brecha ", max(serie_final$anio), ": ", brecha_txt,
      " puntos  (Sin superior: ", nos_txt, "  |  Con superior: ", sup_txt, ")\n\n",
      "Nota metodológica:\n",
      "• Numerador: defunciones fetales (EDF) por nivel educativo de la madre.\n",
      "• Denominador: nacidos vivos (ENV) por nivel educativo de la madre.\n",
      "• Se excluyen registros sin información educativa (<3% en todo el período).\n",
      "• Período seleccionado por consistencia en la escala de codificación INEC.\n",
      "• Fuente: EDF y ENV, INEC 2017–2024. Elaboración: Observatorio de Desigualdad y Pobreza."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(color = "grey40", size = 10),
    plot.caption     = element_text(color = "grey50", size = 7,
                                    hjust = 0, lineheight = 1.4),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    panel.grid.minor = element_blank()
  )

print(grafico)

ggsave(
  "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/TMF_educacion_2017_2024.png",
  plot = grafico, width = 13, height = 7, dpi = 150
)

write.csv(serie_final,
          "C:/Users/user/Observatorio-Desigualdad-Pobreza/EDG/TMF_educacion_2017_2024.csv",
          row.names = FALSE)

cat("\n✔ Gráfico: TMF_educacion_2017_2024.png\n")
cat("✔ Base:    TMF_educacion_2017_2024.csv\n")
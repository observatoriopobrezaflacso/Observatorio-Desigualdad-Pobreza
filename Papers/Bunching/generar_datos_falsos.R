# Genera F102 y F107 falsos (2010-2024) a partir de los descriptivos YAML,
# con las mismas funciones que Codigos/Fake data/fake_master.R.
# Salida: Datos_falsos/F102 y F107 en Google Drive (Papers/Bunching); no va a GitHub
#
# - n_obs filas por formulario y año (los umbrales altos, la reforma de 2022 y
#   la línea de 20.000 del RIMPE necesitan muestras grandes).
# - Solo se generan las variables que usa el pipeline de bunching (keep_all =
#   FALSE). El generador crea cada variable por separado desde su marginal,
#   así que es lo mismo que generar todas y quedarse con estas. Deja fuera
#   nombre_contador_105, cuyos descriptivos contienen nombres reales.
# - Repara los YAML de F102 2021-2023: tienen una "Ñ" mal escrita (byte 0xC3
#   seguido del texto "\x91") y yaml::read_yaml se detiene ahí.
# - Fija un locale UTF-8: con Rscript en locale "C", read_yaml no puede leer
#   caracteres como "Ñ" y corta el archivo sin avisar.

invisible(Sys.setlocale("LC_ALL", "en_US.UTF-8"))
suppressMessages({library(haven); library(dplyr); library(tibble); library(purrr); library(stringr)})
proc <- "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/SRI/Procesamiento"
out  <- "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/Datos_falsos"
n_obs    <- 50000
keep_all <- FALSE   # TRUE = generar las 858 variables (archivos mucho más grandes)
source(file.path(proc, "Codigos/Fake data/Synthetic.R"))
source(file.path(proc, "Codigos/Fake data/descriptives_yaml.R"))

# Variables usadas por arreglar_ids_falsos.do, construir_ingreso_dina_falso.do,
# inyectar_bunching_falso.do y bunching_renta.do
vars_keep <- list(
  "2" = c("CEDULA_PK", "base_imponible_3480",
          "suj_reg_rimpe_4896", "bas_imp_grav_reg_rimpe_5687",
          "ing_syo_trabajo_rde_3240", "ded_syo_trabajo_rde_3250",
          "utilidad_neta_ejercicio_2800", "perdida_ejercicio_2810",
          "ingresos_aem_rie_1280", "deducciones_aem_rie_1290", "ingresos_sir_2988",
          "ing_libre_eje_profesional_2990", "ded_libre_eje_profesional_3000",
          "ing_ocupacion_liberal_3010", "ded_ocupacion_liberal_3020",
          "otr_ing_gravados_exterior_3180", "otr_ingresos_exentos_3460",
          "ing_arriendo_inmuebles_3040", "ded_arriendo_inmuebles_3050",
          "rim_arriendo_otros_act_3100", "rim_predios_agricolas_3164",
          "ingresos_regalias_3170", "rendimientos_financieros_3190",
          "dividendos_recibidos_3192", "ingresos_otr_rgr_3193", "deducciones_otr_rgr_3194",
          "img_herencias_leg_don_3420", "ipa_herencias_leg_don_3410",
          "ing_lot_rifas_apuestas_3400", "ipa_lot_rifas_apuestas_3390",
          "ing_pensiones_jubilares_3450", "imp_renta_causado_3490"),
  "7" = c("CEDULA_PK_empleado", "RUC_PK_empleador", "base_imponible",
          "ingresos_liq_pagados", "sob_suel_com_remu", "partic_utilidades",
          "decimo_tercero", "decimo_cuarto", "fondo_reserva",
          "aporte_iess_empleado", "imp_renta_causado")
)

# Copia temporal del YAML con los bytes reparados
yaml_reparado <- function(f) {
  b <- readBin(f, "raw", n = file.info(f)$size)
  i <- which(b == as.raw(0xc3))
  i <- i[i + 4 <= length(b)]
  i <- i[b[i + 1] == as.raw(0x5c) & b[i + 2] == as.raw(0x78)]   # "\x"
  if (length(i) > 0) {
    borrar <- integer(0)
    for (j in i) {
      b[j + 1] <- as.raw(strtoi(rawToChar(b[(j + 3):(j + 4)]), 16L))
      borrar <- c(borrar, (j + 2):(j + 4))
    }
    b <- b[-borrar]
    message("  -> ", length(i), " caracter(es) reparado(s)")
  }
  tmp <- tempfile(fileext = ".yaml")
  writeBin(b, tmp)
  tmp
}

for (form_n in c(2, 7)) {
  for (year in 2010:2024) {
    message("F10", form_n, " ", year)
    f <- file.path(proc, sprintf("Bases/Descriptivos/F10%d/F10%d_%d.txt", form_n, form_n, year))
    spec <- tryCatch(load_spec_yaml(yaml_reparado(f)), error = function(e) {
      message("  -> YAML ilegible: ", conditionMessage(e)); NULL })
    if (is.null(spec)) next
    if (!keep_all) {
      v <- intersect(vars_keep[[as.character(form_n)]], names(spec$variables))
      spec$variables <- spec$variables[v]
      spec$var_names <- v
      spec$n_vars    <- length(v)
    }
    fake <- fake_data_creation(spec, n = n_obs, seed = 41, verbose = FALSE)
    write_dta(fake[names(fake) != "e_catastrofica"],
              file.path(out, sprintf("F10%d/F10%d_%d.dta", form_n, form_n, year)))
  }
}

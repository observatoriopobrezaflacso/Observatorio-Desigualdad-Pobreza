# =============================================================================
# SCRIPT PRINCIPAL - Análisis para Boletín 2
# Observatorio de Políticas Públicas
# Defunciones y Egresos Hospitalarios 2024
# =============================================================================
#
# Este script ejecuta todos los análisis en orden.
# Cada módulo puede ejecutarse también de forma independiente.
#
# Estructura de archivos:
#   00_configuracion.R          - Librerías, configuración y datos del censo
#   01_analisis_defunciones.R   - Análisis de defunciones (gráficos 1-7)
#   02_analisis_causas_externas.R - Causas externas y suicidios (gráficos 8-14)
#   03_analisis_egresos.R       - Egresos hospitalarios (gráficos 12-16)
#   04_analisis_series_temporales.R - Series temporales de mortalidad, homicidios y suicidios
#
# =============================================================================

# Limpiar entorno
rm(list = ls())

# Establecer directorio de trabajo
setwd("/Users/vero/Library/CloudStorage/GoogleDrive-savaldiviesofl@flacso.edu.ec/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 2")

cat("=============================================================================\n")
cat("ANÁLISIS PARA BOLETÍN 2 - OBSERVATORIO DE POLÍTICAS PÚBLICAS\n")
cat("=============================================================================\n\n")

# Ejecutar módulos en orden ----

# 1. Configuración inicial y datos del censo
cat(">>> Cargando configuración...\n")
source("Procesamiento/Codigos/00_configuracion.R")

# 2. Análisis de defunciones
cat("\n>>> Ejecutando análisis de defunciones...\n")
source("Procesamiento/Codigos/01_analisis_defunciones.R")

# 3. Análisis de causas externas y suicidios
cat("\n>>> Ejecutando análisis de causas externas...\n")
source("Procesamiento/Codigos/02_analisis_causas_externas.R")

# 4. Análisis de egresos hospitalarios
cat("\n>>> Ejecutando análisis de egresos hospitalarios...\n")
source("Procesamiento/Codigos/03_analisis_egresos.R")

# 5. Análisis de series temporales (requiere datos históricos)
cat("\n>>> Ejecutando análisis de series temporales...\n")
source("Procesamiento/Codigos/04_analisis_series_temporales.R")

# Finalización ----
cat("\n=============================================================================\n")
cat("ANÁLISIS COMPLETADO\n")
cat("=============================================================================\n")
cat("\nGráficos guardados en:", output_dir, "\n")

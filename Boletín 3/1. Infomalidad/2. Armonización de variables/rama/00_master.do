*-----------------------------------------------------------------------------
* 00_master.do
*
* Ejecuta toda la cadena de armonizacion de ramas de ENEMDU:
*   1) CIIU Rev. 2  -> Rev. 3.1   (1990-1999)
*   2) CIIU Rev. 3  -> Rev. 3.1   (2000-2006)
*   3) CIIU Rev. 3.1 -> Rev. 4    (1991-2012) + pass-through (2013-2025)
*   4) Tabla descriptiva: % de las ramas mas grandes por anio.
*-----------------------------------------------------------------------------

clear all
set more off
version 16

global wd "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Boletín 3/2. Armonización de variables/rama"

cd "$wd"

di as text "================ STEP 1: Rev 2 -> Rev 3.1 (1990-1999) ================"
do "isic2_31.do"

di as text "================ STEP 2: Rev 3 -> Rev 3.1 (2000-2006) ================"
do "isic3_31.do"

di as text "================ STEP 3: Rev 3.1 -> Rev 4 (1991-2025) ================"
do "ISIC3_1_to_ISIC4.do"

di as text "================ STEP 4: Tabla descriptiva ================"
do "descriptiva_ramas.do"

di as result "Cadena de armonizacion completada."

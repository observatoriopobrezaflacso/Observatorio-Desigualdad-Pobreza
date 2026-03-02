* :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
* SCRIPT STATA: GENERACIÓN DE INSUMO PARROQUIAL TMI 2022 (RUTAS CORREGIDAS)
* :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

clear all
set more off

* 1. DEFINIR RUTAS ESPECÍFICAS (Según tus carpetas)
local carpeta_edg "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"
local carpeta_env "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV"
local ruta_salida "C:\Users\user\Observatorio-Desigualdad-Pobreza"

* 2. PROCESAR DEFUNCIONES (EDG 2022)
* -------------------------------------------------------------------------------
cd "`carpeta_edg'"
capture import spss using "EDG_2022.sav", clear

if _rc {
    display as error "ERROR: No se encontró EDG_2022.sav en: `carpeta_edg'"
    exit
}

* Estandarización de edad (Tu lógica)
capture confirm variable COD_EDA
if !_rc rename COD_EDA cod_edad
capture confirm variable EDAD
if !_rc rename EDAD edad
capture confirm string variable cod_edad
if !_rc destring cod_edad, replace force

* Identificar menores de 1 año
gen menor1 = inlist(cod_edad, 1, 2, 3) | (cod_edad == 4 & edad == 0)

* Colapso parroquial
collapse (sum) defunciones=menor1, by(parr_fall)
rename parr_fall cod_parroquia
tempfile def_2022
save `def_2022'

* 3. PROCESAR NACIDOS VIVOS (ENV 2022)
* -------------------------------------------------------------------------------
cd "`carpeta_env'"
capture import spss using "ENV_2022.sav", clear

if _rc {
    display as error "ERROR: No se encontró ENV_2022.sav en: `carpeta_env'"
    exit
}

* Cada fila es un nacido vivo
gen nacido_vivo = 1
collapse (sum) nacimientos=nacido_vivo, by(parr_res)
rename parr_res cod_parroquia
tempfile nac_2022
save `nac_2022'

* 4. UNIÓN Y EXPORTACIÓN FINAL
* -------------------------------------------------------------------------------
use `def_2022', clear
merge 1:1 cod_parroquia using `nac_2022'

* Limpieza rápida
recode defunciones (. = 0)
recode nacimientos (. = 0)
drop if cod_parroquia == "" | cod_parroquia == "999999"

* Guardar el CSV en la carpeta principal del proyecto
cd "`ruta_salida'"
export delimited using "mortalidad_infantil_parroquial_2022.csv", replace

display "✅ ¡AHORA SÍ, LUIS! Archivo generado en la raíz del proyecto."
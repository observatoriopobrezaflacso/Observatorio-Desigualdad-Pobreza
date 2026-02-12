/*******************************************************************************
* PROGRAMA SRI — Declaración de Renta  (2/3)
* Generación de variables de ingreso
*
* Entrada:  merge_renta_<año>.dta  (de 01_limpieza_merge.do)
* Salida :  ingresos_renta_<año>.dta  (uno por año, en $dir_temp)
*******************************************************************************/

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. CONFIGURACIÓN DE RUTAS
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"

global dir_out  "$basedir/Resultados"
global dir_temp "$basedir/Resultados/Merged"

* ============================================================================
* 2. DETECTAR AÑOS DISPONIBLES (archivos generados por 01_limpieza_merge.do)
* ============================================================================

local years ""
local files_merge : dir "$dir_temp" files "merge_renta_*.dta"
foreach f of local files_merge {
    if regexm("`f'", "merge_renta_([0-9]+)\.dta") {
        local yr = regexs(1)
        local years "`years' `yr'"
    }
}
local years : list sort years

di as text _n "Años a procesar: `years'" _n

* ============================================================================
* 3. LOOP — GENERAR VARIABLES DE INGRESO POR AÑO
* ============================================================================

foreach yr of local years {

    di as result _n "========== Variables de ingreso — año `yr' =========="

    use "$dir_temp/merge_renta_`yr'.dta", clear

    * Totales de ingreso (rowtotal trata missing como 0)
    egen INGRESOS_TRAB_TOTAL    = rowtotal(ingreso_trabajo ///
        ING_TRAB_OBLIGADOS ING_TRAB_NO_OBLIGADOS)
    egen INGRESOS_CAPITAL_TOTAL = rowtotal(INGRESOS_CAPITAL)
    egen INGRESOS_TOTAL         = rowtotal(INGRESOS_TRAB_TOTAL ///
        INGRESOS_CAPITAL_TOTAL)

    * Ceros → missing  (sólo para estadísticas descriptivas)
    foreach var in INGRESOS_TRAB_TOTAL INGRESOS_CAPITAL_TOTAL INGRESOS_TOTAL {
        gen `var'_s = `var'
        replace `var'_s = . if `var'_s == 0
    }

    save "$dir_temp/ingresos_renta_`yr'.dta", replace
    di as text "  Guardado: $dir_temp/ingresos_renta_`yr'.dta"
}

di as result _n "02_variables_ingreso.do completado."

/*******************************************************************************
* PROGRAMA SRI — Declaración de Renta  (3/3)
* Análisis estadístico por percentiles y exportación a Excel
*
* Entrada:  ingresos_renta_<año>.dta  (de 02_variables_ingreso.do)
* Salida :  resultados_renta_percentiles.dta
*           Tablas_Renta.xlsx
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
* 2. DETECTAR AÑOS DISPONIBLES (archivos generados por 02_variables_ingreso.do)
* ============================================================================

local years ""
local files_ing : dir "$dir_temp" files "ingresos_renta_*.dta"
foreach f of local files_ing {
    if regexm("`f'", "ingresos_renta_([0-9]+)\.dta") {
        local yr = regexs(1)
        local years "`years' `yr'"
    }
}
local years : list sort years

di as text _n "Años a procesar: `years'" _n

* ============================================================================
* 3. PREPARAR POSTFILE PARA RESULTADOS
* ============================================================================

tempname results
tempfile results_file

postfile `results'                            ///
    int(anio)                                 ///
    str30(concepto)                           ///
    str10(percentil)                          ///
    double(suma media mediana vmin vmax pct_total) ///
    long(N)                                   ///
    using "`results_file'", replace

* ============================================================================
* 4. LOOP — ESTADÍSTICAS POR GRUPO DE PERCENTIL
* ============================================================================

foreach yr of local years {

    di as result _n "========== Análisis percentiles — año `yr' =========="

    use "$dir_temp/ingresos_renta_`yr'.dta", clear

    local concepts      INGRESOS_TRAB_TOTAL  INGRESOS_CAPITAL_TOTAL  INGRESOS_TOTAL
    local concepts_lbl `""Ingresos de trabajo" "Ingresos de capital" "Ingreso total""'

    local c 1
    foreach concept of local concepts {

        local lbl : word `c' of `concepts_lbl'
        local svar "`concept'_s"

        * Verificar que hay suficientes observaciones
        quietly count if `svar' != .
        if r(N) < 2 {
            di as text "  NOTA: `lbl' — menos de 2 obs no-missing; se omite."
            local ++c
            continue
        }

        * Calcular puntos de corte
        quietly _pctile `svar', percentiles(50 60 70 80 90 95 99)
        local p50 = r(r1)
        local p60 = r(r2)
        local p70 = r(r3)
        local p80 = r(r4)
        local p90 = r(r5)
        local p95 = r(r6)
        local p99 = r(r7)

        quietly summarize `svar'
        local total_sum = r(sum)
        if `total_sum' == 0 local total_sum 1

        * --- Definir 9 grupos ---
        quietly {
            gen byte _g1 = (`svar' >= `p99' & `svar' != .)
            gen byte _g2 = (`svar' >= `p95' & `svar' != .)
            gen byte _g3 = (`svar' >= `p90' & `svar' != .)
            gen byte _g4 = (`svar' >= `p80' & `svar' < `p90' & `svar' != .)
            gen byte _g5 = (`svar' >= `p70' & `svar' < `p80' & `svar' != .)
            gen byte _g6 = (`svar' >= `p60' & `svar' < `p70' & `svar' != .)
            gen byte _g7 = (`svar' >= `p50' & `svar' < `p60' & `svar' != .)
            gen byte _g8 = (`svar' <= `p50' & `svar' != .)
            gen byte _g9 = (`svar' != .)
        }

        local gname1 "P99-P100"
        local gname2 "P95-P100"
        local gname3 "P90-P100"
        local gname4 "P80-P90"
        local gname5 "P70-P80"
        local gname6 "P60-P70"
        local gname7 "P50-P60"
        local gname8 "P1-P50"
        local gname9 "Total"

        forvalues g = 1/9 {
            quietly summarize `svar' if _g`g' == 1, detail
            if r(N) > 0 {
                post `results' (`yr') ("`lbl'") ("`gname`g''")    ///
                    (r(sum)) (r(mean)) (r(p50)) (r(min)) (r(max)) ///
                    ((r(sum) / `total_sum') * 100) (r(N))
            }
            else {
                post `results' (`yr') ("`lbl'") ("`gname`g''") ///
                    (0) (.) (.) (.) (.) (0) (0)
            }
        }

        drop _g1-_g9
        local ++c
    }
}

postclose `results'

* ============================================================================
* 5. GUARDAR RESULTADOS EN FORMATO LARGO
* ============================================================================

use "`results_file'", clear
label var anio      "Año"
label var concepto  "Concepto de ingreso"
label var percentil "Grupo de percentil"
label var suma      "Suma total"
label var media     "Media"
label var mediana   "Mediana"
label var vmin      "Mínimo"
label var vmax      "Máximo"
label var pct_total "% del ingreso total"
label var N         "Número de observaciones"

save "$dir_out/resultados_renta_percentiles.dta", replace

* ============================================================================
* 6. EXPORTAR A EXCEL — UNA HOJA POR CONCEPTO DE INGRESO
* ============================================================================

local outfile "$dir_out/Tablas_Renta.xlsx"

* Nombres de percentil en orden deseado
local pnames `""P99-P100" "P95-P100" "P90-P100" "P80-P90" "P70-P80" "P60-P70" "P50-P60" "P1-P50" "Total""'
local npctiles 9

* Conceptos y nombres de hoja
local sheet_concepts `""Ingresos de trabajo" "Ingresos de capital" "Ingreso total""'
local sheet_names    `""Ingresos de trabajo" "Ingresos de capital" "Total ingreso""'

local sc 1
foreach concept of local sheet_concepts {

    local shname : word `sc' of `sheet_names'

    use "$dir_out/resultados_renta_percentiles.dta", clear
    keep if concepto == "`concept'"

    * Asignar orden numérico a los grupos de percentil
    gen pctil_order = .
    forvalues p = 1/`npctiles' {
        local pn : word `p' of `pnames'
        replace pctil_order = `p' if percentil == "`pn'"
    }

    drop concepto percentil

    * Reshape: una fila por año, columnas = stat × percentil
    reshape wide suma media N mediana vmin vmax pct_total, ///
        i(anio) j(pctil_order)

    * Ordenar columnas: Año | (Suma Media N Mediana % Min Max) × cada grupo
    local ordered "anio"
    forvalues p = 1/`npctiles' {
        local ordered "`ordered' suma`p' media`p' N`p' mediana`p' pct_total`p' vmin`p' vmax`p'"
    }
    order `ordered'

    * Etiquetar variables
    label var anio "Año"
    forvalues p = 1/`npctiles' {
        local pn : word `p' of `pnames'
        label var suma`p'      "`pn': Suma total"
        label var media`p'     "`pn': Media"
        label var N`p'         "`pn': N"
        label var mediana`p'   "`pn': Mediana"
        label var pct_total`p' "`pn': % del total"
        label var vmin`p'      "`pn': Min"
        label var vmax`p'      "`pn': Max"
    }

    * Formatear números
    format suma* %15.2fc
    format media* mediana* vmin* vmax* %12.2fc
    format pct_total* %6.2f
    format N* %12.0fc

    sort anio

    * Exportar
    if `sc' == 1 {
        export excel using "`outfile'", ///
            sheet("`shname'") firstrow(varlabel) replace
    }
    else {
        export excel using "`outfile'", ///
            sheet("`shname'") firstrow(varlabel) sheetmodify
    }

    di as text "  Hoja exportada: `shname'"
    local ++sc
}

* ============================================================================
* 7. FIN
* ============================================================================

di as result _n "============================================="
di as result    "  Proceso completado"
di as result    "============================================="
di as text "Archivos generados:"
di as text "  $dir_out/resultados_renta_percentiles.dta"
di as text "  `outfile'"
di as text ""

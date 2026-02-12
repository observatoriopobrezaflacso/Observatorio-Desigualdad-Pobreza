/*******************************************************************************
* PROGRAMA SRI — Declaración de Renta
* Estadísticas descriptivas de ingresos por percentiles
*
* Genera tablas de distribución del ingreso para:
*   - Ingresos de trabajo
*   - Ingresos de capital
*   - Ingreso total
*
* Automatizado para todos los años con datos en F107 y F102.
* Basado en la lógica de renta2010.do
*
* Salida: Tablas_Renta.xlsx  (una hoja por concepto)
*         resultados_renta_percentiles.dta (formato largo)
*******************************************************************************/

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. CONFIGURACIÓN DE RUTAS
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"

global dir_f107 "$basedir/Bases/Fake/F107"
global dir_f102 "$basedir/Bases/Fake/F102"
global dir_out  "$basedir/Resultados"

capture mkdir "$dir_out"

* ============================================================================
* 2. SALARIO BÁSICO UNIFICADO POR AÑO (para tope de décimo cuarto)
* ============================================================================

local sbu_2008 200
local sbu_2009 218
local sbu_2010 240
local sbu_2011 264
local sbu_2012 292
local sbu_2013 318
local sbu_2014 340
local sbu_2015 354
local sbu_2016 366
local sbu_2017 375
local sbu_2018 386
local sbu_2019 394
local sbu_2020 400
local sbu_2021 400
local sbu_2022 425
local sbu_2023 450
local sbu_2024 460

* ============================================================================
* 3. DETECTAR AÑOS DISPONIBLES
* ============================================================================

* --- Años con F107 ---
local years_107 ""
local files_107 : dir "$dir_f107" files "F107_*.dta"
foreach f of local files_107 {
    if regexm("`f'", "F107_([0-9]+)\.dta") {
        local yr = regexs(1)
        local years_107 "`years_107' `yr'"
    }
}

* --- Años con F102 ---
local years_102 ""
local files_102 : dir "$dir_f102" files "F102_*.dta"
foreach f of local files_102 {
    if regexm("`f'", "F102_([0-9]+)\.dta") {
        local yr = regexs(1)
        local years_102 "`years_102' `yr'"
    }
}

* --- Intersección: años con ambos formularios ---
local years_both ""
foreach yr of local years_107 {
    local found 0
    foreach yr2 of local years_102 {
        if `yr' == `yr2' local found 1
    }
    if `found' local years_both "`years_both' `yr'"
}
local years_both : list sort years_both

di as text _n "Años F107 disponibles : `years_107'"
di as text    "Años F102 disponibles : `years_102'"
di as text    "Años a procesar       : `years_both'" _n

* ============================================================================
* 4. PREPARAR POSTFILE PARA RESULTADOS
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
* 5. LOOP PRINCIPAL — UNA ITERACIÓN POR AÑO
* ============================================================================

foreach yr of local years_both {

    di as result _n "========== Procesando año `yr' =========="

    * ------------------------------------------------------------------
    * 5.1  FORMULARIO 107 — Ingreso de trabajo (relación de dependencia)
    * ------------------------------------------------------------------

    use CEDULA_PK_empleado                  ///
        ingresos_liq_pagados                ///
        sob_suel_com_remu                   ///
        partic_utilidades                   ///
        decimo_tercero                      ///
        decimo_cuarto                       ///
        fondo_reserva                       ///
        base_imponible                      ///
        using "$dir_f107/F107_`yr'.dta", clear

    * Asegurar tipo numérico (datos reales pueden venir como string)
    foreach v of varlist ingresos_liq_pagados sob_suel_com_remu  ///
        partic_utilidades decimo_tercero decimo_cuarto           ///
        fondo_reserva base_imponible {
        capture destring `v', replace force
    }

    * --- Tope décimo cuarto ---
    *     Máximo legal = (SBU/12)*9 + SBU = SBU * 1.75
    local sbu = `sbu_`yr''
    local tope_d14 = (`sbu' / 12) * 9 + `sbu'
    gen decimo_cuarto_dep = min(decimo_cuarto, `tope_d14')

    * --- Tope décimo tercero ---
    *     Máximo = ingreso mensual promedio
    gen decimo_tercero_dep = min(decimo_tercero, ///
        (ingresos_liq_pagados + sob_suel_com_remu) / 12)

    * --- Depuración de fondo de reserva ---
    *     Teórico = (ingresos + sobresueldos + utilidades) * 8,33 %
    egen fondo_reserva_teo = rowtotal(ingresos_liq_pagados ///
        sob_suel_com_remu partic_utilidades)
    replace fondo_reserva_teo = fondo_reserva_teo * 0.0833

    gen coef_fres = fondo_reserva /                         ///
        (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades)
    gen coef_fres_r = round(coef_fres, 0.0001)

    gen freserva_correc = fondo_reserva
    replace freserva_correc = fondo_reserva_teo             ///
        if (freserva_correc > 0 & freserva_correc < .)     ///
         & (coef_fres_r > 0.0833 & coef_fres_r != .)

    * --- Ingreso de trabajo (F107) ---
    gen ingreso_trabajo = base_imponible + decimo_tercero_dep ///
        + decimo_cuarto_dep + freserva_correc

    * Colapsar por persona (puede haber varios empleadores)
    collapse (sum) ingreso_trabajo, by(CEDULA_PK_empleado)
    rename CEDULA_PK_empleado CEDULA_PK

    tempfile f107_yr
    save "`f107_yr'", replace

    * ------------------------------------------------------------------
    * 5.2  FORMULARIO 102 — Ingresos de trabajo (autónomo/empresarial)
    *                        e ingresos de capital
    * ------------------------------------------------------------------

    use CEDULA_PK                             ///
        total_ingresos_1440                   ///
        ing_libre_eje_profesional_2990        ///
        ing_ocupacion_liberal_3010            ///
        ingresos_aem_rie_1280                 ///
        ing_arriendo_inmuebles_3040           ///
        ing_arriendo_otros_act_3080           ///
        rim_pgr_ant_anio_2008_3160            ///
        ingresos_regalias_3170                ///
        rendimientos_financieros_3190         ///
        dividend_recib_soc_resid_5120         ///
        div_recib_soc_no_resid_5130           ///
        ingr_enaj_drc_no_iru_5110             ///
        ingresos_otr_rgr_3193                 ///
        otr_ing_gravados_exterior_3180        ///
        using "$dir_f102/F102_`yr'.dta", clear

    * Corregir variables numéricas con formato string (artefacto del fake data)
    foreach v of varlist _all {
        capture confirm numeric variable `v'
        if !_rc {
            local fmt : format `v'
            if regexm("`fmt'", "s$") {
                format `v' %12.0g
            }
        }
    }

    foreach v of varlist total_ingresos_1440               ///
        ing_libre_eje_profesional_2990                     ///
        ing_ocupacion_liberal_3010 ingresos_aem_rie_1280   ///
        ing_arriendo_inmuebles_3040                        ///
        ing_arriendo_otros_act_3080                        ///
        rim_pgr_ant_anio_2008_3160 ingresos_regalias_3170  ///
        rendimientos_financieros_3190                      ///
        dividend_recib_soc_resid_5120                      ///
        div_recib_soc_no_resid_5130                        ///
        ingr_enaj_drc_no_iru_5110 ingresos_otr_rgr_3193    ///
        otr_ing_gravados_exterior_3180 {
        capture destring `v', replace force
    }

    * Ingreso de trabajo — actividad empresarial (obligados a llevar contab.)
    rename total_ingresos_1440 ING_TRAB_OBLIGADOS

    * Ingreso de trabajo — autónomo / no obligado
    egen ING_TRAB_NO_OBLIGADOS = rowtotal(            ///
        ing_libre_eje_profesional_2990                ///
        ing_ocupacion_liberal_3010                    ///
        ingresos_aem_rie_1280)

    * Ingreso de capital
    egen INGRESOS_CAPITAL = rowtotal(                 ///
        ing_arriendo_inmuebles_3040                   ///
        ing_arriendo_otros_act_3080                   ///
        rim_pgr_ant_anio_2008_3160                    ///
        ingresos_regalias_3170                        ///
        rendimientos_financieros_3190                 ///
        dividend_recib_soc_resid_5120                 ///
        div_recib_soc_no_resid_5130                   ///
        ingr_enaj_drc_no_iru_5110                     ///
        ingresos_otr_rgr_3193                         ///
        otr_ing_gravados_exterior_3180)

    keep CEDULA_PK ING_TRAB_OBLIGADOS ING_TRAB_NO_OBLIGADOS INGRESOS_CAPITAL

    * Colapsar por persona (por si hay declaraciones sustitutivas)
    collapse (sum) ING_TRAB_OBLIGADOS ING_TRAB_NO_OBLIGADOS ///
        INGRESOS_CAPITAL, by(CEDULA_PK)

    tempfile f102_yr
    save "`f102_yr'", replace

    * ------------------------------------------------------------------
    * 5.3  MERGE  F107 ← F102   (por CEDULA_PK)
    * ------------------------------------------------------------------

    use "`f107_yr'", clear
    merge 1:1 CEDULA_PK using "`f102_yr'", nogen

    * Totales de ingreso (rowtotal trata missing como 0)
    egen INGRESOS_TRAB_TOTAL    = rowtotal(ingreso_trabajo ///
        ING_TRAB_OBLIGADOS ING_TRAB_NO_OBLIGADOS)
    egen INGRESOS_CAPITAL_TOTAL = rowtotal(INGRESOS_CAPITAL)
    egen INGRESOS_TOTAL         = rowtotal(INGRESOS_TRAB_TOTAL ///
        INGRESOS_CAPITAL_TOTAL)

    * ------------------------------------------------------------------
    * 5.4  CEROS → MISSING  (sólo para estadísticas descriptivas)
    * ------------------------------------------------------------------

    foreach var in INGRESOS_TRAB_TOTAL INGRESOS_CAPITAL_TOTAL INGRESOS_TOTAL {
        gen `var'_s = `var'
        replace `var'_s = . if `var'_s == 0
    }

    * ------------------------------------------------------------------
    * 5.5  ESTADÍSTICAS POR GRUPO DE PERCENTIL
    * ------------------------------------------------------------------

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
* 6. GUARDAR RESULTADOS EN FORMATO LARGO
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
* 7. EXPORTAR A EXCEL — UNA HOJA POR CONCEPTO DE INGRESO
* ============================================================================

local outfile "$dir_out/Tablas_Renta.xlsx"

* Nombres de percentil en orden deseado
local pnames `""P99-P100" "P95-P100" "P90-P100" "P80-P90" "P70-P80" "P60-P70" "P50-P60" "P1-P50" "Total""'
local npctiles 9

* Conceptos y nombres de hoja (el nombre de hoja replica el formato del Excel original)
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
* 8. FIN
* ============================================================================

di as result _n "============================================="
di as result    "  Proceso completado"
di as result    "============================================="
di as text "Archivos generados:"
di as text "  $dir_out/resultados_renta_percentiles.dta"
di as text "  `outfile'"
di as text ""

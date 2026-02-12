/*******************************************************************************
* PROGRAMA SRI — Declaración de Renta  (1/3)
* Limpieza y merge de formularios F107 y F102
*
* Entrada:  F107_<año>.dta , F102_<año>.dta
* Salida :  merge_renta_<año>.dta  (uno por año, en $dir_temp)
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
global dir_temp "$basedir/Resultados/Merged"

capture mkdir "$dir_out"
capture mkdir "$dir_temp"

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
* 4. LOOP PRINCIPAL — LIMPIEZA Y MERGE POR AÑO
* ============================================================================

foreach yr of local years_both {

    di as result _n "========== Limpieza y merge — año `yr' =========="

    * ------------------------------------------------------------------
    * 4.1  FORMULARIO 107 — Ingreso de trabajo (relación de dependencia)
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
    * 4.2  FORMULARIO 102 — Ingresos de trabajo (autónomo/empresarial)
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
    * 4.3  MERGE  F107 ← F102   (por CEDULA_PK)
    * ------------------------------------------------------------------

    use "`f107_yr'", clear
    merge 1:1 CEDULA_PK using "`f102_yr'", nogen

    gen int anio = `yr'

    save "$dir_temp/merge_renta_`yr'.dta", replace
    di as text "  Guardado: $dir_temp/merge_renta_`yr'.dta"
}

di as result _n "01_limpieza_merge.do completado."

2
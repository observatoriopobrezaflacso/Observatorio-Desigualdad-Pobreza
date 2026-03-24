/*******************************************************************************
* construccion_ingreso_DINA.do
*
* Construye conceptos de ingreso comparables con Cuentas Nacionales (DINA)
* desde los Formularios 107 y 102 del SRI para todos los años disponibles.
* Sigue la estructura de descriptives_ingreso_neto.do pero aplica la
* metodología de ingreso_met_DINA.do para la construcción del ingreso.
*
* Conceptos producidos:
*   PreTaxHHI  = B2B3R + D11R + D4R + D62R + D7R   (ingreso pre-impuesto)
*   B6R        = B5R + D62R + D7N - D5P - D61P       (ingreso disponible)
*   Componentes: B2R, B3R, D1R, D4R, D4N, D62R, D7N, D5P, D61P, B5R
*
* Salidas por año:
*   dir_merged/ingreso_dina_YYYY.dta          (ingreso nominal por declarante)
*
* Salidas consolidadas (serie temporal):
*   dir_out/resultados_dina_percentiles.dta
*   dir_out/Tablas_DINA.xlsx
*******************************************************************************/

clear all
set more off
set maxvar 10000

* ============================================================================
* 0. RUTAS
* ============================================================================

global sri_dir "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Ruthy Intriago"

global dir_f107   "$sri_dir/03 BDD/F107"
global dir_f102   "$sri_dir/03 BDD/F102"

global dir_merged "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/Merged_DINA"

global dir_out    "$sri_dir/Resultados/DINA"

global ipc_file   "$sri_dir/03 BDD/IPC/ipc_adjusted.xls"

capture mkdir "$dir_out"
capture mkdir "$dir_out/Graficos"
capture mkdir "$dir_merged"

global all_yrs "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

* ============================================================================
* 1. SBU POR AÑO
* ============================================================================

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
* 2. IPC — CARGAR DEFLACTORES (BASE 2010)
*
*   ipc_adjusted.xls: columna A = año, columna B = índice de precios
*   Deflactor_t = IPC_t / IPC_2010
*   Ingreso real (precios 2010) = ingreso_nominal_t / Deflactor_t
* ============================================================================

import excel "$ipc_file", firstrow clear
rename A anio
rename B ipc

di as result _n "===== Deflactores IPC (base 2010) ====="

foreach yr of global all_yrs {
    quietly summarize ipc if anio == `yr'
    if r(N) == 0 {
        di as error "  ADVERTENCIA: IPC no encontrado para `yr'"
        scalar ipc_`yr' = .
    }
    else {
        scalar ipc_`yr' = r(mean)
    }
}

scalar ipc_base = scalar(ipc_2010)
di as text "  IPC base (2010): " %8.2f scalar(ipc_base)

foreach yr of global all_yrs {
    if scalar(ipc_`yr') == . {
        scalar defl_`yr' = .
    }
    else {
        scalar defl_`yr' = scalar(ipc_`yr') / scalar(ipc_base)
    }
    di as text "  `yr': IPC = " %8.2f scalar(ipc_`yr') ///
               "  | Deflactor = " %8.4f scalar(defl_`yr')
}

* ============================================================================
* 3. CONSTRUCCIÓN DE CONCEPTOS DINA DESDE F107 + F102
*
*   Los archivos se guardan en valores NOMINALES anuales; la deflación se
*   aplica al construir las estadísticas descriptivas (sección 4).
* ============================================================================

foreach yr of global all_yrs {
*foreach yr in 2015 {

    di as result _n "===== Construyendo ingreso DINA para `yr' ====="

    * ------------------------------------------------------------------
    * 3.1  FORMULARIO 102
    * ------------------------------------------------------------------

    use CEDULA_PK                           ///
        ing_syo_trabajo_rde_3240            ///  Salarios rel. dependencia (3240)
        ded_syo_trabajo_rde_3250            ///  IESS empleado F102 (3250)
        utilidad_neta_ejercicio_2800        ///  Utilidad neta (contabilidad)
        perdida_ejercicio_2810              ///  Pérdida ejercicio (contabilidad)
        ingresos_aem_rie_1280               ///  Ingreso empresarial / RIMPE (1280)
        deducciones_aem_rie_1290            ///  Deducción empresarial / RIMPE (1290)
        ingresos_sir_2988                   ///  Ingresos SIR (2988)
        ing_libre_eje_profesional_2990      ///  Libre ejercicio profesional (2990)
        ded_libre_eje_profesional_3000      ///  Ded. libre ejercicio (3000)
        ing_ocupacion_liberal_3010          ///  Ocupación liberal (3010)
        ded_ocupacion_liberal_3020          ///  Ded. ocupación liberal (3020)
        otr_ing_gravados_exterior_3180      ///  Otros ing. gravados exterior (3180)
        otr_ingresos_exentos_3460           ///  Otros ingresos exentos (3460)
        ing_arriendo_inmuebles_3040         ///  Arriendo inmuebles -B2- (3040)
        ded_arriendo_inmuebles_3050         ///  Ded. arriendo inmuebles (3050)
        rim_arriendo_otros_act_3100         ///  Renta otros activos -D45- (3100)
        rim_predios_agricolas_3164          ///  Renta predios agrícolas (3164)
        ingresos_regalias_3170              ///  Regalías (3170)
        rendimientos_financieros_3190       ///  Intereses recibidos -D41- (3190)
        dividendos_recibidos_3192           ///  Dividendos -D42- (3192)
        ingresos_otr_rgr_3193               ///  Otros ingresos gravados (3193)
        deducciones_otr_rgr_3194            ///  Ded. otras rentas gravadas (3194)
        img_herencias_leg_don_3420          ///  Herencias, legados, donaciones (3420)
        ipa_herencias_leg_don_3410          ///  Impuesto herencias (3410)
        ing_lot_rifas_apuestas_3400         ///  Loterías y rifas (3400)
        ipa_lot_rifas_apuestas_3390         ///  Impuesto loterías (3390)
        ing_pensiones_jubilares_3450        ///  Pensiones jubilares -D62- (3450)
        imp_renta_causado_3490              ///  Impuesto a la renta causado (3490)
        using "$dir_f102/F102_anonimizada_`yr'.dta", clear

    foreach v of varlist _all {
        if "`v'" != "CEDULA_PK" {
            capture confirm string variable `v'
            if !_rc capture destring `v', replace force
            replace `v' = 0 if `v' == .
        }
    }

    tempfile f102_yr
    save "`f102_yr'", replace

    * ------------------------------------------------------------------
    * 3.2  FORMULARIO 107
    * ------------------------------------------------------------------

    use CEDULA_PK_empleado                  ///
        ingresos_liq_pagados                ///  Sueldos y salarios
        sob_suel_com_remu                   ///  Sobresueldos, comisiones, bonos
        partic_utilidades                   ///  Participación de utilidades
        decimo_tercero                      ///  Décimo tercer sueldo
        decimo_cuarto                       ///  Décimo cuarto sueldo
        fondo_reserva                       ///  Fondo de reserva
        aporte_iess_empleado                ///  Aporte personal IESS
        imp_renta_causado                   ///  Impuesto a la renta (F107)
        using "$dir_f107/F107_anonimizada_`yr'.dta", clear

    rename CEDULA_PK_empleado CEDULA_PK
    rename imp_renta_causado imp_renta_causado_f107

    foreach v of varlist _all {
        if "`v'" != "CEDULA_PK" {
            capture confirm string variable `v'
            if !_rc capture destring `v', replace force
        }
    }

    * Corrección fondo de reserva: si el coeficiente declarado supera 8,33%,
    * se reemplaza por el valor teórico (base: sueldos + sobresueldos + utilidades)
    gen fondo_reserva_teo = ///
        (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades) * 0.0833
    gen coef_fres   = fondo_reserva / ///
        (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades)
    gen coef_fres_r = round(coef_fres, 0.0001)
    gen freserva_correc = fondo_reserva
    replace freserva_correc = fondo_reserva_teo ///
        if (freserva_correc > 0 & freserva_correc < .) ///
         & (coef_fres_r > 0.0833 & coef_fres_r != .)
    drop fondo_reserva_teo coef_fres coef_fres_r

    * liq_107: base salarial F107 (sin topes en décimos, siguiendo metodología DINA)
    egen liq_107 = rowtotal(ingresos_liq_pagados sob_suel_com_remu ///
        partic_utilidades freserva_correc decimo_cuarto decimo_tercero)

    * ------------------------------------------------------------------
    * 3.3  MERGE F107 ← F102
    * ------------------------------------------------------------------

    merge m:m CEDULA_PK using "`f102_yr'"
    erase "`f102_yr'"

    * Valores post-merge ausentes en F107 (registros solo-F102) se asignan a 0
    foreach v in liq_107 aporte_iess_empleado imp_renta_causado_f107 {
        replace `v' = 0 if `v' == .
    }

    * ------------------------------------------------------------------
    * 3.4  CORRECCIÓN DE VALORES IMPOSIBLES EN HERENCIAS Y RIFAS
    * ------------------------------------------------------------------

    * Herencias: tasa marginal máxima observada ~15%; se corrige ingreso e impuesto
    tempvar herencia_new herencia_imp_max
    gen `herencia_new' = img_herencias_leg_don_3420 ///
        if img_herencias_leg_don_3420 > 0 ///
        & ((img_herencias_leg_don_3420 >= ipa_herencias_leg_don_3410) ///
           | ipa_herencias_leg_don_3410 == .)
    replace `herencia_new' = ipa_herencias_leg_don_3410 ///
        if img_herencias_leg_don_3420 < ipa_herencias_leg_don_3410 ///
        & ipa_herencias_leg_don_3410 != .
    replace img_herencias_leg_don_3420 = `herencia_new'
    gen `herencia_imp_max' = `herencia_new' * 0.15
    replace ipa_herencias_leg_don_3410 = `herencia_imp_max' ///
        if ipa_herencias_leg_don_3410 > `herencia_imp_max'

    * Rifas/Loterías: impuesto único del 15%; se corrige ingreso e impuesto
    tempvar rifa_new rifa_imp_new
    gen `rifa_new' = ing_lot_rifas_apuestas_3400 ///
        if ing_lot_rifas_apuestas_3400 > 0 ///
        & ing_lot_rifas_apuestas_3400 > ipa_lot_rifas_apuestas_3390
    replace `rifa_new' = ipa_lot_rifas_apuestas_3390 ///
        if ing_lot_rifas_apuestas_3400 < ipa_lot_rifas_apuestas_3390
    replace ing_lot_rifas_apuestas_3400 = `rifa_new'
    gen `rifa_imp_new' = `rifa_new' * 0.15
    replace ipa_lot_rifas_apuestas_3390 = `rifa_imp_new' ///
        if ipa_lot_rifas_apuestas_3390 > `rifa_imp_new'

    * ------------------------------------------------------------------
    * 3.5  B2R: EXCEDENTE DE EXPLOTACIÓN
    *           Renta neta de inmuebles (propietario-ocupante = 0)
    * ------------------------------------------------------------------

    gen B2R = ing_arriendo_inmuebles_3040 - ded_arriendo_inmuebles_3050 ///
        if ing_arriendo_inmuebles_3040 > 0
    replace B2R = 0 if B2R == .

    * ------------------------------------------------------------------
    * 3.6  B3R: INGRESO MIXTO
    * ------------------------------------------------------------------

    tempvar util_cont util_noc util_otros

    * Empresas con contabilidad: utilidad neta; pérdidas multiplicadas por -1
    gen `util_cont' = 0
    replace `util_cont' = utilidad_neta_ejercicio_2800 ///
        if utilidad_neta_ejercicio_2800 > 0
    replace `util_cont' = perdida_ejercicio_2810 * -1 ///
        if perdida_ejercicio_2810 > 0
    replace `util_cont' = 0 if `util_cont' < 0

    * Empresas sin contabilidad / RIMPE
    gen `util_noc' = ingresos_aem_rie_1280 - deducciones_aem_rie_1290
    replace `util_noc' = 0 if `util_noc' < 0

    * Trabajo autónomo, liberal, exterior y exentos
    egen `util_otros' = rowtotal(ingresos_sir_2988                 ///
        ing_libre_eje_profesional_2990 ing_ocupacion_liberal_3010  ///
        otr_ing_gravados_exterior_3180 otr_ingresos_exentos_3460)
    replace `util_otros' = `util_otros'                            ///
        - ded_libre_eje_profesional_3000 - ded_ocupacion_liberal_3020
    replace `util_otros' = 0 if `util_otros' < 0

    egen B3R = rowtotal(`util_cont' `util_noc' `util_otros')

    * ------------------------------------------------------------------
    * 3.7  D11R, D613P: SALARIOS Y APORTES AL IESS
    *
    *   Cuando el declarante aparece en ambos formularios (_merge==3),
    *   se aplica la reconciliación de dos etapas del enfoque DINA:
    *   primero se elige la fuente de mayor ingreso (D11R), luego
    *   se elige la fuente de mayor IESS considerando la consistencia
    *   entre ingreso y aporte (D613P).
    * ------------------------------------------------------------------

    * Corrección de aportes imposibles en F107 (IESS > base salarial)
    tempvar liq_foriess iess_porc_107 dif_107 iess_porc_102 dif_102
    egen `liq_foriess' = rowtotal(ingresos_liq_pagados sob_suel_com_remu partic_utilidades)
    gen `iess_porc_107' = aporte_iess_empleado / `liq_foriess'
    gen `dif_107' = `liq_foriess' - aporte_iess_empleado ///
        if (_merge == 1 | _merge == 3)
    quietly sum `iess_porc_107' ///
        if (_merge == 1 | _merge == 3) & aporte_iess_empleado != 0
    local iess_mean_107 = r(mean)
    replace aporte_iess_empleado = `iess_mean_107' * `liq_foriess' ///
        if `dif_107' <= 0

    * Corrección de aportes imposibles en F102 (IESS > salario declarado)
    gen `iess_porc_102' = ded_syo_trabajo_rde_3250 / ing_syo_trabajo_rde_3240
    gen `dif_102' = ing_syo_trabajo_rde_3240 - ded_syo_trabajo_rde_3250 ///
        if (_merge == 2 | _merge == 3)
    quietly sum `iess_porc_102' ///
        if (_merge == 2 | _merge == 3) & ing_syo_trabajo_rde_3240 != 0
    local iess_mean_102 = r(mean)
    replace ded_syo_trabajo_rde_3250 = `iess_mean_102' * ing_syo_trabajo_rde_3240 ///
        if `dif_102' <= 0

    * Indicadores de comparación entre formularios (usados solo cuando _merge==3)
    gen inc_102_g_107 = (ing_syo_trabajo_rde_3240 > liq_107 ///
        & ing_syo_trabajo_rde_3240 != .)
    replace inc_102_g_107 = 0 ///
        if inc_102_g_107 != 1 & ing_syo_trabajo_rde_3240 != .

    gen iess_102_g_107 = (ded_syo_trabajo_rde_3250 > aporte_iess_empleado ///
        & ded_syo_trabajo_rde_3250 != .)
    replace iess_102_g_107 = 0 ///
        if iess_102_g_107 != 1 & ded_syo_trabajo_rde_3250 != .

    * D11R: mejor estimador de salario
    gen D11R = liq_107                  if _merge == 1
    replace D11R = ing_syo_trabajo_rde_3240 if _merge == 2
    replace D11R = ing_syo_trabajo_rde_3240 if _merge == 3 & inc_102_g_107 == 1
    replace D11R = liq_107                  if _merge == 3 & inc_102_g_107 == 0

    * D613P: mejor estimador de IESS empleado
    gen D613P = aporte_iess_empleado     if _merge == 1
    replace D613P = ded_syo_trabajo_rde_3250 if _merge == 2

    * Ambos formularios: decisión conjunta sobre ingreso e IESS
    replace D613P = ded_syo_trabajo_rde_3250 ///
        if _merge == 3 & inc_102_g_107 == 1 & iess_102_g_107 == 1
    replace D613P = aporte_iess_empleado ///
        if _merge == 3 & inc_102_g_107 == 0 & iess_102_g_107 == 0

    * F102 mayor ingreso, F107 mayor IESS: usar F107 si tasa IESS en F102 es ≤ 1%
    replace D613P = aporte_iess_empleado ///
        if _merge == 3 & inc_102_g_107 == 1 & iess_102_g_107 == 0 ///
        & (ded_syo_trabajo_rde_3250 / ing_syo_trabajo_rde_3240) <= 0.01
    replace D613P = ded_syo_trabajo_rde_3250 ///
        if _merge == 3 & inc_102_g_107 == 1 & iess_102_g_107 == 0 ///
        & (ded_syo_trabajo_rde_3250 / ing_syo_trabajo_rde_3240) > 0.01

    * F107 mayor ingreso, F102 mayor IESS: usar F102 si tasa IESS en F107 es ≤ 1%
    replace D613P = ded_syo_trabajo_rde_3250 ///
        if _merge == 3 & inc_102_g_107 == 0 & iess_102_g_107 == 1 ///
        & (aporte_iess_empleado / liq_107) <= 0.01
    replace D613P = aporte_iess_empleado ///
        if _merge == 3 & inc_102_g_107 == 0 & iess_102_g_107 == 1 ///
        & (aporte_iess_empleado / liq_107) > 0.01

    gen D611P = 0   // Cotizaciones patronales (imputadas en pasos posteriores)
    gen D121R = 0   // Sueldos en especie

    * ------------------------------------------------------------------
    * 3.8  D4R: INGRESO DE LA PROPIEDAD
    * ------------------------------------------------------------------

    gen D41R = rendimientos_financieros_3190                        // Intereses
    gen D42R = dividendos_recibidos_3192                            // Dividendos

    * D45R: Rentas (otros activos, predios agrícolas, regalías, otros, herencias)
    egen D45R = rowtotal(rim_arriendo_otros_act_3100 rim_predios_agricolas_3164 ///
        ingresos_regalias_3170 ingresos_otr_rgr_3193 img_herencias_leg_don_3420)
    replace D45R = D45R - deducciones_otr_rgr_3194

    egen D4R = rowtotal(D41R D42R D45R)
    gen D4P  = 0
    gen D4N  = D4R - D4P

    * ------------------------------------------------------------------
    * 3.9  D62R: PRESTACIONES SOCIALES (PENSIONES JUBILARES)
    * ------------------------------------------------------------------

    gen D62R = ing_pensiones_jubilares_3450

    * ------------------------------------------------------------------
    * 3.10  D7N: OTRAS TRANSFERENCIAS CORRIENTES (NETAS)
    * ------------------------------------------------------------------

    gen D75R = ing_lot_rifas_apuestas_3400
    gen D7R  = D75R
    gen D7P  = 0
    gen D7N  = D7R - D7P

    * ------------------------------------------------------------------
    * 3.11  D5P: IMPUESTO SOBRE LA RENTA
    *
    *   Corrección: se incorpora el impuesto de F107 cuando supera al de F102
    *   y se trunca a una tasa efectiva máxima del 50% sobre la base gravable.
    * ------------------------------------------------------------------

    tempvar base_gravable
    egen `base_gravable' = rowtotal(D11R D121R B2R B3R D4N D62R D7N)
    replace `base_gravable' = 0 if `base_gravable' < 0

    replace imp_renta_causado_3490 = imp_renta_causado_f107 ///
        if _merge == 1
    replace imp_renta_causado_3490 = imp_renta_causado_f107 ///
        if _merge == 3 & imp_renta_causado_f107 > imp_renta_causado_3490

    replace imp_renta_causado_3490 = `base_gravable' * 0.5 ///
        if imp_renta_causado_3490 > `base_gravable' * 0.5

    egen D5P = rowtotal(imp_renta_causado_3490 ///
        ipa_lot_rifas_apuestas_3390 ipa_herencias_leg_don_3410)

    * ------------------------------------------------------------------
    * 3.12  AGREGADOS DINA
    * ------------------------------------------------------------------

    egen B2B3R = rowtotal(B2R B3R)
    egen D1R   = rowtotal(D11R D121R)
    egen D61P  = rowtotal(D611P D613P)
    egen B5R   = rowtotal(B2B3R D1R D4N)

    * PreTaxHHI: ingreso pre-impuesto (variable de distribución principal)
    egen PreTaxHHI = rowtotal(B2B3R D11R D4R D62R D7R)

    * B6R: ingreso disponible
    egen B6R = rowtotal(B5R D62R D7N)
    replace B6R = B6R - D5P - D61P

    * ------------------------------------------------------------------
    * 3.13  RETENER SOLO INGRESOS POSITIVOS
    * ------------------------------------------------------------------

    keep if PreTaxHHI > 0

    * ------------------------------------------------------------------
    * 3.14  COLAPSAR POR CEDULA (declaraciones sustitutivas)
    * ------------------------------------------------------------------

    local final_vars PreTaxHHI B6R B2R B3R B2B3R D1R D4R D4N D62R D7R D7N D5P D61P B5R

    collapse (sum) `final_vars', by(CEDULA_PK _merge)

    drop if CEDULA_PK == ""
    gen anio = `yr'

    quietly count if PreTaxHHI > 0 & PreTaxHHI != .
    di as text "  N con PreTaxHHI > 0 (nominal): " r(N)

    save "$dir_merged/ingreso_dina_`yr'.dta", replace
    di as text "  Guardado: $dir_merged/ingreso_dina_`yr'.dta"

}

* ============================================================================
* 4. PREPARAR POSTFILE PARA RESULTADOS DESCRIPTIVOS
* ============================================================================

tempname results
tempfile results_file

postfile `results'                              ///
    int(anio)                                   ///
    str30(concepto)                             ///
    str10(percentil)                            ///
    double(suma media mediana sd vmin vmax pct_total) ///
    long(N)                                     ///
    using "`results_file'", replace

foreach yr of global all_yrs {

    di "`yr'"

    use "$dir_merged/ingreso_dina_`yr'.dta", clear

    drop if PreTaxHHI <= 0 | PreTaxHHI == .

    * ------------------------------------------------------------------
    * Deflactar a precios de 2010 y convertir a valores mensuales
    * ------------------------------------------------------------------

    local defl = scalar(defl_`yr')

    foreach var in PreTaxHHI B6R {
        gen `var'_s = (`var' / `defl') / 12
        replace `var'_s = . if `var'_s == 0
    }

    * ------------------------------------------------------------------
    * Estadísticas por grupo de percentil
    * ------------------------------------------------------------------

    local concepts      PreTaxHHI            B6R
    local concepts_lbl `""Ingreso Pre-impuesto" "Ingreso Disponible"'

    local c 1
    foreach concept of local concepts {
        di "`c'"

        local lbl : word `c' of `concepts_lbl'
        local svar "`concept'_s"

        quietly count if `svar' != .
        if r(N) < 2 {
            di as text "  NOTA: `lbl' — menos de 2 obs no-missing; se omite."
            local ++c
            continue
        }

        quietly _pctile `svar', percentiles(50 90 95 99)
        local p50 = r(r1)
        local p90 = r(r2)
        local p95 = r(r3)
        local p99 = r(r4)

        di " `p50'  / `p90'  /  `p95'  / `p99' "

        quietly summarize `svar'
        local total_sum = r(sum)
        if `total_sum' == 0 local total_sum 1

        quietly {
            gen byte _g1_`c' = (`svar' >= `p99' & `svar' != .)
            gen byte _g2_`c' = (`svar' >= `p95' & `svar' != .)
            gen byte _g3_`c' = (`svar' >= `p90' & `svar' != .)
            gen byte _g4_`c' = (`svar' <= `p50' & `svar' != .)
            gen byte _g5_`c' = (`svar' != .)
        }

        local gname1 "P99-P100"
        local gname2 "P95-P100"
        local gname3 "P90-P100"
        local gname4 "P1-P50"
        local gname5 "Total"

        forvalues g = 1/5 {
            summarize `svar' if _g`g'_`c' == 1, detail
            if r(N) > 0 {
                post `results' (`yr') ("`lbl'") ("`gname`g''")      ///
                    (r(sum)) (r(mean)) (r(p50)) (r(sd)) (r(min)) (r(max)) ///
                    ((r(sum) / `total_sum') * 100) (r(N))
            }
            else {
                post `results' (`yr') ("`lbl'") ("`gname`g''")      ///
                    (0) (.) (.) (.) (.) (.) (0) (0)
            }
        }

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
label var sd        "Desv. Est."
label var vmin      "Mínimo"
label var vmax      "Máximo"
label var pct_total "% del ingreso total"
label var N         "Número de observaciones"

save "$dir_out/resultados_dina_percentiles.dta", replace

* ============================================================================
* 6. EXPORTAR A EXCEL — UNA HOJA POR CONCEPTO DE INGRESO
* ============================================================================

local outfile "$dir_out/Tablas_DINA.xlsx"

local pnames   `""P99-P100" "P95-P100" "P90-P100" "P1-P50" "Total""'
local npctiles 5

local sheet_concepts `""Ingreso Pre-impuesto" "Ingreso Disponible"'
local sheet_names    `""PreTaxHHI"             "B6R"'

local sc 1
foreach concept of local sheet_concepts {

    local shname : word `sc' of `sheet_names'

    use "$dir_out/resultados_dina_percentiles.dta", clear
    keep if concepto == "`concept'"

    gen pctil_order = .
    forvalues p = 1/`npctiles' {
        local pn : word `p' of `pnames'
        replace pctil_order = `p' if percentil == "`pn'"
    }

    drop concepto percentil

    reshape wide suma media sd N mediana vmin vmax pct_total, ///
        i(anio) j(pctil_order)

    local ordered "anio"
    forvalues p = 1/`npctiles' {
        local ordered "`ordered' suma`p' media`p' sd`p' N`p' mediana`p' pct_total`p' vmin`p' vmax`p'"
    }
    order `ordered'

    label var anio "Año"
    forvalues p = 1/`npctiles' {
        local pn : word `p' of `pnames'
        label var suma`p'      "`pn': Suma total"
        label var media`p'     "`pn': Media"
        label var sd`p'        "`pn': Desv. Est."
        label var N`p'         "`pn': N"
        label var mediana`p'   "`pn': Mediana"
        label var pct_total`p' "`pn': % del total"
        label var vmin`p'      "`pn': Min"
        label var vmax`p'      "`pn': Max"
    }

    format suma* %15.2fc
    format media* mediana* vmin* vmax* %12.2fc
    format pct_total* %6.2f
    format N* %12.0fc

    sort anio

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
di as text "  $dir_out/resultados_dina_percentiles.dta"
di as text "  `outfile'"
di as text ""

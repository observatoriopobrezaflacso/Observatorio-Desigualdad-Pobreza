/*******************************************************************************
* construir_ingreso_dina_falso.do
*
* Copia de SRI/Procesamiento/Codigos/Renta/construccion_ingreso_DINA.do,
* recortada a la sección 3 (construcción de PreTaxHHI por declarante), con
* rutas a las bases falsas de Datos_falsos (Google Drive, Papers/Bunching). La lógica de
* construcción no se modificó; solo cambian rutas y nombres de archivo
* (F102_YYYY.dta en vez de F102_anonimizada_YYYY.dta) y se omiten IPC y
* estadísticas por percentil, que no hacen falta para el bunching.
*
* Salida: Datos_falsos/Merged_DINA/ingreso_dina_YYYY.dta
*******************************************************************************/

clear all
set more off
set maxvar 10000

global dir_base   "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/Datos_falsos"
global dir_f107   "$dir_base/F107"
global dir_f102   "$dir_base/F102"
global dir_merged "$dir_base/Merged_DINA"
capture mkdir "$dir_merged"

* Años con F102 y F107 disponibles
global all_yrs "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

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
        using "$dir_f102/F102_`yr'.dta", clear

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
        using "$dir_f107/F107_`yr'.dta", clear

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


di as result "Listo: ingreso_dina_YYYY.dta en $dir_merged"

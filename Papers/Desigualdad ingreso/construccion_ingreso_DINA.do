*
* Salidas por par de años (2010 → YYYY):
*   dir_merged/ingreso_neto_YYYY.dta          (ingreso nominal por declarante)
*   dir_out/panel_pareado_ingreso_neto_2010_YYYY.dta
*   dir_out/indices_movilidad_2010_YYYY.dta
*   dir_out/top_income_shares_2010_YYYY.dta
*   dir_out/persistencia_top_2010_YYYY.dta
*   dir_out/matriz_transicion_2010_YYYY.dta
*   dir_out/crecimiento_decil_2010_YYYY.dta
*   dir_out/centile_effects_2010_YYYY.dta
*   dir_out/Graficos/[tipo]_2010_YYYY.pdf
*
* Salidas consolidadas (serie temporal):
*   dir_out/serie_movilidad_2010.dta
*   dir_out/Movilidad_Ingreso_Neto_Serie.xlsx
*******************************************************************************/

clear all
set more off
discard
set maxvar 10000

* ============================================================================
* 0. RUTAS
* ============================================================================


* Raíz del proyecto SRI
* Si dir_sri ya está definido (p. ej. datos falsos, Papers/Bunching/
* construir_ingreso_dina_falso.do), se respeta; si no, se usa el servidor.
if "$dir_sri" == "" global dir_sri "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

* Datos administrativos SRI (formularios por año)
global dir_f107    "$dir_sri/03 BDD/SRI/IR/F107"
global dir_f102    "$dir_sri/03 BDD/SRI/IR/F102"
global dir_clean   "$dir_sri/03 BDD/SRI/IR/F102/Clean"

* Directorio de datos merged (salida de ingreso_neto por año)
global dir_merged  "$dir_sri/03 BDD/SRI/IR/Merged/ingreso_dina"
global dir_isd     "$dir_sri/03 BDD/MID"

* ENEMDU diciembre (para totales de control)
*global dir_enemdu  "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Boletín 1/Procesamiento/Bases/enemdu_diciembres"


capture mkdir "$dir_merged"
capture mkdir  "$dir_clean"

global ipc_file  "$dir_sri/03 BDD/IPC/ipc_adjusted.xls"


*global dir_enemdu "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Boletín 1/Procesamiento/Bases/enemdu_diciembres"


* Años con datos disponibles en F107/F102 (sin 2021–2023 en la base actual)
global all_yrs "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"
*global all_yrs "2010 2012"


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
* 3. CONSTRUCCIÓN DE CONCEPTOS DINA DESDE F107 + F102
*
*   Los archivos se guardan en valores NOMINALES anuales; la deflación se
*   aplica al construir las estadísticas descriptivas (sección 4).
* ============================================================================

*foreach yr of global all_yrs {
foreach yr of numlist 2010(1)2024 {
*foreach yr of numlist 2010 {

    di as result _n "===== Construyendo ingreso DINA para `yr' ====="


	* ------------------------------------------------------------------
    * 3.3  MID
    * ------------------------------------------------------------------
	
	
	/*
	if (inrange(`yr', 2018, 2024)) {
	use "$dir_isd/MID_anonimizada`yr'.dta", replace	
	
	rename id_anonimizado_ci CEDULA_PK
	keep CEDULA_PK anio impuesto_salida_divisas_neto
	
	tempfile isd_data
	save `isd_data'
	}
	*/
	
    * ------------------------------------------------------------------
    * 3.2  FORMULARIO 107
    * ------------------------------------------------------------------

    use "$dir_f107/F107_anonimizada_`yr'.dta", clear

	keep CEDULA_PK_empleado                  ///
		 RUC_PK_empleado                     ///
		 RUC_PK_empleador                    ///
         ingresos_liq_pagados                ///  Sueldos y salarios
         sob_suel_com_remu                   ///  Sobresueldos, comisiones, bonos
         partic_utilidades                   ///  Participación de utilidades
         decimo_tercero                      ///  Décimo tercer sueldo
         decimo_cuarto                       ///  Décimo cuarto sueldo
         fondo_reserva                       ///  Fondo de reserva
         aporte_iess_empleado                ///  Aporte personal IESS
         imp_renta_causado                   ///  Impuesto a la renta (F107)
         base_imponible                      ///  Base imponible (bunching)
         ingreso_grav_otr_empleador          //  Ingresos con otros empleadores (bunching)
	
    rename CEDULA_PK_empleado CEDULA_PK
	
    rename imp_renta_causado imp_renta_causado_f107

    foreach v of varlist _all {
        if !inlist("`v'", "CEDULA_PK", "RUC_PK_empleado", "RUC_PK_empleador") {
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
	
	* Correción décimos 
	
	gen decimo_cuarto_corr = min(decimo_cuarto, ((`sbu_`yr''/12)*9*3))
    gen decimo_tercero_corr = min(decimo_tercero, (ingresos_liq_pagad + sob_suel_com_remu)/12)

	
	
    * liq_107: base salarial F107 (sin topes en décimos, siguiendo metodología DINA)
    egen liq_107 = rowtotal(ingresos_liq_pagados sob_suel_com_remu ///
        partic_utilidades freserva_correc decimo_cuarto_corr decimo_tercero_corr)
	
	if (`yr' == 2010) tostring RUC_PK_empleador, replace
    drop if CEDULA_PK == ""

	* ------------------------------------------------------------------
	* 3.2b  VARIABLES PARA BUNCHING (Papers/Bunching/bunching_renta.do)
	*
	*   Se calculan antes del collapse, a nivel persona-empleador:
	*     n_emp_107       número de empleadores distintos (RUC_PK_empleador)
	*     base107_max     base imponible F107 más alta entre empleadores
	*     base107_sum     suma de las bases F107 de todos los empleadores
	*     otr_emp_107     suma de ingreso_grav_otr_empleador
	*     tasa_iess_107   aporte personal al IESS / (sueldos + sobresueldos)
	*                     del registro F107 con la base más alta de la persona
	*     publico_107     1 = servidor público: en algún registro F107 la tasa
	*                     de aporte personal está en [$iess_pub_lo, $iess_pub_hi]
	*                     (máximo entre empleadores: basta un empleador público)
	*   Varios F107 de la misma persona, del mismo empleador o de otros, se
	*   suman (indicación del SRI): ingreso_grav_otr_empleador no entra en el
	*   cálculo de base_imponible, así que sumar no duplica ingresos.
	*
	*   Servidor público: el aporte personal al IESS es 11,45% en el sector
	*   público y 9,45% en el privado (sobre sueldos y sobresueldos; décimos,
	*   fondo de reserva y utilidades no aportan). Se usa una banda alrededor
	*   de 11,45% para tolerar redondeos y meses con otra remuneración; queda
	*   lejos de 9,45%. Sin sueldos ni sobresueldos la tasa es missing y
	*   publico_107 también, si ningún registro de la persona tiene tasa.
	* ------------------------------------------------------------------

	global iess_pub_lo 0.110     // banda de la tasa de aporte personal del sector público (11,45%)
	global iess_pub_hi 0.119

	preserve
		keep CEDULA_PK RUC_PK_empleador base_imponible ingreso_grav_otr_empleador ///
		     aporte_iess_empleado ingresos_liq_pagados sob_suel_com_remu
		replace RUC_PK_empleador = "sin_ruc_" + string(_n) if inlist(RUC_PK_empleador, "", ".")

		* Tasa de aporte personal de cada registro y marca de sector público
		egen double rem_iess = rowtotal(ingresos_liq_pagados sob_suel_com_remu)
		gen double tasa_iess = aporte_iess_empleado / rem_iess if rem_iess > 0
		gen byte publico = inrange(tasa_iess, $iess_pub_lo, $iess_pub_hi) if !missing(tasa_iess)

		* Tasa del registro con la base más alta de la persona (empates: el
		* primer RUC en orden alfabético)
		gsort CEDULA_PK -base_imponible RUC_PK_empleador
		by CEDULA_PK: gen double tasa_iess_107 = tasa_iess[1]

		collapse (sum) base_imponible ingreso_grav_otr_empleador ///
		         (max) publico tasa_iess_107, by(CEDULA_PK RUC_PK_empleador)
		bysort CEDULA_PK: gen int n_emp_107 = _N
		collapse (first) n_emp_107                                      ///
		         (sum)   base107_sum = base_imponible                   ///
		                 otr_emp_107 = ingreso_grav_otr_empleador       ///
		         (max)   base107_max = base_imponible                   ///
		                 publico_107 = publico                          ///
		                 tasa_iess_107, by(CEDULA_PK)
		tempfile bunch107
		save `bunch107'
	restore

	
	bysort CEDULA_PK (RUC_PK_empleador): gen RUC_empleador_combined = RUC_PK_empleador if _n == 1
	bysort CEDULA_PK (RUC_PK_empleador): replace RUC_empleador_combined = RUC_empleador_combined[_n - 1]  + ", " + RUC_PK_empleador if _n > 1
	bysort CEDULA_PK: replace RUC_empleador_combined = RUC_empleador_combined[_N]
	
	
    collapse (first) RUC_PK_empleado RUC_empleador_combined ///
	         (sum) liq_107 ///
				   aporte_iess_empleado ///
				   imp_renta_causado_f107 ///
				   ingresos_liq_pagados ///
				   sob_suel_com_remu ///
				   partic_utilidades ///
				   freserva_correc ///
				   decimo_cuarto_corr ///
				   decimo_tercero_corr, by(CEDULA_PK)
	
	split RUC_empleador_combined, parse(", ") gen(RUC_PK_empleador)

	merge 1:1 CEDULA_PK using `bunch107', nogen

	 
    * ------------------------------------------------------------------
    * 3.3  MERGE F107 ← F102
    * ------------------------------------------------------------------

	
    * F102 limpio (limpiar_F102.do): una fila por CEDULA_PK, variables
    * continuas convertidas a número y valores ausentes asignados a 0. Por eso
    * un 0 en una variable del F102 puede ser "no declarado". Los registros
    * solo-F107 (_merge == 1) sí quedan con missing en estas variables.
    merge 1:1 CEDULA_PK using "$dir_clean/F102_clean_`yr'_2.dta"
		
	
	/*
    if (inrange(`yr', 2018, 2024)) {
	merge m:m CEDULA_PK using `isd_data', nogen
	rename impuesto_salida_divisas_neto D5P_ISD	
	}
*/

    * Valores post-merge ausentes en F107 (registros solo-F102) se asignan a 0
    foreach v in liq_107 aporte_iess_empleado imp_renta_causado_f107 {
        replace `v' = 0 if `v' == .
    }

	* ------------------------------------------------------------------
	* 3.3b  VARIABLES F102 PARA BUNCHING
	*
	*   base102      base imponible del F102 (base_imponible_3480)
	*   rimpe        1 = sujeto a RIMPE (suj_reg_rimpe_4896 = SI; desde 2022)
	*   rimpe_bruto  ingresos brutos gravados RIMPE (bas_imp_grav_reg_rimpe_5687)
	*   emp_bruto    ingresos empresariales brutos (ingresos_aem_rie_1280)
	*   Si el F102 limpio no trae alguna de estas variables, se leen solo esas
	*   columnas del F102 original.
	* ------------------------------------------------------------------

	local bunch102 base_imponible_3480 suj_reg_rimpe_4896 bas_imp_grav_reg_rimpe_5687
	local faltan ""
	foreach v of local bunch102 {
		capture confirm variable `v'
		if _rc local faltan "`faltan' `v'"
	}
	if "`faltan'" != "" {
		quietly describe using "$dir_f102/F102_anonimizada_`yr'.dta", varlist
		local avail `r(varlist)'
		local traer : list faltan & avail
		di as text "  Variables de bunching tomadas del F102 original: `traer'"
		if "`traer'" != "" {
			preserve
				use CEDULA_PK `traer' using "$dir_f102/F102_anonimizada_`yr'.dta", clear
				drop if CEDULA_PK == ""
				foreach v of local traer {
					capture confirm string variable `v'
					if !_rc & "`v'" != "suj_reg_rimpe_4896" destring `v', replace force
				}
				* Declaraciones sustitutivas: se toma el valor más alto
				if strpos("`traer'", "suj_reg_rimpe_4896") {
					gen byte _rimpe = upper(strtrim(suj_reg_rimpe_4896)) == "SI"
					drop suj_reg_rimpe_4896
					rename _rimpe suj_reg_rimpe_4896
				}
				collapse (max) `traer', by(CEDULA_PK)
				tempfile f102bunch
				save `f102bunch'
			restore
			merge m:1 CEDULA_PK using `f102bunch', keep(1 3) nogen
		}
	}

	capture confirm variable base_imponible_3480
	if !_rc {
		capture destring base_imponible_3480, replace force
		gen double base102 = base_imponible_3480
	}
	else gen double base102 = .

	gen byte rimpe = 0
	capture confirm variable suj_reg_rimpe_4896
	if !_rc & `yr' >= 2022 {
		capture confirm string variable suj_reg_rimpe_4896
		if !_rc replace rimpe = upper(strtrim(suj_reg_rimpe_4896)) == "SI"
		else    replace rimpe = suj_reg_rimpe_4896 == 1
	}

	capture confirm variable bas_imp_grav_reg_rimpe_5687
	if !_rc & `yr' >= 2022 {
		capture destring bas_imp_grav_reg_rimpe_5687, replace force
		gen double rimpe_bruto = bas_imp_grav_reg_rimpe_5687
	}
	else gen double rimpe_bruto = .

	gen double emp_bruto = ingresos_aem_rie_1280

    * ------------------------------------------------------------------
    * 3.4  CORRECCIÓN DE VALORES IMPOSIBLES EN HERENCIAS Y RIFAS
    * ------------------------------------------------------------------

		 if (`yr' == 2024) {	
* Se elimina observación que tiene un décimo cuarto de más de 500 millones y 
* un salario de 6324 	
		drop if CEDULA_PK == "C3680396"
		drop if CEDULA_PK == "C1149992"
	 }	 
	
	 if (`yr' == 2016) {
 * Se elimina una observación que tenía un ingreso por salarios de 1.7 mil millones
 * y un aporte al IESS de 415 en F107. De acuerdo con el script de Markus, se trata de 
 * un betunero de cotocollao.
		drop if CEDULA_PK == "C16911030"
		}
		
	if (`yr'==2011) {
	* Ingresos por salarios en F102 de 914.000.000. De acuerdo con el script de
 	* Markus: Guayaquil, Joyeria, suspendido
		drop if CEDULA_PK=="C6219032" 
	}
	
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
    * 3.5  B2R: Renta neta de inmuebles (propietario-ocupante = 0)
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
    local iess_median_107 = r(p50)
    replace aporte_iess_empleado = `iess_median_107' * `liq_foriess' ///
        if `dif_107' <= 0

    * Corrección de aportes imposibles en F102 (IESS > salario declarado)
    gen `iess_porc_102' = ded_syo_trabajo_rde_3250 / ing_syo_trabajo_rde_3240
    gen `dif_102' = ing_syo_trabajo_rde_3240 - ded_syo_trabajo_rde_3250 ///
        if (_merge == 2 | _merge == 3)
    quietly sum `iess_porc_102' ///
        if (_merge == 2 | _merge == 3) & ing_syo_trabajo_rde_3240 != 0
    local iess_median_102 = r(p50) 
    replace ded_syo_trabajo_rde_3250 = `iess_median_102' * ing_syo_trabajo_rde_3240 ///
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
    gen D11R     = liq_107                  if _merge == 1
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
    * 3.8  D4R: INGRESO DE CAPITAL SIN ARRIENDO DE INMUEBLES
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

	if (`yr' >= 2018) capture replace D5P = D5P + D5P_ISD
		
    * ------------------------------------------------------------------
    * 3.12  AGREGADOS DINA
    * ------------------------------------------------------------------

    egen B2B3R = rowtotal(B2R B3R)
    egen D1R   = rowtotal(D11R D121R)
    egen D61P  = rowtotal(D611P D613P)
    egen B5R   = rowtotal(B2B3R D1R D4N)

    * PreTaxHHI: ingreso pre-impuesto (variable de distribución principal)
    egen PreTaxHHI = rowtotal(B2B3R D11R D4R D62R D7R)
 
   * PostTaxHHI: ingreso post-impuesto 
 	gen PostTaxHHI = PreTaxHHI - D5P
 
 * B6R: ingreso post-impuesto y post aporte al IESS
    egen B6R = rowtotal(B5R D62R D7N)	
    replace B6R = B6R - D5P - D61P
	
    * Demostración: B6R = PreTaxHHI - D5P - D61P
		* B6R = B2B3R + D1R + D4N + D62R + D7N - D5P - D61P
		* B6R - PreTaxHHI = D11R + D4R + D7R - D1R - D4N - D7N - D5P - D61P
		* B6R - PreTaxHHI = (D11R - D1R) + (D4R - D4N) + (D7R - D7N) - D5P - D61P
		* D1R = D11R + D12R
		* D12R = 0
		* D4N  = D4R - D4P
		* D4P = 0
		* D7N  = D7R - D7P
		* D7P = 0
		* B6R - PreTaxHHI =  - D5P - D61P
		* B6R = PreTaxHHI - D5P - D61P
	
	* Capital:  INGRESO DE CAPITAL SIN ARRIENDO DE INMUEBLES + ARRIENDO DE INMUEBLES 
	egen capital = rowtotal(D4R B2R)
	gen capital_comparable = capital - ///
	                          rim_predios_agricolas_3164 - ///
							  dividendos_recibidos_3192 
										
	
    * ------------------------------------------------------------------
    * 3.13 COLAPSAR POR CEDULA (declaraciones sustitutivas)
    * ------------------------------------------------------------------
	
	compress
	
    local final_vars PreTaxHHI PostTaxHHI capital capital_comparable B2R B3R B2B3R D1R D4R D4N D62R D7R D7N D5P D61P B5R D11R D121R D41R D42R D4P D611P D613P D7P B6R liq_107 ing_syo_trabajo_rde_3240

    * Variables de bunching: (max) para conservar los missing
    local bunch_vars base102 rimpe rimpe_bruto emp_bruto ///
        n_emp_107 base107_max base107_sum otr_emp_107 ///
        publico_107 tasa_iess_107

    collapse (sum) `final_vars' (max) `bunch_vars', by(CEDULA_PK RUC_PK RUC_PK_empleado RUC_PK_empleador* _merge)

    drop if CEDULA_PK == ""
    gen anio = `yr'

    label var base102        "Bunching: base imponible F102 (3480)"
    label var rimpe          "Bunching: sujeto a RIMPE (desde 2022)"
    label var rimpe_bruto    "Bunching: ingresos brutos gravados RIMPE (5687)"
    label var emp_bruto      "Bunching: ingresos empresariales brutos (1280)"
    label var n_emp_107      "Bunching: número de empleadores distintos (F107)"
    label var base107_max    "Bunching: base imponible F107 más alta entre empleadores"
    label var base107_sum    "Bunching: suma de bases imponibles F107"
    label var otr_emp_107    "Bunching: ingresos gravados con otros empleadores (F107)"
    label var publico_107    "Bunching: servidor público (aporte personal IESS ~11,45% en algún F107)"
    label var tasa_iess_107  "Bunching: tasa de aporte personal IESS del F107 con la base más alta"

    quietly count if PreTaxHHI > 0 & PreTaxHHI != .
    di as text "  N con PreTaxHHI > 0 (nominal): " r(N)
    save "$dir_merged/ingreso_dina_`yr'.dta", replace
    di as text "  Guardado: $dir_merged/ingreso_dina_`yr'.dta"

}

* This should match with the published data:

xtile decil = PreTaxHHI if PreTaxHHI > 0, nq(10)
tabstat PreTaxHHI if PreTaxHHI > 0, by(decil) statistics(n mean min max)




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
set maxvar 10000

* ============================================================================
* 0. RUTAS
* ============================================================================


* Raíz del proyecto SRI
global sri_dir "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Ruthy Intriago"

* Datos administrativos SRI (formularios por año)
global dir_f107    "$sri_dir/03 BDD/F107"
global dir_f102    "$sri_dir/03 BDD/F102"

* Directorio de datos merged (salida de ingreso_neto por año)
global dir_merged  "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/Merged"



* ENEMDU diciembre (para totales de control)
*global dir_enemdu  "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Boletín 1/Procesamiento/Bases/enemdu_diciembres"

* Resultados del análisis de movilidad
global dir_out     "$sri_dir/Resultados/Movilidad"


capture mkdir "$dir_out"
capture mkdir "$dir_out/Graficos"
capture mkdir "$dir_merged"

global ipc_file  "$sri_dir/03 BDD/IPC/ipc_adjusted.xls"


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
* 3. CONSTRUCCIÓN DE INGRESO NETO DESDE F107 + F102 (todos los años)
*    Lógica idéntica a descriptives_ingreso_sri_total.do
*    Los archivos se guardan en valores NOMINALES; la deflación se aplica
*    al construir cada panel de movilidad (sección 6).
* ============================================================================

*foreach yr of global all_yrs {
foreach yr in 2015 {
*forval yr = 2011(1)2024 {

    di as result _n "===== Construyendo ingreso_neto para `yr' ====="

    * ------------------------------------------------------------------
    * 3.1  FORMULARIO 102
    * ------------------------------------------------------------------

    use CEDULA_PK ///
        total_ingresos_1440             ///
        total_costos_gastos_2760        ///
        sub_ing_rgr_tyc_srd_3200        ///
        sub_gto_ded_tyc_srd_3210        ///
        ing_syo_trabajo_rde_3240        ///
        ded_syo_trabajo_rde_3250        ///
        ing_pensiones_jubilares_3450    ///
        ing_div_percibidos_scd_3440     ///
        ren_financieros_exe_3452        ///
        dec_ter_cua_sal_dig_3454        ///
		ing_libre_eje_profesional_2990  /// INGRESOS LIBRE EJERCICIO PROFESIONAL (Casillero 2990)
		ing_ocupacion_liberal_3010      /// INGRESOS OCUPACIÓN LIBERAL (Casillero 3010)
		ingresos_aem_rie_1280           /// INGRESOS ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1280)
		dec_ter_cua_sal_dig_3454        /// Salario de dignidad
		ded_syo_trabajo_rde_3250        /// DEDUCCIONES SALARIOS (Casillero 3250 - usualmente Aportes IESS ahí)
		ded_libre_eje_profesional_3000  /// DEDUCCIONES LIBRE EJERCICIO (Casillero 3000)
		ded_ocupacion_liberal_3020      /// DEDUCCIONES OCUPACIÓN LIBERAL (Casillero 3020)
		deducciones_aem_rie_1290        /// DEDUCCIONES ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1290)
		ing_arriendo_inmuebles_3040     /// ING. ARRIENDO DE INMUEBLES (Casillero 3040)
		ing_arriendo_otros_act_3080     /// ING. ARRIENDO DE OTROS ACTIVOS (3080)
		rim_pgr_ant_anio_2008_3160      /// ING. PREDIOS AGRÍCOLAS AÑOS ANTERIORES (3160)
		ingresos_regalias_3170          /// INGRESOS REGALÍAS (3170)
		rendimientos_financieros_3190   /// RENDIMIENTOS FINANCIEROS (3190)
		dividend_recib_soc_resid_5120   /// DIVIDENDOS SOCIEDADES RESIDENTES (5120)
		div_recib_soc_no_resid_5130     /// DIVIDENDOS SOCIEDADES NO RESIDENTES (5130)
		ingr_enaj_drc_no_iru_5110       /// INGRESOS ENAJENACIÓN DERECHOS REPRESENTATIVOS CAPITAL (5110)
		otr_ing_gravados_exterior_3180  /// OTROS INGRESOS GRAVADOS AL EXTERIOR (3180)
		ingresos_otr_rgr_3193           /// OTROS INGRESOS GRAVADOS (3193)
		ing_div_percibidos_scd_3440     /// Rendimientos financieros exentos
		ren_financieros_exe_3452        /// Rendimientos financieros exentos
		ded_arriendo_inmuebles_3050 	/// DEDUCCIONES ARRIENDO INMUEBLES (3050)
		ded_arriendo_otros_act_3090 	/// DEDUCCIONES ARRIENDO OTROS ACTIVOS (3090)
		ded_predios_agricolas_3162 		/// DEDUCCIONES PREDIOS AGRÍCOLAS (3162)
		deduc_enaj_drc_no_iru_5150 		/// DEDUCCIONES ENAJENACIÓN DRCHOS. CAPITAL (5150)
		deduc_otr_exterior_5140 		/// DEDUCCIONES OTROS INGRESOS DEL EXTERIOR (5140)
		deducciones_otr_rgr_3194 		/// DEDUCCIONES OTRAS RENTAS GRAVADAS (3194)
		*1350 *1360 *1370 *1371 *1373 *1390 ///  INGRESOS ESTADO DE RESULTADOS
		*1410 *1426 *1427 *1411 *1413  /// INGRESOS ESTADO DE RESULTADOS
		*1416 *1380 *1400 *4380 *4385 /// INGRESOS ESTADO DE RESULTADOS
		*1635 *1665 *1685 *1715 *1745 *1915 *1945 *1985 *1983 *1993 *2015 /// COSTOS Y GASTOS
		*2045 *2065 *2135 *2155 *2245 *2265 *2286 *2335 *2355 *2372 *2378 /// COSTOS Y GASTOS
		*2525 *2562 *2578 *2568 *2574 *5000 *1765 *1805 *1825 *1855 *1875 /// COSTOS Y GASTOS
		*1895 *2085 *2105 *2395 *2415 *2425 *2435 *2455 *2485 *2615 *2635 /// COSTOS Y GASTOS
		*2655 *4610 *2584 *5030 *2585 /// COSTOS Y GASTOS
        using "$dir_f102/F102_anonimizada_`yr'.dta" in  1/100000, clear

		
/*
    if _rc {
        use CEDULA_PK ///
            total_ingresos_1440 total_costos_gastos_2760 ///
            sub_ing_rgr_tyc_srd_3200 sub_gto_ded_tyc_srd_3210 ///
            ing_syo_trabajo_rde_3240 ded_syo_trabajo_rde_3250 ///
            ing_pensiones_jubilares_3450 ing_div_percibidos_scd_3440 ///
            ren_financieros_exe_3452 dec_ter_cua_sal_dig_3454 ///
            using "$dir_f102/F102_anonimizada_`yr'.dta", clear
    }
*/
    foreach v of varlist _all {
        if "`v'" != "CEDULA_PK" {
            capture confirm string variable `v'
            if !_rc capture destring `v', replace force
			replace `v' = 0 if `v' == .
  	  }   
    }
	
	
	* Debido a errores en las mallas de validación, no todos los subtotales 
	* son la suma de sus elementos. Para que el ingreso neto cuadre con los 
	* los ingresos de trabajo y capital, se usa la suma de elementos. 

/*	EJEMPLO:
       Ingresos sin contabilidad
	   
	   egen sub_ing_rgr_tyc_srd_3200_2 = rowtotal(*1280 *2990 *3010 *3040 *3080 *3160 *3170 *3190 ///
         	                           	           *5120 *5130 *5110 *3193 *3180) 
	   gen dif_deds = sub_gto_ded_tyc_srd_3210 - sub_gto_ded_tyc_srd_3210_2
       br sub_gto_ded_tyc_srd_3210 sub_gto_ded_tyc_srd_3210_2 *_1290 *3000 *3020 ///
	       *3050 *3090 *3162 *5150 *3194 *5140 ///
	       if abs(dif_deds) > 1 & sub_gto_ded_tyc_srd_3210 != .

       Deducciones sin contabilidad
	   
	   egen sub_gto_ded_tyc_srd_3210_2 = rowtotal(*_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140)
	   gen dif_deds = sub_gto_ded_tyc_srd_3210 - sub_gto_ded_tyc_srd_3210_2
       br sub_gto_ded_tyc_srd_3210 sub_gto_ded_tyc_srd_3210_2 *_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140 if abs(dif_deds) > 1 & sub_gto_ded_tyc_srd_3210 != .		
*/	

		drop sub_ing_rgr_tyc_srd_3200
		egen sub_ing_rgr_tyc_srd_3200_2 = rowtotal(*1280 *2990 *3010 *3040 *3080 *3160 *3170 *3190 ///
        	                           	           *5120 *5130 *5110 *3193 *3180) 
        
		drop sub_gto_ded_tyc_srd_3210
		egen sub_gto_ded_tyc_srd_3210_2 = rowtotal(*_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140)
		

		drop total_ingresos_1440 
		egen total_ingresos_1440_2 = rowtotal( ///
		                                    *1350 *1360 *1370 *1371 *1373 *1390 ///
		                                    *1410 *1426 *1427 *1411 *1413  ///
											*1416 *1380 *1400 *4380 *4385 ///
											)

/*
		*drop total_costos_gastos_2760											
		egen total_costos_gastos_2760_2 = rowtotal( ///
		*1635 *1665 *1685 *1715 *1745 *1915 *1945 *1985 *1983 *1993 *2015 ///
		*2045 *2065 *2135 *2155 *2245 *2265 *2286 *2335 *2355 *2372 *2378 ///
		*2525 *2562 *2578 *2568 *2574 *5000 *1765 *1805 *1825 *1855 *1875 ///
		*1895 *2085 *2105 *2395 *2415 *2425 *2435 *2455 *2485 *2615 *2635 ///
		*2655 *4610 *2584 *5030 *2585 ///
		)		
		
		
		br total_costos_gastos_2760*	*1635 *1665 *1685 *1715 *1745 *1915 *1945 *1985 *1983 *1993 *2015 ///
		*2045 *2065 *2135 *2155 *2245 *2265 *2286 *2335 *2355 *2372 *2378 ///
		*2525 *2562 *2578 *2568 *2574 *5000 *1765 *1805 *1825 *1855 *1875 ///
		*1895 *2085 *2105 *2395 *2415 *2425 *2435 *2455 *2485 *2615 *2635 ///
		*2655 *4610 *2584 *5030 *2585 
*/
    tempfile f102_yr
    save "`f102_yr'", replace

    * ------------------------------------------------------------------
    * 3.2  FORMULARIO 107
    * ------------------------------------------------------------------

    use CEDULA_PK_empleado ///
        ingresos_liq_pagados ///
		sob_suel_com_remu partic_utilidades ///
        decimo_tercero ///
		decimo_cuarto fondo_reserva ///
        ingresos_otros_empleadores ///
		aporte_iess_empleado ///
        aporte_iess_otr_empleador base_imponible ///
		salario_digno /// Salario digno
        using "$dir_f107/F107_anonimizada_`yr'.dta" in  1/100000, clear

/*    if _rc {
        use CEDULA_PK_empleado ///
            ingresos_liq_pagados sob_suel_com_remu partic_utilidades ///
            decimo_tercero decimo_cuarto fondo_reserva ///
            ingresos_otros_empleadores aporte_iess_empleado ///
            aporte_iess_otr_empleador base_imponible ///
            using "$dir_f107/f107_anonimizada_`yr'.dta", clear
    }
*/
    rename CEDULA_PK_empleado CEDULA_PK

    foreach v of varlist _all {
        if "`v'" != "CEDULA_PK" {
            capture confirm string variable `v'
            if !_rc capture destring `v', replace force
        }
    }

    * Tope décimo cuarto y décimo tercero
    local sbu = `sbu_`yr''
    local tope_d14 = (`sbu' / 12) * 9 + `sbu'
	
    gen decimo_cuarto_dep = min(decimo_cuarto, `tope_d14')
    gen decimo_tercero_dep = min(decimo_tercero, ///
        (ingresos_liq_pagados + sob_suel_com_remu) / 12)

    * Corrección fondo de reserva
    gen fondo_reserva_teo = ///
        (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades) * 0.0833
    gen coef_fres   = fondo_reserva / ///
        (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades)
    gen coef_fres_r = round(coef_fres, 0.0001)
    gen freserva_correc = fondo_reserva
    replace freserva_correc = fondo_reserva_teo ///
        if (freserva_correc > 0 & freserva_correc < .) ///
         & (coef_fres_r > 0.0833 & coef_fres_r != .)
		 

    * ------------------------------------------------------------------
    * 3.3  MERGE F107 ← F102
    * ------------------------------------------------------------------

    merge m:m CEDULA_PK using "`f102_yr'"
    erase "`f102_yr'"
	
	
	* ------------------------------------------------------------------------------
	* 3.4. INGRESO NETO LABORAL
	* ------------------------------------------------------------------------------

	* ---------------------------------------------------------
	* A) Ingreso Laboral Dependiente (F107 - Anexo en Relación de Dependencia)
	* ---------------------------------------------------------
	* Ingresos Brutos Dependientes:
	egen labor_gross_F107 = rowtotal( ///
		 ingresos_liq_pagados /// SUELDOS Y SALARIOS (612)
		 sob_suel_com_remu    /// SOBRESUELDOS, COMISIONES, BONOS
		 partic_utilidades    /// PARTICIPACIÓN DE UTILIDADES
		 decimo_tercero_dep   /// DECIMO TERCERO
		 decimo_cuarto_dep    /// DECIMO CUARTO
		 freserva_correc     /// FONDO DE RESERVA
		 ingresos_otros_empleadores /// INGRESOS GENERADOS CON OTROS EMPLEADORES
		 salario_digno       /// Salario digno
         ing_pensiones_jubilares_3450 ///	
)
*	desahucio_otras_remun ///	DESAHUCIO Y OTRAS REMUNERACIONES QUE NO CONSTITUYEN RENTA GRAVADA

	* Gastos Laborales/Aportes Dependientes:
	egen labor_expenses_F107 = rowtotal( ///
		aporte_iess_empleado /// APORTE PERSONAL IESS PAGADO POR EMPLEADO
		aporte_iess_otr_empleador /// APORTE PERSONAL IESS A OTROS EMPLEADORES
	)

	* ---------------------------------------------------------
	* B) Ingreso Laboral F102 (Actividad Autónoma y Relación de Dep.)
	* ---------------------------------------------------------
	* Ingresos Brutos Autónomos/Empresariales + Rel. de Dependencia:
	egen labor_gross_F102 = rowtotal( ///
		 ing_syo_trabajo_rde_3240 /// SALARIOS LÍQUIDOS EN RELACIÓN DE DEPENDENCIA (Casillero 3240)
		 ing_libre_eje_profesional_2990 /// INGRESOS LIBRE EJERCICIO PROFESIONAL (Casillero 2990)
		 ing_ocupacion_liberal_3010 /// INGRESOS OCUPACIÓN LIBERAL (Casillero 3010)
		 ingresos_aem_rie_1280 /// INGRESOS ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1280)
		 dec_ter_cua_sal_dig_3454   /// Salario de dignidad
	)

	* Deducciones de Ingresos Autónomos/Empresariales + Rel de Dep.:
	egen labor_expenses_F102 = rowtotal( ///
		ded_syo_trabajo_rde_3250 /// DEDUCCIONES SALARIOS (Casillero 3250 - usualmente Aportes IESS ahí)
		ded_libre_eje_profesional_3000 /// DEDUCCIONES LIBRE EJERCICIO (Casillero 3000)
		ded_ocupacion_liberal_3020 /// DEDUCCIONES OCUPACIÓN LIBERAL (Casillero 3020)
		deducciones_aem_rie_1290 /// DEDUCCIONES ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1290)
	)

	* ---------------------------------------------------------
	* C) Cálculo de Ingreso Neto Laboral Total
	* ---------------------------------------------------------

    gen ingreso_laboral_bruto = labor_gross_F107 if _merge == 1
    replace ingreso_laboral_bruto = labor_gross_F102 if _merge == 2
	
	replace ingreso_laboral_bruto = labor_gross_F107 ///
	    if _merge == 3 & labor_gross_F107 > labor_gross_F102
		
    replace ingreso_laboral_bruto = labor_gross_F102 ///
	    if _merge == 3 & labor_gross_F107 <= labor_gross_F102 

    gen labor_total_expenses = labor_expenses_F107 if (labor_expenses_F107 > labor_expenses_F107)
    replace labor_total_expenses = labor_expenses_F102 if (labor_expenses_F107 <= labor_expenses_F107)
	
	gen ingreso_laboral_neto = ingreso_laboral_bruto - labor_total_expenses
	* Evitar ingresos negativos en caso de que gastos > ingresos, si aplica a su diseño:
	*replace ingreso_laboral_neto = 0 if ingreso_laboral_neto < 0


	* ------------------------------------------------------------------------------
	* 3.5. INGRESO NETO DE CAPITAL (F102)
	* ------------------------------------------------------------------------------

	* ---------------------------------------------------------
	* A) Ingreso Bruto de Capital (F102):
	* ---------------------------------------------------------
	egen ingreso_capital_bruto = rowtotal( ///
		ing_arriendo_inmuebles_3040 /// ING. ARRIENDO DE INMUEBLES (Casillero 3040)
		ing_arriendo_otros_act_3080 /// ING. ARRIENDO DE OTROS ACTIVOS (3080)
		rim_pgr_ant_anio_2008_3160 /// ING. PREDIOS AGRÍCOLAS AÑOS ANTERIORES (3160)
		ingresos_regalias_3170 /// INGRESOS REGALÍAS (3170)
		rendimientos_financieros_3190 /// RENDIMIENTOS FINANCIEROS (3190)
		dividend_recib_soc_resid_5120 /// DIVIDENDOS SOCIEDADES RESIDENTES (5120)
		div_recib_soc_no_resid_5130 /// DIVIDENDOS SOCIEDADES NO RESIDENTES (5130)
		ingr_enaj_drc_no_iru_5110 /// INGRESOS ENAJENACIÓN DERECHOS REPRESENTATIVOS CAPITAL (5110)
		otr_ing_gravados_exterior_3180 /// OTROS INGRESOS GRAVADOS AL EXTERIOR (3180)
		ingresos_otr_rgr_3193 /// OTROS INGRESOS GRAVADOS (3193)
		ing_div_percibidos_scd_3440 /// Dividendos exentos
		ren_financieros_exe_3452    /// Rendimientos financieros exentos
	)


	
	
	* ---------------------------------------------------------
	* B) Gastos Deducibles de Capital (F102):
	* ---------------------------------------------------------
	egen capital_expenses_F102 = rowtotal( ///
		ded_arriendo_inmuebles_3050 /// DEDUCCIONES ARRIENDO INMUEBLES (3050)
		ded_arriendo_otros_act_3090 /// DEDUCCIONES ARRIENDO OTROS ACTIVOS (3090)
		ded_predios_agricolas_3162 /// DEDUCCIONES PREDIOS AGRÍCOLAS (3162)
		deduc_enaj_drc_no_iru_5150 /// DEDUCCIONES ENAJENACIÓN DRCHOS. CAPITAL (5150)
		deduc_otr_exterior_5140 /// DEDUCCIONES OTROS INGRESOS DEL EXTERIOR (5140)
		deducciones_otr_rgr_3194 /// DEDUCCIONES OTRAS RENTAS GRAVADAS (3194)
	)

	* ---------------------------------------------------------
	* C) Cálculo de Ingreso Neto de Capital
	* ---------------------------------------------------------
	gen ingreso_capital_neto = ingreso_capital_bruto - capital_expenses_F102
	*replace ingreso_capital_neto = 0 if ingreso_capital_neto < 0


	/*
	
    gen a = ingreso_capital_neto + ingreso_laboral_neto
    gen equal = a == ingreso_neto
    sum a ingreso_neto
	
		br CEDULA _merge /// 
		ingreso*neto  ///
        ing_pensiones_jubilares_3450  ing_div_percibidos_scd_3440  ///
        ren_financieros_exe_3452  dec_ter_cua_sal_dig_3454  ///
        ing_syo_trabajo_rde_3240  ded_syo_trabajo_rde_3250  ///
        total_ingresos_1440  total_costos_gastos_2760  ///
        sub_ing_rgr_tyc_srd_3200  sub_gto_ded_tyc_srd_3210 ///
		sub_ing_rgr_tyc_srd_3200 /// 
		sub_gto_ded_tyc_srd_3210 ///
		ing_arriendo_inmuebles_3040 /// ING. ARRIENDO DE INMUEBLES (Casillero 3040)
		ing_arriendo_otros_act_3080 /// ING. ARRIENDO DE OTROS ACTIVOS (3080)
		rim_pgr_ant_anio_2008_3160 /// ING. PREDIOS AGRÍCOLAS AÑOS ANTERIORES (3160)
		ingresos_regalias_3170 /// INGRESOS REGALÍAS (3170)
		rendimientos_financieros_3190 /// RENDIMIENTOS FINANCIEROS (3190)
		dividend_recib_soc_resid_5120 /// DIVIDENDOS SOCIEDADES RESIDENTES (5120)
		div_recib_soc_no_resid_5130 /// DIVIDENDOS SOCIEDADES NO RESIDENTES (5130)
		ingr_enaj_drc_no_iru_5110 /// INGRESOS ENAJENACIÓN DERECHOS REPRESENTATIVOS CAPITAL (5110)
		otr_ing_gravados_exterior_3180 /// OTROS INGRESOS GRAVADOS AL EXTERIOR (3180)
		ingresos_otr_rgr_3193 /// OTROS INGRESOS GRAVADOS (3193)
		ing_div_percibidos_scd_3440 /// Dividendos exentos
		ren_financieros_exe_3452    /// Rendimientos financieros exentos
		ded_arriendo_inmuebles_3050 /// DEDUCCIONES ARRIENDO INMUEBLES (3050)
		ded_arriendo_otros_act_3090 /// DEDUCCIONES ARRIENDO OTROS ACTIVOS (3090)
		ded_predios_agricolas_3162 /// DEDUCCIONES PREDIOS AGRÍCOLAS (3162)
		deduc_enaj_drc_no_iru_5150 /// DEDUCCIONES ENAJENACIÓN DRCHOS. CAPITAL (5150)
		deduc_otr_exterior_5140 /// DEDUCCIONES OTROS INGRESOS DEL EXTERIOR (5140)
		deducciones_otr_rgr_3194 /// DEDUCCIONES OTRAS RENTAS GRAVADAS (3194)
		*1280 *_1290 *3010 *3020  ///
        if equal == 0 & ingreso_neto == 0 & ingreso_capital_neto != 0
	*/
	
	/*
	br  *1280 ///
	    *2990 ///
        *3010 ///
	    *3040 ///
		*3080 ///
		*3160 ///
		*3170 ///
		*3190 ///
		*5120 ///
		*5130 ///
		*5110 ///
		*3193 ///
		*3180 ///
		*3200 if CEDULA == "C121326"
*/

	

	/*
	
    gen a = ingreso_capital_neto + ingreso_laboral_neto
    gen equal = a == ingreso_neto
    sum a ingreso_neto
	
		br CEDULA _merge /// 
		ingreso*neto *3200 *3210 ///
		 ingresos_liq_pagados /// SUELDOS Y SALARIOS (612)
		 sob_suel_com_remu    /// SOBRESUELDOS, COMISIONES, BONOS
		 partic_utilidades    /// PARTICIPACIÓN DE UTILIDADES
		 decimo_tercero_dep   /// DECIMO TERCERO
		 decimo_cuarto_dep    /// DECIMO CUARTO
		 freserva_correc     /// FONDO DE RESERVA
		 ingresos_otros_empleadores /// INGRESOS GENERADOS CON OTROS EMPLEADORES
		 salario_digno       /// Salario digno
         ing_pensiones_jubilares_3450 ///	
		 ing_syo_trabajo_rde_3240 /// SALARIOS LÍQUIDOS EN RELACIÓN DE DEPENDENCIA (Casillero 3240)
		 ing_libre_eje_profesional_2990 /// INGRESOS LIBRE EJERCICIO PROFESIONAL (Casillero 2990)
		 ing_ocupacion_liberal_3010 /// INGRESOS OCUPACIÓN LIBERAL (Casillero 3010)
		 ingresos_aem_rie_1280 /// INGRESOS ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1280)
		*_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140  ///
        if equal == 0 & ingreso_neto == 0 & ingreso_laboral_neto != 0
		
		egen sub_gto_ded_tyc_srd_3210_2 = rowtotal(*_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140)
		gen dif_deds = sub_gto_ded_tyc_srd_3210 - sub_gto_ded_tyc_srd_3210_2
        br sub_gto_ded_tyc_srd_3210 sub_gto_ded_tyc_srd_3210_2 *_1290 *3000 *3020 *3050 *3090 *3162 *5150 *3194 *5140 if abs(dif_deds) > 1 & sub_gto_ded_tyc_srd_3210 != .
		
		
		egen sub_ing_rgr_tyc_srd_3200_2 = rowtotal(*1280 *2990 *3010 *3040 *3080 *3160 *3170 *3190 ///
        	                           	           *5120 *5130 *5110 *3193 *3180) 
		gen dif_ings = sub_ing_rgr_tyc_srd_3200 - sub_ing_rgr_tyc_srd_3200_2
        br sub_ing_rgr_tyc_srd_3200 sub_ing_rgr_tyc_srd_3200_2 *1280 *2990 *3010 /// 
		   *3040 *3080 *3160 *3170 *3190 *5120 *5130 *5110 *3193 *3180 ///
		   if abs(dif_ings) > 1 & sub_ing_rgr_tyc_srd_3200 != .
		
		
		
	*/
	
/*

      br ing_libre_eje_profesional_2990 /// INGRESOS LIBRE EJERCICIO PROFESIONAL (Casillero 2990)
		 ing_ocupacion_liberal_3010 /// INGRESOS OCUPACIÓN LIBERAL (Casillero 3010)
		 ingresos_aem_rie_1280 /// INGRESOS ACTIVIDAD EMPRESARIAL / RIMPE (Casillero 1280)
		 *3200 ///
         if inlist(CEDULA, "C1674954", "C192406", "C1974812", "C1992396", ///
		                   "C2005739", "C250854", "C254101", "C292376")

		 CEDULA_PK "C1674954" "C192406" C1974812 C1992396 C2005739 C250854 C254101 C292376

		 

*/	
	
	

	*drop sub_ing_rgr_tyc_srd_3200
	*egen sub_ing_rgr_tyc_srd_3200 = rowtotal(*1280 *2990 *3010 *3040 *3080 *3160 *3170 *3190 ///
	                           	             *5120 *5130 *5110 *3193 *3180) 
	
	
    * ------------------------------------------------------------------
    * 3.6  INGRESO NETO (cuatro casos de merge)
    * ------------------------------------------------------------------

    egen ing_107 = rowtotal( ///
        ingresos_liq_pagados sob_suel_com_remu partic_utilidades ///
        freserva_correc decimo_cuarto_dep decimo_tercero_dep ///
        ingresos_otros_empleadores)

    gen ingreso_neto = .

    * Caso 1: solo F107
    replace ingreso_neto = ing_107 - aporte_iess_empleado - aporte_iess_otr_empleador ///
        if _merge == 1

		/*
	br ingresos_liq_pagados sob_suel_com_remu partic_utilidades freserva_correc decimo_cuarto decimo_tercero ingresos_otros_empleadores ingreso_neto ing_107 aporte_iess_empleado  if ingreso_neto < 0	
		*/
		
    * Caso 2: solo F102
    replace ingreso_neto = ///
	    (ing_ocupacion_liberal_3010 - ded_ocupacion_liberal_3020) + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_syo_trabajo_rde_3240 - ded_syo_trabajo_rde_3250) + ///
        (total_ingresos_1440 - total_costos_gastos_2760) + ///
        (sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210) ///
        if _merge == 2
			
    * Caso 3a: ambos — F107 domina
    replace ingreso_neto = ///
	    (ing_ocupacion_liberal_3010 - ded_ocupacion_liberal_3020) + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_107 - aporte_iess_empleado) + ///
        (total_ingresos_1440 - total_costos_gastos_2760) + ///
        (sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210) ///
        if _merge == 3 & (ing_107 > ing_syo_trabajo_rde_3240)

    * Caso 3b: ambos — F102 rel.dep. domina
    replace ingreso_neto = ///
	    (ing_ocupacion_liberal_3010 - ded_ocupacion_liberal_3020) + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_syo_trabajo_rde_3240 - ded_syo_trabajo_rde_3250) + ///
        (total_ingresos_1440 - total_costos_gastos_2760) + ///
        (sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210) ///
        if _merge == 3 & (ing_107 <= ing_syo_trabajo_rde_3240)

	* ------------------------------------------------------------------
    * 3.7  INGRESO BRUTO (cuatro casos de merge)
    * ------------------------------------------------------------------

    gen ingreso_bruto = .

    * Caso 1: solo F107
    replace ingreso_bruto = ing_107 ///
        if _merge == 1

    * Caso 2: solo F102
    replace ingreso_bruto = ///
	    ing_ocupacion_liberal_3010  + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_syo_trabajo_rde_3240) + ///
        (total_ingresos_1440 ) + ///
        (sub_ing_rgr_tyc_srd_3200 ) ///
        if _merge == 2

    * Caso 3a: ambos — F107 domina
    replace ingreso_bruto = ///
	    ing_ocupacion_liberal_3010  + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_107 - aporte_iess_empleado) + ///
        (total_ingresos_1440 ) + ///
        (sub_ing_rgr_tyc_srd_3200 ) ///
        if _merge == 3 & (ing_107 > ing_syo_trabajo_rde_3240)

    * Caso 3b: ambos — F102 rel.dep. domina
    replace ingreso_bruto = ///
	    ing_ocupacion_liberal_3010 + ///
        ing_pensiones_jubilares_3450 + ing_div_percibidos_scd_3440 + ///
        ren_financieros_exe_3452 + dec_ter_cua_sal_dig_3454 + ///
        (ing_syo_trabajo_rde_3240 ) + ///
        (total_ingresos_1440) + ///
        (sub_ing_rgr_tyc_srd_3200) ///
        if _merge == 3 & (ing_107 <= ing_syo_trabajo_rde_3240)	
		
	
    * ------------------------------------------------------------------
    * 3.8  COLAPSAR POR CEDULA (declaraciones sustitutivas)
    * ------------------------------------------------------------------
s
	local final_vars ingreso_neto ingreso_bruto ///
	                 ingreso_capital_neto ingreso_capital_bruto ///
	                 ingreso_laboral_neto  ingreso_laboral_bruto
	
    collapse (sum) `final_vars', by(CEDULA_PK _merge)
	
	drop if CEDULA_PK == ""
    gen anio = `yr'
	
    quietly count if ingreso_neto > 0 & ingreso_neto != .
    quietly count if ingreso_bruto > 0 & ingreso_bruto != .
    di as text "  N con ingreso_neto > 0 (nominal): " r(N)

    save "$dir_merged/ingreso_neto_`yr'.dta", replace
    di as text "  Guardado: $dir_merged/ingreso_neto_`yr'.dta"
s	
}




* ============================================================================
* 4. PREPARAR POSTFILE PARA RESULTADOS
* ============================================================================
/*
keep CEDULA_PK ///
     ingreso_trabajo /// 
     ingresos_trabajo_obligados  ///
	 ingresos_trabajo_no_obligados ///
     ingresos_capital ///
	 ingresos_trabajo_total ///
	 ingresos_capital_total ///
	 ingresos_total ///
	 ingreso_neto
*/

tempname results
tempfile results_file

postfile `results'                            ///
	int(anio)                                 ///
	str30(concepto)                           ///
	str10(percentil)                          ///
	double(suma media mediana sd vmin vmax pct_total) ///
	long(N)                                   ///
	using "`results_file'", replace



foreach yr of global all_yrs {
*forval yr = 2010(1)2024 {
*foreach yr in 2024 {

di "`yr'"

     use "$dir_merged/ingreso_neto_`yr'.dta", clear

	 drop if ingreso_neto <= 0 | ingreso_neto == .
	 
    * ------------------------------------------------------------------
    * 5.4  CEROS → MISSING  (sólo para estadísticas descriptivas)
    * ------------------------------------------------------------------

    foreach var in ingreso_neto ingreso_bruto ingreso_capital_neto ingreso_capital_bruto  {
        gen `var'_s = `var' / 12
        replace `var'_s = . if `var'_s == 0
    }

    * ------------------------------------------------------------------
    * 5.5  ESTADÍSTICAS POR GRUPO DE PERCENTIL
    * ------------------------------------------------------------------

    local concepts      ingreso_neto       ingreso_bruto  
    local concepts_lbl `""Ingreso Neto"    "Ingreso Bruto"' 

    local c 1
    foreach concept of local concepts {
	   di "`c'"

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
        quietly _pctile `svar', percentiles(50 90 95 99)
        local p50 = r(r1)
        local p90 = r(r2)
        local p95 = r(r3)
        local p99 = r(r4)
		
		di " `p50'  / `p90'  /  `p95'  / `p99' "

        quietly summarize `svar'
        local total_sum = r(sum)
        if `total_sum' == 0 local total_sum 1

        * --- Definir grupos ---
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
			* di "`results'  /  `yr'  /   `lbl'  / `gname`g'' " 
                post `results' (`yr') ("`lbl'") ("`gname`g''")    ///
                    (r(sum)) (r(mean)) (r(p50)) (r(sd)) (r(min)) (r(max)) ///
                    ((r(sum) / `total_sum') * 100) (r(N))
            }
            else {
                post `results' (`yr') ("`lbl'") ("`gname`g''") ///
                    (0) (.) (.) (.) (.) (0) (0)
            }
        }

        *drop _g1-_g5
        local ++c
    }


	
}


postclose `results'


/*
ingresos_trabajo_total ingresos_capital_total ingresos_total ///
*/
/*
local f107_vars ingresos_liq_pagados sob_suel_com_remu partic_utilidades ///
				freserva_teorico decimo_cuarto decimo_tercero 
			   
local f102_vars total_ingresos_1440 sub_ing_rgr_tyc_srd_3200 ///
                ing_syo_trabajo_rde_3240 ingresos_otros_empleadores  ///
				aporte_iess_empleado aporte_iess_otr_empleador ///
				base_imponible decimo_tercero_1 ded_syo_trabajo_rde_3250 ///
				total_costos_gastos_2760 sub_gto_ded_tyc_srd_3210 
*/				
/*				///
				ingreso_trabajo ingresos_trabajo_obligados ///
				ingresos_trabajo_no_obligados
*/


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
label var sd        "Desv. Est."
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
local pnames `""P99-P100" "P95-P100" "P90-P100" "P1-P50" "Total""'
local npctiles 5

* Conceptos y nombres de hoja (el nombre de hoja replica el formato del Excel original)
local sheet_concepts `""Ingreso Neto" "Ingreso Bruto""'
local sheet_names    `""Ingreso Neto" "Ingreso Bruto""'

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
    reshape wide suma media sd N mediana vmin vmax pct_total, ///
        i(anio) j(pctil_order)

    * Ordenar columnas: Año | (Suma Media N Mediana % Min Max) × cada grupo
    local ordered "anio"
    forvalues p = 1/`npctiles' {
        local ordered "`ordered' suma`p' media`p' sd`p' N`p' mediana`p' pct_total`p' vmin`p' vmax`p'"
    }
    order `ordered'

    * Etiquetar variables
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

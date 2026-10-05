/*******************************************************************************
* limpiar_F102.do
*
* Crea las bases F102 limpias que usa construccion_ingreso_DINA.do:
*   entrada: $dir_f102/F102_anonimizada_YYYY.dta   (original, pesado)
*   salida : $dir_clean/F102_clean_YYYY_2.dta
*
* 1. Conserva solo las variables del F102 que aparecen en
*    construccion_ingreso_DINA.do (se usen o no para las variables DINA).
* 2. Convierte a número las variables continuas (en el original vienen como
*    texto) con destring, force. No se tocan los identificadores ni las
*    variables de texto ($f102_texto).
* 3. Asigna 0 a los valores ausentes de las variables numéricas, como hacía la
*    versión anterior del código DINA al cargar el F102.
* 4. Elimina las filas sin CEDULA_PK. En el F102 anonimizado cada CEDULA_PK
*    aparece una sola vez (los únicos repetidos son los vacíos), y el código
*    DINA hace merge 1:1: si algún año trae CEDULA_PK repetidos, isid detiene
*    el do file en vez de elegir una declaración sin avisar.
*
* Sección 1: crea las bases limpias completas (todas las variables de
*            $f102_vars).
* Sección 2: agrega variables nuevas ($f102_nuevas) a bases limpias que ya
*            existen, sin rehacer la sección 1. Correr solo las secciones 0 y 2.
*            Después, sumar esas variables a $f102_vars para que la próxima
*            corrida completa también las incluya.
*******************************************************************************/

clear all
set more off

* ============================================================================
* 0. RUTAS Y VARIABLES (las mismas rutas que construccion_ingreso_DINA.do)
* ============================================================================

* Si dir_sri ya está definido (p. ej. datos falsos, Papers/Bunching/
* construir_ingreso_dina_falso.do), se respeta; si no, se usa el servidor.
if "$dir_sri" == "" global dir_sri "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"
global dir_f102  "$dir_sri/03 BDD/SRI/IR/F102"
global dir_clean "$dir_sri/03 BDD/SRI/IR/F102/Clean"
capture mkdir "$dir_clean"

global f102_years "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

* Variables del F102 mencionadas en construccion_ingreso_DINA.do. Incluyen
* las del análisis de bunching (Papers/Bunching/bunching_renta.do):
*   base_imponible_3480, suj_reg_rimpe_4896, bas_imp_grav_reg_rimpe_5687,
*   ingresos_aem_rie_1280
global f102_vars                                                        ///
    CEDULA_PK RUC_PK                                                    ///
    ing_syo_trabajo_rde_3240 ded_syo_trabajo_rde_3250                   ///
    utilidad_neta_ejercicio_2800 perdida_ejercicio_2810                 ///
    ingresos_aem_rie_1280 deducciones_aem_rie_1290 ingresos_sir_2988    ///
    ing_libre_eje_profesional_2990 ded_libre_eje_profesional_3000       ///
    ing_ocupacion_liberal_3010 ded_ocupacion_liberal_3020               ///
    otr_ing_gravados_exterior_3180 otr_ingresos_exentos_3460            ///
    ing_arriendo_inmuebles_3040 ded_arriendo_inmuebles_3050             ///
    rim_arriendo_otros_act_3100 rim_predios_agricolas_3164              ///
    ingresos_regalias_3170 rendimientos_financieros_3190                ///
    dividendos_recibidos_3192 ingresos_otr_rgr_3193 deducciones_otr_rgr_3194 ///
    img_herencias_leg_don_3420 ipa_herencias_leg_don_3410               ///
    ing_lot_rifas_apuestas_3400 ipa_lot_rifas_apuestas_3390             ///
    ing_pensiones_jubilares_3450 imp_renta_causado_3490                 ///
    base_imponible_3480 suj_reg_rimpe_4896 bas_imp_grav_reg_rimpe_5687  //  bunching (+ 1280 arriba)

* Variables de texto que no se convierten a número
global f102_texto "CEDULA_PK RUC_PK suj_reg_rimpe_4896"

* Sección 2: variables nuevas para agregar a las bases limpias existentes
* (si ya están en la base limpia, se reemplazan)
global f102_nuevas ""
global f102_nuevas_years "$f102_years"

* ============================================================================
* 1. LOOP POR AÑO
* ============================================================================

foreach yr of global f102_years {

    di as result _n "===== F102 limpio `yr' ====="

    * --- 1.1 Leer solo las variables necesarias ---
    quietly describe using "$dir_f102/F102_anonimizada_`yr'.dta", varlist
    local disp `r(varlist)'
    local vars $f102_vars
    local leer    : list vars & disp
    local faltan  : list vars - disp
    global f102_leer    "`leer'"
    global f102_faltan  "`faltan'"
    if "$f102_faltan" != "" di as error "  No están en el F102 `yr': $f102_faltan"

    use $f102_leer using "$dir_f102/F102_anonimizada_`yr'.dta", clear
    di as text "  Registros originales: " _N

    * --- 1.2 Variables continuas: texto -> número; ausentes -> 0 ---
    foreach v of varlist _all {
        if !strpos(" $f102_texto ", " `v' ") {
            capture confirm string variable `v'
            if !_rc destring `v', replace force
            replace `v' = 0 if missing(`v')
        }
    }

    * --- 1.3 Una fila por CEDULA_PK ---
    drop if missing(CEDULA_PK) | CEDULA_PK == ""
    isid CEDULA_PK
    di as text "  Personas: " _N

    compress
    save "$dir_clean/F102_clean_`yr'_2.dta", replace
    di as text "  Guardado: $dir_clean/F102_clean_`yr'_2.dta"
}

* ============================================================================
* 2. AGREGAR VARIABLES NUEVAS A LAS BASES LIMPIAS EXISTENTES
*    Requiere: sección 0 y las bases $dir_clean/F102_clean_YYYY_2.dta.
*    Lee del original solo CEDULA_PK y $f102_nuevas, aplica los mismos pasos
*    de la sección 1 (texto -> número, ausentes -> 0, sin CEDULA_PK vacíos) y
*    las une 1:1 a la base limpia.
* ============================================================================

if "$f102_nuevas" != "" {
foreach yr of global f102_nuevas_years {

    di as result _n "===== Agregar variables al F102 limpio `yr' ====="

    * --- 2.1 Leer las variables nuevas del original ---
    quietly describe using "$dir_f102/F102_anonimizada_`yr'.dta", varlist
    local disp `r(varlist)'
    local nuevas $f102_nuevas
    local leer    : list nuevas & disp
    local faltan  : list nuevas - disp
    if "`faltan'" != "" di as error "  No están en el F102 `yr': `faltan'"
    if "`leer'" == "" continue

    use CEDULA_PK `leer' using "$dir_f102/F102_anonimizada_`yr'.dta", clear

    * --- 2.2 Texto -> número y ausentes -> 0 (salvo variables de texto) ---
    foreach v of local leer {
        if !strpos(" $f102_texto ", " `v' ") {
            capture confirm string variable `v'
            if !_rc destring `v', replace force
            replace `v' = 0 if missing(`v')
        }
    }

    * --- 2.3 Una fila por CEDULA_PK (como en la sección 1) ---
    drop if missing(CEDULA_PK) | CEDULA_PK == ""
    isid CEDULA_PK
    keep CEDULA_PK `leer'
    tempfile nuevas_yr
    save `nuevas_yr'

    * --- 2.4 Unir a la base limpia (reemplaza versiones anteriores) ---
    use "$dir_clean/F102_clean_`yr'_2.dta", clear
    foreach v of local leer {
        capture drop `v'
    }
    merge 1:1 CEDULA_PK using `nuevas_yr', keep(1 3) nogen
    isid CEDULA_PK
    compress
    save "$dir_clean/F102_clean_`yr'_2.dta", replace
    di as text "  Agregadas: `leer'"
}
}

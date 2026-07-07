/*******************************************************************************
* REGRESIÓN: EFECTO DE LA PANDEMIA (2020) SOBRE LA MOVILIDAD ECONÓMICA
*
* Variable dependiente:
*   - moved_up:   P(percentil_{t+1} > percentil_t)
*   - moved_down: P(percentil_{t+1} < percentil_t)
*
* Variable independiente principal:
*   - pandemic: dummy = 1 para la transición 2019→2020
*
* Datos: forms_merged_YYYY.dta (Merged folder)
* Metodología: consistente con movilidad_economica.do (deciles/percentiles
*              intra-año, panel pareado por CEDULA_PK)
*
* Especificaciones:
*   (1) LPM:   moved_up/down = α + β·pandemic + ε
*   (2) LPM:   moved_up/down = α + β·pandemic + γ·percentil_t0 + ε
*   (3) LPM con FE de transición (pandemic identificado vs. todos los demás)
*   (4) Logit: moved_up/down = Λ(α + β·pandemic + γ·percentil_t0)
*******************************************************************************/

clear all
set more off
set maxvar 10000

* ============================================================================
* 0. RUTAS
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"
global dir_merged "$basedir/Bases/Fake/03_BDD/Merged"
global dir_out    "$basedir/Resultados/Movilidad_Regresion"

capture mkdir "$dir_out"

* ============================================================================
* 1. GENERAR DATOS FAKE PARA 2021, 2022, 2023
*    Basados en la estructura de 2020, con variación aleatoria razonable
* ============================================================================

di as result _n "===== Generando datos fake para 2021–2023 ====="

use "$dir_merged/forms_merged_2020.dta", clear

local N_2020 = _N
di as text "  Observaciones en 2020 (plantilla): `N_2020'"

local income_vars "ingresos_trabajo_total ingresos_capital_total ingresos_total"
local income_vars "`income_vars' ingresos_liq_pagados sob_suel_com_remu"
local income_vars "`income_vars' partic_utilidades freserva_correc"
local income_vars "`income_vars' decimo_cuarto decimo_tercero"
local income_vars "`income_vars' total_ingresos_1440 sub_ing_rgr_tyc_srd_3200"
local income_vars "`income_vars' ing_syo_trabajo_rde_3240 ingresos_otros_empleadores"
local income_vars "`income_vars' aporte_iess_empleado aporte_iess_otr_empleador"
local income_vars "`income_vars' base_imponible ded_syo_trabajo_rde_3250"
local income_vars "`income_vars' total_costos_gastos_2760 sub_gto_ded_tyc_srd_3210"
local income_vars "`income_vars' ingreso_trabajo ingresos_trabajo_obligados"
local income_vars "`income_vars' ingresos_trabajo_no_obligados"
local income_vars "`income_vars' ing_pensiones_jubilares_3450 ing_div_percibidos_scd_3440"
local income_vars "`income_vars' ren_financieros_exe_3452 dec_ter_cua_sal_dig_3454"
local income_vars "`income_vars' ing_107 ingreso_bruto ingreso_neto"

set seed 20250508

foreach yr in 2021 2022 2023 {

    use "$dir_merged/forms_merged_2020.dta", clear

    local growth_mean = (`yr' - 2020) * 0.03
    local growth_sd   = 0.15

    foreach v of local income_vars {
        capture confirm variable `v'
        if !_rc {
            capture confirm numeric variable `v'
            if !_rc {
                gen _shock = rnormal(`growth_mean', `growth_sd')
                replace `v' = `v' * (1 + _shock) if `v' > 0 & `v' != .
                replace `v' = `v' * (1 - abs(_shock) * 0.5) if `v' < 0 & `v' != .
                drop _shock
            }
        }
    }

    gen _drop = runiform() < 0.03
    drop if _drop
    drop _drop

    save "$dir_merged/forms_merged_`yr'.dta", replace
    di as text "  Guardado forms_merged_`yr'.dta (N=" _N ")"
}

* ============================================================================
* 2. CONSTRUIR PANEL LONGITUDINAL
*    Apilar todos los años, conservar CEDULA_PK + ingreso_neto + año
* ============================================================================

di as result _n "===== Construyendo panel longitudinal ====="

local years "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

local first 1
foreach yr of local years {
    capture confirm file "$dir_merged/forms_merged_`yr'.dta"
    if _rc {
        di as error "  Archivo no encontrado: forms_merged_`yr'.dta — se omite."
        continue
    }
    use CEDULA_PK ingreso_neto using "$dir_merged/forms_merged_`yr'.dta", clear
    gen int anio = `yr'
    if `first' {
        tempfile panel
        save "`panel'", replace
        local first 0
    }
    else {
        append using "`panel'"
        save "`panel'", replace
    }
}

save "$dir_merged/dina_appended.dta", replace
use "$dir_merged/dina_appended.dta", clear

drop if ingreso_neto <= 0 | ingreso_neto == .

di as text _n "  Observaciones en el panel (ingreso_neto > 0):"
tab anio

* ============================================================================
* 3. CONSTRUCCIÓN DE PERCENTILES INTRA-AÑO
* ============================================================================

di as result _n "===== Asignando percentiles intra-año ====="

gen percentil = .
gen decil     = .

levelsof anio, local(all_years)
foreach yr of local all_years {
    quietly count if anio == `yr'
    local N_yr = r(N)

    if `N_yr' >= 100 {
        xtile _tp = ingreso_neto if anio == `yr', nq(100)
        replace percentil = _tp if anio == `yr'
        drop _tp
    }
    else if `N_yr' >= 2 {
        local nq = min(100, `N_yr' - 1)
        xtile _tp = ingreso_neto if anio == `yr', nq(`nq')
        replace percentil = _tp if anio == `yr'
        drop _tp
        di as text "  NOTA: `yr' tiene `N_yr' obs → se usaron `nq' grupos"
    }

    if `N_yr' >= 10 {
        xtile _td = ingreso_neto if anio == `yr', nq(10)
        replace decil = _td if anio == `yr'
        drop _td
    }
}

label var percentil "Percentil de ingreso neto (intra-año)"
label var decil     "Decil de ingreso neto (intra-año)"

save "$dir_merged/all_years.dta", replace
use "$dir_merged/all_years.dta", clear



* ============================================================================
* 4. CREAR TRANSICIONES CONSECUTIVAS Y APILARLAS
*    Excluir 2020→2024 porque cubre 4 años (no es comparable)
*    Solo usar transiciones anuales: t → t+1
* ============================================================================

di as result _n "===== Construyendo transiciones año a año ====="

local trans_t0 "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022"
local trans_t1 "2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023"

local npairs : word count `trans_t0'

local first_pair 1
forvalues p = 1/`npairs' {

    local y0 : word `p' of `trans_t0'
    local y1 : word `p' of `trans_t1'

    * Año t0
    use "$dir_merged/all_years.dta", clear
    quietly count if anio == `y0'
    if r(N) == 0 {
        di as error "  Año `y0' no encontrado. Se omite transición."
        continue
    }
    keep if anio == `y0'
    rename (percentil decil ingreso_neto) (percentil_t0 decil_t0 ingreso_t0)
    drop anio
    tempfile t0_data
    save "`t0_data'", replace

    * Año t1
    use "$dir_merged/all_years.dta", clear
    quietly count if anio == `y1'
    if r(N) == 0 {
        di as error "  Año `y1' no encontrado. Se omite transición."
        continue
    }
    keep if anio == `y1'
    rename (percentil decil ingreso_neto) (percentil_t1 decil_t1 ingreso_t1)
    drop anio
    tempfile t1_data
    save "`t1_data'", replace

    * Merge: solo individuos presentes en ambos años
    use "`t0_data'", clear
    merge 1:1 CEDULA_PK using "`t1_data'", keep(3) nogen

    gen int anio_t0 = `y0'
    gen int anio_t1 = `y1'

    local N_match = _N
    di as text "  Transición `y0'→`y1': N = `N_match'"

    if `N_match' < 5 {
        di as error "  Insuficientes observaciones. Se omite."
        continue
    }

    if `first_pair' {
        tempfile transitions
        save "`transitions'", replace
        local first_pair 0
    }
    else {
        append using "`transitions'"
        save "`transitions'", replace
    }
}

use "`transitions'", clear

* ============================================================================
* 5. CONSTRUIR VARIABLES DE MOVILIDAD Y TRATAMIENTO
* ============================================================================

di as result _n "===== Construyendo variables de movilidad ====="

* --- Variables dependientes ---
gen byte moved_up   = (percentil_t1 > percentil_t0) if !missing(percentil_t0, percentil_t1)
gen byte moved_down = (percentil_t1 < percentil_t0) if !missing(percentil_t0, percentil_t1)
gen byte stayed     = (percentil_t1 == percentil_t0) if !missing(percentil_t0, percentil_t1)
gen delta_pctl      = percentil_t1 - percentil_t0
gen abs_delta_pctl  = abs(delta_pctl)
gen delta_decile      = decil_t1 - decil_t0

* --- Variables usando deciles ---
gen byte moved_up_d   = (decil_t1 > decil_t0) if !missing(decil_t0, decil_t1)
gen byte moved_down_d = (decil_t1 < decil_t0) if !missing(decil_t0, decil_t1)

* --- Variable independiente principal: pandemia ---
gen byte pandemic = (anio_t1 == 2020)
label var pandemic "Dummy pandemia (transición 2019→2020)"

* --- Etiquetas ---
label var moved_up      "=1 si sube de percentil"
label var moved_down    "=1 si baja de percentil"
label var stayed        "=1 si permanece en mismo percentil"
label var delta_pctl    "Cambio en percentil (t1 − t0)"
label var abs_delta_pctl "Cambio absoluto en percentil"
label var moved_up_d    "=1 si sube de decil"
label var moved_down_d  "=1 si baja de decil"
label var anio_t0       "Año de origen"
label var anio_t1       "Año de destino"
label var percentil_t0  "Percentil en t0"
label var percentil_t1  "Percentil en t1"
label var decil_t0      "Decil en t0"
label var decil_t1      "Decil en t1"

* --- Generar un ID de transición para FE ---
gen str9 trans_id = string(anio_t0) + "_" + string(anio_t1)
encode trans_id, gen(trans_fe)
label var trans_fe "Efecto fijo de transición"

* --- ID numérico de individuo para clustering ---
encode CEDULA_PK, gen(id_individuo)

* --- Descriptivas rápidas ---
di as result _n "===== Estadísticas descriptivas ====="

di as text _n "  Distribución de transiciones:"
tab trans_id

di as text _n "  Tasas promedio de movilidad por transición:"
tabstat moved_up moved_down stayed, by(trans_id) stat(mean n) format(%8.4f)

di as text _n "  Comparación pandemia vs. no pandemia:"
tabstat moved_up moved_down delta_pctl abs_delta_pctl, by(pandemic) stat(mean sd n) format(%8.4f)

save "$dir_out/panel_transiciones_movilidad.dta", replace
di as text _n "  Guardado: panel_transiciones_movilidad.dta (N=" _N ")"

* ============================================================================
* 6. REGRESIONES
* ============================================================================

di as result _n "============================================================="
di as result    "  REGRESIONES: EFECTO DE LA PANDEMIA SOBRE MOVILIDAD"
di as result    "============================================================="

* ------------------------------------------------------------------
* 6.1  MOVILIDAD ASCENDENTE (moved_up)
* ------------------------------------------------------------------

di as result _n "---------- VARIABLE DEPENDIENTE: MOVILIDAD ASCENDENTE ----------"

* Spec 1: LPM simple
di as result _n "  [1] LPM: moved_up = α + β·pandemic"
regress moved_up pandemic, vce(cluster id_individuo)
estimates store up_lpm1

* Spec 2: LPM con control de posición inicial
di as result _n "  [2] LPM: moved_up = α + β·pandemic + γ·percentil_t0"
regress moved_up pandemic percentil_t0, vce(cluster id_individuo)
estimates store up_lpm2

* Spec 3: LPM con FE de transición (pandemic = 0 por colinealidad, 
*         usar comparación directa)
di as result _n "  [3] LPM: moved_up = α + β·pandemic + γ·percentil_t0 + δ_t"
regress moved_up pandemic percentil_t0 i.trans_fe, vce(cluster id_individuo)
estimates store up_lpm3

* Spec 4: Logit
di as result _n "  [4] Logit: moved_up = Λ(α + β·pandemic + γ·percentil_t0)"
logit moved_up pandemic percentil_t0, vce(cluster id_individuo) or
estimates store up_logit

* Efectos marginales del logit
margins, dydx(pandemic) post
estimates store up_logit_me

* ------------------------------------------------------------------
* 6.2  MOVILIDAD DESCENDENTE (moved_down)
* ------------------------------------------------------------------

di as result _n "---------- VARIABLE DEPENDIENTE: MOVILIDAD DESCENDENTE ----------"

* Spec 1
di as result _n "  [1] LPM: moved_down = α + β·pandemic"
regress moved_down pandemic, vce(cluster id_individuo)
estimates store dn_lpm1

* Spec 2
di as result _n "  [2] LPM: moved_down = α + β·pandemic + γ·percentil_t0"
regress moved_down pandemic percentil_t0, vce(cluster id_individuo)
estimates store dn_lpm2

* Spec 3
di as result _n "  [3] LPM: moved_down = α + β·pandemic + γ·percentil_t0 + δ_t"
regress moved_down pandemic percentil_t0 i.trans_fe, vce(cluster id_individuo)
estimates store dn_lpm3

* Spec 4
di as result _n "  [4] Logit: moved_down = Λ(α + β·pandemic + γ·percentil_t0)"
logit moved_down pandemic percentil_t0, vce(cluster id_individuo) or
estimates store dn_logit

margins, dydx(pandemic) post
estimates store dn_logit_me

* ------------------------------------------------------------------
* 6.3  CAMBIO EN PERCENTIL (intensidad de movilidad)
* ------------------------------------------------------------------

di as result _n "---------- VARIABLE DEPENDIENTE: CAMBIO EN PERCENTIL ----------"

di as result _n "  [1] OLS: delta_pctl = α + β·pandemic"
regress delta_pctl pandemic, vce(cluster id_individuo)
estimates store dp_ols1

di as result _n "  [2] OLS: delta_pctl = α + β·pandemic + γ·percentil_t0"
regress delta_pctl pandemic percentil_t0, vce(cluster id_individuo)
estimates store dp_ols2

di as result _n "  [3] OLS: abs_delta_pctl = α + β·pandemic + γ·percentil_t0"
regress abs_delta_pctl pandemic percentil_t0, vce(cluster id_individuo)
estimates store adp_ols


reghdfe delta_pctl pandemic percentil_t0, absorb(id_individuo) vce(cluster id_individuo)


* ============================================================================
* 6.6  PERSISTENCIA DE LA PANDEMIA
*      Las cuatro especificaciones rastrean si el choque de 2020 fue
*      transitorio o persistió en los años siguientes.
*
*      NOTA IMPORTANTE DE IDENTIFICACIÓN:
*      La pandemia es un choque COMÚN (mismo año calendario para todos).
*      Sin grupo de control, los coeficientes post-evento equivalen a los
*      cambios medios por año calendario, netos del FE individual. La lectura
*      causal descansa en el supuesto de que la dinámica pre-pandemia
*      aproxima el contrafactual (verificable con las pre-tendencias).
* ============================================================================

di as result _n "============================================================="
di as result    "  PERSISTENCIA DE LA PANDEMIA"
di as result    "============================================================="


* ------------------------------------------------------------------
* OPCIÓN 1: Dummies por año post-pandemia
*   Base = transición 2018→2019 (anio_t1 == 2019), justo antes del choque.
*   La secuencia de coeficientes traza el perfil temporal del efecto.
* ------------------------------------------------------------------

di as result _n "  [1] Dummies por año post-pandemia (base = 2019)"
reghdfe delta_pctl ib2019.anio_t1 percentil_t0, ///
    absorb(id_individuo) vce(cluster id_individuo)
estimates store pers_year

* ------------------------------------------------------------------
* OPCIÓN 2: Rezagos distribuidos del evento pandémico
*   lag0 = el propio choque (anio_t1==2020), lag1=2021, ... 
*   Categoría omitida = todas las demás transiciones agrupadas.
*   (Con un único evento común, estos rezagos coinciden mecánicamente
*    con los efectos de año calendario; se incluyen por interpretabilidad.)
* ------------------------------------------------------------------

di as result _n "  [2] Rezagos distribuidos del choque pandémico"
forvalues k = 0/3 {
    gen byte pand_lag`k' = (anio_t1 == 2020 + `k')
    label var pand_lag`k' "Pandemia: `k' años después"
}
reghdfe delta_pctl pand_lag0 pand_lag1 pand_lag2 pand_lag3 percentil_t0, ///
    absorb(id_individuo) vce(cluster id_individuo)
estimates store pers_lags

* prueba conjunta: ¿efecto acumulado distinto de cero?
test pand_lag0 pand_lag1 pand_lag2 pand_lag3

* ------------------------------------------------------------------
* OPCIÓN 3: Event study (tiempo relativo al evento)
*   evt = anio_t1 - 2020. Base = evt == -1 (transición 2018→2019).
*   Permite: (a) test de pre-tendencias (evt<0 ≈ 0 valida el diseño),
*            (b) impacto (evt=0), (c) persistencia (evt>0).
* ------------------------------------------------------------------

di as result _n "  [3] Event study sobre delta_pctl"
cap gen int evt = anio_t1 - 2020
summarize evt
cap gen int evt_f = evt - r(min)              // desplaza a enteros ≥ 0 para i.
local base = -1 - r(min)                  // posición de evt == -1
di "`base'"
reghdfe delta_pctl ib`base'.evt_f percentil_t0, ///
    absorb(id_individuo) vce(cluster id_individuo)
estimates store pers_event

* Gráfico opcional (requiere coefplot: ssc install coefplot)
capture which coefplot
if !_rc {
    coefplot pers_event, keep(*.evt_f) vertical yline(0) ///
        xline(`=`base'+0.5') ///
        title("Event study: cambio en percentil") ///
        ytitle("Efecto vs. evt = -1") xtitle("Años desde la pandemia")
    graph export "$dir_out/eventstudy_delta_pctl.png", replace width(1400)
}

* ------------------------------------------------------------------
* OPCIÓN 4: Cicatriz (scarring) sobre el NIVEL del percentil
*   Se vuelve al panel persona-año (all_years.dta), no a las transiciones,
*   porque aquí interesa el nivel y su persistencia, no el cambio.
* ------------------------------------------------------------------

di as result _n "  [4] Cicatriz sobre el nivel del percentil"
use "$dir_merged/all_years.dta", clear
keep CEDULA_PK anio percentil decil ingreso_neto
drop if missing(percentil)
encode CEDULA_PK, gen(id_ind)
xtset id_ind anio

gen int evt = anio - 2020
quietly summarize evt
gen int evt_f = evt - r(min)
local base = -1 - r(min)
reghdfe percentil ib`base'.evt_f, ///
    absorb(id_ind) vce(cluster id_ind)
estimates store scar_level

* (4b) Persistencia dinámica con rezago de la dependiente (AR(1))
*      lambda = L.percentil mide la persistencia intrínseca de la posición;
*      d2020..d2023 capturan el desvío inducido por la pandemia.
*      CAVEAT: con FE + dependiente rezagada hay sesgo de Nickell (modesto
*      con T moderado). Para T corto, considerar xtabond / Arellano-Bond.
gen byte d2020 = (anio == 2020)
gen byte d2021 = (anio == 2021)
gen byte d2022 = (anio == 2022)
gen byte d2023 = (anio == 2023)
reghdfe percentil L.percentil d2020 d2021 d2022 d2023, ///
    absorb(id_ind) vce(cluster id_ind)
estimates store scar_ar1


* Arellano-Bond
xtabond2 percentil L.percentil ib2010.anio, ///
    gmm(L.percentil, lag(2 4))              ///
    iv(ib2010.anio)                         ///
    twostep robust                          ///
    small nocons
estimates store ab_full

* ------------------------------------------------------------------
* 6.4  TABLA RESUMEN
* ------------------------------------------------------------------

di as result _n "============================================================="
di as result    "  TABLA RESUMEN DE RESULTADOS"
di as result    "============================================================="

di as result _n "  --- Panel A: Movilidad ascendente (moved_up) ---"
estimates table up_lpm1 up_lpm2 up_lpm3 up_logit, ///
    keep(pandemic percentil_t0) b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- Panel B: Movilidad descendente (moved_down) ---"
estimates table dn_lpm1 dn_lpm2 dn_lpm3 dn_logit, ///
    keep(pandemic percentil_t0) b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- Panel C: Intensidad de movilidad ---"
estimates table dp_ols1 dp_ols2 adp_ols, ///
    keep(pandemic percentil_t0) b(%9.4f) se(%9.4f) stats(N r2)

* ------------------------------------------------------------------
* 6.5  HETEROGENEIDAD POR POSICIÓN INICIAL
* ------------------------------------------------------------------

di as result _n "============================================================="
di as result    "  HETEROGENEIDAD: EFECTO POR QUINTIL DE ORIGEN"
di as result    "============================================================="

gen int quintil_t0 = ceil(percentil_t0 / 20)
replace quintil_t0 = 5 if quintil_t0 > 5 & quintil_t0 != .
label var quintil_t0 "Quintil de origen"

gen pandemic_q1 = pandemic * (quintil_t0 == 1)
gen pandemic_q2 = pandemic * (quintil_t0 == 2)
gen pandemic_q3 = pandemic * (quintil_t0 == 3)
gen pandemic_q4 = pandemic * (quintil_t0 == 4)
gen pandemic_q5 = pandemic * (quintil_t0 == 5)

di as result _n "  Efecto de pandemia por quintil — Movilidad ascendente:"
regress moved_up pandemic_q1 pandemic_q2 pandemic_q3 pandemic_q4 pandemic_q5 ///
    i.quintil_t0, vce(cluster id_individuo)

di as result _n "  Efecto de pandemia por quintil — Movilidad descendente:"
regress moved_down pandemic_q1 pandemic_q2 pandemic_q3 pandemic_q4 pandemic_q5 ///
    i.quintil_t0, vce(cluster id_individuo)

* ============================================================================
* 7. EXPORTAR RESULTADOS A EXCEL
* ============================================================================

di as result _n "===== Exportando resultados ====="

* --- Resumen por transición ---
use "$dir_out/panel_transiciones_movilidad.dta", clear

collapse (mean) moved_up moved_down stayed delta_pctl abs_delta_pctl ///
    moved_up_d moved_down_d ///
    (count) N=moved_up, by(anio_t0 anio_t1 pandemic)

label var moved_up      "P(sube percentil)"
label var moved_down    "P(baja percentil)"
label var stayed        "P(permanece)"
label var delta_pctl    "Media cambio percentil"
label var abs_delta_pctl "Media |cambio percentil|"
label var moved_up_d    "P(sube decil)"
label var moved_down_d  "P(baja decil)"
label var N             "N observaciones"
label var pandemic      "Transición pandemia"

format moved_up moved_down stayed delta_pctl abs_delta_pctl ///
    moved_up_d moved_down_d %8.4f
format N %8.0fc

local outfile "$dir_out/Regresion_Pandemia_Movilidad.xlsx"

export excel using "`outfile'", ///
    sheet("Movilidad por transicion") firstrow(varlabel) replace

di as text "  Exportado: `outfile'"

* ============================================================================
* 8. FIN
* ============================================================================

di as result _n "============================================================="
di as result    "  ANÁLISIS COMPLETADO"
di as result    "============================================================="
di as text ""
di as text "Archivos generados:"
di as text "  $dir_merged/forms_merged_2021.dta  (fake)"
di as text "  $dir_merged/forms_merged_2022.dta  (fake)"
di as text "  $dir_merged/forms_merged_2023.dta  (fake)"
di as text "  $dir_out/panel_transiciones_movilidad.dta"
di as text "  $dir_out/Regresion_Pandemia_Movilidad.xlsx"
di as text ""
di as text "Especificaciones estimadas:"
di as text "  [1] LPM simple"
di as text "  [2] LPM + control percentil de origen"
di as text "  [3] LPM + control percentil + FE de transición"
di as text "  [4] Logit + control percentil (odds ratios + efecto marginal)"
di as text "  [5] OLS sobre cambio en percentil"
di as text "  [6] Heterogeneidad por quintil de origen"
di as text ""
di as text "Nota: la transición 2020→2024 se excluye por cubrir 4 años."
di as text "      Errores estándar clustered a nivel de individuo."

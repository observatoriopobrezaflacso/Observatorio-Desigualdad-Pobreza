/*******************************************************************************
* analysis_3.do  —  extension de analysis_2.do con correcciones de attrition
*
* Igual que analysis_2.do (bloques BALANCED / UNBALANCED / FILLIN con las
* imputaciones g = 0 y g = -1) MAS metodos adicionales para tratar la
* attrition no aleatoria (negativamente correlacionada con el ingreso):
*
*   [S0] Referencia: solo stayers, sin imputacion
*   [S1] Imputacion g = 0    (attriters sin crecimiento)      — de analysis_2
*   [S2] Imputacion g = -1   (attriters caen a ingreso 0)     — de analysis_2
*   [M2] Cotas de Lee (2009): trimming de stayers para igualar la tasa de
*        retencion entre anios dentro de cada decil
*   [M3] IPW: reponderacion de stayers por la inversa de la probabilidad
*        (logit) de permanecer en el panel
*   [M4] Heckman dos etapas (exclusion: 'enforcement' provincial, afecta
*        declarar pero no el ingreso)
*   [M5] Hot-deck: a cada attriter se le imputa el g de un donante aleatorio
*        (stayer) de su misma celda anio x decil
*   [M6] Imputacion multiple (mi impute pmm + mi estimate, reglas de Rubin)
*   [M7] Reingreso al panel: para attriters que reaparecen, crecimiento
*        anualizado hasta el retorno; variantes 0 / -1 para no-retornantes
*   [M9] Sensibilidad: g(attriter) = g medio de stayers de su celda - delta,
*        con delta en una grilla 0 .. 1
*
* Para CADA especificacion se corre la regresion pedida:
*       reg <g imputado> ib2020.anio##ib2.decil_t0_`j' , vce(cluster id_bal)
* con j = 1 (t0 = anio previo) y j = 2 (t0 = promedio 3 anios previos).
*
* COVARIABLES ADICIONALES requeridas en working_data_unbalanced (no estaban
* en analysis_2): anio_nac genero industria provincia enforcement.
* En los datos reales del SRI hay que construirlas con las variables
* administrativas equivalentes; 'enforcement' debe ser un factor que afecte
* la probabilidad de declarar pero no el crecimiento del ingreso
* (p.ej. variacion regional de control/fiscalizacion del SRI).
*
* PRUEBA CON DATOS FALSOS:
*   global fake_root "<carpeta>"
*   do fake_data_analysis_3.do     // genera defl.dta y working_data_*.dta
*   do analysis_3.do               // usa $fake_root en vez de las rutas D:/
*******************************************************************************/

clear all
set more off
set seed 20260723

* ============================================================================
* RUTAS
* ============================================================================

global user_root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

global ipc		  "$user_root/03 BDD/IPC"
global dina       "$user_root/03 BDD/IR/Merged/ingreso_dina"
global data_out   "$user_root/Proyectos/Impacto shocks/data"
global results    "$user_root/Proyectos/Impacto shocks/resultados"
global senescyt   "$user_root/03 BDD/SENESCYT"

* --- Para pruebas con datos FALSOS: definir $fake_root antes de ejecutar ---
if "$fake_root" != "" {
    global ipc      "$fake_root"
    global data_out "$fake_root"
    global results  "$fake_root/resultados"
}
capture mkdir "$results"


* ============================================================================
* BALANCED
* ============================================================================


use ingreso_* anio id_bal nyears all_preyears decil_* universidad using "$data_out/working_data_balanced.dta", clear


merge m:1 anio using "$ipc/defl", nogen keep(1 3)   // * FIX: keep(1 3) — defl puede traer anios fuera del panel
drop if anio == 2017

xtset id_bal anio


gen ipc_t0 = L.ipc
gen ipc_l2 = L2.ipc
gen ipc_l3 = L3.ipc
egen ipc_t0_2 = rowmean(ipc_t0 ipc_l2 ipc_l3)
rename ipc ipc_t1

gen real_t0_1 = ingreso_t0_1 / (ipc_t0/100)
gen real_t0_2 = ingreso_t0_2 / (ipc_t0_2/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real_1 = ingreso_t1/ingreso_t0_1 - 1
gen g_real_2 = ingreso_t1/ingreso_t0_2 - 1


preserve

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10

*	keep if anio == 2019
	keep g_real_* ingreso_t0* anio decil_t0* ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1 g_real_2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10)

	forval j = 1/2 {

			gen product = g_real_`j' * n

			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1

			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1

			gen g`j' = sumproduct/sumweigth
			drop product sumproduct sumweigth
	}

	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & ///
			!inlist(., g1, g2) & ///
			!inlist(., decil_t0_1, decil_t0_2)

	sort anio decil_t0_1
	export excel using "$results/g_by_decil_balanced.xlsx", firstrow(var) replace

	list

restore



* ============================================================================
* UNBALANCED
* ============================================================================

* * FIX: se agregan a la lista las covariables que usan los metodos M3-M6:
*        anio_nac genero industria provincia enforcement
use ingreso_* anio id_bal nyears all_preyears decil_* universidad ///
    anio_nac genero industria provincia enforcement ///
    using "$data_out/working_data_unbalanced.dta", clear


merge m:1 anio using "$ipc/defl", nogen keep(1 3)   // * FIX: keep(1 3)
drop if anio == 2017

xtset id_bal anio


gen ipc_t0 = L.ipc
gen ipc_l2 = L2.ipc
gen ipc_l3 = L3.ipc
egen ipc_t0_2 = rowmean(ipc_t0 ipc_l2 ipc_l3)
rename ipc ipc_t1

gen real_t0_1 = ingreso_t0_1 / (ipc_t0/100)
gen real_t0_2 = ingreso_t0_2 / (ipc_t0_2/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real_1 = ingreso_t1/ingreso_t0_1 - 1
gen g_real_2 = ingreso_t1/ingreso_t0_2 - 1


preserve

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10

*	keep if anio == 2019
	keep g_real_* ingreso_t0* anio decil_t0* ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1 g_real_2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10)

	forval j = 1/2 {

			gen product = g_real_`j' * n

			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1

			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1

			gen g`j' = sumproduct/sumweigth
			drop product sumproduct sumweigth
	}

	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & ///
			!inlist(., g1, g2) & ///
			!inlist(., decil_t0_1, decil_t0_2)

	sort anio decil_t0_1
	export excel using "$results/g_by_decil_unbalanced.xlsx", firstrow(var) replace

	list

restore

* ============================================================================
* FILLIN (IMPUTATIONS TO ATTRITERS)
* ============================================================================


fillin id_bal anio
save "$data_out/fillin_data_unbalanced.dta", replace

drop decil_*

* Identify the attriters

xtset id_bal anio
gen present = _fillin == 0
gen attrition = present == 0 if L.present == 1

* Rellenar covariables fijas del individuo en las filas creadas por fillin
* (necesarias para M3-M6 en las filas de los attriters)
foreach v of varlist universidad genero industria provincia enforcement anio_nac {
    bysort id_bal: egen double _f = max(`v')
    replace `v' = _f if missing(`v')
    drop _f
}
gen edad  = anio - anio_nac
gen edad2 = edad^2

* Impute growth = 0 and = -1 for the attriters

gen g_real_1_imp1 = g_real_1 if attrition == 0
replace g_real_1_imp1 = 0 if attrition == 1

gen g_real_2_imp1 = g_real_2 if attrition == 0
replace g_real_2_imp1 = 0 if attrition == 1

gen g_real_1_imp2 = g_real_1 if attrition == 0
replace g_real_1_imp2 = -1 if attrition == 1

gen g_real_2_imp2 = g_real_2 if attrition == 0
replace g_real_2_imp2 = -1 if attrition == 1

* Regenerate deciles in t0 with the attriters

sort id_bal anio           // * FIX: los bysort de arriba desordenan; L. requiere orden panel

replace ingreso_t0_1 = L.ingreso_t1 if attrition == 1
replace ingreso_l1   = L.ingreso_t1 if attrition == 1
xtile decil_t0_1 = ingreso_t0_1, nq(10)

replace ingreso_l2 = L.ingreso_l1 if attrition == 1   // * FIX: era ingreso_l1 (misma fila, siempre missing)
replace ingreso_l3 = L.ingreso_l2 if attrition == 1   // * FIX: era ingreso_l2

egen a = rowmean(ingreso_t0_1 ingreso_l2 ingreso_l3) if attrition == 1
replace ingreso_t0_2 = a if attrition == 1
drop a

xtile decil_t0_2 = ingreso_t0_2, nq(10)

* * FIX: en analysis_2 estas tablas iban despues de 'drop decil_*' (error);
*        aqui van despues de regenerar los deciles.
* * FIX: tab..., sum() means en vez de table..., stat() para que corra tanto
*        en Stata 16 como en 17+
tab decil_t0_1 anio, sum(attrition) means
tab decil_t0_2 anio, sum(attrition) means

* Log del ingreso t0 (para los modelos de seleccion M3, M4, M6)
gen ln_t0_1 = ln(max(ingreso_t0_1, 1))
gen ln_t0_2 = ln(max(ingreso_t0_2, 1))


preserve

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10

	*	keep if anio == 2019
	keep g_real_1_imp1 g_real_1_imp2 g_real_2_imp1 g_real_2_imp2 ///
		 ingreso_t0_1 ingreso_t0_2 anio decil_t0_1 decil_t0_2 ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1_imp1 g_real_1_imp2 g_real_2_imp1 g_real_2_imp2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10)

	forval j = 1/2 {
		forval i = 1/2 {

			gen product = g_real_`j'_imp`i' * n

			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1

			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1

			gen g`j'_`i' = sumproduct/sumweigth
			drop product sumproduct sumweigth

		}
	}

	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & !inlist(., g1_1, g1_2, g2_1, g2_2)

	sort anio decil_t0_1
	export excel using "$results/g_imputations_by_decil.xlsx", firstrow(var) replace

	list

restore


* ============================================================================
* ============================================================================
*   METODOS DE CORRECCION DE ATTRITION  +  REGRESIONES POR ESPECIFICACION
*
*   En todos los casos la regresion pedida es:
*       reg <g> ib2020.anio##ib2.decil_t0_`j' , vce(cluster id_bal)
*   (base: anio 2020 y decil 2). j = 1 usa decil_t0_1; j = 2 usa decil_t0_2.
*
*   Nota: attrition solo esta definida desde el segundo anio del panel
*   (se necesita observar t-1), por lo que las especificaciones con
*   imputacion cubren 2019+ mientras que [S0] tambien incluye 2018.
* ============================================================================
* ============================================================================

capture log close
log using "$results/attrition_methods", replace text


* ============================================================================
* [S0] REFERENCIA: SOLO STAYERS (sin imputacion)
* ============================================================================
di as result _n "===== [S0] Solo stayers ====="
forval j = 1/2 {
    reg g_real_`j' ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
    estimates store s0_`j'
}

* ============================================================================
* [S1]-[S2] IMPUTACIONES g = 0  Y  g = -1  (cotas "manuales" de analysis_2)
* ============================================================================
di as result _n "===== [S1] g(attriter) = 0   /  [S2] g(attriter) = -1 ====="
forval j = 1/2 {
    forval i = 1/2 {
        reg g_real_`j'_imp`i' ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
        estimates store imp`i'_`j'
    }
}

* ============================================================================
* [M2] COTAS DE LEE (2009) — TRIMMING
* ============================================================================
* La seleccion (permanecer en el panel) difiere entre anios. Dentro de cada
* decil t0 se iguala la tasa de retencion de todos los anios a la MINIMA del
* decil, recortando el excedente de stayers:
*   - lee_lo: se recorta la parte ALTA de g  -> cota inferior del g medio
*   - lee_hi: se recorta la parte BAJA de g  -> cota superior del g medio
* Las dos regresiones dan el rango [lo, hi] del efecto por anio x decil.

di as result _n "===== [M2] Cotas de Lee (trimming por celda anio x decil) ====="
forval j = 1/2 {


local j = 1
    * tasa de retencion por celda (anio x decil), solo filas en riesgo
    bysort decil_t0_`j' anio: egen double _ret_cell = mean(1 - attrition) if attrition != .
    bysort decil_t0_`j': egen double _ret_min = min(_ret_cell)
    gen double _trim = (_ret_cell - _ret_min) / _ret_cell

    * posicion de g dentro de la celda (solo stayers con g observado)
    gen byte _st = attrition == 0 & g_real_`j' != .
    bysort decil_t0_`j' anio _st (g_real_`j'): gen long _rk = _n if _st
    bysort decil_t0_`j' anio _st: gen long _N_st = _N if _st
    gen double _p = _rk / _N_st

    gen byte lee_lo_`j' = _st & (_p <= 1 - _trim)   // recorta arriba
    gen byte lee_hi_`j' = _st & (_p > _trim)        // recorta abajo

    di as result _n "  -- [M2] j = `j' : cota INFERIOR --"
    reg g_real_`j' ib2020.anio##ib2.decil_t0_`j' if lee_lo_`j', vce(cluster id_bal)
    estimates store m2lo_`j'

    di as result _n "  -- [M2] j = `j' : cota SUPERIOR --"
    reg g_real_`j' ib2020.anio##ib2.decil_t0_`j' if lee_hi_`j', vce(cluster id_bal)
    estimates store m2hi_`j'

    drop _ret_cell _ret_min _trim _st _rk _N_st _p
}

* ============================================================================
* [M3] INVERSE PROBABILITY WEIGHTING
* ============================================================================
* Logit de permanecer en el panel sobre observables pre-periodo; los stayers
* se reponderan por 1/p(permanecer). Corrige seleccion en observables.

di as result _n "===== [M3] IPW ====="
forval j = 1/2 {

    logit present ln_t0_`j' i.decil_t0_`j' i.anio c.edad c.edad2 ///
        i.genero i.universidad i.industria if attrition != ., vce(cluster id_bal)

    predict double _ph if e(sample), pr
    gen double ipw_`j' = 1/_ph if attrition == 0

    * winsorizar pesos extremos (p99)
    quietly summarize ipw_`j', detail
    replace ipw_`j' = r(p99) if ipw_`j' > r(p99) & ipw_`j' != .

    reg g_real_`j' ib2020.anio##ib2.decil_t0_`j' [pw = ipw_`j'], vce(cluster id_bal)
    estimates store m3_`j'

    drop _ph
}

* ============================================================================
* [M4] HECKMAN DOS ETAPAS
* ============================================================================
* Exclusion restriction: 'enforcement' (exigencia provincial de declarar)
* entra en la ecuacion de seleccion pero no en la de crecimiento.
* Stayers con g no observado (t0 faltante) se tratan como no-seleccionados.

di as result _n "===== [M4] Heckman dos etapas ====="
forval j = 1/2 {

    gen byte _sel = attrition == 0 & g_real_`j' != .

    heckman g_real_`j' ib2020.anio##ib2.decil_t0_`j' c.edad c.edad2 ///
            i.genero i.universidad if attrition != ., ///
        select(_sel = ln_t0_`j' ib2.decil_t0_`j' ib2020.anio c.edad c.edad2 ///
               i.genero i.universidad c.enforcement) twostep
    estimates store m4_`j'

    drop _sel
}

* ============================================================================
* [M5] HOT-DECK / DONANTES ALEATORIOS
* ============================================================================
* A cada attriter se le imputa el g observado de un stayer (donante) escogido
* al azar (con reemplazo) dentro de su celda anio x decil t0.

di as result _n "===== [M5] Hot-deck por celda anio x decil ====="
forval j = 1/2 {

    tempfile donors dcount

    preserve
        keep if attrition == 0 & g_real_`j' != . & decil_t0_`j' != .
        keep anio decil_t0_`j' g_real_`j'
        rename g_real_`j' g_donor
        gen double _u = runiform()
        sort anio decil_t0_`j' _u
        by anio decil_t0_`j': gen long _didx = _n
        by anio decil_t0_`j': gen long _dN = _N
        drop _u
        save `donors'
        by anio decil_t0_`j': keep if _n == 1
        keep anio decil_t0_`j' _dN
        save `dcount'
    restore

    merge m:1 anio decil_t0_`j' using `dcount', keep(1 3) nogen
    gen long _didx = ceil(runiform()*_dN) if attrition == 1
    merge m:1 anio decil_t0_`j' _didx using `donors', keep(1 3) nogen keepusing(g_donor)

    gen g_real_`j'_hd = g_real_`j' if attrition == 0
    replace g_real_`j'_hd = g_donor if attrition == 1

    reg g_real_`j'_hd ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
    estimates store m5_`j'

    drop _didx _dN g_donor
}

* ============================================================================
* [M6] IMPUTACION MULTIPLE (mi impute pmm)
* ============================================================================
* Predictive mean matching sobre observables; 5 imputaciones combinadas con
* las reglas de Rubin (errores estandar reflejan la incertidumbre imputada).

di as result _n "===== [M6] Imputacion multiple (pmm) ====="
forval j = 1/2 {

    preserve
        keep if attrition != . & decil_t0_`j' != . & ln_t0_`j' != .
        keep id_bal anio g_real_`j' decil_t0_`j' ln_t0_`j' edad genero ///
             universidad industria attrition

        mi set wide
        mi register imputed g_real_`j'
        mi impute pmm g_real_`j' ln_t0_`j' i.anio i.decil_t0_`j' c.edad ///
            i.genero i.universidad i.industria, add(5) knn(5) rseed(20260723)

        mi estimate, post: reg g_real_`j' ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
        estimates store m6_`j'
    restore
}

* ============================================================================
* [M7] REINGRESO AL PANEL
* ============================================================================
* Para attriters que reaparecen en <= 3 anios se calcula el crecimiento
* ANUALIZADO entre t0 y el anio de retorno. Para los que nunca vuelven se
* usan las dos variantes extremas (0 y -1), que ahora solo aplican al
* subconjunto verdaderamente no observado.

di as result _n "===== [M7] Reingreso al panel ====="

sort id_bal anio
xtset id_bal anio

gen double _ing_fut = .
gen double _gap = .
forval k = 1/3 {
    replace _gap     = `k' + 1          if attrition == 1 & _ing_fut == . & F`k'.present == 1
    replace _ing_fut = F`k'.ingreso_t1  if attrition == 1 & _ing_fut == . & F`k'.present == 1
}

gen byte _recovered = _ing_fut != . if attrition == 1
di as result _n "  Proporcion de attriters que reingresan (<=3 anios), por anio:"
tabstat _recovered, by(anio) stat(mean n) format(%9.4f)

forval j = 1/2 {

    gen double g_reent_`j' = (_ing_fut/ingreso_t0_`j')^(1/_gap) - 1 ///
        if attrition == 1 & _ing_fut != . & ingreso_t0_`j' > 0 & ingreso_t0_`j' != .

    * variante A: no-retornantes con g = 0 ; variante B: g = -1
    gen g_real_`j'_re0 = g_real_`j' if attrition == 0
    replace g_real_`j'_re0 = g_reent_`j' if attrition == 1 & g_reent_`j' != .
    gen g_real_`j'_rem1 = g_real_`j'_re0
    replace g_real_`j'_re0  = 0  if attrition == 1 & g_reent_`j' == .
    replace g_real_`j'_rem1 = -1 if attrition == 1 & g_reent_`j' == .

    di as result _n "  -- [M7] j = `j' : no-retornantes g = 0 --"
    reg g_real_`j'_re0 ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
    estimates store m7a_`j'

    di as result _n "  -- [M7] j = `j' : no-retornantes g = -1 --"
    reg g_real_`j'_rem1 ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
    estimates store m7b_`j'
}

* ============================================================================
* [M9] ANALISIS DE SENSIBILIDAD SOBRE LA FUERZA DE LA SELECCION
* ============================================================================
* g(attriter) = g medio de los stayers de su celda (anio x decil) - delta.
* delta = 0  -> attriters como stayers comparables (MAR dentro de celda);
* delta -> 1 -> se acerca al peor caso (g = -1). Se guardan los coeficientes
* clave de la regresion para cada delta.

di as result _n "===== [M9] Sensibilidad en delta ====="
forval j = 1/2 {

    bysort anio decil_t0_`j': egen double _gstay = mean(cond(attrition == 0, g_real_`j', .))

    tempname S
    postfile `S' double(delta b_2019 se_2019 b_2021 se_2021 b_2022 se_2022 ///
        b_2019_x_d10 se_2019_x_d10) using "$results/sensibilidad_delta_`j'", replace

    foreach d of numlist 0 0.05 0.1 0.2 0.3 0.5 0.75 1 {
        gen double g_sens = g_real_`j' if attrition == 0
        replace g_sens = _gstay - `d' if attrition == 1
        quietly reg g_sens ib2020.anio##ib2.decil_t0_`j', vce(cluster id_bal)
        post `S' (`d') (_b[2019.anio]) (_se[2019.anio]) ///
            (_b[2021.anio]) (_se[2021.anio]) (_b[2022.anio]) (_se[2022.anio]) ///
            (_b[2019.anio#10.decil_t0_`j']) (_se[2019.anio#10.decil_t0_`j'])
        drop g_sens
    }
    postclose `S'

    preserve
        use "$results/sensibilidad_delta_`j'", clear
        export excel using "$results/sensibilidad_delta_`j'.xlsx", firstrow(var) replace
        di as result _n "  -- [M9] j = `j' : coeficientes (base anio 2020, decil 2) por delta --"
        list, noobs
    restore

    drop _gstay
}

* ============================================================================
* EXPORT: g MEDIO POR ANIO x DECIL SEGUN METODO
* ============================================================================
forval j = 1/2 {
    preserve
        keep if attrition != . & decil_t0_`j' != .
        collapse (mean) g_obs  = g_real_`j' ///
                        g_imp0  = g_real_`j'_imp1 ///
                        g_impm1 = g_real_`j'_imp2 ///
                        g_hd    = g_real_`j'_hd ///
                        g_re0   = g_real_`j'_re0 ///
                        g_rem1  = g_real_`j'_rem1 ///
                 (count) n = g_real_`j'_imp1, by(anio decil_t0_`j')
        export excel using "$results/g_by_decil_metodos_`j'.xlsx", firstrow(var) replace
    restore

    * version IPW (promedio ponderado de stayers)
    preserve
        keep if attrition == 0 & decil_t0_`j' != . & ipw_`j' != .
        collapse (mean) g_ipw = g_real_`j' (count) n = g_real_`j' ///
            [pw = ipw_`j'], by(anio decil_t0_`j')
        export excel using "$results/g_by_decil_ipw_`j'.xlsx", firstrow(var) replace
    restore
}

* ============================================================================
* RESUMEN: COEFICIENTES DE ANIO (base 2020) ENTRE METODOS
* ============================================================================
* Los coeficientes 2019/2021/2022 miden la diferencia de crecimiento de cada
* anio respecto al anio pandemia (2020) para el decil base (2).

forval j = 1/2 {
    di as result _n "===== RESUMEN j = `j' (OLS; Heckman m4_`j' se reporta arriba) ====="
    estimates table s0_`j' imp1_`j' imp2_`j' m2lo_`j' m2hi_`j' ///
                    m3_`j' m5_`j' m6_`j' m7a_`j' m7b_`j', ///
        keep(2018.anio 2019.anio 2021.anio 2022.anio) ///
        b(%9.4f) se(%9.4f) stats(N)
}

log close

di as result _n "===================================================="
di as result    "  analysis_3.do FINALIZO SIN ERRORES"
di as result    "===================================================="

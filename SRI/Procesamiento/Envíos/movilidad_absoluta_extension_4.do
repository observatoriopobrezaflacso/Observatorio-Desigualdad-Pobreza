/*******************************************************************************
* EXTENSIÓN: TODO SOBRE UN ÚNICO PANEL BALANCEADO (2018–2021)
*
* Se ejecuta DESPUÉS del script principal. Reutiliza:
*   - $dir_merged/all_years.dta   (panel persona-año)
*
* Población FIJA: solo cédulas presentes en LOS CUATRO años (2018–2021).
* Percentiles RECONSTRUIDOS dentro del panel balanceado.
* Transiciones consecutivas: 2018→2019, 2019→2020 (pandemia), 2020→2021.
* La pandemia se contrasta contra 2018→2019 y 2020→2021.
*
* Bloques (todos sobre la MISMA muestra balanceada):
*   A. delta_pctl SIGNADO   → beta(pandemic) ~0 (movilidad de rango, suma cero).
*   B. Movilidad de RANGO:  |Δpercentil| + persistencia en cima/fondo.
*   C. Movilidad ABSOLUTA:  crecimiento real del ingreso.
*******************************************************************************/

clear all
set more off

* ============================================================================
* 0. RUTAS + PARÁMETROS
* ============================================================================

global user_root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

global dir_merged "$user_root/03 BDD/Merged"
global dir_out    "$user_root/Resultados/Movilidad_Regresion"
global dir_senescyt "$user_root/03 BDD/SENESCYT"

capture mkdir "$dir_out"

log using "$dir_out/log", replace


* Cortes de "cima"/"fondo": decil superior (>=90) / decil inferior (=<10).
* top 1%: 99 / 2.  Quintiles: 80 / 21.
global topcut 90
global botcut 10



* ============================================================================
* 1. DEFLACTOR — ¡REEMPLAZAR CON IPC OFICIAL DE ECUADOR (INEC), base 2018=100!
* ============================================================================
* Sin un IPC real, la movilidad absoluta (C) estaría contaminada por inflación.

preserve
clear
input int anio double ipc
2017 105
2018 105.28
2019 105.21
2020 104.23
2021 106.26
2022 110.23
end
label var ipc "IPC base 2014=100  (REEMPLAZAR con INEC)"
save "$dir_merged/defl", replace
restore

* ============================================================================
* 2. CONSTRUIR LA MUESTRA BALANCEADA (UNA SOLA VEZ)
* ============================================================================

di as result _n "============================================================="
di as result    "  2. CONSTRUCCIÓN DEL PANEL BALANCEADO 2018–2021"
di as result    "============================================================="

use "$dir_merged/all_years.dta" if inrange(anio, 2017, 2022), clear
keep CEDULA_PK anio PreTaxHHI
drop if PreTaxHHI <= 0 | missing(PreTaxHHI)




* --- Retener solo individuos presentes en los 4 años (población fija) ---
bysort CEDULA_PK: gen byte _nyears = _N
keep if _nyears == 6
drop _nyears

quietly bysort CEDULA_PK: gen byte _first = (_n==1)
quietly count if _first
di as text "  Cédulas en panel balanceado: " r(N)
drop _first

* --- Re-rankear DENTRO del panel balanceado, intra-año ---

gen percentil = .


preserve 
keep in 1
drop in 1
tempfile rank
save "$dir_merged/rank", replace 
restore

levelsof anio, local(byrs)
*local byrs 2018 2019 2020 2021
foreach yr of local byrs { 
	di "******`yr'******"
	preserve 
	keep if anio == `yr'
    xtile _tp = PreTaxHHI, nq(100)
    replace percentil = _tp 
    drop _tp
	append using  "$dir_merged/rank"
	save "$dir_merged/rank", replace 
	restore
}

use "$dir_merged/rank", clear



** Merge con SENESCYT **
merge m:1 CEDULA_PK using "$dir_senescyt/SENESCYT_clean.dta"

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     6,937,411
        from master                 6,382,302  (_merge==1)
        from using                    555,109  (_merge==2)

    Matched                         4,189,872  (_merge==3)
    -----------------------------------------
*/


drop if _merge == 2

replace max_nivel = 0 if _merge == 1

label define nivel 0 "No universidad", add
label values max_nivel nivel

gen universidad = max_nivel != 0
replace universidad = . if max_nivel == .


encode genero, gen(genero_enc)
drop genero
rename genero_enc genero


encode tipo_financiamiento, gen(financiamiento)
recode financiamiento (1 2 = 1) (3 = 2)
label define financiamiento 1 "Particular" 2 "Pública", modify
label values financiamiento financiamiento
drop tipo_financiamiento


gen tercer_nivel = 1 if inlist(max_nivel, 1, 2)
replace tercer_nivel = 0 if max_nivel == 3


* --- Construir transiciones consecutivas vía xtset ---


gen cedula_num = substr(CEDULA_PK, 2, .)
destring cedula_num, gen(id_bal)
drop cedula_num CEDULA_PK
xtset id_bal anio
gen percentil_t1   = percentil
gen percentil_t0   = L.percentil
gen double ingreso_t1 = PreTaxHHI
gen double ingreso_t0 = L.PreTaxHHI
gen int  anio_t1   = anio
gen int  anio_t0   = anio - 1
gen delta_pctl     = percentil_t1 - percentil_t0
gen abs_delta_pctl = abs(delta_pctl)
gen byte pandemic  = (anio_t1==2020)      // 2019→2020
label var pandemic "Transición pandemia (2019→2020)"

* --- Indicadores de cima/fondo ---
gen byte top_t0 = (percentil_t0 >= $topcut) if !missing(percentil_t0)
gen byte bot_t0 = (percentil_t0 <= $botcut) if !missing(percentil_t0)
gen byte top_t1 = (percentil_t1 >= $topcut) if !missing(percentil_t1)
gen byte bot_t1 = (percentil_t1 <= $botcut) if !missing(percentil_t1)
gen byte stay_top    = (top_t1==1) if top_t0==1
gen byte stay_bottom = (bot_t1==1) if bot_t0==1
label var stay_top    "=1 permanece en la cima (origen en cima)"
label var stay_bottom "=1 permanece en el fondo (origen en fondo)"

gen transiciones = string(anio_t0) + "_" + string(anio_t1)
recode percentil   (1/10 = 1) (11/20 = 2) (21/30= 3) ///
				   (31/40 = 4) (41/50 = 5) (51/60 = 6) ///
				   (61/70 = 7) (71/80 = 8) (81/90 = 9) ///
				   (91/100 = 10), gen(decil)

gen decil_t1   = decil
gen decil_t0   = L.decil
gen delta_decil = decil_t1 - decil_t0
gen abs_delta_decil = abs(delta_decil)
				   
gen pos_delta_decil = delta_decil if delta_decil >= 0
replace pos_delta_decil = 0 if delta_decil < 0 

gen pos_delta_pctl = delta_pctl if delta_pctl >= 0
replace pos_delta_pctl = 0 if delta_pctl< 0 
				   				   
				  				   
*drop if missing(percentil_t0)             // descarta la 1a obs (2017)
				   
log using "$dir_out/transiciones_por_anio", replace text
				   
di as text _n "  Transiciones en la muestra balanceada:"
tab anio_t0 anio_t1

log close

* ============================================================================
* A. RANGO SIGNADO — CHEQUEO DEL COEFICIENTE CERO
* ============================================================================

tabstat delta_pctl, by(anio_t1) stat(mean n) format(%9.5f)
regress delta_pctl pandemic, vce(cluster id_bal)
regress delta_decil pandemic, vce(cluster id_bal)


* ============================================================================
* B. MOVILIDAD DE RANGO — CAMBIO ABSOLUTO Y PERSISTENCIA (BALANCEADO)
* ============================================================================

log using "$dir_out/movilidad_relativa", replace text

* --- Descriptiva: matriz de transición por quintil ---
gen byte q_t0 = ceil(percentil_t0/20)
gen byte q_t1 = ceil(percentil_t1/20)
replace q_t0 = 5 if q_t0>5 & !missing(q_t0)
replace q_t1 = 5 if q_t1>5 & !missing(q_t1)
di as result _n "  Matriz de transición de RANGO (quintiles) — NO pandemia:"
tab q_t0 q_t1 if pandemic==0, row nofreq
di as result _n "  Matriz de transición de RANGO (quintiles) — PANDEMIA:"
tab q_t0 q_t1 if pandemic==1, row nofreq


tab q_t0 q_t1 if anio == 2018, row nofreq
tab q_t0 q_t1 if anio == 2019, row nofreq
tab q_t0 q_t1 if anio == 2020, row nofreq
tab q_t0 q_t1 if anio == 2021, row nofreq
tab q_t0 q_t1 if anio == 2022, row nofreq

******* Absoluto ******

tabstat abs_delta_pctl stay_top stay_bottom, by(pandemic) ///
    stat(mean sd n) format(%9.4f)

reg abs_delta_pctl pandemic,  vce(cluster id_bal)
estimates store b_abs1
reg abs_delta_pctl ib2018.anio, vce(cluster id_bal)
reg stay_top pandemic,  vce(cluster id_bal)
estimates store b_stop
reg stay_bottom pandemic, vce(cluster id_bal)
estimates store b_sbot

***** Solo cambios positivos *****

* Decil

reg abs_delta_decil pandemic,  vce(cluster id_bal)
reg pos_delta_decil pandemic,  vce(cluster id_bal)


reg abs_delta_decil ib2018.anio,  vce(cluster id_bal)
reg pos_delta_decil ib2018.anio,  vce(cluster id_bal)

* Percentil

reg abs_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl pandemic,  vce(cluster id_bal)


reg abs_delta_pctl ib2018.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio,  vce(cluster id_bal)

reg pos_delta_pctl ib2019.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio,  vce(cluster id_bal)


log close

* ============================================================================
* INTERACCIONES
* ============================================================================


***** X universidad *****

log using "$dir_out/interacciones", replace text


reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.universidad,  vce(cluster id_bal)


***** X sexo *****


reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.genero,  vce(cluster id_bal)


***** X financiamiento *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.financiamiento,  vce(cluster id_bal)

***** X financiamiento *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.financiamiento,  vce(cluster id_bal)


***** X Nivel *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.tercer_nivel,  vce(cluster id_bal)


log close




s


* ============================================================================
* C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL DEL INGRESO (BALANCEADO)
* ============================================================================

di as result _n "============================================================="
di as result    "  C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL"
di as result    "============================================================="

* --- Deflactar (merge IPC en t0 y t1) ---

drop anio
rename anio_t0 anio
merge m:1 anio using "$dir_merged/defl", keep(1 3) nogen
rename anio anio_t0
rename ipc  ipc_t0
rename anio_t1 anio
merge m:1 anio using "$dir_merged/defl", keep(1 3) nogen
rename anio anio_t1
rename ipc  ipc_t1

gen double real_t0 = ingreso_t0 / (ipc_t0/100)
gen double real_t1 = ingreso_t1 / (ipc_t1/100)
gen double g_real   = ln(real_t1) - ln(real_t0) if real_t0>0 & real_t1>0 & ///
    !missing(real_t0, real_t1)
gen byte abs_up = (real_t1 > real_t0) if !missing(real_t0,real_t1)
label var g_real "Crecimiento real del ingreso (log, t0→t1)"

di as result _n "  Crecimiento real medio — pandemia vs. resto:"
tabstat g_real abs_up, by(pandemic) stat(mean sd n) format(%9.4f)

di as result _n "  [C1] g_real = a + b*pandemic        (b NO atado a 0)"
regress g_real pandemic, vce(cluster id_bal)
estimates store c_ols1

di as result _n "  [C2] g_real = a + b*pandemic + g*percentil_t0"
regress g_real pandemic percentil_t0, vce(cluster id_bal)
estimates store c_ols2

di as result _n "  [C3] g_real con FE de individuo"
capture which reghdfe
if !_rc {
    reghdfe g_real pandemic percentil_t0, absorb(id_bal) vce(cluster id_bal)
    estimates store c_fe
}
else di as error "  reghdfe no instalado; omito C3. (ssc install reghdfe)"

di as result _n "  [C4] Tasa de movilidad absoluta ascendente (ingreso creció)"
regress abs_up pandemic percentil_t0, vce(cluster id_bal)
estimates store c_up

* ============================================================================
* TABLA RESUMEN  (todo sobre la muestra balanceada)
* ============================================================================

di as result _n "============================================================="
di as result    "  RESUMEN — MUESTRA BALANCEADA 2018–2021"
di as result    "============================================================="

di as result _n "  --- A: rango signado ---"
estimates table a_signed, keep(pandemic) b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- B: rango (|Δ| y persistencia) ---"
estimates table b_abs1 b_abs2 b_stop b_sbot, keep(pandemic) ///
    b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- C: absoluta (crecimiento real) ---"
estimates table c_ols1 c_ols2 c_up, keep(pandemic percentil_t0) ///
    b(%9.4f) se(%9.4f) stats(N r2)

di as text _n "  Todo sobre POBLACIÓN FIJA → sin sesgo de composición."
di as text    "  Base de comparación de la pandemia: 2018→2019 y 2020→2021."
di as text    "  A: signado ~0 (suma cero).  B: reordenamiento/persistencia."
di as text    "  C: nivel real (empobrecimiento). Reemplazar el IPC de ejemplo."
log close
s

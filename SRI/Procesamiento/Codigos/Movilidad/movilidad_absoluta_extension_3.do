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

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"
global dir_merged "$basedir/Bases/Fake/03_BDD/Merged"
global dir_out    "$basedir/Resultados/Movilidad_Regresion"

* Cortes de "cima"/"fondo": decil superior (>=90) / decil inferior (=<10).
* top 1%: 99 / 2.  Quintiles: 80 / 21.
global topcut 90
global botcut 10

* ============================================================================
* 1. DEFLACTOR — ¡REEMPLAZAR CON IPC OFICIAL DE ECUADOR (INEC), base 2018=100!
* ============================================================================
* Sin un IPC real, la movilidad absoluta (C) estaría contaminada por inflación.

tempfile defl
clear
input int anio double ipc
2018 100.0
2019 100.3
2020 100.0
2021 101.3
end
label var ipc "IPC base 2018=100  (REEMPLAZAR con INEC)"
save "`defl'", replace

* ============================================================================
* 2. CONSTRUIR LA MUESTRA BALANCEADA (UNA SOLA VEZ)
* ============================================================================

di as result _n "============================================================="
di as result    "  2. CONSTRUCCIÓN DEL PANEL BALANCEADO 2018–2021"
di as result    "============================================================="

use "$dir_merged/all_years.dta", clear
keep CEDULA_PK anio ingreso_neto
keep if inrange(anio, 2018, 2021)
drop if ingreso_neto <= 0 | missing(ingreso_neto)

* --- Retener solo individuos presentes en los 4 años (población fija) ---
bysort CEDULA_PK: gen byte _nyears = _N
keep if _nyears == 4
keep if inrange(anio, 2018, 2024)
drop _nyears

quietly bysort CEDULA_PK: gen byte _first = (_n==1)
quietly count if _first
di as text "  Cédulas en panel balanceado: " r(N)
drop _first

* --- Re-rankear DENTRO del panel balanceado, intra-año ---
gen percentil = .
levelsof anio, local(byrs)
foreach yr of local byrs {
    xtile _tp = ingreso_neto if anio==`yr', nq(100)
    replace percentil = _tp if anio==`yr'
    drop _tp
}

* --- Construir transiciones consecutivas vía xtset ---
encode CEDULA_PK, gen(id_bal)
xtset id_bal anio
gen percentil_t1   = percentil
gen percentil_t0   = L.percentil
gen double ingreso_t1 = ingreso_neto
gen double ingreso_t0 = L.ingreso_neto
gen int  anio_t1   = anio
gen int  anio_t0   = anio - 1
gen delta_pctl     = percentil_t1 - percentil_t0
gen abs_delta_pctl = abs(delta_pctl)
gen byte pandemic  = (anio_t1==2020)      // 2019→2020
label var pandemic "Transición pandemia (2019→2020)"
drop if missing(percentil_t0)             // descarta la 1a obs (2018)

* --- Indicadores de cima/fondo ---
gen byte top_t0 = (percentil_t0 >= $topcut) if !missing(percentil_t0)
gen byte bot_t0 = (percentil_t0 <= $botcut) if !missing(percentil_t0)
gen byte top_t1 = (percentil_t1 >= $topcut) if !missing(percentil_t1)
gen byte bot_t1 = (percentil_t1 <= $botcut) if !missing(percentil_t1)
gen byte stay_top    = (top_t1==1) if top_t0==1
gen byte stay_bottom = (bot_t1==1) if bot_t0==1
label var stay_top    "=1 permanece en la cima (origen en cima)"
label var stay_bottom "=1 permanece en el fondo (origen en fondo)"

di as text _n "  Transiciones en la muestra balanceada:"
tab anio_t0 anio_t1

* ============================================================================
* A. RANGO SIGNADO — CHEQUEO DEL COEFICIENTE CERO
* ============================================================================

di as result _n "============================================================="
di as result    "  A. delta_pctl SIGNADO (suma cero → b ~0)"
di as result    "============================================================="

di as result _n "  Media de delta SIGNADO por transición (debe ~0):"
tabstat delta_pctl, by(anio_t1) stat(mean n) format(%9.5f)

di as result _n "  [A1] delta_pctl = a + b*pandemic   (b debe ~0)"
regress delta_pctl pandemic, vce(cluster id_bal)
estimates store a_signed

* ============================================================================
* B. MOVILIDAD DE RANGO — CAMBIO ABSOLUTO Y PERSISTENCIA (BALANCEADO)
* ============================================================================

di as result _n "============================================================="
di as result    "  B. MOVILIDAD DE RANGO — |Δpercentil| Y PERSISTENCIA"
di as result    "============================================================="

* --- Descriptiva: matriz de transición por quintil ---
gen byte q_t0 = ceil(percentil_t0/20)
gen byte q_t1 = ceil(percentil_t1/20)
replace q_t0 = 5 if q_t0>5 & !missing(q_t0)
replace q_t1 = 5 if q_t1>5 & !missing(q_t1)
di as result _n "  Matriz de transición de RANGO (quintiles) — NO pandemia:"
tab q_t0 q_t1 if pandemic==0, row nofreq
di as result _n "  Matriz de transición de RANGO (quintiles) — PANDEMIA:"
tab q_t0 q_t1 if pandemic==1, row nofreq

di as result _n "  Medias pandemia vs. resto:"
tabstat abs_delta_pctl stay_top stay_bottom, by(pandemic) ///
    stat(mean sd n) format(%9.4f)

di as result _n "  [B1] |Δpercentil| = a + b*pandemic"
reghdfe abs_delta_pctl pandemic, absorb(id_bal) vce(cluster id_bal)
estimates store b_abs1
reg abs_delta_pctl pandemic,  vce(cluster id_bal)


di as result _n "  [B2] |Δpercentil| = a + b*pandemic + f(percentil_t0)"
reghdfe abs_delta_pctl pandemic c.percentil_t0##c.percentil_t0, ///
 absorb(id_bal) vce(cluster id_bal)
estimates store b_abs2

di as result _n "  [B3] PERMANECER EN LA CIMA = a + b*pandemic"
reghdfe stay_top pandemic, absorb(id_bal) vce(cluster id_bal)
estimates store b_stop

di as result _n "  [B4] PERMANECER EN EL FONDO = a + b*pandemic"
reghdfe stay_bottom pandemic, absorb(id_bal) vce(cluster id_bal)
estimates store b_sbot


reg stay_bottom pandemic, vce(cluster id_bal)


* ============================================================================
* C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL DEL INGRESO (BALANCEADO)
* ============================================================================

di as result _n "============================================================="
di as result    "  C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL"
di as result    "============================================================="

* --- Deflactar (merge IPC en t0 y t1) ---
rename anio_t0 anio
merge m:1 anio using "`defl'", keep(1 3) nogen
rename anio anio_t0
rename ipc  ipc_t0
rename anio_t1 anio
merge m:1 anio using "`defl'", keep(1 3) nogen
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

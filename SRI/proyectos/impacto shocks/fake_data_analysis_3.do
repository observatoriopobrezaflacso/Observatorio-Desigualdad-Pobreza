/*******************************************************************************
* fake_data_analysis_3.do
*
* Genera datos FALSOS (aleatorios, no reales) con el esquema que necesita
* analysis_3.do:
*   - defl.dta                    (IPC por anio)
*   - working_data_unbalanced.dta (panel persona-transicion, con attrition)
*   - working_data_balanced.dta   (individuos presentes en todos los anios)
*
* La attrition simulada esta correlacionada NEGATIVAMENTE con el ingreso
* (los pobres salen mas del panel) y se intensifica en 2020-2021, replicando
* el problema de los datos administrativos del SRI. Tambien hay REINGRESO
* al panel (la salida no es absorbente), necesario para el metodo M7.
*
* Variables extra respecto a los datos de analysis_2 (necesarias para los
* metodos de correccion de attrition de analysis_3):
*   anio_nac    : anio de nacimiento          (IPW, Heckman, MI, hot-deck)
*   genero      : 0/1                          (IPW, Heckman, MI)
*   industria   : sector 1-8                   (IPW, Heckman, MI)
*   provincia   : 1-10                         (nivel del exclusion restriction)
*   enforcement : indice provincial de exigencia de declarar; afecta la
*                 probabilidad de declarar pero NO el ingreso
*                 -> exclusion restriction del Heckman (M4)
*
* Uso:  definir  global fake_root "<carpeta destino>"  y ejecutar este do.
*******************************************************************************/

clear all
set more off
set seed 20260723

if "$fake_root" == "" global fake_root "`c(pwd)'"

* ============================================================================
* 1. DEFLACTOR IPC  ->  defl.dta
* ============================================================================
clear
set obs 10
gen int anio = 2013 + _n                          // 2014 .. 2023
gen double ipc = 100 * (1.02)^(anio - 2018)       // ~2% anual, base 2018=100
label var ipc "IPC falso (base 2018=100)"
save "$fake_root/defl.dta", replace

* ============================================================================
* 2. PANEL PERSONA-ANIO "VERDADERO" (ingreso latente + decision de declarar)
* ============================================================================
local N 3000

clear
set obs `N'
gen long id_bal = _n

* Caracteristicas fijas del individuo
gen double fe          = rnormal(6, 0.7)          // log-ingreso permanente
gen int    anio_nac    = 1960 + int(runiform()*40)
gen byte   genero      = runiform() < .5
gen byte   universidad = runiform() < (.3 + .3*(fe > 6))
gen byte   industria   = 1 + int(runiform()*8)
gen byte   provincia   = 1 + int(runiform()*10)
* Enforcement: constante por provincia, afecta declarar pero no el ingreso
gen double enforcement = 0.3 + 0.6*(provincia - 1)/9

* Una fila por (individuo, anio), 2015-2022
expand 8
bysort id_bal: gen int anio = 2014 + _n           // 2015 .. 2022

* Log-ingreso: AR(1) alrededor del efecto fijo
bysort id_bal (anio): gen double lny = fe + rnormal(0, .35) if _n == 1
by id_bal: replace lny = 0.3*fe + 0.7*lny[_n-1] + rnormal(0, .3) if _n > 1

* Shock pandemia 2020: caida transitoria, mas fuerte abajo de la distribucion
replace lny = lny - max(0.25 - 0.10*(fe - 6), 0) if anio == 2020

gen double y = exp(lny)
replace y = 1 if y < 1

* Decision de declarar (presencia en los datos): creciente en ingreso y en
* enforcement; shock de attrition en 2020-2021 concentrado en ingresos bajos
gen double xb = -4 + 0.75*lny + 1.5*enforcement + 0.3*universidad
replace xb = xb - 0.6 - 0.6*(lny < 6) if inlist(anio, 2020, 2021)
gen byte present = runiform() < invlogit(xb)

* ============================================================================
* 3. FILAS DE TRANSICION (formato de working_data_unbalanced)
* ============================================================================
* Solo se "observa" el ingreso de los anios en que la persona declaro.
xtset id_bal anio
gen double ingreso_t1 = y    if present == 1
gen double ingreso_l1 = L.y  if L.present  == 1
gen double ingreso_l2 = L2.y if L2.present == 1
gen double ingreso_l3 = L3.y if L3.present == 1
gen double ingreso_t0_1 = ingreso_l1
egen double ingreso_t0_2 = rowmean(ingreso_l1 ingreso_l2 ingreso_l3)

label var ingreso_t1   "Ingreso declarado en t1"
label var ingreso_t0_1 "Ingreso t0 (anio previo)"
label var ingreso_t0_2 "Ingreso t0 (promedio 3 anios previos)"

* Una fila existe solo si la persona declaro en t1 (attrition = fila faltante)
keep if anio >= 2018 & present == 1

* Deciles de ingreso t0 dentro de cada anio
forval s = 1/2 {
    gen int decil_t0_`s' = .
    forval a = 2018/2022 {
        xtile _d = ingreso_t0_`s' if anio == `a', nq(10)
        replace decil_t0_`s' = _d if anio == `a'
        drop _d
    }
    label var decil_t0_`s' "Decil de ingreso t0 (def. `s')"
}

bysort id_bal: gen byte nyears = _N
gen byte all_preyears = !missing(ingreso_l1, ingreso_l2, ingreso_l3)

keep id_bal anio anio_nac genero universidad industria provincia enforcement ///
     ingreso_t1 ingreso_t0_1 ingreso_t0_2 ingreso_l1 ingreso_l2 ingreso_l3 ///
     decil_t0_1 decil_t0_2 nyears all_preyears
sort id_bal anio

label data "FALSO - working_data_unbalanced (prueba analysis_3)"
save "$fake_root/working_data_unbalanced.dta", replace

* ============================================================================
* 4. PANEL BALANCEADO (presentes en los 5 anios 2018-2022)
* ============================================================================
keep if nyears == 5
label data "FALSO - working_data_balanced (prueba analysis_3)"
save "$fake_root/working_data_balanced.dta", replace

display as result _n "== Datos falsos generados en: $fake_root =="

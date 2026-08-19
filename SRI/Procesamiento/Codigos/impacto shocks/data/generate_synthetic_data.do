/*******************************************************************************
* generate_synthetic_data.do
*
* Crea datos SINTÉTICOS (no reales) con el esquema que espera analysis.do:
*   - defl.dta                    (IPC por año)
*   - working_data_balanced.dta   (panel persona-transición, balanceado)
*   - working_data_unbalanced.dta (panel persona-transición, no balanceado)
*
* Los valores son aleatorios pero internamente consistentes (los deciles /
* percentiles se calculan a partir del ingreso, los deltas a partir de los
* percentiles, etc.) para que las regresiones y tabstats de analysis.do
* corran sin errores de "variable not found".
*
* Uso: definir el global data_dir a la carpeta destino y ejecutar.
*******************************************************************************/

clear all
set more off
set seed 20200720

* Carpeta destino (se puede sobreescribir antes de llamar a este do)
if "$data_dir" == "" {
    global data_dir "`c(pwd)'"
}

* ============================================================================
* 1. DEFLACTOR IPC  ->  defl.dta   (keyed by anio; ipc base 100 en 2018)
* ============================================================================
clear
set obs 9
gen int anio = 2014 + _n              // 2015 .. 2023
gen double ipc = 100 * (1.02)^(anio - 2018)   // ~2% anual, base 2018=100
label var ipc "Índice de precios al consumidor (base 2018=100)"
save "$data_dir/defl.dta", replace

* ============================================================================
* 2. PANEL NO BALANCEADO  ->  working_data_unbalanced.dta
* ============================================================================
* Estructura: cada fila es una transición t0 -> t1 de un individuo.
*   anio == anio_t1 (año de llegada); anio_t0 = anio_t1 - 1.
*   (id_bal, anio) es único  =>  xtset id_bal anio es válido.

local N   4000                        // individuos
local Y0  2017                        // primer anio_t1
local Y1  2022                        // último anio_t1

clear
set obs `N'
gen long id_bal = _n
* Efecto fijo de individuo (nivel de ingreso permanente, lognormal)
gen double _fe = exp(rnormal(6, 0.6))

* Expandir a una fila por (individuo, anio_t1)
expand `= `Y1' - `Y0' + 1'
bysort id_bal: gen int anio_t1 = `Y0' + _n - 1
gen int anio_t0 = anio_t1 - 1
gen int anio    = anio_t1

* No balanceado: descartar ~20% de las transiciones (pero conservar al menos
* una observación por individuo para que fillin tenga sentido)
gen double _keep = runiform()
by id_bal: gen byte _first = (_n == 1)
drop if _keep > 0.80 & _first == 0
drop _keep _first

* --- Ingresos -------------------------------------------------------------
* choque de la pandemia: caída del crecimiento en 2020->2021
gen double _shock = cond(inlist(anio_t1, 2020, 2021), -0.15, 0.03)
gen double ingreso_t0   = _fe * exp(rnormal(0, 0.35))
gen double ingreso_t1   = ingreso_t0 * (1 + _shock + rnormal(0, 0.25))
replace    ingreso_t1   = 1 if ingreso_t1 < 1          // sin ingresos <=0
* Definición alternativa de ingreso base (otra fuente / formulario)
gen double ingreso_t0_2 = ingreso_t0 * exp(rnormal(0, 0.15))
* Ingreso rezagado (dos años antes); faltante para ~30% (sin año previo)
gen double ingreso_l1   = ingreso_t0 * exp(rnormal(0, 0.20))
replace    ingreso_l1   = . if runiform() < 0.30

label var ingreso_t0   "Ingreso base (fuente principal), t0"
label var ingreso_t0_2 "Ingreso base (definición alternativa), t0"
label var ingreso_t1   "Ingreso, t1"
label var ingreso_l1   "Ingreso rezagado (t0-1)"

* --- Percentiles y deciles dentro de cada anio_t1 -------------------------
* percentil_t1 / percentil_t0 en 1..100 ; deciles en 1..10
foreach v in t1 t0 {
    local src = cond("`v'" == "t1", "ingreso_t1", "ingreso_t0")
    bysort anio_t1 (`src'): gen double _r = _n
    by anio_t1: gen double _nn = _N
    gen int percentil_`v' = ceil(100 * _r / _nn)
    replace percentil_`v' = 100 if percentil_`v' > 100
    replace percentil_`v' = 1   if percentil_`v' < 1
    gen int decil_`v' = ceil(percentil_`v' / 10)
    drop _r _nn
}
* percentil "genérico" del año (usado en recode -> twentil). Igual a percentil_t1
gen int percentil = percentil_t1

* Deciles del ingreso base alternativo (decil_t0_2) y de la fuente 1 (decil_t0_1)
bysort anio_t1 (ingreso_t0_2): gen double _r = _n
by anio_t1: gen double _nn = _N
gen int decil_t0_2 = ceil(10 * _r / _nn)
replace decil_t0_2 = 10 if decil_t0_2 > 10
drop _r _nn
gen int decil_t0_1 = decil_t0

label var percentil_t0 "Percentil de ingreso, t0"
label var percentil_t1 "Percentil de ingreso, t1"
label var decil_t0     "Decil de ingreso, t0"
label var decil_t1     "Decil de ingreso, t1"
label var decil_t0_1   "Decil de ingreso (fuente 1), t0"
label var decil_t0_2   "Decil de ingreso (definición alt.), t0"

* --- Movilidad de rango (deltas) ------------------------------------------
gen int    delta_pctl      = percentil_t1 - percentil_t0
gen int    delta_decil     = decil_t1     - decil_t0
gen int    abs_delta_pctl  = abs(delta_pctl)
gen int    abs_delta_decil = abs(delta_decil)
gen int    pos_delta_pctl  = max(delta_pctl, 0)
gen int    pos_delta_decil = max(delta_decil, 0)
* Variantes por fuente (delta_pctl_1 / delta_pctl_2): con ligero ruido
gen int    delta_pctl_1    = delta_pctl
gen int    delta_pctl_2    = delta_pctl + round(rnormal(0, 2))

label var delta_pctl      "Cambio de percentil (signado), t0->t1"
label var delta_decil     "Cambio de decil (signado), t0->t1"
label var abs_delta_pctl  "|Cambio de percentil|"
label var abs_delta_decil "|Cambio de decil|"
label var pos_delta_pctl  "Cambio de percentil positivo (ascensos)"
label var pos_delta_decil "Cambio de decil positivo (ascensos)"

* --- Persistencia en la cima / fondo --------------------------------------
gen byte stay_top    = (percentil_t0 >= 80 & percentil_t1 >= 80)
gen byte stay_bottom = (percentil_t0 <= 20 & percentil_t1 <= 20)
label var stay_top    "Permanece en el quintil superior"
label var stay_bottom "Permanece en el quintil inferior"

* --- Tratamiento pandemia -------------------------------------------------
gen byte pandemic = inlist(anio_t1, 2020, 2021)
label var pandemic "Transición durante la pandemia (2020-2021)"

* --- Covariables categóricas (interacciones) ------------------------------
gen byte universidad    = (runiform() < 0.5)
gen byte genero         = (runiform() < 0.5)
gen byte financiamiento = 1 + int(runiform() * 3)      // 1,2,3
gen byte tercer_nivel   = (runiform() < 0.6)
gen byte source         = 1 + int(runiform() * 3)      // 1,2,3 (formulario)
label var universidad    "Asistió a universidad (0/1)"
label var genero         "Género (0/1)"
label var financiamiento "Tipo de financiamiento (1-3)"
label var tercer_nivel   "Educación de tercer nivel (0/1)"
label var source         "Fuente/formulario (1=F107,2=F102,3=ambos)"

* --- has_preyear2 (referida en un tabstat de analysis.do) -----------------
gen byte has_preyear2 = (ingreso_l1 != .)
label var has_preyear2 "Tiene año previo observado (0/1)"

drop _fe _shock
order id_bal anio anio_t0 anio_t1
sort id_bal anio
label data "SINTÉTICO - working_data_unbalanced (impacto shocks)"
save "$data_dir/working_data_unbalanced.dta", replace

* ============================================================================
* 3. PANEL BALANCEADO  ->  working_data_balanced.dta
* ============================================================================
* analysis.do sólo usa de aquí: id_bal, anio, ingreso_t0_2, ingreso_t1,
* decil_t0_2 (y luego lo mezcla con defl por anio). Lo derivamos del panel
* no balanceado quedándonos con individuos presentes en TODOS los años.

use "$data_dir/working_data_unbalanced.dta", clear
bysort id_bal: gen int _cnt = _N
quietly summarize anio
local nyears = r(max) - r(min) + 1
keep if _cnt == `nyears'
keep id_bal anio ingreso_t0_2 ingreso_t1 decil_t0_2
sort id_bal anio
label data "SINTÉTICO - working_data_balanced (impacto shocks)"
save "$data_dir/working_data_balanced.dta", replace

display as result _n "== Datos sintéticos generados en: $data_dir =="
display as result "   defl.dta / working_data_balanced.dta / working_data_unbalanced.dta"

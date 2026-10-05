/*******************************************************************************
* master_movilidad.do
*
* CORRE TODAS LAS VERSIONES DEL ANALISIS DE MOVILIDAD, UNA DETRAS DE OTRA
*
*   1) covid         completo  (2019 vs 2020, 2021, 2022)  movilidad_shock.do
*   2) covid         dos anios (2019 vs 2020)              movilidad_shock_dos_anios.do
*   3) placebo2018   sin shock (2017 vs 2018, 2019)        movilidad_shock_placebo.do
*   4) petroleo2014  completo  (2013 vs 2014, 2015, 2016)  movilidad_shock_petroleo2014.do
*
* No duplica nada: llama a los lanzadores de siempre, que a su vez llaman al
* motor (movilidad_shock.do). Todo lo del analisis se configura en el bloque
* 00 del motor; aca solo se elige QUE correr y con que opciones.
*
* Cada corrida es independiente: el motor lee y BORRA los globals $OVR_* al
* arrancar, asi que las opciones de una corrida no se pegan a la siguiente.
* Por eso las opciones de abajo se vuelven a fijar antes de cada corrida.
*
* Si una corrida falla, el master sigue con la siguiente y al final lista
* las que fallaron (con su codigo de error).
*
* -----------------------------------------------------------------------------
* COMO SE USA
*   1) cd a la carpeta de los do-files (o fijar $code_dir abajo).
*   2) Elegir las corridas (1 = correr, 0 = saltear) y las opciones.
*   3) Correr este archivo entero.
*******************************************************************************/

* --- Carpeta de los do-files -----------------------------------------------
* Por defecto, el directorio de trabajo. Si no estan ahi, fijarla a mano:
* global code_dir "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/Proyectos/Impacto shocks/codigos"
if "$code_dir" == "" global code_dir "`c(pwd)'"
capture confirm file "$code_dir/movilidad_shock.do"
if _rc {
    di as error "No encuentro movilidad_shock.do en: $code_dir"
    di as error "Hacer  cd \"<carpeta de los do-files>\"  o fijar  global code_dir  arriba."
    exit 601
}

* --- Que corridas ------------------------------------------------------------
local run_covid     1       // covid completo
local run_dos_anios 1       // covid dos anios
local run_placebo   1       // placebo2018
local run_petroleo  1       // petroleo2014

* --- Opciones que se aplican a TODAS las corridas --------------------------
* Vacio = lo que diga el bloque 00 del motor.
local opt_wins_p    ""      // winsorizacion de g en p / 100-p (ej. 1). Va a /winsorized
local opt_im_se     ""      // "boot" = EE bootstrap para los IC de Imbens-Manski
local opt_im_reps   ""      // replicas del bootstrap (ej. 500)
local opt_fake_root ""      // datos falsos para pruebas (vacio en produccion)

* ============================================================================
* A correr
* ============================================================================

local runs    "covid dos_anios placebo petroleo"
local file_covid     "movilidad_shock.do"
local file_dos_anios "movilidad_shock_dos_anios.do"
local file_placebo   "movilidad_shock_placebo.do"
local file_petroleo  "movilidad_shock_petroleo2014.do"

local fallaron ""
local corridas ""
di as result _n "== master_movilidad: inicio " c(current_date) " " c(current_time) " =="

foreach r of local runs {
    if `run_`r'' != 1 continue

    * opciones: se vuelven a fijar en cada vuelta (el motor las borra)
    if "`opt_wins_p'"    != "" global OVR_wins_p    `opt_wins_p'
    if "`opt_im_se'"     != "" global OVR_im_se     "`opt_im_se'"
    if "`opt_im_reps'"   != "" global OVR_im_reps   `opt_im_reps'
    if "`opt_fake_root'" != "" global OVR_fake_root "`opt_fake_root'"

    di as result _n "####################################################################"
    di as result    "## master: `r'  (`file_`r'')  -- " c(current_time)
    di as result    "####################################################################"

    capture noisily do "$code_dir/`file_`r''"
    local rc = _rc
    capture log close movlog            // por si la corrida se corto con un log abierto
    if `rc' {
        local fallaron "`fallaron' `r'(r`rc')"
        * limpiar overrides que hayan quedado si el motor no llego a leerlos
        foreach g in OVR_shock OVR_two_period OVR_wins_p OVR_im_se OVR_im_reps ///
                     OVR_fake_root OVR_base_mode OVR_main_growth OVR_do_leavers OVR_run_tag OVR_do_het {
            capture macro drop `g'
        }
    }
    local corridas "`corridas' `r'"
}

di as result _n "== master_movilidad: fin " c(current_date) " " c(current_time) " =="
di as text      "   corridas: `corridas'"
if "`fallaron'" == "" di as result "   todas terminaron bien"
else                  di as error  "   FALLARON:`fallaron'"

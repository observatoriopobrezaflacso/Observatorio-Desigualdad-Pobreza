/*******************************************************************************
* movilidad_shock_placebo.do
*
* PLACEBO: EL MISMO DISENO EN ANIOS SIN SHOCK
*
* No duplica nada: fija el preset "placebo2018" y llama a movilidad_shock.do.
*
*   orden (a)   2015        (decil de origen)
*   orden (b)   2013-2015   (promedio, exige los 3 anios)
*   base        2016        (base del crecimiento)
*   pre         2017
*   post        2018 2019   (2020 ya es COVID)
*
* PARA QUE SIRVE. El dif-en-dif D10 vs D6 del COVID compara el crecimiento
* hasta cada anio post con el crecimiento hasta el anio pre. Si D10 sigue
* revirtiendo a la media despues del anio pre (componentes persistentes del
* ingreso), la brecha se agranda con el horizonte aunque no haya shock. Aca
* no hay shock entre 2017 y 2019: lo que de el dif-en-dif es la parte
* mecanica. Comparar:
*       placebo 2018  con  covid 2020   (un anio despues del pre)
*       placebo 2019  con  covid 2021   (dos anios despues del pre)
* Si el placebo da cerca de cero, la reversion a la media no explica el
* resultado del COVID.
*
* OJO: 2016 (la base) es un anio de recesion (petroleo + terremoto). Con
* log-crecimiento la base se cancela en el dif-en-dif, pero la recuperacion
* 2016-2017 puede seguir en 2018. Si molesta, correr tambien la variante con
* pre 2018 y post 2019 (editar el preset en el bloque 00).
*
* -----------------------------------------------------------------------------
* COMO SE USA
*   1) Fijar $code_dir si los do-files no estan en el directorio de trabajo.
*   2) Correr este archivo entero (no por bloques: es un lanzador).
*   Resultados en .../resultados/movilidad_v2/placebo2018/
*******************************************************************************/

* --- Carpeta donde viven los do-files --------------------------------------
* Se resuelve en este orden:
*   1) $code_dir, si ya lo fijaste
*   2) el directorio de trabajo actual (lo normal si hiciste -cd- ahi)
*   3) unas carpetas candidatas bajo la raiz del proyecto en el SRI
* Si nada de eso da, descomentar y fijarla a mano:
* global code_dir "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/Proyectos/Impacto shocks/codigos"

* Raiz del proyecto en la maquina del SRI: la MISMA que usan movilidad_shock.do,
* movilidad_shock_prep1.do y analysis.do. Va en un local para no pisarle el
* global al motor.
local _root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"
local _proj "`_root'Proyectos/Impacto shocks"

if "$code_dir" != "" {
    capture confirm file "$code_dir/movilidad_shock.do"
    if _rc {
        di as error "El code_dir que fijaste no tiene movilidad_shock.do: $code_dir"
        global code_dir ""
    }
}
if "$code_dir" == "" {
    capture confirm file "`c(pwd)'/movilidad_shock.do"
    if !_rc global code_dir "`c(pwd)'"
}
* Candidatos numerados, no -foreach in-: las rutas tienen espacios.
local cand1 "`_proj'/codigos"
local cand2 "`_proj'/do"
local cand3 "`_proj'"
local cand4 "`_root'Carga codigos"
forvalues i = 1/4 {
    if "$code_dir" == "" {
        capture confirm file "`cand`i''/movilidad_shock.do"
        if !_rc global code_dir "`cand`i''"
    }
}
if "$code_dir" == "" {
    di as error "No encuentro movilidad_shock.do. Busque en:"
    di as error "   `c(pwd)'"
    forvalues i = 1/4 {
        di as error "   `cand`i''"
    }
    di as error "Solucion: hacer  cd \"<carpeta de los do-files>\"  y volver a correr,"
    di as error "          o descomentar  global code_dir  arriba."
    exit 601
}
di as text "do-files en: $code_dir"

* --- Parametros de esta corrida --------------------------------------------
global OVR_shock     "placebo2018"

* Winsorizacion del crecimiento (p / 100-p). Descomentar para la corrida
* winsorizada; los resultados van a la subcarpeta /winsorized.
* global OVR_wins_p  2

* Version de dos anios (2017 vs 2018, sin 2019). Sale a la subcarpeta
* /dos_anios. Para eso esta movilidad_shock_dos_anios.do, pero tambien se
* puede prender desde aca.
* global OVR_two_period 1

* EE de las cotas de Lee para el IC de Imbens-Manski: "reg" (rapido, por
* defecto) o "boot" (bootstrap de personas; es el que hay que reportar).
* global OVR_im_se   "boot"
* global OVR_im_reps 500

* Datos falsos para pruebas (dejar vacio en produccion).
* global OVR_fake_root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/Proyectos/Impacto shocks/prueba_falsa"

* --- A correr ---------------------------------------------------------------
do "$code_dir/movilidad_shock.do"

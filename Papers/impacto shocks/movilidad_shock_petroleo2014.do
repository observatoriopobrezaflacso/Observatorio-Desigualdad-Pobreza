/*******************************************************************************
* movilidad_shock_petroleo2014.do
*
* VERSION DEL ANALISIS PARA EL SHOCK DEL PRECIO DEL PETROLEO (2014)
*
* No duplica nada: fija los parametros del shock y llama a movilidad_shock.do,
* que es el mismo motor que se usa para el COVID. Asi hay UN solo lugar donde
* arreglar bugs y agregar analisis.
*
*   orden (a)   2011        (decil de origen)
*   orden (b)   2010-2011   (promedio, exige los 2 anios; el IPC arranca en 2010)
*   base        2012        (base del crecimiento, v2)
*   pre-shock   2013        ultimo anio "normal"
*   post-shock  2014 2015 2016
*
* El crudo se derrumba a mediados de 2014 (de ~100 a ~50 USD entre junio y
* diciembre), asi que 2014 YA es un anio de shock: el ultimo anio de
* referencia limpio es 2013. Si preferis fechar el impacto sobre el ingreso
* declarado un anio mas tarde (pre = 2014, post = 2015-2017), cambiar el
* preset "petroleo2014" en el bloque 00 de movilidad_shock.do.
*
* -----------------------------------------------------------------------------
* COMO SE USA
*   1) Fijar $code_dir si los do-files no estan en el directorio de trabajo.
*   2) Correr este archivo entero (no por bloques: es un lanzador).
*   3) Para la version winsorizada, descomentar $OVR_wins_p. Los resultados
*      van solos a  .../resultados/movilidad/petroleo2014/winsorized/
*
* Todo lo demas (variables de ingreso, deciles 6-10, muestras, cotas de Lee)
* se configura en el bloque 00 de movilidad_shock.do y se comparte con COVID.
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
global OVR_shock     "petroleo2014"

* Winsorizacion del crecimiento (p / 100-p). Descomentar para la corrida
* winsorizada; los resultados van a la subcarpeta /winsorized.
* global OVR_wins_p  2

* Version de dos anios (2013 vs 2014, sin 2015 ni 2016). Sale a la subcarpeta
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

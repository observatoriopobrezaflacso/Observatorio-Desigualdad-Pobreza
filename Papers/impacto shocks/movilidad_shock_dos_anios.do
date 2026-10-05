/*******************************************************************************
* movilidad_shock_dos_anios.do
*
* VERSION DE DOS ANIOS: solo el anio PRE y el PRIMER anio POST
*
*       covid         2019  vs  2020
*       petroleo2014  2013  vs  2014
*       placebo2018   2017  vs  2018
*
* No duplica nada: prende $two_period y llama a movilidad_shock.do, el mismo
* motor de siempre.
*
* -----------------------------------------------------------------------------
* QUE CAMBIA Y QUE NO
*
*   CAMBIA: $post_years se queda con un solo anio. Entonces
*     - el dif-en-dif del analisis (1) es el 2x2 clasico
*       [g(D10,post) - g(D6,post)] - [g(D10,pre) - g(D6,pre)]
*       (la especificacion 7.2 se omite porque seria la misma regresion)
*     - los analisis (2) y (3) reportan un solo contraste post vs pre
*     - las cotas de Lee y sus IC de Imbens-Manski salen para ese unico anio
*
*   NO CAMBIA (v2): los anios de ORDEN con los que se arman los deciles de
*   origen y la BASE del crecimiento siguen intactos:
*     orden (a)  covid 2017 ; petroleo2014 2011 ; placebo2018 2015
*     orden (b)  covid 2015-2017 ; petroleo2014 2010-2011 ; placebo2018 2013-2015
*     base       covid 2018 ; petroleo2014 2012 ; placebo2018 2016
*   Sigue haciendo falta leer el panel desde $t0_win_first, aunque despues se
*   analicen solo dos anios.
*
*   Con solo dos anios, el bloque 11 (los que se van) y las cotas de Lee
*   comparan unicamente el pre con el primer post: el recorte de Lee iguala
*   la retencion de esos dos anios y no la del peor anio de toda la ventana.
*
*   OJO con mover la base. Tiene que quedar ESTRICTAMENTE antes de $pre_year:
*   si fuera el propio $pre_year, el crecimiento del anio pre seria cero por
*   construccion y el dif-en-dif se quedaria sin periodo pre. Y los anios de
*   orden tienen que quedar antes de la base (el bloque 01 lo controla).
*
* -----------------------------------------------------------------------------
* SALIDAS
*       .../resultados/movilidad_v2/<shock>/dos_anios/
*       .../resultados/movilidad_v2/<shock>/dos_anios/winsorized/   (si $OVR_wins_p)
*   y los .dta intermedios llevan el sufijo _2p, asi que esta corrida no pisa
*   la version completa.
*
* -----------------------------------------------------------------------------
* COMO SE USA
*   1) Elegir el shock abajo.
*   2) Correr el archivo entero (es un lanzador, no se corre por bloques).
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
global OVR_shock      "covid"       // <<< EDITAR: covid | petroleo2014 | placebo2018
global OVR_two_period 1

* Winsorizacion del crecimiento (p / 100-p). Descomentar para la version
* winsorizada; sale a .../dos_anios/winsorized/
* global OVR_wins_p   2

* EE de las cotas de Lee: "reg" (rapido) o "boot" (bootstrap de personas, es
* el que hay que usar para reportar los IC de Imbens-Manski en el paper).
* Con solo dos anios el bootstrap cuesta mucho menos que en la version
* completa, asi que aca conviene prenderlo.
* global OVR_im_se    "boot"
* global OVR_im_reps  500

* Datos falsos para pruebas (dejar comentado en produccion).
* global OVR_fake_root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/Proyectos/Impacto shocks/prueba_falsa"

* --- A correr ---------------------------------------------------------------
do "$code_dir/movilidad_shock.do"

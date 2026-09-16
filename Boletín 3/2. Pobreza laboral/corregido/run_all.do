*------------------------------------------------------------------------------*
* run_all.do — Master file: corre toda la cadena de pobreza laboral
*------------------------------------------------------------------------------*
* Uso:
*     do "run_all.do"
*
* Se puede ejecutar desde cualquier directorio: el master se ubica solo.
* Para saltar etapas, cambie los interruptores de abajo a 0.
*
* Etapas:
*     01  Construye el panel armonizado 2001-2025 desde las bases de ENEMDU
*     05  Valida que la replica reproduce los archivos publicados
*     02  Calcula las series corregidas y los Graficos 9, 10 y 11
*     03  Cuantifica el efecto de cada error
*     04  Composicion de los ocupados pobres por horas trabajadas
*
* Dependencias: 05, 02 y 03 necesitan el panel de 01. 03 y 04 necesitan
* ademas el panel final que produce 02. Respete el orden si salta etapas.
*------------------------------------------------------------------------------*

clear all
set more off
version 15.1

*--- Interruptores ---*
local hacer_01 1      // panel (es la etapa lenta)
local hacer_05 1      // validacion contra lo publicado
local hacer_02 1      // series corregidas y graficos
local hacer_03 1      // cuantificacion del impacto
local hacer_04 1      // descriptivos de horas

*------------------------------------------------------------------------------*
* Ubicar la carpeta de codigo
*------------------------------------------------------------------------------*
capture confirm file "00_config.do"
if _rc {
    local u = c(username)
    if "`u'" == "vero" {
        local gh_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
    }
    else if "`u'" == "santiago" {
        local gh_root "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza"
    }
    else {
        display as error "Usuario `u' no configurado. Ejecute el master desde su propia carpeta."
        error 198
    }
    quietly cd "`gh_root'/Boletín 3/2. Pobreza laboral/corregido"

    capture confirm file "00_config.do"
    if _rc {
        display as error "No se encuentra 00_config.do en `c(pwd)'"
        error 601
    }
}

local codigo "`c(pwd)'"
display as text "Carpeta de codigo: `codigo'"

*------------------------------------------------------------------------------*
* Bitacora
*------------------------------------------------------------------------------*
* Se usa una bitacora con NOMBRE y se cierra solo esa. Un "log close _all"
* cerraria tambien el log que abre quien invoque este master (por ejemplo, el
* generador del boletin, que corre los .do con "stata -b do" y despues lee ese
* log para detectar errores).
capture log close runall
local marca = subinstr("`c(current_date)'", " ", "", .) + "_" + ///
              subinstr(substr("`c(current_time)'", 1, 5), ":", "", .)
log using "`codigo'/run_all_`marca'.log", replace text name(runall)

display as text _n(2) "{hline 78}"
display as text "POBREZA LABORAL — corrida completa"
display as text "Inicio: `c(current_date)' `c(current_time)'"
display as text "{hline 78}"

*------------------------------------------------------------------------------*
* Ejecucion
*------------------------------------------------------------------------------*
local fallidas ""
local corridas ""

foreach par in "01 01_panel" "05 05_validacion" "02 02_indicadores" ///
               "03 03_impacto" "04 04_descriptivos" {

    local num : word 1 of `par'
    local scr : word 2 of `par'

    if !`hacer_`num'' {
        display as text _n "--- `scr'.do: OMITIDA por interruptor ---"
        continue
    }

    display as text _n(2) "{hline 78}"
    display as text ">>> `scr'.do   (`c(current_time)')"
    display as text "{hline 78}"

    * Se mide con reloj de pared: "clear all" dentro de cada script borra los
    * timers de Stata, asi que no se pueden usar aqui.
    local t0 = clock("`c(current_date)' `c(current_time)'", "DMY hms")
    capture noisily do "`codigo'/`scr'.do"
    local rc = _rc
    local t1 = clock("`c(current_date)' `c(current_time)'", "DMY hms")
    local seg = (`t1' - `t0') / 1000

    * Cada script hace "clear all", que puede dejar el directorio de trabajo
    * intacto pero conviene reafirmarlo antes de la siguiente etapa.
    quietly cd "`codigo'"

    if `rc' {
        display as error _n "!!! `scr'.do fallo con codigo de error `rc'"
        local fallidas "`fallidas' `scr'"
        display as error "Se interrumpe la cadena: las etapas siguientes dependen de esta."
        continue, break
    }
    else {
        display as result _n "OK  `scr'.do  (" %6.1f `seg' " segundos)"
        local corridas "`corridas' `scr'"
    }
}

*------------------------------------------------------------------------------*
* Resumen
*------------------------------------------------------------------------------*
do "`codigo'/00_config.do"

display as text _n(2) "{hline 78}"
display as text "RESUMEN"
display as text "{hline 78}"
display as text "Etapas completadas:`corridas'"

if "`fallidas'" != "" {
    display as error "Etapas con error:`fallidas'"
}
else {
    display as result "Todas las etapas solicitadas terminaron sin errores."
    display as text _n "Salidas:"
    display as text "  Series y graficos : $outdir"
    display as text "  Tablas de impacto : $outdir/impacto_*.xlsx"
    display as text "  Panel armonizado  : $paneldir"
    display as text _n "Los archivos publicados en" _n ///
                    "  $user_root/Boletín 3/4. Resultados/pobreza laboral" _n ///
                    "no se modifican: todo se escribe en la subcarpeta 'corregido'."
}

display as text _n "Fin: `c(current_date)' `c(current_time)'"
display as text "{hline 78}"

capture log close runall

* Se propaga el fallo a quien invoque este master (master_boletin3.do, el
* generador del boletin o "stata -b"). Sin esto, las etapas internas quedan
* capturadas y el llamador creeria que todo salio bien.
if "`fallidas'" != "" exit 1

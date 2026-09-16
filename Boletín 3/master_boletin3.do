*------------------------------------------------------------------------------*
* master_boletin3.do — Corre todos los gráficos del Boletín 3 y genera el Word
*------------------------------------------------------------------------------*
* Uso:
*     do "master_boletin3.do"
*
* Se puede ejecutar desde cualquier directorio: el master se ubica solo.
* Para saltar etapas, cambie los interruptores de abajo a 0.
*
* Etapas:
*   armonizacion  diseno_muestral.do + merge_informal.do   -> bases armonizadas
*   informalidad  analisis_descriptivo.do                  -> Graficos 1-8, Tablas 1-2
*   ic            analisis_descriptivo_ic.do               -> graficos con IC
*   pobreza       2. Pobreza laboral/corregido/run_all.do  -> Graficos 9-11 y series
*   homicidios    graficos_homicidios_nna.do               -> Grafico 12
*   word          generar_boletin.py                       -> el .docx
*
* Notas:
*   - "armonizacion" no corre por omision: es la parte lenta y sus salidas
*     cambian poco.
*   - "ic" tampoco: necesita estrato_svy y upm_svy, que crea la armonizacion, y
*     no produce ninguna de las 12 figuras del boletin.
*   - "homicidios" esta marcada como OPCIONAL: sus .csv de insumo no estan en el
*     repositorio, asi que si falla se avisa y se continua.
*------------------------------------------------------------------------------*

clear all
set more off
version 15.1

*------------------------------------------------------------------------------*
* Interruptores
*------------------------------------------------------------------------------*
local hacer_armonizacion 0
local hacer_informalidad 1
local hacer_ic           0
local hacer_pobreza      1
local hacer_homicidios   1
local hacer_word         1

* Etapas que pueden fallar sin detener la cadena.
local opcionales "homicidios ic"

*------------------------------------------------------------------------------*
* Rutas
*------------------------------------------------------------------------------*
local u = c(username)

if "`u'" == "vero" {
    local gh_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
}
else if "`u'" == "santiago" {
    local gh_root "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza"
}
else {
    display as error "Usuario `u' no configurado en master_boletin3.do."
    display as error "Agregue su caso definiendo gh_root."
    error 198
}

local b3      "`gh_root'/Boletín 3"
local analisis "`b3'/1. Infomalidad/3. Analisis"
local armoniz  "`b3'/1. Infomalidad/2. Armonización de variables/main"
local generador "`b3'/4. Boletin automatizado"
local pobreza   "`b3'/2. Pobreza laboral/corregido"
local homicidios "`b3'/3. homicidios_nna"

capture confirm file "`generador'/generar_boletin.py"
if _rc {
    display as error "No se encuentra el generador en: `generador'"
    display as error "Revise gh_root en este archivo."
    error 601
}

local dir_inicial "`c(pwd)'"

*------------------------------------------------------------------------------*
* Bitacora
*------------------------------------------------------------------------------*
* Log con NOMBRE: un "log close _all" cerraria tambien el log de quien invoque
* este master (por ejemplo, Stata en modo batch).
capture log close master3
local marca = subinstr("`c(current_date)'", " ", "", .) + "_" + ///
              subinstr(substr("`c(current_time)'", 1, 5), ":", "", .)
capture mkdir "`b3'/logs"
log using "`b3'/logs/master_boletin3_`marca'.log", replace text name(master3)

display as text _n(2) "{hline 78}"
display as text "BOLETIN 3 — corrida completa"
display as text "Inicio: `c(current_date)' `c(current_time)'"
display as text "{hline 78}"

*------------------------------------------------------------------------------*
* Etapas de Stata
*------------------------------------------------------------------------------*
local fallidas ""
local ok_lista ""
local etapa_rota ""

* Cada elemento es "etapa|ruta del do-file".
* Las comillas van literales en el foreach: si la lista se guardara antes en un
* local, Stata las descartaria y partiria las rutas que tienen espacios.
foreach tarea in ///
    "armonizacion|`armoniz'/componentes/diseno_muestral.do" ///
    "armonizacion|`analisis'/merge_informal.do" ///
    "informalidad|`analisis'/analisis_descriptivo.do" ///
    "ic|`analisis'/analisis_descriptivo_ic.do" ///
    "pobreza|`pobreza'/run_all.do" ///
    "homicidios|`homicidios'/graficos_homicidios_nna.do" {

    gettoken etapa resto : tarea, parse("|")
    local archivo = substr("`resto'", 2, .)
    local nombre = substr("`archivo'", strrpos("`archivo'", "/") + 1, .)

    if !`hacer_`etapa'' continue

    * Si un do-file anterior de la MISMA etapa fallo, no tiene sentido seguir:
    * los que vienen despues dependen de el.
    if "`etapa'" == "`etapa_rota'" {
        display as text _n "--- `nombre': se omite (`etapa' ya fallo) ---"
        continue
    }

    display as text _n(2) "{hline 78}"
    display as text ">>> [`etapa'] `nombre'   (`c(current_time)')"
    display as text "{hline 78}"

    * Reloj de pared: "clear all" dentro de cada do-file borra los timers.
    local t0 = clock("`c(current_date)' `c(current_time)'", "DMY hms")
    capture noisily do "`archivo'"
    local rc = _rc
    local t1 = clock("`c(current_date)' `c(current_time)'", "DMY hms")
    local seg = (`t1' - `t0') / 1000

    * Los do-files pueden dejar el directorio de trabajo en otro lado.
    quietly cd "`dir_inicial'"

    if `rc' {
        local es_opcional : list posof "`etapa'" in opcionales
        if `es_opcional' {
            display as error _n "[opcional] `nombre' fallo con r(`rc'). Se continua."
            local fallidas "`fallidas' `nombre'(opcional)"
        }
        else {
            display as error _n "!!! `nombre' fallo con r(`rc')."
            local fallidas "`fallidas' `nombre'"
            local etapa_rota "`etapa'"
        }
    }
    else {
        display as result _n "OK  `nombre'  (" %6.1f `seg' " segundos)"
        local ok_lista "`ok_lista' `nombre'"
    }
}

*------------------------------------------------------------------------------*
* Generacion del Word
*------------------------------------------------------------------------------*
local rc_word 0

if `hacer_word' {

    display as text _n(2) "{hline 78}"
    display as text ">>> [word] generar_boletin.py   (`c(current_time)')"
    display as text "{hline 78}"

    local python "`generador'/.venv/bin/python"

    capture confirm file "`python'"
    if _rc {
        display as error "No existe el entorno de Python del generador."
        display as error "Creelo una sola vez con:"
        display as error `"    cd "`generador'""'
        display as error "    python3 -m venv .venv"
        display as error "    .venv/bin/pip install -r requirements.txt"
        local rc_word 1
        local fallidas "`fallidas' generar_boletin.py"
    }
    else {
        tempfile salida_py codigo_py
        * Se redirige a un archivo y despues se vuelca al log, para que la salida
        * de Python quede registrada tambien en modo batch.
        * No se usa "echo $?" porque Stata expandiria el $ como macro global:
        * se escribe OK o FALLO segun el exito del comando.
        shell cd "`generador'" && "`python'" generar_boletin.py > "`salida_py'" 2>&1 && echo OK > "`codigo_py'" || echo FALLO > "`codigo_py'"

        capture noisily type "`salida_py'"

        local rc_word 1
        capture {
            tempname fh
            file open `fh' using "`codigo_py'", read text
            file read `fh' linea
            file close `fh'
            if trim("`linea'") == "OK" local rc_word 0
        }

        if `rc_word' {
            display as error _n "!!! generar_boletin.py fallo con codigo `rc_word'."
            local fallidas "`fallidas' generar_boletin.py"
        }
        else {
            display as result _n "OK  generar_boletin.py"
            local ok_lista "`ok_lista' generar_boletin.py"
        }
    }
}

*------------------------------------------------------------------------------*
* Resumen
*------------------------------------------------------------------------------*
display as text _n(2) "{hline 78}"
display as text "RESUMEN"
display as text "{hline 78}"
display as text "Completados:`ok_lista'"

if "`fallidas'" != "" {
    display as error "Con error: `fallidas'"
    display as text _n "El detalle del error esta en esta misma bitacora:"
    display as text "  `b3'/logs/master_boletin3_`marca'.log"
}
else {
    display as result "Todas las etapas solicitadas terminaron sin errores."
}

display as text _n "Salidas:"
display as text "  Graficos 1-8, Tablas  : 4. Resultados/informalidad"
display as text "  Graficos 9-11, series : 4. Resultados/pobreza laboral/corregido"
display as text "  Documento             : 5. Redacción/Boletin_3_automatizado.docx"

display as text _n "Fin: `c(current_date)' `c(current_time)'"
display as text "{hline 78}"

capture log close master3

*==============================================================================*
* CONSOLIDA EN UN SOLO LIBRO TODOS LOS EXCEL QUE GENERA EL MASTER
*
* Cada do-file del paper escribe su propio .xlsx en su carpeta. Este archivo
* junta todas esas hojas en un único libro:
*
*     $out/Iconos_resultados.xlsx
*
* Una hoja por tabla, con un prefijo que dice de qué módulo viene. La primera
* hoja se escribe con `replace` (crea el archivo) y el resto con `sheetreplace`,
* así que volver a correrlo regenera todo sin dejar hojas viejas.
*
* Se corre al final de master.do. También funciona suelto, siempre que los
* do-files ya hayan generado sus salidas.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}
if "$out" == "" global out "$gd/Papers/Íconos/outputs"

set more off
set varabbrev off

global libro "$out/Iconos_resultados.xlsx"

*------------------------------------------------------------------------------
* Carpetas de cada módulo. Se definen aparte porque algunas tienen espacios y
* eso rompe el troceo por palabras de un `foreach`.
*------------------------------------------------------------------------------
local d_des "$out/desigualdad"
local d_bre "$out/brechas"
local d_gin "$out/Gini"
local d_pri "$out/educ_ingrl"
local d_ade "$out/empleo adecuado"
local d_ram "$out/rama_educ"

*------------------------------------------------------------------------------
* Lista de trabajos: archivo de origen, hoja de origen, hoja de destino.
* Se usan locales numerados en vez de una lista suelta para que los nombres
* con espacios no se partan.
*------------------------------------------------------------------------------
local n = 0

* --- Gini y Palma (gini_palma_serie.do) ---------------------------------------
local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "gini"
local t`n' "gini_serie"

local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "palma"
local t`n' "palma_serie"

local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "detalle"
local t`n' "gini_palma_detalle"

* --- Brechas salariales (brechas_salariales.do) -------------------------------
local ++n
local f`n' "`d_bre'/brechas_salariales.xlsx"
local s`n' "brechas"
local t`n' "brechas"

* --- Descomposición del Gini (gini_decomp5.do) --------------------------------
local ++n
local f`n' "`d_gin'/gini_decomposition.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_nacional"

local ++n
local f`n' "`d_gin'/gini_decomposition_cuartiles.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_cuartiles"

local ++n
local f`n' "`d_gin'/gini_decomposition_quintiles.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_quintiles"

local ++n
local f`n' "`d_gin'/gini_decomposition_urbano.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_urbano"

local ++n
local f`n' "`d_gin'/Gini.xlsx"
local s`n' "Sheet1"
local t`n' "gini_decomp5_gini"

* --- Prima salarial por hora (educ_ingrl_hora.do) -----------------------------
local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "coeficientes"
local t`n' "prima_coeficientes"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "ancho_para_grafico"
local t`n' "prima_ancho"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "horas_y_muestra"
local t`n' "prima_horas_muestra"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "modelo_agrupado"
local t`n' "prima_modelo_agrupado"

* --- Empleo adecuado (empleo_adecuado_serie.do) -------------------------------
local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Serie"
local t`n' "adecuado_serie"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Diagnostico"
local t`n' "adecuado_diagnostico"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Sensibilidad"
local t`n' "adecuado_sensibilidad"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Umbrales"
local t`n' "adecuado_umbrales"

* --- Crecimiento del empleo por rama (empleo_calificados.do) ------------------
local ++n
local f`n' "`d_ram'/crecimiento_empleo.xlsx"
local s`n' "crec_2001_2010"
local t`n' "crec_2001_2010"

local ++n
local f`n' "`d_ram'/crecimiento_empleo.xlsx"
local s`n' "crec_2011_2024"
local t`n' "crec_2011_2024"

local ++n
local f`n' "`d_ram'/crecimiento_empleo.xlsx"
local s`n' "crec_2001_2024"
local t`n' "crec_2001_2024"

* --- Paneles de rama y educación (empleo_pleno_rama.do) -----------------------
local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_crecimiento"
local t`n' "panel_crecimiento"

local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_educ_pleno"
local t`n' "panel_educ_pleno"

*==============================================================================*
* CONSOLIDACIÓN
*==============================================================================*

local escritas = 0
local faltantes ""

forvalues i = 1/`n' {

    local arch "`f`i''"
    local hoja "`s`i''"
    local dest "`t`i''"

    capture confirm file "`arch'"
    if _rc {
        di as error "FALTA: `arch'"
        local faltantes "`faltantes' `dest'"
        continue
    }

    capture import excel "`arch'", sheet("`hoja'") firstrow clear
    if _rc {
        di as error "No se pudo leer `dest' (hoja `hoja' de `arch')"
        local faltantes "`faltantes' `dest'"
        continue
    }
    if (_N == 0) {
        di as error "`dest': hoja vacía, se omite"
        local faltantes "`faltantes' `dest'"
        continue
    }

    * La primera hoja crea el libro; las demás sólo reemplazan la suya.
    if (`escritas' == 0) {
        export excel using "$libro", sheet("`dest'") firstrow(variables) replace
    }
    else {
        export excel using "$libro", sheet("`dest'") firstrow(variables) sheetreplace
    }
    local ++escritas
    di as txt "  hoja `escritas': `dest'  (`=_N' filas)  <- `hoja'"
}

*------------------------------------------------------------------ índice ----
* Una hoja inicial que dice de dónde viene cada tabla.
clear
set obs `n'
gen int    orden  = _n
gen str60  hoja   = ""
gen str90  origen = ""
gen str40  modulo = ""

forvalues i = 1/`n' {
    local arch "`f`i''"
    replace hoja   = "`t`i''"                     in `i'
    replace origen = "`=substr("`arch'", strrpos("`arch'", "/") + 1, .)'" in `i'
    replace modulo = "`=substr("`arch'", 1, strrpos("`arch'", "/") - 1)'" in `i'
}
replace modulo = substr(modulo, strrpos(modulo, "/") + 1, .)

label var orden  "#"
label var hoja   "Hoja en este libro"
label var origen "Archivo de origen"
label var modulo "Carpeta / módulo"

if (`escritas' > 0) {
    export excel using "$libro", sheet("00_indice") firstrow(varlabels) sheetreplace
}

di as res _n "{hline 78}"
di as res "Libro consolidado: $libro"
di as res "Hojas escritas: `escritas' de `n'"
if ("`faltantes'" != "") di as err "Sin escribir:`faltantes'"
di as res "{hline 78}"

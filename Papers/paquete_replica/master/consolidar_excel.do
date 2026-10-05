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
local d_gic "$out/GIC"

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

* --- Paneles de rama y educación (empleo_pleno_rama.do) -----------------------
local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_crecimiento"
local t`n' "panel_crecimiento"

local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_educ_pleno"
local t`n' "panel_educ_pleno"

* --- Curvas de incidencia del crecimiento (gic_paper.do) ----------------------
local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_urbano"
local t`n' "gic_urbano"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_nacional"
local t`n' "gic_nacional"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_ref"
local t`n' "gic_referencias"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_largo"
local t`n' "gic_largo"

*==============================================================================*
* CONSOLIDACIÓN
*==============================================================================*

* Stata no logra abrir ni escribir .xlsx directamente sobre la carpeta de
* Google Drive (r(603): "could not be loaded"). Por eso cada archivo de
* origen se copia primero a disco local, el libro se arma también en local y
* recién al final se copia a su lugar en el Drive.
tempfile tsrc tlib
local origen_loc "`tsrc'.xlsx"
local libro_loc  "`tlib'.xlsx"

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

    capture copy "`arch'" "`origen_loc'", replace
    if _rc {
        di as error "No se pudo copiar `arch'"
        local faltantes "`faltantes' `dest'"
        continue
    }

    capture import excel "`origen_loc'", sheet("`hoja'") firstrow clear
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
        export excel using "`libro_loc'", sheet("`dest'") firstrow(variables) replace
    }
    else {
        export excel using "`libro_loc'", sheet("`dest'") firstrow(variables) sheetreplace
    }
    local ++escritas
    di as txt "  hoja `escritas': `dest'  (`=_N' filas)  <- `hoja'"
}

*------------------------------------------------------------------------------
* Crecimiento del empleo por rama y nivel educativo (Gráficos 14, 15 y 16)
*
* Los cuatro períodos salen del MISMO libro, el de empleo_pleno_rama.do, que
* usa el empleo adecuado armonizado y cubre 1992-1999, 2001-2010, 2011-2024 y
* 2001-2024. Antes tres de ellos venían de empleo_calificados.do, que parte por
* "universitaria" en vez de "superior" y da otros números: mezclarlos hacía que
* los gráficos no fueran comparables entre sí.
*
* El gemelo empleo_pleno_rama_condact.do escribe un libro igual pero con la
* definición oficial de empleo pleno (condact == 1), que no es comparable a lo
* largo del período. Sirve para cotejar, no para estos gráficos.
*
* La hoja de origen trae todas las ramas y una columna por concepto. Aquí se
* recorta a las cinco ramas de las barras (CIIU 1, 3, 6, 7 y 9) y se le da la
* forma de tres columnas que espera la macro de gráficos.
*
* En 1992-1999 la ENEMDU de diciembre es sólo urbana, que es el ámbito que
* pide el pie del Gráfico 14.
*------------------------------------------------------------------------------

local crec_arch "$out/rama_educ/nacional/tablas_rama_educ.xlsx"
local crec_pares "1992_1999 2001_2010 2011_2024 2001_2024"
local crec_hojas ""

capture confirm file "`crec_arch'"
if _rc {
    di as error "FALTA: `crec_arch' (lo genera empleo_pleno_rama.do)"
    foreach par of local crec_pares {
        local faltantes "`faltantes' crec_`par'"
    }
}
else {
    capture copy "`crec_arch'" "`origen_loc'", replace

    foreach par of local crec_pares {

        capture import excel "`origen_loc'", sheet("crecimiento_`par'") firstrow clear
        if _rc | _N == 0 {
            di as error "No se pudo leer crecimiento_`par' de `crec_arch'"
            local faltantes "`faltantes' crec_`par'"
            continue
        }

        * Columnas por posición, porque los encabezados son las etiquetas de
        * variable: 1 código, 2 rama, 6 variación con superior, 7 sin superior.
        unab todas : _all
        local v_cod  : word 1 of `todas'
        local v_rama : word 2 of `todas'
        local v_uni  : word 6 of `todas'
        local v_nou  : word 7 of `todas'

        keep `v_cod' `v_rama' `v_uni' `v_nou'
        capture confirm numeric variable `v_cod'
        if _rc destring `v_cod', replace force
        keep if inlist(`v_cod', 1, 3, 6, 7, 9)

        rename `v_rama' rama_nombre
        rename `v_uni'  uni_crec_`par'
        rename `v_nou'  nouni_crec_`par'
        keep  rama_nombre uni_crec_`par' nouni_crec_`par'
        order rama_nombre uni_crec_`par' nouni_crec_`par'
        sort rama_nombre

        if (_N == 0) {
            di as error "crec_`par': ninguna de las cinco ramas sobrevivió"
            local faltantes "`faltantes' crec_`par'"
            continue
        }

        if (`escritas' == 0) export excel using "`libro_loc'", ///
            sheet("crec_`par'") firstrow(variables) replace
        else export excel using "`libro_loc'", ///
            sheet("crec_`par'") firstrow(variables) sheetreplace

        local ++escritas
        local crec_hojas "`crec_hojas' crec_`par'"
        di as txt "  hoja `escritas': crec_`par'  (`=_N' filas)  <- crecimiento_`par'"
    }
}

*------------------------------------------------------------------ índice ----
* Una hoja inicial que dice de dónde viene cada tabla.
clear
local n_extra : word count `crec_hojas'
local n_idx = `n' + `n_extra'
set obs `n_idx'
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

local i = `n'
foreach h of local crec_hojas {
    local ++i
    replace hoja   = "`h'"                                       in `i'
    replace origen = "tablas_rama_educ.xlsx"                     in `i'
    replace modulo = "rama_educ/nacional"                        in `i'
}

label var orden  "#"
label var hoja   "Hoja en este libro"
label var origen "Archivo de origen"
label var modulo "Carpeta / módulo"

if (`escritas' > 0) {
    export excel using "`libro_loc'", sheet("00_indice") firstrow(varlabels) sheetreplace
    copy "`libro_loc'" "$libro", replace
}

di as res _n "{hline 78}"
di as res "Libro consolidado: $libro"
di as res "Hojas escritas: `escritas' de `=`n' + 4'"
if ("`faltantes'" != "") di as err "Sin escribir:`faltantes'"
di as res "{hline 78}"

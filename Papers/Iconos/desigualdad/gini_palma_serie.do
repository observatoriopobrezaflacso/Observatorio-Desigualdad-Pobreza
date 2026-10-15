*==============================================================================*
* SERIE DEL COEFICIENTE DE GINI Y DEL ÍNDICE DE PALMA
* ENEMDU de diciembre, ingreso per cápita del hogar. Urbano y nacional.
*
* Alimenta las hojas gini_serie y palma_serie de Iconos_resultados.xlsx (las
* arma consolidar_excel.do), que dibujan los Gráficos 1, 2 y 3 del paper.
* El pie del Gráfico 3 cita CEPALSTAT; éste es el Palma calculado sobre la
* ENEMDU, que da valores más bajos (ver la sección 6 de master.do).
*
* Método (el mismo de los Ineq_<año>.do e Ind_<año>.do del Boletín 1):
*   Gini  : ineqdeco sobre el ingreso per cápita del hogar, ponderado por fexp.
*   Palma : deciles ponderados de personas según ingreso per cápita; razón entre
*           el ingreso total del decil 10 y el de los deciles 1 a 4.
*
* Fuente: Bases/ENEMDU/Procesadas/ingresos_pc/{Urbano,Nacional}
* Requiere: ineqdeco  (ssc install ineqdeco)
*
* COMPARACIÓN: al final compara con gini_serie y palma_serie de la última
* corrida (Iconos_resultados.xlsx), para ver qué cambió.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off
set varabbrev off

global urb "$gd/Bases/ENEMDU/Procesadas/ingresos_pc/Urbano"
global nac "$gd/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
global gini_out "$gd/Papers/Íconos/outputs/desigualdad"

capture mkdir "$gd/Papers/Íconos/outputs"
capture mkdir "$gini_out"

capture which ineqdeco
if _rc {
    di as error "Falta el comando ineqdeco. Instalar con: ssc install ineqdeco"
    exit 111
}

*==============================================================================*
* 1. CÁLCULO POR AÑO Y ÁMBITO
*==============================================================================*

tempname pf
tempfile res
postfile `pf' byte ambito int anio double(gini palma p_top10 p_bot40 N) ///
    using "`res'", replace

foreach amb in urb nac {

    if ("`amb'" == "urb") {
        local dir "$urb"
        local a   2
    }
    else {
        local dir "$nac"
        local a   1
    }

    forvalues y = 1991/2025 {

        local f "`dir'/ing_perca_`y'_`amb'_precios2000.dta"
        capture confirm file "`f'"
        if _rc continue

        qui describe using "`f'", varlist
        local vl = r(varlist)

        * ingpc existe desde 2007; antes se usa ingtot_per. Son la misma
        * definición (ingreso total del hogar dividido para sus miembros).
        local hasingpc : list posof "ingpc" in vl
        if (`hasingpc') local iv ingpc
        else            local iv ingtot_per

        * Las bases viven en Google Drive y a veces la lectura falla con un
        * error de E/S transitorio. Se reintenta un par de veces antes de
        * darse por vencido con ese año.
        local ok = 0
        forvalues intento = 1/3 {
            if (`ok' == 0) {
                capture qui use `iv' fexp using "`f'", clear
                if (_rc == 0) local ok = 1
                else di as error "  lectura fallida (`amb' `y', intento `intento', _rc=`=_rc')"
            }
        }
        if (`ok' == 0) {
            di as error "OMITIDO `amb' `y': no se pudo leer la base"
            continue
        }
        qui keep if !missing(`iv') & !missing(fexp) & fexp > 0

        *------------------------------------------------------------- Gini --
        qui ineqdeco `iv' [w=fexp]
        local g = r(gini)
        local n = r(N)

        *------------------------------------------------------------ Palma --
        qui xtile decil = `iv' [pw=fexp], n(10)
        qui collapse (sum) `iv' [pw=fexp], by(decil)
        qui egen double tot = total(`iv')
        qui su `iv' if decil == 10
        local top = r(mean)
        qui su `iv' if decil <= 4
        local bot = r(sum)
        qui su tot in 1
        local t = r(mean)

        post `pf' (`a') (`y') (`g') (`top'/`bot') (100*`top'/`t') ///
            (100*`bot'/`t') (`n')

        di as txt "`amb' `y': gini=" %6.4f `g' "  palma=" %6.4f `top'/`bot' ///
            "  (`iv', N=`n')"
    }
}
postclose `pf'

*==============================================================================*
* 2. TABLA
*==============================================================================*

use "`res'", clear
label define lbl_amb 1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb

label var anio    "Año"
label var gini    "Coeficiente de Gini"
label var palma   "Índice de Palma (decil 10 / deciles 1-4)"
label var p_top10 "% del ingreso en el decil 10"
label var p_bot40 "% del ingreso en los deciles 1 a 4"
label var N       "Observaciones"

format gini %6.4f
format palma %7.4f
format p_top10 p_bot40 %6.2f

sort ambito anio
list, sepby(ambito) noobs

save "$gini_out/gini_palma_serie.dta", replace

*--- formato ancho, igual que la hoja "gini" del libro -------------------------
preserve
    keep ambito anio gini
    decode ambito, gen(amb)
    drop ambito
    reshape wide gini, i(anio) j(amb) string
    rename giniUrbano   gini_urb
    rename giniNacional gini_nac
    label var anio     "Año"
    label var gini_urb "Gini urbano"
    label var gini_nac "Gini nacional"
    order anio gini_urb gini_nac
    sort anio
    export excel using "$gini_out/gini_palma_tablas.xlsx", ///
        sheet("gini") firstrow(varlabels) replace
restore

*--- formato ancho de Palma ---------------------------------------------------
preserve
    keep ambito anio palma
    decode ambito, gen(amb)
    drop ambito
    reshape wide palma, i(anio) j(amb) string
    rename palmaUrbano   palma_urb
    rename palmaNacional palma_nac
    label var anio      "Año"
    label var palma_urb "Palma urbano"
    label var palma_nac "Palma nacional"
    order anio palma_urb palma_nac
    sort anio
    export excel using "$gini_out/gini_palma_tablas.xlsx", ///
        sheet("palma") firstrow(varlabels) sheetreplace
restore

*--- detalle largo ------------------------------------------------------------
preserve
    decode ambito, gen(amb)
    drop ambito
    rename amb ambito
    label var ambito "Ámbito"
    order ambito anio gini palma p_top10 p_bot40 N
    export excel using "$gini_out/gini_palma_tablas.xlsx", ///
        sheet("detalle") firstrow(varlabels) sheetreplace
restore

*==============================================================================*
* 3. COMPARACIÓN CON LA ÚLTIMA CORRIDA
*
* Compara el Gini y el Palma con las hojas gini_serie y palma_serie de
* Iconos_resultados.xlsx, el libro que armó consolidar_excel.do en la corrida
* anterior del master. No es una validación contra una fuente externa: sirve
* para ver qué años cambiaron desde la última vez. Si el libro no existe, se
* omite.
*==============================================================================*

di as res _n "{hline 78}"
di as res "COMPARACIÓN — gini_serie y palma_serie de Iconos_resultados.xlsx"
di as res "{hline 78}"

local libro "$gd/Papers/Íconos/outputs/Iconos_resultados.xlsx"
capture confirm file "`libro'"
if _rc di as txt "No existe `libro': se omite la comparación."
else {
    * Stata no abre .xlsx directamente sobre Google Drive (r(603)): se copia a
    * disco local primero, igual que en consolidar_excel.do.
    tempfile tlib
    local libro_loc "`tlib'.xlsx"
    qui copy "`libro'" "`libro_loc'", replace

    * formato ancho de esta corrida: anio gini_urb gini_nac palma_urb palma_nac
    use "$gini_out/gini_palma_serie.dta", clear
    keep ambito anio gini palma
    qui reshape wide gini palma, i(anio) j(ambito)
    rename (gini1 gini2 palma1 palma2) (gini_nac gini_urb palma_nac palma_urb)
    tempfile act
    qui save `act'

    foreach m in gini palma {
        di as txt _n "--- `m'"
        capture import excel "`libro_loc'", sheet("`m'_serie") firstrow clear
        if _rc {
            di as txt "El libro no tiene la hoja '`m'_serie': se omite."
            continue
        }
        * columnas por posición: 1 año, 2 urbano, 3 nacional
        unab todas : _all
        local va : word 1 of `todas'
        local vu : word 2 of `todas'
        local vn : word 3 of `todas'
        keep `va' `vu' `vn'
        rename (`va' `vu' `vn') (anio `m'_urb_ant `m'_nac_ant)
        qui merge 1:1 anio using `act', keepusing(`m'_urb `m'_nac)

        gen double dmax = 0
        foreach a in urb nac {
            qui replace dmax = max(dmax, abs(`m'_`a' - `m'_`a'_ant)) ///
                if _merge == 3 & !missing(`m'_`a', `m'_`a'_ant)
        }
        format `m'_* %7.4f

        qui count if (_merge == 3 & dmax > 0.0005) | _merge != 3
        if (r(N) == 0) di as txt "Sin cambios en ningún año."
        else {
            list anio `m'_urb `m'_urb_ant `m'_nac `m'_nac_ant _merge ///
                 if (_merge == 3 & dmax > 0.0005) | _merge != 3, noobs sep(0)
            di as txt "_merge: 1 = sólo en la anterior, 2 = sólo en esta corrida."
        }
    }
}

di as res _n "Salidas en: $gini_out"

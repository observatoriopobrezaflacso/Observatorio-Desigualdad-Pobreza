*==============================================================================*
* SERIE DEL COEFICIENTE DE GINI Y DEL ÍNDICE DE PALMA
* ENEMDU de diciembre, ingreso per cápita del hogar. Urbano y nacional.
*
* Alimenta las hojas "gini" y "palma" del libro plots_sources_graficos.xlsx
* (Gráficos 1, 2 y 3 del paper).
*
* Método (el mismo de los Ineq_<año>.do e Ind_<año>.do del Boletín 1):
*   Gini  : ineqdeco sobre el ingreso per cápita del hogar, ponderado por fexp.
*   Palma : deciles ponderados de personas según ingreso per cápita; razón entre
*           el ingreso total del decil 10 y el de los deciles 1 a 4.
*
* Fuente: Bases/ENEMDU/Procesadas/ingresos_pc/{Urbano,Nacional}
* Requiere: ineqdeco  (ssc install ineqdeco)
*
* VALIDACIÓN: al final compara contra los valores que ya están en el libro.
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
global out "$gd/Papers/Íconos/outputs/desigualdad"

capture mkdir "$gd/Papers/Íconos/outputs"
capture mkdir "$out"

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

save "$out/gini_palma_serie.dta", replace

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
    export excel using "$out/gini_palma_tablas.xlsx", ///
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
    export excel using "$out/gini_palma_tablas.xlsx", ///
        sheet("palma") firstrow(varlabels) sheetreplace
restore

*--- detalle largo ------------------------------------------------------------
preserve
    decode ambito, gen(amb)
    drop ambito
    rename amb ambito
    label var ambito "Ámbito"
    order ambito anio gini palma p_top10 p_bot40 N
    export excel using "$out/gini_palma_tablas.xlsx", ///
        sheet("detalle") firstrow(varlabels) sheetreplace
restore

*==============================================================================*
* 3. VALIDACIÓN CONTRA EL LIBRO DE GRÁFICOS
*
* Se comparan los años de referencia con lo que hoy está en las hojas "gini" y
* "palma" de plots_sources_graficos.xlsx.
*==============================================================================*

di as res _n "{hline 78}"
di as res "VALIDACIÓN — Gini contra la hoja del libro"
di as res "{hline 78}"

use "$out/gini_palma_serie.dta", clear

* valores de la hoja "gini" del libro
matrix REF = (2001, .575, .581 \ 2003, .538, .5586 \ 2005, .524, .548 \ ///
              2011, .4413, .4732 \ 2013, .4708, .485 \ 2017, .4349, .4593 \ ///
              2021, .4655, .486)

di as txt "  año    urb calc   urb libro    dif  |  nac calc   nac libro    dif"
forvalues i = 1/`=rowsof(REF)' {
    local y  = REF[`i',1]
    local ru = REF[`i',2]
    local rn = REF[`i',3]
    qui su gini if anio==`y' & ambito==2
    local cu = cond(r(N)>0, r(mean), .)
    qui su gini if anio==`y' & ambito==1
    local cn = cond(r(N)>0, r(mean), .)
    di as txt "  " %4.0f `y' "  " %8.4f `cu' "  " %8.4f `ru' "  " %6.4f `cu'-`ru' ///
        "  |" %8.4f `cn' "  " %8.4f `rn' "  " %6.4f `cn'-`rn'
}

di as txt _n "Nota: el pie del Gráfico 1 del paper dice que desde 2007 la serie"
di as txt "del libro reporta el valor publicado por el INEC, no el calculado."
di as txt "En esos años la diferencia con este do-file es esperable."

di as res _n "{hline 78}"
di as res "VALIDACIÓN — Palma contra la hoja del libro"
di as res "{hline 78}"

matrix REFP = (2001, 5.61162 \ 2005, 4.28376 \ 2011, 2.87698 \ ///
               2017, 2.60470 \ 2021, 2.80963 \ 2025, 2.72712)

di as txt "  año   palma nac   palma urb   libro"
forvalues i = 1/`=rowsof(REFP)' {
    local y = REFP[`i',1]
    local r = REFP[`i',2]
    qui su palma if anio==`y' & ambito==1
    local cn = cond(r(N)>0, r(mean), .)
    qui su palma if anio==`y' & ambito==2
    local cu = cond(r(N)>0, r(mean), .)
    di as txt "  " %4.0f `y' "  " %9.4f `cn' "  " %9.4f `cu' "  " %9.4f `r'
}

di as err _n "ATENCIÓN: la hoja 'palma' del libro NO se reproduce con este"
di as err "cálculo. El pie del Gráfico 3 del paper cita CEPALSTAT como fuente,"
di as err "así que esa serie probablemente no sale de las bases ENEMDU."
di as err "Los valores de este do-file son el Palma calculado sobre la ENEMDU."

di as res _n "Salidas en: $out"

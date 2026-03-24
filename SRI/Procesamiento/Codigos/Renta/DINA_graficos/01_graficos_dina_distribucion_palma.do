/*******************************************************************************
* Graficos DINA: participacion del ingreso e indice de Palma
*
* Fuente:
*   Tablas_DINA_dec_corr.xlsx (Resultados/20.03.2026)
*
* Graficos:
*   1. Participacion del 0.1% superior, 1% superior, 10% superior,
*      40% medio (P50-P90), 35% inferior y 50% inferior en el ingreso
*      nacional (PreTaxHHI).
*   2. Indice de Palma antes de tributacion (PreTaxHHI) y despues de
*      tributacion (PostTaxHHI).
*   3. Concentracion del ingreso de capital (hoja capital): Top 0,1%,
*      Top 1%, Top 10% y 50% inferior (misma disposicion de columnas que PreTaxHHI).
*
* Nota:
*   El archivo fuente entregado contiene serie 2010-2024 para estas hojas.
*******************************************************************************/

clear all
set more off
version 16.0

* ---------------------------------------------------------------------------
* 0. Rutas
* ---------------------------------------------------------------------------

global repo_dir "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
global code_dir "$repo_dir/SRI/Procesamiento/Codigos/Renta/DINA_graficos"
global out_dir  "$repo_dir/SRI/Procesamiento/Resultados/DINA_graficos"

local input_excel "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/SRI 11.05.16 p. m./Resultados/20.03.2026/Tablas_DINA_dec_corr.xlsx"

capture mkdir "$out_dir"

tempfile pretax posttax graf_data

* ---------------------------------------------------------------------------
* 1. Hoja PreTaxHHI: participaciones y Palma antes de tributacion
*    Se importan por letra de columna para evitar problemas con nombres largos
*    N por grupo: E P999-P100, M Top 1%, AC Top 10%, AK P50-P90, BY P1-P35, BI 50% inferior
* ---------------------------------------------------------------------------

import excel using "`input_excel'", sheet("PreTaxHHI") clear

rename A  anio
rename G  share_top01
rename O  share_top1
rename AE share_top10
rename AM share_middle40
rename BS share_bot40
rename CA share_bottom35
rename BK share_bottom50
rename E  N_top01
rename M  N_top1
rename AC N_top10
rename AK N_mid40
rename BY N_bot35
rename BI N_bot50

drop in 1
keep anio share_top01 share_top1 share_top10 share_middle40 share_bot40 share_bottom35 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot35 N_bot50

destring anio share_top01 share_top1 share_top10 share_middle40 share_bot40 share_bottom35 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot35 N_bot50, replace force
drop if missing(anio)

* Palma grafico 2: 10% superior vs 40% inferior (P1-P40, % del total)
gen palma_pretax = share_top10 / share_bot40

label var share_top01    "Top 0.1%"
label var share_top1     "Top 1%"
label var share_top10    "Top 10%"
label var share_middle40 "Clase media (P50-P90)"
label var share_bottom35 "35% más pobre"
label var share_bottom50 "50% más pobre"
label var palma_pretax   "Palma antes de tributacion"

sort anio
save "`pretax'", replace

* ---------------------------------------------------------------------------
* 2. Hoja PostTaxHHI: Palma despues de tributacion
* ---------------------------------------------------------------------------

import excel using "`input_excel'", sheet("PostTaxHHI") clear

rename A  anio
rename AE share_top10_post
rename BS share_bot40_post

drop in 1
keep anio share_top10_post share_bot40_post

destring anio share_top10_post share_bot40_post, replace force
drop if missing(anio)

gen palma_posttax = share_top10_post / share_bot40_post
label var palma_posttax "Palma despues de tributacion"

sort anio
save "`posttax'", replace

* ---------------------------------------------------------------------------
* 3. Base final para graficos
* ---------------------------------------------------------------------------

use "`pretax'", clear
merge 1:1 anio using "`posttax'", nogen
sort anio

save "`graf_data'", replace
save "$out_dir/serie_graficos_dina_2010_2024.dta", replace
export excel using "$out_dir/serie_graficos_dina_2010_2024.xlsx", ///
    firstrow(varlabels) replace

quietly summarize anio, meanonly
local xmin = r(min)
local xmax = r(max)

* Etiquetas grafico 1: solo 2010 2015 2020 2024, sin decimales
foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 {
    gen str12 lab_`v' = ""
    replace lab_`v' = trim(string(`v', "%9.1f")) if inlist(anio, 2010, 2015, 2020, 2024)
}

* Posiciones por parejas que se cruzan: mayor participacion -> etiqueta arriba (12), menor -> abajo (6)
foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 {
    gen byte pos_`v' = .
}

* Top 0.1% vs 35% inferior
replace pos_share_top01    = 12 if share_top01    >= share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_bottom35 = 6  if share_top01    >= share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_top01    = 6  if share_top01    <  share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_bottom35 = 12 if share_top01    <  share_bottom35 & share_top01 < . & share_bottom35 < .

* Top 1% vs 50% inferior
replace pos_share_top1     = 12 if share_top1     >= share_bottom50 & share_top1 < . & share_bottom50 < .
replace pos_share_bottom50 = 6  if share_top1     >= share_bottom50 & share_top1 < . & share_bottom50 < .
replace pos_share_top1     = 6  if share_top1     <  share_bottom50 & share_top1 < . & share_bottom50 < .
replace pos_share_bottom50 = 12 if share_top1     <  share_bottom50 & share_top1 < . & share_bottom50 < .

* Top 10% vs clase media (P50-P90)
replace pos_share_top10    = 12 if share_top10    >= share_middle40 & share_top10 < . & share_middle40 < .
replace pos_share_middle40 = 6  if share_top10    >= share_middle40 & share_top10 < . & share_middle40 < .
replace pos_share_top10    = 6  if share_top10    <  share_middle40 & share_top10 < . & share_middle40 < .
replace pos_share_middle40 = 12 if share_top10    <  share_middle40 & share_top10 < . & share_middle40 < .

* Leyenda: N personas por grupo (año `xmax'); >= 1M -> "mill.", si no -> "mil"
local rem "top01 N_top01 top1 N_top1 top10 N_top10 mid40 N_mid40 bot35 N_bot35 bot50 N_bot50"
while "`rem'" != "" {
    gettoken tag rem : rem
    gettoken var rem : rem
    quietly summarize `var' if anio == `xmax', meanonly
    local pop_`tag' ""
    if r(N) > 0 & !missing(r(mean)) {
        local vv = r(mean)
        if `vv' >= 1000000 {
            local pop_`tag' = trim(string(`vv'/1000000, "%9.2f")) + " mill."
        }
        else {
            local pop_`tag' = trim(string(`vv'/1000, "%9.1f")) + " mil"
        }
    }
}

if "`pop_top01'" != "" local leg_top01 `"Top 0.1% (`pop_top01')"'
else local leg_top01 "Top 0.1%"
if "`pop_top1'" != "" local leg_top1 `"Top 1% (`pop_top1')"'
else local leg_top1 "Top 1%"
if "`pop_top10'" != "" local leg_top10 `"Top 10% (`pop_top10')"'
else local leg_top10 "Top 10%"
if "`pop_mid40'" != "" local leg_mid40 `"Clase media (P50-P90) (`pop_mid40')"'
else local leg_mid40 "Clase media (P50-P90)"
if "`pop_bot35'" != "" local leg_bot35 `"35% más pobre (`pop_bot35')"'
else local leg_bot35 "35% más pobre"
if "`pop_bot50'" != "" local leg_bot50 `"50% más pobre (`pop_bot50')"'
else local leg_bot50 "50% más pobre"

* ---------------------------------------------------------------------------
* 4. Grafico 1: participacion en el ingreso nacional
* ---------------------------------------------------------------------------

twoway ///
    (connected share_top01 anio, sort lcolor("106 61 154") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("106 61 154") ///
        mlabel(lab_share_top01) mlabcolor("106 61 154") mlabsize(small) mlabvposition(pos_share_top01)) ///
    (connected share_top1 anio, sort lcolor("163 29 33")  lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("163 29 33") ///
        mlabel(lab_share_top1) mlabcolor("163 29 33") mlabsize(small) mlabvposition(pos_share_top1)) ///
    (connected share_top10 anio, sort lcolor("233 127 2") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("233 127 2") ///
        mlabel(lab_share_top10) mlabcolor("233 127 2") mlabsize(small) mlabvposition(pos_share_top10)) ///
    (connected share_middle40 anio, sort lcolor("31 120 180") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("31 120 180") ///
        mlabel(lab_share_middle40) mlabcolor("31 120 180") mlabsize(small) mlabvposition(pos_share_middle40)) ///
    (connected share_bottom35 anio, sort lcolor("27 158 119") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("27 158 119") ///
        mlabel(lab_share_bottom35) mlabcolor("27 158 119") mlabsize(small) mlabvposition(pos_share_bottom35)) ///
    (connected share_bottom50 anio, sort lcolor("51 160 44") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("51 160 44") ///
        mlabel(lab_share_bottom50) mlabcolor("51 160 44") mlabsize(small) mlabvposition(pos_share_bottom50)), ///
    title("Participación en el ingreso nacional", size(medium)) ///
    subtitle("PreTaxHHI", size(small)) ///
    ytitle("Porcentaje del ingreso nacional") ///
    xtitle("") ///
    xlabel(`xmin'(1)`xmax', angle(45)) ///
    ylabel(, angle(horizontal) format(%9.0g)) ///
    legend(order(1 "`leg_top01'" 2 "`leg_top1'" 3 "`leg_top10'" 4 "`leg_mid40'" 5 "`leg_bot35'" 6 "`leg_bot50'") ///
           rows(3) position(6) span size(small) region(lcolor(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) 
	
capture noisily graph export "$out_dir/participacion_ingreso_pretax_2010_2024.png", ///
    replace width(2400)
graph export "$out_dir/participacion_ingreso_pretax_2010_2024.pdf", replace
graph save "$out_dir/participacion_ingreso_pretax_2010_2024.gph", replace

* ---------------------------------------------------------------------------
* 5. Grafico 2: indice de Palma antes y despues de tributacion
* ---------------------------------------------------------------------------

* Create label variables (only for selected years)
capture drop lab_palma_pretax lab_palma_posttax
capture drop pos_palma_pretax pos_palma_posttax

gen lab_palma_pretax  = ""
gen lab_palma_posttax = ""

replace lab_palma_pretax  = string(palma_pretax,  "%4.1f") if inlist(anio, 2010, 2015, 2020, 2024)
replace lab_palma_posttax = string(palma_posttax, "%4.1f") if inlist(anio, 2010, 2015, 2020, 2024)

gen pos_palma_pretax  = 12
gen pos_palma_posttax = 6

twoway ///
    (connected palma_pretax anio, sort lcolor("163 29 33") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("163 29 33") ///
        mlabel(lab_palma_pretax) mlabcolor("163 29 33") mlabsize(vsmall) mlabvposition(pos_palma_pretax)) ///
    (connected palma_posttax anio, sort lcolor("31 120 180") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("31 120 180") ///
        mlabel(lab_palma_posttax) mlabcolor("31 120 180") mlabsize(vsmall) mlabvposition(pos_palma_posttax)), ///
    title("Número de veces que el ingreso del 10% más rico supera al del 40% más pobre", size(medium)) ///
    subtitle("Antes y despues de tributacion", size(small)) ///
    xtitle("") ///
    xlabel(`xmin'(1)`xmax', angle(45)) ///
    ylabel(0(1)5, angle(horizontal) format(%9.0f)) ///
    yscale(range(0 5)) ///
    legend(order(1 "Antes de tributacion" 2 "Despues de tributacion") ///
           rows(1) position(6) span size(small) region(lcolor(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white))

capture noisily graph export "$out_dir/palma_pretax_posttax_2010_2024.png", ///
    replace width(2400)
graph export "$out_dir/palma_pretax_posttax_2010_2024.pdf", replace
graph save "$out_dir/palma_pretax_posttax_2010_2024.gph", replace

* ---------------------------------------------------------------------------
* 6. Grafico 3: concentracion del ingreso de capital (hoja capital)
*    Solo Top 0,1%, Top 1%, Top 10% y 50% inferior. Columnas alineadas con PreTaxHHI.
* ---------------------------------------------------------------------------

preserve

import excel using "`input_excel'", sheet("capital") clear

rename A  anio
rename G  share_cap_top01
rename O  share_cap_top1
rename AE share_cap_top10
rename BK share_cap_bot50
rename E  N_cap_top01
rename M  N_cap_top1
rename AC N_cap_top10
rename BI N_cap_bot50

drop in 1
keep anio share_cap_top01 share_cap_top1 share_cap_top10 share_cap_bot50 ///
    N_cap_top01 N_cap_top1 N_cap_top10 N_cap_bot50

destring anio share_cap_top01 share_cap_top1 share_cap_top10 share_cap_bot50 ///
    N_cap_top01 N_cap_top1 N_cap_top10 N_cap_bot50, replace force
drop if missing(anio)

label var share_cap_top01  "Top 0,1% (0,1% superior)"
label var share_cap_top1   "Top 1% (1% superior)"
label var share_cap_top10  "Top 10% (10% superior)"
label var share_cap_bot50  "50% inferior (50% inferior)"

quietly summarize anio, meanonly
local xmax_cap = r(max)

foreach v in share_cap_top01 share_cap_top1 share_cap_top10 share_cap_bot50 {
    gen str12 lab_`v' = ""
    replace lab_`v' = trim(string(`v', "%9.1f")) if inlist(anio, 2010, 2015, 2020, 2024)
}

foreach v in share_cap_top01 share_cap_top1 share_cap_top10 share_cap_bot50 {
    gen byte pos_`v' = .
}

* Etiquetas: colocacion arriba/abajo segun si cada serie supera al 50% inferior;
*   la linea 50% inferior se contrasta con el 0,1% superior para evitar solapamientos.
replace pos_share_cap_top01  = 12 if share_cap_top01 >= share_cap_bot50 & share_cap_top01 < . & share_cap_bot50 < .
replace pos_share_cap_top01  = 6  if share_cap_top01 <  share_cap_bot50 & share_cap_top01 < . & share_cap_bot50 < .
replace pos_share_cap_top1   = 12 if share_cap_top1  >= share_cap_bot50 & share_cap_top1  < . & share_cap_bot50 < .
replace pos_share_cap_top1   = 6  if share_cap_top1  <  share_cap_bot50 & share_cap_top1  < . & share_cap_bot50 < .
replace pos_share_cap_top10  = 12 if share_cap_top10 >= share_cap_bot50 & share_cap_top10 < . & share_cap_bot50 < .
replace pos_share_cap_top10  = 6  if share_cap_top10 <  share_cap_bot50 & share_cap_top10 < . & share_cap_bot50 < .
replace pos_share_cap_bot50  = 6  if share_cap_top01 >= share_cap_bot50 & share_cap_top01 < . & share_cap_bot50 < .
replace pos_share_cap_bot50  = 12 if share_cap_top01 <  share_cap_bot50 & share_cap_top01 < . & share_cap_bot50 < .

* Leyenda con N en el ultimo año (misma regla que grafico 1)
local rem "top01 N_cap_top01 top1 N_cap_top1 top10 N_cap_top10 bot50 N_cap_bot50"
while "`rem'" != "" {
    gettoken tag rem : rem
    gettoken var rem : rem
    quietly summarize `var' if anio == `xmax_cap', meanonly
    local pop_cap_`tag' ""
    if r(N) > 0 & !missing(r(mean)) {
        local vv = r(mean)
        if `vv' >= 1000000 {
            local pop_cap_`tag' = trim(string(`vv'/1000000, "%9.2f")) + " mill."
        }
        else {
            local pop_cap_`tag' = trim(string(`vv'/1000, "%9.1f")) + " mil"
        }
    }
}

if "`pop_cap_top01'" != "" local leg_cap_top01 `"Top 0,1% (`pop_cap_top01')"'
else local leg_cap_top01 "Top 0,1% (0,1% superior)"
if "`pop_cap_top1'" != "" local leg_cap_top1 `"Top 1% (`pop_cap_top1')"'
else local leg_cap_top1 "Top 1% (1% superior)"
if "`pop_cap_top10'" != "" local leg_cap_top10 `"Top 10% (`pop_cap_top10')"'
else local leg_cap_top10 "Top 10% (10% superior)"
if "`pop_cap_bot50'" != "" local leg_cap_bot50 `"50% inferior (`pop_cap_bot50')"'
else local leg_cap_bot50 "50% inferior (50% inferior)"

twoway ///
    (connected share_cap_top01 anio, sort lcolor("106 61 154") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("106 61 154") ///
        mlabel(lab_share_cap_top01) mlabcolor("106 61 154") mlabsize(small) mlabvposition(pos_share_cap_top01)) ///
    (connected share_cap_top1 anio, sort lcolor("163 29 33") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("163 29 33") ///
        mlabel(lab_share_cap_top1) mlabcolor("163 29 33") mlabsize(small) mlabvposition(pos_share_cap_top1)) ///
    (connected share_cap_top10 anio, sort lcolor("233 127 2") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("233 127 2") ///
        mlabel(lab_share_cap_top10) mlabcolor("233 127 2") mlabsize(small) mlabvposition(pos_share_cap_top10)) ///
    (connected share_cap_bot50 anio, sort lcolor("51 160 44") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("51 160 44") ///
        mlabel(lab_share_cap_bot50) mlabcolor("51 160 44") mlabsize(small) mlabvposition(pos_share_cap_bot50)), ///
    title("Concentración del ingreso de capital", size(medium)) ///
    subtitle("Participación por grupo de percentil (hoja capital)", size(small)) ///
    ytitle("Porcentaje del ingreso de capital total") ///
    xtitle("") ///
    xlabel(`xmin'(1)`xmax', angle(45)) ///
    ylabel(, angle(horizontal) format(%9.0g)) ///
    legend(order(1 "`leg_cap_top01'" 2 "`leg_cap_top1'" 3 "`leg_cap_top10'" 4 "`leg_cap_bot50'") ///
           rows(2) position(6) span size(small) region(lcolor(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white))

capture noisily graph export "$out_dir/participacion_ingreso_capital_2010_2024.png", ///
    replace width(2400)
graph export "$out_dir/participacion_ingreso_capital_2010_2024.pdf", replace
graph save "$out_dir/participacion_ingreso_capital_2010_2024.gph", replace

restore

exit, clear

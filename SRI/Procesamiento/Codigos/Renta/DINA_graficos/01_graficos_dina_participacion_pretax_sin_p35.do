/*******************************************************************************
* Grafico DINA 1 (variante): participacion en el ingreso nacional (PreTaxHHI)
*   Misma serie que grafico 1 en 01_graficos_dina_distribucion_palma.do,
*   pero sin la linea del 35% inferior (P1-P35).
*
* Salidas: participacion_ingreso_pretax_2010_2024_sin_p35.{png,pdf,gph}
*******************************************************************************/

clear all
set more off
version 16.0

global repo_dir "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
global code_dir "$repo_dir/SRI/Procesamiento/Codigos/Renta/DINA_graficos"
global out_dir  "$repo_dir/SRI/Procesamiento/Resultados/DINA_graficos"

local input_excel "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/SRI/Resultados/25.03.2026/Tablas_DINA_dec_corr.xlsx"

capture mkdir "$out_dir"

* ---------------------------------------------------------------------------
* Hoja PreTaxHHI (mismas columnas que el do principal; no se usa P1-P35)
* ---------------------------------------------------------------------------

import excel using "`input_excel'", sheet("PreTaxHHI") clear

rename A  anio
rename G  share_top01
rename O  share_top1
rename AE share_top10
rename AM share_middle40
rename BS share_bot40
rename BK share_bottom50
rename E  N_top01
rename M  N_top1
rename AC N_top10
rename AK N_mid40
rename BI N_bot50

drop in 1
keep anio share_top01 share_top1 share_top10 share_middle40 share_bot40 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot50

destring anio share_top01 share_top1 share_top10 share_middle40 share_bot40 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot50, replace force
drop if missing(anio)

label var share_top01    "Top 0.1%"
label var share_top1     "Top 1%"
label var share_top10    "Top 10%"
label var share_middle40 "Clase media (P50-P90)"
label var share_bottom50 "50% más pobre"

sort anio

quietly summarize anio, meanonly
local xmin = r(min)
local xmax = r(max)

foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom50 {
    gen str12 lab_`v' = ""
    replace lab_`v' = trim(string(`v', "%9.1f")) if inlist(anio, 2010, 2015, 2020, 2024)
}

foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom50 {
    gen byte pos_`v' = .
}

replace pos_share_top01 = 12

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

local rem "top01 N_top01 top1 N_top1 top10 N_top10 mid40 N_mid40 bot50 N_bot50"
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
if "`pop_bot50'" != "" local leg_bot50 `"50% más pobre (`pop_bot50')"'
else local leg_bot50 "50% más pobre"

* Eje Y: ticks desde 0 hasta techo >= max entre las cinco series
tempvar _ym
egen `_ym' = rowmax(share_top01 share_top1 share_top10 share_middle40 share_bottom50)
quietly summarize `_ym'
local rawg = cond(missing(r(max)), 0, r(max))
drop `_ym'
local ysg = 5
if `rawg' <= 12 local ysg = 2
if `rawg' <= 4 local ysg = 1
local ytg = ceil(`rawg'/`ysg')*`ysg'
if `ytg' < `rawg' local ytg = `ytg' + `ysg'
if `ytg' == 0 local ytg = `ysg'

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
    (connected share_bottom50 anio, sort lcolor("51 160 44") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("51 160 44") ///
        mlabel(lab_share_bottom50) mlabcolor("51 160 44") mlabsize(small) mlabvposition(pos_share_bottom50)), ///
    title("Participación en el ingreso nacional", size(medium)) ///
    subtitle("PreTaxHHI", size(small)) ///
    ytitle("Porcentaje del ingreso nacional") ///
    xtitle("") ///
    xlabel(`xmin'(1)`xmax', angle(45)) ///
    ylabel(0(`ysg')`ytg', angle(horizontal) format(%9.0g)) ///
    yscale(range(0 `ytg')) ///
    legend(order(1 "`leg_top01'" 2 "`leg_top1'" 3 "`leg_top10'" 4 "`leg_mid40'" 5 "`leg_bot50'") ///
           rows(3) position(6) span size(small) region(lcolor(none))) ///
    graphregion(color(white)) ///
    plotregion(color(white))

capture noisily graph export "$out_dir/participacion_ingreso_pretax_2010_2024_sin_p35.png", ///
    replace width(3600)
graph export "$out_dir/participacion_ingreso_pretax_2010_2024_sin_p35.pdf", replace
graph save "$out_dir/participacion_ingreso_pretax_2010_2024_sin_p35.gph", replace

exit, clear

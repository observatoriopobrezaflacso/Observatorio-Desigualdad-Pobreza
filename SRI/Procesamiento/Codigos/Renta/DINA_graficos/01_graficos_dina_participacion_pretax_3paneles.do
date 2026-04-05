/*******************************************************************************
* Grafico DINA 1 (tres paneles): participacion PreTaxHHI por parejas
*   Panel 1: Top 0.1% y 35% mas pobre
*   Panel 2: Top 1% y 50% mas pobre
*   Panel 3: Top 10% y clase media (P50-P90)
*
* Misma fuente y estilo que 01_graficos_dina_distribucion_palma.do (grafico 1).
* Eje Y: ticks desde 0 hasta techo >= max de las series del panel.
* Salidas: participacion_ingreso_pretax_2010_2024_3paneles.{png,pdf,gph}
*******************************************************************************/

clear all
set more off
version 16.0

global repo_dir "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
global out_dir  "$repo_dir/SRI/Procesamiento/Resultados/DINA_graficos"

local input_excel "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/SRI/Resultados/25.03.2026/Tablas_DINA_dec_corr.xlsx"

capture mkdir "$out_dir"

import excel using "`input_excel'", sheet("PreTaxHHI") clear

rename A  anio
rename G  share_top01
rename O  share_top1
rename AE share_top10
rename AM share_middle40
rename CA share_bottom35
rename BK share_bottom50
rename E  N_top01
rename M  N_top1
rename AC N_top10
rename AK N_mid40
rename BY N_bot35
rename BI N_bot50

drop in 1
keep anio share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot35 N_bot50

destring anio share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 ///
    N_top01 N_top1 N_top10 N_mid40 N_bot35 N_bot50, replace force
drop if missing(anio)

sort anio

quietly summarize anio, meanonly
local xmin = r(min)
local xmax = r(max)

foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 {
    gen str12 lab_`v' = ""
    replace lab_`v' = trim(string(`v', "%9.1f")) if inlist(anio, 2010, 2015, 2020, 2024)
}

foreach v in share_top01 share_top1 share_top10 share_middle40 share_bottom35 share_bottom50 {
    gen byte pos_`v' = .
}

* Top 0.1% vs 35% inferior
replace pos_share_top01    = 12 if share_top01    >= share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_bottom35 = 6  if share_top01    >= share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_top01    = 6  if share_top01    <  share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_bottom35 = 12 if share_top01    <  share_bottom35 & share_top01 < . & share_bottom35 < .
replace pos_share_bottom35 = 6 if inlist(anio, 2010, 2015, 2020)

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
* Tres graficos (memoria) y combinacion
* Ticks eje Y: desde 0 hasta techo >= max de las series de cada panel
* ---------------------------------------------------------------------------

tempvar _ym
egen `_ym' = rowmax(share_top01 share_bottom35)
quietly summarize `_ym'
local raw1 = cond(missing(r(max)), 0, r(max))
drop `_ym'
local ys1 = 5
if `raw1' <= 12 local ys1 = 2
if `raw1' <= 4 local ys1 = 1
local yt1 = ceil(`raw1'/`ys1')*`ys1'
if `yt1' < `raw1' local yt1 = `yt1' + `ys1'
if `yt1' == 0 local yt1 = `ys1'

egen `_ym' = rowmax(share_top1 share_bottom50)
quietly summarize `_ym'
local raw2 = cond(missing(r(max)), 0, r(max))
drop `_ym'
local ys2 = 5
if `raw2' <= 12 local ys2 = 2
if `raw2' <= 4 local ys2 = 1
local yt2 = ceil(`raw2'/`ys2')*`ys2'
if `yt2' < `raw2' local yt2 = `yt2' + `ys2'
if `yt2' == 0 local yt2 = `ys2'

egen `_ym' = rowmax(share_top10 share_middle40)
quietly summarize `_ym'
local raw3 = cond(missing(r(max)), 0, r(max))
drop `_ym'
local ys3 = 5
if `raw3' <= 12 local ys3 = 2
if `raw3' <= 4 local ys3 = 1
local yt3 = ceil(`raw3'/`ys3')*`ys3'
if `yt3' < `raw3' local yt3 = `yt3' + `ys3'
if `yt3' == 0 local yt3 = `ys3'

twoway ///
    (connected share_top01 anio, sort lcolor("106 61 154") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("106 61 154") ///
        mlabel(lab_share_top01) mlabcolor("106 61 154") mlabsize(small) mlabvposition(pos_share_top01)) ///
    (connected share_bottom35 anio, sort lcolor("27 158 119") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("27 158 119") ///
        mlabel(lab_share_bottom35) mlabcolor("27 158 119") mlabsize(small) mlabvposition(pos_share_bottom35)), ///
    subtitle("Top 0.1% y 35% más pobre", size(small)) ///
    ytitle("Porcentaje del ingreso nacional", size(small)) ///
    xtitle("") xlabel(none) ///
    ylabel(0(`ys1')`yt1', angle(horizontal) format(%9.0g) labsize(small)) ///
    yscale(range(0 `yt1')) ///
    legend(order(1 "`leg_top01'" 2 "`leg_bot35'") rows(1) position(6) span size(vsmall) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(dina_pretax_p1, replace)

twoway ///
    (connected share_top1 anio, sort lcolor("163 29 33") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("163 29 33") ///
        mlabel(lab_share_top1) mlabcolor("163 29 33") mlabsize(small) mlabvposition(pos_share_top1)) ///
    (connected share_bottom50 anio, sort lcolor("51 160 44") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("51 160 44") ///
        mlabel(lab_share_bottom50) mlabcolor("51 160 44") mlabsize(small) mlabvposition(pos_share_bottom50)), ///
    subtitle("Top 1% y 50% más pobre", size(small)) ///
    ytitle("Porcentaje del ingreso nacional", size(small)) ///
    xtitle("") xlabel(none) ///
    ylabel(0(`ys2')`yt2', angle(horizontal) format(%9.0g) labsize(small)) ///
    yscale(range(0 `yt2')) ///
    legend(order(1 "`leg_top1'" 2 "`leg_bot50'") rows(1) position(6) span size(vsmall) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(dina_pretax_p2, replace)

twoway ///
    (connected share_top10 anio, sort lcolor("233 127 2") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("233 127 2") ///
        mlabel(lab_share_top10) mlabcolor("233 127 2") mlabsize(small) mlabvposition(pos_share_top10)) ///
    (connected share_middle40 anio, sort lcolor("31 120 180") lwidth(medthick) ///
        msymbol(O) msize(vsmall) mcolor("31 120 180") ///
        mlabel(lab_share_middle40) mlabcolor("31 120 180") mlabsize(small) mlabvposition(pos_share_middle40)), ///
    subtitle("Top 10% y clase media (P50-P90)", size(small)) ///
    ytitle("Porcentaje del ingreso nacional", size(small)) ///
    xtitle("") ///
    xlabel(`xmin'(1)`xmax', angle(45) labsize(small)) ///
    ylabel(0(`ys3')`yt3', angle(horizontal) format(%9.0g) labsize(small)) ///
    yscale(range(0 `yt3')) ///
    legend(order(1 "`leg_top10'" 2 "`leg_mid40'") rows(1) position(6) span size(vsmall) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    name(dina_pretax_p3, replace)

graph combine dina_pretax_p1 dina_pretax_p2 dina_pretax_p3, rows(3) ///
    title("Participación en el ingreso nacional", size(medium)) ///
    subtitle("PreTaxHHI", size(small)) ///
    graphregion(color(white)) ///
    imargin(tiny) ///
    name(dina_pretax_3pan_comb, replace)

capture noisily graph export "$out_dir/participacion_ingreso_pretax_2010_2024_3paneles.png", ///
    replace width(4800) height(3600)
graph export "$out_dir/participacion_ingreso_pretax_2010_2024_3paneles.pdf", replace
graph save "$out_dir/participacion_ingreso_pretax_2010_2024_3paneles.gph", replace

graph drop dina_pretax_p1 dina_pretax_p2 dina_pretax_p3 dina_pretax_3pan_comb

exit, clear

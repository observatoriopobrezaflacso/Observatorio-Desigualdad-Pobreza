* ============================================================================
* GRÁFICO FINAL — Informalidad por deciles de ingtot_per (deflactada)
* ============================================================================
use "H:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago\base_trabajo_ingrpc_final.dta", clear

* Filtros
drop if anio == 2025
keep if mi_pea == 1
keep if anio >= 2000
keep if ingrpc != . & ingrpc > 0

* Reconstruir informalidad (igual que tu código)
replace area = 1 if area == .

gen informal1 = affiliated_iess == 0 | ///
                adec            == 0 | ///
                no_remunerado   == 1 | ///
                cuenta_base     == 1
replace informal1 = . if inlist(., affiliated_iess, adec, no_remunerado, cuenta_propia)

gen informal2 = affiliated_iess == 0 | ///
                adec            == 0 | ///
                no_remunerado   == 1 | ///
                (tiene_ruc == 0 & tamano_armonizado == 0) | ///
                cuenta_base     == 1
replace informal2 = . if inlist(., affiliated_iess, adec, tiene_ruc, tamano_armonizado, cuenta_propia)

* Escalar a porcentaje
replace informal1 = informal1 * 100
replace informal2 = informal2 * 100

* Deciles por año
gen decil_pc = .
levelsof anio, local(anios)
foreach y of local anios {
    quietly xtile temp_d = ingrpc if anio == `y' [pw=fexp], nq(10)
    quietly replace decil_pc = temp_d if anio == `y'
    drop temp_d
}

collapse (mean) informal1 informal2 [pw=fexp], by(anio decil_pc)

* Gráfico año más reciente
quietly summarize anio
local y = r(max)

twoway ///
    (connected informal1 decil_pc if anio == `y', ///
        lcolor(navy) mcolor(navy) msymbol(O)) ///
    (connected informal2 decil_pc if anio == `y', ///
        lcolor(maroon) mcolor(maroon) msymbol(D)), ///
    title("Informalidad por Deciles de Ingreso Per Cápita - `y'") ///
    subtitle("Total Nacional — Serie deflactada (precios dic-2006)") ///
    xtitle("{bf:Decil de Ingreso Per Cápita del Hogar}") ///
    ytitle("{bf:Tasa de Informalidad (%)}") ///
    legend(order(1 "Informal 1 (IESS+adec+no rem)" 2 "Informal 2 (IESS+adec+RUC+tamaño)") ///
        position(6) rows(2)) ///
    ylabel(0(20)100) xlabel(1(1)10) ///
    graphregion(color(white))

graph export "H:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago\Grafico_Ingrpc_`y'.png", as(png) replace
display ">> GRÁFICO EXPORTADO."


**********************************************************************

* Deciles por año — solo si hay observaciones con ingrpc
gen decil_pc = .
levelsof anio, local(anios)
foreach y of local anios {
    quietly count if anio == `y' & ingrpc != . & ingrpc > 0
    if r(N) > 0 {
        quietly xtile temp_d = ingrpc if anio == `y' & ingrpc != . & ingrpc > 0 [pw=fexp], nq(10)
        quietly replace decil_pc = temp_d if anio == `y'
        drop temp_d
    }
}

collapse (mean) informal1 informal2 [pw=fexp], by(anio decil_pc)
drop if decil_pc == .

quietly summarize anio
local y = r(max)

twoway ///
    (connected informal1 decil_pc if anio == `y', ///
        lcolor(navy) mcolor(navy) msymbol(O)) ///
    (connected informal2 decil_pc if anio == `y', ///
        lcolor(maroon) mcolor(maroon) msymbol(D)), ///
    title("Informalidad por Deciles de Ingreso Per Cápita - `y'") ///
    subtitle("Total Nacional — Serie deflactada (precios dic-2006)") ///
    xtitle("{bf:Decil de Ingreso Per Cápita del Hogar}") ///
    ytitle("{bf:Tasa de Informalidad (%)}") ///
    legend(order(1 "Informal 1 (IESS+adec+no rem)" 2 "Informal 2 (IESS+adec+RUC+tamaño)") ///
        position(6) rows(2)) ///
    ylabel(0(20)100) xlabel(1(1)10) ///
    graphregion(color(white))

graph export "H:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago\Grafico_Ingrpc_`y'.png", as(png) replace
display ">> GRÁFICO EXPORTADO."
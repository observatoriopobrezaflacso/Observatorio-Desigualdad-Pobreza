*------------------------------------------------------------------------------*
* Create poverty variable in ENEMDU per-capita income datasets
*------------------------------------------------------------------------------*
*
* Rule:
*   pobreza = 1 if ingtot_per is below the annual December poverty threshold
*   pobreza = 0 if ingtot_per is at or above the threshold
*
* Data selection:
*   1991-1999 odd years: urban datasets (_urb)
*   2001 onwards odd years: national datasets (_nac)
*
* By default, the script saves modified copies in:
*   .../ingresos_pc/con_pobreza
*
* To overwrite the original datasets, change replace_originals to 1.
*------------------------------------------------------------------------------*

clear all
set more off
version 15.1

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global ingresos_pc "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
global lineas_xlsx "$user_root/Bases/lineas_pobreza/lineas_de_pobreza_historica.xlsx"

local replace_originals 0
local outdir "$ingresos_pc/con_pobreza"
local historico "`outdir'/ing_perca_pobreza_historico.dta"
local resumen "`outdir'/evolucion_pobreza.dta"

if !`replace_originals' {
    capture mkdir "`outdir'"
}

*--- Import annual December poverty thresholds ---*
tempfile lineas

import excel using "$lineas_xlsx", clear

rename A anio
rename C linea_pobreza
keep anio linea_pobreza

foreach v in anio linea_pobreza {
    capture confirm numeric variable `v'
    if _rc {
        destring `v', replace force
    }
}

drop if missing(anio) | missing(linea_pobreza)
duplicates drop anio, force
save `lineas', replace

*--- Years requested by source type ---*


*forval y = 2001(2)2025 {
foreach y in 2025 {

	local infile "$ingresos_pc/empleo`y'.dta"
	local outfile "`outdir'/ing_perca_`y'_`scope'_precios2000.dta"

	capture confirm file "`infile'"
	if _rc {
		display as error "File not found: `infile'"
		continue
	}

	quietly use `lineas', clear
	quietly keep if anio == `y'

	if _N != 1 {
		display as error "No unique poverty threshold found for year `y'"
		error 459
	}

	local lp = linea_pobreza[1]
	
	

	use "`infile'", clear

	capture confirm variable ingtot_per
	if _rc {
		display as error "Variable ingtot_per not found in `infile'"
		error 111
	}

	capture drop pobreza
	capture drop linea_pobreza
	capture drop cobertura_pobreza
	
	capture confirm variable anio
	if _rc {
		generate int anio = `y'
	}
	else {
		replace anio = `y' if missing(anio)
	}

	generate double linea_pobreza = `lp'
	generate byte pobreza = (ingtot_per < linea_pobreza) if !missing(ingtot_per)
	generate str3 cobertura_pobreza = "`scope'"

	label variable linea_pobreza "Linea de pobreza anual diciembre (USD)"
	label variable pobreza "Ingreso per capita bajo linea de pobreza"
	label variable cobertura_pobreza "Cobertura de base usada para pobreza"
	label define pobreza_lbl 0 "No pobre" 1 "Pobre", replace
	label values pobreza pobreza_lbl

	quietly count if pobreza == 1
	local n_pobres = r(N)
	quietly count if pobreza < .
	local n_validos = r(N)

	display as text "Year `y' (`scope'): line = " ///
		as result %9.2f `lp' ///
		as text ", poor = " ///
		as result %12.0fc `n_pobres' ///
		as text " / " ///
		as result %12.0fc `n_validos'

	if `replace_originals' {
		save "`infile'", replace
	}
	else {
		save "`outfile'", replace
	}
}

*--- Append processed datasets into one historical file ---*
clear
local first_file 1
local append_vars anio cobertura_pobreza fexp ingtot_per pobreza linea_pobreza



forval y = 2001(2)2025 {

	if `replace_originals' {
		local datafile "$ingresos_pc/ing_perca_`y'_`scope'_precios2000.dta"
	}
	else {
		local datafile "`outdir'/ing_perca_`y'_`scope'_precios2000.dta"
	}

	capture confirm file "`datafile'"
	if _rc {
		display as error "File not found for append: `datafile'"
		continue
	}

	if `first_file' {
		use "`datafile'", clear
		keep `append_vars'
		local first_file 0
	}
	else {
		tempfile nextfile
		preserve
		use "`datafile'", clear
		keep `append_vars'
		save `nextfile', replace
		restore

		append using `nextfile'
		
	}
}


save "`historico'", replace

*--- Poverty evolution plot ---*
preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] if pobreza < . & fexp < ., ///
    by(anio cobertura_pobreza)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

*save "`resumen'", replace

twoway ///
    (line tasa_pobreza_pct anio, ///
        lcolor(navy) lwidth(medthick) msymbol(circle) mcolor(navy)), ///
    title("Evolucion de la pobreza") ///
    subtitle("Ingreso per capita bajo linea de pobreza anual de diciembre") ///
    xtitle("Anio") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2023, angle(45)) ///
    legend(order(1 "Urbana 1991-1999" 2 "Nacional 2001-2023") ///
        position(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))

*graph save "`outdir'/evolucion_pobreza.gph", replace
*graph export "`outdir'/evolucion_pobreza.pdf", replace


restore

display as text "Done."

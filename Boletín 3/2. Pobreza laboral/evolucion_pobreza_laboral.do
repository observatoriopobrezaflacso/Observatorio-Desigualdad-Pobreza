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
set varabbrev off

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global gh_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"

global ingresos_pc "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc"
global lineas_xlsx "$user_root/Bases/lineas_pobreza/lineas_de_pobreza_historica.xlsx"
global outdir      "$user_root/Boletín 3/4. Resultados/pobreza laboral"
global out_dash    "$gh_root/Dashboards/data/Data final/empleo/pobreza"


cap mkdir "$ingresos_pc/pobreza"

local replace_originals 0




if !`replace_originals' {
    capture mkdir "$outdir"
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


foreach y of numlist 2001(2)2007 2008(1)2025  {

	local infile "$ingresos_pc/Nacional/ing_perca_`y'_nac_precios2000.dta"
	local outfile "$outdir/ing_perca_`y'_`scope'_precios2000.dta"

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

	if `y' >= 1991 & `y' <= 1999 {
		local ingreso_var ingtot_per_deflated
	}
	else {
		local ingreso_var ingtot_per
	}
	
	capture confirm variable hortrasa  
	if !_rc rename hortrasa p24
	
	capture confirm variable p03 
	if !_rc rename p03 edad

	
	
	capture confirm variable `ingreso_var'
	if _rc {
		display as error "Variable `ingreso_var' not found in `infile'"
		error 111
	}

	capture confirm variable ing_lab
	if _rc {
		display as text "Variable ing_lab not found in `infile'; generating missing values."
		generate double ing_lab = .
	}

	capture drop pobreza
	capture drop linea_pobreza
	capture drop cobertura_pobreza
	capture drop ingreso_pobreza
	capture drop ingreso_pobreza_var
	capture drop educacion
	capture drop educacion_superior
	
	capture confirm variable anio
	if _rc {
		generate int anio = `y'
	}
	else {
		replace anio = `y' if missing(anio)
	}

	capture confirm variable sexo
	if _rc {
		capture confirm variable p02
		if !_rc {
			generate byte sexo = p02
		}
		else {
			generate byte sexo = .
		}
	}

	capture confirm variable area
	if _rc {
		generate byte area = .
		replace area = 1 if "`scope'" == "urb"
	}

	capture confirm variable nnivins
	if !_rc {
		generate educacion = nnivins
	}
	else {
		capture confirm variable nivinst
		if !_rc {
			generate educacion = nivinst
		}
		else {
			capture confirm variable p10a
			if !_rc {
				generate educacion = p10a
			}
			else {
				generate byte educacion = .
			}
		}
	}

	generate byte educacion_superior = 0

	if inrange(`y', 1991, 1999) {
		capture confirm variable nivinst
		if !_rc {
			replace educacion_superior = 1 if nivinst == 5
			replace educacion_superior = . if missing(nivinst)
		}
		else {
			replace educacion_superior = .
		}
	}
	else if `y' == 2001 {
		capture confirm variable nivinst
		if !_rc {
			replace educacion_superior = 1 if inlist(nivinst, 6, 7)
			replace educacion_superior = . if missing(nivinst)
		}
		else {
			replace educacion_superior = .
		}
	}
	else if inrange(`y', 2003, 2006) {
		capture confirm variable nivinst
		if !_rc {
			replace educacion_superior = 1 if inlist(nivinst, 9, 10)
			replace educacion_superior = . if missing(nivinst)
		}
		else {
			replace educacion_superior = .
		}
	}
	else if `y' >= 2007 {
		capture confirm variable p10a
		if !_rc {
			replace educacion_superior = 1 if inlist(p10a, 9, 10)
			replace educacion_superior = . if missing(p10a)
		}
		else {
			replace educacion_superior = .
		}
	}

	generate double linea_pobreza = `lp'
	generate double ingreso_pobreza = `ingreso_var'
	generate byte pobreza = (ingreso_pobreza < linea_pobreza) if !missing(ingreso_pobreza)
	generate str3 cobertura_pobreza = "`scope'"
	generate str20 ingreso_pobreza_var = "`ingreso_var'"

	label variable linea_pobreza "Linea de pobreza anual diciembre (USD)"
	label variable ingreso_pobreza "Ingreso usado para pobreza"
	label variable ingreso_pobreza_var "Variable de ingreso usada para pobreza"
	label variable pobreza "Ingreso per capita bajo linea de pobreza"
	label variable cobertura_pobreza "Cobertura de base usada para pobreza"
	label variable educacion "Nivel de educacion armonizado desde variable original"
	label variable educacion_superior "Tiene educacion superior"
	label define pobreza_lbl 0 "No pobre" 1 "Pobre", replace
	label define educ_sup_lbl 0 "Sin educacion superior" 1 "Con educacion superior", replace
	label values pobreza pobreza_lbl
	label values educacion_superior educ_sup_lbl

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

	tempfile dta_`y'_`scope'	
	save `dta_`y'_`scope''	
		
}


*--- Append processed datasets into one historical file ---*
clear
local first_file 1
local append_vars anio cobertura_pobreza fexp sexo area educacion educacion_superior ing_lab ingtot_per ingreso_pobreza ingreso_pobreza_var pobreza linea_pobreza p24 edad ingtot_per_deflated inglab_per_deflated

foreach y of numlist 2001(2)2007 2008(1)2025  {

	if `first_file' {
		use `dta_`y'_`scope'', clear
		keep `append_vars'
		local first_file 0
		
	}
	else {
		tempfile nextfile
		preserve
		use `dta_`y'_`scope'', clear
		keep `append_vars'
		save `nextfile', replace
		restore

		append using `nextfile'
	}
}


save "$ingresos_pc/pobreza/historico.dta", replace

drop if p24 == 999

*--- Poverty evolution plot ---*
preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if pobreza < . & fexp < ., ///
    by(anio cobertura_pobreza)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

export excel using "$outdir/pobreza_evolucion.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_evolucion.xlsx", replace firstrow(var)

twoway ///
    (connected tasa_pobreza_pct anio, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)), ///
    title("Evolucion de la pobreza") ///
    subtitle("Ingreso per capita bajo linea de pobreza anual de diciembre") ///
    xtitle("Anio") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2023, angle(45)) ///
    legend(order(1 "Nacional") position(6) rows(1)) ///
    name(g_pobreza_total, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza.gph", replace
graph export "$outdir/evolucion_pobreza.pdf", replace

capture graph export "$outdir/evolucion_pobreza.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore

*--- Poverty evolution among people with observed labor income ---*
preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if  pobreza < . & fexp < . & ing_lab < ., ///
    by(anio cobertura_pobreza)
list 

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

export excel using "$outdir/pobreza_laboral.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_laboral.xlsx", replace firstrow(var)


* --- Value labels in selected years ---
gen lbl_pobreza = tasa_pobreza_pct if inlist(anio, 2001, 2009, 2017, 2025)
format lbl_pobreza %9.1f

twoway ///
    (connected tasa_pobreza_pct anio, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
    (scatter lbl_pobreza anio, msymbol(none) mlabel(lbl_pobreza) ///
        mlabposition(12) mlabcolor(maroon) mlabsize(vsmall)), ///
    title("Pobreza entre personas con ingreso laboral") ///
    subtitle("Muestra restringida a observaciones con ing_lab") ///
    xtitle("") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "Nacional") position(6) rows(1)) ///
    name(g_pobreza_ing_lab, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza_ing_lab.gph", replace
graph export "$outdir/evolucion_pobreza_ing_lab.pdf", replace

capture graph export "$outdir/evolucion_pobreza_ing_lab.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore

*--- Poverty evolution among people with observed labor income, by age group ---*
preserve

* --- Age groups ---
gen age_cat = .
replace age_cat = 1 if edad >= 18 & edad <= 29
replace age_cat = 2 if edad >= 30 & edad <= 64
replace age_cat = 3 if edad >= 65 & edad < 98

label variable age_cat "Grupo de edad"
label define age_cat_lbl 1 "18-29" 2 "30-64" 3 "65+"
label values age_cat age_cat_lbl

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if  pobreza < . & fexp < . & ing_lab < . & age_cat < ., ///
    by(anio age_cat)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

export excel using "$outdir/pobreza_lab_edad.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_lab_edad.xlsx", replace firstrow(var)

* --- Value labels in selected years ---
gen lbl_1 = tasa_pobreza_pct if age_cat == 1 & inlist(anio, 2001, 2009, 2017, 2025)
gen lbl_2 = tasa_pobreza_pct if age_cat == 2 & inlist(anio, 2001, 2009, 2017, 2025)
gen lbl_3 = tasa_pobreza_pct if age_cat == 3 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_1 lbl_2 lbl_3 %9.1f

twoway ///
    (connected tasa_pobreza_pct anio if age_cat == 1, ///
        lcolor(navy) lwidth(medthick) msymbol(circle) mcolor(navy)) ///
    (connected tasa_pobreza_pct anio if age_cat == 2, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
    (connected tasa_pobreza_pct anio if age_cat == 3, ///
        lcolor(forest_green) lwidth(medthick) msymbol(circle) mcolor(forest_green)) ///
    (scatter lbl_1 anio, msymbol(none) mlabel(lbl_1) ///
        mlabposition(12) mlabcolor(navy) mlabsize(vsmall)) ///
    (scatter lbl_2 anio, msymbol(none) mlabel(lbl_2) ///
        mlabposition(12) mlabcolor(maroon) mlabsize(vsmall)) ///
    (scatter lbl_3 anio, msymbol(none) mlabel(lbl_3) ///
        mlabposition(6) mlabcolor(forest_green) mlabsize(vsmall)), ///
    title("Pobreza entre personas con ingreso laboral, por edad") ///
    subtitle("Muestra restringida a observaciones con ing_lab") ///
    xtitle("") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "18-29" 2 "30-64" 3 "65+") position(6) rows(1)) ///
    name(g_pobreza_ing_lab_edad, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza_ing_lab_edad.gph", replace
graph export "$outdir/evolucion_pobreza_ing_lab_edad.pdf", replace

capture graph export "$outdir/evolucion_pobreza_ing_lab_edad.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore


*--- Disaggregation by sex among people with observed labor income ---*

preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if  pobreza < . & fexp < . & ing_lab < . & sexo < ., ///
    by(anio sexo)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

export excel using "$outdir/pobreza_lab_sexo.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_lab_sexo.xlsx", replace firstrow(var)


* --- Value labels in selected years ---
gen lbl_h = tasa_pobreza_pct if sexo == 1 & inlist(anio, 2001, 2009, 2017, 2025)
gen lbl_m = tasa_pobreza_pct if sexo == 2 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_h lbl_m %9.1f

twoway ///
    (connected tasa_pobreza_pct anio if sexo == 1, ///
        lcolor(navy) lwidth(medthick) msymbol(circle) mcolor(navy)) ///
    (connected tasa_pobreza_pct anio if sexo == 2, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
    (scatter lbl_h anio, msymbol(none) mlabel(lbl_h) ///
        mlabposition(12) mlabcolor(navy) mlabsize(vsmall)) ///
    (scatter lbl_m anio, msymbol(none) mlabel(lbl_m) ///
        mlabposition(6) mlabcolor(maroon) mlabsize(vsmall)), ///
    title("Pobreza con ingreso laboral, por sexo") ///
    subtitle("Muestra restringida a observaciones con ing_lab") ///
    xtitle("") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "Hombre" 2 "Mujer") position(6) rows(1)) ///
    name(g_pobreza_ing_lab_sexo, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza_ing_lab_sexo.gph", replace
graph export "$outdir/evolucion_pobreza_ing_lab_sexo.pdf", replace

capture graph export "$outdir/evolucion_pobreza_ing_lab_sexo.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore

*--- Disaggregation by area among people with observed labor income ---*
preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if  pobreza < . & fexp < . & ing_lab < . & area < ., ///
    by(anio area)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"

export excel using "$outdir/pobreza_lab_area.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_lab_area.xlsx", replace firstrow(var)


* --- Value labels in selected years ---
gen lbl_urb = tasa_pobreza_pct if area == 1 & inlist(anio, 2001, 2009, 2017, 2025)
gen lbl_rur = tasa_pobreza_pct if area == 2 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_urb lbl_rur %9.1f

twoway ///
    (connected tasa_pobreza_pct anio if area == 1, ///
        lcolor(navy) lwidth(medthick) msymbol(circle) mcolor(navy)) ///
    (connected tasa_pobreza_pct anio if area == 2, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
    (scatter lbl_urb anio, msymbol(none) mlabel(lbl_urb) ///
        mlabposition(12) mlabcolor(navy) mlabsize(vsmall)) ///
    (scatter lbl_rur anio, msymbol(none) mlabel(lbl_rur) ///
        mlabposition(6) mlabcolor(maroon) mlabsize(vsmall)), ///
    title("Pobreza con ingreso laboral, por area") ///
    subtitle("Muestra restringida a observaciones con ing_lab") ///
    xtitle("") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "Urbana" 2 "Rural") position(6) rows(1)) ///
    name(g_pobreza_ing_lab_area, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza_ing_lab_area.gph", replace
graph export "$outdir/evolucion_pobreza_ing_lab_area.pdf", replace

capture graph export "$outdir/evolucion_pobreza_ing_lab_area.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore

*--- Disaggregation by higher education among people with observed labor income ---*

preserve

collapse (mean) tasa_pobreza = pobreza [iw = fexp] ///
    if  pobreza < . & fexp < . & ing_lab < . & educacion_superior < ., ///
    by(anio educacion_superior)

generate tasa_pobreza_pct = 100 * tasa_pobreza
label variable tasa_pobreza_pct "Pobreza (%)"


export excel using "$outdir/pobreza_lab_educ.xlsx", replace firstrow(var)
export excel using "$out_dash/pobreza_lab_educ.xlsx", replace firstrow(var)


* --- Value labels in selected years ---
gen lbl_0 = tasa_pobreza_pct if educacion_superior == 0 & inlist(anio, 2001, 2009, 2017, 2025)
gen lbl_1 = tasa_pobreza_pct if educacion_superior == 1 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_0 lbl_1 %9.1f


twoway ///
    (connected tasa_pobreza_pct anio if educacion_superior == 0, ///
        lcolor(navy) lwidth(medthick) msymbol(circle) mcolor(navy)) ///
    (connected tasa_pobreza_pct anio if educacion_superior == 1, ///
        lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
    (scatter lbl_0 anio, msymbol(none) mlabel(lbl_0) ///
        mlabposition(12) mlabcolor(navy) mlabsize(vsmall)) ///
    (scatter lbl_1 anio, msymbol(none) mlabel(lbl_1) ///
        mlabposition(6) mlabcolor(maroon) mlabsize(vsmall)), ///
    title("Pobreza con ingreso laboral, por educacion superior") ///
    subtitle("Muestra restringida a observaciones con ing_lab") ///
    xtitle("") ///
    ytitle("Pobreza (%)") ///
    ylabel(0(10)100, angle(horizontal)) ///
    xlabel(2001(2)2025, angle(45)) ///
    legend(order(1 "Sin educacion superior" 2 "Con educacion superior") ///
        position(6) rows(1)) ///
    name(g_pobreza_ing_lab_educacion, replace) ///
    graphregion(color(white)) plotregion(color(white))

graph save "$outdir/evolucion_pobreza_ing_lab_educacion_superior.gph", replace
graph export "$outdir/evolucion_pobreza_ing_lab_educacion_superior.pdf", replace

capture graph export "$outdir/evolucion_pobreza_ing_lab_educacion_superior.png", replace width(2400)
if _rc {
    display as text "PNG export skipped because the Graph2png translator is not available."
}

restore


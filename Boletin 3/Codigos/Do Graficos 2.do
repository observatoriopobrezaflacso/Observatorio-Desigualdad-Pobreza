* ==============================================================================
* BOLETÍN 3: GRÁFICOS SEPARADOS (URBANO VS NACIONAL)
* ==============================================================================

* 1. Cargar la nueva base de datos (V2)
use "H:\Mi unidad\Boletín 3\2. Armonización de variables\Bases_limpias\Emilio\Modulos_Emilio\ENEMDU_Boletin3_Emilio_FINAL_V2.dta", clear

* 2. Crear variable dummy para Empleo Adecuado (0 = No, 1 = Sí)
gen d_adecuado = (condicion_empleo_adecuado == "Adecuado")
replace d_adecuado = . if condicion_empleo_adecuado == ""


* ==============================================================================
* GRÁFICO 1: SERIE EXCLUSIVAMENTE URBANA (1990 - 2024)
* ==============================================================================
* Aquí aislamos el efecto rural. Comparamos peras con peras durante 34 años.

preserve
	* Magia pura: nos quedamos SOLO con la gente de la ciudad
	keep if area_armonizada == "Urbano"
	
	* Calculamos el porcentaje por año
	collapse (mean) d_adecuado, by(anio)
	replace d_adecuado = d_adecuado * 100

	twoway (connected d_adecuado anio, lcolor(navy) mcolor(navy) msymbol(O)), ///
		title("Evolución del Empleo Adecuado (Área Urbana)", size(medium)) ///
		subtitle("Periodo 1990 - 2024", size(small)) ///
		ytitle("Porcentaje (%)") xtitle("Año") ///
		xline(1999.5, lcolor(gs10) lpattern(dash)) ///
		text(30 1999.5 "Crisis '99", color(gs10) size(vsmall) placement(e)) ///
		xlabel(1990(5)2024) ylabel(30(10)70, angle(0)) ///
		note("Nota: Serie homogénea filtrada exclusivamente para dominios urbanos.") ///
		graphregion(color(white))
		
	graph export "H:\Mi unidad\Boletín 3\Serie_Urbana_Adecuado.png", replace
restore


* ==============================================================================
* GRÁFICO 2: SERIE NACIONAL (2000 - 2024)
* ==============================================================================
* Aquí mostramos la foto macroeconómica completa del país, pero desde 
* que la encuesta tiene representatividad rural (año 2000).

preserve
	* Cortamos la base para empezar desde el 2000
	keep if anio >= 2000
	
	* Calculamos el porcentaje por año
	collapse (mean) d_adecuado, by(anio)
	replace d_adecuado = d_adecuado * 100

	twoway (connected d_adecuado anio, lcolor(maroon) mcolor(maroon) msymbol(D)), ///
		title("Evolución del Empleo Adecuado (Nacional)", size(medium)) ///
		subtitle("Periodo 2000 - 2024", size(small)) ///
		ytitle("Porcentaje (%)") xtitle("Año") ///
		xlabel(2000(4)2024) ylabel(20(5)50, angle(0)) ///
		note("Nota: Incluye dominios urbanos y rurales.") ///
		graphregion(color(white))
		
	graph export "H:\Mi unidad\Boletín 3\Serie_Nacional_Adecuado.png", replace
restore
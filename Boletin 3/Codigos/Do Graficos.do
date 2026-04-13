* ==============================================================================
* BOLETÍN 3: GRÁFICOS DE EVOLUCIÓN HISTÓRICA (1990 - 2024)
* ==============================================================================

* 1. Cargar la base de datos
use "H:\Mi unidad\Bases\ENEMDU\Procesadas\Modulos_Emilio\ENEMDU_Boletin3_Emilio_FINAL.dta", clear

* 2. Crear variables dummy (0/1) para facilitar el cálculo de porcentajes
* (Stata maneja mejor los números que los textos largos para colapsar)

gen d_adecuado = (condicion_empleo_adecuado == "Adecuado")
replace d_adecuado = . if condicion_empleo_adecuado == ""

gen d_noremun = (condicion_empleo_no_remun == "No Remunerado")
replace d_noremun = . if condicion_empleo_no_remun == ""


* ==============================================================================
* GRÁFICO 1: EVOLUCIÓN DEL EMPLEO ADECUADO
* ==============================================================================
preserve
	* Calculamos el promedio (porcentaje) por año
	collapse (mean) d_adecuado, by(anio)
	replace d_adecuado = d_adecuado * 100

	twoway (connected d_adecuado anio, lcolor(navy) mcolor(navy) msymbol(O)), ///
		title("Evolución del Empleo Adecuado en Ecuador", size(medium)) ///
		subtitle("Periodo 1990 - 2024", size(small)) ///
		ytitle("Porcentaje (%)") xtitle("Año") ///
		xline(1999.5, lcolor(red) lpattern(dash)) ///
		text(15 1995 "Área Urbana", color(red) size(vsmall)) ///
		text(15 2005 "Nacional", color(red) size(vsmall)) ///
		xlabel(1990(5)2024) ylabel(0(10)60, angle(0)) ///
		note("Nota: Hasta 1999 la ENEMDU solo tiene representatividad urbana.") ///
		graphregion(color(white))
		
	graph export "H:\Mi unidad\Bases\ENEMDU\Procesadas\Evolucion_Empleo_Adecuado.png", replace
restore


* ==============================================================================
* GRÁFICO 2: EVOLUCIÓN DEL EMPLEO NO REMUNERADO
* ==============================================================================
preserve
	collapse (mean) d_noremun, by(anio)
	replace d_noremun = d_noremun * 100

	twoway (connected d_noremun anio, lcolor(forest_green) mcolor(forest_green) msymbol(D)), ///
		title("Evolución del Empleo No Remunerado", size(medium)) ///
		ytitle("Porcentaje (%)") xtitle("Año") ///
		xline(1999.5, lcolor(red) lpattern(dash)) ///
		xlabel(1990(5)2024) ylabel(0(5)30, angle(0)) ///
		note("Nota: Ruptura de serie en 2000 por cambio a representatividad nacional.") ///
		graphregion(color(white))
		
	graph export "H:\Mi unidad\Bases\ENEMDU\Procesadas\Evolucion_No_Remunerado.png", replace
restore


* ==============================================================================
* GRÁFICO 3: MACRO-SECTORES DE ACTIVIDAD (MANUFACTURA VS COMERCIO)
* ==============================================================================
* Para este gráfico, vamos a comparar cómo se ha comportado la Manufactura
* frente al Comercio y Servicios a lo largo del tiempo.

preserve
	* Limpiar casos ND para el cálculo de los sectores
	drop if macro_sector_actividad == "7. N/D" | macro_sector_actividad == ""
	
	* Crear dummies sectoriales
	gen d_comercio = (macro_sector_actividad == "5. Comercio y Servicios")
	gen d_manufact = (macro_sector_actividad == "2. Manufactura")
	
	collapse (mean) d_comercio d_manufact, by(anio)
	
	replace d_comercio = d_comercio * 100
	replace d_manufact = d_manufact * 100

	twoway (line d_comercio anio, lcolor(orange) lwidth(medthick)) ///
		   (line d_manufact anio, lcolor(ebblue) lwidth(medthick)), ///
		title("Composición Sectorial: Comercio vs Manufactura", size(medium)) ///
		ytitle("Participación en el Empleo (%)") xtitle("Año") ///
		xline(1999.5, lcolor(red) lpattern(dash)) ///
		legend(order(1 "Comercio y Servicios" 2 "Manufactura") region(lcolor(white))) ///
		xlabel(1990(5)2024) ylabel(0(10)60, angle(0)) ///
		graphregion(color(white))
		
	graph export "H:\Mi unidad\Bases\ENEMDU\Procesadas\Evolucion_Sectores.png", replace
restore
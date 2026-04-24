* ============================================================
* Gráfico: % informalidad por decil de ingresos laborales
* ============================================================

preserve

* --- 1. Filtro de población ocupada con ingreso válido --------
keep if mi_pea == 1
keep if ingrl != . & ingrl > 0   

* --- 2. Construir deciles ponderados ------------------------
xtile decil = ingrl [pw=fexp], nq(10)

* --- 3. Colapsar: % informalidad por decil ------------------
collapse (mean) inf1=informal1 inf2=informal2 [pw=fexp], by(decil)

replace inf1 = inf1 * 100
replace inf2 = inf2 * 100

* --- 4. Gráfico de Alta Calidad -----------------------------
twoway ///
    (connected inf1 decil, ///
        lcolor(navy) mcolor(navy) msymbol(O) lwidth(medthick) msize(medlarge) lpattern(solid)) ///
    (connected inf2 decil, ///
        lcolor(maroon) mcolor(maroon) msymbol(D) lwidth(medthick) msize(medlarge) lpattern(dash)), ///
    /// Ejes y Cuadrículas
    xlabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10", labsize(small)) ///
    ylabel(0(20)100, angle(horizontal) format(%2.0f) labsize(small) grid glcolor(gs14) glpattern(dot)) ///
    /// Títulos de Ejes (Corregido)
    xtitle("{bf:Decil de Ingresos Laborales}", size(small) margin(t=2)) ///
    ytitle("{bf:Tasa de Informalidad (%)}", size(small) margin(r=2)) ///
    /// Títulos principales
    title("Informalidad Laboral por Deciles de Ingreso", size(medium) color(black) margin(b=2)) ///
    subtitle("Población ocupada — Ponderado por factor de expansión", size(vsmall) color(gs7)) ///
    /// Leyenda
    legend(order(1 "Informalidad 1" 2 "Informalidad 2") ///
           position(6) rows(1) size(small) region(lcolor(white))) ///
    /// Fondos y Notas
    graphregion(color(white) margin(medium)) plotregion(color(white)) ///
    note("Fuente: ENEMDU." "Elaboración: Propia.", size(vsmall) color(gs6) span)

restore

**********************************************************************************************

* ======================================================================
* Gráficos por Año: % informalidad por decil de ingresos laborales
* ======================================================================

preserve

* --- 1. Filtro de población ocupada con ingreso válido ----------------
keep if mi_pea == 1
keep if ingrl != . & ingrl > 0   

* --- 2. Calcular deciles año por año ----------------------------------
* Creamos una variable vacía y la llenamos iterando por cada año
gen decil = .
levelsof anio, local(anios)

foreach y of local anios {
    quietly xtile temp_dec_`y' = ingrl if anio == `y' [pw=fexp], nq(10)
    quietly replace decil = temp_dec_`y' if anio == `y'
    drop temp_dec_`y'
}

* --- 3. Colapsar la base por Año y Decil ------------------------------
collapse (mean) inf1=informal1 inf2=informal2 [pw=fexp], by(anio decil)

replace inf1 = inf1 * 100
replace inf2 = inf2 * 100

* --- 4. Directorio de salida para los gráficos ------------------------
* Cambia esta ruta a la carpeta donde quieres guardar los PNG
local ruta_salida "H:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago"

* --- 5. Loop para graficar y exportar por año -------------------------
levelsof anio, local(anios_graf)

foreach y of local anios_graf {
    
    * Para asegurar que el año se vea bien en el título (sin decimales)
    local y_str : display %9.0g `y'
    local y_str = strtrim("`y_str'")
    
    quietly twoway ///
        (connected inf1 decil if anio == `y', ///
            lcolor(navy) mcolor(navy) msymbol(O) lwidth(medthick) msize(medlarge) lpattern(solid)) ///
        (connected inf2 decil if anio == `y', ///
            lcolor(maroon) mcolor(maroon) msymbol(D) lwidth(medthick) msize(medlarge) lpattern(dash)), ///
        /// Ejes y Cuadrículas
        xlabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10", labsize(small)) ///
        ylabel(0(20)100, angle(horizontal) format(%2.0f) labsize(small) grid glcolor(gs14) glpattern(dot)) ///
        /// Títulos de Ejes
        xtitle("{bf:Decil de Ingresos Laborales}", size(small) margin(t=2)) ///
        ytitle("{bf:Tasa de Informalidad (%)}", size(small) margin(r=2)) ///
        /// Títulos principales (Añadimos el año dinámicamente)
        title("Informalidad Laboral por Deciles de Ingreso - `y_str'", size(medium) color(black) margin(b=2)) ///
        subtitle("Población ocupada — Ponderado por factor de expansión", size(vsmall) color(gs7)) ///
        /// Leyenda
        legend(order(1 "Informalidad 1" 2 "Informalidad 2") ///
               position(6) rows(1) size(small) region(lcolor(white))) ///
        /// Fondos y Notas
        graphregion(color(white) margin(medium)) plotregion(color(white)) ///
        note("Fuente: ENEMDU (`y_str')." "Elaboración: Propia.", size(vsmall) color(gs6) span) name(graf_`y_str', replace)

    * Exportar el gráfico en formato PNG
    quietly graph export "`ruta_salida'\Informalidad_Deciles_`y_str'.png", as(png) replace
    
    * Cerrar el gráfico de la memoria para que Stata no se ponga lento
    quietly graph drop graf_`y_str'
    
    display "Gráfico del año `y_str' exportado con éxito."
}

restore
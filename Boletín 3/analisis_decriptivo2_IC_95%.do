*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
*------------------------------------------------------------------*

clear all
set more off

* Definición de rutas globales para acceder a las bases de datos
global user_root "/G:\Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global variables_base "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global bases_armonizadas "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global out_results "$user_root/Boletín 3/2. Armonización de variables/Resultados"

* Definición de variables importantes para análisis
global important_variable informal1
global important_variable2 informal2

* Cargar base de datos de trabajo
use "G:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago/base_trabajo.dta", clear

* Eliminar observaciones del año 2025
drop if anio == 2025


replace area = 1 if area == .

* Definir lista de variables relevantes para análisis de informalidad
local vars affiliated_iess adec cuenta_propia tiene_ruc tamano_armonizado no_remunerado

* Generar tabulaciones de cada variable por año para control
foreach var of local vars {
    di "`var'"	
    tab anio `var'
}

* ============================================================
* CONSTRUCCIÓN DE INDICADOR DE INFORMALIDAD 1
* ============================================================
* Crear variable informal1 basada en cuatro criterios:
* - No afiliado al IESS
* - Trabajo no adecuado
* - Trabajador no remunerado
* - Empleado doméstico
gen informal1 =  affiliated_iess    == 0 | ///
				 adec               == 0 | ///
				 no_remunerado      == 1 
				 
* Asignar missing si alguna de las variables componentes es missing
replace informal1 = . if inlist(., affiliated_iess, adec, no_remunerado)				 

* ============================================================
* CONSTRUCCIÓN DE INDICADOR DE INFORMALIDAD 2
* ============================================================
* Crear variable informal2 con criterios alternativos:
* - No afiliado al IESS
* - Trabajo no adecuado
* - Clasificación informal nueva
* - Trabajador doméstico no remunerado
gen informal2 =  affiliated_iess    == 0 | ///
				 adec               == 0 | ///
				 no_remunerado      == 1 | ///
				 (tiene_ruc == 0) 
				 
* Asignar missing si alguna de las variables componentes es missing
replace informal2 = . if inlist(., affiliated_iess, adec,  tiene_ruc, tamano_armonizado, cuenta_propia)


* ============================================================
* GRÁFICO DE TENDENCIAS: INFORMALIDAD URBANA VS NACIONAL
* ============================================================

* Calcular promedio de informalidad por año y área (urbano/rural)
preserve
    collapse (mean) $important_variable, by(anio area)
    list
    format $important_variable %9.2f
    * Mantener solo área urbana (area == 1)
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore

* Calcular promedio nacional de informalidad por año
preserve
    collapse (mean) $important_variable, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    * Combinar con datos urbanos
    merge 1:1 anio using `urb', nogen
    list
    * Generar gráfico de líneas comparando tendencia nacional vs urbana
    twoway (line ${important_variable}_nac anio)  ///
           (line ${important_variable}_urb anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           name(informal1_nac_urb, replace)
    graph export "$out_results/informal1_nac_urb.png", replace
restore


* Calcular promedio ponderado de informal2 por año y área (2007-2024)
preserve
    keep if inrange(anio, 2001, 2024)
    collapse (mean) $important_variable2  if anio != 2002 [iw = fexp], by(anio area)
    list
    format $important_variable2 %9.2f
    * Mantener solo área urbana
    keep if area == 1
    rename $important_variable2 ${important_variable2}_urb
    tempfile urb
    save `urb'
restore

preserve
    keep if inrange(anio, 2001, 2024)
    collapse (mean) $important_variable2  if anio != 2002 [iw = fexp], by(anio area)
    list
    format $important_variable2 %9.2f
    * Mantener solo área urbana
    keep if area == 2
    rename $important_variable2 ${important_variable2}_rural
    tempfile rural
    save `rural', replace
restore

* Calcular promedio nacional ponderado de informal2 (2007-2024)
preserve
    keep if inrange(anio, 2001, 2024)
    collapse (mean) $important_variable2 if anio != 2002 [iw = fexp], by(anio)
    format $important_variable2 %9.2f
    rename $important_variable2 ${important_variable2}_nac
    * Combinar con datos urbanos
    merge 1:1 anio using `urb', nogen
    merge 1:1 anio using `rural', nogen
    list
    * Generar gráfico de líneas para informal2
    twoway (line ${important_variable2}_nac anio)  ///
           (line ${important_variable2}_urb anio if anio >= 2000) ///
           (line ${important_variable2}_rural anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano" 3 "Rural"))  ///
           yscale(range(0.6 1)) ylabel(#5, format(%9.2f)) ///
           xscale(range(2001 2024)) xlabel(2001(3)2024) ///
           name(informal2_nac_urb, replace)
    graph export "$out_results/informal2_nac_urb.png", replace
restore

s
* ============================================================
* GRÁFICOS DESAGREGADOS POR GÉNERO
* ============================================================

* ============================================================
* Gráfico de informalidad urbana por sexo (todos los años). Se considera desde 2001 porque sino el área del gráfico en el año 2000 genera confusión en la interpretación.
preserve 
    keep if area == 1 & anio >= 2001
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio sexo)
    reshape wide informal2 N, i(anio) j(sexo)

    * errores estándar
    gen se_h = sqrt((informal21*(1-informal21))/N1)
    gen se_m = sqrt((informal22*(1-informal22))/N2)

    * IC
    gen ub_h = informal21 + 1.96*se_h
    gen lb_h = informal21 - 1.96*se_h
    gen ub_m = informal22 + 1.96*se_m
    gen lb_m = informal22 - 1.96*se_m
    replace ub_h = min(ub_h,1)
    replace lb_h = max(lb_h,0)
    replace ub_m = min(ub_m,1)
    replace lb_m = max(lb_m,0)
	* Tabla con IC
	list anio informal21 se_h ub_h lb_h ///
     informal22 se_m ub_m lb_m, sepby(anio)
	
	* Diferencia (Hombre - Mujer)
	gen diff = informal21 - informal22
	gen se_diff = sqrt(se_h^2 + se_m^2)
	gen z = diff / se_diff
	gen p_value = 2 * normal(-abs(z))
	gen diff_sig = p_value < 0.05
	* Mostrar lista y años donde la diferencia es significativa
	list anio diff p_value if diff_sig, noobs

	*Gráfico
    twoway ///
        (rarea ub_h lb_h anio, sort color(navy%35)) ///
        (line informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_m lb_m anio, sort color(maroon%35)) ///
        (line informal22 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "Hombre" 4 "Mujer")) ///
        xlabel(2001(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.8 1)) ///
        graphregion(color(white)) ///
        note("Nota:Los intervalos de confianza al 95% aproximados usando varianza de proporción: SE = sqrt[p(1-p)/N]. " ///
             "Debido al gran tamaño muestral, los intervalos son muy estrechos y pueden no ser visibles.", size(small)) ///
        name(informal2_sexo_ci_area, replace)

*    graph export "$out_results/informal2_sexo_IC1.png", replace

restore

*La mayoría de los años la informalidad femenina es mayor (diferencia negativa), excepto 2006 y 2010 donde ocurre lo contrario. La brecha máxima es de alrededor de 6.5 puntos porcentuales (2002) y la mínima de 0.2 puntos (2005). Con estos tamaños de muestra, todas las diferencias son estadísticamente significativas. 

	 
* Gráfico de informalidad por sexo desde el año 2001. Es igual al anterior debido a usar los datos desde 2001.

* ============================================================
* GRÁFICO DE BARRAS: INFORMALIDAD POR PROVINCIA EN 2024
* ============================================================

	* Codificar variable provincia de string a numérica
	encode provincia, gen(provincia_enc)
	drop provincia
	rename provincia_enc provincia

	* Definir etiquetas de valor para las provincias de Ecuador
	capture label define provincia_lbl ///
		01 "Azuay" ///
		02 "Bolívar" ///
		03 "Cañar" ///
		04 "Carchi" ///
		05 "Cotopaxi" ///
		06 "Chimborazo" ///
		07 "El Oro" ///
		08 "Esmeraldas" ///
		09 "Guayas" ///
		10 "Imbabura" ///
		11 "Loja" ///
		12 "Los Ríos" ///
		13 "Manabí" ///
		14 "Morona Santiago" ///
		15 "Napo" ///
		16 "Pastaza" ///
		17 "Pichincha" ///
		18 "Tungurahua" ///
		19 "Zamora Chinchipe" ///
		20 "Galápagos" ///
		21 "Sucumbíos" ///
		22 "Orellana" ///
		23 "Santo Domingo de los Tsáchilas" ///
		24 "Santa Elena" ///
		90 "Zonas no delimitadas"

	* Aplicar etiquetas a la variable provincia
	label values provincia provincia_lbl

	preserve
    keep if anio == 2024
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(provincia)

    * error estándar
    gen se = sqrt((informal2*(1-informal2))/N)

    * intervalos
    gen ub = informal2 + 1.96*se
    gen lb = informal2 - 1.96*se
    replace ub = min(ub,1)
    replace lb = max(lb,0)

    * ordenar
    gsort -informal2

	 * tabla completa
    list provincia informal2 se ub lb, sepby(provincia)
    * resumen de precisión
    sum se

***** Prueba de diferencias: provincias vs una de referencia
	* Indicar el nombre o código (numérico)
	local ref_cod = 17

	* Obtener tasa y error estándar de la provincia de referencia
	sum informal2 if provincia == `ref_cod', meanonly
	local ref_mean = r(mean)
	sum se if provincia == `ref_cod', meanonly
	local ref_se = r(mean)
	di "Comparando con provincia código `ref_cod' (tasa = `ref_mean')"

	* Crear variables para resultados
	gen diff_vs_ref = .
	gen se_diff_vs_ref = .
	gen p_vs_ref = .
	gen sig_vs_ref = .

	* Recorrer todas las provincias excepto la de referencia
	foreach prov in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 90 {
		if `prov' != `ref_cod' {
			sum informal2 if provincia == `prov', meanonly
			local prov_mean = r(mean)
			sum se if provincia == `prov', meanonly
			local prov_se = r(mean)
			
			local diff = `prov_mean' - `ref_mean'
			local se_diff = sqrt(`prov_se'^2 + `ref_se'^2)
			local z = `diff' / `se_diff'
			local p = 2 * normal(-abs(`z'))
			
			replace diff_vs_ref = `diff' if provincia == `prov'
			replace se_diff_vs_ref = `se_diff' if provincia == `prov'
			replace p_vs_ref = `p' if provincia == `prov'
			replace sig_vs_ref = (`p' < 0.05) if provincia == `prov'
		}
	}

	* Mostrar tabla comparando la provincia y ver si hay diferencia estadísticamente significativa
	list provincia informal2 diff_vs_ref p_vs_ref sig_vs_ref if provincia != `ref_cod', sep(0)

    * gráfico con IC (tipo barras + bigotes)
    twoway ///
        (bar informal2 provincia, horizontal barwidth(0.6) color(navy)) ///
        (rcap ub lb provincia, horizontal lcolor(black)), ///
        ylabel(, valuelabel angle(0) labsize(small)) ///
        xlabel(0.6(0.05)1, format(%9.2f)) ///
        xscale(range(0.6 1))  ///
		xtitle("Informalidad") ///
        legend(off) ///
        graphregion(color(white)) ///
        title("Informalidad por provincia - 2024", size(medium)) ///
        note("Nota: IC al 95% usando SE = sqrt[p(1-p)/N]. Los tamaños muestrales varían por provincia.", size(small)) ///
        name(informal2_provincia_ci_2024, replace)

*    graph export "$out_results/informal2_provincia_ci_2024.png", replace

restore

*Al comparar la informalidad de cada provincia con la de "Pichincha", hay diferencias estadísticamente significativas en todos los casos (p < 0.001). Las provincias con mayor diferencia positiva superan a "Pichincha" hasta en 21.1 puntos porcentuales (Orellana), mientras que Galápagos presenta una diferencia negativa de -8.5 puntos porcentuales."

* ============================================================
* GRÁFICO INFORMALIDAD POR EDAD
* ============================================================

* Generate categorical age variable with three groups
gen age_cat = .
replace age_cat = 1 if edad >= 18 & edad <= 29
replace age_cat = 2 if edad >= 30 & edad <= 64
replace age_cat = 3 if edad >= 65 & edad < 98

* Label the variable and its values
label variable age_cat "Age category"
label define age_cat_lbl 1 "18-29" 2 "30-64" 3 "65+"
label values age_cat age_cat_lbl

* Check the results
tab age_cat

* Gráfico de informalidad por edad desde el año 2000 - nacional
preserve 
    keep if anio >= 2001
    drop if missing(age_cat)          // Elimina observaciones con edad missing
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio age_cat)

    * reshape para separar grupos
    reshape wide informal2 N, i(anio) j(age_cat)

    * errores estándar (usando N como número de observaciones NO ponderado)
    * NOTA: Este cálculo subestima el error estándar si hay ponderaciones.
    gen se_1 = sqrt((informal21*(1-informal21))/N1)
    gen se_2 = sqrt((informal22*(1-informal22))/N2)
    gen se_3 = sqrt((informal23*(1-informal23))/N3)

    * IC
    gen ub_1 = informal21 + 1.96*se_1
    gen lb_1 = informal21 - 1.96*se_1

    gen ub_2 = informal22 + 1.96*se_2
    gen lb_2 = informal22 - 1.96*se_2

    gen ub_3 = informal23 + 1.96*se_3
    gen lb_3 = informal23 - 1.96*se_3

    * límites válidos 
    foreach var in ub_1 ub_2 ub_3 {
        replace `var' = min(`var', 1)
    }
    foreach var in lb_1 lb_2 lb_3 {
        replace `var' = max(`var', 0)
    }
	
    * tabla completa de intervalos de confianza
    list anio ///
         informal21 se_1 ub_1 lb_1 ///
         informal22 se_2 ub_2 lb_2 ///
         informal23 se_3 ub_3 lb_3, sepby(anio)
    * resumen tabla intervalos de confianza
    sum se_1 se_2 se_3

*****Diferencias estadísticas entre grupos
	* Diferencia 18-29 vs 30-64
	gen diff_1v2 = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2 = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2 = (p_1v2 < 0.05)
    
	* Diferencia 18-29 vs 65+
	gen diff_1v3 = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3 = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3 = (p_1v3 < 0.05)
    
	* Diferencia 30-64 vs 65+
	gen diff_2v3 = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3 = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3 = (p_2v3 < 0.05)
    
	* Mostrar años donde alguna diferencia NO es significativa (si existe)
    list anio diff_1v2 p_1v2 sig_1v2 diff_1v3 p_1v3 sig_1v3 diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
		 
    * gráfico con áreas
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (line informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (line informal22 anio, sort lcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (line informal23 anio, sort lcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.75 1)) ///
        graphregion(color(white)) ///
        note("IC 95% usando SE = sqrt[p(1-p)/N]. Intervalos muy estrechos por gran tamaño muestral.", size(small)) ///
        name(informal2_edad_ci, replace)

   * graph export "$out_results/informal2_edad_IC.png", replace

restore
*Al comparar grupos etarios, se encuentra que la diferencia entre jóvenes (18-29) y adultos de mediana edad (30-64) no es estadísticamente significativa en los años 2016 y 2017 (p > 0.05), mientras que en el resto del período sí lo es. En cambio, las diferencias entre jóvenes y adultos mayores (65+), y entre mediana edad y adultos mayores, son significativas en todos los años (p < 0.05).


* Gráfico de informalidad por edad - urbano
preserve 
    keep if area == 1
    keep if anio >= 2001 & anio <= 2024
    drop if missing(age_cat)
    gen uno = 1 
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio age_cat)
    
    * Reshape a ancho para tener grupos por edad
    reshape wide informal2 N, i(anio) j(age_cat)
    
    * Errores estándar (fórmula de proporción simple)
    gen se_1 = sqrt((informal21*(1-informal21))/N1)
    gen se_2 = sqrt((informal22*(1-informal22))/N2)
    gen se_3 = sqrt((informal23*(1-informal23))/N3)
    
    * Intervalos de confianza al 95%
    foreach g in 1 2 3 {
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    * Tabla completa de IC
    list anio ///
         informal21 se_1 ub_1 lb_1 ///
         informal22 se_2 ub_2 lb_2 ///
         informal23 se_3 ub_3 lb_3, sepby(anio)
    
    * Resumen de errores estándar
    sum se_1 se_2 se_3

*****Diferencias estadísticas entre grupos etarios (urbano)
	* Diferencia 18-29 vs 30-64
	gen diff_1v2 = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2 = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2 = (p_1v2 < 0.05)
    
    * Diferencia 18-29 vs 65+
    gen diff_1v3 = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3 = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3 = (p_1v3 < 0.05)
    
    * Diferencia 30-64 vs 65+
    gen diff_2v3 = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3 = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3 = (p_2v3 < 0.05)
    
    * Mostrar años donde alguna diferencia NO es significativa (si existe)
    list anio diff_1v2 p_1v2 sig_1v2 ///
         diff_1v3 p_1v3 sig_1v3 ///
         diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)

    * Gráfico con bandas y líneas, con zoom en Y (rango ajustado según los datos urbanos)
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (line informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (line informal22 anio, sort lcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (line informal23 anio, sort lcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.7 0.95))                      ///
        graphregion(color(white))                    ///
        note("IC 95% basado en SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_edad_urb_IC, replace)
    
    *graph export "$out_results/informal2_edad_urb_IC.png", replace
restore  
	
*En zona urbana, la brecha de informalidad entre jóvenes (18-29) y adultos de mediana edad (30-64) solo fue estadísticamente no significativa en el año 2005 (p = 0.466). En todos los demás años, las diferencias entre estos dos grupos son significativas, al igual que las diferencias de ambos con el grupo de adultos mayores (65+), que se mantienen significativas en todo el período.	 
 
* ============================================================
* GRÁFICO INFORMALIDAD POR ETNIA
* ============================================================

* Gráfico de informalidad por etnia desde el año 2000 - nacional
preserve 
    keep if anio >= 2000 & anio <= 2024
    drop if missing(etnia_arm)
    gen uno = 1 
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio etnia_arm)
    
    * Verificar valores únicos de etnia_arm (asumo 1, 2, 3)
    tab etnia_arm
    
    * Reshape a ancho
    reshape wide informal2 N, i(anio) j(etnia_arm)
    
    * Errores estándar e IC 95% para cada grupo
    foreach g in 1 2 3 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
   
	* Tabla completa
    list anio ///
         informal21 se_1 ub_1 lb_1 ///
         informal22 se_2 ub_2 lb_2 ///
         informal23 se_3 ub_3 lb_3, sepby(anio)
    
    * Resumen de errores estándar
    sum se_1 se_2 se_3

****Diferencias estadísticas entre grupos étnicos
	* Diferencia: Indígena (1) vs Negro/Afro (2)
    gen diff_1v2 = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2 = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2 = (p_1v2 < 0.05)
    
    * Diferencia: Indígena (1) vs Blanco/Mestizo (3)
    gen diff_1v3 = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3 = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3 = (p_1v3 < 0.05)
    
    * Diferencia: Negro/Afro (2) vs Blanco/Mestizo (3)
    gen diff_2v3 = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3 = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3 = (p_2v3 < 0.05)
    
    * Mostrar años donde alguna diferencia NO es significativa (si existe)
    list anio diff_1v2 p_1v2 sig_1v2 ///
         diff_1v3 p_1v3 sig_1v3 ///
         diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
		 
    * Gráfico con bandas de confianza y zoom en eje Y
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (line informal21 anio, sort lcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (line informal22 anio, sort lcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (line informal23 anio, sort lcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afro" 6 "Blanco/Mestizo")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.75 0.95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por etnia (Nacional)", size(med))  ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Años 2000-2024.", size(small)) ///
        name(informal2_etnia_nac_IC, replace)
    
    *graph export "$out_results/informal2_etnia_nac_IC.png", replace 
restore 

*Hay diferencia estadísticamente significativa entre grupos étnicos a nivel nacional. Tanto la etnica indígea y Afro tienen mayor informalidad que el grupo Blanco-Mestizo.

* Gráfico de informalidad por etnia - urbano
preserve 
    keep if area == 1
    keep if anio >= 2000 & anio <= 2024
    drop if missing(etnia_arm)
    
    gen uno = 1
    
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio etnia_arm)
    
    * Verificar categorías de etnia_arm (1,2,3)
    tab etnia_arm
    
    * Reshape a ancho
    reshape wide informal2 N, i(anio) j(etnia_arm)
    
    * Errores estándar e IC 95%
    foreach g in 1 2 3 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    
	* Tabla completa IC 
    list anio ///
         informal21 se_1 ub_1 lb_1 ///
         informal22 se_2 ub_2 lb_2 ///
         informal23 se_3 ub_3 lb_3, sepby(anio)
    
    * Resumen de errores estándar
    sum se_1 se_2 se_3 
	
****Diferencias Estadísticas Entre Grupos Étnicos (Urbano)
	* Diferencia: Indígena (1) vs Negro/Afro (2)
	gen diff_1v2 = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2 = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2 = (p_1v2 < 0.05)
    
    * Diferencia: Indígena (1) vs Blanco/Mestizo (3)
    gen diff_1v3 = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3 = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3 = (p_1v3 < 0.05)
    
    * Diferencia: Negro/Afro (2) vs Blanco/Mestizo (3)
    gen diff_2v3 = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3 = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3 = (p_2v3 < 0.05)
    
    * Mostrar años donde alguna diferencia NO es significativa (si existe)
    list anio diff_1v2 p_1v2 sig_1v2 ///
         diff_1v3 p_1v3 sig_1v3 ///
         diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
    * Gráfico con bandas de confianza y zoom en Y
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (line informal21 anio, sort lcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (line informal22 anio, sort lcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (line informal23 anio, sort lcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afro" 6 "Blanco/Mestizo")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.75 0.95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por etnia (Urbano)", size(med))   ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_etnia_urb_IC, replace)
    
   * graph export "$out_results/informal2_etnia_urb_IC.png", replace
      
restore

*Hay diferencia estadísticamente significativa entre grupos étnicos a nivel nacional urbano. Tanto la etnica indígea y Afro tienen mayor informalidad que el grupo Blanco-Mestizo.

* ============================================================
* GRÁFICO INFORMALIDAD POR EDUCACION
* ============================================================

* Gráfico de informalidad por educación desde el año 2000 - nacional
preserve 
    keep if anio >= 2001 & anio <= 2024
    drop if missing(educ_univ)
    
    gen uno = 1
    
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio educ_univ)
    
    * Verificar categorías de educ_univ (0 = No universitaria, 1 = Universitaria)
    tab educ_univ
    
    * Reshape a ancho
    reshape wide informal2 N, i(anio) j(educ_univ)
    
    * Errores estándar e IC 95% para cada grupo
    foreach g in 0 1 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
     * Tabla completa IC
    list anio ///
         informal20 se_0 ub_0 lb_0 ///
         informal21 se_1 ub_1 lb_1, sepby(anio)
    
    * Resumen de errores estándar
    sum se_0 se_1
	
	 * Diferencia: No universitaria (0) vs Universitaria (1)
    gen diff = informal20 - informal21
    gen se_diff = sqrt(se_0^2 + se_1^2)
    gen p_value = 2 * normal(-abs(diff / se_diff))
    gen sig = (p_value < 0.05)
    
    * Mostrar años donde la diferencia NO es significativa (si existe)
    list anio diff p_value sig if !sig, noobs sep(0)
	
    * Gráfico con bandas de confianza y zoom en Y
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (line informal20 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (line informal21 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.5 0.95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por educación (Nacional)", size(med)) ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Años 2000-2024.", size(small)) ///
        name(informal2_educ_nac_IC, replace)
    
*    graph export "$out_results/informal2_educ_nac_IC.png", replace
    
restore

* La informalidad es consistentemente mayor entre las personas sin educación universitaria que entre aquellas con educación universitaria durante todo el período 2001‑2024. La diferencia es estadísticamente significativa (p < 0.001) en cada año.

* Gráfico de informalidad por educación - urbano
preserve 
    keep if area == 1
    keep if anio >= 2001 & anio <= 2024
    drop if missing(educ_univ)
    
    gen uno = 1
    
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(anio educ_univ)
    
    * Verificar categorías (0 = No universitaria, 1 = Universitaria)
    tab educ_univ
    
    * Reshape a ancho
    reshape wide informal2 N, i(anio) j(educ_univ)
    
    * Errores estándar e IC 95%
    foreach g in 0 1 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }

	 * Tabla completa IC
    list anio ///
         informal20 se_0 ub_0 lb_0 ///
         informal21 se_1 ub_1 lb_1, sepby(anio)
    
    * Resumen de errores estándar
    sum se_0 se_1
	
	* Diferencia: No universitaria (0) vs Universitaria (1)
	gen diff = informal20 - informal21
    gen se_diff = sqrt(se_0^2 + se_1^2)
    gen p_value = 2 * normal(-abs(diff / se_diff))
    gen sig = (p_value < 0.05)
    
    * Mostrar años donde la diferencia NO es significativa (si existe)
    list anio diff p_value sig if !sig, noobs sep(0)
    
    * Gráfico con bandas y zoom en Y
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (line informal20 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (line informal21 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(0.5 0.95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por educación (Urbano)", size(med)) ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_educ_urb_IC, replace)
    
  *  graph export "$out_results/informal2_educ_urb_IC.png", replace
    
restore

*Las personas sin educación universitaria tienen una informalidad estadísticamente significativa en comparaciólas que sí la tienen.


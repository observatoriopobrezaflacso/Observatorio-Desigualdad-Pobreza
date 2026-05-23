*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
*------------------------------------------------------------------*

clear all
set more off

* Definición de rutas globales para acceder a las bases de datos
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
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
global important_variable3 informal2_sim
global important_variable4 informal1_sim

* Cargar base de datos de trabajo
use "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago/base_trabajo.dta", clear

* Eliminar observaciones del año 2025
*drop if anio == 2025

replace area = 1 if area == .

* Definir lista de variables relevantes para análisis de informalidad
local vars affiliated_iess adec cuenta_propia tiene_ruc tamano_armonizado no_remunerado

* Generar tabulaciones de cada variable por año para control
foreach var of local vars {
    di "`var'"	
    tab anio `var'
}


* ============================================================
**# INFORMALIDAD 1
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
**# INFORMALIDAD 1 SIM
* ============================================================
* Crear variable informal1 basada en cuatro criterios:
* - No afiliado al IESS
* - Trabajo no adecuado con criterio SBU 2025 retropolado a la serie
* - Trabajador no remunerado
* - Empleado doméstico
gen informal1_sim = ///
				  affiliated_iess    == 0 | ///
				  adec_sim           == 0 | ///
				  no_remunerado      == 1 
				 
* Asignar missing si alguna de las variables componentes es missing
replace informal1_sim = . if inlist(., affiliated_iess, adec_sim, no_remunerado)				 

* ============================================================
**#  INFORMALIDAD 2
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
replace informal2 = . if inlist(., affiliated_iess, adec,  tiene_ruc, tamano_armonizado)

* ============================================================
**#  INFORMALIDAD 2 SIM
* ============================================================
* Crear variable informal2_sim con criterios alternativos:
* - No afiliado al IESS
* - Trabajo no adecuado con criterio SBU 2025 retropolado a la serie
* - Clasificación informal nueva
* - Trabajador doméstico no remunerado
				 
gen informal2_sim =  ///
				 affiliated_iess        == 0 | ///
				 adec_sim               == 0 | ///
				 no_remunerado          == 1 | ///
				 (tiene_ruc == 0) 
				 
replace informal2_sim = . if inlist(., affiliated_iess, adec_sim,  tiene_ruc, tamano_armonizado)
s			
				
* ===============================================================
**# INFORMALIDAD CON Y SIN RUC 
* ===============================================================
				 
* Calcular promedio nacional de informalidad por año
preserve
    collapse (mean) informal1 informal2, by(anio)
    replace informal1 = informal1 * 100
    replace informal2 = informal2 * 100
    format informal1 %9.2f
    format informal2 %9.2f
    * Generar gráfico de líneas comparando tendencia nacional vs urbana
    twoway (connected informal1 anio) /// 
	       (connected informal2 anio if anio >= 2001),  ///
		   legend(order(1 "Informalidad sin criterio RUC" 2 "Informalidad con criterio RUC") position(6) ring(1)) ///
           yscale(range(0 100)) ylabel(#5, format(%9.2f)) ///
           xscale(range(1990 2025)) xlabel(1990(2)2025, angle(90)) ///
           name(informal1_nac_urb, replace)
    graph export "$out_results/informal1_nac_urb.png", replace
restore




* ===============================================================
**# INFORMALIDAD CON Y SIN RUC Y CON Y SIN EMPLEO ADECUADO SIMULADO
* ===============================================================


* Calcular promedio nacional de informalidad por año
preserve
    collapse (mean) informal1 informal2 ///
					informal2_sim informal1_sim, by(anio)
    replace informal1 = informal1 * 100
    replace informal2 = informal2 * 100
    replace informal2_sim = informal2_sim * 100
    replace informal1_sim = informal1_sim * 100
    format informal1 %9.2f
    format informal2 %9.2f
    format informal2_sim %9.2f
    format informal1_sim %9.2f
    
    * Panel 1: Con criterio RUC
    twoway (connected informal2 anio  if anio >= 2001) ///
           (connected informal2_sim anio if anio >= 2001), ///
           legend(order(1 "Informalidad" ///
                        2 "Informalidad con empleo adecuado simulado") ///
                  position(6) ring(1) rows(2)) ///
           yscale(range(0 100)) ylabel(#5, format(%9.2f)) ///
           xscale(range(2001 2025)) xlabel(2001(2)2025, angle(90)) ///
           title("Con criterio RUC") ///
           name(informal_ruc, replace)
    
    * Panel 2: Sin criterio RUC
    twoway (connected informal1 anio) ///
           (connected informal1_sim anio), ///
           legend(order(1 "Informalidad" ///
                        2 "Informalidad con empleo adecuado simulado") ///
                  position(6) ring(1) rows(2)) ///
           yscale(range(0 100)) ylabel(#5, format(%9.2f)) ///
           xscale(range(1990 2025)) xlabel(1991(2)2025, angle(90)) ///
           title("Sin criterio RUC") ///
           name(informal_no_ruc, replace)
    
    * Combinar los dos paneles
    graph combine informal_ruc informal_no_ruc, ///
        title("Tendencia nacional de informalidad") ///
        name(informal1_nac_urb, replace)
    graph export "$out_results/informal1_nac_urb.png", replace
restore

		 
* ============================================================
**# INFORMALIDAD URBANA VS NACIONAL
* ============================================================


*::::::::::::::::::::: SIN CRITERIO RUC :::::::::::::::::::::

* Calcular promedio de informalidad por año y área (urbano/rural)
preserve
    collapse (mean) informal1, by(anio area)
    replace informal1 = informal1 * 100
    list
    format informal1 %9.2f
    * Mantener solo área urbana (area == 1)
    keep if area == 1
    rename informal1 ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    keep if anio >= 2001
    collapse (mean) informal1  if anio != 2002 [iw = fexp], by(anio area)
    replace informal1 = informal1 * 100
    list
    format informal1 %9.2f
    * Mantener solo área urbana
    keep if area == 2
    rename informal1 ${important_variable}_rural
    tempfile rural
    save `rural', replace
restore

* Calcular promedio nacional de informalidad por año
preserve
    collapse (mean) informal1, by(anio)
    replace informal1 = informal1 * 100
    format informal1 %9.2f
    rename informal1 ${important_variable}_nac
    * Combinar con datos urbanos
    merge 1:1 anio using `urb', nogen
    merge 1:1 anio using `rural', nogen
    list
    * Generar gráfico de líneas comparando tendencia nacional vs urbana
    twoway (connected ${important_variable}_nac anio)  ///
           (connected ${important_variable}_urb anio if anio >= 2000) ///
           (connected ${important_variable}_rural anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano" 3 "Rural"))  ///
           yscale(range(0 100)) ylabel(#5, format(%9.2f)) ///
           xscale(range(2001 2024)) xlabel(2001(3)2024) ///
           name(informal1_nac_urb, replace)
    graph export "$out_results/informal1_nac_urb.png", replace
restore


*::::::::::::::::::::: CON CRITERIO RUC :::::::::::::::::::::

* Calcular promedio ponderado de informal2 por año y área (2007-2024)
preserve
    keep if anio >= 2001
    collapse (mean) informal2  if anio != 2002 [iw = fexp], by(anio area)
    replace informal2 = informal2 * 100
    list
    format informal2 %9.2f
    * Mantener solo área urbana
    keep if area == 1
    rename informal2 ${important_variable2}_urb
    tempfile urb
    save `urb'
restore

preserve
    keep if anio >= 2001
    collapse (mean) informal2  if anio != 2002 [iw = fexp], by(anio area)
    replace informal2 = informal2 * 100
    list
    format informal2 %9.2f
    * Mantener solo área urbana
    keep if area == 2
    rename informal2 ${important_variable2}_rural
    tempfile rural
    save `rural', replace
restore

* Calcular promedio nacional ponderado de informal2 (2007-2024)
preserve
    keep if anio >= 2001
    collapse (mean) informal2 if anio != 2002 [iw = fexp], by(anio)
    replace informal2 = informal2 * 100
    format informal2 %9.2f
    rename informal2 ${important_variable2}_nac
    * Combinar con datos urbanos
    merge 1:1 anio using `urb', nogen
    merge 1:1 anio using `rural', nogen
    list
    * Generar gráfico de líneas para informal2
    twoway (connected ${important_variable2}_nac anio)  ///
           (connected ${important_variable2}_urb anio if anio >= 2000) ///
           (connected ${important_variable2}_rural anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano" 3 "Rural"))  ///
           yscale(range(60 100)) ylabel(#5, format(%9.2f)) ///
           xscale(range(2001 2024)) xlabel(2001(3)2024) ///
           name(informal2_nac_urb, replace)
    graph export "$out_results/informal2_nac_urb.png", replace
restore


* ============================================================
**# GRÁFICOS DESAGREGADOS POR GÉNERO
* ============================================================

* ============================================================
* Gráfico de informalidad urbana por sexo (todos los años). Se considera desde 2001 porque sino el área del gráfico en el año 2000 genera confusión en la interpretación.
preserve
    keep if area == 1 & anio >= 2001
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(anio sexo)
    reshape wide informal2 N, i(anio) j(sexo)
    * errores estándar (calculados antes de escalar a porcentaje)
    gen se_h = sqrt((informal21*(1-informal21))/N1)
    gen se_m = sqrt((informal22*(1-informal22))/N2)

    * IC (calculados antes de escalar a porcentaje)
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	replace informal21 = informal21 * 100
	replace informal22 = informal22 * 100
	replace ub_h = ub_h * 100
	replace lb_h = lb_h * 100
	replace ub_m = ub_m * 100
	replace lb_m = lb_m * 100

	*Gráfico
    twoway ///
        (rarea ub_h lb_h anio, sort color(navy%35)) ///
        (connected informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_m lb_m anio, sort color(maroon%35)) ///
        (connected informal22 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "Hombre" 4 "Mujer")) ///
        xlabel(2001(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(80 100)) ///
        graphregion(color(white)) ///
        note("Nota:Los intervalos de confianza al 95% aproximados usando varianza de proporción: SE = sqrt[p(1-p)/N]. " ///
             "Debido al gran tamaño muestral, los intervalos son muy estrechos y pueden no ser visibles.", size(small)) ///
        name(informal2_sexo_ci_area, replace)
		
    graph export "$out_results/informal2_sexo_IC1.png", replace
restore

*La mayoría de los años la informalidad femenina es mayor (diferencia negativa), excepto 2006 y 2010 donde ocurre lo contrario. La brecha máxima es de alrededor de 6.5 puntos porcentuales (2002) y la mínima de 0.2 puntos (2005). Con estos tamaños de muestra, todas las diferencias son estadísticamente significativas. 

	 
**# Gráfico de informalidad por sexo desde el año 2001. Es igual al anterior debido a usar los datos desde 2001.

* ============================================================
**# GRÁFICO DE BARRAS: INFORMALIDAD POR PROVINCIA EN 2024
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
    keep if anio == 2025
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp], by(provincia)

    * error estándar (calculado antes de escalar)
    gen se = sqrt((informal2*(1-informal2))/N)

    * intervalos (calculados antes de escalar)
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	replace informal2 = informal2 * 100
	replace ub = ub * 100
	replace lb = lb * 100

    * gráfico con IC (tipo barras + bigotes)
    twoway ///
        (bar informal2 provincia, horizontal barwidth(0.6) color(navy)) ///
        (rcap ub lb provincia, horizontal lcolor(black)), ///
        ylabel(, valuelabel angle(0) labsize(small)) ///
        xlabel(60(5)100, format(%9.2f)) ///
        xscale(range(60 100))  ///
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
**# TABLA LATEX: INFORMALIDAD POR PROVINCIA - 2000-2025 (cada 5 años)
* ============================================================

preserve
    keep if inlist(anio, 2001, 2005, 2010, 2015, 2020, 2025)
    drop if provincia == 25
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(provincia anio)
    
    * Renombrar para evitar problemas con reshape (variable termina en número)
    rename informal2 inf
    
    * Reshape para tener años en columnas
    keep provincia anio inf
    reshape wide inf, i(provincia) j(anio)
    
    * Ordenar por informalidad en 2025 (descendente)
    gsort -inf2025
    
    * Exportar a LaTeX
    capture file close tex
    file open tex using "$out_results/informalidad_provincia.tex", write replace
    
    file write tex "\begin{table}[htbp]" _n
    file write tex "\centering" _n
    file write tex "\caption{Tasa de informalidad por provincia, Ecuador}" _n
    file write tex "\label{tab:informal_prov}" _n
    file write tex "\begin{tabular}{lcccccc}" _n
    file write tex "\hline\hline" _n
    file write tex "Provincia & 2001 & 2005 & 2010 & 2015 & 2020 & 2025 \\" _n
    file write tex "\hline" _n
    
    local nobs = _N
    forvalues i = 1/`nobs' {
        local prov : label (provincia) `=provincia[`i']'
        
        local v00 = inf2001[`i']
        local v05 = inf2005[`i']
        local v10 = inf2010[`i']
        local v15 = inf2015[`i']
        local v20 = inf2020[`i']
        local v25 = inf2025[`i']
        
        local f00 = cond(missing(`v00'), "--", string(`v00', "%6.3f"))
        local f05 = cond(missing(`v05'), "--", string(`v05', "%6.3f"))
        local f10 = cond(missing(`v10'), "--", string(`v10', "%6.3f"))
        local f15 = cond(missing(`v15'), "--", string(`v15', "%6.3f"))
        local f20 = cond(missing(`v20'), "--", string(`v20', "%6.3f"))
        local f25 = cond(missing(`v25'), "--", string(`v25', "%6.3f"))
        
        file write tex "`prov' & `f00' & `f05' & `f10' & `f15' & `f20' & `f25' \\" _n
    }
    
    file write tex "\hline\hline" _n
    file write tex "\end{tabular}" _n
    file write tex "\end{table}" _n
    file close tex
    
    display "Tabla exportada a: informalidad_provincia.tex"
    list provincia inf2001 inf2005 inf2010 inf2015 inf2020 inf2025, sep(0)
restore



preserve
keep if inlist(anio, 2001, 2005, 2010, 2015, 2020, 2025)
drop if provincia == 25
gen uno = 1
replace informal2 = informal2*100
* Calcular media, desviación estándar y N para obtener el margen de error
collapse (mean) informal2 (sd) sd_inf=informal2 (rawsum) N=uno [iw = fexp], by(provincia anio)

* Calcular error estándar y semi-amplitud del IC al 95%
gen se_inf = sd_inf / sqrt(N)
gen hci = 1.96 * se_inf

* Renombrar para evitar problemas con reshape
rename informal2 inf
rename hci hci_inf

* Reshape para tener años en columnas (tanto la estimación como la semi-amplitud)
keep provincia anio inf hci_inf
reshape wide inf hci_inf, i(provincia) j(anio)

* Ordenar por informalidad en 2025 (descendente)
gsort -inf2025

* Exportar a LaTeX
capture file close tex
file open tex using "$out_results/informalidad_provincia.tex", write replace

file write tex "\begin{table}[htbp]" _n
file write tex "\centering" _n
file write tex "\caption{Tasa de informalidad por provincia, Ecuador (semi-amplitud del IC 95\% entre paréntesis)}" _n
file write tex "\label{tab:informal_prov}" _n
file write tex "\begin{tabular}{lcccccc}" _n
file write tex "\hline\hline" _n
file write tex "Provincia & 2001 & 2005 & 2010 & 2015 & 2020 & 2025 \\" _n
file write tex "\hline" _n

local nobs = _N
forvalues i = 1/`nobs' {
    local prov : label (provincia) `=provincia[`i']'
    
    foreach yr in 2001 2005 2010 2015 2020 2025 {
        local v`yr' = inf`yr'[`i']
        local h`yr' = hci_inf`yr'[`i']
        
        if missing(`v`yr'') {
            local f`yr' = "--"
        }
        else {
            local f`yr' = string(`v`yr'', "%4.1f") + " (" + string(`h`yr'', "%4.1f") + ")"
        }
    }
    
    file write tex "`prov' & `f2001' & `f2005' & `f2010' & `f2015' & `f2020' & `f2025' \\" _n
}

file write tex "\hline\hline" _n
file write tex "\multicolumn{7}{l}{\footnotesize Semi-amplitud del intervalo de confianza al 95\% entre paréntesis.} \\" _n
file write tex "\end{tabular}" _n
file write tex "\end{table}" _n
file close tex

display "Tabla exportada a: informalidad_provincia.tex"
list provincia inf2001 hci_inf2001 inf2025 hci_inf2025, sep(0)

restore





* ============================================================
**# GRÁFICO INFORMALIDAD POR EDAD
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
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(anio age_cat)

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

	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}
		 
    * gráfico con áreas
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (connected informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (connected informal22 anio, sort lcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (connected informal23 anio, sort lcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2000(1)2025, angle(90)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(75 100)) ///
        graphregion(color(white)) ///
        note("IC 95% usando SE = sqrt[p(1-p)/N]. Intervalos muy estrechos por gran tamaño muestral.", size(small)) ///
        name(informal2_edad_ci, replace)

   graph export "$out_results/informal2_edad_IC.png", replace

restore
*Al comparar grupos etarios, se encuentra que la diferencia entre jóvenes (18-29) y adultos de mediana edad (30-64) no es estadísticamente significativa en los años 2016 y 2017 (p > 0.05), mientras que en el resto del período sí lo es. En cambio, las diferencias entre jóvenes y adultos mayores (65+), y entre mediana edad y adultos mayores, son significativas en todos los años (p < 0.05).


* Gráfico de informalidad por edad - urbano
preserve 
    keep if area == 1
    keep if anio >= 2001 & anio <= 2024
    drop if missing(age_cat)
    gen uno = 1 
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(anio age_cat)
    
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}

    * Gráfico con bandas y líneas, con zoom en Y (rango ajustado según los datos urbanos)
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (connected informal21 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (connected informal22 anio, sort lcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (connected informal23 anio, sort lcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(70 95))                      ///
        graphregion(color(white))                    ///
        note("IC 95% basado en SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_edad_urb_IC, replace)
    
    *graph export "$out_results/informal2_edad_urb_IC.png", replace
restore  
	
*En zona urbana, la brecha de informalidad entre jóvenes (18-29) y adultos de mediana edad (30-64) solo fue estadísticamente no significativa en el año 2005 (p = 0.466). En todos los demás años, las diferencias entre estos dos grupos son significativas, al igual que las diferencias de ambos con el grupo de adultos mayores (65+), que se mantienen significativas en todo el período.	 
 
* ============================================================
**# GRÁFICO INFORMALIDAD POR ETNIA
* ============================================================

* Gráfico de informalidad por etnia desde el año 2000 - nacional
preserve 
    keep if anio >= 2000 & anio <= 2024
    drop if missing(etnia_arm)
    gen uno = 1 
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(anio etnia_arm)
    
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
		 
	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}

    * Gráfico con bandas de confianza y zoom en eje Y
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (connected informal21 anio, sort lcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (connected informal22 anio, sort lcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (connected informal23 anio, sort lcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afro" 6 "Blanco/Mestizo")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(75 95))                                 ///
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}

    * Gráfico con bandas de confianza y zoom en Y
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (connected informal21 anio, sort lcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (connected informal22 anio, sort lcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (connected informal23 anio, sort lcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afroecuatoriano" 6 "Blanco/Mestizo")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(75 95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por etnia (Urbano)", size(med))   ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_etnia_urb_IC, replace)
    
   * graph export "$out_results/informal2_etnia_urb_IC.png", replace
      
restore

*Hay diferencia estadísticamente significativa entre grupos étnicos a nivel nacional urbano. Tanto la etnica indígea y Afro tienen mayor informalidad que el grupo Blanco-Mestizo.

* ============================================================
**# GRÁFICO INFORMALIDAD POR EDUCACION
* ============================================================

* Gráfico de informalidad por educación desde el año 2000 - nacional
preserve 
    keep if anio >= 2001 & anio <= 2024
    drop if missing(educ_univ)
    
    gen uno = 1
    
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp], by(anio educ_univ)
    
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 0 1 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}
	
    * Gráfico con bandas de confianza y zoom en Y
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (connected informal20 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (connected informal21 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(50 95))                                 ///
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

	* Escalar valores a porcentaje (0-100) para el gráfico
	foreach g in 0 1 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g' = ub_`g' * 100
		replace lb_`g' = lb_`g' * 100
	}
    
    * Gráfico con bandas y zoom en Y
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (connected informal20 anio, sort lcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (connected informal21 anio, sort lcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(#5, format(%9.2f)) ///
        yscale(range(50 95))                                 ///
        graphregion(color(white)) bgcolor(white)               ///
        title("Informalidad por educación (Urbano)", size(med)) ///
        note("IC 95% con SE = sqrt[p(1-p)/N]. Área urbana.", size(small)) ///
        name(informal2_educ_urb_IC, replace)
    
  *  graph export "$out_results/informal2_educ_urb_IC.png", replace
    
restore

*Las personas sin educación universitaria tienen una informalidad estadísticamente significativa en comparaciólas que sí la tienen.


* ============================================================
**# Gráfico: % informalidad por decil de ingresos laborales
* ============================================================


bysort anio: xtile decil2 = ingrl [pw=fexp], nq(10)


/*
Revisión:

preserve
keep if anio == 2024
keep if ingrl != . & ingrl > 0   
xtile decile = ingrl [pw = fexp], nq(10)
tab decile
tab decile informal2 if anio == 2024, nofreq row
bysort decile: sum ingrl
gen a = ingrl == 460 
restore
*/


preserve
* --- 1. Filtro de población ocupada con ingreso válido --------
keep if mi_pea == 1
keep if ingrl != . & ingrl > 0   
keep if anio == 2024 | anio == 2019 
* --- 2. Construir deciles ponderados DENTRO de cada año -----
gen decil = .
levelsof anio, local(years)
foreach y of local years {
    xtile decil_`y' = ingrl [pw=fexp] if anio == `y', nq(10)
    replace decil = decil_`y' if anio == `y'
    drop decil_`y'
}
* --- 3. Colapsar: % informalidad por decil y año ------------
collapse (mean) inf2=informal2 [pw=fexp], by(decil anio)
replace inf2 = inf2 * 100
* --- 4. Reshape para graficar ambas líneas ------------------
reshape wide inf2, i(decil) j(anio)
* --- 5. Gráfico de Alta Calidad -----------------------------
twoway ///
    (connected inf22019 decil, ///
        lcolor(navy) mcolor(navy) msymbol(O) lwidth(medthick) msize(medlarge) lpattern(solid)) ///
    (connected inf22024 decil, ///
        lcolor(maroon) mcolor(maroon) msymbol(D) lwidth(medthick) msize(medlarge) lpattern(solid)), ///
    xlabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10", labsize(small)) ///
    ylabel(0(20)100, angle(horizontal) format(%2.0f) labsize(small) grid glcolor(gs14) glpattern(dot)) ///
    xtitle("{bf:Decil de Ingresos Laborales}", size(small) margin(t=2)) ///
    ytitle("{bf:Tasa de Informalidad (%)}", size(small) margin(r=2)) ///
    title("Informalidad Laboral por Deciles de Ingreso", size(medium) color(black) margin(b=2)) ///
    subtitle("Población ocupada — Ponderado por factor de expansión", size(vsmall) color(gs7)) ///
    legend(order(1 "2019" 2 "2024") position(6) rows(1) size(small) region(lcolor(white))) ///
    graphregion(color(white) margin(medium)) plotregion(color(white)) ///
    note("Fuente: ENEMDU." "Elaboración: Propia.", size(vsmall) color(gs6) span)
restore

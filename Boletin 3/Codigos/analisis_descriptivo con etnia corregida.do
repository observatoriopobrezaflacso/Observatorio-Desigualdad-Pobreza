*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
*------------------------------------------------------------------*

clear all
set more off

* Definición de rutas globales para acceder a las bases de datos
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
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
use "$bases_armonizadas/base_trabajo.dta", clear

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
				 no_remunerado      == 1 | ///
				 cuenta_base        == 1 

* Asignar missing si alguna de las variables componentes es missing
replace informal1 = . if inlist(., affiliated_iess, adec, no_remunerado, cuenta_propia)				 

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
				 (tiene_ruc == 0 & tamano_armonizado == 0) | ///
				 cuenta_base       == 1 

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
    collapse (mean) $important_variable2 [iw = fexp], by(anio area)
    list
    format $important_variable2 %9.2f
    * Mantener solo área urbana
    keep if area == 1
    rename $important_variable2 ${important_variable2}_urb
    tempfile urb
    save `urb'
restore

* Calcular promedio nacional ponderado de informal2 (2007-2024)
preserve
    keep if inrange(anio, 2001, 2024)
    collapse (mean) $important_variable2 [iw = fexp], by(anio)
    format $important_variable2 %9.2f
    rename $important_variable2 ${important_variable2}_nac
    * Combinar con datos urbanos
    merge 1:1 anio using `urb', nogen
    list
    * Generar gráfico de líneas para informal2
    twoway (line ${important_variable2}_nac anio)  ///
           (line ${important_variable2}_urb anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           xscale(range(2001 2024)) xlabel(2001(3)2024) ///
           name(informal2_nac_urb, replace)
    graph export "$out_results/informal2_nac_urb.png", replace
restore

* ============================================================
* GRÁFICOS DESAGREGADOS POR GÉNERO
* ============================================================

* Gráfico de informalidad urbana por sexo (todos los años)
preserve 
    keep if area == 1
    collapse (mean) informal1 [iw = fexp], by(anio sexo)
    * Generar líneas separadas para hombres y mujeres
    twoway (line informal1 anio if sexo == 1) ///
           (line informal1 anio if sexo == 2), ///
           legend(label(1 "Hombre") label(2 "Mujer")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
		   name(informal1_sexo_urb, replace)
    graph export "$out_results/informal1_sexo_urb.png", replace
restore	   

* Gráfico de informalidad por sexo desde el año 2000
preserve 
    keep if anio >= 2000
    collapse (mean) informal1 [iw = fexp], by(anio sexo)
    twoway (line informal1 anio if sexo == 1) ///
           (line informal1 anio if sexo == 2), ///
           legend(label(1 "Hombre") label(2 "Mujer")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_sexo_nac, replace)
    graph export "$out_results/informal1_sexo_nac.png", replace
restore	 

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
    * Filtrar solo datos del año 2024
    keep if anio == 2024
    * Calcular promedio de informalidad por provincia
    collapse (mean) informal1 [iw = fexp], by(provincia)
    
    * Ordenar por tasa de informalidad (de mayor a menor)
    gsort -informal1
    
    * Generar gráfico de barras horizontales
    graph hbar informal1, over(provincia, sort(1) descending label(labsize(small))) ///
        ylabel(0(0.2)1, format(%9.2f)) ///
        ytitle("Informalidad") ///
        bar(1, color(navy)) ///
        graphregion(color(white)) bgcolor(white) ///
        title("Informalidad por provincia - 2024", size(medium)) ///
        name(informal1_provincia_2024, replace)
    graph export "$out_results/informal1_provincia_2024.png", replace
restore


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
    keep if anio >= 2000
    collapse (mean) informal1 [iw = fexp], by(anio age_cat)
    twoway (line informal1 anio if age_cat == 1) ///
           (line informal1 anio if age_cat == 2) ///
           (line informal1 anio if age_cat == 3), ///
           legend(label(1 "18-29") label(2 "30-64") label(3 "65+")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_edad_nac, replace)
    graph export "$out_results/informal1_edad_nac.png", replace
restore	 


* Gráfico de informalidad por edad - urbano
preserve 
    keep if area == 1
    collapse (mean) informal1 [iw = fexp], by(anio age_cat)
    twoway (line informal1 anio if age_cat == 1) ///
           (line informal1 anio if age_cat == 2) ///
           (line informal1 anio if age_cat == 3), ///
           legend(label(1 "18-29") label(2 "30-64") label(3 "65+")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_edad_urb, replace)
    graph export "$out_results/informal1_edad_urb.png", replace
restore	 



* ============================================================
* GRÁFICO INFORMALIDAD POR ETNIA
* ============================================================

* Gráfico de informalidad por etnia desde el año 2000 - nacional
preserve 
    keep if anio >= 2000
    collapse (mean) informal1 [iw = fexp], by(anio etnia_arm)
    twoway (line informal1 anio if etnia_arm == 1) ///
           (line informal1 anio if etnia_arm == 2) ///
           (line informal1 anio if etnia_arm == 3), ///
           legend(label(1 "Indigena") label(2 "Negro/Afroecuatoriano") ///
		   label(3 "Blanco/Mestizo")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_etnia_nac, replace)
    graph export "$out_results/informal1_etnia_nac.png", replace
restore	 


* Gráfico de informalidad por etnia - urbano
preserve 
    keep if area == 1
    collapse (mean) informal1 [iw = fexp], by(anio etnia_arm)
    twoway (line informal1 anio if etnia_arm == 1) ///
           (line informal1 anio if etnia_arm == 2) ///
           (line informal1 anio if etnia_arm == 3), ///
           legend(label(1 "Indigena") label(2 "Negro/Afroecuatoriano") ///
		   label(3 "Blanco/Mestizo")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_etnia_urb, replace)
    graph export "$out_results/informal1_etnia_urb.png", replace
restore	 

* ============================================================
* GRÁFICO INFORMALIDAD POR EDUCACION
* ============================================================

* Gráfico de informalidad por educación desde el año 2000 - nacional
preserve 
    keep if anio >= 2000
    collapse (mean) informal1 [iw = fexp], by(anio educ_univ)
    twoway (line informal1 anio if educ_univ == 0) ///
           (line informal1 anio if educ_univ == 1), ///
           legend(label(1 "No universitaria") label(2 "Universitaria")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_educ_nac, replace)
    graph export "$out_results/informal1_educ_nac.png", replace
restore	 


* Gráfico de informalidad por educación - urbano
preserve 
    keep if area == 1
    collapse (mean) informal1 [iw = fexp], by(anio educ_univ)
    twoway (line informal1 anio if educ_univ == 0) ///
           (line informal1 anio if educ_univ == 1), ///
           legend(label(1 "No universitaria") label(2 "Universitaria")) ///
           xlabel(, angle(45)) ///
           ylabel(, angle(0)) ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           graphregion(color(white)) bgcolor(white) ///
           name(informal1_educ_urb, replace)
    graph export "$out_results/informal1_educ_urb.png", replace
restore

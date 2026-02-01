*=============================================================================
*  CURVAS DE INCIDENCIA DEL CRECIMIENTO (GIC) - ANÁLISIS DE INGRESOS URBANOS
*  Encuesta ENEMDU Ecuador (1991-2010)
*=============================================================================
* Programa: mk_ingtot_urb
* Descripción: Procesa microdatos de la ENEMDU para un año específico,
*              construye variables de ingreso, deflacta a precios del año base,
*              calcula ingreso per cápita del hogar, y guarda base procesada.
*
* Parámetros:
*   year(integer) - Año de la encuesta a procesar (1991, 1992-1999, 2000, 2006, 2010)
*
* Salida:
*   Archivo .dta con ingreso per cápita urbano deflactado
*
*  Fuentes de datos:
*    - Rondas de diciembre ENEMDU (empleo[año].dta)
*    - Serie histórica del IPC
*
*  Autor: Santiago Valdivieso
*  Fecha: 24/11/2025
*=============================================================================

*-------------------------------------------------------------
* CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global procesado "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Procesamiento/Bases/Procesadas"
global out "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Outcomes\Curvas de crecimiento"


* Creación de directorios de salida (capture ignora errores si ya existen)
capture mkdir "$procesado\ingresos_pc"          // Almacena bases procesadas de ingreso per cápita
capture mkdir "$out\GIC_exports"          // Almacena gráficos y resultados de las GIC


*-------------------------------------------------------------
* GENERACIÓN DE CURVAS DE INCIDENCIA DEL CRECIMIENTO (GIC)
*-------------------------------------------------------------
* Las GIC muestran la tasa de crecimiento del ingreso por percentil
* Permiten evaluar si el crecimiento es pro-pobre (mayor crecimiento en percentiles bajos)

set autotabgraphs on, permanently

*---------------------------------------------------------
* GIC 1991-1998: Período pre-dolarización
*---------------------------------------------------------

* Create the temp directory first
cap mkdir "C:/temp"

* Urbano

use "$procesado/ingresos_pc/ing_perca_1991_urb_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_1998_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) yp(7) np(10)  ///
    name(gic_9198_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_1991_1998_precios2000", replace) outputfile("C:/temp/gic_urb_1991_1998.dta")

	 graph export "$out/GIC_exports/gic_urb_1991_1998_precios2000.png", replace width(2400)  

	 	 
*---------------------------------------------------------
* GIC 2000-2006: Período de dolarización temprana
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2000_nac_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2006_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(6) np(10)  name(gic_0006_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2000_2006_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2000_2006.dta")

graph export "$out/GIC_exports/gic_nac_2000_2006_precios2000.png", replace width(2400)

* Urbano

use "$procesado/ingresos_pc/ing_perca_2000_urb_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2006_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(6) np(10)  name(gic_0006_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_2000_2006_precios2000", replace) ///
	outputfile("C:/temp/gic_urb_2000_2006.dta")


	graph export "$out/GIC_exports/gic_urb_2000_2006_precios2000.png", replace width(2400) 

*---------------------------------------------------------
* GIC 2006-2010: Período de bonanza petrolera
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2006_nac_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2010_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(4) np(10)  name(gic_0610_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2006_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2006_2010.dta")
	
graph export "$out/GIC_exports/gic_nac_2006_2010_precios2000.png", replace width(2400)


* Urbano 

use "$procesado/ingresos_pc/ing_perca_2006_urb_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2010_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(4) np(10)  name(gic_0610_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_2006_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_urb_2006_2010.dta")


graph export "$out/GIC_exports/gic_urb_2006_2010_precios2000.png", replace width(2400)



*---------------------------------------------------------
* GIC 2001-2006 - Pre RC
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2006_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(5) np(10)  name(gic_0106_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2001_2006_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2001_2006.dta")
	
graph export "$out/GIC_exports/gic_nac_2001_2006_precios2000.png", replace width(2400)


*---------------------------------------------------------
* GIC 2007-2017 - RC
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2007_nac_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2017_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(10) np(10)  name(gic_0717_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2007_2017_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2007_2017.dta")
	
graph export "$out/GIC_exports/gic_nac_2007_2017_precios2000.png", replace width(2400)

*---------------------------------------------------------
* GIC 2018-2024 - Post RC
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2018_nac_precios2000.dta", clear
gicurve using "$procesado/ingresos_pc/ing_perca_2024_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(6) np(10)  name(gic_1824_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2018_2024_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2018_2024.dta")
	
graph export "$out/GIC_exports/gic_nac_2018_2024_precios2000.png", replace width(2400)



*---------------------------------------------------------
* GIC 2001 - 2010
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2010_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(9) np(10)  name(gic_0110_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2001_2010.dta")

graph export "$out/GIC_exports/gic_nac_2006_2010_precios2000.png", replace width(2400)

*Urbano

use "$procesado/ingresos_pc/ing_perca_2001_urb_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2010_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(9) np(10)  name(gic_0110_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_urb_2001_2010.dta")


graph export "$out/GIC_exports/gic_urb_2006_2010_precios2000.png", replace width(2400)

*Indígena

use "$procesado/ingresos_pc/ing_perca_2001_ind_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2010_ind_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(9) np(10)  name(gic_0110_ind, replace) ///
    saving("$out/GIC_exports/gic_ind_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_ind_2001_2010.dta")


graph export "$out/GIC_exports/gic_ind_2006_2010_precios2000.png", replace width(2400)



*---------------------------------------------------------
* GIC 2011 - 2024
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2011_nac_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(13) np(10)  name(gic_1124_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2011_2024_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2011_2024.dta")

graph export "$out/GIC_exports/gic_nac_2011_2024_precios2000.png", replace width(2400)


* Urbano

use "$procesado/ingresos_pc/ing_perca_2011_urb_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(13) np(10)  name(gic_1124_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_2011_2024_precios2000", replace) ///
	outputfile("C:/temp/gic_urb_2011_2024.dta")

graph export "$out/GIC_exports/gic_urb_2011_2024_precios2000.png", replace width(2400)


* Indígena

use "$procesado/ingresos_pc/ing_perca_2011_ind_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_ind_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(13) np(10)  name(gic_1124_ind, replace) ///
    saving("$out/GIC_exports/gic_ind_2011_2024_precios2000", replace) ///
	outputfile("C:/temp/gic_ind_2011_2024.dta")

graph export "$out/GIC_exports/gic_ind_2011_2024_precios2000.png", replace width(2400)



*---------------------------------------------------------
* GIC 2001 - 2024
*---------------------------------------------------------

* Nacional

use "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_nac_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(23) np(10)  name(gic_0124_nac, replace) ///
    saving("$out/GIC_exports/gic_nac_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_nac_2001_2024.dta")

graph export "$out/GIC_exports/gic_nac_2006_2010_precios2000.png", replace width(2400)


* Urbano

use "$procesado/ingresos_pc/ing_perca_2001_urb_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_urb_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(23) np(10)  name(gic_0124_urb, replace) ///
    saving("$out/GIC_exports/gic_urb_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_urb_2001_2024.dta")

graph export "$out/GIC_exports/gic_urb_2006_2010_precios2000.png", replace width(2400)


* Indígena

use "$procesado/ingresos_pc/ing_perca_2001_ind_precios2000.dta", clear

gicurve using "$procesado/ingresos_pc/ing_perca_2024_ind_precios2000.dta" ///
    [fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
    yp(23) np(10)  name(gic_0124_ind, replace) ///
    saving("$out/GIC_exports/gic_ind_2001_2010_precios2000", replace) ///
	outputfile("C:/temp/gic_ind_2001_2024.dta")

graph export "$out/GIC_exports/gic_ind_2006_2010_precios2000.png", replace width(2400)



*---------------------------------------------------------
*                Combine GIC curves
*---------------------------------------------------------

* ----------- Urbano: 1991-1998 & 2001-2024 ------------ *

* Load first dataset
use "C:/temp/gic_urb_1991_1998.dta", clear
rename pr_growth gic1
rename pctl percentile1

* Calculate slope for curve 1
quietly reg gic1 percentile1
local slope1 = _b[percentile1]
local slope1_fmt : display %5.3f `slope1'

* Get position for text annotation (observation 7)
local y1 = gic1[7]
local x1 = percentile1[7]

* Save temp file
tempfile data1
save `data1'

* Load second dataset
use "C:/temp/gic_urb_2001_2024.dta", clear
rename pr_growth gic2
rename pctl percentile2

* Calculate slope for curve 2
quietly reg gic2 percentile2
local slope2 = _b[percentile2]
local slope2_fmt : display %5.3f `slope2'

* Get position for text annotation (observation 4)
local y2 = gic2[4]
local x2 = percentile2[4]

* Append datasets (don't merge)
append using `data1'

* Create combined graph
twoway (connected gic1 percentile1) ///
       (connected gic2 percentile2), ///
       legend(label(1 "1991-1998") label(2 "2001-2024")) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(urb_2p, replace)

* Create combined graph
twoway (connected gic1 percentile1) ///
       (connected gic2 percentile2), ///
       text(`y1' `x1' "β = `slope1_fmt'", color(navy) size(small) placement(n)) ///
       text(`y2' `x2' "β = `slope2_fmt'", color(maroon) size(small) placement(n)) ///
       legend(label(1 "1991-1998") label(2 "2001-2024")) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(urb_2p, replace)
	   
	   
graph export "$out/GIC_exports/gic_urb_2p.png", replace width(2400)
	 
	   
* ------------  Nacional: 1991-1998, 2011-2024, 2001-2024 ------------ *

use "C:/temp/gic_nac_2001_2010.dta", clear
rename pr_growth gic1  // rename the growth rate variable

* Merge with second GIC results
merge 1:1 pctl using "C:/temp/gic_nac_2011_2024.dta", nogen
rename pr_growth  gic2

merge 1:1 pctl using "C:/temp/gic_nac_2001_2024.dta", nogen
rename pr_growth  gic3
rename pctl percentile

* Check what percentile values exist
list percentile

* Calculate slopes for each curve
quietly reg gic1 percentile
local slope1 = _b[percentile]
local slope1_fmt : display %5.3f `slope1'

quietly reg gic2 percentile
local slope2 = _b[percentile]
local slope2_fmt : display %5.3f `slope2'

quietly reg gic3 percentile
local slope3 = _b[percentile]
local slope3_fmt : display %5.3f `slope3'

* Get y-values and x-values at specific observations for positioning
* Using different observations to avoid overlap
local obs1 = 7  // for gic1
local obs2 = 4  // for gic2  
local obs3 = 2  // for gic3

local y1 = gic1[`obs1']
local x1 = percentile[`obs1']
local y2 = gic2[`obs2']
local x2 = percentile[`obs2']
local y3 = gic3[`obs3']
local x3 = percentile[`obs3']

* Create combined graph with slopes as text annotations
twoway (connected gic1 percentile) ///
       (connected gic2 percentile) ///
       (connected gic3 percentile), ///
       legend(label(1 "2001-2010") label(2 "2011-2024") label(3 "2001-2024") col(3)) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(nac_3p, replace) ///
	   ylabel(-3(1)8, angle(horizontal) grid)

	   
* Create combined graph with slopes as text annotations
twoway (connected gic1 percentile) ///
       (connected gic2 percentile) ///
       (connected gic3 percentile), ///
       text(`y1' `x1' "β = `slope1_fmt'", color(navy) size(small) placement(n)) ///
       text(`y2' `x2' "β = `slope2_fmt'", color(maroon) size(small) placement(n)) ///
       text(`y3' `x3' "β = `slope3_fmt'", color(green) size(small) placement(n)) ///
       legend(label(1 "2001-2010") label(2 "2011-2024") label(3 "2001-2024") col(3)) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(nac_3p, replace) ///
	   ylabel(-3(1)8, angle(horizontal) grid)


	   
	   
graph export "$out/GIC_exports/gic_nac_3p.png", replace width(2400)
	   	   

* ------------  Indígena: 1991-1998, 2011-2024, 2001-2024 ------------  *

use "C:/temp/gic_ind_2001_2010.dta", clear
rename pr_growth gic1  // rename the growth rate variable

* Merge with second GIC results
merge 1:1 pctl using "C:/temp/gic_ind_2011_2024.dta", nogen
rename pr_growth  gic2

merge 1:1 pctl using "C:/temp/gic_ind_2001_2024.dta", nogen
rename pr_growth  gic3
rename pctl percentile


* Create combined graph
twoway (connected gic1 percentile, lcolor(darkbrown)) ///
       (connected gic2 percentile, lcolor(red)) ///
       (connected gic3 percentile), ///
       legend(label(1 "2001-2010") label(2 "2011-2024") label(3 "2001-2024") col(3)) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(ind_3p, replace) ///
	   ylabel(-3(1)8, angle(horizontal) grid)
	   
graph export "$out/GIC_exports/gic_ind_3p.png", replace width(2400)


* ------------  Nacional: 2001-2006, 2007-2017, 2018-2024 ------------ *

use "C:/temp/gic_nac_2001_2006.dta", clear
rename pr_growth gic1  // rename the growth rate variable

* Merge with second GIC results
merge 1:1 pctl using "C:/temp/gic_nac_2007_2017.dta", nogen
rename pr_growth gic2

merge 1:1 pctl using "C:/temp/gic_nac_2018_2024.dta", nogen
rename pr_growth gic3
rename pctl percentile

* Check what percentile values exist
list percentile

* Calculate slopes for each curve
quietly reg gic1 percentile
local slope1 = _b[percentile]
local slope1_fmt : display %5.3f `slope1'

quietly reg gic2 percentile
local slope2 = _b[percentile]
local slope2_fmt : display %5.3f `slope2'

quietly reg gic3 percentile
local slope3 = _b[percentile]
local slope3_fmt : display %5.3f `slope3'

* Get y-values and x-values at specific observations for positioning
* Using different observations to avoid overlap
local obs1 = 7  // for gic1
local obs2 = 4  // for gic2  
local obs3 = 2  // for gic3

local y1 = gic1[`obs1']
local x1 = percentile[`obs1']
local y2 = gic2[`obs2']
local x2 = percentile[`obs2']
local y3 = gic3[`obs3']
local x3 = percentile[`obs3']

* Create combined graph with slopes as text annotations
twoway (connected gic1 percentile) ///
       (connected gic2 percentile) ///
       (connected gic3 percentile), ///
       text(`y1' `x1' "β = `slope1_fmt'", color(navy) size(small) placement(n)) ///
       text(`y2' `x2' "β = `slope2_fmt'", color(maroon) size(small) placement(n)) ///
       text(`y3' `x3' "β = `slope3_fmt'", color(green) size(small) placement(n)) ///
       legend(label(1 "2001-2006") label(2 "2007-2017") label(3 "2018-2024") col(3)) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(ind_3p_pol, replace) 
	   
graph export "$out/GIC_exports/gic_politics_3p.png", replace width(2400) 
	   

	   
use "C:/temp/gic_nac_2001_2006.dta", clear
rename pr_growth gic1  // rename the growth rate variable

* Merge with second GIC results
merge 1:1 pctl using "C:/temp/gic_nac_2007_2017.dta", nogen
rename pr_growth gic2

merge 1:1 pctl using "C:/temp/gic_nac_2018_2024.dta", nogen
rename pr_growth gic3
rename pctl percentile

* Check what percentile values exist
list percentile

* Calculate slopes for each curve
quietly reg gic1 percentile
local slope1 = _b[percentile]
local slope1_fmt : display %5.3f `slope1'

quietly reg gic2 percentile
local slope2 = _b[percentile]
local slope2_fmt : display %5.3f `slope2'

quietly reg gic3 percentile
local slope3 = _b[percentile]
local slope3_fmt : display %5.3f `slope3'

* Get y-values and x-values at specific observations for positioning
* Using different observations to avoid overlap
local obs1 = 7  // for gic1
local obs2 = 4  // for gic2  
local obs3 = 2  // for gic3

local y1 = gic1[`obs1']
local x1 = percentile[`obs1']
local y2 = gic2[`obs2']
local x2 = percentile[`obs2']
local y3 = gic3[`obs3']
local x3 = percentile[`obs3']

* Create combined graph with slopes as text annotations
twoway (connected gic1 percentile) ///
       (connected gic2 percentile) ///
       (connected gic3 percentile), ///
       legend(label(1 "2001-2006") label(2 "2007-2017") label(3 "2018-2024") col(3)) ///
       ytitle("Crecimiento anualizado (%)") xtitle("Percentil") ///
       title("") name(ind_3p_pol, replace) 
	   
graph export "$out/GIC_exports/gic_politics_3p.png", replace width(2400) 
	   
	   	   	  	   	   
	   
s

*-------------------------------------------------------------
* SECCIÓN 6: CÁLCULO MANUAL DE TASAS DE CRECIMIENTO POR DECIL
*-------------------------------------------------------------
* Esta sección replica el análisis de la GIC de forma manual

use "$procesado/ingresos_pc/ing_perca_2006_urb_precios2000.dta", clear
append using "$procesado/ingresos_pc/ing_perca_2010_urb_precios2000.dta" 

preserve

*---------------------------------------------------------
* Calcular tasa de crecimiento del ingreso máximo por decil
* Metodología: Median Spline (usando máximo como proxy)
*---------------------------------------------------------
collapse (max) ingtot_per_deflated [fw = round(fexp)], by(decile anio)

* Reshapear datos: una fila por decil, columnas por año
reshape wide ingtot, i(decile) j(anio)

* Calcular cambio porcentual total entre 2006 y 2010
gen per_change = ((ingtot_per_deflated2010 / ingtot_per_deflated2006) - 1) * 100

* Calcular tasa de crecimiento anualizada (4 años entre 2006 y 2010)
* Fórmula: [(1 + r_total)^(1/n) - 1] * 100
gen per_change_year = ((1 + per_change/100)^(1/4) - 1) * 100

list

*---------------------------------------------------------
* Calcular tasa de crecimiento media para los p% más pobres
* Esta es la estadística "pro-poor growth rate"
*---------------------------------------------------------
* Itera sobre los primeros i deciles y calcula la media acumulada
forval i = 1/9 {
    di "`i'"
    qui: mean per_change in 1/`i'
    
    * Inicializar matrices en la primera iteración
    if `i' == 1 mat growth_rate = .
    mat growth_rate = growth_rate \ e(b)
    
    if `i' == 1 mat growth_rate_year = .
    * Anualizar la tasa de crecimiento media
    mat growth_rate_year = growth_rate_year \ ((1 + growth_rate[`i', 1]/100)^(1/4) - 1) * 100 
}

* Mostrar resultados
* growth_rate: Tasa de crecimiento media acumulada (%)
* growth_rate_year: Tasa anualizada para cada acumulado
matlist growth_rate
matlist growth_rate_year

restore





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
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global procesado "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc"
global out "$user_root/Boletín 1/Outcomes/Curvas de crecimiento"

cd "$out"


* Creación de directorios de salida (capture ignora errores si ya existen)
capture mkdir "$procesado"          // Almacena bases procesadas de ingreso per cápita
capture mkdir "$out/GIC_exports"          // Almacena gráficos y resultados de las GIC


*-------------------------------------------------------------
* GENERACIÓN DE CURVAS DE INCIDENCIA DEL CRECIMIENTO (GIC)
*-------------------------------------------------------------
* Las GIC muestran la tasa de crecimiento del ingreso por percentil
* Permiten evaluar si el crecimiento es pro-pobre (mayor crecimiento en percentiles bajos)

set autotabgraphs on, permanently

	 	 
*---------------------------------------------------------
* ALL
*---------------------------------------------------------

* Nacional

local y1_list "2000 2001 2003 2005 2006 2007 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"
local y2_list "2001 2003 2005 2006 2007 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025"

foreach y1 of local y1_list {
	foreach y2 of local y2_list {
		if (`y2' > `y1') {
			local period = `y2' - `y1'
			use "$procesado/Nacional/ing_perca_`y1'_nac_precios2000.dta", clear
			gicurve using "$procesado/Nacional/ing_perca_`y2'_nac_precios2000.dta" ///
				[fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
				yp(`period') np(10) name(gic_0006_nac, replace) ///
				saving("$out/GIC_exports/gic_nac_`y1'_`y2'_precios2000", replace) ///
				outputfile("GIC_exports/tables/dta/gic_nac_`y1'_`y2'.dta") nograph
			preserve
			use "GIC_exports/tables/dta/gic_nac_`y1'_`y2'.dta", clear
			export excel using "GIC_exports/tables/xlsx/gic_nac_`y1'_`y2'.xlsx", replace firstrow(var)
			restore
		}
	}
}



* Urbano


local y1_list "1991 1993 1995 1997 1998 1999 2000 2001 2003 2005 2006 2007 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"
local y2_list "1993 1995 1997 1998 1999 2000 2001 2003 2005 2006 2007 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025"

foreach y1 of local y1_list {
	foreach y2 of local y2_list {
		if (`y2' > `y1') {
			local period = `y2' - `y1'
			use "$procesado/Urbano/ing_perca_`y1'_urb_precios2000.dta", clear
			gicurve using "$procesado/Urbano/ing_perca_`y2'_urb_precios2000.dta" ///
				[fw=fw], var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
				yp(`period') np(10) name(gic_0006_urb, replace) ///
				saving("$out/GIC_exports/gic_urb_`y1'_`y2'_precios2000", replace) ///
				outputfile("GIC_exports/tables/dta/gic_urb_`y1'_`y2'.dta") nograph
			preserve
			use "GIC_exports/tables/dta/gic_urb_`y1'_`y2'.dta", clear
			export excel using "GIC_exports/tables/xlsx/gic_urb_`y1'_`y2'.xlsx", replace firstrow(var)
			restore
		}
	}
}

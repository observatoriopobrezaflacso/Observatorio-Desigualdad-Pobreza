*=============================================================================
*  CURVAS DE INCIDENCIA DEL CRECIMIENTO (GIC) - ANÁLISIS DE INGRESOS URBANOS
*  Encuesta ENEMDU Ecuador (1991-2010)
*=============================================================================
*  Propósito: Construye distribuciones de ingreso per cápita del hogar a partir
*             de las encuestas de empleo ENEMDU, ajusta por inflación usando el
*             IPC.
*
*  Fuentes de datos:
*    - Rondas de diciembre ENEMDU (empleo[año].dta)
*    - Serie histórica del IPC
*
*  Autor: Santiago Valdivieso
*  Fecha: 24/11/2025
*=============================================================================

*-------------------------------------------------------------
* SECCIÓN 1: CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global codigos "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Codigos/Ingresos/Por separado/Solo ingreso"

global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases/Procesadas"
global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Outcomes/Curvas de crecimiento"


* Creación de directorios de salida (capture ignora errores si ya existen)
capture mkdir "$procesado/ingresos_pc"          // Almacena bases procesadas de ingreso per cápita
capture mkdir "$out/GIC_exports"          // Almacena gráficos y resultados de las GIC

*-------------------------------------------------------------
* SECCIÓN 2: PROCESAMIENTO DEL ÍNDICE DE PRECIOS AL CONSUMIDOR (IPC)
*-------------------------------------------------------------
* Año base para deflactar todos los ingresos a precios constantes
scalar base_year = 2000

* Importar serie histórica del IPC desde archivo Excel
* La hoja "1. ÍNDICE" contiene los índices mensuales; usamos diciembre de cada año
import excel "$bases/IPC/SERIE HISTORICA IPC_10_2025.xls", ///
    sheet("1. ÍNDICE") cellrange(A4) clear firstrow

* Estandarizar nombres de variables a minúsculas
rename *, lower
rename (meses diciembre) (anio ipc)  // Renombrar: meses→anio, diciembre→ipc

* Convertir año a numérico y limpiar datos
destring anio, replace force
keep anio ipc                         // Conservar solo año e IPC de diciembre
keep if anio != .                     // Eliminar observaciones con año faltante

* Guardar base del IPC para merge posterior con datos de encuestas
save "$bases\IPC\ipc_adjusted.xls", replace

* Extraer el IPC del año base para calcular el deflactor
keep if anio == base_year
scalar cpi_base = ipc                 // Almacenar IPC base como escalar

clear

*-------------------------------------------------------------
* SECCIÓN 3: PROGRAMA PRINCIPAL - PROCESAMIENTO DE INGRESOS POR AÑO
*-------------------------------------------------------------
* Eliminar programas previos del mismo nombre para evitar conflictos
program drop _all

*-------------------------------------------------------------
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
*-------------------------------------------------------------

program define mk_ingtot
    version 15
    syntax , year(integer)

di "************`year'******************"	
	
quietly {	
	
    *---------------------------------------------------------
    * PASO 1: Cargar datos de la encuesta ENEMDU del año especificado
    *---------------------------------------------------------
    use "$raw\empleo`year'.dta", clear

    * Convertir variables de identificación geográfica a numéricas
    * (necesario para crear identificadores únicos de hogar)
    foreach v in ciudad zona sector vivienda hogar {
        capture confirm variable `v'
        if !_rc destring `v', replace force
    }
	
    *---------------------------------------------------------
    * PASO 2: Merge con IPC para obtener deflactor
    *---------------------------------------------------------
    gen anio = `year'
    qui: merge m:1 anio using "$bases\IPC\ipc_adjusted.xls", keep(match) nogen
	
    * Obtener IPC del diciembre del año de la encuesta
	preserve
	keep if anio == `year'
    scalar cpi_dec = ipc
	restore
    
    * Calcular deflactor: IPC_base / IPC_año_encuesta
    * Multiplicar ingresos nominales por este factor los lleva a precios del año base
	gen deflator = cpi_base / cpi_dec
}

	di "Año base: " base_year "; cpi base: " cpi_base

quietly {
	
    *---------------------------------------------------------
    * PASO 3: Construcción de variables de ingreso
    * NOTA: La estructura de variables cambia significativamente entre años
    *       debido a cambios en el diseño del cuestionario ENEMDU
    *---------------------------------------------------------
	
    *=========================================================
    **# AÑO 1991: Estructura básica de ingresos
    *=========================================================

    *=========================================================
    **# AÑOS 1992-1999: Estructura intermedia
    *=========================================================
    if inrange(`year', 1991, 1999) {
 
      do "$codigos/Ingreso_`year'"
	  
    }
	
	*=========================================================
    **# AÑOS 2001-2009: Estructura intermedia
    *=========================================================
    if inrange(`year', 2001, 2009) {
 
      do "$codigos/Ingreso_`year'"
	  
    }

    *=========================================================
    **# AÑO 2010-2025
    *=========================================================
    else if inrange(`year', 2010, 2025) {
  
        * --- Ingreso cuenta propia (neto de gastos) ---
		recode p63 999999 =.           // Ingreso bruto actividad independiente
		recode p63 .=0
		recode p64b 999999 =.          // Ingresos adicionales
		recode p64b .=0
		recode p65 999999 = .          // Gastos de la actividad
		recode p65 .=0

        * Ingreso neto = ingreso bruto - gastos (con piso en cero)
		generate ing_cta1 = p63 + p64b - p65
		gen ing_cta = ing_cta1
		replace ing_cta = 0 if ing_cta1 <= 0    // No permitir ingresos negativos

        * --- Ingreso salarial ---
		recode p66 999999=.            // Sueldo/salario
		recode p66 .=0
		recode p67 999999=.            
		recode p67 .=0
		recode p68b 999999=.           
		recode p68b .=0
		recode p69 999999 = .          
		recode p69 .=0 
		recode p70b 999999=.           
		recode p70b .=0

		generate ing_sal = p66 + p67 + p68b + p69 + p70b
		gen ing_lab = ing_cta + ing_sal

        * --- Ingresos no laborales ---
		recode p71b 999999=.           // Rentas del capital (arriendos, intereses)
		recode p71b .=0
		recode p72b 999999=.           // Jubilación/pensión
		recode p72b .=0
		recode p73b 999999=.           // Otros ingresos (transferencias)
		recode p73b .=0

        * Desagregación de rentas
		gen ing_cap = p71b             // Ingresos del capital
		gen ing_pen = p72b             // Pensiones/jubilaciones
		generate ing_rent = p71b + p72b + p73b

        * Remesas del exterior
		generate ing_rem = p74b
		recode ing_rem 999999= .
		recode ing_rem .=0

        * Bono de Desarrollo Humano
		generate ingbon = p76
		recode ingbon 999999 = .
		recode ingbon .=0

        * Transferencias totales (otros + bono)
		gen ing_transf = p73b + ingbon

        * Ingreso total
		generate ing_tot = ing_lab + ing_rent + ingbon + ing_rem

        * Convertir ceros a missing
		recode ing_sal 0=.
		recode ing_cta 0=.
		recode ing_rent 0=.
		recode ing_lab 0=.
		recode ing_rem 0=.
		recode ingbon 0=.
		recode ing_tot 0=.

        *---------------------------------------------------------
        * Cálculo del ingreso per cápita del hogar
        *---------------------------------------------------------
		
		capture confirm variable id_hogar
		
		if _rc{
		destring area ciudad zona sector panelm vivienda hogar, replace
		sort ciudad zona sector panelm vivienda hogar
		egen id_hogar = group(ciudad zona sector panelm vivienda hogar)
        }
		
		foreach v in ing_sal ing_transf ing_cta ing_cta1 ing_rent ing_lab ing_tot ingtot_per ingrl ing_rem ingbon ing_cap ing_pen {
        capture confirm variable `v'
        if !_rc recode `v' (999999=.)
        }
		gen x = 1
		egen n = sum(x), by(id_hogar)
		egen ingtot_hh = sum(ing_tot), by(id_hogar)
		egen inglab_hh = sum(ing_lab), by(id_hogar)
		egen ingcta_hh = sum(ing_cta), by(id_hogar)
		egen ingrent_hh = sum(ing_rent), by(id_hogar)
		egen ingrem_hh = sum(ing_rem), by(id_hogar)
		egen ingbon_hh = sum(ingbon), by(id_hogar)

		gen ingtot_per = ingtot_hh / n
		gen inglab_per = inglab_hh / n
		gen ingrent_per = ingrent_hh / n
		gen ingrem_per = ingrem_hh / n
		gen ingbo_per = ingbon_hh / n

		recode ingtot_per 0=.		
    }
    else {
        * Error si el año no está implementado
        di as error "Programa sólo cubre 1991-2000, 2006 y 2010."
        exit 198
    }

	
		   		di "asd"

	
    *---------------------------------------------------------
    * PASO 4: Deflactar variables de ingreso a precios del año base
    *---------------------------------------------------------
    * Aplicar deflactor a todas las variables de ingreso existentes
    foreach v in ing_sal ing_cta ing_rent ing_lab ing_tot ingtot_per ingrl ing_rem ingbon ing_cap ing_pen {
        capture confirm variable `v'
        if !_rc {
            recode `v' (0 = .) (999999 = .) (-1 = 0) 
            gen `v'_deflated = `v' * deflator   // Crear versión deflactada
        }
    }

	
	*---------------------------------------------------------
    * PASO 5: Crear identificador de personas
    *---------------------------------------------------------	
	
	capture confirm variable id_hogar
	if !_rc rename id_hogar idhogar

	
	tostring(idhogar), replace

	gen len_idhogar = strlen(idhogar) 
	gen zero = 0
	egen idhogar1 = concat(zero zero zero zero idhogar) if len_idhogar == 1
	egen idhogar2 = concat(zero zero zero idhogar) if len_idhogar == 2
	egen idhogar3 = concat(zero zero idhogar) if len_idhogar == 3
	egen idhogar4 = concat(zero idhogar) if len_idhogar == 4

	forval i = 1/4 {
		replace idhogar = idhogar`i' if len_idhogar == `i'
	}

	bysort idhogar: gen persona_n = _n
	egen idper = concat(idhogar persona_n)

	
	
	
    *---------------------------------------------------------
    * PASO 5: Preparar factor de expansión para análisis ponderado
    *---------------------------------------------------------
    capture confirm variable fexp
    if _rc {
        di as error "No existe fexp en `year'."
        exit 459
    }
	
    gen fw = round(fexp)                         // Redondear para usar como frequency weight
    
    recode ingtot_per (0=.)                      // Asegurar que ceros son missing

    * Etiquetas de variables
    label var ingtot_per "Ingreso per cápita urbano (`year', precios dic-2006)"
    label var fw "Factor expansión redondeado"
	
    *---------------------------------------------------------
    * PASO 6: Crear deciles de ingreso per cápita deflactado
    *---------------------------------------------------------
	xtile decile = ingtot_per_deflated [fw = fw], nquantiles(10)
	
}
	
    *---------------------------------------------------------
    * PASO 7: Filtrar solo áreas urbanas
    *---------------------------------------------------------
	preserve

	capture confirm variable area
	if !_rc {
		save "$procesado/ingresos_pc/ing_perca_`year'_nac_precios2000_2.dta", replace
		destring area, replace 
	*	keep if area == 1 // area=1 corresponde a urbano
	*	save "$procesado/ingresos_pc/ing_perca_`year'_urb_precios2000_2.dta", replace
		}
		
	*if _rc save "$procesado/ingresos_pc/ing_perca_`year'_urb_precios2000_2.dta", replace

/*	
    lookfor "se considera"
	local etnia_var = r(varlist)
	di "etnia var: `etnia_var'"
	capture confirm variable `etnia_var'
	if !_rc {
		lookfor "se considera"
	    local etnia_var = r(varlist)
		decode `etnia_var', generate(`etnia_var'_str)
		keep if ustrregexm(`etnia_var'_str, "Ind") | ustrregexm(`etnia_var'_str, "ind")
		drop `etnia_var'_str 		
		save "$procesado/ingresos_pc/ing_perca_`year'_ind_precios2000.dta", replace
		}  
		
	restore
*/

    *---------------------------------------------------------
    * PASO 8: Descriptive statistics
    *---------------------------------------------------------
    
	capture confirm variable ingpc
	if !_rc {
	recode ingpc (0=.)
	sum ingpc ingtot_per
	}
	
	sum ingtot_per_deflated [w = fexp]
    tabstat ingtot_per_deflated [w = fexp], by(decile) stat(max)	
	
end

**# Usage

foreach y of numlist 1998 {
    mk_ingtot, year(`y')
}

s

foreach y of numlist 1991(2)1999{
    mk_ingtot, year(`y')
}




foreach y of numlist 1991(2)2023 {
    di "**********`y'***********"
    capture describe id_upm using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta"
	if !_rc di "existe"
	else di "no existe"
}


foreach y of numlist 2001(2)2009 {
    di "**********`y'***********"
    use ingtot_per using "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", clear
	
	sum ingtot_per 
	
    use ingtot_per using "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000_2.dta", clear
	
	sum ingtot_per 
}



foreach y of numlist 1991(1)1998 {
    di "**********`y'***********"
    use ingtot_per using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", clear
	
	sum ingtot_per 
	
    use ingtot_per using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000_2.dta", clear
	
	sum ingtot_per 
}







use ing* idhogar idper using "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000.dta", clear

gen a = 1
rename ing* ing*_1

merge 1:1 idper using "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000_2.dta", keepusing(ing* idhogar idper)


recode a . = 2

rename ingrl ing_lab_2

foreach v of varlist _all {
    if substr("`v'", -2, 2) != "_1" {
        rename `v' `v'_2
    }
}









merge 1:1 id using "$procesado/ingresos_pc/ing_perca_2001_nac_precios2000_2.dta", keep(ing*)

replace a = 2 if a == .



egen ingtot_per2 = ing 









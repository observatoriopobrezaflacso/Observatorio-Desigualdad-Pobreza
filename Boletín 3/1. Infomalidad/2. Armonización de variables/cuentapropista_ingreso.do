*==============================================================================
* ARMONIZACIÓN DEFINITIVA: CUENTA PROPIA Y BASE IMPONIBLE (1990-2025)
* FLACSO - Observatorio de Pobreza
*
* Variable dicotómica final (cuenta_base):
* 1 = Cuenta propia Y gana MENOS de la base imponible (Informal / Subsistencia)
* 0 = Cuenta propia Y gana IGUAL O MÁS de la base imponible (Formal)
* . = Resto de ocupados / inactivos / cuenta propia sin ingresos declarados
*==============================================================================

clear all
set more off


* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"

local path_excel "$user_root/Bases/IPC/base_imponible_deflactada.xlsx"

* --- 1. PREPARAR EL EXCEL DE LA BASE IMPONIBLE ---
import excel "`path_excel'", clear 
capture rename A anio_merge
capture rename B IPC
capture rename C base_deflactada
destring anio_merge base_deflactada, replace force
keep if !missing(anio_merge)
tempfile base_sri
save `base_sri'

* --- 2. CARPETA TEMPORAL LOCAL ---
local tmpdir      "/Users/vero/tmp_enemdu"
cap mkdir         "`tmpdir'"
local master_base "`tmpdir'/master_base.dta"

* --- ARCHIVO MAESTRO VACÍO EN DISCO LOCAL ---
clear
save `master_base', emptyok replace

*------------------------------------------------------------------------------
* 3. BUCLE PRINCIPAL (1990 - 2025)
*------------------------------------------------------------------------------
forvalues year = 1990/2025 {

	use "$raw/empleo`year'.dta", clear
	di as text "Procesando año: `year'"

	* =========================================================
	* 0. BARREDORA DE VARIABLES RESIDUALES 
	* (Evita el error r(110) si la base viene sucia)
	* =========================================================
	capture drop mes id id_persona2 provincia anio_merge ipc_anio cuenta_propia ing_nom ing_usd_2000 informal_trib ingreso_laboral exento_sri cuenta_base base_deflactada

	capture tostring anio,       replace force
	capture tostring id_persona, replace force
	
	gen anio_merge = `year'

	* =========================================================
	* A. IDENTIFICACIÓN DE CUENTA PROPIA (Fechas corregidas)
	* =========================================================
	gen byte cuenta_propia = .

	* 1990-1999: código 4
	if `year' <= 1999 {
		capture replace cuenta_propia = 0 if !missing(catetrab)
		capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates)
		capture replace cuenta_propia = 1 if catetrab == 4
		capture replace cuenta_propia = 1 if  missing(catetrab) & cates == 4
	}
	* 2000: códigos 4 y 10
	else if `year' == 2000 {
		capture replace cuenta_propia = 0 if !missing(catetrab)
		capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates)
		capture replace cuenta_propia = 1 if inlist(catetrab, 4, 10)
		capture replace cuenta_propia = 1 if  missing(catetrab) & inlist(cates, 4, 10)
	}
	* 2001-2002: códigos 5 y 10
	else if inrange(`year', 2001, 2002) {
		capture replace cuenta_propia = 0 if !missing(catetrab)
		capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates)
		capture replace cuenta_propia = 1 if inlist(catetrab, 5, 10)
		capture replace cuenta_propia = 1 if  missing(catetrab) & inlist(cates, 5, 10)
	}
	* 2003-2006: código 7 (Muere en 2006)
	else if inrange(`year', 2003, 2006) {
		capture replace cuenta_propia = 0 if !missing(catetrab)
		capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates)
		capture replace cuenta_propia = 1 if catetrab == 7
		capture replace cuenta_propia = 1 if  missing(catetrab) & cates == 7
	}
	* 2007-2025: código 6 en p42/p54 (Arranca en 2007)
	else if `year' >= 2007 {
		capture replace cuenta_propia = 0 if !missing(p42)
		capture replace cuenta_propia = 0 if  missing(p42) & !missing(p54)
		capture replace cuenta_propia = 1 if p42 == 6
		capture replace cuenta_propia = 1 if  missing(p42) & p54 == 6
		
	}

	* =========================================================
	* B. LIMPIEZA DEL INGRESO LABORAL (ingrl)
	* =========================================================
	gen double ingreso_laboral = .
	
	* 1. Limpieza para los años en SUCRES (1990 - 1999)
	* Aquí la gente ganaba millones, el tope es altísimo.
	if `year' < 2000 {
		capture replace ingreso_laboral = ingrl if ingrl > 0 & ingrl < 999999999
		* Lo pasamos a dólares para que hable el mismo idioma que tu Excel
		replace ingreso_laboral = ingreso_laboral / 25000
	}
	* 2. Limpieza para los años DOLARIZADOS (2000 - 2025)
	* Aplicamos el filtro de 99,999 para eliminar el código basura del INEC
	else {
		capture replace ingreso_laboral = ingrl if ingrl > 0 & ingrl < 99999
	}

	* =========================================================
	* C. CRUCE CON EXCEL Y CREACIÓN DE VARIABLES
	* =========================================================
	merge m:1 anio_merge using `base_sri', keep(master match) nogen
	
	* --- Paso 1: Condición Tributaria General ---
	gen byte exento_sri = .
	replace exento_sri = 1 if ingreso_laboral < base_deflactada & !missing(ingreso_laboral)
	replace exento_sri = 0 if ingreso_laboral >= base_deflactada & !missing(ingreso_laboral)

	* --- Paso 2: Intersección exclusiva para Cuenta Propia ---
	gen byte cuenta_base = .
	replace cuenta_base = 1 if cuenta_propia == 1 & exento_sri == 1 
	replace cuenta_base = 0 if cuenta_propia == 0 | exento_sri == 0 

	* =========================================================
	* D. GUARDADO Y CONSOLIDACIÓN
	* =========================================================
	
	capture confirm variable area
	if !_rc {
	local area_var area
	destring area, replace
	} 
	else    local area_var 
	
	keep id_persona anio cuenta_propia exento_sri cuenta_base base_deflactada ingreso_laboral ingrl `area_var'

	append using `master_base'
	save `master_base', replace


} // fin forvalues

*------------------------------------------------------------------------------
* 4. FINALIZACIÓN Y ETIQUETADO DE LA BASE MAESTRA
*------------------------------------------------------------------------------
use `master_base', clear

label variable cuenta_propia "Trabajador por cuenta propia"
label define  cp_lab 1 "Cuenta propia" 0 "Resto de ocupados", replace
label values  cuenta_propia cp_lab

label variable exento_sri "Población exenta de Impuesto a la Renta"
label define exento_lab 1 "Exento (Menor a base)" 0 "Paga Renta (Mayor a base)", replace
label values exento_sri exento_lab

label variable cuenta_base "Cuenta Propia vs Base Imponible"
label define base_lab 1 "Bajo Base (Informal)" 0 "Sobre Base (Formal)", replace
label values cuenta_base base_lab

* Comprobación estructural final
tab anio cuenta_base, row missing


replace area = 1 if area == .

destring anio, replace


save "$out/cuenta_propia", replace

use "$out/cuenta_propia", clear

global important_variable cuenta_propia


preserve
    collapse (mean) $important_variable if anio != 2002, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    collapse (mean) $important_variable if anio != 2002, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
    
    twoway (line ${important_variable}_nac anio if anio >= 2000)  ///
           (line ${important_variable}_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           ytitle("Cuenta propistas") xtitle("Año") ///
           title("Cuenta propistas")
restore

graph export "$out_plot/historico_${important_variable}.pdf", replace





use "$out/cuenta_propia", clear

global important_variable cuenta_base


preserve
    collapse (mean) $important_variable if anio != 2002, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    collapse (mean) $important_variable if anio != 2002, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
    
    twoway (line ${important_variable}_nac anio if anio >= 2000)  ///
           (line ${important_variable}_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           ytitle("Cuenta propistas") xtitle("Año") ///
           title("Cuenta propistas")
restore

graph export "$out_plot/historico_${important_variable}.pdf", replace


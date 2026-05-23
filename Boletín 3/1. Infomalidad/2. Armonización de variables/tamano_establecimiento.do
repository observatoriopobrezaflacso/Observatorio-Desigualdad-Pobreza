***************** Armonización de establecimiento
clear all
set more off

* --- RUTAS ---

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

* Loop para recorrer toda la serie
forvalues anio = 1990/2025 {
    
    di "=> Procesando Año: `anio'"
    
    * 1. Carga inteligente (solo variables necesarias para no saturar memoria)
    * Usamos capture porque los nombres cambian entre pertrabn y p47a
    capture use id_persona anio pertrabn p47a using "$raw/empleo`anio'.dta", clear
    
    if _rc != 0 {
        * Si las variables no están con esos nombres, cargamos la base completa
        use "$raw/empleo`anio'.dta", clear
    }

    * 2. Creación de la variable ARMONIZADA
    gen tamano_armonizado = .
    
    * --- LÓGICA POR ÉPOCAS ---
    
    * B. Época pertrabn estándar (1993 - 2006)
    if `anio' >= 1993 & `anio' <= 2006 {
        capture replace tamano_armonizado = 1 if pertrabn == 1
        capture replace tamano_armonizado = 2 if pertrabn == 2
    }
    
    * C. Época p47a estándar (2007 - 2024)
    else if `anio' >= 2007 {
        capture replace tamano_armonizado = 1 if p47a == 1
        capture replace tamano_armonizado = 2 if p47a == 2
    }

    * 3. Limpieza y Guardado del Componente
    label define lbl_tam 1 "Menos de 100" 2 "100 y más"
    label values tamano_armonizado lbl_tam
    label var tamano_armonizado "Tamaño del establecimiento (Armonizado 90-24)"
    
	
    capture confirm variable area
	if !_rc {
	local area_var area
	destring area, replace
	} 
	else    local area_var 

	
    keep id_persona anio tamano_armonizado `area_var'
	tempfile comp_tamano_`anio' 
    save `comp_tamano_`anio'.dta', replace
}

* --- UNIÓN FINAL (APPEND) ---
di "📦 Uniendo todos los años..."
clear

use "$raw/empleo1990.dta", clear
destring area, replace

forvalues anio = 1991/2025 {
di "`anio'"
append using `comp_tamano_`anio'.dta'

}


replace area = 1 if area == .

* Guardamos el resultado final
save "$out/tamano_establecimiento.dta", replace


use "$out/tamano_establecimiento.dta", clear



******GRÁFICO*******

* 1. Preparación de datos para la serie de tiempo
gen tamano_dummy = (tamano_armonizado == 2) if !missing(tamano_armonizado)


global important_variable tamano_dummy

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



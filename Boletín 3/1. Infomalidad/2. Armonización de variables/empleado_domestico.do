*==============================================================================*
* HARMONIZACIÓN: EMPLEADO DOMÉSTICO (1990-2024)                                *
* empleado_domestico = 1 si es empleado(a) doméstico(a), 0 en otro caso        *
*==============================================================================*
* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"

global important_variable empleado_domestico

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace 
drop in 1
tempfile domestico_acumulado
save `domestico_acumulado', replace

foreach y of numlist 1990(1)2024 {
    di "*****************   `y'   ************************"
    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
        
    gen empleado_domestico = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: variable 'catetrab' (y a veces 'cates')
    * Código 8 = empleado doméstico
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc
        
        if `has_catetrab' {
            replace empleado_domestico = 1 if catetrab == 8
        }
        if `has_cates' {
            replace empleado_domestico = 1 if cates == 8
        }
        if `has_catetrab' & `has_cates' {
            replace empleado_domestico = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace empleado_domestico = . if missing(catetrab)
        }
        else if `has_cates' {
            replace empleado_domestico = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2001-2002: 'catetrab' / 'cates' con codificación expandida
    * Código 12 = empleado(a) doméstico(a)
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2001, 2002)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc
        
        if `has_catetrab' {
            replace empleado_domestico = 1 if catetrab == 12
        }
        if `has_cates' {
            replace empleado_domestico = 1 if cates == 12
        }
        if `has_catetrab' & `has_cates' {
            replace empleado_domestico = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace empleado_domestico = . if missing(catetrab)
        }
        else if `has_cates' {
            replace empleado_domestico = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2003-2006: 'catetrab' / 'cates' con codificación reducida
    * Código 9 = empleado/a doméstico/a
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2003, 2006)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc
        
        if `has_catetrab' {
            replace empleado_domestico = 1 if catetrab == 9
        }
        if `has_cates' {
            replace empleado_domestico = 1 if cates == 9
        }
        if `has_catetrab' & `has_cates' {
            replace empleado_domestico = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace empleado_domestico = . if missing(catetrab)
        }
        else if `has_cates' {
            replace empleado_domestico = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: variables p42 (ocupación principal) y p54 (secundaria)
    * Código 10 = Empleado(a) Doméstico(a)
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2007, 2024)) {
        capture confirm variable p42
        local has_p42 = !_rc
        capture confirm variable p54
        local has_p54 = !_rc
        
        if `has_p42' {
            replace empleado_domestico = 1 if p42 == 10
        }
        if `has_p54' {
            replace empleado_domestico = 1 if p54 == 10
        }
        if `has_p42' & `has_p54' {
            replace empleado_domestico = . if missing(p42) & missing(p54)
        }
        else if `has_p42' {
            replace empleado_domestico = . if missing(p42)
        }
        else if `has_p54' {
            replace empleado_domestico = . if missing(p54)
        }
    }
    
    label define lbl_dom 0 "Otra categoría" 1 "Empleado(a) doméstico(a)", replace
    label values empleado_domestico lbl_dom
    label variable empleado_domestico "Empleado(a) doméstico(a) (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 
	
    keep id_persona $important_variable anio `area_var'
    
    append using `domestico_acumulado'
    
	keep id_persona $important_variable anio `area_var'
	
    save `domestico_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd
}
save "$out/historico_empleado_domestico.dta", replace
use "$out/historico_empleado_domestico.dta", clear

* Verificación
tab anio empleado_domestico, row missing


preserve
    collapse (mean) $important_variable, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore
preserve
    collapse (mean) $important_variable, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
twoway (line ${important_variable}_nac anio)  ///
           (line ${important_variable}_urb anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f))
restore


graph export "$out_plot/historico_empleado_domestico.pdf", replace


s


preserve 
collapse (mean) empleado_domestico, by(anio)
format empleado_domestico %9.2f
twoway line empleado_domestico anio
graph export "$out_plot/historico_empleado_domestico.pdf", replace
restore

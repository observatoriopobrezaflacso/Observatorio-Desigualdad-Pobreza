*==============================================================================*
* HARMONIZACIÓN: NO REMUNERADO O no_rem DOMÉSTICO (2007-2024)                  *
* no_rem = 1 si la categoría de ocupación corresponde a:                       *
*   - Trabajador del hogar no remunerado (p42/p54 == 7)                        *
*   - Trabajador no del hogar no remunerado (p42/p54 == 8)                     *
*   - Ayudante no remunerado de asalariado/jornalero (p42/p54 == 9)            *
*   - no_rem(a) doméstico(a) (p42/p54 == 10)                                   *
* 0 en otro caso                                                               *
*==============================================================================*
* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"


global important_variable no_rem

use "$raw/empleo2007.dta" in 1, clear 
drop in 1
tempfile nrd_acumulado
save `nrd_acumulado', replace

foreach y of numlist 2007(1)2024 {
    di "*****************   `y'   ************************"
    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    *gen anio = `y'
    
    gen no_rem = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: variables p42 (ocupación principal) y p54 (secundaria)
    * Código 7  = Trabajador del hogar no remunerado
    * Código 8  = Trabajador no del hogar no remunerado
    * Código 9  = Ayudante no remunerado de asalariado/jornalero
    * Código 10 = no_rem(a) Doméstico(a)
    *--------------------------------------------------------------------------*
    capture confirm variable p42
    local has_p42 = !_rc
    capture confirm variable p54
    local has_p54 = !_rc
    
    if `has_p42' {
        replace no_rem = 1 if inlist(p42, 7, 8, 9)
    }
    if `has_p54' {
        replace no_rem = 1 if inlist(p54, 7, 8, 9)
    }
    if `has_p42' & `has_p54' {
        replace no_rem = . if missing(p42) & missing(p54)
    }
    else if `has_p42' {
        replace no_rem = . if missing(p42)
    }
    else if `has_p54' {
        replace no_rem = . if missing(p54)
    }
    
    label define lbl_nrd 0 "Otra categoría" 1 "Trab. no remunerado", replace
    label values no_rem lbl_nrd
    label variable no_rem "Trab. no remunerado (hogar/no hogar/ayudante) "
    
    *do "$gh/Generales/id_persona_loop.do"
    
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 

	
    keep id_persona $important_variable anio `area_var' fexp
    
    append using `nrd_acumulado'

    keep id_persona $important_variable anio `area_var' fexp
    
    save `nrd_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd
}

save "$out/historico_no_rem_2007_2024.dta", replace
use "$out/historico_no_rem_2007_2024.dta", clear


* Verificación
tab anio no_rem, row missing


preserve
    collapse (mean) $important_variable [iw = fexp] if anio != 2002, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore
preserve
    collapse (mean) $important_variable [iw = fexp], by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
twoway (line ${important_variable}_nac anio)  ///
           (line ${important_variable}_urb anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f))
restore


graph export "$out_plot/historico_no_rem.pdf", replace




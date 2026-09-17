*==============================================================================*
* HARMONIZACIÓN: TRABAJADOR FAMILIAR NO REMUNERADO (1990-2024)                 *
* no_remunerado = 1 si es trabajador familiar no remunerado, 0 en otro caso    *
*==============================================================================*
* Definición de rutas globales para facilitar la portabilidad del código
* Raiz del Drive segun el usuario que corre el script: antes estaba fija en
* la carpeta de vero, asi que el do-file no arrancaba en otras maquinas.
if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"

global important_variable no_remunerado

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1
tempfile no_rem_acumulado
save `no_rem_acumulado', replace

foreach y of numlist 1990(1)2025 {
    di "*****************   `y'   ************************"
    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
   * gen anio = `y'
    
    gen no_remunerado = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-1999: 'catetrab'; desde 1991 también 'cates'
    * Código 5 = trabajador familiar no remunerado
    *
    * OJO: el corte va en 1999, no en 2000. El año 2000 ya trae la codificación
    * de 2001 y se procesa más abajo (ver la nota de esa rama).
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 1999)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc
        
        replace no_remunerado = 1 if catetrab == 5
        if `y' >= 1991 & `has_cates' {
            replace no_remunerado = 1 if cates == 5
        }

        * Desde 1991, usar ambas ocupaciones con el mismo criterio de 2001 en adelante.
        * Una ocupación remunerada impide clasificar a la persona como no remunerada.
        replace no_remunerado = 0 if !missing(catetrab) & catetrab != 5
        if `y' >= 1991 & `has_cates' {
            replace no_remunerado = 0 if !missing(cates) & cates != 5
        }
		
        if `has_catetrab' & `has_cates' {
            replace no_remunerado = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace no_remunerado = . if missing(catetrab)
        }
        else if `has_cates' {
            replace no_remunerado = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2000-2001: 'catetrab' / 'cates' con nueva codificación
    * Código 6 = trab. fam. no remunerado
    * Código 11 = trab. fam. agrop. no remunerado
    *
    * El año 2000 entra aquí, y no en la rama de los noventa, porque su
    * 'catetrab' ya viene con esta codificación aunque conserve pegada la
    * etiqueta de valores vieja (que sólo define los códigos 3-9). Procesarlo
    * con la regla de los noventa ("código 5") marcaba como no remunerados a
    * los CUENTA PROPIA, que en esta codificación son justamente el 5: el
    * indicador saltaba al 21,8% en 2000 frente al 4,9% de 1999 y el 8,6% de
    * 2003. Con esta rama baja al 9,7%, que es lo que corresponde.
    *
    * La evidencia está en componentes/verificacion_catetrab_2000.do:
    *   - en 2000 los códigos 1, 2, 10, 11 y 12 no tienen etiqueta (14.876 obs);
    *   - su distribución calca la de 2001 y no la de 1999;
    *   - el 93,8% del código 5 declara ingreso laboral (o sea, es remunerado),
    *     mientras que los que no declaran ingreso son los códigos 6 y 11.
    *--------------------------------------------------------------------------*
    if (inlist(`y', 2000, 2001)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc

        * En 2001, cates = 0 también indica secundaria no aplicable.
        * No debe interpretarse como una categoría ocupacional remunerada.
        * (En 2000 no hay ceros, así que la línea no lo toca.)
        if `has_cates' replace cates = . if cates == 0
        
		replace no_remunerado = 1 if inlist(catetrab, 6, 11)
		replace no_remunerado = 1 if inlist(cates, 6, 11)
		
		replace no_remunerado = 0 if !missing(catetrab) & !inlist(catetrab, 6, 11)
		replace no_remunerado = 0 if !missing(cates)    & !inlist(cates, 6, 11)
			
        if `has_catetrab' & `has_cates' {
            replace no_remunerado = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace no_remunerado = . if missing(catetrab)
        }
        else if `has_cates' {
            replace no_remunerado = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2002: 'catetrab' / 'cates' (misma codificación que 2001)
    * Código 6 = trab. del hogar no remunerado
    * Código 11 = trab. fam. agrop. no remunerado
    *--------------------------------------------------------------------------*
    if (`y' == 2002) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc

        * En 2002, cates = 0 no es una categoría ocupacional válida.
        * Tratar la secundaria no aplicable como faltante para que no anule la principal.
        if `has_cates' replace cates = . if cates == 0
        
		replace no_remunerado = 1 if inlist(catetrab, 6, 11)
		replace no_remunerado = 1 if inlist(cates, 6, 11)
		
		replace no_remunerado = 0 if !missing(catetrab) & !inlist(catetrab, 6, 11)
		replace no_remunerado = 0 if !missing(cates) & !inlist(cates, 6, 11)
		
        if `has_catetrab' & `has_cates' {
            replace no_remunerado = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace no_remunerado = . if missing(catetrab)
        }
        else if `has_cates' {
            replace no_remunerado = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2003-2006: 'catetrab' / 'cates' con codificación reducida
    * Código 8 = trab. familiar no remunerado
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2003, 2006)) {
        capture confirm variable catetrab
        local has_catetrab = !_rc
        capture confirm variable cates
        local has_cates = !_rc
        
		replace no_remunerado = 1 if catetrab == 8
		replace no_remunerado = 1 if cates == 8
		
		replace no_remunerado = 0 if !missing(catetrab) & catetrab != 8
		replace no_remunerado = 0 if !missing(cates)    & cates    != 8
		
        if `has_catetrab' & `has_cates' {
            replace no_remunerado = . if missing(catetrab) & missing(cates)
        }
        else if `has_catetrab' {
            replace no_remunerado = . if missing(catetrab)
        }
        else if `has_cates' {
            replace no_remunerado = . if missing(cates)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: variables p42 (ocupación principal) y p54 (secundaria)
    * Código 7 = Trabajador del hogar no remunerado
    * Código 8 = Trabajador no del hogar no remunerado
    * Código 9 = Ayudante no remunerado de asalariado/jornalero
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
        capture confirm variable p42
        local has_p42 = !_rc
        capture confirm variable p54
        local has_p54 = !_rc
        
		replace no_remunerado = 1 if inlist(p42, 7, 8, 9) 
		replace no_remunerado = 1 if inlist(p54, 7, 8, 9) 
		replace no_remunerado = 0 if !missing(p54) & !inlist(p54, 7, 8, 9) 
		replace no_remunerado = 0 if !missing(p42) & !inlist(p42, 7, 8, 9) 
			
        if `has_p42' & `has_p54' {
            replace no_remunerado = . if missing(p42) & missing(p54)
        }
        else if `has_p42' {
            replace no_remunerado = . if missing(p42)
        }
        else if `has_p54' {
            replace no_remunerado = . if missing(p54)
        }
    }
    
    label define lbl_norem 0 "Remunerado / Otra categoría" 1 "Trabajador no remunerado", replace
    label values no_remunerado lbl_norem
    label variable no_remunerado "Trabajador no remunerado (armonizado)"
    
	
    *do "$gh/Generales/id_persona_loop.do"
    
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 
	
    keep id_persona $important_variable anio `area_var' fexp edad condact*
	
    append using `no_rem_acumulado'
	
	keep id_persona $important_variable anio `area_var' fexp edad condact*

    save `no_rem_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    *if (`n' != 0) asd
}
save "$out/historico_no_remunerado.dta", replace
use "$out/historico_no_remunerado.dta", clear

* Verificación
tab anio no_remunerado [iw = fexp], row missing
tab anio no_remunerado [iw = fexp], nofreq row


/*

s


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
    collapse (mean) $important_variable  if anio != 2002, by(anio)
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
*/

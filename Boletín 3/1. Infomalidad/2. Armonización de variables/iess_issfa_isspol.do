*==============================================================================*
* HARMONIZACIÓN: AFILIACIÓN AL IESS (1990-2024)                                *
* affiliated = 1 si la persona está afiliada a algun seguro, 0 en otro caso    *
*==============================================================================*


* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable affiliated

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile iess_acumulado
save `iess_acumulado', replace

foreach y of numlist 1990(1)2025 {

    di "*****************   `y'   ************************"

    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    *gen anio = `y'
    
    gen affiliated = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: variable 'iess' binaria (1=sí, 2=no)
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
            replace affiliated = 1 if iess == 1
            replace affiliated = . if missing(iess) | inrange(condact, 5, 8)
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2001-2006: 'iess' multicategórica
    * IESS general = 2, IESS campesino = 3, ISSFA/ISSPOL = 4
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2001, 2006)) {
	
            replace affiliated = 1 if inlist(iess, 2, 3, 4)
            replace affiliated = . if missing(iess) | inrange(condact, 5, 8)
			s
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: variables p05a y p05b
    * IESS general = 1, IESS voluntario = 2, IESS campesino = 3, ISSFA/ISSPOL = 4
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2007, 2025)) {
		
		cap confirm variable condactn 
		if !_rc local condact_var condactn
		else    local condact_var condact
		
		replace affiliated = 1 if inrange(p05a, 1, 4)
		replace affiliated = 1 if inrange(p05b, 1, 4)
		replace affiliated = . if (missing(p05a) & missing(p05b)) ///
								  | inlist(`condact_var', 0, 7, 8, 9)		
    }
    
    label define lbl_iess 1 "Tiene seguro" 0 "No tiene seguro", replace
    label values affiliated lbl_iess
    label variable affiliated "Tenencia de seguro (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 
	
    keep id_persona $important_variable anio `area_var' fexp
	
	append using `iess_acumulado'
	
    keep id_persona $important_variable anio `area_var' fexp
        
    save `iess_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_iess_issfa_isspol.dta", replace

use "$out/historico_iess_issfa_isspol.dta", clear
s
* Verificación
tab anio affiliated [iw = fexp], nofreq row missing
tab anio affiliated [iw = fexp], nofreq row



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

graph export "$out_plot/historico_{$important_variable}_issfa_isspol.pdf", replace

*==============================================================================*
* ARMONIZACIÓN: ESTABLECIMIENTO TIENE RUC (1990-2024)                        *
* tiene_ruc = 1 si el establecimiento tiene RUC, 0 en otro caso               *
* "No sabe" se codifica como missing (.)                                      *
*==============================================================================*

* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable tiene_ruc

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile ruc_acumulado
save `ruc_acumulado', replace

foreach y of numlist 1990(1)2025 {

    di "*****************   `y'   ************************"

    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    * Inicializar variable armonizada de RUC
    gen tiene_ruc = .
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: NO DISPONIBLE
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
        * No hay información de RUC en estos años
        replace tiene_ruc = .
    }
    
    *--------------------------------------------------------------------------*
    * 2001: Variable pe51 (el establecimiento tiene ruc)
    * 1 si / 2 no
    *--------------------------------------------------------------------------*
    if (`y' == 2001) {
        capture confirm variable pe51
        if !_rc {
			replace tiene_ruc = pe51 == 2
			replace tiene_ruc = . if inrange(condact, 5, 8)			
			gen institucion_formal = cond(catetrab == 1, 1, tiene_ruc)
			
        }
    }
    
    *--------------------------------------------------------------------------*
    * 2002: Variable pe49 (el establecimiento donde trabaja tiene ruc)
    * 1 si / 2 no / 9 no sabe
    *--------------------------------------------------------------------------*
    if (`y' == 2002) {
        capture confirm variable pe49
        if !_rc {
            replace tiene_ruc = 1 if pe49 == 1  // Sí
            replace tiene_ruc = 0 if pe49 == 2  // No
            replace tiene_ruc = . if pe49 == 9  // No sabe → missing
            replace tiene_ruc = . if missing(pe49)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2003-2006: Variable pe49 (establecimiento tiene ruc)
    * 1 si / 2 no / 3 no sabe
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2003, 2006)) {
        capture confirm variable pe49
        if !_rc {
            replace tiene_ruc = 1 if pe49 == 1  // Sí
            replace tiene_ruc = 0 if pe49 == 2  // No
            replace tiene_ruc = . if pe49 == 3  // No sabe → missing
            replace tiene_ruc = . if missing(pe49)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: Variable p49 (El establecimiento tiene RUC)
    * 1 Si / 2 No / 3 No sabe
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
        capture confirm variable p49
        if !_rc {
            replace tiene_ruc = 1 if p49 == 1  // Sí
            replace tiene_ruc = 0 if p49 == 2  // No
            replace tiene_ruc = . if p49 == 3  // No sabe → missing
            replace tiene_ruc = . if missing(p49)
        }
    }
    
    * Etiquetar variable armonizada
    label define lbl_ruc 0 "No tiene RUC" 1 "Tiene RUC", replace
    label values tiene_ruc lbl_ruc
    label variable tiene_ruc "Establecimiento tiene RUC (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
    capture confirm variable area 
    if  !_rc {
        local area_var area
        destring area, replace 
    }
    else local area_var 
    
    keep id_persona $important_variable anio `area_var'
    
    append using `ruc_acumulado'
    
    keep id_persona $important_variable anio `area_var'
        
    save `ruc_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_ruc.dta", replace
s
use "$out/historico_ruc.dta", clear

* Verificación
tab anio tiene_ruc, row missing

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
    
    twoway (line ${important_variable}_nac anio)  ///
           (line ${important_variable}_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           ytitle("Proporción de establecimientos con RUC") xtitle("Año") ///
           title("Evolución de formalización: Establecimientos con RUC (2001-2024)")
restore

graph export "$out_plot/historico_${important_variable}.pdf", replace




/*

gen asked_p49 = 0
label variable asked_p49 "Observation was asked Question 49"

* OCUPADOS reach the establishment block
replace asked_p49 = 1 if p20 == 1
replace asked_p49 = 1 if !missing(p21) & p21 != 12
replace asked_p49 = 1 if p22 == 1

* But those with p47 == 2 (100+ workers) skip to P50, bypassing P49
replace asked_p49 = 0 if p47a == 2

tab asked_p49 if !missing(p49)


* Final version
gen asked_p49 = 0
label variable asked_p49 "Observation was asked Question 49 (RUC)"

* OCUPADOS reach this block
replace asked_p49 = 1 if p20 == 1
replace asked_p49 = 1 if !missing(p21) & p21 != 12
replace asked_p49 = 1 if p22 == 1

* Exclude per the universe header above P49:
replace asked_p49 = 0 if p42 == 1     // Empleado de gobierno
replace asked_p49 = 0 if p42 == 10    // Empleado(a) Doméstico(a)
replace asked_p49 = 0 if p47a == 2    // Establecimiento de 100 y más

tab asked_p49 if !missing(p49)
tab asked_p49


replace secemp =2 if pea==1 & empleo==1 & p47a==1 & p49==2 & secemp ==.


*/

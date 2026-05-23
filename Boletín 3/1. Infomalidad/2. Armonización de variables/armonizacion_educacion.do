*==============================================================================*
* ARMONIZACIÓN: EDUCACIÓN UNIVERSITARIA (1990-2024)                          *
* educ_univ = 1 si tiene educación universitaria, 0 en otro caso              *
*==============================================================================*

* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable educ_univ

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile educ_acumulado
save `educ_acumulado', replace

foreach y of numlist 1990(1)2025 {

    di "*****************   `y'   ************************"

    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    * Inicializar variable armonizada de educación universitaria
    gen educ_univ = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: Variable 'nivinst' con 5 categorías
    * 1 ninguno / 2 alfabetización / 3 primaria / 4 secundaria / 5 superior
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
        capture confirm variable nivinst
        if !_rc {
            replace educ_univ = 1 if nivinst == 5  // Superior
            replace educ_univ = . if missing(nivinst)
        }
    }
    
    *--------------------------------------------------------------------------*
    * 2001: nivinst con 7 categorías (incluye jardín y postgrado)
    * 1 ninguno / 2 alfabetización / 3 jardín / 4 primaria / 
    * 5 secundaria / 6 superior / 7 postgrado
    *--------------------------------------------------------------------------*
    if (`y' == 2001) {
        capture confirm variable nivinst
        if !_rc {
            replace educ_univ = 1 if inlist(nivinst, 6, 7)  // Superior o postgrado
            replace educ_univ = . if missing(nivinst)
        }
    }
    
    *--------------------------------------------------------------------------*
    * 2002: nivinst con 8 categorías (separa superior universitaria/no univ)
    * 1 ninguno / 2 alfabetización / 3 jardín / 4 primaria / 5 secundaria / 
    * 6 superior no universitaria / 7 superior / 8 postgrado
    *--------------------------------------------------------------------------*
    if (`y' == 2002) {
        capture confirm variable nivinst
        if !_rc {
            replace educ_univ = 1 if inlist(nivinst, 7, 8)  // Superior universitaria o postgrado
            replace educ_univ = . if missing(nivinst)
        }
    }
    
    *--------------------------------------------------------------------------*
    * 2003-2006: nivinst con 10 categorías (más desagregado)
    * 1 ninguno / 2 alfabetización / 3 jardín / 4 primaria / 5 educ básica / 
    * 6 secundaria / 7 educ media / 8 superior no universitaria / 
    * 9 superior universitaria / 10 postgrado
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2003, 2006)) {
        capture confirm variable nivinst
        if !_rc {
            replace educ_univ = 1 if inlist(nivinst, 9, 10)  // Superior universitaria o postgrado
            replace educ_univ = . if missing(nivinst)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: Variables p10a (nivel) y p10b (año aprobado)
    * p10a: 1 Ninguno / 2 Alfabetización / 3 Jardín / 4 Primaria / 
    *       5 Educación Básica / 6 Secundaria / 7 Educación Media / 
    *       8 Superior no universitario / 9 Superior Universitario / 10 Postgrado
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
        capture confirm variable p10a
        if !_rc {
            replace educ_univ = 1 if inlist(p10a, 9, 10)  // Superior universitaria o postgrado
            replace educ_univ = . if missing(p10a)
        }
    }
    
    * Etiquetar variable armonizada
    label define lbl_educ 0 "No universitaria" 1 "Universitaria", replace
    label values educ_univ lbl_educ
    label variable educ_univ "Educación universitaria (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
    capture confirm variable area 
    if  !_rc {
        local area_var area
        destring area, replace 
    }
    else local area_var 
    
    keep id_persona $important_variable anio `area_var'
    
    append using `educ_acumulado'
    
    keep id_persona $important_variable anio `area_var'
        
    save `educ_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_educacion.dta", replace

use "$out/historico_educacion.dta", clear

* Verificación
tab anio educ_univ, row missing

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
           (line ${important_variable}_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           ytitle("Proporción con educación universitaria") xtitle("Año") ///
           title("Evolución de la educación universitaria (1990-2025)")
restore

graph export "$out_plot/historico_${important_variable}.pdf", replace

*==============================================================================*
* ARMONIZACIÓN: ESTABLECIMIENTO TIENE RUC (2001-2025)                        *
* tiene_ruc = 1 si el establecimiento tiene RUC, 0 en otro caso               *
* "No sabe" se codifica como missing (.)                                      *
*==============================================================================*

* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/santiago/Documents/GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable tiene_ruc

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile ruc_acumulado
save `ruc_acumulado', replace

foreach y of numlist 2001(1)2025 {

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
            *replace tiene_ruc = 1 if pe51 == 1  // Sí
            *replace tiene_ruc = 0 if pe51 == 2  // No
            *replace tiene_ruc = . if missing(pe51)
			gen no_tiene_ruc = (pe51 == 2) if inlist(pe51, 1, 2)
			replace no_tiene_ruc = . if inrange(condact, 5, 8)			
			replace tiene_ruc = (no_tiene_ruc * - 1) + 1
			gen institucion_formal = cond(catetrab == 1, 1, tiene_ruc)
			replace institucion_formal = 1 if pertrabn == 2

        }
    }
    
    *--------------------------------------------------------------------------*
    * 2002: Variable pe49 (el establecimiento donde trabaja tiene ruc)
    * 1 si / 2 no / 9 no sabe
    *--------------------------------------------------------------------------*
    if (`y' == 2002) {

        capture confirm variable pe49
        if !_rc {
           * replace tiene_ruc = 1 if pe49 == 1  // Sí
           * replace tiene_ruc = 0 if pe49 == 2  // No
           * replace tiene_ruc = . if pe49 == 9  // No sabe → missing
           * replace tiene_ruc = . if missing(pe49)
		   
		   	gen no_tiene_ruc = (pe49 == 2) if inlist(pe49, 1, 2)
			replace no_tiene_ruc = . if inrange(condact, 5, 8) | pe49 == 9		
			replace tiene_ruc = (no_tiene_ruc * - 1) + 1
			gen institucion_formal = cond(catetrab == 1, 1, tiene_ruc)
			replace institucion_formal = 1 if pertrabn == 2
			
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2003-2006: Variable pe49 (establecimiento tiene ruc)
    * 1 si / 2 no / 3 no sabe
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2003, 2006)) {
			
        capture confirm variable pe49
        if !_rc {
			
            *replace tiene_ruc = 1 if pe49 == 1  // Sí
            *replace tiene_ruc = 0 if pe49 == 2  // No
            *replace tiene_ruc = . if pe49 == 3  // No sabe → missing
            *replace tiene_ruc = . if missing(pe49)
		   	gen no_tiene_ruc = pe49 == 2
			replace no_tiene_ruc = . if inrange(condact, 5, 8) | pe49 == 3 | missing(pe49)		
			replace tiene_ruc = (no_tiene_ruc * - 1) + 1
			gen institucion_formal = cond(catetrab == 1, 1, tiene_ruc)
			replace institucion_formal = 1 if pertrabn == 2
			
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2025: Variable p49 (El establecimiento tiene RUC)
    * 1 Si / 2 No / 3 No sabe
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
		
        capture confirm variable p49
        if !_rc {
            *replace tiene_ruc = 1 if p49 == 1  // Sí
            *replace tiene_ruc = 0 if p49 == 2  // No
            *replace tiene_ruc = . if p49 == 3  // No sabe → missing
            *replace tiene_ruc = . if missing(p49)
			
			cap confirm variable condactn 
			if !_rc local condact_var condactn
			else    local condact_var condact
			
			gen no_tiene_ruc = p49 == 2 if p49 != 3 & !missing(p49) & empleo == 1
			replace tiene_ruc = (no_tiene_ruc * - 1) + 1

			gen institucion_formal = cond(p47a == 2, 1, tiene_ruc) ///
			if empleo == 1
			
        }
    }
    
    * Etiquetar variable RUC
    label define lbl_ruc 0 "No tiene RUC" 1 "Tiene RUC", replace
    label values tiene_ruc lbl_ruc
    label variable tiene_ruc "Establecimiento tiene RUC (armonizado)"
	
	 * Etiquetar variable institucion formal
    label define lbl_if 0 "No Institucion Formal" 1 "Institucion Formal", replace
    label values institucion_formal lbl_if
    label variable institucion_formal "Trabaja en institucion formal"

    
    * do "$gh/Generales/id_persona_loop.do"
    
    capture confirm variable area 
    if  !_rc {
        local area_var area
        destring area, replace 
    }
    else local area_var 
    
    keep id_persona $important_variable anio `area_var' institucion_formal no_tiene_ruc fexp
    
    append using `ruc_acumulado'
    
    keep id_persona $important_variable anio `area_var' institucion_formal  no_tiene_ruc fexp
        
    save `ruc_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_ruc.dta", replace

use "$out/historico_ruc.dta", clear

* Verificación
tab anio tiene_ruc [iw = fexp], nofreq row
tab anio institucion_formal [iw = fexp], nofreq row

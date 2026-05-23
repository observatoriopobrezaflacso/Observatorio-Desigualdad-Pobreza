*==============================================================================*
* ARMONIZACIÓN: ETNIA/AUTOIDENTIFICACIÓN ÉTNICA (1990-2024)                  *
* etnia_arm = variable armonizada de autoidentificación étnica                *
* Categorías: 1=Indígena, 2=Negro/Afro, 3=Blanco/Mestizo, 4=Otro              *
*==============================================================================*

* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable etnia_arm

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile etnia_acumulado
save `etnia_acumulado', replace

foreach y of numlist 2003(1)2025 {

    di "*****************   `y'   ************************"

    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    * Inicializar variable armonizada de etnia
    gen etnia_arm = .
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: NO DISPONIBLE
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
        * No hay información de etnia en estos años
        replace etnia_arm = .
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2001-2002: Variables pe13 (idioma) y pe14 (autoidentificación)
    * pe14: 1 blanco / 2 negro / 3 indígena / 4 mestizo / 5 mulato / 6 otro
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2001, 2002)) {
        capture confirm variable pe14
        if !_rc {
            replace etnia_arm = 1 if pe14 == 3              // Indígena
            replace etnia_arm = 2 if inlist(pe14, 2, 5)     // Negro/Mulato
            replace etnia_arm = 3 if inlist(pe14, 1, 4)     // Blanco/Mestizo
            replace etnia_arm = 4 if pe14 == 6              // Otro
            replace etnia_arm = . if missing(pe14)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2003: Variable pe13 (autoidentificación directa)
    * pe13: 1 indígena / 2 blanco / 3 mestizo / 4 negro / 5 mulato / 6 otro
    *--------------------------------------------------------------------------*
    if (`y' == 2003) {
        capture confirm variable pe13
        if !_rc {
            replace etnia_arm = 1 if pe13 == 1              // Indígena
            replace etnia_arm = 2 if inlist(pe13, 4, 5)     // Negro/Mulato
            replace etnia_arm = 3 if inlist(pe13, 2, 3)     // Blanco/Mestizo
            replace etnia_arm = 4 if pe13 == 6              // Otro
            replace etnia_arm = . if missing(pe13)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2004-2006: Variable pe13 (autoidentificación directa)
    * pe13: 1 indígena / 2 blanco / 3 mestizo / 4 negro / 5 mulato / 6 otro
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2004, 2006)) {
        capture confirm variable pe13
        if !_rc {
            replace etnia_arm = 1 if pe13 == 1              // Indígena
            replace etnia_arm = 2 if inlist(pe13, 4, 5)     // Negro/Mulato
            replace etnia_arm = 3 if inlist(pe13, 2, 3)     // Blanco/Mestizo
            replace etnia_arm = 4 if pe13 == 6              // Otro
            replace etnia_arm = . if missing(pe13)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: Variable p15 (autoidentificación ampliada)
    * p15: 1 Indígena / 2 Afroecuatoriano / 3 Negro / 4 Mulato / 
    *      5 Montubio / 6 Mestizo / 7 Blanco / 8 Otro
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
        capture confirm variable p15
        if !_rc {
            replace etnia_arm = 1 if p15 == 1                    // Indígena
            replace etnia_arm = 2 if inlist(p15, 2, 3, 4)        // Afroecuatoriano/Negro/Mulato
            replace etnia_arm = 3 if inlist(p15, 6, 7)           // Mestizo/Blanco
            replace etnia_arm = 4 if inlist(p15, 5, 8)           // Montubio/Otro
            replace etnia_arm = . if missing(p15)
        }
    }
    
    * Etiquetar variable armonizada
    label define lbl_etnia 1 "Indígena" 2 "Negro/Afro" 3 "Blanco/Mestizo" 4 "Otro", replace
    label values etnia_arm lbl_etnia
    label variable etnia_arm "Etnia (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
    capture confirm variable area 
    if  !_rc {
        local area_var area
        destring area, replace 
    }
    else local area_var 
    
    keep id_persona $important_variable anio `area_var'
    
    append using `etnia_acumulado'
    
    keep id_persona $important_variable anio `area_var'
        
    save `etnia_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_etnia.dta", replace

use "$out/historico_etnia.dta", clear

tab anio etnia_arm, nofreq row

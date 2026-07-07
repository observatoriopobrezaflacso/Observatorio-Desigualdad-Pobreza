*==============================================================================
* ARMONIZACIÓN: TRABAJADOR POR CUENTA PROPIA - ENEMDU 1990-2025
* FLACSO - Observatorio de Pobreza
*
* Variable dicotómica:
*   1 = Cuenta propia
*   0 = Resto de ocupados
*   . = No ocupados (inactivos, desocupados, sin dato)
*
* Períodos y códigos verificados contra datos reales:
*   1990-1999  catetrab / cates   código 4
*   2000       catetrab / cates   códigos 4 y 10
*   2001-2002  catetrab / cates   códigos 5 y 10 (excluye código 0)
*   2003-2006  catetrab / cates   código 7
*   2007-2025  p42 / p54          código 6
*
* Estructura final: id_persona (str) + anio (num) + cuenta_propia (byte)
*==============================================================================

clear all
set more off


* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"

* --- 2. CARPETA TEMPORAL LOCAL ---
local tmpdir      "/Users/vero/tmp_enemdu"
cap mkdir         "`tmpdir'"
local master_base "`tmpdir'/master_base.dta"

* --- ARCHIVO MAESTRO VACÍO EN DISCO LOCAL ---
clear
save "`master_base'", emptyok replace

*------------------------------------------------------------------------------
* BUCLE PRINCIPAL
*------------------------------------------------------------------------------
forvalues year = 1990/2025 {

 
        use "$raw/empleo`year'.dta", clear

        * Estandarizar identificadores
        * Fix: drop explícito + gen str para evitar conflicto de tipos entre años
        capture tostring id_persona, replace force
        capture drop anio
        gen int anio = `year'

        *------------------------------------------------------------------
        * VARIABLE cuenta_propia
        * Lógica en dos pasos: evita que missing de catetrab entre al 0
        *------------------------------------------------------------------
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

        * 2001-2002: códigos 5 y 10 — excluye código 0 (no ocupados mal codificados)
        else if inrange(`year', 2001, 2002) {
            capture replace cuenta_propia = 0 if !missing(catetrab) & catetrab != 0
            capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates) & cates != 0
            capture replace cuenta_propia = 1 if inlist(catetrab, 5, 10)
            capture replace cuenta_propia = 1 if  missing(catetrab) & inlist(cates, 5, 10)
        }

        * 2003-2006: código 7
        else if inrange(`year', 2003, 2006) {
            capture replace cuenta_propia = 0 if !missing(catetrab)
            capture replace cuenta_propia = 0 if  missing(catetrab) & !missing(cates)
            capture replace cuenta_propia = 1 if catetrab == 7
            capture replace cuenta_propia = 1 if  missing(catetrab) & cates == 7
        }

        * 2007-2025: código 6 en p42 (principal) o p54 (secundario)
        else if `year' >= 2007 {
            capture replace cuenta_propia = 0 if !missing(p42)
            capture replace cuenta_propia = 0 if  missing(p42) & !missing(p54)
            capture replace cuenta_propia = 1 if p42 == 6
            capture replace cuenta_propia = 1 if  missing(p42) & p54 == 6
        }

        * Solo variables necesarias — evita conflictos de tipo en el append
        keep id_persona anio cuenta_propia

        append using "`master_base'"
        save "`master_base'", replace


}  // fin forvalues

*------------------------------------------------------------------------------
* FINALIZACIÓN
*------------------------------------------------------------------------------
use "`master_base'", clear

label variable id_persona    "Identificador de persona (INEC)"
label variable anio          "Año de la encuesta"
label variable cuenta_propia "Trabajador por cuenta propia (armonizada 1990-2025)"

label define cp_lab 1 "Cuenta propia" 0 "Resto de ocupados", replace
label values cuenta_propia cp_lab

tab cuenta_propia, missing

save "$out/cuentapropista", replace

cap erase "`master_base'"

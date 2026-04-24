*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
* Versión con ingrl armonizado — Emilio (Windows)
*------------------------------------------------------------------*
clear all
set more off

global bases_armonizadas "H:\Mi unidad\Bases\ENEMDU\Procesadas\analisis informalidad\Santiago"
global raw "H:\Mi unidad\Bases\ENEMDU\Procesadas\Armonizacion\Variables base\Trimestrales"

*--- Start with the Master file ---*
use "$bases_armonizadas/historico_iess.dta", clear
isid id_persona anio, missok

*--- Merges variables armonizadas ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_adec.dta", generate(m_adec)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_ruc.dta", generate(m_ruc)
merge 1:1 id_persona anio using "$bases_armonizadas/tamano_establecimiento.dta", generate(m_tamano)
merge 1:1 id_persona anio using "$bases_armonizadas/pea.dta", generate(m_pea)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_no_remunerado.dta", generate(m_no_remunerado)
merge 1:1 id_persona anio using "$bases_armonizadas/cuenta_propia.dta", generate(m_cuentapropia) keepusing(id_persona cuenta_propia cuenta_base)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_etnia.dta", generate(m_etnia)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_educacion.dta", generate(m_educacion)

drop m_*

*--- Merge bases originales: fexp, sexo, edad, provincia + ingrl ---*
forval y = 1990/2025 {
    capture confirm file "$raw/empleo`y'.dta"
    if _rc != 0 continue
    merge 1:1 id_persona anio using "$raw/empleo`y'.dta", ///
        keepusing(fexp sexo edad provincia ingrl) update replace nogen
}

recode tamano_armonizado (2=1) (1=0)

*------------------------------------------------------------------*
* Armonización de ingrl
*------------------------------------------------------------------*

recode ingrl (-1=.) (999999=.) (9999998=.) (9999999=.) (0=.)

local tc_1990 = 767
local tc_1991 = 1046
local tc_1992 = 1534
local tc_1993 = 1919
local tc_1994 = 2197
local tc_1995 = 2564
local tc_1996 = 3189
local tc_1997 = 3998
local tc_1998 = 5446
local tc_1999 = 11787

forvalues y = 1990/1999 {
    replace ingrl = ingrl / `tc_`y'' if anio == `y'
}

di "===== Verificación ingrl por año ====="
forvalues y = 1990/2024 {
    quietly sum ingrl if anio == `y'
    di "Año `y': media = " %6.1f r(mean) "  |  p50 = " %6.1f r(p50) "  |  N = " r(N)
}

*------------------------------------------------------------------*
* Keep y guardar
*------------------------------------------------------------------*
local vars affiliated_iess adec no_remunerado tamano_armonizado ///
           mi_pea tiene_ruc cuenta_propia cuenta_base

keep `vars' fexp sexo edad provincia educ_univ etnia anio area ingrl

save "$bases_armonizadas/base_trabajo_cningrl.dta", replace

di "===== Guardado: base_trabajo_cningrl.dta ====="
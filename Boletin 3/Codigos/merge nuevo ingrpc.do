clear all
set more off

global user_root "H:\Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global bases_armonizadas "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"

use "$bases_armonizadas/historico_iess.dta", clear
isid id_persona anio, missok

merge 1:1 id_persona anio using "$bases_armonizadas/historico_adec.dta", generate(m_adec)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_ruc.dta", generate(m_ruc)
merge 1:1 id_persona anio using "$bases_armonizadas/tamano_establecimiento.dta", generate(m_tamano)
merge 1:1 id_persona anio using "$bases_armonizadas/pea.dta", generate(m_pea)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_no_remunerado.dta", generate(m_no_remunerado)
merge 1:1 id_persona anio using "$bases_armonizadas/cuenta_propia.dta", generate(m_cuentapropia) keepusing(id_persona cuenta_propia cuenta_base)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_etnia.dta", generate(m_etnia)
merge 1:1 id_persona anio using "$bases_armonizadas/historico_educacion.dta", generate(m_educacion)

drop m_*

* Extracción de las llaves necesarias para el merge con ingrpc
forval y = 1990/2025 {
    capture confirm file "$raw/empleo`y'.dta"
    if _rc != 0 continue
    
    merge 1:1 id_persona anio using "$raw/empleo`y'.dta", ///
        keepusing(fexp sexo edad provincia ciudad zona sector panel panelm vivienda hogar p04) update replace nogen
}

* Corrección de inconsistencias históricas en los nombres de las variables de diseño
capture confirm variable panel
if _rc == 0 {
    capture confirm variable panelm
    if _rc != 0 gen panelm = .
    replace panelm = panel if panelm == . & panel != .
    drop panel
}

foreach v in ciudad zona sector panelm vivienda hogar p04 {
    capture confirm variable `v'
    if _rc != 0 gen `v' = .
}

recode tamano_armonizado (2 = 1) (1 = 0)

* Retención de variables
local vars affiliated_iess adec no_remunerado tamano_armonizado mi_pea tiene_ruc cuenta_propia cuenta_base
keep `vars' fexp sexo edad provincia educ_univ etnia anio area id_persona ciudad zona sector panelm vivienda hogar p04
replace area = 1 if area == .

save "$bases_armonizadas/base_trabajo.dta", replace
*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
*------------------------------------------------------------------*

clear all
set more off

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global variables_base "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global bases_armonizadas "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global ingpc "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"


cd "`path'"

*--- Start with the Master file (largest, likely the base) ---*
use "$bases_armonizadas/historico_iess_issfa_isspol.dta", clear

* Make sure key variables exist and are the right type
isid id_persona anio, missok    // check uniqueness; remove if not unique

*--- Merge Adecuado ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_adec_sim.dta", ///
    generate(m_adec)

*--- Merge Informalidad ---*

* RUC
merge 1:1 id_persona anio using "$bases_armonizadas/historico_ruc.dta", ///
    generate(m_ruc)

* Tamaño establecimiento	
*merge 1:1 id_persona anio using "$bases_armonizadas/tamano_establecimiento.dta", ///
    generate(m_tamano)
	
* PEA
merge 1:1 id_persona anio using "$bases_armonizadas/pea.dta", ///
    generate(m_pea)

*--- Merge No remunerado ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_no_remunerado.dta", ///
    generate(m_no_remunerado)

*--- Merge  etnia ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_etnia.dta", ///
    generate(m_etnia)

*--- Merge educacion ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_educacion.dta", ///
    generate(m_educacion)

*--- Merge rama ---*
merge 1:1 id_persona anio using "$bases_armonizadas/historico_rama.dta", ///
    generate(m_rama)
		
	
drop m_*

	

	
forval y = 2001/2025 {
	
	di "**************`y'*******************"
	
	local svyvars
	

	
	if (`y' <= 2017) local svyvars ciudad zona sector
	else             local svyvars 

	
	if (inrange(`y', 2015, 2017)) local svyvars `svyvars' plan_muestreo
	else                          local svyvars `svyvars' 
	
	if (`y' >= 2018) {
		*local svyvars `svyvars' estrato upm
		*tostring estrato, replace 
		}
	else                          local svyvars `svyvars'
	
	if `y' == 2009 local ingrl_var ing_lab
	else           local ingrl_var ingrl

	
    merge 1:1 id_persona anio using "$raw/empleo`y'.dta", ///
        keepusing(fexp sexo edad provincia `ingrl_var' condact* `svyvars') ///
		update replace nogen
	
}

replace condactn = condact if inrange(anio, 2018, 2025)
*replace ingrl = ing_lab if anio == 2009
*drop ing_lab

merge 1:1 id_persona anio using "$raw/empleo2022.dta", ///
	keepusing(fexp sexo edad provincia `ingrl_var' condact* `svyvars') ///
	update replace nogen



/*

*label values condact  CONDACTN 

forval y = 2001(2)2025 {
    merge 1:1 id_persona anio using "$ingpc/empleo`y'.dta", ///
        keepusing(ingtot_per) update replace nogen
}

*/

*rename ingtot_per ingpc


*recode tamano_armonizado (2 = 1) (1 = 0)


*local vars affiliated adec adec_sim no_remunerado tamano_armonizado mi_pea tiene_ruc cuenta_propia cuenta_base condact*

local vars affiliated adec adec_sim no_remunerado  tiene_ruc mi_pea   condact* id_persona


keep `vars' fexp sexo edad provincia educ_univ etnia_arm anio area ingrl rama1 ///
	  ciudad zona sector plan_muestreo 
	  
	  *estrato upm
	  
replace area = 1 if area == .

save "$bases_armonizadas/base_trabajo.dta", replace


/*
s


use "$bases_armonizadas/base_trabajo.dta", clear

	

	
	
local vars affiliated adec no_remunerado tamano_armonizado mi_pea tiene_ruc  cuenta_propia cuenta_base


foreach var of local vars {

preserve
    collapse (mean) `var' [iw = fexp] if anio != 2002, by(anio area)
    list
    format `var' %9.2f
    keep if area == 1
    rename `var' `var'_urb
    tempfile urb
    save `urb'
restore

preserve
    collapse (mean) `var' [iw = fexp]  if anio != 2002, by(anio)
    format `var' %9.2f
    rename `var' `var'_nac
    merge 1:1 anio using `urb', nogen
    list
twoway (line `var'_nac anio  if anio >= 2000)  ///
           (line `var'_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
		   name(`var', replace)
restore

graph export "$out_plot/historico_{`var'}.pdf", replace


}

*/



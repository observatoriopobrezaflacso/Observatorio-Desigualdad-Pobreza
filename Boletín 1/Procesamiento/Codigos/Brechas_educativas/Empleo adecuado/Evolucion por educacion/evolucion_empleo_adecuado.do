global codes "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Procesamiento\Codigos\Ingresos"

*-------------------------------------------------------------
* SECCIÓN 1: CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "$bases/Procesadas"
global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Outcomes/Curvas de crecimiento"



foreach y of numlist 2001(2)2023 {
    di "**********`y'***********"		
	
	local condact_var condact
	if inrange(`y', 2007, 2013) local condact_var CONDACTN

	local instr_var nivins
	if `y' >= 2007 local instr_var p10a
	
	capture describe adec using "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta"
	if !_rc local adec_var adec
	else local adec_var
		
	use `adec_var' `condact_var' `instr_var' w t anio fexp using  "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", clear
	
   rename `condact_var' condact_`y'
   rename `instr_var' nivins_`y'
   

   save "$procesado/empleo_adecuado/empleo_`y'.dta", replace

}


use condact nivin* adec anio fexp w t using  "$procesado/empleo_adecuado/empleo_2001.dta", clear

foreach y of numlist 2003(2)2023 {
    di "**********`y'***********"		
			
	capture describe adec using "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta"
	if !_rc local adec_var adec
	else local adec_var	
			
    append using "$procesado/empleo_adecuado/empleo_`y'.dta", keep(condact* nivins anio fexp `adec_var' w t)

}

save "$procesado/empleo_adecuado/empleo_anios_impares_2000s.dta", replace


use "$procesado/empleo_adecuado/empleo_anios_impares_2000s.dta", clear

*tostring anio, replace
cap drop uni
gen universitario = 0

foreach var of varlist nivins_* {

if "`var'" == "nivins_2001" replace universitario = 1 if `var' >= 6 & `var' != .
else replace universitario = 1 if `var' >= 8 & `var' != .


local anio = real(substr("`var'", -4, .))
di "`anio'"
replace universitario = . if `var' == . & anio == `anio'

}


cap drop emp_adec
gen emp_adec = 0

foreach var of varlist condact_* {

local anio = real(substr("`var'", -4, .))
di "`anio'"

replace emp_adec = 1 if `var' == 1  
replace emp_adec = . if inlist(`var', 0, 9) & anio == `anio'
replace emp_adec = adec if inlist(anio , 2001, 2003, 2005, 2015) 
}


keep if !inlist(., universitario, emp_adec)

tab emp_adec anio [iw = fexp], nofreq col

tabstat emp_adec [w = fexp], by(anio) 



replace emp_adec = emp_adec * 100
replace t = t * 100
replace w = w * 100

gen emp_adec_n = emp_adec



preserve 

collapse (mean) emp_adec (count) emp_adec_n [iw = fexp], by(universitario anio) 

gen a = emp_adec*emp_adec_n
bysort anio: egen b = sum(a)
bysort anio: egen c = sum(emp_adec_n)
gen emp_nacional = b/c

twoway (connected emp_nacional anio, lcolor(dkgreen) mcolor(dkgreen)), ///
       legend(order(1 "Nacional") col(3)) ///
       xtitle("Año") ytitle("Empleo adecuado (%)") ///
	   xlabel(2001(4)2023) ///
	   name(nacional, replace) ///
	   yscale(r(30(10)80)) ylabel(30(10)80)


twoway (connected emp_adec anio if universitario == 0, lcolor(navy) mcolor(navy)) ///
       (connected emp_adec anio if universitario == 1, lcolor(cranberry) mcolor(cranberry)), ///
       legend(order(1 "No Ed. Superior" 2 "Ed. Superior") col(3)) ///
       xtitle("Año") ytitle("Empleo adecuado (%)") ///
	   xlabel(2001(4)2023) ///
	   name(adec_educ, replace)
	   
	   
	   
twoway (connected emp_adec anio if universitario == 0, lcolor(navy) mcolor(navy)) ///
       (connected emp_adec anio if universitario == 1, lcolor(cranberry) mcolor(cranberry)) ///
       (connected emp_nacional anio, lcolor(dkgreen) mcolor(dkgreen)), ///
       legend(order(1 "No Ed. Superior" 2 "Ed. Superior" 3 "Nacional") col(3)) ///
       xtitle("Año") ytitle("Empleo adecuado (%)") ///
	   xlabel(2001(4)2023) ///
	   name(adec_combined, replace)

restore


preserve

collapse (mean) emp_adec (mean) t (mean) w [iw = fexp], by(anio)

	   
twoway (connected t anio, lcolor(navy) mcolor(navy)) ///
       (connected w anio, lcolor(cranberry) mcolor(cranberry)) ///
       (connected emp_adec anio, lcolor(dkgreen) mcolor(dkgreen)), ///
       legend(order(1 "Trabaja 40h" 2 "Salario >= Mín." 3 "Empleo Adecuado") col(3) size(small)) ///
       xtitle("Año") ytitle("(%)") ///
	   xlabel(2001(4)2023) ///
	   name(adec_decomposition, replace)

restore	   
	   



/*

2001: 7 8  (9?)

2003, 2005: 7, 8, 9
 
2015: 7, 8

2007-2013, 2017-2023: 1, 9

*/

** Educación
** 2001: 7



foreach y of numlist 2001 2003 2005 2015 {
    di "**********`y'***********"		
	
	local condact_var condact
	if inrange(`y', 2007, 2013) local condact_var CONDACTN

	local instr_var nivins
	if `y' >= 2007 local instr_var p10a
	
	use `condact_var' `instr_var' anio fexp using  "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", clear
	
	order `condact_var' `instr_var' 
	
	label dir 
    local first_lab = word("`r(names) '", 2)	
	label list  `first_lab'
}



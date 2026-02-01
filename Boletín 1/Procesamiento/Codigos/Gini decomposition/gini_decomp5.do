global codes "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Procesamiento\Codigos\Ingresos"

*-------------------------------------------------------------
* SECCIÓN 1: CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "$bases/Procesadas"
global out "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Outcomes\Gini decomposition"


use ing* anio fexp using "$procesado/ingresos_pc/ing_perca_1991_urb_precios2000.dta", clear


foreach y of numlist 1992(1)2001 2003 2005 2006(1)2023 2024 {
    di "**********`y'***********"		
		
	if `y' < 2000 local vars ing* anio fexp 
	else local vars ing* anio area fexp

	if `y' < 2000 local prefix urb
	else local prefix nac
		
    append using "$procesado/ingresos_pc/ing_perca_`y'_`prefix'_precios2000.dta", keep(`vars')

}


save "$procesado/casi_completa.dta", replace

keep if area == 1
save "$procesado/casi_completa_urb.dta", replace



use "$procesado/casi_completa.dta", clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)


/*
preserve 
keep if anio == 2007
sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition
restore 
*/

preserve 
keep if anio == 2001
descogini ingtot_per ingtot_per
restore 

preserve 
keep if anio == 2011
sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition
restore 



mat a = .

foreach y of numlist 1991/2001 2003 2005 2006 2007/2024 {

di "************`y'****************"

preserve 
keep if anio == `y'
ineqdeco  ingtot_per [w=fexp] 
restore 

mat a = a\r(gini)

}

mat a = a[2..rowsof(a), 1..1]

matrix rownames a = 1991 1992 1993 1994 1995 1996 1997 1998 1999 2000 2001 2003 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024
matrix colnames a = ineqdeco

matlist a


putexcel set "$out/Gini.xlsx", replace

putexcel A1 = ("")                    // empty cell before labels
putexcel A2 = matrix(a), names      // row names




* With sgini

mat a = .

foreach y of numlist 1991/2001 2003 2005 2006 2007/2024 {

di "************`y'****************"

preserve 
keep if anio == `y'
sgini ingtot_per [pw = fexp]
restore 

mat a = a\r(coeff)

}

mat a = a[2..rowsof(a), 1..1]

matrix rownames a = 1991 1992 1993 1994 1995 1996 1997 1998 1999 2000 2001 2003 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024
matrix colnames a = sgini

matlist a

putexcel C2 = matrix(a), colnames


* Gini decomposition

mat a = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .


foreach year of numlist 2001(2)2023 {

di "************`year'***************"

preserve 

keep if anio == `year'

qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

mat b = r(coeffs)[1, 1..4]

mat a = a\(r(s), b, r(r), r(elasticity))

restore 


}

mat list a

matrix a = a[2..13, 1..16]
matrix colnames a = slaboral srentas sremesas sbono  ///
                    glaboral grentas gremesas gbono ///
                    rlaboral rrentas rremesas rbono  ///
                    elaboral erentas eremesas ebono 


matrix rownames a = 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 

mat list a




clear
svmat double a, names(col)

gen t = 2001 + 2*(_n - 1) 

foreach var of varlist slaboral srentas sbono sremesas {
replace `var' = `var'*100
}


foreach var of varlist s* g* e* {

 if substr("`var'", 1, 1) == "s" local ytitle "Participación ingreso (%)" 
 if substr("`var'", 1, 1) == "g" local ytitle "Gini" 
 if substr("`var'", 1, 1) == "e" local ytitle "Elasticidad ingreso - Gini" 

twoway connected `var' t, ///
    ytitle(`ytitle') ///
    xtitle("Año") ///
    lcolor(dknavy) name(`var', replace) ///
	xlab(2001(4)2025)

}

	
local prefix s g e
	
foreach pref of local prefix {
	
 if "`pref'" == "s" local ytitle "Participación ingreso (%)" 
 if "`pref'" == "g" local ytitle "Gini" 
 if "`pref'" == "e" local ytitle "Elasticidad ingreso - Gini" 

	
twoway ///
    (connected `pref'laboral t) ///
    (connected `pref'rentas  t) ///
    (connected `pref'bono   t) ///
    (connected `pref'remesas t), ///
    ytitle("`ytitle'") ///
    xtitle("Año") ///
	xlabel(2001(4)2025) ///
    legend(order(1 "Laboral" 2 "Rentas" 3 "Bono" 4 "Remesas") ///
           rows(1)) ///
    name(comb_`pref', replace)
	
twoway ///
    (connected `pref'laboral t) ///
    (connected `pref'rentas  t) ///
    (connected `pref'remesas t), ///
    ytitle("`ytitle'") ///
    xtitle("Año") ///
	xlabel(2001(4)2025) ///
    legend(order(1 "Laboral" 2 "Rentas" 3 "Remesas") ///
           rows(1)) ///
    name(comb_`pref'2, replace)	
	
}			


*** Solo urbano con 90s ***

use "$procesado/casi_completa_urb.dta", clear


recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)


mat a = ., ., ., ., ., ., ., .


foreach year of numlist 1991(2)2023 {

preserve 

keep if anio == `year'
if `year' >= 2000 keep if area == 1

qui: sgini inglab_per ingrent_per [pw = fexp], sourcedecomposition 

mat b = r(coeffs)[1, 1..2]

mat a = a\(r(s), b, r(r), r(elasticity))

restore 


}

mat list a

matrix a = a[2..18, 1..8]
matrix colnames a = slaboral srentas ///
                    glaboral grentas ///
                    rlaboral rrentas ///
                    elaboral erentas 


matrix rownames a = 1991 1993 1995 1997 1999 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 

mat list a

clear
svmat double a, names(col)

gen t = 1991 + 2*(_n - 1) 
order t



foreach var of varlist slaboral srentas {
replace `var' = `var'*100
}


foreach var of varlist s* g* e* {

 if substr("`var'", 1, 1) == "s" local ytitle "Participación ingreso (%)" 
 if substr("`var'", 1, 1) == "g" local ytitle "Gini" 
 if substr("`var'", 1, 1) == "e" local ytitle "Elasticidad ingreso - Gini" 

twoway connected `var' t, ///
    ytitle(`ytitle') ///
    xtitle("Año") ///
    lcolor(dknavy) name(`var', replace) ///
	xlab(1991(4)2025)

}

	
local prefix s g e
	
foreach pref of local prefix {
	
 if "`pref'" == "s" local ytitle "Participación ingreso (%)" 
 if "`pref'" == "g" local ytitle "Gini" 
 if "`pref'" == "e" local ytitle "Elasticidad ingreso - Gini" 

	
twoway ///
    (connected `pref'laboral t) ///
    (connected `pref'rentas  t), ///
    ytitle("`ytitle'") ///
    xtitle("Año") ///
	xlabel(2001(4)2025) ///
    legend(order(1 "Laboral" 2 "Rentas") ///
           rows(1)) ///
    name(comb_`pref', replace)
	
}			
	

	

* Gini decomposition by quintiles



use ingtot_per  inglab_per ingrent_per ingrem_per ingbo_per anio fexp using "$procesado/casi_completa.dta" if inrange(anio, 2001, 2024), clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)



mat b = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .


foreach year of numlist 2001(4)2021 2024{

di "************`year'***************"

forval i = 1/5 {

di "**** quintil: `i' ****"


preserve 

keep if anio == `year'

xtile ing_quants = ingtot_per [w = fexp], nquant(5)

keep if ing_quants == `i'

qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

mat a = r(coeffs)[1, 1..4]
mat b = b\(r(s), a, r(r), r(elasticity))

restore 

}

}

mat list b

matrix b = b[2..rowsof(b), 1..colsof(b)]
matrix colnames b = slaboral srentas sremesas sbono  ///
                    glaboral grentas gremesas gbono ///
                    rlaboral rrentas rremesas rbono  ///
                    elaboral erentas eremesas ebono 


matrix rownames b = 2001q1 2001q2 2001q3 2001q4 2001q5 ///
					2005q1 2005q2 2005q3 2005q4 2005q5 ///
					2009q1 2009q2 2009q3 2009q4 2009q5 ///
					2013q1 2013q2 2013q3 2013q4 2013q5 ///
					2017q1 2017q2 2017q3 2017q4 2017q5 ///
					2021q1 2021q2 2021q3 2021q4 2021q5 ///
 					2024q1 2024q2 2024q3 2024q4 2024q5

mat list b
	

	
clear
svmat double b, names(col)

gen t = 2001 + 4*floor((_n-1)/5)
bysort t: gen q = _n


replace t = 2024 if t == 2025

order t q

foreach var of varlist slaboral srentas sremesas sbono {
replace `var' = `var'*100
}

local suffix laboral rentas remesas bono
	
foreach suf of local suffix {
	
 if "`suf'" == "laboral" local ytitle "Participación ingreso laboral (%)" 
 if "`suf'" == "rentas"  local ytitle "Participación ingreso rentas (%)" 
 if "`suf'" == "remesas" local ytitle "Participación ingreso remesas(%)" 
 if "`suf'" == "bono"    local ytitle "Participación ingreso bono (%)" 

	
twoway ///
(connected s`suf' t if q==1, sort) ///
(connected s`suf' t if q==2, sort) ///
(connected s`suf' t if q==3, sort) ///
(connected s`suf' t if q==4, sort) ///
(connected s`suf' t if q==5, sort), ///
legend( ///
    title("Quintil", size(small)) ///
    order(1 "1" 2 "2" 3 "3" 4 "4" 5 "5") ///
    cols(5) ///
) ///
xtitle("Year") ///
ytitle("`ytitle'") ///
name("`suf'", replace)

}	





* Gini decomposition by cuartiles



use ingtot_per  inglab_per ingrent_per ingrem_per ingbo_per anio fexp using "$procesado/casi_completa.dta" if inrange(anio, 2001, 2024), clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)



mat b = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .


foreach year of numlist 2001(4)2021 2024{

di "************`year'***************"

forval i = 1/4 {

di "**** quintil: `i' ****"


preserve 

keep if anio == `year'

xtile ing_quants = ingtot_per [w = fexp], nquant(4)

keep if ing_quants == `i'

qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

mat a = r(coeffs)[1, 1..4]
mat b = b\(r(s), a, r(r), r(elasticity))

restore 

}

}

mat list b

matrix b = b[2..rowsof(b), 1..colsof(b)]
matrix colnames b = slaboral srentas sremesas sbono  ///
                    glaboral grentas gremesas gbono ///
                    rlaboral rrentas rremesas rbono  ///
                    elaboral erentas eremesas ebono 


matrix rownames b = 2001q1 2001q2 2001q3 2001q4 ///
					2005q1 2005q2 2005q3 2005q4 ///
					2009q1 2009q2 2009q3 2009q4 ///
					2013q1 2013q2 2013q3 2013q4 ///
					2017q1 2017q2 2017q3 2017q4 ///
					2021q1 2021q2 2021q3 2021q4 ///
 					2024q1 2024q2 2024q3 2024q4

mat list b
	

	
clear
svmat double b, names(col)

gen t = 2001 + 4*floor((_n-1)/4)
bysort t: gen q = _n


replace t = 2024 if t == 2025

order t q

foreach var of varlist slaboral srentas sremesas sbono {
replace `var' = `var'*100
}

local suffix laboral rentas remesas bono
	
foreach suf of local suffix {
	
 if "`suf'" == "laboral" local ytitle "Participación ingreso laboral (%)" 
 if "`suf'" == "rentas"  local ytitle "Participación ingreso rentas (%)" 
 if "`suf'" == "remesas" local ytitle "Participación ingreso remesas(%)" 
 if "`suf'" == "bono"    local ytitle "Participación ingreso bono (%)" 

	
twoway ///
(connected s`suf' t if q==1, sort) ///
(connected s`suf' t if q==2, sort) ///
(connected s`suf' t if q==3, sort) ///
(connected s`suf' t if q==4, sort), ///
legend( ///
    title("Cuartil", size(small)) ///
    order(1 "1" 2 "2" 3 "3" 4 "4") ///
    cols(5) ///
) ///
xtitle("Year") ///
ytitle("`ytitle'") ///
name("`suf'", replace)

}	
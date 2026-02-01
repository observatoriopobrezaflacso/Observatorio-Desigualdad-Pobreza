global codes "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Procesamiento\Codigos\Ingresos"

*-------------------------------------------------------------
* SECCIÓN 1: CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "$bases/Procesadas"
global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Outcomes/Curvas de crecimiento"



use ing* anio using "$procesado/ingresos_pc/ing_perca_1991_urb_precios2000.dta", clear


foreach y of numlist 1993(2)2023 {
    di "**********`y'***********"		
    append using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", keep(ing* anio)
}


foreach y of numlist 1993(2)2023 {
    di "**********`y'***********"		
    describe using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", keep(ing* anio)
	capture confirm variable upm
	if !_rc di "upm"
}


save "$procesado/1991-2023_odd_years.dta", replace

use "$procesado/1991-2023_odd_years.dta", clear

capture program drop mygini
program define mygini, rclass
    syntax [if]
    marksample touse
    sgini inglab_per ingrent_per ingrem_per if `touse', sourcedecomposition
    matrix shares = r(s)
    return scalar inglab  = shares[1,1]
    return scalar ingrent = shares[1,2]
end


bootstrap (shares: inglab= r(inglab) ingrent=r(ingrent)) : mygini


capture program drop mygini
program define mygini, rclass
   syntax varlist(min=1) [if]
   marksample touse
   sgini `varlist' if `touse', sourcedecomposition
   matrix shares = r(s)
   local i = 1
   foreach v of varlist `varlist' {
        return scalar `v' = shares[1,`i']
        local ++i
    }
end

matrix contrib = .,., ., .


foreach year of numlist 2001(2)2003 {

bootstrap (shares: inglab  = r(inglab_per)   ///
				   ingrent = r(ingrent_per)  ///
		           ingbo   = r(ingbo_per)    ///
				   ingrem  = r(ingrem_per)): ///
				   mygini inglab_per ingrent_per ingrem_per ingbo_per if anio ==`year'


matrix contrib= contrib \ e(b)

}



bootstrap (shares: inglab  = r(inglab_per)   ///
				   ingrent = r(ingrent_per)  ///
		           ingbo   = r(ingbo_per)    ///
				   ingrem  = r(ingrem_per)): ///
				   mygini inglab_per ingrent_per ingrem_per ingbo_per if anio == 2003

				   
mygini inglab_per ingrent_per ingrem_per ingbo_per 
mygini inglab_per ingrent_per ingrem_per ingbo_per if anio == 2003


drop *_mis
gen ing_mis = missing(ingbo_per)
tab ing_mis anio

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per

descogini ingtot_per inglab_per ingrent_per  if anio == 1993
descogini ingtot_per inglab_per ingrent_per  if anio == 2003

preserve

keep if !inlist(., ingtot_per, inglab_per, ingrent_per, ingrem_per, ingbo_per)

*descogini ingtot_per inglab_per ingrent_per  if anio == 1993
descogini ingtot_per inglab_per ingrent_per  if anio == 2003

restore


preserve

recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

*descogini ingtot_per inglab_per ingrent_per  ingrem_per ingbo_per  if anio == 1993
descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per   if anio == 2003

restore


preserve

recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

*descogini ingtot_per inglab_per ingrent_per  ingrem_per ingbo_per  if anio == 1993

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per  if anio == 2007

restore






descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per if anio == 2003



capture drop a b c d e b1 c1 d1 e1
egen a = total(ingtot_per)
egen b = total(inglab_per)
egen c = total(ingrent_per)
egen d = total(ingbo_per)
egen e = total(ingrem_per)

gen b1 = b/a
gen c1 = c/a
gen d1 = d/a
gen e1 = e/a


descogini ingtot_per inglab_per ingrent_per if anio == 1993

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per if anio == 2003

br ingtot_per inglab_per ingrent_per ingrem_per ingbo_per a b c d e


preserve 
keep ingtot_per inglab_per ingrent_per ingrem_per ingbo_per a b c d e b1 c1 d1 e1
export excel using "asd_1.xlsx", replace  
restore

s




use ing* anio using "$procesado/ingresos_pc/ing_perca_1991_urb_precios2000.dta", clear


foreach y of numlist 1992(1)1999 {
    di "**********`y'***********"		
    append using "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", keep(ing* anio)
}

save "$procesado/1991-1999.dta", replace






*replace ing_lab = ingrl 

replace ing_lab = . if inlist(ing_lab, 2.00e+07, 9999999, 19999998)

sum ing_lab ingrl if anio == 1991 

sum ing_lab ingrl if anio == 1993

sum ing_lab ingrl if anio == 1995

sum ing_lab ingrl if anio == 1996

sum ing_lab ingrl if anio == 1997

sum ing_lab ingrl if anio == 1998

br ing_lab ingrl if anio == 1991 & ing_lab != ingrl 

br ing_lab ingrl if anio == 1998 & ing_lab != . & ingrl == . 

br ing_lab ingrl if anio == 1997 & ing_lab != . & ingrl == . 

br ing_lab ingrl if anio == 1996 & ing_lab != . & ingrl == . 

br ing_lab ingrl if anio == 1998 & ing_lab != . & ingrl == . 


replace ing_lab = . if inlist(ing_lab, 9999999, 19999998)




recode ing_lab (0 = .)

sum ing_lab ingrl if anio == 1991 


sum ing_lab2 ingrl if anio == 1995

recode ing_lab2 (0 = .)

sum ing_lab2 ingrl if anio == 1991 



br ing_lab2 ingrl if anio == 1991 & ing_lab2 != ingrl & ing_lab2 != 0
br ing_lab2 ingrl if anio == 1991 & ing_lab2 != ingrl & ing_lab2 != 0



2.00e+07
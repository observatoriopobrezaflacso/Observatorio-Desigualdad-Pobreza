global codes "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Procesamiento\Codigos\Ingresos"

*-------------------------------------------------------------
* SECCIÓN 1: CONFIGURACIÓN DE RUTAS Y DIRECTORIOS
*-------------------------------------------------------------
* Definición de rutas globales para facilitar la portabilidad del código
global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "$bases/Procesadas"
global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Outcomes/Curvas de crecimiento"



use ing* anio fexp using "$procesado/ingresos_pc/ing_perca_1991_urb_precios2000.dta", clear


foreach y of numlist 1992(1)2001 2003 2005 2006(1)2023 {
    di "**********`y'***********"		
		
	if `y' < 2000 local vars ing* anio fexp 
	else local vars ing* anio area fexp

	if `y' < 2000 local prefix urb
	else local prefix nac
		
    append using "$procesado/ingresos_pc/ing_perca_`y'_`prefix'_precios2000.dta", keep(`vars')

}


save "$procesado/casi_completa.dta", replace

use "$procesado/casi_completa.dta", clear


recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)






forval y = 2001(2)2023 {

di "**************`y'*****************"

preserve
keep if anio == `y'
keep if area == 1
sgini inglab_per ingrent_per ingrem_per ingbo_per, sourcedecomposition
restore


preserve
keep if anio == `y'
keep if area == 1
descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per  
restore

}



capture program drop mygini
program define mygini, rclass
    syntax varlist(min=1) [if]
    marksample touse

    sgini `varlist' if `touse' [aw = fexp], sourcedecomposition
    matrix shares       = r(s)
    matrix elasticities = r(elasticity)

    local i = 1
    foreach v of varlist `varlist' {
        return scalar s`v' = shares[1,`i']
        return scalar e`v'  = elasticities[1,`i']
        local ++i
    }
end


svyset _n [pweight = fexp]


matrix contrib = .,., ., ., ., ., ., ., .,., ., ., ., ., ., .


preserve 

keep if anio == 2001

svy bootstrap (shares:      singlab  = r(singlab_per)   ///
				         singrent = r(singrent_per)  ///
		                 singbo   = r(singbo_per)    ///
				         singrem  = r(singrem_per))   ///
          (elasticities: einglab  = r(einglab_per)   ///
				         eingrent = r(eingrent_per)  ///
		                 eingbo   = r(eingbo_per)    ///
				         eingrem  = r(eingrem_per)): ///
				   mygini inglab_per ingrent_per ingrem_per ingbo_per 
restore 


matrix contrib= (contrib)\ (e(b), e(se))
mat list contrib




capture program drop mygini
program define mygini, rclass
    syntax varlist(min=1) [if]
    marksample touse

    sgini `varlist' if `touse', sourcedecomposition
    matrix shares       = r(s)
    matrix elasticities = r(elasticity)

    local i = 1
    foreach v of varlist `varlist' {
        return scalar s`v' = shares[1,`i']
        return scalar e`v'  = elasticities[1,`i']
        local ++i
    }
end



matrix contrib = .,., ., ., ., ., ., ., .,., ., ., ., ., ., .


foreach year of numlist 2001(2)2023{

preserve 

keep if anio == `year'

bootstrap (shares:      singlab  = r(singlab_per)   ///
				         singrent = r(singrent_per)  ///
		                 singbo   = r(singbo_per)    ///
				         singrem  = r(singrem_per))   ///
          (elasticities: einglab  = r(einglab_per)   ///
				         eingrent = r(eingrent_per)  ///
		                 eingbo   = r(eingbo_per)    ///
				         eingrem  = r(eingrem_per)): ///
				   mygini inglab_per ingrent_per ingrem_per ingbo_per if anio == `year'

matrix contrib= (contrib)\ (e(b), e(se))

restore 
}

matrix contrib= (contrib)\ (e(b), e(se))
mat list contrib


matrix contrib = contrib[2..13, 1..4]
matrix colnames contrib = laboral rentas bono remesas

mat list contrib
matrix rownames contrib = 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 

clear
svmat double contrib, names(col)

gen t = 2001 + 2*(_n - 1) 

foreach var of varlist laboral rentas bono remesas {
replace `var' = `var'*100
}

twoway line lab t, ///
    ytitle("Participación ingreso laboral (%)") ///
    xtitle("Año") ///
    lcolor(dknavy)

twoway line remesas t, ///
    ytitle("Participación Remesas (%)") ///
    xtitle("Año") ///
    lcolor(dknavy)

	
	
twoway ///
    (line laboral t, lcolor(dknavy)) ///
    (line rentas  t, lcolor(cranberry)) ///
    (line bono    t, lcolor(emerald)) ///
    (line remesas t, lcolor(maroon)), ///
    ytitle("Participación porcentual (%)") ///
    xtitle("Año") ///
    legend(order(1 "Laboral" 2 "Rentas" 3 "Bono" 4 "Remesas") ///
           rows(1))
	


* Make sure the parallel package is installed
* ssc install parallel

parallel statapath("C:\Users\santy\Videos\Respaldos\Desktop\Programas de trabajo\Stata16\stata.exe")



parallel setclusters 6   // or the number of cores you want



tempfile results
capture postutil clear
postfile handle str4 year double(inglab ingrent ingbo ingrem) using `results'

parallel, by(anio) : ///
    bootstrap (shares: inglab  = r(inglab_per)   ///
                        ingrent = r(ingrent_per) ///
                        ingbo   = r(ingbo_per)    ///
                        ingrem  = r(ingrem_per)) : ///
        mygini inglab_per ingrent_per ingrem_per ingbo_per

* Now collect all results
use `results', clear
list






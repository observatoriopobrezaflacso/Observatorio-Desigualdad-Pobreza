
clear

* Definición de rutas globales para facilitar la portabilidad del código
global limpias "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brechas educacion/bases limpias"


use rama1 p10a CONDACT fexp using "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\bases limpias\empleo2011.dta", clear
rename *, lower
rename condact condact_2011 


gen anio = "2011_"

append using "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\bases limpias\empleo2024.dta", force

replace anio = "2024_" if anio == ""

rename condact condact_2024

gen empleo_pleno = inlist(1, condact_2011, condact_2024)
replace empleo_pleno = . if inlist(condact_2011, 7, 8)
replace empleo_pleno = . if inlist(condact_2024, 0, 9)


gen universitario = inlist(p10a, 9, 10)
drop p10a

keep rama1 universitario empleo_pleno anio fexp


gen n_obs = !inlist(., rama1, universitario, empleo_pleno)
replace n_obs = . if n_obs == 0

gen n = n_obs
replace n_obs = n_obs * fexp

tostring empleo_pleno, replace
replace empleo_pleno = "pleno" if empleo_pleno == "1"
replace empleo_pleno = "nopleno" if empleo_pleno == "0" 
keep if empleo_pleno !="."

tostring universitario, replace
replace universitario = "uni_" if universitario == "1"
replace universitario = "nouni_" if universitario == "0"


collapse (sum) n, by(rama1 universitario anio empleo_pleno)

reshape wide n, i(rama1 universitario empleo_pleno) j(anio) string 

reshape wide n*, i(rama1 empleo_pleno) j(universitario) string

reshape wide n*, i(rama1) j(empleo_pleno) string



egen tot_2011_nouni_nopleno = total(n2011_nouni_nopleno)
gen per_2011_nouni_nopleno = n2011_nouni_nopleno / tot_2011_nouni_nopleno 

egen tot_2024_nouni_pleno = total(n2024_nouni_pleno)
gen per_2024_nouni_pleno = n2024_nouni_pleno / tot_2024_nouni_pleno


egen tot_2011_uni_nopleno = total(n2011_uni_nopleno)
gen per_2011_uni_nopleno = n2011_uni_nopleno / tot_2011_uni_nopleno 

egen tot_2024_uni_pleno = total(n2024_uni_pleno)
gen per_2024_uni_pleno = n2024_uni_pleno / tot_2024_uni_pleno

* Graduados vs no graduados 

egen n2011_uni = rowtotal(n2011_uni_pleno n2011_uni_nopleno)
egen n2011_nouni = rowtotal(n2011_nouni_pleno n2011_nouni_nopleno)

egen n2024_uni = rowtotal(n2024_uni_pleno n2024_uni_nopleno)
egen n2024_nouni = rowtotal(n2024_nouni_pleno n2024_nouni_nopleno)


egen rowtot_2011 = rowtotal(n2011_nouni n2011_uni)  
gen rowper_2011_uni = n2011_uni/rowtot_2011

egen rowtot_2024 = rowtotal(n2024_nouni n2024_uni)  
gen rowper_2024_uni = n2024_uni/rowtot_2024

* Empleo pleno vs no pleno

egen n2011_pleno = rowtotal(n2011_uni_pleno n2011_nouni_pleno)
egen n2011_nopleno = rowtotal(n2011_uni_nopleno n2011_nouni_nopleno)

egen n2024_pleno = rowtotal(n2024_uni_pleno n2024_nouni_pleno)
egen n2024_nopleno = rowtotal(n2024_uni_nopleno n2024_nouni_nopleno)

gen rowper_2011_pleno = n2011_pleno/rowtot_2011

gen rowper_2024_pleno = n2024_pleno/rowtot_2024



s

egen tot_2011nouni = total(n2011no_uni)
gen per_2011nouni = n2011no_uni / tot_2011nouni

egen tot_2024nouni= total(n2024no_uni)
gen per_2024nouni = n2024no_uni / tot_2024nouni

gen rowtot_2011 = n2011no_uni + n2011uni  
gen rowper_2011 = n2011no_uni/rowtot_2011


gen rowtot_2024 = n2024no_uni + n2024uni  
gen rowper_2024 = n2024no_uni/rowtot_2024



gen col_exp2011no_uni =  









use "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\bases limpias\empleo2011.dta", clear
rename *, lower

tab condact

tab condact, nol

use "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\bases limpias\empleo2024.dta", clear
rename *, lower

tab condact

tab condact, nol

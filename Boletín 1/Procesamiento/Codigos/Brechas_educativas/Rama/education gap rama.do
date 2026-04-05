

use "$raw/empleo2011", clear
/*
gen adm_pub = rama1 ==  15
tab adm_pub universitario [iw = fexp], col
tab p40 universitario [iw = fexp], col
*/

gen universitario = inlist(p10a, 9, 10)


*gen rama1 = real(substr(string(p40, "%04.0f"), 1, 1))

gen n_obs = !inlist(., rama1, universitario)
replace n_obs = . if n_obs == 0

gen n_obs_exp = n_obs
replace n_obs = n_obs * fexp


collapse (sum) n_obs_exp n_obs, by(rama1 universitario)

reshape wide n_obs n_obs_exp, i(rama1) j(universitario)

replace n_obs0 = 0 if n_obs0 == .
replace n_obs1 = 0 if n_obs1 == .

gen row_tot = n_obs0 + n_obs1

gen row_per_no_uni = n_obs0/row_tot 
gen row_per_uni = n_obs1/row_tot 

egen col_no_uni_tot = total(n_obs0)
egen col_uni_tot = total(n_obs1)

gen col_per_no_uni = (n_obs0/col_no_uni_tot)*100
gen col_per_uni = (n_obs1/col_uni_tot)*100


*keep if col_per_uni > 1 | col_per_no_uni > 1

order rama1 n_obs_exp*

list

*egen a = total(col_per_uni)
*egen b = total(col_per_no_uni)
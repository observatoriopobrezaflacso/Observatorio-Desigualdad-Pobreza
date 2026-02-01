use  ing_rem ingrem_per fexp anio using "$procesado/casi_completa.dta" if anio >= 2000, clear



gen rem_receptor = !inlist(ingrem_per, 0, .)

preserve 
collapse (sum) ing_rem [iw = fexp], by(anio)
twoway connected ing_rem anio if ing_rem != 0, ///
ytitle("Remesas totales") name(remesas_totales, replace) 
list
restore



preserve 
collapse (mean) rem_receptor [iw = fexp], by(anio)
replace rem_receptor = rem_receptor *100
twoway connected rem_receptor anio if rem_receptor != 0, ///
ytitle("% receptores remesas")  ///
name(receptores_remesas, replace)
list
restore
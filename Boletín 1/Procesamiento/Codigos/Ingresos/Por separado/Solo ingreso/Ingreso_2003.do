*Calculo ingresos totales
*ENEMDU 2003

*Rentas y otros
recode pe68b 999999=.
recode pe68b .=0
recode pe69b 999999=.
recode pe69b .=0
recode pe70b 999999=.
recode pe70b .=0

generate ing_rent=pe68b+pe69b+pe70b

generate ing_rem=pe71b
recode ing_rem .=0
recode pe72b 999999=.
generate ingbon=pe72b
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)

egen ing_tot = rowtotal(ingrl ing_rent ingbon ing_rem)

recode ing_tot (0=.)

destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
egen ingrem_hh=sum(ing_rem), by(idhogar)
egen ingbo_hh=sum(ingbon), by(idhogar)
egen inglab_hh=sum(ingrl), by(idhogar)
egen ingrent_hh=sum(ing_rent), by(idhogar)

gen ingtot_per =ingtot_hh/n
gen ingrem_per = ingrem_hh/n
gen ingbo_per = ingbo_hh/n
gen inglab_per = inglab_hh/n
gen ingrent_per = ingrent_hh/n

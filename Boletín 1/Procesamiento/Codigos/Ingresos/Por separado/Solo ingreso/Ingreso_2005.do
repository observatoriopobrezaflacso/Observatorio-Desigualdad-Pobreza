
 *Rentas y otros
recode pe68b 999999=.
recode pe68b 999=.
recode pe68b .=0
recode pe69b 999999=.
recode pe69b 999=.
recode pe69b .=0
recode pe70b 999999=.
recode pe70b .=0

generate ing_rent=pe68b+pe69b+pe70b

generate ing_rem=pe71b
recode ing_rem 999999= .
recode ing_rem .=0

generate ingbon=pe73
recode ingbon .=0


recode ingrl (-1=.) (999999=.) (0=.)

generate ing_tot=ingrl+ing_rent+ingbon+ing_rem

recode ing_tot (0=.)

*Hogar
destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
gen ingtot_per = ingtot_hh/n



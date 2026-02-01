
*Indicadores de desigualdad

*Rentas y otros

recode pe65a (999999 = .)
recode pe66a (999999 = .)
recode pe67a (999999 = .)
generate ing_rent=pe65a+pe66a+pe67a
recode ing_rent .=0
recode pe68a (999999 = .)
generate ing_rem=pe68a
recode ing_rem .=0

recode pe69a (999999 = .)
generate ingbon=pe69a
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)
generate ing_tot=ingrl+ing_rent+ingbon+ing_rem

recode ing_tot (0=.)
recode ing_tot (200000 = .) (200002= .)

destring area ciudad zona sector vivienda hogar, replace
sort ciudad zona sector vivienda hogar
egen idhogar=group(ciudad zona sector vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)

gen ingtot_per = ingtot_hh/n

recode ingtot_per (0=.)


 *Rentas y otros
recode p71b 999999=.
recode p71b .=0
recode p72b 999999=.
recode p72b 9999=.
recode p72b .=0
recode p73b 999999=.
recode p73b .=0

generate ing_rent=p71b+p72b+p73b

recode p74b 999999= .
generate ing_rem=p74b
recode ing_rem .=0

generate ingbon=p76
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)
generate ing_tot=ingrl+ing_rent+ingbon+ing_rem
recode ing_tot (0=.)

destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
gen ingtot_per = ingtot_hh/n

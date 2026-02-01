*Programa para calcular desigualdad.


*Ingresos Laborales

recode p63 999999 =.
recode p63 .=0
recode p64b 999999 =.
recode p64b .=0
recode p65 999999 = .
recode p65 .=0

generate ing_cta1= p63+p64b-p65
gen ing_cta=ing_cta1
replace ing_cta=0 if ing_cta1<=0


recode p66 999999=.
recode p66 .=0
recode p67 999999=.
recode p67 .=0
recode p68b 999999=.
recode p68b .=0

recode p69 999999 = .
recode p69 .=0 
recode p70b 999999=.
recode p70b .=0

generate ing_sal= p66+p67+p68b+p69+p70b
gen ing_lab= ing_cta+ing_sal

*Rentas y otros
recode p71b 999999=.
recode p71b .=0
recode p72b 999999=.
recode p72b .=0
recode p73b 999999=.
recode p73b .=0

gen ing_cap=p71b
gen ing_pen=p72b

generate ing_rent=p71b+p72b+p73b


generate ing_rem=p74b
recode ing_rem 999999= .
recode ing_rem .=0

generate ingbon=p76
recode ingbon .=0

gen ing_transf=p73b+ingbon

generate ing_tot=ing_lab+ing_rent+ingbon+ing_rem

recode ing_sal 0=.
recode ing_cta 0=.
recode ing_rent 0=.
recode ing_lab 0=.
recode ing_rem 0=.
recode ingbon 0=.
recode ing_tot 0=.


*Análisis del ingreso percápita del hogar.
*Creación del id-hogar

destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
egen inglab_hh=sum(ing_lab), by(idhogar)
egen ingcta_hh=sum(ing_cta), by(idhogar)
egen ingrent_hh=sum(ing_rent), by(idhogar)
egen ingrem_hh=sum(ing_rem), by(idhogar)
egen ingbon_hh=sum(ingbon), by(idhogar)

gen ingtot_per=ingtot_hh/n
gen inglab_per=inglab_hh/n
gen ingrent_per=ingrent_hh/n
gen ingrem_per=ingrem_hh/n
gen ingbo_per=ingbon_hh/n


recode ingtot_per 0=.


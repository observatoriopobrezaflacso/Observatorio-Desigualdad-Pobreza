
*Ingresos Laborales

recode pe61 999999= .
recode pe61 .=0

recode pe62b 999999=.
recode pe62b .=0

generate ing_cta= pe61+pe62b

recode pe63 999999= .
recode pe63 22150=.
recode pe63 9999= .
recode pe63 99999= .
recode pe63 .=0

recode pe64 999999=.
recode pe64 9999=.
recode pe64 999=.
recode pe64 .=0

recode pe65b 999999 = .
recode pe65b .=0

recode pe66 999999=.
recode pe66 .=0
recode pe67b 999999=.
recode pe67b .=0
generate ing_sal= pe63+pe64+pe65b+pe66+pe67b
gen ing_lab= ing_cta+ing_sal

*Rentas y otros
recode pe68b 999999=.
recode pe68b 250000=.
recode pe68b 300222=.
recode pe68b .=0
recode pe69b 999999=.
recode pe69b .=0
recode pe70b 999999=.
recode pe70b .=0

generate ing_rent=pe68b+pe69b+pe70b

generate ing_rem=pe71b
recode ing_rem 999999= .
recode ing_rem .=0

generate ingbon=pe73
recode ingbon .=0

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

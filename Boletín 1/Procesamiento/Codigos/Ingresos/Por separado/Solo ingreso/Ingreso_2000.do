*Programa para calcular desigualdad.

*Ingresos Laborales

recode ingpat 9999 = .
recode ingpat 10000 = .
recode ingpat 99999 = .
recode ingpat 999999 = .
recode ingpat 9999999 = .
recode ingpat 39999999 = .
recode ingpat 89999999 = .
recode ingpat 99999999 = .
recode ingpat .=0
recode retpat 99999999 = .
recode retpat 9999 = .
recode retpat .=0

recode ingasa 9999999 = .
recode ingasa 99999999 = .
recode ingasa 89999999 = .
recode ingasa 99999 = .
recode ingasa 9999 = .

recode ingasa .=0

recode ingasa1 9999= .
recode ingasa1 99999= .
recode ingasa1 99999999= .
recode ingasa1 .=0

recode ingasa2 99999999 = .
recode ingasa2 9999= .
recode ingasa2 .=0

recode ingsec 999999 = .
recode ingsec 9999999 = .
recode ingsec 99999999 = .
recode ingsec .=0

generate ing_sal = ingasa1+ingasa2+ingsec
generate ing_cta= ingpat+retpat

gen ing_lab = ing_sal+ing_cta


*Rentas y otros

recode inginv 99999999=.
recode inginv .=0
recode ingjub 99999999=.
recode ingjub .=0
recode ingotr 99999999=.
recode ingotr .=0
recode ingbon 99999999=.
recode ingbon 10333333= .
recode ingbon .=0

generate ing_rent=inginv+ingjub

gen ing_rem= ingotr

generate ing_tot=ing_lab+ing_rent+ingbon+ing_rem

recode ing_sal 0=.
recode ing_cta 0=.
recode ing_rent 0=.
recode ing_lab 0=.
recode ing_tot 0=.


*Análisis del ingreso percápita del hogar.
*Creación del id-hogar

destring ciudad zona sector vivienda hogar, replace
sort ciudad zona sector vivienda hogar
egen idhogar=group(ciudad zona sector vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
egen inglab_hh=sum(ing_lab), by(idhogar)
egen ingcta_hh=sum(ing_cta), by(idhogar)
egen ingrent_hh=sum(ing_rent), by(idhogar)
egen ingbon_hh=sum(ingbon), by(idhogar)
egen ingrem_hh=sum(ing_rem), by(idhogar)

gen ingtot_per=ingtot_hh/n
gen inglab_per=inglab_hh/n
gen ingrent_per=ingrent_hh/n
gen ingrem_per=ingrem_hh/n
gen ingbon_per=ingbon_hh/n

recode ingtot_per 0=.
recode ingtot_per 861131.3 =.


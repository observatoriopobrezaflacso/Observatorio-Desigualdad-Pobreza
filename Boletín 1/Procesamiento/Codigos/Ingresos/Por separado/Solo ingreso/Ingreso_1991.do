*Programa para calcular desigualdad.

*Ingresos Salariales

recode ingobr .=0
recode ingpat 9999998=.
recode ingpat .=0
recode ingalq .=0
recode ingjub .=0
recode ingotr .=0

gen ing_sal=ingobr
gen ing_cta=ingpat
gen ing_rent=ingalq+ingjub+ingotr

gen ing_lab= ing_sal+ing_cta

gen ing_tot= ing_lab+ing_rent

recode ing_sal 0=.
recode ing_cta 0=.
recode ing_rent 0=.
recode ing_lab 0=.
recode ing_tot 0=.

* Análisis del ingreso percápita

destring ciudad zona sector vivienda hogar, replace
sort ciudad zona sector vivienda hogar
egen idhogar=group(ciudad zona sector vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
egen inglab_hh=sum(ing_lab), by(idhogar)
egen ingcta_hh=sum(ing_cta), by(idhogar)
egen ingrent_hh=sum(ing_rent), by(idhogar)

gen ingtot_per=ingtot_hh/n
gen inglab_per=inglab_hh/n
gen ingrent_per=ingrent_hh/n


recode ingtot_per 0=.




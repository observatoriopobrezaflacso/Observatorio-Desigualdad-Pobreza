*Programa para calcular desigualdad.

*Ingresos Laborales

recode ingpat 99999999=.
recode ingasg 99999999=.
recode ingepv 99999999=.
recode ingdom 99999999=.

recode ingpat . = 0
recode  ingasg . = 0
recode  ingepv . = 0
recode ingdom . = 0

gen ing_sal = ingasg+ingepv+ingdom
gen ing_cta = ingpat
gen ing_lab = ingpat+ingasg+ingepv+ingdom

*Rentas y otros
recode ingjub 99999999=.
recode ingjub .=0
recode  ingalq 99999999 = .
recode ingalq .=0
recode  ingotr 99999999 = .
recode ingotr .=0

gen ing_rent= ingjub+ingalq+ingotr
gen ing_tot=ing_lab+ing_rent

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

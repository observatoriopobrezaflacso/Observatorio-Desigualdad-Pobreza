*Programa para calcular desigualdad.

gen escola= anoinst if nivinst==3
replace escola=0 if nivinst==1
replace escola=1 if nivinst==2
replace escola=anoinst+6 if nivinst==4
replace escola=anoinst+12 if nivinst==5

generate califica=1 if escola>12
replace califica=0 if escola<=12

generate moderno=1 if peamsiu==1
replace moderno=0 if peamsiu==2

generate moder_cal=1 if moderno==1 & califica==1
replace moder_cal=0 if moderno==0 | califica==0

*Ingresos Laborales

recode ingpat 9999999 = .
recode  ingasg 9999999 = .
recode  ingepv 9999999 = .
recode ingdom 9999999 = .

recode ingpat . = 0
recode  ingasg . = 0
recode  ingepv . = 0
recode ingdom . = 0

gen ing_sal = ingasg+ingepv+ingdom
gen ing_cta = ingpat
gen ing_lab = ingpat+ingasg+ingepv+ingdom

*Rentas y otros

recode  ingjub 9999999 = .
recode ingjub .=0
recode  ingalq 9999999 = .
recode ingalq .=0
recode  ingotr 9999999 = .
recode ingotr .=0

gen ing_rent= ingjub+ingalq+ingotr

gen ing_tot=ing_lab+ing_rent

recode ing_sal 0=.
recode ing_cta 0=.
recode ing_rent 0=.
recode ing_lab 0=.
recode ing_tot 0=.

*inequal ing_lab
*inequal ing_rent
*inequal ing_tot

descogini ing_tot ing_lab ing_rent
descogini ing_tot ingrl ingjub ingalq ingotr

*bootstrap "descogini ing_tot ingrl ingjub ingalq ingotr" _b
*bootstrap "descogini ing_tot ingrl ingjub ingalq ingotr" _b


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

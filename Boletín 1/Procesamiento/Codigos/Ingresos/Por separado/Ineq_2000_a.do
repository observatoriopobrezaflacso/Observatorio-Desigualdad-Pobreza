*Programa para calcular desigualdad.

cd "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Bases\enemdu_diciembres"

use "empleo2000", clear

drop if area==2

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


*save "$out/ingresos_pc_urb/ing_perca_2000.dta", replace

s

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbon_per 

povdeco ingtot_per [w=fexp], pline(27.6)

inequal ingtot_per [w=round(fexp)]
inequal ing_lab [w=round(fexp)]
inequal ing_rent [w=round(fexp)]

sumdist ingtot_per [w=fexp] if ingtot_per>0, n(10) qgp(decil)
 
sort decil
table decil [fweight = round(fexp)], contents(sum ing_lab)
table decil [fweight = round(fexp)], contents(sum ing_rent)

*Número de perceptores de ingreso por hogar, por deciles.

sort idhogar
by idhogar: egen perceptor_hh = count(ing_tot)
table decil [fweight = round(fexp)], contents(mean perceptor)
mean perceptor [fweight=round(fexp)]


*Escolaridad promedio de la PEA, por decil.
*Tasa de ocupación por decil
gen ocupa_pleno=condact==1 if edad>=25 & edad<=55
gen esco_pea=escola if edad>=25 & edad<=55 & condact<=6

table decil [fweight = round(fexp)], contents(mean esco_pea)
table decil [fweight = round(fexp)], contents(mean ocupa_pleno)
mean esco_pea [fweight=round(fexp)]


table decil [fweight = round(fexp)], contents(mean moderno)


*tasa de dependencia del hh
gen edad25_55=1 if edad>=25 & edad<=55
egen edad25_55hh=sum(edad25_55), by(idhogar)
gen propor_25_55=edad25_55hh/n

table decil [fweight = round(fexp)], contents(mean propor_25_55)
mean propor_25_55 [fweight=round(fexp)]

*BDH

table decil [fweight = round(fexp)], contents(sum ingbon)
table decil [fweight = round(fexp)], contents(sum ing_rem)


*Minceriano

generate primaria=nivinst==3
generate media=nivinst==4
generate superior=nivinst==5

generate horas=hortrasa*4
generate hwage=ing_lab/horas
generate log_wage=ln(hwage)

generate edad2=edad*edad
*de 25 a 55 años y solo urbano.

gen urbano=area==1

reg log_wage urbano sexo califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55, robust



reg log_wage califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55 & sexo==1
reg log_wage califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55 & sexo==2

table decil [fweight = round(fexp)], contents(mean hortrasa)
mean hortrasa [fweight=round(fexp)]





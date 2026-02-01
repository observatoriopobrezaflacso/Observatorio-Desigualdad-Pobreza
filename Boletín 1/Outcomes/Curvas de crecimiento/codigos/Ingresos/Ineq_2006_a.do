*Programa para calcular desigualdad.

set mem 80m

use "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/enemdu_diciembres/empleo2006", clear

drop if area==2

gen escola=0 if nivinst==1
replace escola=1 if nivinst==2
replace escola=anoinst if nivinst==3
replace escola=anoinst if nivinst==4
replace escola=anoinst + 6 if nivinst==5
replace escola=anoinst + 6 if nivinst==6
replace escola=anoinst + 12 if nivinst==7
replace escola=anoinst + 12 if nivinst==8
replace escola=anoinst + 17 if nivinst==9

generate califica=1 if escola>12
replace califica=0 if escola<=12
generate moderno=1 if peamsiu==1
replace moderno=0 if peamsiu==2

generate moder_cal=1 if moderno==1 & califica==1
replace moder_cal=0 if moderno==0 | califica==0

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

gen ingtot_per_deflated = ingtot_per * .6510417

save "$out/ingresos_pc_urb/ing_perca_2006.dta", replace

s

sum ingtot_per [w=round(fexp)]

povdeco ingtot_per [w=round(fexp)], pline(43.9)

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per
bootstrap "descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per" _b


inequal ingtot_per [w=round(fexp)]
inequal ing_lab [w=round(fexp)]
inequal ing_rent [w=round(fexp)]

sumdist ingtot_per [w=fexp], n(10) 

sumdist ingtot_per [w=fexp] if ingtot_per>0, n(10) qgp(decil)
 
sort decil
table decil [fweight = round(fexp)], contents(sum ing_lab)
table decil [fweight = round(fexp)], contents(sum ing_rent)

*BDH

table decil [fweight = round(fexp)], contents(sum ingbon)
table decil [fweight = round(fexp)], contents(sum ing_rem)


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
table decil [fweight = round(fexp)], contents(mean moderno)

mean esco_pea [fweight=round(fexp)]

*tasa de dependencia del hh
gen edad25_55=1 if edad>=25 & edad<=55
egen edad25_55hh=sum(edad25_55), by(idhogar)
gen propor_25_55=edad25_55hh/n

table decil [fweight = round(fexp)], contents(mean propor_25_55)
mean propor_25_55 [fweight=round(fexp)]


table decil [fweight = round(fexp)], contents(mean hortrasa)
mean hortrasa [fweight=round(fexp)]


*Minceriano

generate primaria=nivinst==3
generate media=nivinst==4
generate superior=nivinst==5

generate horas=hortrasa*4
generate hwage=ing_lab/horas
generate log_wage=ln(hwage)

generate edad2=edad*edad
*de 25 a 55 años y solo urbano.

gen dindio=pe13==1
gen dnegro=pe13>=4 & pe13<=5
gen dsexo=sexo==2

reg log_wage sexo califica edad edad2 moderno [w=fexp] if edad>=25 & edad<=55, robust 

reg log_wage califica edad edad2 moderno [w=fexp] if edad>=25 & edad<=55 & sexo==1
reg log_wage califica edad edad2 moderno [w=fexp] if edad>=25 & edad<=55 & sexo==2

reg log_wage califica edad edad2 moderno dsexo dindio dnegro [w=fexp] if edad>=25 & edad<=55, robust








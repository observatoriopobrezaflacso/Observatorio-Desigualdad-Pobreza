*Programa para calcular desigualdad.

set mem 80m

use "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/enemdu_diciembres/empleo2010", clear


drop if area==2

gen escola=0 if p10a==1
replace escola=1 if p10a==2
replace escola=p10b if p10a==3
replace escola=p10b if p10a==4
replace escola=p10b + 6 if p10a==5
replace escola=p10b + 6 if p10a==6
replace escola=p10b + 12 if p10a==7
replace escola=p10b + 12 if p10a==8
replace escola=p10b + 17 if p10a==9

generate califica=1 if escola>12
replace califica=0 if escola<=12

*generate moderno=1 if peamsiu==1
*replace moderno=0 if peamsiu==2

*generate moder_cal=1 if moderno==1 & califica==1
*replace moder_cal=0 if moderno==0 | califica==0

generate primaria=p10a==4 | (p10a==5 & p10b<=6)
generate media=p10a==6 |(p10a==5 & p10b>6)| (p10a==7)
generate superior=p10a>=8

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

gen ingtot_per_deflated = ingtot_per * .5372285

save "$out/ingresos_pc_urb/ing_perca_2010.dta", replace

s




sum ingtot_per [w=round(fexp)]

inequal ingtot_per [w=round(fexp)]
inequal ing_lab [w=round(fexp)]
inequal ing_rent [w=round(fexp)]

povdeco ingtot_per [w=round(fexp)], pline(53)

gen ing_per_sinbdh=ingtot_per-ingbo_per

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per
bootstrap "descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per" _b


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


generate edad=p03

*Escolaridad promedio de la PEA, por decil.
*Tasa de ocupación por decil
gen ocupa_pleno=condact==1 if edad>=25 & edad<=55
gen esco_pea=escola if edad>=25 & edad<=55 & condact<=6

table decil [fweight = round(fexp)], contents(mean esco_pea)
table decil [fweight = round(fexp)], contents(mean moderno)
mean esco_pea [fweight=round(fexp)]

table decil [fweight = round(fexp)], contents(mean ingtot_per)
table decil [fweight = round(fexp)], contents(mean ing_per_sinbdh)

inequal ingtot_per [w=round(fexp)]
inequal ing_per_sinbdh [w=round(fexp)]



*tasa de dependencia del hh
gen edad25_55=1 if edad>=25 & edad<=55
egen edad25_55hh=sum(edad25_55), by(idhogar)
gen propor_25_55=edad25_55hh/n

table decil [fweight = round(fexp)], contents(mean propor_25_55)
mean propor_25_55 [fweight=round(fexp)]



*Minceriano

generate horas=p24*4
generate hwage=ing_lab/horas
generate log_wage=ln(hwage)


generate edad2=edad*edad
generate dsexo=p02==2

gen dindio= p15==1
gen dnegro=p15>=2 & p15<=4

reg log_wage dsexo califica edad edad2 moderno [fw= round(fexp)] if edad>=25 & edad<=55, robust 


reg log_wage califica edad edad2 moderno [fw= round(fexp)] if edad>=25 & edad<=55 & dsexo==0, robust
reg log_wage califica edad edad2 moderno [fw= round(fexp)] if edad>=25 & edad<=55 & dsexo==1, robust


reg log_wage califica edad edad2 dsexo moderno dindio dnegro [fw= round(fexp)] if edad>=25 & edad<=55 & dsexo==0, robust

table decil [fweight = round(fexp)], contents(mean p24)
mean p24 [fweight=round(fexp)]



_
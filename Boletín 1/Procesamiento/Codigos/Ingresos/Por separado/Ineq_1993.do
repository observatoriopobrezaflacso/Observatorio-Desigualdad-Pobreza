*Programa para calcular desigualdad.

cd "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases/enemdu_diciembres"

use "empleo1993.dta", clear

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

ineqdeco ing_lab
ineqdeco ing_rent
ineqdeco ing_tot

*descogini ing_tot ing_lab ing_rent
*descogini ing_tot ingrl ingjub ingalq ingotr

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

sum ingtot_per [w=fexp]

ineqdeco inglab_per [w=fexp] 
ineqdeco ingrent_per [w=fexp] 
ineqdeco ingtot_per [w=fexp] 

s

*povdeco ingtot_per [w=fexp], pline(63405)

*descogini ingtot_per inglab_per ingrent_per 
*bootstrap "descogini ingtot_per inglab_per ingrent_per" _b

*sgini inglab_per ingrent_per, sourcedecomposition

*bootstrap (asd: a=r(coeffs)): sgini inglab_per ingrent_per, sourcedecomposition
s

capture program drop mygini
program define mygini, rclass
    sgini inglab_per ingrent_per, sourcedecomposition
    matrix shares = r(s)
    matrix shares = r(s)
    return scalar inglab = shares[1,1]
    return scalar ingrent = shares[1,2]
end


bootstrap (shares: inglab= r(inglab) ingrent=r(ingrent)) : mygini

bootstrap (shares: inglab= r(inglab) ingrent=r(ingrent)) (scale: sd=r(sd) iqr=(r(p75)-r(p25)) range=(r(max)-r(min))) : mygini


bootstrap (location: mean=r(mean) median=r(p50)) (scale: sd=r(sd) iqr=(r(p75)-r(p25)) range=(r(max)-r(min))) : summarize price, detail



sysuse auto, clear


bootstrap (location: mean=r(mean) median=r(p50)) (scale: sd=r(sd) iqr=(r(p75)-r(p25)) range=(r(max)-r(min))) : summarize price, detail


bootstrap (location: mean=r(mean) median=r(p50))
                (scale: sd=r(sd) iqr=(r(p75)-r(p25))
                        range=(r(max)-r(min)))
                : summarize price, detail
				
				

bootstrap , r	eps(50): ///
    sgini inglab_per ingrent_per, sourcedecomposition


s
sumdist ingtot_per [w=fexp] if ingtot_per>0, n(10) qgp(decil)
 
sort decil
by decil: egen dec_ing_lab = sum(ing_lab)
by decil: egen dec_ing_rent = sum(ing_rent)

*collapse (sum) dec_ing_lab [fw=fexp], by(decil)
*collapse (sum) dec_ing_rent [fw=fexp], by(decil)


*Número de perceptores de ingreso por hogar, por deciles.

sort idhogar
by idhogar: egen perceptor_hh = count(ing_tot)
table decil [fweight = fexp], contents(mean perceptor)

*Escolaridad promedio de la PEA, por decil.
*Tasa de ocupación por decil
gen ocupa_pleno=condact==1 if edad>=25 & edad<=55
gen esco_pea=escola if edad>=25 & edad<=55 & condact<=6

table decil [fweight = fexp], contents(mean esco_pea)
table decil [fweight = fexp], contents(mean ocupa_pleno)
table decil [fweight = fexp], contents(mean moderno)

*tasa de dependencia del hh
gen edad25_55=1 if edad>=25 & edad<=55
egen edad25_55hh=sum(edad25_55), by(idhogar)
gen propor_25_55=edad25_55hh/n

table decil [fweight = fexp], contents(mean propor_25_55)

*Asalariados.

gen asal =1 if catetrab==6 | catetrab==7
gen publico=1 if asal==1 & catetrab==6
replace publico=0 if asal==1 & catetrab==7

table decil [fweight = fexp], contents(mean publico)


*Minceriano
generate primaria=nivinst==3
generate media=nivinst==4
generate superior=nivinst==5

generate horas=hortrasa*4
generate hwage=ing_lab/horas
generate log_wage=ln(hwage)

generate edad2=edad*edad
*de 25 a 55 años y solo urbano.

reg log_wage sexo califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55, robust

reg log_wage califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55 & sexo==1
reg log_wage califica edad edad2 moderno [weight=fexp] if edad>=25 & edad<=55 & sexo==2







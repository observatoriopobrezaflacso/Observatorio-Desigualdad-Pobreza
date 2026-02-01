*Calculo ingresos totales
*ENEMDU 2003

cd "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases/enemdu_diciembres"

use "empleo2003.dta", clear



*Rentas y otros
recode pe68b 999999=.
recode pe68b .=0
recode pe69b 999999=.
recode pe69b .=0
recode pe70b 999999=.
recode pe70b .=0

generate ing_rent=pe68b+pe69b+pe70b

generate ing_rem=pe71b
recode ing_rem .=0
recode pe72b 999999=.
generate ingbon=pe72b
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)

egen ing_tot = rowtotal(ingrl ing_rent ingbon ing_rem)

recode ing_tot (0=.)

destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
egen ingrem_hh=sum(ing_rem), by(idhogar)
egen ingbo_hh=sum(ingbon), by(idhogar)
egen inglab_hh=sum(ingrl), by(idhogar)
egen ingrent_hh=sum(ing_rent), by(idhogar)

gen ingtot_per =ingtot_hh/n
gen ingrem_per = ingrem_hh/n
gen ingbo_per = ingbo_hh/n
gen inglab_per = inglab_hh/n
gen ingrent_per = ingrent_hh/n

keep if area == 1

descogini ingtot_per inglab_per ingrent_per ingrem_per ingbo_per

sgini inglab_per ingrent_per ingrem_per ingbo_per, sourcedecomposition

br idhogar ing_tot ingrl ing_rent ingbon ing_rem *_hh ingtot_per inglab_per ingrent_per ingrem_per ingbo_per if ingtot_per != inglab_per + ingrent_per + ingrem_per + ingbo_per

br ing_tot ingrl ing_rent ingbon ing_rem if ing_tot!= ingrl+ing_rent+ingbon+ing_rem

s






inequal ingpc [w=round(fexp)]

sort ingpc
xtile decil = ingpc [pw=fexp], n(10)

gen duniversitario=nivinst>=9 & nivinst<=10
gen indigena=pe13==1
gen publico=1 if catetrab==1
replace publico=0 if catetrab==2


tabstat ingrl [w=round(fexp)], by(duniversitario) statistics (N mean)

tabstat ingrl [w=round(fexp)], by(publico) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(sexo) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(indigen) statistics (N mean)


*Indice de Palma
sort ingpc
xtile decil = ingpc [pw=fexp], n(10)

collapse (sum) ingpc [pw=fexp], by(decil)
egen total_ingreso = total(ingpc)
gen participacion = ingpc / total_ingreso


summ ingpc if decil==10
scalar top10 = r(mean)

summ ingpc if decil<=4
scalar bottom40 = r(sum)

scalar palma = top10 / bottom40
display "Índice de Palma = " palma

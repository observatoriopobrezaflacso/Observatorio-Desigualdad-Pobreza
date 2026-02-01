
*Indicadores de desigualdad

use "C:\Users\JuanElíasPonceJarrín\OneDrive - flacso.edu.ec\Documents\DISCO D\Inequality\clase media\Encuestas de empleo\empleo01.dta", clear

*Rentas y otros

recode pe65a (999999 = .)
recode pe66a (999999 = .)
recode pe67a (999999 = .)
generate ing_rent=pe65a+pe66a+pe67a
recode ing_rent .=0
recode pe68a (999999 = .)
generate ing_rem=pe68a
recode ing_rem .=0

recode pe69a (999999 = .)
generate ingbon=pe69a
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)
generate ing_tot=ingrl+ing_rent+ingbon+ing_rem

recode ing_tot (0=.)
recode ing_tot (200000 = .) (200002= .)

destring area ciudad zona sector vivienda hogar, replace
sort ciudad zona sector vivienda hogar
egen idhogar=group(ciudad zona sector vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)

gen ingpc=ingtot_hh/n

recode ingpc (0=.)
inequal ingpc [w=round(fexp)]


sort ingpc
xtile decil = ingpc [pw=fexp], n(10)

gen duniversitario=nivinst>=6 & nivinst<=7
gen indigena=pe14==3
gen publico=1 if catetrab==1
replace publico=0 if catetrab==2

tabstat ingrl [w=round(fexp)], by(duniversitario) statistics (N mean)

tabstat ingrl [w=round(fexp)], by(publico) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(sexo) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(indigen) statistics (N mean)

*Ingreso laboral por deciles

recode ingrl (-1=.) (999999=.) (0 =.)
xtile decilab = ingrl [pw=fexp], n(10)

tabstat ingrl [w=round(fexp)], by(decilab) statistics (median)

*Indice de Palma

collapse (sum) ingpc [pw=fexp], by(decil)
egen total_ingreso = total(ingpc)
gen participacion = ingpc / total_ingreso


summ ingpc if decil==10
scalar top10 = r(mean)

summ ingpc if decil<=4
scalar bottom40 = r(sum)

scalar palma = top10 / bottom40
display "Índice de Palma = " palma

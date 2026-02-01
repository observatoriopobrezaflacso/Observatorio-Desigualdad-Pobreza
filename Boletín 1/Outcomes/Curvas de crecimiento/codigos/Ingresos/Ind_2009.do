
 use "C:\Users\JuanElíasPonceJarrín\OneDrive - flacso.edu.ec\Documents\DISCO D\BASES DE DATOS DEMOGRAFICAS INEC\ENCUENTAS DE EMPLEO\Encuestas de empleo\empleo09.dta", clear
 
 *Rentas y otros
recode p71b 999999=.
recode p71b .=0
recode p72b 999999=.
recode p72b .=0
recode p73b 999999=.
recode p73b .=0

generate ing_rent=p71b+p72b+p73b

generate ing_rem=p74b
recode ing_rem 999999= .
recode ing_rem .=0

generate ingbon=p76
recode ingbon .=0

recode ingrl (-1=.) (999999=.) (0=.)
generate ing_tot=ingrl+ing_rent+ingbon+ing_rem
recode ing_tot (0=.)

destring area ciudad zona sector panelm vivienda hogar, replace
sort ciudad zona sector panelm vivienda hogar
egen idhogar=group(ciudad zona sector panelm vivienda hogar)

gen x=1
egen n=sum(x), by(idhogar)
egen ingtot_hh=sum(ing_tot), by(idhogar)
gen ingpc=ingtot_hh/n

recode ingpc (0=.)
inequal ingpc [w=round(fexp)]

sort ingpc
xtile decil = ingpc [pw=fexp], n(10)

rename p10a nivinst
gen duniversitario=nivinst>=9 & nivinst<=10
gen publico=1 if p42==1
replace publico=0 if p42==2
gen indigena=p15==1

tabstat ingrl [w=round(fexp)], by(duniversitario) statistics (N mean)

tabstat ingrl [w=round(fexp)], by(publico) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(p02) statistics (N mean)
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




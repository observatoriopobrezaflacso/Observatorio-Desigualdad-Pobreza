
 use "C:\Users\JuanElíasPonceJarrín\OneDrive - flacso.edu.ec\Documents\DISCO D\BASES DE DATOS DEMOGRAFICAS INEC\ENCUENTAS DE EMPLEO\Encuestas de empleo\empleo17.dta", clear

 recode ingpc (0=.)
inequal ingpc [w=round(fexp)]

sort ingpc
xtile decil = ingpc [pw=fexp], n(10)

rename p10a nivinst
gen duniversitario=nivinst>=9 & nivinst<=10
gen publico=1 if p42==1
replace publico=0 if p42==2
gen indigena=p15==1

recode ingrl (-1 = .) (999999 = .) (0=.)

tabstat ingrl [w=round(fexp)], by(duniversitario) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(publico) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(p02) statistics (N mean)
tabstat ingrl [w=round(fexp)], by(indigen) statistics (N mean)

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

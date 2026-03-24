
*Construct income concepts comparable to survey ENINGHUR and National Accounts


*******************************************
*Extract information about total population first
*******************************************

use "$dir_working\ENINGHUR_ind.dta", clear

*Keep age>20, because we only change the distribution of adults in the sample, later the whole Database has to be matched
*again, including <=20. Finally, the db with individuals will be transformed to HH
keep if agegroup>=5

sum Fexp_cen
global total_pop_survey=round(r(sum))
di $total_pop_survey


*******************************************
* Work with original SRI dataset
*******************************************


*Read matched 102-107 dataset
use "$dir_input\SRI\Unif_F102_F107_prepared.dta", clear




*correct impossible values for heritage (herencias), rifas/loterias and taxes (impuestos)
*********************************************

*Herencias
*Highest tax is 35%, but highest marginal to be found is around 15%
tempvar herencia_new herencia_imp_new herencia_imp_new_max

gen `herencia_new'=img_herencias_leg_don_3420 if img_herencias_leg_don_3420>0&((img_herencias_leg_don_3420>=ipa_herencias_leg_don_3410)|ipa_herencias_leg_don_3410==.)
replace `herencia_new'=ipa_herencias_leg_don_3410 if img_herencias_leg_don_3420<ipa_herencias_leg_don_3410&ipa_herencias_leg_don_3410!=.
replace img_herencias_leg_don_3420=`herencia_new'
gen  `herencia_imp_new_max'=`herencia_new'*0.15

replace  ipa_herencias_leg_don_3410=`herencia_imp_new_max' if ipa_herencias_leg_don_3410>`herencia_imp_new_max'

*Rifas (15% flat tax)

tempvar rifa_new rifa_imp_new

gen `rifa_new'=ing_lot_rifas_apuestas_3400 if ing_lot_rifas_apuestas_3400>0&ing_lot_rifas_apuestas_3400>ipa_lot_rifas_apuestas_3390
replace `rifa_new'=ipa_lot_rifas_apuestas_3390 if ing_lot_rifas_apuestas_3400<ipa_lot_rifas_apuestas_3390
 
replace  ing_lot_rifas_apuestas_3400=`rifa_new'

gen `rifa_imp_new'=`rifa_new'*0.15
 
replace ipa_lot_rifas_apuestas_3390=`rifa_imp_new' if ipa_lot_rifas_apuestas_3390>`rifa_imp_new'


*******************************************
*	Primary income concepts
*******************************************


*B2: Operating surplus (this is owner-occupied dwelling)

gen B2R1=0
*gen B2R2=rim_arriendo_inmuebles_3060 if rim_arriendo_inmuebles_3060>0
*The direct use of _3060 resulted in a loss of information -> calculate by hand

gen B2R2=ing_arriendo_inmuebles_3040-ded_arriendo_inmuebles_3050 if ing_arriendo_inmuebles_3040>0


*B3: Mixed income

*Income from enterprises for bookkeeping firms
tempvar utilidad_102
gen `utilidad_102'=0
replace `utilidad_102'=utilidad_neta_ejercicio_2800 if utilidad_neta_ejercicio_2800>0
replace `utilidad_102'=perdida_ejercicio_2810*-1 if perdida_ejercicio_2810>0
replace `utilidad_102'=0 if `utilidad_102'<0
*sum `utilidad_102', d

*Income from enterprises for non-bookkeeping firms 
tempvar utilidad_102A
gen `utilidad_102A'=ingresos_aem_rie_1280-deducciones_aem_rie_1290
replace `utilidad_102A'=0 if `utilidad_102A'<0
*total `utilidad_102A'
*sum `utilidad_102A', d


tempvar utilidad_others
egen `utilidad_others'=rowtotal(ingresos_sir_2988 ing_libre_eje_profesional_2990 ing_ocupacion_liberal_3010 ///
								otr_ing_gravados_exterior_3180 otr_ingresos_exentos_3460)
replace `utilidad_others'=`utilidad_others'-ded_libre_eje_profesional_3000-ded_ocupacion_liberal_3020
replace `utilidad_others'=0 if `utilidad_others'<0

egen B3R1=rowtotal(`utilidad_102' `utilidad_102A' `utilidad_others')

/*
egen B3_2=rowtotal(ingresos_sir_2988 ing_libre_eje_profesional_2990 ing_ocupacion_liberal_3010 otr_ing_gravados_exterior_3180)
replace B3_2=B3_2-ded_libre_eje_profesional_3000-ded_ocupacion_liberal_3020
replace B3_2=0 if B3_2<0

egen B3R1=rowtotal(B3_1 B3_2)
drop B3_1 B3_2
*/

*D11, D121, D611, D613: Gross wages and social contributions:
***************************************************************


*Wage income dependent workers (from 107)

*di as error "stop -> sth with fondos is wrong...resolved by trimming"
*stop
tempvar fondo_real
*egen `fondo_real'=rowmin(fondo_reserva_teorico fondo_reserva)
gen `fondo_real'=fondo_reserva_teorico

egen liq_107= rowtotal(ingresos_liq_pagados sob_suel_com_remu partic_utilidades `fondo_real' decimo_cuarto decimo_tercero) if marca==1|marca==3

*Check and correct for impossible values of income and social security contributions by employee
tempvar liq_foriess_107 iess_porc_107 dif_107 iess_porc_102 dif_102

*Social contributions are paid for this part:
egen `liq_foriess_107'=rowtotal(ingresos_liq_pagados sob_suel_com_remu partic_utilidades)

*gen iess_porc_107=aporte_iess_empleado/liq_107
gen `iess_porc_107'=aporte_iess_empleado/`liq_foriess_107'
/*sum `iess_porc_107', d
sum `iess_porc_107' if marca==1, d
sum `iess_porc_107' if marca==3, d
*/

*Correct impossible values
*************************************

*More social contribution than salary for 107s:
gen `dif_107'=`liq_foriess_107'-aporte_iess_empleado if marca==1|marca==3
sum `dif_107', d

*gen `dif_107'=liq_107-aporte_iess_empleado if marca==1|marca==3
sum `iess_porc_107' if  marca==1|marca==3&aporte_iess_empleado!=0
local iess_mean=r(mean)
replace aporte_iess_empleado=`iess_mean'*`liq_foriess_107' if `dif_107'<=0

*More social contribution than salary for 102s:
gen `iess_porc_102'=ded_syo_trabajo_rde_3250/ ing_syo_trabajo_rde_3240

gen `dif_102'=ing_syo_trabajo_rde_3240- ded_syo_trabajo_rde_3250 if marca==2|marca==3

sum `iess_porc_102' if  marca==2|marca==3&ing_syo_trabajo_rde_3240!=0
local iess_mean=r(mean)
replace ded_syo_trabajo_rde_3250=`iess_mean'*ing_syo_trabajo_rde_3240 if `dif_102'<=0


*Check for inconsistencies in comparison between declared income and soc. contributions in 107 and 102
*********************************************

gen inc_102_g_107=1 if ing_syo_trabajo_rde_3240> liq_107& ing_syo_trabajo_rde_3240!=.
replace inc_102_g_107=0 if inc_102_g_107!=1&ing_syo_trabajo_rde_3240!=.
gen iess_102_g_107=1 if ded_syo_trabajo_rde_3250> aporte_iess_empleado& ded_syo_trabajo_rde_3250!=.
replace iess_102_g_107=0 if iess_102_g_107!=1& ded_syo_trabajo_rde_3250!=.

*gen dif_perc=(aporte_iess_empleado/ liq_107)-(ded_syo_trabajo_rde_3250/ ing_syo_trabajo_rde_3240)


*Calculte D11R, D613P directly from dataset
**********************************************

*107
gen D11R=liq_107 if marca==1
gen D613P=aporte_iess_empleado if marca==1

*102
replace D11R=ing_syo_trabajo_rde_3240 if marca==2
replace D613P=ded_syo_trabajo_rde_3250 if marca==2

*Intersection
replace D11R=ing_syo_trabajo_rde_3240 if marca==3&inc_102_g_107
replace D11R=liq_107 if marca==3&inc_102_g_107==0

*	Check which IESS is higher

*Take IESS from 102 if both income and IESS from 102 are higher, and vice versa
replace D613P=ded_syo_trabajo_rde_3250 if marca==3&inc_102_g_107&iess_102_g_107
replace D613P=aporte_iess_empleado if marca==3&inc_102_g_107==0&iess_102_g_107==0

*In cases, where income from 102 is higher, but IESS from 102 lower, only take IESS from 107 if IESS from 102 is considerable smaller (less than 10% of 107)
*and 3 cases of vice versa
replace D613P=aporte_iess_empleado if marca==3&inc_102_g_107==1&iess_102_g_107==0&(ded_syo_trabajo_rde_3250/ ing_syo_trabajo_rde_3240)<=0.01
replace D613P=ded_syo_trabajo_rde_3250 if marca==3&inc_102_g_107==1&iess_102_g_107==0&(ded_syo_trabajo_rde_3250/ ing_syo_trabajo_rde_3240)>0.01

replace D613P=ded_syo_trabajo_rde_3250 if marca==3&inc_102_g_107==0&iess_102_g_107&(aporte_iess_empleado/ liq_107)<=0.01
replace D613P=aporte_iess_empleado if marca==3&inc_102_g_107==0&iess_102_g_107&(aporte_iess_empleado/ liq_107)>0.01

*The rest is impution which will be done in Syntaxis 4


gen D611P=0
gen D121R=D611P


*D4 Property income:
*********************

*D41R Interest received

gen D41R=rendimientos_financieros_3190 

*egen D41_intrec=rowtotal( ingresos_regalias_3170 rendimientos_financieros_3190 ingresos_otr_rgr_3193)
*replace D41_intrec=D41_intrec-deducciones_otr_rgr_3194


*D42 Distributed income of corporations

gen D42R=dividendos_recibidos_3192

*D45 Rent received

egen D45R=rowtotal( rim_arriendo_otros_act_3100 rim_predios_agricolas_3164 ingresos_regalias_3170 ///
					ingresos_otr_rgr_3193 img_herencias_leg_don_3420)
					
replace D45R=D45R-deducciones_otr_rgr_3194
rename  img_herencias_leg_don_3420 D45R_inheritance


egen D4R=rowtotal(D41R D42R D45R)
gen D4P=0
gen D4N=D4R-D4P

/*One more precision is possible:
Following EG-DNA Guide p. 11: Mixed income is but before deducting any interest charges, rent or other property incomes payable on financial assets, 
land or other natural resources required to carry out the production.
Therefore, one could exclude the following costs from Mixed income (B3R) and convert them to interest costs (D41P)
 total cto_iba_local_2120 gto_iba_local_2130 cto_iba_exterior_2140 gto_iba_exterior_2150 gto_inp_terceros_locales_2160 gto_inp_terceros_exterior_2170 
*/

*******************************************
*	Disposable Income concepts
*******************************************


*D62: Social benefits other than STiK received

egen D62R=rowtotal(ing_pensiones_jubilares_3450 )

*D7: Other current transfers (net)

egen D75R=rowtotal(ing_lot_rifas_apuestas_3400)

gen D7R=D75R
gen D7P=0

gen D7N=D7R-D7P


*D5: Current taxes on income and wealth

*egen D5P=rowtotal(imp_renta_causado_3490 ipa_lot_rifas_apuestas_3390 ipa_herencias_leg_don_3410)


*Correct impossible values of income tax (highest rate is 35%, but temp_taxable is
*not exactly the same es base gravable -  difficult to calculate marginals, therefore trim at 50%)

tempvar temp_taxable

egen `temp_taxable'=rowtotal(D11R D121R B2R2 B3R1 D4N D62R D7N)
replace `temp_taxable'=0 if `temp_taxable'<0

gen max_imp=`temp_taxable'*0.5

*Here include taxes from 102 and 107
replace imp_renta_causado_3490=imp_renta_causado if marca==1
replace imp_renta_causado_3490=imp_renta_causado if marca==3&imp_renta_causado>imp_renta_causado_3490

replace imp_renta_causado_3490=`temp_taxable'*0.5 if (imp_renta_causado_3490)>(`temp_taxable'*0.5)
							

egen D5P=rowtotal(imp_renta_causado_3490 /*imp_renta_causado*/ ipa_lot_rifas_apuestas_3390 ipa_herencias_leg_don_3410)


*******************************************
*DINA Aggreate: 
*******************************************

gen B2R=B2R2
gen B3R=B3R1
egen B2B3R=rowtotal(B2R B3R)

egen D1R=rowtotal(D11R D121R)

egen B5R=rowtotal(B2B3R D1R D4N)

egen D61P=rowtotal(D611P D613P)


egen B6R=rowtotal(B5R D62R D7N)
replace B6R=B6R-D5P-D61P

*************************************
*Define the merging variable PreTaxHHI
*************************************

egen PreTaxHHI=rowtotal(B2B3R D11R D4R D62R D7R)
*replace PreTaxHHI=PreTaxHHI - D61P

/*
********************************************
*Check for outliers
********************************************
preserve

keep if PreTaxHHI>10000

egen rank=rank(-PreTaxHHI)
keep if rank<=100
sort rank


/*keep  numero_identificacion ingresos_liq_pagados sob_suel_com_remu decimo_cuarto decimo_tercero fondo_reserva* desahucio_otras_remun partic_utilidades aporte_iess_empleado imp_renta_causado salario_digno valor_retenido base_imponible ///
      utilidad_neta_ejercicio_2800 ingresos_aem_rie_1280 ing_arriendo_inmuebles_3040 ingresos_sir_2988 ing_libre_eje_profesional_2990 ing_ocupacion_liberal_3010 otr_ing_gravados_exterior_3180 ing_syo_trabajo_rde_3240 rendimientos_financieros_3190 dividendos_recibidos_3192 rim_arriendo_otros_act_3100 rim_predios_agricolas_3164 ingresos_regalias_3170 ingresos_otr_rgr_3193 ing_pensiones_jubilares_3450  otr_ingresos_exentos_3460 ing_lot_rifas_apuestas_3400 img_herencias_leg_don_3420 ///
	  D11R D613P D611P D121R D41R D42R D45R D4R D4P D4N D5P D62R D75R D7R D7P D7N B2R B3R B2B3R D1R B5R D61P B6R PreTaxHHI rank
*/
egen max_comp=rowmax(D11R B2R B3R D4R D7R D62R)
gen max_comp2="wages" if max_comp==D11R
replace max_comp2="operating surplus" if max_comp==B2R
replace max_comp2="mixed income" if max_comp==B3R
replace max_comp2="property income" if max_comp==D4R
replace max_comp2="social benefits" if max_comp==D62R
replace max_comp2="other transfers" if max_comp==D7R

egen max_detail=rowmax(ingresos_liq_pagados - ingresos_sir_2988)
gen detail=""

foreach var of varlist ingresos_liq_pagados - ingresos_sir_2988 {
	di `var'
	replace detail="`var'" if round(`var')==round(max_detail)
}


/*capture drop f102g
gen f102g=1 if ing_syo_trabajo_rde_3240>ingresos_liq_pagados&ing_syo_trabajo_rde_3240!=.

total ingresos_liq_pagados if f102g!=1
*/

order numero_ident

export excel using "$dir_working\outliers.xls", sheet(`year') sheetreplace firstrow(var)

***********Here has to come the elmination of outliers**

restore
*/

***********************************************
* Check for inconsistencies (negative values)
***********************************************

keep numero_identificacion B2* B3* B5* B6* D* Pre marca

sum B2R B3R B5R D1R D4N D45R D62R PreTaxHHI if (B2B3R<0|D1R<0|D4N<0|D62R<0)&PreTaxHHI<0

*Only keep positive income observations from SRI
keep if PreTaxHHI>0

sum B2R B3R B5R D1R D4N D45R D62R PreTaxHHI if (B2B3R<0|D1R<0|D4N<0|D62R<0)

*di as error "Be aware that we keep negative values for mixed income, which are deleated in the ENINGHUR survey by default. This is especially important for the Machine Learning approach!"

************************************************
*Make values monthly and save
************************************************
foreach var of varlist B2* B3* B5* B6* D* Pre {
		*Make all values monthly for merge
		replace `var' = `var' /12
	}

		


total PreTaxHHI
*di r(table)[1,1]*12

egen num_rank=rank(PreTaxHHI), unique

*tostring num_rank, gen(rank2) format(%08.0f)
tostring num_rank, replace format(%08.0f)
drop numero_identificacion
rename num_rank numero_identificacion

sort numero_identificacion
order numero_ide


********************************************
*Artificially increment dataset to be "representative" for the whole population >20
********************************************

set obs $total_pop_survey

gen numero_temp = _n if numero_identificacion==""
tostring numero_temp, replace format(%08.0f)

replace numero_identificacion=numero_temp if marca==.
drop numero_temp
replace $income_var=0 if marca==.
replace marca=99 if marca==.
label define marca 99 "4 SRI_0", add



save "$dir_working\SRI_ind.dta", replace


********************************************
*Create reduced Tax Dataset (127 brackets)
********************************************

use "$dir_working\SRI_ind.dta", clear


sort $income_var

gen freq=1/_N
gen F_freq=sum(freq)


egen fractile = cut(F_freq), at(0(0.01) 0.99 0.991(0.001)0.999 0.9991(0.0001)0.9999 0.99991(0.00001)0.99999 1)
replace fractile=0.99999 if F_freq==1

tab fractile, sum($income_var)
egen bracket=group(fractile)

collapse (min) fractile thr=$income_var (mean) bracketavg=$income_var (count) obs=fractile ///
		 (sum) B2B3R D1R D4N B5R, by(bracket)

rename fractile p
drop B* D* 


save "$dir_working\SRI_ind_127_brackets", replace



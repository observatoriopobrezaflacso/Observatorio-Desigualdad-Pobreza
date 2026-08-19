/*******************************************************************************
* Se ejecuta DESPUÉS de data_preparation:
*   - $dir_merged/data_preparation.dta   (panel persona-año)
*
* Bloques 
*   A. delta_pctl SIGNADO   → beta(pandemic) ~0 (movilidad de rango, suma cero).
*   B. Movilidad de RANGO:  |Δpercentil| + persistencia en cima/fondo.
*   C. Movilidad ABSOLUTA:  crecimiento real del ingreso.
*******************************************************************************/

* ============================================================================
* RUTAS 
* ============================================================================

global user_root "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

global ipc		  "$user_root/03 BDD/IPC"
global dina       "$user_root/03 BDD/IR/Merged/ingreso_dina"
global data_out   "$user_root/Proyectos/Impacto shocks/data"
global results    "$user_root/Proyectos/Impacto shocks/resultados"
global senescyt   "$user_root/03 BDD/SENESCYT"



use "$data_out/working_data_balanced.dta", clear

merge m:1 anio using "$ipc/defl", nogen keep(1 3)

xtset id_bal anio

gen ipc_t0 = L.ipc
rename ipc ipc_t1

gen real_t0_2 = ingreso_t0_2 / (ipc_t0/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real = ingreso_t1/ingreso_t0_2 - 1

tabstat g_real if ingreso_t0_2 > 1 & anio == 2020, by(decil_t0_2)


tabstat g_real if ingreso_t0_2 > 1 & anio == 2020, by(decil_t0_2)



use "$data_out/working_data_unbalanced.dta", clear

merge m:1 anio using "$ipc/defl", nogen

xtset id_bal anio

gen ipc_t0 = L.ipc
rename ipc ipc_t1

gen real_t0_2 = ingreso_t0_2 / (ipc_t0/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real = ingreso_t1/ingreso_t0_2 - 1
	


tabstat g_real if ingreso_t0_2 > 10 & anio == 2020, by(decil_t0_2)


gen t0_2_mayor_10 = ingreso_t0_2 >= 10 
gen t0_2_mayor_400 = ingreso_t0_2 >= 400

preserve 
gen n = 1
collapse (mean) g_real (sum) n, by(anio decil_t0_2 t0_2_mayor_10 t0_2_mayor_400)
export excel using "$results/descriptivos/g_real_by_decil.xlsx", firstrow(var) replace
restore



preserve 
keep if anio == 2020 
tabstat g_real if ingreso_t0_2 > 10, by(decil_t0_2) 
restore

preserve 
keep if anio == 2019 
tabstat g_real if ingreso_t0_2 > 1, by(decil_t0_2) 
restore



tabstat delta_pctl_1, by(anio_t1) stat(mean n) format(%9.5f)
tabstat delta_pctl_2, by(anio_t1) stat(mean n) format(%9.5f)



fillin id_bal anio
save "$data_out/fillin_data_unbalanced.dta", replace

use "$data_out/fillin_data_unbalanced.dta", clear

gen has_preyear = 1 if ingreso_l1 != .
replace has_preyear = 0 if has_preyear == . 

tabstat has_preyear2, by(anio) stat(mean n) format(%9.5f)
reg has_preyear ib2020.anio


forval i = 2017/2021 {
gen a = decil_t0_1 if anio == `i' + 1
bysort id_bal: egen decil_`i'_1 = max(a)

gen b = decil_t0_2 if anio == `i' + 1
bysort id_bal: egen decil_`i'_2 = max(b)

drop a b
}

forval i = 2019/2021 {

preserve 
keep if anio == `i'
local j = `i' - 2
gen n = 1
collapse (mean) has_preyear (sum) n, by(anio decil_`j'_1)
export excel using "$results/descriptivos/attrition_by_decil_`j'_1.xlsx", firstrow(var) replace
restore

preserve 
keep if anio == `i'
gen n = 1
collapse (mean) has_preyear (sum) n, by(anio decil_`j'_2)
export excel using "$results/descriptivos/attrition_by_decil_`j'_2.xlsx", firstrow(var) replace
restore
}

preserve 
gen n = 1
collapse (mean) has_preyear (sum) n, by(anio decil_2018_2)
export excel using "$results/descriptivos/attrition_by_decil_2018_2.xlsx", firstrow(var) replace
restore




* ============================================================================
* A. RANGO SIGNADO — CHEQUEO DEL COEFICIENTE CERO
* ============================================================================

tabstat delta_pctl, by(anio_t1) stat(mean n) format(%9.5f)
regress delta_pctl pandemic, vce(cluster id_bal)
regress delta_decil pandemic, vce(cluster id_bal)


* ============================================================================
* B. MOVILIDAD DE RANGO — CAMBIO ABSOLUTO Y PERSISTENCIA (BALANCEADO)
* ============================================================================

log using "$dir_out/movilidad_relativa_unbalanced", replace text

* --- Descriptiva: matriz de transición por quintil ---
gen q_t0 = ceil(percentil_t0/20)
gen q_t1 = ceil(percentil_t1/20)
replace q_t0 = 5 if q_t0>5 & !missing(q_t0)
replace q_t1 = 5 if q_t1>5 & !missing(q_t1)
di as result _n "  Matriz de transición de RANGO (quintiles) — NO pandemia:"
tab q_t0 q_t1 if pandemic==0, row nofreq
di as result _n "  Matriz de transición de RANGO (quintiles) — PANDEMIA:"
tab q_t0 q_t1 if pandemic==1, row nofreq


tab q_t0 q_t1 if anio == 2018, row nofreq
tab q_t0 q_t1 if anio == 2019, row nofreq
tab q_t0 q_t1 if anio == 2020, row nofreq
tab q_t0 q_t1 if anio == 2021, row nofreq
tab q_t0 q_t1 if anio == 2022, row nofreq

******* Absoluto ******

tabstat abs_delta_pctl stay_top stay_bottom, by(pandemic) ///
    stat(mean sd n) format(%9.4f)

reg abs_delta_pctl pandemic,  vce(cluster id_bal)
estimates store b_abs1
reg abs_delta_pctl ib2018.anio, vce(cluster id_bal)
reg stay_top pandemic,  vce(cluster id_bal)
estimates store b_stop
reg stay_bottom pandemic, vce(cluster id_bal)
estimates store b_sbot

***** Solo cambios positivos *****

tabstat pos_delta_pctl, by(pandemic)
tabstat pos_delta_pctl, by(anio)

tabstat pos_delta_decil, by(anio)


* Decil

reg abs_delta_decil pandemic,  vce(cluster id_bal)
reg pos_delta_decil pandemic,  vce(cluster id_bal)


reg abs_delta_decil ib2018.anio,  vce(cluster id_bal)
reg pos_delta_decil ib2018.anio,  vce(cluster id_bal)

* Percentil

reg abs_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl pandemic,  vce(cluster id_bal)


reg abs_delta_pctl ib2018.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio,  vce(cluster id_bal)

reg pos_delta_pctl ib2019.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio,  vce(cluster id_bal)


log close

* ============================================================================
* INTERACCIONES
* ============================================================================


***** X universidad *****

log using "$dir_out/interacciones_unbalanced", replace text


reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.universidad,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.universidad,  vce(cluster id_bal)


***** X sexo *****


reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.genero,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.genero,  vce(cluster id_bal)


***** X financiamiento *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.financiamiento,  vce(cluster id_bal)

***** X financiamiento *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.financiamiento,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.financiamiento,  vce(cluster id_bal)


***** X Nivel *****

reg pos_delta_pctl pandemic,  vce(cluster id_bal)
reg pos_delta_pctl i.pandemic##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2018.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2019.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2020.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2021.anio##i.tercer_nivel,  vce(cluster id_bal)
reg pos_delta_pctl ib2022.anio##i.tercer_nivel,  vce(cluster id_bal)


log close







* ============================================================================
* C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL DEL INGRESO (BALANCEADO)
* ============================================================================

di as result _n "============================================================="
di as result    "  C. MOVILIDAD ABSOLUTA — CRECIMIENTO REAL"
di as result    "============================================================="

* --- Deflactar (merge IPC en t0 y t1) ---


gen decil_2017_tmp = decil_t1 if anio_t1 == 2017
bysort id_bal: egen decil_2017  = max(decil_2017)
drop decil_2017_tmp



drop anio
rename anio_t0 anio
merge m:1 anio using "$dir_merged/defl", keep(1 3) nogen
rename anio anio_t0
rename ipc  ipc_t0
rename anio_t1 anio
merge m:1 anio using "$dir_merged/defl", keep(1 3) nogen
rename anio anio_t1
rename ipc  ipc_t1

gen real_t0 = ingreso_t0 / (ipc_t0/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen  g_real = ingreso_t1/ingreso_t0 - 1
gen abs_up = (real_t1 > real_t0) if !missing(real_t0,real_t1)
label var g_real "Crecimiento real del ingreso (log, t0→t1)"

di as result _n "  Crecimiento real medio — pandemia vs. resto:"
tabstat g_real abs_up, by(pandemic) stat(mean sd n) format(%9.4f)

di as result _n "  [C1] g_real = a + b*pandemic        (b NO atado a 0)"
regress g_real pandemic, vce(cluster id_bal)
estimates store c_ols1

di as result _n "  [C2] g_real = a + b*pandemic + g*percentil_t0"
regress g_real pandemic percentil_t0, vce(cluster id_bal)
estimates store c_ols2

di as result _n "  [C3] g_real con FE de individuo"
capture which reghdfe
if !_rc {
    reghdfe g_real pandemic percentil_t0, absorb(id_bal) vce(cluster id_bal)
    estimates store c_fe
}
else di as error "  reghdfe no instalado; omito C3. (ssc install reghdfe)"

di as result _n "  [C4] Tasa de movilidad absoluta ascendente (ingreso creció)"
regress abs_up pandemic percentil_t0, vce(cluster id_bal)
estimates store c_up




regress g_real i.percentil_t0, vce(cluster id_bal)
regress g_real i.pandemic##i.decil_t0, vce(cluster id_bal)


regress g_real i.pandemic##i.percentil_t0, vce(cluster id_bal)
regress g_real ib.pandemic##i.percentil_t0, vce(cluster id_bal)


preserve 
regress g_real i.pandemic##i.decil_t0, vce(cluster id_bal)
restore





* ============================================================================
* TABLA RESUMEN  (todo sobre la muestra balanceada)
* ============================================================================

di as result _n "============================================================="
di as result    "  RESUMEN — MUESTRA BALANCEADA 2018–2021"
di as result    "============================================================="

di as result _n "  --- A: rango signado ---"
estimates table a_signed, keep(pandemic) b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- B: rango (|Δ| y persistencia) ---"
estimates table b_abs1 b_abs2 b_stop b_sbot, keep(pandemic) ///
    b(%9.4f) se(%9.4f) stats(N r2)

di as result _n "  --- C: absoluta (crecimiento real) ---"
estimates table c_ols1 c_ols2 c_up, keep(pandemic percentil_t0) ///
    b(%9.4f) se(%9.4f) stats(N r2)

di as text _n "  Todo sobre POBLACIÓN FIJA → sin sesgo de composición."
di as text    "  Base de comparación de la pandemia: 2018→2019 y 2020→2021."
di as text    "  A: signado ~0 (suma cero).  B: reordenamiento/persistencia."
di as text    "  C: nivel real (empobrecimiento). Reemplazar el IPC de ejemplo."
log close
s










xtset id_bal anio_t1



recode percentil (1/5 = 1) (6/10 = 2) (11/15 = 3) (16/20 = 4) ///
				   (21/25 = 5) (26/30 = 6) (31/35 = 7) (36/40 = 8) ///
				   (41/45 = 9) (46/50 = 10) (51/55 = 11) (56/60 = 12) ///
				   (61/65 = 13) (66/70 = 14) (71/75= 15) (76/80 = 16) ///
				   (81/85 = 17) (86/90 = 18) (91/95 = 19) (96/100 = 20), gen(twentil)

gen twentil_t0 = L.twentil				   
				   
log close
				   
log using "growth_descriptives_unbalanced", replace text



foreach yr of numlist 2018(1)2022 {

preserve 

keep if anio_t1 == `yr'
				   
di "******************** `yr' *******************"				   

di "ingreso_t0 > 10 - percentil"
tabstat g_real if ingreso_t0 > 10, by(percentil_t0)
			
di "ingreso_t0 > 10"
tabstat g_real if ingreso_t0 > 10, by(decil_t0)
di "ingreso_t0 >= 400"
tabstat g_real if ingreso_t0 >= 400, by(decil_t0)
di "source == 1"
tabstat g_real if source == 1, by(decil_t0)
di "source == 2"
tabstat g_real if source == 2, by(decil_t0)
di "source == 3"
tabstat g_real if source == 3, by(decil_t0)

restore

}



log close				   
				
				
gen t0_mayor_10 = ingreso_t0 > 10
gen t0_mayor_400 = ingreso_t0 > 10
gen all_f107 = inlist(source, 1, 3)
gen all_f102 = inlist(source, 2, 3)
				
gen n = 1

preserve 

collapse (mean) g_mean = g_real (median) g_median = g_real (sum) n, by(t0_mayor_10 t0_mayor_40 source all_f102 all_f107 anio_t1 decil_t0) 
export excel using "$dir_out/descriptives_g_real_decil.xlsx", firstrow(var) replace 

restore
	
preserve 

collapse (mean) g_mean = g_real (median) g_median = g_real (sum) n, by(t0_mayor_10 t0_mayor_40 source all_f102 all_f107 anio_t1 percentil_t0) 
export excel using "$dir_out/descriptives_g_real_percentil.xlsx", firstrow(var) replace 

restore
	
	
	


use `g_real_descriptives', clear				   

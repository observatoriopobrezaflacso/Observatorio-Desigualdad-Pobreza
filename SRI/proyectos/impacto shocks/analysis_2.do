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


* ============================================================================
* BALANCED
* ============================================================================


use ingreso_* anio id_bal nyears all_preyears decil_* universidad using "$data_out/working_data_balanced.dta", clear


merge m:1 anio using "$ipc/defl", nogen
drop if anio == 2017

xtset id_bal anio


gen ipc_t0 = L.ipc
gen ipc_l2 = L2.ipc
gen ipc_l3 = L3.ipc
egen ipc_t0_2 = rowmean(ipc_t0 ipc_l2 ipc_l3)
rename ipc ipc_t1

gen real_t0_1 = ingreso_t0_1 / (ipc_t0/100)
gen real_t0_2 = ingreso_t0_2 / (ipc_t0_2/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real_1 = ingreso_t1/ingreso_t0_1 - 1
gen g_real_2 = ingreso_t1/ingreso_t0_2 - 1


preserve 

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10
	
*	keep if anio == 2019 
	keep g_real_* ingreso_t0* anio decil_t0* ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1 g_real_2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10) 

	forval j = 1/2 {
			
			gen product = g_real_`j' * n
			
			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1
			
			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1
			
			gen g`j' = sumproduct/sumweigth
			drop product sumproduct sumweigth
	}
	
	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & ///
			!inlist(., g1, g2) & ///
			!inlist(., decil_t0_1, decil_t0_2) 

	sort anio decil_t0_1
	export excel using "$results/g_by_decil_balanced.xlsx", firstrow(var) replace
	
	list 

restore



* ============================================================================
* UNBALANCED
* ============================================================================


use ingreso_* anio id_bal nyears all_preyears decil_* universidad using "$data_out/working_data_unbalanced.dta", clear


merge m:1 anio using "$ipc/defl", nogen
drop if anio == 2017

xtset id_bal anio


gen ipc_t0 = L.ipc
gen ipc_l2 = L2.ipc
gen ipc_l3 = L3.ipc
egen ipc_t0_2 = rowmean(ipc_t0 ipc_l2 ipc_l3)
rename ipc ipc_t1

gen real_t0_1 = ingreso_t0_1 / (ipc_t0/100)
gen real_t0_2 = ingreso_t0_2 / (ipc_t0_2/100)
gen real_t1 = ingreso_t1 / (ipc_t1/100)
gen g_real_1 = ingreso_t1/ingreso_t0_1 - 1
gen g_real_2 = ingreso_t1/ingreso_t0_2 - 1


preserve 

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10
	
*	keep if anio == 2019 
	keep g_real_* ingreso_t0* anio decil_t0* ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1 g_real_2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10) 

	forval j = 1/2 {
			
			gen product = g_real_`j' * n
			
			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1
			
			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1
			
			gen g`j' = sumproduct/sumweigth
			drop product sumproduct sumweigth
	}
	
	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & ///
			!inlist(., g1, g2) & ///
			!inlist(., decil_t0_1, decil_t0_2) 

	sort anio decil_t0_1
	export excel using "$results/g_by_decil_unbalanced.xlsx", firstrow(var) replace
	
	list 

restore

* ============================================================================
* FILLIN (IMPUTATIONS TO ATTRITERS)
* ============================================================================


fillin id_bal anio
save "$data_out/fillin_data_unbalanced.dta", replace

drop decil_*

*use "$data_out/fillin_data_unbalanced.dta", clear

* Identify the attriters 

xtset id_bal anio
gen present = _fillin == 0
gen attrition = present == 0 if L.present == 1 


table decil_t0_1 anio, stat(mean attrition)
table decil_t0_2 anio, stat(mean attrition)


* Impute growth = 0 and = -1 for the attriters

gen g_real_1_imp1 = g_real_1 if attrition == 0 
replace g_real_1_imp1 = 0 if attrition == 1

gen g_real_2_imp1 = g_real_2 if attrition == 0 
replace g_real_2_imp1 = 0 if attrition == 1

gen g_real_1_imp2 = g_real_1 if attrition == 0 
replace g_real_1_imp2 = -1 if attrition == 1

gen g_real_2_imp2 = g_real_2 if attrition == 0 
replace g_real_2_imp2 = -1 if attrition == 1

* Regenerate deciles in t0 with the attriters

replace ingreso_t0_1 = L.ingreso_t1 if attrition == 1
xtile decil_t0_1 = ingreso_t0_1, nq(10)

replace ingreso_l2 = ingreso_l1 if attrition == 1
replace ingreso_l3 = ingreso_l2 if attrition == 1

egen a = rowmean(ingreso_t0_1 ingreso_l2 ingreso_l3) if attrition == 1
replace ingreso_t0_2 = a if attrition == 1

xtile decil_t0_2 = ingreso_t0_2, nq(10)



preserve 

	gen ing_t0_1_mayor_10 = ingreso_t0_1 > 10
	gen ing_t0_2_mayor_10 = ingreso_t0_2 > 10

	*	keep if anio == 2019 
	keep g_real_*_imp* ingreso_t0* anio decil_t0* ///
		 ing_t0_1_mayor_10 ing_t0_2_mayor_10
	gen n = 1
	collapse (mean)  g_real_1_imp1 g_real_1_imp2 g_real_2_imp1 g_real_2_imp2 ///
	(sum) n, ///
	by(decil_t0_1 decil_t0_2 anio ing_t0_1_mayor_10 ing_t0_2_mayor_10) 

	forval j = 1/2 {
		forval i = 1/2 {
			
			gen product = g_real_`j'_imp`i' * n
			
			bysort decil_t0_`j' anio: egen sumproduct = total(product) ///
			if ing_t0_`j'_mayor_10 == 1
			
			bysort decil_t0_`j' anio: egen sumweigth = total(n) ///
			if ing_t0_`j'_mayor_10 == 1
			
			gen g`j'_`i' = sumproduct/sumweigth
			drop product sumproduct sumweigth
			
		}
	}
	
	keep anio decil* g1* g2*
	keep if decil_t0_1 == decil_t0_2 & !inlist(., g1_1, g1_2, g2_1, g2_2)

	sort anio decil_t0_1
	export excel using "$results/g_imputations_by_decil.xlsx", firstrow(var) replace
	
	list 

restore











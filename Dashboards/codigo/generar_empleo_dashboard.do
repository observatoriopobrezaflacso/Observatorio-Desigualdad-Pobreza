/*==============================================================================
  generar_empleo_dashboard.do
  Genera archivos Excel de empleo para el dashboard
  Fuente: base_trabajo.dta
==============================================================================*/

clear all
set more off

* Paths
global data "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/data/Data final/empleo/empleo adecuado"

* Load data
use "$data/base_trabajo.dta", clear

* Keep only years >= 2007 and PEA (condactn 1-8: employed + unemployed)
* Note: mi_pea==1 excludes unemployed for years before 2014, so use condactn directly
keep if anio >= 2007 & condactn >= 1 & condactn <= 8

* Create indicator variables
gen empleo_adecuado = (condactn == 1) * 100
gen empleo_no_adecuado = (condactn >= 2 & condactn <= 6) * 100
gen desempleo = (condactn == 7 | condactn == 8) * 100

* Create age groups
gen grupo_edad = .
replace grupo_edad = 1 if edad >= 15 & edad <= 29
replace grupo_edad = 2 if edad >= 30 & edad <= 64
replace grupo_edad = 3 if edad >= 65 & edad <= 99

/*==============================================================================
  1. empleo_series.xlsx
==============================================================================*/

preserve

* Collapse empleo adecuado
collapse (mean) empleo_adecuado [iw=fexp], by(anio)
rename empleo_adecuado valor
gen indicador = "Empleo adecuado"
tempfile t1
save `t1'

restore
preserve

* Collapse empleo no adecuado
collapse (mean) empleo_no_adecuado [iw=fexp], by(anio)
rename empleo_no_adecuado valor
gen indicador = "Empleo no adecuado"
tempfile t2
save `t2'

restore
preserve

* Collapse desempleo
collapse (mean) desempleo [iw=fexp], by(anio)
rename desempleo valor
gen indicador = "Desempleo"
tempfile t3
save `t3'

restore

preserve
use `t1', clear
append using `t2'
append using `t3'
order anio indicador valor
sort anio indicador
export excel using "$out/empleo_series.xlsx", firstrow(variables) replace
restore

/*==============================================================================
  2. empleo_scorecard.xlsx — only most recent year
==============================================================================*/

preserve

* Find max year
summarize anio, meanonly
local maxyear = r(max)

* Collapse empleo adecuado
collapse (mean) empleo_adecuado [iw=fexp], by(anio)
keep if anio == `maxyear'
rename empleo_adecuado valor
gen indicador = "Empleo adecuado"
tempfile s1
save `s1'

restore
preserve

collapse (mean) empleo_no_adecuado [iw=fexp], by(anio)
keep if anio == `maxyear'
rename empleo_no_adecuado valor
gen indicador = "Empleo no adecuado"
tempfile s2
save `s2'

restore
preserve

collapse (mean) desempleo [iw=fexp], by(anio)
keep if anio == `maxyear'
rename desempleo valor
gen indicador = "Desempleo"
tempfile s3
save `s3'

restore

preserve
use `s1', clear
append using `s2'
append using `s3'
order anio indicador valor
sort indicador
export excel using "$out/empleo_scorecard.xlsx", firstrow(variables) replace
restore

/*==============================================================================
  3. empleo_demografico.xlsx
==============================================================================*/

* We need adec rate by year and various demographic breakdowns

* --- Area ---
preserve
keep if area == 1 | area == 2
gen adec100 = adec * 100
collapse (mean) empleo_adecuado = adec100 [iw=fexp], by(anio area)
gen tipo_categoria = "area"
gen categoria = "Urbano" if area == 1
replace categoria = "Rural" if area == 2
drop area
tempfile d_area
save `d_area'
restore

* --- Sexo ---
preserve
gen adec100 = adec * 100
collapse (mean) empleo_adecuado = adec100 [iw=fexp], by(anio sexo)
gen tipo_categoria = "sexo"
gen categoria = "Hombre" if sexo == 1
replace categoria = "Mujer" if sexo == 2
drop sexo
tempfile d_sexo
save `d_sexo'
restore

* --- Etnia ---
preserve
keep if etnia_arm >= 1 & etnia_arm <= 3
gen adec100 = adec * 100
collapse (mean) empleo_adecuado = adec100 [iw=fexp], by(anio etnia_arm)
gen tipo_categoria = "etnia"
gen categoria = "Indígena" if etnia_arm == 1
replace categoria = "Negro/Afro" if etnia_arm == 2
replace categoria = "Blanco/Mestizo" if etnia_arm == 3
drop etnia_arm
tempfile d_etnia
save `d_etnia'
restore

* --- Educacion ---
preserve
gen adec100 = adec * 100
collapse (mean) empleo_adecuado = adec100 [iw=fexp], by(anio educ_univ)
gen tipo_categoria = "educacion"
gen categoria = "No universitaria" if educ_univ == 0
replace categoria = "Universitaria" if educ_univ == 1
drop educ_univ
tempfile d_educ
save `d_educ'
restore

* --- Edad ---
preserve
keep if grupo_edad != .
gen adec100 = adec * 100
collapse (mean) empleo_adecuado = adec100 [iw=fexp], by(anio grupo_edad)
gen tipo_categoria = "edad"
gen categoria = "15-29" if grupo_edad == 1
replace categoria = "30-64" if grupo_edad == 2
replace categoria = "65+" if grupo_edad == 3
drop grupo_edad
tempfile d_edad
save `d_edad'
restore

preserve
use `d_area', clear
append using `d_sexo'
append using `d_etnia'
append using `d_educ'
append using `d_edad'
order anio tipo_categoria categoria empleo_adecuado
sort anio tipo_categoria categoria
export excel using "$out/empleo_demografico.xlsx", firstrow(variables) replace
restore

/*==============================================================================
  4. variacion_empleo_significancia.xlsx
  Year-over-year significance tests using svy: proportion + lincom
==============================================================================*/

tostring ciudad zona sector, replace
egen id_upm = concat(ciudad zona sector) if anio <= 2017
destring ciudad zona sector, replace

gen psu_str = id_upm if anio <= 2017
replace psu_str = upm if anio >= 2018
destring psu_str, gen(psu_num) force

gen strata_str = "1"
replace strata_str = plan_muestreo if inlist(anio, 2016, 2017)
replace strata_str = estrato       if anio >= 2018
encode strata_str, gen(strata_num)

gen adec01 = (condactn == 1)

tempfile empleo_sig
postfile sig_handle int(anio anioAnterior) str20(indicador) ///
    double(valor se valorAnterior seAnterior variacionPp variacionPct tStat pValue) ///
    str20(significativo) using `empleo_sig'

	

levelsof anio, local(years)
local years_list `years'
local n_years : word count `years_list'
	
forvalues i = 2/`n_years' {
    local y1 : word `i' of `years_list'
    local j = `i' - 1
    local y0 : word `j' of `years_list'

    preserve
    keep if inlist(anio, `y0', `y1')

    svyset psu_num [iw=fexp], strata(strata_num) vce(linearized) singleunit(certainty)

    qui svy: proportion adec01, over(anio)

    local val1 = _b[1.adec01@`y1'.anio] * 100
    local val0 = _b[1.adec01@`y0'.anio] * 100
    local se1  = _se[1.adec01@`y1'.anio] * 100
    local se0  = _se[1.adec01@`y0'.anio] * 100

    test _b[1.adec01@`y0'.anio] = _b[1.adec01@`y1'.anio]
    lincom _b[1.adec01@`y1'.anio] - _b[1.adec01@`y0'.anio]
    local diff = r(estimate) * 100
    local t_stat = r(estimate) / r(se)
    local p_value = r(p)
	di "`p_value'"

	
    restore

    local sig "No"
    if `p_value' < 0.05 local sig "Sí (p<0.05)"
    if `p_value' < 0.01 local sig "Sí (p<0.01)"

    local var_pct = 0
    if `val0' != 0 local var_pct = `diff' / `val0' * 100

    post sig_handle (`y1') (`y0') ("Empleo adecuado") ///
        (round(`val1', 0.0001)) (round(`se1', 0.0001)) ///
        (round(`val0', 0.0001)) (round(`se0', 0.0001)) ///
        (round(`diff', 0.0001)) (round(`var_pct', 0.0001)) ///
        (round(`t_stat', 0.0001)) (round(`p_value', 0.0001)) ///
        ("`sig'")
}


svy: reg adec01 i.anio if inlist(anio, 2023, 2024)

postclose sig_handle
use `empleo_sig', clear
export excel using "$out/variacion_empleo_significancia.xlsx", firstrow(variables) replace

di "=========================================="
di "Archivos generados exitosamente en:"
di "$out"
di "=========================================="

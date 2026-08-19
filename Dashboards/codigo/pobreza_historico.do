/*==============================================================================
  pobreza_historico.do
  Genera archivos Excel de pobreza para el dashboard
  Fuentes:
    - historico.dta                     (nacional/area/sexo/educ/edad)
    - ing_perca_*_nac_precios2000.dta   (provincia, etnia)
  Equivalente a: pobreza_historico.py
==============================================================================*/

clear all
set more off

* ── Paths ──────────────────────────────────────────────────────────────────────
global src  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza/historico.dta"
global indiv "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/con_pobreza"
global out  "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/data/Data final/pobreza"

* ══════════════════════════════════════════════════════════════════════════════
*  PART A: historico.dta  (nacional, area, sexo, educacion, edad)
* ══════════════════════════════════════════════════════════════════════════════

use "$src", clear
di "Loaded historico.dta: `=_N' obs"

drop if missing(pobreza, fexp, anio)

* pobreza is labeled numeric: 1 = Pobre, 0 = No pobre
gen pobre = (pobreza == 1) * 100
gen pobre_extremo = (ingreso_pobreza < linea_pobreza * 0.5625) * 100

* Age groups [0,18) [18,30) [30,65) [65,200)
gen grupoEtario = ""
replace grupoEtario = "Niños (0-17)"          if edad >= 0  & edad < 18
replace grupoEtario = "Jóvenes (18-29)"       if edad >= 18 & edad < 30
replace grupoEtario = "Adultos (30-64)"       if edad >= 30 & edad < 65
replace grupoEtario = "Adultos mayores (65+)" if edad >= 65 & !missing(edad)

* Decode labeled numerics to strings
decode area, gen(area_str)
drop area
rename area_str area

decode sexo, gen(sexo_str)
drop sexo
rename sexo_str sexo

decode educacion_superior, gen(educ_str)
gen nivelEducativo = ""
replace nivelEducativo = "Superior"           if educ_str == "Con educacion superior"
replace nivelEducativo = "Menos que superior" if educ_str == "Sin educacion superior"
drop educ_str

tempfile historico
save `historico'

/*==============================================================================
  1. series_historicas_indicadores.xlsx  (nacional)
==============================================================================*/

use `historico', clear
preserve
collapse (mean) pobre [iw=fexp], by(anio)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile t1
save `t1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `t1'
sort anio indicador
export excel using "$out/series_historicas_indicadores.xlsx", firstrow(variables) replace
di "  series_historicas_indicadores.xlsx: `=_N' rows"

/*==============================================================================
  2. Pobreza_tableau.xlsx  (por nivel: Nacional/Urbano/Rural)
==============================================================================*/

* By area
use `historico', clear
preserve
collapse (mean) pobre [iw=fexp], by(anio area)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile a1
save `a1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio area)
rename pobre_extremo valor
gen indicador = "Pobreza Extrema"
replace valor = round(valor, 0.0001)

append using `a1'

gen nivel = ""
replace nivel = "Urbano" if area == "urbana"
replace nivel = "Rural"  if area != "urbana"
rename anio ano
drop area
tempfile by_area
save `by_area'

* Nacional
use `historico', clear
preserve
collapse (mean) pobre [iw=fexp], by(anio)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile n1
save `n1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio)
rename pobre_extremo valor
gen indicador = "Pobreza Extrema"
replace valor = round(valor, 0.0001)

append using `n1'
gen nivel = "Nacional"
rename anio ano

append using `by_area'
sort ano nivel indicador
export excel using "$out/Pobreza_tableau.xlsx", firstrow(variables) replace
di "  Pobreza_tableau.xlsx: `=_N' rows"

/*==============================================================================
  3a. pobreza_sexo_etnia.xlsx — sex part (etnia appended in Part B)
==============================================================================*/

use `historico', clear
preserve
collapse (mean) pobre [iw=fexp], by(anio sexo)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile s1
save `s1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio sexo)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `s1'

replace sexo = proper(sexo)
rename sexo grupo
gen tipoGrupo = "sexo"
tempfile by_sexo
save `by_sexo'

/*==============================================================================
  4. pobreza_educacion.xlsx
==============================================================================*/

use `historico', clear
drop if missing(nivelEducativo) | nivelEducativo == ""

preserve
collapse (mean) pobre [iw=fexp], by(anio nivelEducativo)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile e1
save `e1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio nivelEducativo)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `e1'
sort anio nivelEducativo indicador
export excel using "$out/pobreza_educacion.xlsx", firstrow(variables) replace
di "  pobreza_educacion.xlsx: `=_N' rows"

/*==============================================================================
  5. pobreza_edad.xlsx
==============================================================================*/

use `historico', clear
drop if missing(grupoEtario) | grupoEtario == ""

preserve
collapse (mean) pobre [iw=fexp], by(anio grupoEtario)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile g1
save `g1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio grupoEtario)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `g1'
sort grupoEtario anio indicador
export excel using "$out/pobreza_edad.xlsx", firstrow(variables) replace
di "  pobreza_edad.xlsx: `=_N' rows"

/*==============================================================================
  7. variacion_pobreza_significancia.xlsx
     Uses svy: proportion with test/lincom for proper significance testing
==============================================================================*/

use `historico', clear
keep if anio >= 2007

* Create id_upm for years <= 2017
tostring ciudad zona sector, replace
egen id_upm = concat(ciudad zona sector) if anio <= 2017
destring ciudad zona sector, replace

* Unified PSU: id_upm for <=2017, upm for >=2018
gen psu_str = id_upm if anio <= 2017
replace psu_str = upm if anio >= 2018
destring psu_str, gen(psu_num) force

* Unified strata (constant "1" for years without strata design)
gen strata_str = "1"
replace strata_str = plan_muestreo if inlist(anio, 2016, 2017)
replace strata_str = estrato       if anio >= 2018
encode strata_str, gen(strata_num)

* 0/1 indicators for proportion
gen pobre01 = (pobre == 100)
gen pextr01 = (pobre_extremo == 100)

tempfile sig_base
save `sig_base'

levelsof anio, local(years)
local years_list `years'
local n_years : word count `years_list'

tempfile sig_results
postfile sig_handle int(anio anioAnterior) str20(dimension nivel indicador) ///
    double(valor se valorAnterior seAnterior variacionPp variacionPct tStat pValue) ///
    str20(significativo) using `sig_results'

forvalues i = 2/`n_years' {
    local y1 : word `i' of `years_list'
    local j = `i' - 1
    local y0 : word `j' of `years_list'

    foreach ind in "pobre01" "pextr01" {
        if "`ind'" == "pobre01" local lab "Pobreza"
        if "`ind'" == "pextr01" local lab "Pobreza extrema"

        preserve
        keep if inlist(anio, `y0', `y1')

        svyset psu_num [iw=fexp], strata(strata_num) vce(linearized) singleunit(certainty)

        qui svy: proportion `ind', over(anio)

        local val1 = _b[1.`ind'@`y1'.anio] * 100
        local val0 = _b[1.`ind'@`y0'.anio] * 100
        local se1  = _se[1.`ind'@`y1'.anio] * 100
        local se0  = _se[1.`ind'@`y0'.anio] * 100

        qui test _b[1.`ind'@`y0'.anio] = _b[1.`ind'@`y1'.anio]
        qui lincom _b[1.`ind'@`y1'.anio] - _b[1.`ind'@`y0'.anio]
        local diff = r(estimate) * 100
        local t_stat = r(estimate) / r(se)
        local p_value = r(p)

        restore

        local sig "No"
        if `p_value' < 0.05 local sig "Sí (p<0.05)"
        if `p_value' < 0.01 local sig "Sí (p<0.01)"

        local var_pct = 0
        if `val0' != 0 local var_pct = `diff' / `val0' * 100

        post sig_handle (`y1') (`y0') ("Nacional") ("Nacional") ("`lab'") ///
            (round(`val1', 0.0001)) (round(`se1', 0.0001)) ///
            (round(`val0', 0.0001)) (round(`se0', 0.0001)) ///
            (round(`diff', 0.0001)) (round(`var_pct', 0.0001)) ///
            (round(`t_stat', 0.0001)) (round(`p_value', 0.0001)) ///
            ("`sig'")
    }
}

postclose sig_handle
use `sig_results', clear
export excel using "$out/variacion_pobreza_significancia.xlsx", firstrow(variables) replace
di "  variacion_pobreza_significancia.xlsx: `=_N' rows"


* ══════════════════════════════════════════════════════════════════════════════
*  PART B: Individual year files  (provincia, etnia)
* ══════════════════════════════════════════════════════════════════════════════

di _newline "Reading individual year files..."

* Build province label dataset
clear
input int prov_code str40 provincia
1  "Azuay"
2  "Bolívar"
3  "Cañar"
4  "Carchi"
5  "Cotopaxi"
6  "Chimborazo"
7  "El Oro"
8  "Esmeraldas"
9  "Guayas"
10 "Imbabura"
11 "Loja"
12 "Los Ríos"
13 "Manabí"
14 "Morona Santiago"
15 "Napo"
16 "Pastaza"
17 "Pichincha"
18 "Tungurahua"
19 "Zamora Chinchipe"
20 "Galápagos"
21 "Sucumbíos"
22 "Orellana"
23 "Santo Domingo de los Tsáchilas"
24 "Santa Elena"
end
tempfile prov_labels
save `prov_labels'

* Loop through individual year files
local indiv_files : dir "$indiv" files "ing_perca_*_nac_precios2000.dta"

tempfile all_indiv
local first_indiv = 1

foreach f of local indiv_files {
    di "  `f'"
    qui use "$indiv/`f'", clear

    * Check if p15 exists
    cap confirm variable p15
    local has_p15 = (_rc == 0)

    * Build keep list dynamically
    local keepvars "ciudad fexp pobreza linea_pobreza ingreso_pobreza anio"
    if `has_p15' local keepvars "`keepvars' p15"
    keep `keepvars'

    drop if missing(pobreza, fexp, anio)

    * pobreza is numeric 0/1 in individual files
    gen pobre = pobreza * 100
    gen pobre_extremo = (ingreso_pobreza < linea_pobreza * 0.5625) * 100

    * Province code from ciudad
    gen prov_code = int(ciudad / 10000)

    * Ethnicity from p15
    gen etnia = ""
    if `has_p15' {
        cap destring p15, replace force
        replace etnia = "Indígena"        if p15 == 1
        replace etnia = "Afroecuatoriano" if p15 == 2 | p15 == 3 | p15 == 4
        replace etnia = "Montuvio"        if p15 == 5
        replace etnia = "Mestizo"         if p15 == 6
        replace etnia = "Blanco"          if p15 == 7
    }

    keep anio fexp pobre pobre_extremo prov_code etnia

    if `first_indiv' {
        save `all_indiv', replace
        local first_indiv = 0
    }
    else {
        append using `all_indiv'
        save `all_indiv', replace
    }
}

use `all_indiv', clear

* Merge province names
merge m:1 prov_code using `prov_labels', keep(match master) nogen

tempfile indiv_data
save `indiv_data'

/*==============================================================================
  6. pobreza_provincial.xlsx
==============================================================================*/

use `indiv_data', clear
drop if missing(provincia) | provincia == ""

preserve
collapse (mean) pobre [iw=fexp], by(anio provincia)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile p1
save `p1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio provincia)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `p1'
sort anio provincia indicador
export excel using "$out/pobreza_provincial.xlsx", firstrow(variables) replace
di "  pobreza_provincial.xlsx: `=_N' rows"

/*==============================================================================
  3b. pobreza_sexo_etnia.xlsx  (append ethnicity to sex data from Part A)
==============================================================================*/

use `indiv_data', clear
drop if missing(etnia) | etnia == ""

preserve
collapse (mean) pobre [iw=fexp], by(anio etnia)
rename pobre valor
gen indicador = "Pobreza"
replace valor = round(valor, 0.0001)
tempfile et1
save `et1'
restore

collapse (mean) pobre_extremo [iw=fexp], by(anio etnia)
rename pobre_extremo valor
gen indicador = "Pobreza extrema"
replace valor = round(valor, 0.0001)

append using `et1'
rename etnia grupo
gen tipoGrupo = "etnia"

append using `by_sexo'
sort anio tipoGrupo grupo indicador
export excel using "$out/pobreza_sexo_etnia.xlsx", firstrow(variables) replace
di "  pobreza_sexo_etnia.xlsx: `=_N' rows"


di _newline "Done."




net from http://dasp.ecn.ulaval.ca/modules/DASP_V2.3/dasp
net install dasp_p1, force
net install dasp_p2, force
net install dasp_p3, force
net install dasp_p4, force

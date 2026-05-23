/*==============================================================================
  generar_pobreza_dashboard.do
  Generates poverty disaggregation Excel files for the dashboard
  from the historico.dta microdata.

  Input:  historico.dta (individual-level, pre-processed ENEMDU)
  Output: Excel files in $out
==============================================================================*/

clear all
set more off

global data "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza"
global out  "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/data/Data final/pobreza"

use "$data/historico.dta", clear
drop if missing(pobreza)

* pobreza: 1=Pobre, 0=No pobre (numeric with value label)
gen pobre = (pobreza == 1)

* Extreme poverty: income below 56.37% of poverty line (INEC ratio)
gen pobre_extremo = (ingreso_pobreza < linea_pobreza * 0.5637) if !missing(ingreso_pobreza) & !missing(linea_pobreza)

gen grupo_etario = ""
replace grupo_etario = "Niños (0-17)"          if edad >= 0  & edad <= 17
replace grupo_etario = "Jóvenes (18-29)"       if edad >= 18 & edad <= 29
replace grupo_etario = "Adultos (30-64)"       if edad >= 30 & edad <= 64
replace grupo_etario = "Adultos mayores (65+)" if edad >= 65 & !missing(edad)

gen str10 area_str = cond(area == 1, "urbana", "rural")
gen str10 sexo_str = cond(sexo == 1, "hombre", "mujer")
gen str30 educ_str = ""
replace educ_str = "Sin educacion superior" if educacion_superior == 0
replace educ_str = "Con educacion superior" if educacion_superior == 1

gen int anio_int = int(anio)
drop anio
rename anio_int anio

tempfile master
save `master'

* ══════════════════════════════════════════════════════════════════════════════
* 1. series_historicas_indicadores.xlsx  (anio, indicador, valor)
* ══════════════════════════════════════════════════════════════════════════════
use `master', clear
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio)

tempfile base1
save `base1'

* Pobreza
use `base1', clear
gen str20 indicador = "Pobreza"
gen valor = pobre * 100
keep anio indicador valor
tempfile s1
save `s1'

* Extrema
use `base1', clear
gen str20 indicador = "Pobreza extrema"
gen valor = pobre_extremo * 100
keep anio indicador valor
append using `s1'
sort anio indicador
export excel using "$out/series_historicas_indicadores.xlsx", replace firstrow(var)

* ══════════════════════════════════════════════════════════════════════════════
* 2. Pobreza_tableau.xlsx  (Año, Indicador, Nivel, Valor)
* ══════════════════════════════════════════════════════════════════════════════

* Nacional
use `master', clear
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio)
gen str10 nivel = "Nacional"
tempfile t_nac
save `t_nac'

* Por area
use `master', clear
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio area_str)
gen str10 nivel = cond(area_str == "urbana", "Urbano", "Rural")
drop area_str
tempfile t_area
save `t_area'

* Combine and stack indicators
use `t_nac', clear
append using `t_area'
tempfile t_base
save `t_base'

* Pobreza
use `t_base', clear
rename anio Año
rename nivel Nivel
gen str20 Indicador = "Pobreza"
gen Valor = round(pobre * 100, 0.01)
keep Año Indicador Nivel Valor
tempfile t1
save `t1'

* Extrema
use `t_base', clear
rename anio Año
rename nivel Nivel
gen str20 Indicador = "Pobreza Extrema"
gen Valor = round(pobre_extremo * 100, 0.01)
keep Año Indicador Nivel Valor
append using `t1'
sort Año Indicador Nivel
export excel using "$out/Pobreza_tableau.xlsx", sheet("Data") replace firstrow(var)

* ══════════════════════════════════════════════════════════════════════════════
* 3. pobreza_sexo_etnia.xlsx  (anio, grupo, tipo_grupo, indicador, valor)
* ══════════════════════════════════════════════════════════════════════════════
use `master', clear
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio sexo_str)
gen str10 grupo = proper(sexo_str)
gen str10 tipo_grupo = "sexo"
tempfile sx_base
save `sx_base'

use `sx_base', clear
gen str20 indicador = "Pobreza"
gen valor = pobre * 100
keep anio grupo tipo_grupo indicador valor
tempfile sx1
save `sx1'

use `sx_base', clear
gen str20 indicador = "Pobreza extrema"
gen valor = pobre_extremo * 100
keep anio grupo tipo_grupo indicador valor
append using `sx1'
sort anio grupo indicador
export excel using "$out/pobreza_sexo_etnia.xlsx", replace firstrow(var)

* ══════════════════════════════════════════════════════════════════════════════
* 4. pobreza_educacion.xlsx  (anio, nivel_educativo, indicador, valor)
* ══════════════════════════════════════════════════════════════════════════════
use `master', clear
drop if educ_str == ""
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio educ_str)
gen str30 nivel_educativo = cond(educ_str == "Con educacion superior", "Superior", "Menos que superior")
tempfile ed_base
save `ed_base'

use `ed_base', clear
gen str20 indicador = "Pobreza"
gen valor = pobre * 100
keep anio nivel_educativo indicador valor
tempfile ed1
save `ed1'

use `ed_base', clear
gen str20 indicador = "Pobreza extrema"
gen valor = pobre_extremo * 100
keep anio nivel_educativo indicador valor
append using `ed1'
sort anio nivel_educativo indicador
export excel using "$out/pobreza_educacion.xlsx", replace firstrow(var)

* ══════════════════════════════════════════════════════════════════════════════
* 5. pobreza_edad.xlsx  (anio, grupo_etario, indicador, valor)
* ══════════════════════════════════════════════════════════════════════════════
use `master', clear
drop if grupo_etario == ""
collapse (mean) pobre pobre_extremo [iw=fexp], by(anio grupo_etario)
tempfile age_base
save `age_base'

use `age_base', clear
gen str20 indicador = "Pobreza"
gen valor = pobre * 100
keep anio grupo_etario indicador valor
tempfile age1
save `age1'

use `age_base', clear
gen str20 indicador = "Pobreza extrema"
gen valor = pobre_extremo * 100
keep anio grupo_etario indicador valor
append using `age1'
sort anio grupo_etario indicador
export excel using "$out/pobreza_edad.xlsx", replace firstrow(var)

di _n "Done. Output saved to: $out"

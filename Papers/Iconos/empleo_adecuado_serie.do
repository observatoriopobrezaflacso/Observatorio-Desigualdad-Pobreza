*===============================================================
* EMPLEO ADECUADO — SERIES NACIONAL Y URBANA
* Fuente: ENEMDU (INEC), base armonizada base_trabajo.dta
*
* Produce la tasa de empleo adecuado sobre ocupados de 15 años y
* más, ponderada por el factor de expansión, en dos series:
*   - Urbana   (area == 1): 1990-2025
*   - Nacional (area 1 y 2): desde 2000, cuando la ENEMDU pasa a
*     tener cobertura nacional
*===============================================================

clear all
set more off
set graphics off

*---------------------------------------------------------------
* SECCIÓN 1: RUTAS
*---------------------------------------------------------------

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global bases "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out   "$user_root/Papers/Íconos/outputs/empleo adecuado"
global out_g "$out/graficos"

cap mkdir "$user_root/Papers/Íconos/outputs"
cap mkdir "$out"
cap mkdir "$out_g"

* Años con etiqueta de valor en los gráficos (separados por coma: van dentro
* de inlist(), que no admite una lista separada por espacios)
global label_years 1991, 1995, 1999, 2001, 2006, 2014, 2020, 2025

*---------------------------------------------------------------
* SECCIÓN 2: BASE DE TRABAJO Y DENOMINADOR
*---------------------------------------------------------------

use area fexp anio adec adec_sim edad condact condactn ///
    using "$bases/base_trabajo.dta", clear

* Antes de 2000 la ENEMDU es urbana por construcción y no trae la
* variable de área: se etiquetan esos años como urbanos.
replace area = 1 if missing(area)

* Denominador: ocupados en edad de trabajar (15 años y más).
* La condición de actividad cambia de codificación en 2007:
*   hasta 2006  condact  5-8      = desocupados/inactivos/menores
*   desde 2007  condactn 0,7,8,9  = menores/desocupados/inactivos
keep if edad >= 15

foreach var of varlist adec adec_sim {
    replace `var' = . if inrange(condact, 5, 8)        & anio <= 2006
    replace `var' = . if inlist(condactn, 0, 7, 8, 9)  & anio >= 2007
}

drop if missing(adec)

* 2002 no tiene ENEMDU comparable en la serie armonizada
drop if anio == 2002

tab anio area

*---------------------------------------------------------------
* SECCIÓN 3: SERIES NACIONAL Y URBANA
*---------------------------------------------------------------

gen byte uno = 1

* --- Serie urbana (1990-2025) ---
preserve
    keep if area == 1
    collapse (mean) adec (rawsum) N = uno [iw = fexp], by(anio)
    rename adec adec_urb
    rename N    N_urb
    tempfile urb
    save `urb'
restore

* --- Serie nacional (desde 2000; antes la muestra es solo urbana) ---
preserve
    keep if anio >= 2000
    collapse (mean) adec (rawsum) N = uno [iw = fexp], by(anio)
    rename adec adec_nac
    rename N    N_nac
    tempfile nac
    save `nac'
restore

use `urb', clear
merge 1:1 anio using `nac', nogen
sort anio

* Intervalos de confianza al 95% (proporción binomial, n sin ponderar).
* El truncamiento a [0,1] se hace con replace y no con min()/max(): estas
* funciones ignoran los missing, de modo que min(., 1) devuelve 1 y los años
* sin serie nacional (1991-1999) quedarían con un IC espurio de 0 a 100.
foreach s in urb nac {
    gen se_`s' = sqrt((adec_`s' * (1 - adec_`s')) / N_`s')
    gen ub_`s' = adec_`s' + 1.96 * se_`s'
    gen lb_`s' = adec_`s' - 1.96 * se_`s'
    replace ub_`s' = 1 if ub_`s' > 1 & !missing(ub_`s')
    replace lb_`s' = 0 if lb_`s' < 0
}

* Escala a porcentajes
foreach v of varlist adec_urb adec_nac se_urb se_nac ub_urb ub_nac lb_urb lb_nac {
    replace `v' = `v' * 100
}

label var anio     "Año"
label var adec_urb "Empleo adecuado, urbano (%)"
label var adec_nac "Empleo adecuado, nacional (%)"
label var N_urb    "Observaciones, urbano"
label var N_nac    "Observaciones, nacional"

format adec_urb adec_nac se_urb se_nac ub_urb ub_nac lb_urb lb_nac %9.2f

list anio adec_nac adec_urb N_nac N_urb, sep(0) noobs

export excel anio adec_nac lb_nac ub_nac N_nac adec_urb lb_urb ub_urb N_urb ///
    using "$out/empleo_adecuado_serie.xlsx", firstrow(varlabels) replace
save "$out/empleo_adecuado_serie.dta", replace

*---------------------------------------------------------------
* SECCIÓN 4: GRÁFICO
*---------------------------------------------------------------

gen lbl_nac = adec_nac if inlist(anio, $label_years)
gen lbl_urb = adec_urb if inlist(anio, $label_years)
format lbl_nac lbl_urb %9.1f

twoway ///
    (rarea ub_urb lb_urb anio, sort color(maroon%30)) ///
    (connected adec_urb anio, sort msymbol(O) msize(small) lcolor(maroon) mcolor(maroon) lwidth(medium)) ///
    (rarea ub_nac lb_nac anio, sort color(navy%30)) ///
    (connected adec_nac anio, sort msymbol(O) msize(small) lcolor(navy) mcolor(navy) lwidth(medium)) ///
    (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)) ///
    (scatter lbl_urb anio, msymbol(none) mlabel(lbl_urb) mlabposition(12) mlabcolor(maroon) mlabsize(vsmall)) ///
    (scatter lbl_nac anio, msymbol(none) mlabel(lbl_nac) mlabposition(6)  mlabcolor(navy)   mlabsize(vsmall)), ///
    legend(order(2 "Urbano" 4 "Nacional") position(6) rows(1) size(small)) ///
    ytitle("Empleo adecuado (% de ocupados)") xtitle("") ///
    ylabel(0(10)70, angle(0) grid format(%9.0f) labsize(small)) ///
    yscale(range(0 70)) ///
    xlabel(1990(2)2025, angle(90) labsize(small)) ///
    xscale(range(1990 2025)) ///
    note("Fuente: ENEMDU (INEC). Elaboración propia." ///
         "Ocupados de 15 años y más, ponderado por el factor de expansión." ///
         "La cobertura nacional inicia en 2000; antes la muestra es urbana.") ///
    graphregion(color(white)) plotregion(color(white)) scheme(s2color) ///
    name(empleo_adecuado_serie, replace)

graph export "$out_g/empleo_adecuado_serie.pdf", replace
graph save   "$out_g/empleo_adecuado_serie.gph", replace

* En modo batch la consola de Stata no trae el traductor a png: se obtiene
* el png a partir del pdf (mismo recurso usado en empleo_pleno_rama.do)
cap graph export "$out_g/empleo_adecuado_serie.png", replace width(2200)
if _rc shell sips -s format png --resampleWidth 2200 ///
    "$out_g/empleo_adecuado_serie.pdf" ///
    --out "$out_g/empleo_adecuado_serie.png" > /dev/null 2>&1

display "Series exportadas a: $out"

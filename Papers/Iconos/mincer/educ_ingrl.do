*==============================================================================
* Retorno a la educación universitaria (o más) sobre el ingreso laboral (ingrl)
* Base: ENEMDU armonizada - base_trabajo.dta
* Salidas: tabla (per-year + pooled) y gráfico de coeficientes
*==============================================================================

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off

local base "$gd/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago/base_trabajo.dta"
local root "$gd/Papers/Íconos"
local out  "`root'/outputs/educ_ingrl"
cap mkdir "`root'/outputs"
cap mkdir "`out'"

use "`base'", clear

*------------------------------------------------------------------ muestra ---
* condactn (condición de actividad armonizada) sólo existe desde 2007;
* ingrl no está disponible en 2009.
keep if inrange(anio,2007,2025)
gen byte ocupado = inlist(condactn,1,2,3,4,5,6)

keep if ocupado==1
keep if inrange(edad,15,65)
keep if inlist(area,1,2)
keep if ingrl>0 & !missing(ingrl)
keep if !missing(educ_univ)
drop if missing(fexp)

gen double lningrl = ln(ingrl)
label var lningrl "ln(ingreso laboral)"

* etnia: categoría explícita para no perder observaciones
gen byte etnia = etnia_arm
replace etnia = 9 if missing(etnia_arm)

recode sexo (.=9)
gen double edad2 = edad^2

label define educ2 0 "Hasta secundaria" 1 "Universitaria o más", replace
label values educ_univ educ2

tab anio educ_univ, row

*----------------------------------------------------- regresiones por año ---
tempname pf
tempfile res
postfile `pf' int anio double(b_raw se_raw b_adj se_adj b_lvl se_lvl ///
        mean_no mean_si N r2_raw r2_adj) using "`res'", replace

levelsof anio, local(anios)
foreach y of local anios {

    * (1) sin controles, log
    qui reg lningrl i.educ_univ [pw=fexp] if anio==`y', vce(robust)
    local b_raw  = _b[1.educ_univ]
    local se_raw = _se[1.educ_univ]
    local r2_raw = e(r2)
    local N      = e(N)

    * (2) con controles, log
    qui reg lningrl i.educ_univ i.sexo c.edad c.edad2 i.area i.etnia ///
        [pw=fexp] if anio==`y', vce(robust)
    local b_adj  = _b[1.educ_univ]
    local se_adj = _se[1.educ_univ]
    local r2_adj = e(r2)

    * (3) sin controles, niveles (USD corrientes)
    qui reg ingrl i.educ_univ [pw=fexp] if anio==`y', vce(robust)
    local b_lvl  = _b[1.educ_univ]
    local se_lvl = _se[1.educ_univ]

    * medias del ingreso por grupo (ponderadas)
    qui sum ingrl [aw=fexp] if anio==`y' & educ_univ==0
    local m0 = r(mean)
    qui sum ingrl [aw=fexp] if anio==`y' & educ_univ==1
    local m1 = r(mean)

    post `pf' (`y') (`b_raw') (`se_raw') (`b_adj') (`se_adj') (`b_lvl') ///
        (`se_lvl') (`m0') (`m1') (`N') (`r2_raw') (`r2_adj')
}
postclose `pf'

*--------------------------------------------------- modelos agrupados (pool) -
eststo clear
eststo m1: qui reg lningrl i.educ_univ [pw=fexp], vce(cluster anio)
eststo m2: qui reg lningrl i.educ_univ i.anio [pw=fexp], vce(cluster anio)
eststo m3: qui reg lningrl i.educ_univ i.sexo c.edad c.edad2 i.area i.etnia ///
        i.anio [pw=fexp], vce(cluster anio)
eststo m4: qui reg lningrl i.educ_univ i.sexo c.edad c.edad2 i.area i.etnia ///
        i.anio i.rama1 [pw=fexp], vce(cluster anio)

esttab m1 m2 m3 m4 using "`out'/tabla_pooled_educ_ingrl.rtf", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observaciones" "R2")) ///
    mtitles("(1) Simple" "(2) + año" "(3) + demog." "(4) + rama") ///
    varlabels(1.educ_univ "Universitaria o más") ///
    title("Efecto de la educación universitaria o más sobre ln(ingreso laboral), ENEMDU 2007-2025") ///
    addnotes("MCO ponderado por fexp. EE agrupados por año. Ocupados 15-65 con ingreso laboral positivo.")

esttab m1 m2 m3 m4 using "`out'/tabla_pooled_educ_ingrl.csv", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0f %9.3f) labels("Observaciones" "R2")) ///
    mtitles("Simple" "MasAnio" "MasDemog" "MasRama") ///
    varlabels(1.educ_univ "Universitaria o mas") plain

esttab m1 m2 m3 m4, keep(1.educ_univ) b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(%12.0fc %9.3f))

*--------------------------------------------------------- tabla por año -----
use "`res'", clear

foreach v in raw adj lvl {
    gen double lo_`v' = b_`v' - 1.96*se_`v'
    gen double hi_`v' = b_`v' + 1.96*se_`v'
    gen double t_`v'  = b_`v'/se_`v'
    gen double p_`v'  = 2*ttail(N-2, abs(t_`v'))
}
* efecto porcentual exacto de una dummy en log: exp(b)-1
gen double pct_raw = 100*(exp(b_raw)-1)
gen double pct_adj = 100*(exp(b_adj)-1)
gen double ratio   = mean_si/mean_no

label var b_raw   "Coef. ln(ingrl), sin controles"
label var b_adj   "Coef. ln(ingrl), con controles"
label var b_lvl   "Coef. ingrl en USD corrientes"
label var pct_raw "Brecha % (sin controles)"
label var pct_adj "Brecha % (con controles)"
label var mean_no "Ingreso medio: hasta secundaria"
label var mean_si "Ingreso medio: universitaria o más"

format b_* se_* lo_* hi_* %6.3f
format pct_* mean_* b_lvl se_lvl %8.1f
format p_* %6.4f

list anio b_raw se_raw pct_raw b_adj se_adj pct_adj N, sepby(anio) noobs
save "`out'/coef_educ_ingrl.dta", replace
export delimited using "`out'/coef_educ_ingrl.csv", replace

*----------------------------------------------------------------- gráfico ---
gen anio_adj = anio + 0.15

twoway ///
  (connected b_raw anio, lcolor(navy) mcolor(navy) msymbol(O) msize(small)) ///
  (connected b_adj anio, lcolor(cranberry) mcolor(cranberry) msymbol(S) ///
        msize(small) lpattern(dash)) ///
  , ///
  yline(0, lcolor(gs8) lpattern(solid) lwidth(thin)) ///
  ylabel(0(.2)1.2, angle(0) format(%3.1f) grid glcolor(gs14)) ///
  xlabel(2007(2)2025, angle(45)) ///
  ytitle("Coeficiente sobre ln(ingreso laboral)") ///
  xtitle("Año") ///
  title("Prima salarial de la educación universitaria o más", size(medium)) ///
  subtitle("Ecuador, ENEMDU 2007-2025 (sin datos de ingreso en 2009)", size(small)) ///
  legend(order(1 "Sin controles" 2 "Con controles") rows(1) ///
        size(small) region(lstyle(none))) ///
  note("MCO por año, ponderado por fexp, EE robustos. Muestra: ocupados de 15 a 65 años con ingreso laboral positivo." ///
       "Controles: sexo, edad, edad², área y etnia.", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color)

* Nota: Stata en modo batch (-b) en Mac no tiene el traductor Graph2png,
* así que se exporta PDF/EPS/GPH. El PNG se genera convirtiendo el PDF:
*   sips -s format png --resampleWidth 2400 fig_educ_ingrl.pdf --out fig_educ_ingrl.png
graph export "`out'/fig_educ_ingrl.pdf", replace
graph export "`out'/fig_educ_ingrl.eps", replace
graph save   "`out'/fig_educ_ingrl.gph", replace
cap graph export "`out'/fig_educ_ingrl.png", replace width(2400)

di "Listo. Salidas en: `out'"

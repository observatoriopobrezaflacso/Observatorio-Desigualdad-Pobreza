clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off
local out "$gd/Papers/Íconos/outputs/educ_ingrl"

use "`out'/coef_educ_ingrl.dta", clear

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
       "Controles: sexo, edad, edad2, área y etnia.", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) ///
  name(fig1, replace)

graph export "`out'/fig_educ_ingrl.pdf", replace
graph export "`out'/fig_educ_ingrl.eps", replace
graph save "`out'/fig_educ_ingrl.gph", replace
di "OK"

*==============================================================================*
* GRÁFICOS de la prima por hora (lee hora_coef_educ_ingrl.dta)
* Permite reestilizar sin volver a leer las bases.
*==============================================================================*
clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off
local out "$gd/Papers/Íconos/outputs/educ_ingrl"
use "`out'/hora_coef_educ_ingrl.dta", clear

*==============================================================================*
* 5. GRÁFICOS (sin intervalos de confianza)
*==============================================================================*

local nota  "MCO por año sobre ln(ingreso laboral real por hora). Ponderado por fexp. Controles: edad y edad{sup:2}."
local nota2 "Horas = suma de horas semanales de todos los trabajos (principal + secundario + otros)."
local nota3 "Muestra: perceptores de ingreso laboral con horas > 0, sin restricción de edad."
local nota4 "1990 y 2002 no tienen base: se usan 1991 y 2003."

local xlab "xlabel(1991 1993 1996 1999 2003 2005 2008 2011 2014 2017 2021 2025, angle(45) labsize(small))"

* --- 5.1 Urbano ---
twoway ///
  (connected b_adj anio if ambito==2 & grupo==0, lcolor(black) mcolor(black) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==2 & grupo==1, lcolor(navy) mcolor(navy) msymbol(T) msize(small) lpattern(dash)) ///
  (connected b_adj anio if ambito==2 & grupo==2, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(shortdash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) `xlab' ///
  ytitle("Coeficiente sobre ln(ingreso por hora)") xtitle("Año") ///
  title("Prima salarial por hora de la educación universitaria o más", size(medium)) ///
  subtitle("Ecuador urbano, ENEMDU 1991-2025", size(small)) ///
  legend(order(1 "Total" 2 "Hombres" 3 "Mujeres") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'" "`nota4'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(urb, replace)
graph export "`out'/fig_hora_urbano.pdf", replace
graph export "`out'/fig_hora_urbano.eps", replace
graph save   "`out'/fig_hora_urbano.gph", replace

* --- 5.2 Nacional ---
twoway ///
  (connected b_adj anio if ambito==1 & grupo==0, lcolor(black) mcolor(black) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==1 & grupo==1, lcolor(navy) mcolor(navy) msymbol(T) msize(small) lpattern(dash)) ///
  (connected b_adj anio if ambito==1 & grupo==2, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(shortdash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) ///
  xlabel(2001 2003 2005 2008 2011 2014 2017 2021 2025, angle(45) labsize(small)) ///
  ytitle("Coeficiente sobre ln(ingreso por hora)") xtitle("Año") ///
  title("Prima salarial por hora de la educación universitaria o más", size(medium)) ///
  subtitle("Ecuador nacional, ENEMDU 2001-2025", size(small)) ///
  legend(order(1 "Total" 2 "Hombres" 3 "Mujeres") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'" "`nota4'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(nac, replace)
graph export "`out'/fig_hora_nacional.pdf", replace
graph export "`out'/fig_hora_nacional.eps", replace
graph save   "`out'/fig_hora_nacional.gph", replace

* --- 5.3 Urbano vs nacional (total) ---
twoway ///
  (connected b_adj anio if ambito==2 & grupo==0, lcolor(navy) mcolor(navy) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==1 & grupo==0, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(dash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) `xlab' ///
  ytitle("Coeficiente sobre ln(ingreso por hora)") xtitle("Año") ///
  title("Prima salarial por hora: urbano vs. nacional", size(medium)) ///
  subtitle("Ecuador, ENEMDU 1991-2025", size(small)) ///
  legend(order(1 "Urbano" 2 "Nacional") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'" "`nota4'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(comp, replace)
graph export "`out'/fig_hora_urb_vs_nac.pdf", replace
graph export "`out'/fig_hora_urb_vs_nac.eps", replace
graph save   "`out'/fig_hora_urb_vs_nac.gph", replace

* Los PNG se generan convirtiendo los PDF (Stata batch en Mac no trae Graph2png):
*   sips -s format png --resampleWidth 2400 fig.pdf --out fig.png

di as res "Listo. Salidas en: `out'"

clear all
set more off

* =============================================================================
* Gráfico: Tasa de homicidios de NNA por cada 100.000, por etnia en Ecuador
* Fuente: Ministerio del Interior (datos abiertos), INEC (proyecciones)
* =============================================================================

global root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Boletín 3/3. homicidios_nna"
global out  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 3/4. Resultados/homicidios infantiles"

* --- Cargar datos ---
import delimited using "$root/datos_homicidios_nna.csv", clear

* --- Etiquetas ---
label variable anio       "Año"
label variable tasa_afro  "Afroecuatoriana"
label variable tasa_otras "Otras etnias"
label variable tasa_total "Total"

* =============================================================================
* Gráfico: Tasa de homicidios de NNA por cada 100.000, por etnia en Ecuador
* =============================================================================

import delimited using "$root/datos_homicidios_nna.csv", clear

label variable anio       "Año"
label variable tasa_afro  "Afroecuatoriana"
label variable tasa_otras "Otras etnias"
label variable tasa_total "Total"

* --- Etiquetas de valor (mismos años que gráficos de informalidad) ---
gen lbl_afro  = tasa_afro  if inlist(anio, 2001, 2006, 2014, 2019, 2025)
gen lbl_total = tasa_total if inlist(anio, 2001, 2006, 2014, 2019, 2025)
format lbl_afro lbl_total %9.1f

twoway ///
    (connected tasa_afro  anio, ///
        lcolor("227 66 52")  mcolor("227 66 52")  lwidth(medthick) msymbol(circle)   msize(small) lpattern(solid)) ///
    (connected tasa_otras anio, ///
        lcolor("46 134 171") mcolor("46 134 171") lwidth(medthick) msymbol(triangle) msize(small) lpattern(solid)) ///
    (connected tasa_total anio, ///
        lcolor("80 80 80")   mcolor("80 80 80")   lwidth(medthick) msymbol(square)   msize(small) lpattern(solid)) ///
    (scatter lbl_afro  anio, msymbol(none) mlabel(lbl_afro)  mlabposition(12) mlabcolor("227 66 52") mlabsize(vsmall)) ///
    (scatter lbl_total anio, msymbol(none) mlabel(lbl_total) mlabposition(6)  mlabcolor("80 80 80")   mlabsize(vsmall)) ///
    , ///
    title("Tasa de homicidios de niños, niñas y adolescentes (NNA)" ///
          "por cada 100.000, por etnia en Ecuador", size(medium)) ///
    subtitle("2014 – 2025", size(small)) ///
    ytitle("Tasa por 100.000") ///
    xtitle("") ///
    xlabel(2014(1)2025, angle(45) labsize(small)) ///
    ylabel(0(2)16, labsize(small) grid glcolor(gs14)) ///
    legend(order(1 "Afroecuatoriana" 2 "Otras etnias" 3 "Total") ///
           rows(1) size(small) position(6)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    note("Fuente: Ministerio del Interior (datos abiertos – homicidios intencionales), INEC (proyecciones de población)." ///
         "Elaborado por: Andrés Mideros-Mora", size(vsmall))

graph export "$out/tasa_homicidios_nna_etnia.pdf", replace
graph export "$out/tasa_homicidios_nna_etnia.eps", replace

di "Gráfico NNA exportado exitosamente."

* =============================================================================
* Gráfico: Tasa de homicidios de jóvenes por cada 100.000, por etnia en Ecuador
* =============================================================================

import delimited using "$root/datos_homicidios_jovenes.csv", clear

label variable anio       "Año"
label variable tasa_afro  "Afroecuatoriana"
label variable tasa_otras "Otras etnias"
label variable tasa_total "Total"

* --- Etiquetas de valor (mismos años que gráficos de informalidad) ---
gen lbl_afro  = tasa_afro  if inlist(anio, 2001, 2006, 2014, 2020, 2025)
gen lbl_total = tasa_total if inlist(anio, 2001, 2006, 2014, 2020, 2025)
format lbl_afro lbl_total %9.1f

twoway ///
    (connected tasa_afro  anio, ///
        lcolor("227 66 52")  mcolor("227 66 52")  lwidth(medthick) msymbol(circle)   msize(small) lpattern(solid)) ///
    (connected tasa_otras anio, ///
        lcolor("46 134 171") mcolor("46 134 171") lwidth(medthick) msymbol(triangle) msize(small) lpattern(solid)) ///
    (connected tasa_total anio, ///
        lcolor("80 80 80")   mcolor("80 80 80")   lwidth(medthick) msymbol(square)   msize(small) lpattern(solid)) ///
    (scatter lbl_afro  anio, msymbol(none) mlabel(lbl_afro)  mlabposition(12) mlabcolor("227 66 52") mlabsize(vsmall)) ///
    (scatter lbl_total anio, msymbol(none) mlabel(lbl_total) mlabposition(6)  mlabcolor("80 80 80")   mlabsize(vsmall)) ///
    , ///
    title("Tasa de homicidios de jóvenes" ///
          "por cada 100.000, por etnia en Ecuador", size(medium)) ///
    subtitle("2014 – 2025", size(small)) ///
    ytitle("Tasa por 100.000") ///
    xtitle("") ///
    xlabel(2014(1)2025, angle(45) labsize(small)) ///
    ylabel(0(20)200, labsize(small) grid glcolor(gs14)) ///
    legend(order(1 "Afroecuatoriana" 2 "Otras etnias" 3 "Total") ///
           rows(1) size(small) position(6)) ///
    graphregion(color(white)) plotregion(color(white))

graph export "$out/tasa_homicidios_jovenes_etnia.pdf", replace
graph export "$out/tasa_homicidios_jovenes_etnia.eps", replace

di "Gráfico jóvenes exportado exitosamente."

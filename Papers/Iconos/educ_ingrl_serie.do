*==============================================================================*
* PRIMA SALARIAL DE LA EDUCACIÓN UNIVERSITARIA O MÁS
* Series largas por ámbito (Urbano 1991-2025 / Nacional 2001-2025) y por sexo
*
* Fuente: ENEMDU procesada, bases de ingresos per cápita a precios constantes
*         .../ENEMDU/Procesadas/ingresos_pc/{Urbano,Nacional}
* Educación: armonización replicada de
*         .../Boletín 3/1. Infomalidad/2. Armonización de variables/main/
*           desagregaciones/armonizacion_educacion.do
*==============================================================================*

clear all
set more off

local urb  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/Urbano"
local nac  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
local root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Íconos"
local out  "`root'/outputs/educ_ingrl"
cap mkdir "`root'/outputs"
cap mkdir "`out'"

*==============================================================================*
* 1. ARMADO DEL PANEL ARMONIZADO
*==============================================================================*

tempfile acum
clear
set obs 0
gen byte ambito = .
save `acum', emptyok replace

foreach amb of numlist 1 2 {

    if (`amb' == 1) {
        local dir "`nac'"
        local pat "nac"
    }
    else {
        local dir "`urb'"
        local pat "urb"
    }

    local files : dir "`dir'" files "ing_perca_*_`pat'_precios2000.dta"
    local files : list sort files

    foreach f of local files {

        local y = real(substr("`f'", 11, 4))

        qui describe using "`dir'/`f'", varlist
        local vl = r(varlist)

        * nombres de variables según el formulario del año
        local hasp10a : list posof "p10a" in vl
        local hasp02  : list posof "p02"  in vl
        local hasarea : list posof "area" in vl

        if (`hasp10a') local educvar p10a
        else           local educvar nivinst
        if (`hasp02')  local sexvar p02
        else           local sexvar sexo
        if (`hasp02')  local edadvar p03
        else           local edadvar edad
        local areavar
        if (`hasarea') local areavar area

        qui use `educvar' `sexvar' `edadvar' ing_lab_deflated fexp `areavar' ///
            using "`dir'/`f'", clear

        *----------------------------------------------------------------------
        * Armonización de educación universitaria (idéntica a
        * armonizacion_educacion.do): educ_univ = 1 si superior universitaria
        * o postgrado. Las categorías de nivinst cambian de año a año.
        *----------------------------------------------------------------------
        gen byte educ_univ = 0

        * 1990-2000: nivinst 5 categorías -> 5 = superior
        if (inrange(`y', 1990, 2000)) {
            replace educ_univ = 1 if nivinst == 5
        }
        * 2001: 7 categorías -> 6 superior, 7 postgrado
        if (`y' == 2001) {
            replace educ_univ = 1 if inlist(nivinst, 6, 7)
        }
        * 2002: 8 categorías -> 7 superior universitaria, 8 postgrado
        if (`y' == 2002) {
            replace educ_univ = 1 if inlist(nivinst, 7, 8)
        }
        * 2003-2006: 10 categorías -> 9 superior universitaria, 10 postgrado
        if (inrange(`y', 2003, 2006)) {
            replace educ_univ = 1 if inlist(nivinst, 9, 10)
        }
        * 2007+: p10a -> 9 superior universitario, 10 postgrado
        if (`y' >= 2007) {
            replace educ_univ = 1 if inlist(p10a, 9, 10)
        }
        replace educ_univ = . if missing(`educvar')

        * homogeneizar nombres
        rename `sexvar'  sexo_h
        rename `edadvar' edad_h
        gen int  anio   = `y'
        gen byte ambito = `amb'
        if ("`areavar'" == "") gen byte area = 1

        keep ambito anio educ_univ sexo_h edad_h area ing_lab_deflated fexp
        destring area, replace force

        * ámbito: nacional = urbano + rural; urbano = solo área 1
        if (`amb' == 1) keep if inlist(area, 1, 2)
        if (`amb' == 2) keep if area == 1

        append using `acum'
        save `acum', replace
        di as txt "procesado: `pat' `y'"
    }
}

use `acum', clear
rename sexo_h sexo
rename edad_h edad
rename ing_lab_deflated ingrl_real
label var ingrl_real "Ingreso laboral real (precios constantes 2000)"

label define lbl_amb 1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb
label define lbl_sexo 1 "Hombre" 2 "Mujer", replace
label values sexo lbl_sexo
label define lbl_educ2 0 "Hasta secundaria" 1 "Universitaria o más", replace
label values educ_univ lbl_educ2

*------------------------------------------------------------------ muestra ---
keep if inrange(edad, 15, 65)
keep if ingrl_real > 0 & !missing(ingrl_real)
keep if !missing(educ_univ)
keep if inlist(sexo, 1, 2)
keep if !missing(fexp) & fexp > 0

*------------------------------------------------------- pre-dolarización -----
* En los años previos a la dolarización el ingreso deflactado de estas bases
* está expresado en SUCRES de precios constantes (medias del orden de 2,4
* millones), mientras que desde 2000 está en dólares. Se convierte al tipo de
* cambio de fijación de enero de 2000 (25.000 sucres/USD) para que los NIVELES
* sean comparables en el tiempo.
* Ojo: esto no altera los coeficientes por año — un factor de escala común
* dentro de un año se cancela en la diferencia de logaritmos.
replace ingrl_real = ingrl_real/25000 if anio <= 1999

gen double lningrl = ln(ingrl_real)
gen double edad2   = edad^2

di as res "=== observaciones por ámbito y año ==="
table anio ambito, c(freq)
di as res "=== % universitaria (ponderado) ==="
table anio ambito [aw=fexp], c(mean educ_univ) format(%5.3f)

compress
save "`out'/microdatos_serie.dta", replace

*==============================================================================*
* 2. REGRESIONES POR ÁMBITO x SEXO x AÑO
*    grupo: 0 = Total, 1 = Hombres, 2 = Mujeres
*==============================================================================*

tempname pf
tempfile res
postfile `pf' byte ambito byte grupo int anio ///
    double(b_raw se_raw b_adj se_adj N share_univ mean_no mean_si) using "`res'", replace

foreach amb of numlist 1 2 {
    levelsof anio if ambito==`amb', local(anios)
    foreach y of local anios {
        foreach g of numlist 0 1 2 {

            if (`g' == 0) local cond "ambito==`amb' & anio==`y'"
            else          local cond "ambito==`amb' & anio==`y' & sexo==`g'"

            * controles: sexo sólo en el total; área sólo en el nacional
            local ctrl "c.edad c.edad2"
            if (`g' == 0)   local ctrl "i.sexo `ctrl'"
            if (`amb' == 1) local ctrl "`ctrl' i.area"

            qui count if `cond'
            if (r(N) < 100) continue

            qui reg lningrl i.educ_univ [pw=fexp] if `cond', vce(robust)
            local b_raw  = _b[1.educ_univ]
            local se_raw = _se[1.educ_univ]
            local N      = e(N)

            qui reg lningrl i.educ_univ `ctrl' [pw=fexp] if `cond', vce(robust)
            local b_adj  = _b[1.educ_univ]
            local se_adj = _se[1.educ_univ]

            qui sum educ_univ [aw=fexp] if `cond'
            local sh = r(mean)
            qui sum ingrl_real [aw=fexp] if `cond' & educ_univ==0
            local m0 = r(mean)
            qui sum ingrl_real [aw=fexp] if `cond' & educ_univ==1
            local m1 = r(mean)

            post `pf' (`amb') (`g') (`y') (`b_raw') (`se_raw') (`b_adj') ///
                (`se_adj') (`N') (`sh') (`m0') (`m1')
        }
    }
}
postclose `pf'

*==============================================================================*
* 3. MODELOS AGRUPADOS (una columna por ámbito x sexo)
*==============================================================================*

eststo clear
local i = 0
foreach amb of numlist 2 1 {
    foreach g of numlist 0 1 2 {
        local ++i
        if (`g' == 0) local cond "ambito==`amb'"
        else          local cond "ambito==`amb' & sexo==`g'"
        local ctrl "c.edad c.edad2 i.anio"
        if (`g' == 0)   local ctrl "i.sexo `ctrl'"
        if (`amb' == 1) local ctrl "`ctrl' i.area"
        eststo m`i': qui reg lningrl i.educ_univ `ctrl' [pw=fexp] if `cond', vce(cluster anio)
    }
}

esttab m1 m2 m3 m4 m5 m6 using "`out'/serie_tabla_pooled.rtf", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observaciones" "R2")) ///
    mtitles("Urb Total" "Urb Hombres" "Urb Mujeres" "Nac Total" "Nac Hombres" "Nac Mujeres") ///
    varlabels(1.educ_univ "Universitaria o más") ///
    title("Prima salarial de la educación universitaria o más sobre ln(ingreso laboral real)") ///
    addnotes("MCO ponderado por fexp, EE agrupados por año. Controles: edad, edad2, año (y sexo en el total; área en el nacional).")

esttab m1 m2 m3 m4 m5 m6 using "`out'/serie_tabla_pooled.csv", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0f %9.3f) labels("Observaciones" "R2")) ///
    mtitles("UrbTotal" "UrbHombres" "UrbMujeres" "NacTotal" "NacHombres" "NacMujeres") ///
    varlabels(1.educ_univ "Universitaria o mas") plain

esttab m1 m2 m3 m4 m5 m6, keep(1.educ_univ) b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) stats(N r2, fmt(%12.0fc %9.3f)) ///
    mtitles("UrbTot" "UrbH" "UrbM" "NacTot" "NacH" "NacM")

*==============================================================================*
* 4. TABLA POR AÑO
*==============================================================================*

use "`res'", clear

label define lbl_amb 1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb
label define lbl_grupo 0 "Total" 1 "Hombres" 2 "Mujeres", replace
label values grupo lbl_grupo

gen double pct_raw = 100*(exp(b_raw)-1)
gen double pct_adj = 100*(exp(b_adj)-1)
gen double t_adj   = b_adj/se_adj
gen double p_adj   = 2*normal(-abs(t_adj))

label var b_raw      "Coef. sin controles"
label var b_adj      "Coef. con controles"
label var pct_raw    "Brecha % sin controles"
label var pct_adj    "Brecha % con controles"
label var share_univ "Proporción universitaria o más"
label var mean_no    "Ingreso real medio: hasta secundaria"
label var mean_si    "Ingreso real medio: universitaria o más"

format b_* se_* %6.3f
format pct_* mean_* %8.1f
format share_univ %5.3f

sort ambito grupo anio
list ambito grupo anio b_raw b_adj pct_adj N if ambito==2, sepby(grupo) noobs
list ambito grupo anio b_raw b_adj pct_adj N if ambito==1, sepby(grupo) noobs

save "`out'/serie_coef_educ_ingrl.dta", replace
export delimited using "`out'/serie_coef_educ_ingrl.csv", replace

*==============================================================================*
* 5. GRÁFICOS (sin intervalos de confianza)
*==============================================================================*

local nota  "MCO por año sobre ln(ingreso laboral real). Ponderado por fexp."
local nota2 "Muestra: perceptores de ingreso laboral de 15 a 65 años. Controles: edad, edad{sup:2} (y área en el nacional)."
local nota3 "Educación armonizada según armonizacion_educacion.do."

* --- 5.1 Urbano: total, hombres, mujeres ---
twoway ///
  (connected b_adj anio if ambito==2 & grupo==0, lcolor(black) mcolor(black) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==2 & grupo==1, lcolor(navy) mcolor(navy) msymbol(T) msize(small) lpattern(dash)) ///
  (connected b_adj anio if ambito==2 & grupo==2, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(shortdash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) ///
  xlabel(1991(3)2024, angle(45)) ///
  ytitle("Coeficiente sobre ln(ingreso laboral)") xtitle("Año") ///
  title("Prima salarial de la educación universitaria o más", size(medium)) ///
  subtitle("Ecuador urbano, ENEMDU 1991-2025", size(small)) ///
  legend(order(1 "Total" 2 "Hombres" 3 "Mujeres") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(urb, replace)
graph export "`out'/fig_serie_urbano.pdf", replace
graph export "`out'/fig_serie_urbano.eps", replace
graph save   "`out'/fig_serie_urbano.gph", replace

* --- 5.2 Nacional: total, hombres, mujeres ---
twoway ///
  (connected b_adj anio if ambito==1 & grupo==0 & anio>=2001, lcolor(black) mcolor(black) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==1 & grupo==1 & anio>=2001, lcolor(navy) mcolor(navy) msymbol(T) msize(small) lpattern(dash)) ///
  (connected b_adj anio if ambito==1 & grupo==2 & anio>=2001, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(shortdash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) ///
  xlabel(2001(3)2025, angle(45)) ///
  ytitle("Coeficiente sobre ln(ingreso laboral)") xtitle("Año") ///
  title("Prima salarial de la educación universitaria o más", size(medium)) ///
  subtitle("Ecuador nacional, ENEMDU 2001-2025", size(small)) ///
  legend(order(1 "Total" 2 "Hombres" 3 "Mujeres") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(nac, replace)
graph export "`out'/fig_serie_nacional.pdf", replace
graph export "`out'/fig_serie_nacional.eps", replace
graph save   "`out'/fig_serie_nacional.gph", replace

* --- 5.3 Urbano vs nacional (total) ---
twoway ///
  (connected b_adj anio if ambito==2 & grupo==0, lcolor(navy) mcolor(navy) msymbol(O) msize(small)) ///
  (connected b_adj anio if ambito==1 & grupo==0 & anio>=2001, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(small) lpattern(dash)) ///
  , ///
  ylabel(0(.2)1.4, angle(0) format(%3.1f) grid glcolor(gs14)) ///
  xlabel(1991(3)2024, angle(45)) ///
  ytitle("Coeficiente sobre ln(ingreso laboral)") xtitle("Año") ///
  title("Prima salarial universitaria: urbano vs. nacional", size(medium)) ///
  subtitle("Ecuador, ENEMDU 1991-2025", size(small)) ///
  legend(order(1 "Urbano" 2 "Nacional") rows(1) size(small) region(lstyle(none))) ///
  note("`nota'" "`nota2'" "`nota3'", size(vsmall)) ///
  graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(comp, replace)
graph export "`out'/fig_serie_urb_vs_nac.pdf", replace
graph export "`out'/fig_serie_urb_vs_nac.eps", replace
graph save   "`out'/fig_serie_urb_vs_nac.gph", replace

* Nota: Stata en batch (-b) en Mac no trae el traductor Graph2png; los PNG se
* generan convirtiendo los PDF:
*   sips -s format png --resampleWidth 2400 fig.pdf --out fig.png
cap graph export "`out'/fig_serie_urbano.png", replace width(2400)

di as res "Listo. Salidas en: `out'"

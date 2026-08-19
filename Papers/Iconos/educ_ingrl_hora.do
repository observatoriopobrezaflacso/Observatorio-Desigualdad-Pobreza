*==============================================================================*
* PRIMA SALARIAL DE LA EDUCACIÓN UNIVERSITARIA O MÁS — INGRESO POR HORA
*
* Variable dependiente: ln(ingreso laboral real por hora)
*   ingreso por hora = ing_lab_deflated / (horas semanales * 4.33)
*   horas = suma de horas de TODOS los trabajos (principal + secundario + otros)
*
* Ámbitos: Urbano y Nacional.  Años: 1990-93-96-99-02-05-08-11-14-17-21-25
*   (1990 y 2002 no existen como base; se usan 1991 y 2003 en su lugar)
*
* Fuente: .../ENEMDU/Procesadas/ingresos_pc/{Urbano,Nacional}
* Educación: armonización replicada de armonizacion_educacion.do
* Controles: edad y edad2 únicamente. Muestra sin restricción de edad.
*==============================================================================*

clear all
set more off

local urb  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/Urbano"
local nac  "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
local root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Íconos"
local out  "`root'/outputs/educ_ingrl"
cap mkdir "`root'/outputs"
cap mkdir "`out'"

* Años pedidos. 1990 y 2002 no tienen base: se reemplazan por 1991 y 2003.
* En el nacional sólo existen desde 2000, así que se añade 2001 como ancla.
local anios_urb "1991 1993 1996 1999 2003 2005 2008 2011 2014 2017 2021 2025"
local anios_nac "2001 2003 2005 2008 2011 2014 2017 2021 2025"

* tope de horas semanales plausibles (16 h/día x 7 días)
local maxhoras = 112
* semanas por mes (el ingreso es mensual y las horas semanales).
* Es un factor constante: no altera los coeficientes, sólo los niveles.
local semanas = 4.33

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
        local anios "`anios_nac'"
    }
    else {
        local dir "`urb'"
        local pat "urb"
        local anios "`anios_urb'"
    }

    foreach y of local anios {

        local f "ing_perca_`y'_`pat'_precios2000.dta"
        capture confirm file "`dir'/`f'"
        if _rc {
            di as error "FALTA: `f'"
            continue
        }

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

        *----------------------------------------------------------------------
        * HORAS TRABAJADAS: la ENEMDU pregunta por horas de cada trabajo.
        *   hasta 2006: hortrahp / hortrahs / hortraho
        *   desde 2007: p51a / p51b / p51c
        * Se suman las tres (principal + secundario + otros).
        *----------------------------------------------------------------------
        if (`y' <= 2006) local hvars "hortrahp hortrahs hortraho"
        else             local hvars "p51a p51b p51c"

        * conservar sólo las que existan realmente en ese año
        local hkeep
        foreach h of local hvars {
            local hit : list posof "`h'" in vl
            if `hit' local hkeep "`hkeep' `h'"
        }
        if ("`hkeep'" == "") {
            di as error "SIN HORAS: `f'"
            continue
        }

        qui use `educvar' `sexvar' `edadvar' `hkeep' ing_lab_deflated fexp ///
            `areavar' using "`dir'/`f'", clear

        *----------------------------------------------------------------------
        * Armonización de educación universitaria (idéntica a
        * armonizacion_educacion.do)
        *----------------------------------------------------------------------
        gen byte educ_univ = 0
        if (inrange(`y', 1990, 2000))  replace educ_univ = 1 if nivinst == 5
        if (`y' == 2001)               replace educ_univ = 1 if inlist(nivinst, 6, 7)
        if (`y' == 2002)               replace educ_univ = 1 if inlist(nivinst, 7, 8)
        if (inrange(`y', 2003, 2006))  replace educ_univ = 1 if inlist(nivinst, 9, 10)
        if (`y' >= 2007)               replace educ_univ = 1 if inlist(p10a, 9, 10)
        replace educ_univ = . if missing(`educvar')

        *----------------------------------------------------------------------
        * Horas semanales totales. Valores implausibles (999, 2058, etc.) se
        * tratan como faltantes antes de sumar. Un componente faltante suma 0
        * siempre que al menos uno esté informado.
        *----------------------------------------------------------------------
        gen double horas   = 0
        gen byte   horas_n = 0
        foreach h of local hkeep {
            replace `h' = . if `h' > `maxhoras' & !missing(`h')
            replace horas   = horas + `h' if !missing(`h')
            replace horas_n = horas_n + 1 if !missing(`h')
        }
        replace horas = . if horas_n == 0

        * homogeneizar nombres
        rename `sexvar'  sexo_h
        rename `edadvar' edad_h
        gen int  anio   = `y'
        gen byte ambito = `amb'
        if ("`areavar'" == "") gen byte area = 1

        keep ambito anio educ_univ sexo_h edad_h area horas ing_lab_deflated fexp
        destring area, replace force

        if (`amb' == 1) keep if inlist(area, 1, 2)
        if (`amb' == 2) keep if area == 1

        append using `acum'
        save `acum', replace
        di as txt "procesado: `pat' `y' (horas:`hkeep')"
    }
}

use `acum', clear
rename sexo_h sexo
rename edad_h edad
rename ing_lab_deflated ingrl_real

label define lbl_amb 1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb
label define lbl_sexo 1 "Hombre" 2 "Mujer", replace
label values sexo lbl_sexo
label define lbl_educ2 0 "Hasta secundaria" 1 "Universitaria o más", replace
label values educ_univ lbl_educ2

*------------------------------------------------------------------ muestra ---
* Sin restricción de edad: entran todos los perceptores de ingreso laboral.
keep if ingrl_real > 0 & !missing(ingrl_real)
keep if !missing(educ_univ)
keep if inlist(sexo, 1, 2)
keep if !missing(fexp) & fexp > 0
keep if inrange(horas, 1, `maxhoras')

*------------------------------------------------------- pre-dolarización -----
* Antes de 2000 el ingreso deflactado de estas bases está en sucres; se pasa a
* dólares al tipo de fijación de enero de 2000. No altera los coeficientes.
replace ingrl_real = ingrl_real/25000 if anio <= 1999

*-------------------------------------------------------- ingreso por hora ----
gen double ingrl_hora = ingrl_real / (horas * `semanas')
label var ingrl_hora "Ingreso laboral real por hora (precios constantes)"
label var horas      "Horas semanales trabajadas (todos los trabajos)"

gen double lnw   = ln(ingrl_hora)
gen double edad2 = edad^2

di as res "=== horas semanales medias (ponderadas) ==="
table anio ambito [aw=fexp], c(mean horas mean ingrl_hora) format(%6.2f)
di as res "=== observaciones ==="
table anio ambito, c(freq)

compress
save "`out'/microdatos_hora.dta", replace

*==============================================================================*
* 2. REGRESIONES POR ÁMBITO x SEXO x AÑO
*==============================================================================*

tempname pf
tempfile res
postfile `pf' byte ambito byte grupo int anio ///
    double(b_raw se_raw b_adj se_adj N share_univ w_no w_si h_no h_si) using "`res'", replace

foreach amb of numlist 1 2 {
    levelsof anio if ambito==`amb', local(anios)
    foreach y of local anios {
        foreach g of numlist 0 1 2 {

            if (`g' == 0) local cond "ambito==`amb' & anio==`y'"
            else          local cond "ambito==`amb' & anio==`y' & sexo==`g'"

            * controles: sólo edad y edad2 en todos los modelos
            local ctrl "c.edad c.edad2"

            qui count if `cond'
            if (r(N) < 100) continue

            qui reg lnw i.educ_univ [pw=fexp] if `cond', vce(robust)
            local b_raw  = _b[1.educ_univ]
            local se_raw = _se[1.educ_univ]
            local N      = e(N)

            qui reg lnw i.educ_univ `ctrl' [pw=fexp] if `cond', vce(robust)
            local b_adj  = _b[1.educ_univ]
            local se_adj = _se[1.educ_univ]

            qui sum educ_univ [aw=fexp] if `cond'
            local sh = r(mean)
            qui sum ingrl_hora [aw=fexp] if `cond' & educ_univ==0
            local w0 = r(mean)
            qui sum ingrl_hora [aw=fexp] if `cond' & educ_univ==1
            local w1 = r(mean)
            qui sum horas [aw=fexp] if `cond' & educ_univ==0
            local h0 = r(mean)
            qui sum horas [aw=fexp] if `cond' & educ_univ==1
            local h1 = r(mean)

            post `pf' (`amb') (`g') (`y') (`b_raw') (`se_raw') (`b_adj') ///
                (`se_adj') (`N') (`sh') (`w0') (`w1') (`h0') (`h1')
        }
    }
}
postclose `pf'

*==============================================================================*
* 3. MODELOS AGRUPADOS
*==============================================================================*

eststo clear
local i = 0
foreach amb of numlist 2 1 {
    foreach g of numlist 0 1 2 {
        local ++i
        if (`g' == 0) local cond "ambito==`amb'"
        else          local cond "ambito==`amb' & sexo==`g'"
        * sólo edad y edad2; i.anio se mantiene porque define la comparación
        * dentro de cada año en el modelo agrupado
        local ctrl "c.edad c.edad2 i.anio"
        eststo m`i': qui reg lnw i.educ_univ `ctrl' [pw=fexp] if `cond', vce(cluster anio)
    }
}

esttab m1 m2 m3 m4 m5 m6 using "`out'/hora_tabla_pooled.rtf", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observaciones" "R2")) ///
    mtitles("Urb Total" "Urb Hombres" "Urb Mujeres" "Nac Total" "Nac Hombres" "Nac Mujeres") ///
    varlabels(1.educ_univ "Universitaria o más") ///
    title("Prima salarial de la educación universitaria o más sobre ln(ingreso laboral real por hora)") ///
    addnotes("MCO ponderado por fexp, EE agrupados por año. Controles: edad y edad2. Horas = suma de todos los trabajos.")

esttab m1 m2 m3 m4 m5 m6 using "`out'/hora_tabla_pooled.csv", replace ///
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
label var w_no       "Ingreso/hora medio: hasta secundaria"
label var w_si       "Ingreso/hora medio: universitaria o más"
label var h_no       "Horas semanales: hasta secundaria"
label var h_si       "Horas semanales: universitaria o más"
label var share_univ "Proporción universitaria o más"

format b_* se_* w_* %7.3f
format pct_* h_* %7.1f
format share_univ %5.3f

sort ambito grupo anio
list ambito grupo anio b_raw b_adj pct_adj h_no h_si N if ambito==2, sepby(grupo) noobs
list ambito grupo anio b_raw b_adj pct_adj h_no h_si N if ambito==1, sepby(grupo) noobs

save "`out'/hora_coef_educ_ingrl.dta", replace
export delimited using "`out'/hora_coef_educ_ingrl.csv", replace

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

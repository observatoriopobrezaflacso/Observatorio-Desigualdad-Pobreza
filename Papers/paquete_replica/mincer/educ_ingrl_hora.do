*==============================================================================*
* PRIMA SALARIAL DE LA EDUCACIÓN UNIVERSITARIA O MÁS — INGRESO POR HORA
*
* Variable dependiente: ln(ingreso laboral por hora)
*   ingreso por hora = ingrl / (horas semanales * 4.33)
*   horas = suma de horas de TODOS los trabajos (principal + secundario + otros)
*
* Ámbitos: Urbano y Nacional.  Años: 1990-93-96-99-02-05-08-11-14-17-21-25
*   (1990 y 2002 no existen como base; se usan 1991 y 2003 en su lugar)
*
* Fuente: .../ENEMDU/Procesadas/ramas homogeneizadas/empleo<año>_isic4.dta
*   Son las ENEMDU completas con la rama homogeneizada añadida, así que traen
*   todo lo necesario (educación, sexo, edad, horas, ingrl, fexp, area) y no
*   hace falta emparejarlas con nada.
*   rama1 = sección CIIU 4, códigos 1-21 = A..U, homogénea 1991-2025.
*   Un solo archivo por año: NO están separadas en urbano/nacional. El archivo
*   se lee una vez por ámbito y el recorte lo hace `area` (urbano = area 1;
*   nacional = area 1 y 2). Los años anteriores a 2000 son sólo urbanos.
*
* Ingreso: ingrl (ingreso laboral corriente de la ENEMDU). Al estimarse un
*   modelo por año, el deflactor es un factor constante dentro de cada
*   regresión y no altera los coeficientes; en el modelo agrupado lo absorben
*   los efectos fijos de año. Los niveles reportados (w_no, w_si) sí quedan en
*   valores corrientes.
* Educación: armonización replicada de armonizacion_educacion.do
* Controles: edad, edad2 y efectos fijos de rama de actividad (i.rama_h).
*            Muestra sin restricción de edad.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off


local ram  "$gd/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
local root "$gd/Papers/Íconos"
local out  "`root'/outputs/educ_ingrl"
cap mkdir "`root'/outputs"
cap mkdir "`out'"

* Años pedidos. 1990 y 2002 no tienen base: se reemplazan por 1991 y 2003.
* En el nacional sólo existen desde 2000, así que se añade 2001 como ancla.
* 2001 se agrega al urbano para tener el mismo anclaje que el nacional
* (la figura del paper no lo etiqueta, pero la base existe).
local anios_urb "1991 1993 1996 1999 2001 2003 2005 2008 2011 2014 2017 2021 2025"
local anios_nac "2001 2003 2005 2008 2011 2014 2017 2021 2025"

* Para probar rápido, descomentar:
* local anios_urb "2025"
* local anios_nac "2025"

* tope de horas semanales plausibles (16 h/día x 7 días)
local maxhoras = 140
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
        local pat "nac"
        local anios "`anios_nac'"
    }
    else {
        local pat "urb"
        local anios "`anios_urb'"
    }

    foreach y of local anios {

        * Mismo archivo para los dos ámbitos: la ENEMDU completa del año con la
        * rama homogeneizada. El recorte urbano/nacional se hace más abajo con
        * `area'.
        local f "empleo`y'_isic4.dta"
        capture confirm file "`ram'/`f'"
        if _rc {
            di as error "FALTA: `f'"
            continue
        }

        qui describe using "`ram'/`f'", varlist
        local vl = r(varlist)

        * nombres de variables según el formulario del año. sexo y edad ya
        * vienen con nombre homogéneo en todos los años.
        local hasp10a : list posof "p10a" in vl
        local hasarea : list posof "area" in vl

        if (`hasp10a') local educvar p10a
        else           local educvar nivinst
        local areavar
        if (`hasarea') local areavar area

        *----------------------------------------------------------------------
        * HORAS TRABAJADAS: la ENEMDU pregunta por horas de cada trabajo.
        *   hasta 2006: hortrahp / hortrahs / hortraho
        *   desde 2007: p51a / p51b / p51c
        * Se suman las tres (principal + secundario + otros).
        *----------------------------------------------------------------------
        local hasho : list posof "hortrahp" in vl
        if (`hasho') local hvars "hortrahp hortrahs hortraho"
        else         local hvars "p51a p51b p51c"

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

        qui use `educvar' sexo edad `hkeep' ingrl fexp rama1 `areavar' ///
            using "`ram'/`f'", clear

        rename rama1 rama_h

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

        *----------------------------------------------------------------------
        * CÓDIGOS DE NO RESPUESTA DE ingrl. Se replican los de
        * Boletín 1/.../Ingresos/ingresos_anios_all_fn.do:
        *   - su PASO 4 corre para todos los años: 999999, 0 y -1;
        *   - bloque 1991: 9999998 (lo anula en ingpat, el componente de ingrl);
        *   - bloque 1992-1999: 99999999, 9999999 y 9999998;
        *   - bloques 2001-2009: recode ingrl (-1=.) (999999=.) (0=.);
        *   - bloque 2010-2025: recode ingrl (999999=.).
        * ÚNICA DIFERENCIA: en los años en sucres 999999 NO se trata como código
        * de no respuesta, sino como un monto válido (999999 sucres son unos
        * USD 40 al mes al tipo de fijación, un sueldo perfectamente posible).
        * Los ceros y los negativos no hace falta anularlos aquí: los descarta
        * el filtro ingrl > 0 de la sección de muestra.
        *----------------------------------------------------------------------
        local invalidos "999999"
        if (`y' == 1991)              local invalidos "9999998"
        if (inrange(`y', 1992, 1999)) local invalidos "9999998 9999999 99999999"

        foreach v of local invalidos {
            qui count if ingrl == `v'
            if (r(N) > 0) di as txt "  `y': `r(N)' casos de ingrl==`v' anulados"
            qui replace ingrl = . if ingrl == `v'
        }

        gen int  anio   = `y'
        gen byte ambito = `amb'
        if ("`areavar'" == "") gen byte area = 1

        keep ambito anio educ_univ sexo edad area horas ingrl fexp rama_h
        destring area, replace force

        if (`amb' == 1) keep if inlist(area, 1, 2)
        if (`amb' == 2) keep if area == 1

        append using `acum'
        save `acum', replace
        di as txt "procesado: `pat' `y' (horas:`hkeep')"
    }
}

use `acum', clear

label define lbl_amb 1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb
label define lbl_sexo 1 "Hombre" 2 "Mujer", replace
label values sexo lbl_sexo
label define lbl_educ2 0 "Hasta secundaria" 1 "Universitaria o más", replace
label values educ_univ lbl_educ2
label var rama_h "Rama de actividad (CIIU 4, secciones A-U)"

gen byte tiene_rama = !missing(rama_h)

*------------------------------------------------------------------ muestra ---
* Sin restricción de edad: entran todos los perceptores de ingreso laboral.
keep if ingrl > 0 & !missing(ingrl)
keep if !missing(educ_univ)
keep if inlist(sexo, 1, 2)
keep if !missing(fexp) & fexp > 0
keep if inrange(horas, 1, `maxhoras')

*--------------------------------------------------------------- rama ---------
* La rama sólo está definida para la población ocupada. Antes de recortar se
* reporta la cobertura dentro de la muestra de perceptores, para que quede
* claro cuánto cuesta el control.


di as res "=== cobertura de rama en la muestra de perceptores (% no faltante) ==="
foreach a of numlist 2 1 {
    di as txt "--- ámbito `a' (2=Urbano, 1=Nacional)"
    tabstat tiene_rama if ambito==`a', by(anio) stat(mean n) format(%6.3f)
}
keep if !missing(rama_h)

*------------------------------------------------------- pre-dolarización -----
* Antes de 2000 el ingreso de estas bases está en sucres; se pasa a dólares al
* tipo de fijación de enero de 2000. No altera los coeficientes: sólo hace
* legibles los niveles de w_no y w_si junto a los de los años dolarizados.
replace ingrl = ingrl/25000 if anio <= 1999

*-------------------------------------------------------- ingreso por hora ----
gen double ingrl_hora = ingrl / (horas * `semanas')
label var ingrl_hora "Ingreso laboral por hora (valores corrientes)"
label var horas      "Horas semanales trabajadas (todos los trabajos)"

gen double lnw   = ln(ingrl_hora)
gen double edad2 = edad^2

di as res "=== horas semanales medias y observaciones ==="
foreach a of numlist 2 1 {
    di as txt "--- ámbito `a' (2=Urbano, 1=Nacional)"
    tabstat horas ingrl_hora [aw=fexp] if ambito==`a', by(anio) stat(mean) format(%6.2f)
    tabstat lnw if ambito==`a', by(anio) stat(n) format(%9.0f)
}

compress
save "`out'/microdatos_hora.dta", replace


*==============================================================================*
* 2. REGRESIONES POR ÁMBITO x SEXO x AÑO
*==============================================================================*

tempname pf
tempfile res
postfile `pf' byte ambito byte grupo int anio ///
    double(b_raw se_raw b_edad se_edad b_adj se_adj N share_univ w_no w_si h_no h_si) ///
    using "`res'", replace

foreach amb of numlist 1 2 {
    levelsof anio if ambito==`amb', local(anios)
    foreach y of local anios {
        foreach g of numlist 0 1 2 {

            if (`g' == 0) local cond "ambito==`amb' & anio==`y'"
            else          local cond "ambito==`amb' & anio==`y' & sexo==`g'"

            * controles: edad, edad2 y efectos fijos de rama de actividad
            local ctrl "c.edad c.edad2 i.rama_h"

            qui count if `cond'
            if (r(N) < 100) continue

            qui reg lnw i.educ_univ [pw=fexp] if `cond', vce(robust)
            local b_raw  = _b[1.educ_univ]
            local se_raw = _se[1.educ_univ]
            local N      = e(N)

            * especificación anterior (sólo edad), para poder comparar cuánto
            * de la prima se explica por la composición sectorial
            qui reg lnw i.educ_univ c.edad c.edad2 [pw=fexp] if `cond', vce(robust)
            local b_edad  = _b[1.educ_univ]
            local se_edad = _se[1.educ_univ]

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

            post `pf' (`amb') (`g') (`y') (`b_raw') (`se_raw') ///
                (`b_edad') (`se_edad') (`b_adj') (`se_adj') ///
                (`N') (`sh') (`w0') (`w1') (`h0') (`h1')
        }
    }
}
postclose `pf'

*==============================================================================*
* 3. MODELOS AGRUPADOS
*==============================================================================*

* Además de eststo, se guardan los resultados en un tempfile para poder
* llevarlos después a la hoja "modelo_agrupado" del Excel.
tempname pf2
tempfile pooledres
postfile `pf2' byte ambito byte grupo double(b se N r2) using "`pooledres'", replace

eststo clear
local i = 0
foreach amb of numlist 2 1 {
    foreach g of numlist 0 1 2 {
        local ++i
        if (`g' == 0) local cond "ambito==`amb'"
        else          local cond "ambito==`amb' & sexo==`g'"
        * edad, edad2 y rama; i.anio se mantiene porque define la comparación
        * dentro de cada año en el modelo agrupado
        local ctrl "c.edad c.edad2 i.rama_h i.anio"
        eststo m`i': qui reg lnw i.educ_univ `ctrl' [pw=fexp] if `cond', vce(cluster anio)
        post `pf2' (`amb') (`g') (_b[1.educ_univ]) (_se[1.educ_univ]) ///
            (e(N)) (e(r2))
    }
}
postclose `pf2'

esttab m1 m2 m3 m4 m5 m6 using "`out'/hora_tabla_pooled.rtf", replace ///
    keep(1.educ_univ) b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observaciones" "R2")) ///
    mtitles("Urb Total" "Urb Hombres" "Urb Mujeres" "Nac Total" "Nac Hombres" "Nac Mujeres") ///
    varlabels(1.educ_univ "Universitaria o más") ///
    title("Prima salarial de la educación universitaria o más sobre ln(ingreso laboral por hora)") ///
    addnotes("MCO ponderado por fexp, EE agrupados por año. Controles: edad, edad2 y efectos fijos de rama (CIIU 4). Horas = suma de todos los trabajos.")

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

gen double pct_raw  = 100*(exp(b_raw)-1)
gen double pct_edad = 100*(exp(b_edad)-1)
gen double pct_adj  = 100*(exp(b_adj)-1)
gen double t_adj   = b_adj/se_adj
gen double p_adj   = 2*normal(-abs(t_adj))

label var b_raw      "Coef. sin controles"
label var b_edad     "Coef. con edad y edad2"
label var b_adj      "Coef. con edad, edad2 y rama"
label var w_no       "Ingreso/hora medio corriente: hasta secundaria"
label var w_si       "Ingreso/hora medio corriente: universitaria o más"
label var h_no       "Horas semanales: hasta secundaria"
label var h_si       "Horas semanales: universitaria o más"
label var share_univ "Proporción universitaria o más"

format b_* se_* w_* %7.3f
format pct_* h_* %7.1f
format share_univ %5.3f

sort ambito grupo anio
list ambito grupo anio b_raw b_edad b_adj pct_adj h_no h_si N if ambito==2, sepby(grupo) noobs
list ambito grupo anio b_raw b_edad b_adj pct_adj h_no h_si N if ambito==1, sepby(grupo) noobs

save "`out'/hora_coef_educ_ingrl.dta", replace
export delimited using "`out'/hora_coef_educ_ingrl.csv", replace

*==============================================================================*
* 5. GRÁFICOS (sin intervalos de confianza)
*==============================================================================*

local nota  "MCO por año sobre ln(ingreso laboral por hora). Ponderado por fexp. Controles: edad, edad{sup:2} y rama de actividad (CIIU 4)."
local nota2 "Horas = suma de horas semanales de todos los trabajos (principal + secundario + otros)."
local nota3 "Muestra: perceptores de ingreso laboral con horas > 0 y rama declarada, sin restricción de edad."
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

*==============================================================================*
* 6. TABLAS EN EXCEL
*
* Un solo libro con todas las tablas de este análisis, en la carpeta del
* análisis dentro de Papers/Íconos. La primera hoja usa `replace` (crea el
* archivo) y las demás `sheetreplace` (sólo reemplazan su hoja).
*==============================================================================*

local xls "`out'/prima_hora_tablas.xlsx"

*--- 6.1 Coeficientes por ámbito x grupo x año (formato largo) -----------------
use "`out'/hora_coef_educ_ingrl.dta", clear
decode ambito, gen(ambito_t)
decode grupo,  gen(grupo_t)
drop ambito grupo
rename ambito_t ambito
rename grupo_t  grupo
label var ambito "Ámbito"
label var grupo  "Grupo"
label var anio   "Año"
label var N      "Observaciones"
order ambito grupo anio b_raw se_raw b_edad se_edad b_adj se_adj ///
    pct_adj t_adj p_adj share_univ w_no w_si h_no h_si N
sort ambito grupo anio
export excel using "`xls'", sheet("coeficientes") firstrow(varlabels) replace

*--- 6.2 Formato ancho: lo que se pega en la hoja prima_salarial ---------------
use "`out'/hora_coef_educ_ingrl.dta", clear
keep ambito grupo anio b_adj
decode ambito, gen(amb)
drop ambito
reshape wide b_adj, i(amb anio) j(grupo)
rename b_adj0 total
rename b_adj1 hombres
rename b_adj2 mujeres
rename amb ambito
label var ambito  "Ámbito"
label var anio    "Año"
label var total   "Total"
label var hombres "Hombres"
label var mujeres "Mujeres"
order ambito anio total hombres mujeres
sort ambito anio
export excel using "`xls'", sheet("ancho_para_grafico") firstrow(varlabels) sheetreplace

*--- 6.3 Horas y tamaño de muestra --------------------------------------------
use "`out'/hora_coef_educ_ingrl.dta", clear
keep if grupo == 0
keep ambito anio h_no h_si w_no w_si share_univ N
decode ambito, gen(amb)
drop ambito
rename amb ambito
label var ambito "Ámbito"
label var anio   "Año"
label var N      "Observaciones"
order ambito anio h_no h_si w_no w_si share_univ N
sort ambito anio
export excel using "`xls'", sheet("horas_y_muestra") firstrow(varlabels) sheetreplace

*--- 6.4 Modelo agrupado (todos los años juntos) ------------------------------
use "`pooledres'", clear
label define lbl_amb   1 "Nacional" 2 "Urbano", replace
label values ambito lbl_amb
label define lbl_grupo 0 "Total" 1 "Hombres" 2 "Mujeres", replace
label values grupo lbl_grupo
decode ambito, gen(ambito_t)
decode grupo,  gen(grupo_t)
drop ambito grupo
rename ambito_t ambito
rename grupo_t  grupo
gen double pct = 100*(exp(b)-1)
gen double t   = b/se
label var ambito "Ámbito"
label var grupo  "Grupo"
label var b      "Coeficiente universitaria o más"
label var se     "Error estándar (cluster por año)"
label var pct    "Prima en % sobre el ingreso por hora"
label var t      "Estadístico t"
label var N      "Observaciones"
label var r2     "R2"
order ambito grupo b se t pct N r2
export excel using "`xls'", sheet("modelo_agrupado") firstrow(varlabels) sheetreplace

*--- 6.5 Notas metodológicas ---------------------------------------------------
clear
set obs 10
gen str244 nota = ""
replace nota = "Prima salarial por hora de la educación universitaria o más." in 1
replace nota = "Variable dependiente: ln(ingreso laboral por hora)." in 2
replace nota = "Ingreso por hora = ingrl / (horas semanales x 4.33), en valores corrientes." in 3
replace nota = "Horas = suma del trabajo principal + secundario + otros trabajos." in 4
replace nota = "MCO por año, ponderado por fexp, errores estándar robustos." in 5
replace nota = "b_raw = sin controles. b_edad = con edad y edad^2 (especificación anterior)." in 6
replace nota = "b_adj = con edad, edad^2 y efectos fijos de rama CIIU 4 (es la serie del gráfico)." in 7
replace nota = "Fuente única: ENEMDU/Procesadas/ramas homogeneizadas/empleo<año>_isic4.dta (rama = rama1)." in 8
replace nota = "Muestra: perceptores de ingreso laboral con horas > 0 y rama declarada, sin restricción de edad." in 9
replace nota = "1990 y 2002 no tienen base: se usan 1991 y 2003. Generado por educ_ingrl_hora.do." in 10
label var nota "Notas"
export excel using "`xls'", sheet("notas") firstrow(varlabels) sheetreplace

di as res "Tablas en Excel: `xls'"
di as res "Listo. Salidas en: `out'"

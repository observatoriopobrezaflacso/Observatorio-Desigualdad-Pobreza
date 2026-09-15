*------------------------------------------------------------------*
* INFORMALIDAD 1991-2025 CON INTERVALOS DE CONFIANZA
*------------------------------------------------------------------*
* Versión de analisis_descriptivo.do que estima los mismos indicadores
* pero usando el diseño muestral complejo de la ENEMDU (estrato + UPM),
* de modo que cada punto viene con error estándar e IC al 95%.
*
* Requisitos:
*   1) componentes/diseno_muestral.do  -> historico_diseno_muestral.dta
*   2) 3. Analisis/merge_informal.do   -> base_trabajo.dta (ya con
*                                         estrato_svy y upm_svy)
*
* Diferencias metodológicas frente a analisis_descriptivo.do:
*   - [iw=fexp] + collapse  ->  svyset ... [pw=fexp] + svy: mean
*   - el denominador (ocupados de 15 años y más) se maneja con
*     subpop() en vez de borrar observaciones, que es lo correcto
*     para estimar la varianza.
*   - cada año se svysetea por separado: el diseño de la ENEMDU
*     cambia (ver diseno_fuente) y los años no son comparables como
*     un solo diseño.
*
* COBERTURA: 2000-2025. La década de 1990 queda fuera a propósito.
* Estratos por período:
*   2000-2014  provincia x area  -> RECONSTRUIDO: no existe variable
*              de estrato ni en las bases armonizadas ni en los
*              originales de INEC. Al ser más grueso que el estrato
*              real, los EE salen conservadores (nunca subestimados).
*   2015-2017  plan_muestreo     -> estrato oficial INEC
*   2018-2025  estrato           -> estrato oficial INEC
*------------------------------------------------------------------*

clear all
set more off

global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases"
global bases_armonizadas "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_results "$user_root/Boletín 3/4. Resultados/informalidad"
global out_tablas  "$out_results/Tablas"
global out_graficos "$out_results/Graficos"

cap mkdir "$out_results"
cap mkdir "$out_tablas"
cap mkdir "$out_graficos"

* Base de entrada (cambiar aquí para correr sobre una base de prueba)
global base_ic "$bases_armonizadas/base_trabajo.dta"

* Rango de años y exclusiones
* (2002 no tiene muestra comparable; antes de 2000 no se estiman IC)
global anio_ini 2000
global anios_excluidos 2002

* Nivel de confianza
global nivel 95

*==================================================================*
**# 1. CARGA Y VERIFICACIÓN DEL DISEÑO
*==================================================================*

use "$base_ic", clear

replace area = 1 if area == .

foreach v in estrato_svy upm_svy fexp {
    capture confirm variable `v'
    if _rc {
        di as error "Falta la variable `v' en la base."
        di as error "Vuelva a correr diseno_muestral.do y merge_informal.do."
        exit 111
    }
}

* Observaciones sin diseño: no pueden entrar a svy
qui count if missing(estrato_svy) | missing(upm_svy) | missing(fexp) | fexp <= 0
if r(N) > 0 {
    di as error "ATENCION: " r(N) " observaciones sin estrato/UPM/fexp válidos."
    tab anio if missing(estrato_svy) | missing(upm_svy) | missing(fexp) | fexp <= 0
}

* Resumen del diseño por año
preserve
    egen te = tag(anio estrato_svy)
    egen tu = tag(anio upm_svy)
    gen byte uno = 1
    collapse (sum) estratos = te upm = tu obs = uno, by(anio diseno_fuente)
    di as txt _n "Diseño muestral por año:"
    list anio diseno_fuente estratos upm obs, noobs sepby(diseno_fuente) abbrev(14)
restore

*==================================================================*
**# 2. CONSTRUCCIÓN DE INDICADORES
*==================================================================*
* Mismos criterios que analisis_descriptivo.do, con una diferencia:
* aquí NO se borran los no ocupados ni los menores de 15 años; se
* marcan en 'ocupado' y se usan como subpoblación.

gen byte ocupado = .
replace ocupado = !inrange(condact, 5, 8)       if anio <= 2006 & !missing(condact)
replace ocupado = !inlist(condactn, 0, 7, 8, 9) if anio >= 2007 & !missing(condactn)
replace ocupado = 0 if edad < 15 | missing(edad)
replace ocupado = 0 if missing(ocupado)
label var ocupado "Ocupado de 15 años y más (denominador)"

* --- Informalidad 1: IESS + adecuado + no remunerado ---
gen byte informal1 = affiliated == 0 | adec == 0 | no_remunerado == 1
replace informal1 = . if inlist(., affiliated, adec, no_remunerado)

gen byte informal1_sim = affiliated == 0 | adec_sim == 0 | no_remunerado == 1
replace informal1_sim = . if inlist(., affiliated, adec_sim, no_remunerado)

* --- Informalidad 2: agrega el criterio de institución formal (RUC) ---
gen byte informal2 = affiliated == 0 | adec == 0 | no_remunerado == 1 | institucion_formal == 0
replace informal2 = . if inlist(., affiliated, adec, institucion_formal, no_remunerado)

gen byte informal2_sim = affiliated == 0 | adec_sim == 0 | no_remunerado == 1 | institucion_formal == 0
replace informal2_sim = . if inlist(., affiliated, adec_sim, institucion_formal, no_remunerado)

* --- Componentes ---
gen byte comp_no_iess  = (affiliated == 0)         if !missing(affiliated)
gen byte comp_no_adec  = (adec == 0)               if !missing(adec)
gen byte comp_no_remun = (no_remunerado == 1)      if !missing(no_remunerado)
gen byte comp_no_ruc   = (institucion_formal == 0) if !missing(institucion_formal)

label var informal1     "Informalidad sin criterio RUC"
label var informal2     "Informalidad con criterio RUC"
label var informal1_sim "Informalidad sin criterio RUC (adec simulado)"
label var informal2_sim "Informalidad con criterio RUC (adec simulado)"
label var comp_no_iess  "No afiliado al IESS"
label var comp_no_adec  "Sin condiciones adecuadas"
label var comp_no_remun "Trabajador no remunerado"
label var comp_no_ruc   "Institución no formal (sin RUC)"

* --- Subpoblaciones ---
gen byte sp_nacional = ocupado == 1
gen byte sp_hombres  = ocupado == 1 & sexo == 1
gen byte sp_mujeres  = ocupado == 1 & sexo == 2
gen byte sp_urbano   = ocupado == 1 & area == 1
gen byte sp_rural    = ocupado == 1 & area == 2

global indicadores informal1 informal2 informal1_sim informal2_sim ///
                   comp_no_iess comp_no_adec comp_no_remun comp_no_ruc
global grupos nacional hombres mujeres urbano rural

*==================================================================*
**# 3. ESTIMACIÓN AÑO POR AÑO CON svy
*==================================================================*

tempname P
tempfile RES
postfile `P' int anio str16 grupo str16 indicador ///
    double(estimacion ee lb ub deff) long(n_obs n_pob) int(n_estratos n_upm) ///
    using `RES', replace

qui levelsof anio, local(anios)

foreach y of local anios {

    if `y' < $anio_ini {
        di as txt "-- `y' fuera del rango de estimación"
        continue
    }

    local excl : list y in global(anios_excluidos)
    if `excl' {
        di as txt "-- `y' excluido por configuración"
        continue
    }

    di as txt _n "================ `y' ================"

    preserve
    qui keep if anio == `y'
    qui drop if missing(estrato_svy) | missing(upm_svy) | missing(fexp) | fexp <= 0

    * singleunit(centered): trata los estratos con una sola UPM
    * centrando en la media general en vez de descartarlos.
    qui svyset upm_svy [pw = fexp], strata(estrato_svy) singleunit(centered)

    foreach g of global grupos {
        foreach v of global indicadores {

            qui count if sp_`g' == 1 & !missing(`v')
            if r(N) < 30 continue

            capture qui svy, subpop(sp_`g'): mean `v'
            if _rc {
                di as error "   `y' `g' `v': svy falló (rc=" _rc ")"
                continue
            }

            matrix T = r(table)
            local est = T[1,1] * 100
            local ee  = T[2,1] * 100
            local lb  = T[5,1] * 100
            local ub  = T[6,1] * 100

            * e(N_sub) = observaciones de la subpoblación
            * e(N_subpop) = población estimada por esa subpoblación
            local nsub  = e(N_sub)
            local npob  = e(N_subpop)
            local nstr  = e(N_strata)
            local nupm  = e(N_psu)

            * Efecto de diseño
            local dff = .
            capture qui estat effects
            if !_rc {
                matrix D = r(deff)
                capture local dff = D[1,1]
            }

            post `P' (`y') ("`g'") ("`v'") (`est') (`ee') (`lb') (`ub') (`dff') ///
                     (`nsub') (`npob') (`nstr') (`nupm')
        }
        di as txt "   `g': listo"
    }
    restore
}

postclose `P'

*==================================================================*
**# 4. GUARDAR RESULTADOS
*==================================================================*

use `RES', clear

gen double amplitud = ub - lb
label var estimacion "Estimación (%)"
label var ee         "Error estándar (pp)"
label var lb         "Límite inferior IC 95%"
label var ub         "Límite superior IC 95%"
label var deff       "Efecto de diseño"
label var n_obs      "Observaciones en la subpoblación"
label var n_pob      "Población estimada"
label var amplitud   "Amplitud del IC (pp)"

format estimacion ee lb ub amplitud deff %9.2f
sort indicador grupo anio

save "$bases_armonizadas/resultados_ic.dta", replace
export excel using "$out_tablas/informalidad_ic.xlsx", firstrow(varlabels) replace

* Tabla ancha (un indicador por hoja) para revisión rápida
foreach v in informal1 informal2 {
    preserve
        keep if indicador == "`v'" & grupo == "nacional"
        keep anio estimacion ee lb ub n_obs deff
        export excel using "$out_tablas/informalidad_ic.xlsx", ///
            sheet("`v'_nacional") sheetreplace firstrow(varlabels)
    restore
}

*==================================================================*
**# 5. GRÁFICOS CON BANDAS DE CONFIANZA
*==================================================================*

* ---------- 5.1 Informalidad con y sin criterio RUC ----------
preserve
    keep if grupo == "nacional" & inlist(indicador, "informal1", "informal2")
    keep anio indicador estimacion lb ub
    reshape wide estimacion lb ub, i(anio) j(indicador) string

    twoway ///
        (rarea lbinformal1 ubinformal1 anio, color(navy%25) lwidth(none)) ///
        (rarea lbinformal2 ubinformal2 anio if anio >= 2001, color(maroon%25) lwidth(none)) ///
        (connected estimacioninformal1 anio, lcolor(navy) mcolor(navy) msymbol(O) msize(vsmall)) ///
        (connected estimacioninformal2 anio if anio >= 2001, lcolor(maroon) mcolor(maroon) msymbol(O) msize(vsmall)), ///
        legend(order(3 "Sin criterio RUC" 4 "Con criterio RUC" ///
                     1 "IC 95% (sin RUC)" 2 "IC 95% (con RUC)") ///
               position(6) rows(2) size(small)) ///
        ylabel(50(10)100, format(%9.0f) angle(0) grid) yscale(range(50 100)) ///
        xlabel(2000(2)2025, angle(90) labsize(small)) xscale(range(2000 2025)) ///
        ytitle("Informalidad (%)") xtitle("") ///
        note("Fuente: ENEMDU. Elaboración propia. IC 95% con diseño muestral complejo (estrato + UPM)." "En 2000-2014 el estrato es reconstruido (provincia x área): los IC de esos años son conservadores.", size(vsmall)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ic_informal, replace)
    graph export "$out_graficos/informalidad_ic.png", replace width(2200)
    graph export "$out_graficos/informalidad_ic.pdf", replace
restore

* ---------- 5.2 Componentes ----------
preserve
    keep if grupo == "nacional" & ///
        inlist(indicador, "comp_no_iess", "comp_no_adec", "comp_no_remun", "comp_no_ruc")
    keep anio indicador estimacion lb ub
    reshape wide estimacion lb ub, i(anio) j(indicador) string

    twoway ///
        (rarea lbcomp_no_iess  ubcomp_no_iess  anio, color(navy%20) lwidth(none)) ///
        (rarea lbcomp_no_adec  ubcomp_no_adec  anio, color(cranberry%20) lwidth(none)) ///
        (rarea lbcomp_no_remun ubcomp_no_remun anio, color(teal%20) lwidth(none)) ///
        (rarea lbcomp_no_ruc   ubcomp_no_ruc   anio, color(orange%20) lwidth(none)) ///
        (line estimacioncomp_no_iess  anio, lcolor(navy)) ///
        (line estimacioncomp_no_adec  anio, lcolor(cranberry)) ///
        (line estimacioncomp_no_remun anio, lcolor(teal)) ///
        (line estimacioncomp_no_ruc   anio, lcolor(orange)), ///
        legend(order(5 "No IESS" 6 "No adecuado" 7 "No remunerado" 8 "Sin RUC") ///
               position(6) rows(1) size(small)) ///
        ylabel(0(20)100, format(%9.0f) angle(0) grid) ///
        xlabel(2000(2)2025, angle(90) labsize(small)) xscale(range(2000 2025)) ///
        ytitle("Porcentaje de ocupados (%)") xtitle("") ///
        note("Fuente: ENEMDU. Elaboración propia. Bandas: IC 95%.", size(vsmall)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ic_componentes, replace)
    graph export "$out_graficos/componentes_ic.png", replace width(2200)
    graph export "$out_graficos/componentes_ic.pdf", replace
restore

* ---------- 5.3 Informalidad (con RUC) por sexo ----------
preserve
    keep if indicador == "informal2" & inlist(grupo, "hombres", "mujeres")
    keep anio grupo estimacion lb ub
    reshape wide estimacion lb ub, i(anio) j(grupo) string

    twoway ///
        (rarea lbhombres ubhombres anio, color(navy%25) lwidth(none)) ///
        (rarea lbmujeres ubmujeres anio, color(cranberry%25) lwidth(none)) ///
        (connected estimacionhombres anio, lcolor(navy) mcolor(navy) msymbol(O) msize(vsmall)) ///
        (connected estimacionmujeres anio, lcolor(cranberry) mcolor(cranberry) msymbol(O) msize(vsmall)), ///
        legend(order(3 "Hombres" 4 "Mujeres") position(6) rows(1) size(small)) ///
        ylabel(50(10)100, format(%9.0f) angle(0) grid) ///
        xlabel(2000(2)2025, angle(90) labsize(small)) xscale(range(2000 2025)) ///
        ytitle("Informalidad (%)") xtitle("") ///
        note("Fuente: ENEMDU. Elaboración propia. Bandas: IC 95%.", size(vsmall)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ic_informal_sexo, replace)
    graph export "$out_graficos/informalidad_ic_sexo.png", replace width(2200)
    graph export "$out_graficos/informalidad_ic_sexo.pdf", replace
restore

* ---------- 5.4 Informalidad (con RUC) por área ----------
preserve
    keep if indicador == "informal2" & inlist(grupo, "urbano", "rural")
    keep anio grupo estimacion lb ub
    reshape wide estimacion lb ub, i(anio) j(grupo) string

    twoway ///
        (rarea lburbano uburbano anio, color(navy%25) lwidth(none)) ///
        (rarea lbrural  ubrural  anio, color(forest_green%25) lwidth(none)) ///
        (connected estimacionurbano anio, lcolor(navy) mcolor(navy) msymbol(O) msize(vsmall)) ///
        (connected estimacionrural  anio, lcolor(forest_green) mcolor(forest_green) msymbol(O) msize(vsmall)), ///
        legend(order(3 "Urbano" 4 "Rural") position(6) rows(1) size(small)) ///
        ylabel(50(10)100, format(%9.0f) angle(0) grid) ///
        xlabel(2000(2)2025, angle(90) labsize(small)) xscale(range(2000 2025)) ///
        ytitle("Informalidad (%)") xtitle("") ///
        note("Fuente: ENEMDU. Elaboración propia. Bandas: IC 95%.", size(vsmall)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ic_informal_area, replace)
    graph export "$out_graficos/informalidad_ic_area.png", replace width(2200)
    graph export "$out_graficos/informalidad_ic_area.pdf", replace
restore

*==================================================================*
**# 6. CONTROL: ¿cuánto pesa el diseño?
*==================================================================*
* deff > 1 indica cuánta precisión se pierde frente a un muestreo
* aleatorio simple. Sirve para justificar por qué no basta con [iw=fexp].

use "$bases_armonizadas/resultados_ic.dta", clear
keep if grupo == "nacional"
table indicador, stat(mean deff) stat(mean ee) stat(mean amplitud) nformat(%9.2f)

di as txt _n "Listo. Resultados en:"
di as txt "  $bases_armonizadas/resultados_ic.dta"
di as txt "  $out_tablas/informalidad_ic.xlsx"
di as txt "  $out_graficos/"

*------------------------------------------------------------------------------*
* 02_indicadores.do — Series corregidas de pobreza laboral (2001-2025)
*------------------------------------------------------------------------------*
* Correcciones respecto del codigo original:
*   1. "scope" quedaba sin definir: cobertura_pobreza salia vacia. Ahora es "nac".
*   2. ocupado ya no imputa 1 a los valores perdidos de la condicion de actividad,
*      y 2018 usa su propia variable (antes quedaba sin condactn -> todos ocupados).
*   3. No se eliminan las observaciones con p24 == 999 de las tasas de pobreza:
*      "no sabe cuantas horas trabaja" no es motivo para excluir a alguien del
*      calculo de pobreza. Ese filtro solo se aplica donde se usan las horas.
*   4. El panel se guarda DESPUES de todas las correcciones, no antes.
*   5. Cada poblacion de referencia escribe en archivos con nombre propio, de modo
*      que la version "ocupados" y la version "con ingreso laboral" no se pisan.
*   6. educacion_superior usa una definicion comparable en toda la serie.
*------------------------------------------------------------------------------*

do "00_config.do"

use "$paneldir/panel_pobreza_laboral.dta", clear

*--- Metadatos ---*
generate str3 cobertura_pobreza = "nac"
label variable cobertura_pobreza "Cobertura de la base usada"

*--- Etiquetas de los grupos ---*
* "export excel" escribe las etiquetas de valor, no los codigos, asi que estas
* etiquetas son los nombres con los que el generador del Word lee cada grupo.
* Cambiarlas obliga a cambiar tambien configuracion.py del boletin automatizado.
label define area_lbl 1 "Urbana" 2 "Rural", replace
label values area area_lbl

label define sexo_lbl 1 "Hombre" 2 "Mujer", replace
label values sexo sexo_lbl

label define educsup_lbl 0 "Sin educación superior" 1 "Con educación superior", replace
label values educsup_ok   educsup_lbl
label values educsup_orig educsup_lbl

*--- Grupos de edad ---*
generate byte age_cat = .
replace age_cat = 1 if inrange(edad, 18, 29)
replace age_cat = 2 if inrange(edad, 30, 64)
replace age_cat = 3 if inrange(edad, 65, 97)
label define age_cat_lbl 1 "18-29" 2 "30-64" 3 "65+", replace
label values age_cat age_cat_lbl
label variable age_cat "Grupo de edad"

*--- Horas trabajadas: 999 = "no sabe". Se marca como perdido en lugar de
*--- eliminar la observacion completa del calculo de pobreza.              ---*
generate double horas = p24
replace horas = . if p24 == 999 | p24 >= 999
label variable horas "Horas trabajadas a la semana (999 = no sabe -> perdido)"

compress
save "$paneldir/panel_pobreza_laboral_final.dta", replace

*------------------------------------------------------------------------------*
* Series. Dos poblaciones de referencia, con nombres de archivo distintos:
*   ocupados  -> ocupado_ok == 1        (definicion del boletin)
*   inglab    -> !missing(ing_lab)      (variante con ingreso laboral observado)
*------------------------------------------------------------------------------*

foreach pob in total ocupados inglab {

    if "`pob'" == "total"    local filtro ""
    if "`pob'" == "ocupados" local filtro "& ocupado_ok == 1"
    if "`pob'" == "inglab"   local filtro "& !missing(ing_lab)"

    foreach dim in nacional area sexo edad educ {

        if "`dim'" == "nacional" local byv ""
        if "`dim'" == "area"     local byv "area"
        if "`dim'" == "sexo"     local byv "sexo"
        if "`dim'" == "edad"     local byv "age_cat"
        if "`dim'" == "educ"     local byv "educsup_ok"

        local cond "pobreza < . & fexp < . `filtro'"
        if "`byv'" != "" local cond "`cond' & `byv' < ."

        preserve
        collapse (mean) tasa_pobreza = pobreza (rawsum) n_casos = fexp ///
            [iw = fexp] if `cond', by(anio `byv')

        generate tasa_pobreza_pct = 100 * tasa_pobreza
        label variable tasa_pobreza_pct "Pobreza (%)"

        export excel using "$outdir/pobreza_`pob'_`dim'.xlsx", ///
            replace firstrow(var)
        restore
    }
}

display as text _n "Series corregidas exportadas a: $outdir"

*------------------------------------------------------------------------------*
* Graficos del boletin (poblacion: ocupados), con la serie completa en el eje X
*------------------------------------------------------------------------------*

* Grafico 9: evolucion nacional
preserve
collapse (mean) t = pobreza [iw = fexp] if pobreza < . & fexp < . & ocupado_ok == 1, by(anio)
generate tasa = 100 * t
generate lbl = tasa if inlist(anio, 2001, 2009, 2017, 2025)
format lbl %9.1f

twoway (connected tasa anio, lcolor(maroon) lwidth(medthick) msymbol(circle) mcolor(maroon)) ///
       (scatter lbl anio, msymbol(none) mlabel(lbl) mlabposition(12) ///
            mlabcolor(maroon) mlabsize(vsmall)), ///
    xtitle("") ytitle("Pobreza (%)") ///
    ylabel(0(10)60, angle(horizontal)) xlabel(2001(2)2025, angle(90)) ///
    legend(off) name(g9, replace) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$outdir/g09_pobreza_laboral_nacional.png", replace width(2400)
restore

* Grafico 10: por area
preserve
collapse (mean) t = pobreza [iw = fexp] ///
    if pobreza < . & fexp < . & ocupado_ok == 1 & area < ., by(anio area)
generate tasa = 100 * t
generate lbl_u = tasa if area == 1 & inlist(anio, 2001, 2009, 2017, 2025)
generate lbl_r = tasa if area == 2 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_u lbl_r %9.1f

twoway (connected tasa anio if area == 1, lcolor(navy) lwidth(medthick) mcolor(navy)) ///
       (connected tasa anio if area == 2, lcolor(maroon) lwidth(medthick) mcolor(maroon)) ///
       (scatter lbl_u anio, msymbol(none) mlabel(lbl_u) mlabposition(6) mlabcolor(navy) mlabsize(vsmall)) ///
       (scatter lbl_r anio, msymbol(none) mlabel(lbl_r) mlabposition(12) mlabcolor(maroon) mlabsize(vsmall)), ///
    xtitle("") ytitle("Pobreza (%)") ///
    ylabel(0(10)80, angle(horizontal)) xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "Urbana" 2 "Rural") position(6) rows(1)) name(g10, replace) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$outdir/g10_pobreza_laboral_area.png", replace width(2400)
restore

* Grafico 11: por educacion superior
preserve
collapse (mean) t = pobreza [iw = fexp] ///
    if pobreza < . & fexp < . & ocupado_ok == 1 & educsup_ok < ., by(anio educsup_ok)
generate tasa = 100 * t
generate lbl_0 = tasa if educsup_ok == 0 & inlist(anio, 2001, 2009, 2017, 2025)
generate lbl_1 = tasa if educsup_ok == 1 & inlist(anio, 2001, 2009, 2017, 2025)
format lbl_0 lbl_1 %9.1f

twoway (connected tasa anio if educsup_ok == 0, lcolor(navy) lwidth(medthick) mcolor(navy)) ///
       (connected tasa anio if educsup_ok == 1, lcolor(maroon) lwidth(medthick) mcolor(maroon)) ///
       (scatter lbl_0 anio, msymbol(none) mlabel(lbl_0) mlabposition(12) mlabcolor(navy) mlabsize(vsmall)) ///
       (scatter lbl_1 anio, msymbol(none) mlabel(lbl_1) mlabposition(6) mlabcolor(maroon) mlabsize(vsmall)), ///
    xtitle("") ytitle("Pobreza (%)") ///
    ylabel(0(10)60, angle(horizontal)) xlabel(2001(2)2025, angle(90)) ///
    legend(order(1 "Sin educacion superior" 2 "Con educacion superior") position(6) rows(1)) ///
    name(g11, replace) graphregion(color(white)) plotregion(color(white))
graph export "$outdir/g11_pobreza_laboral_educacion.png", replace width(2400)
restore

display as text _n "Graficos exportados a: $outdir"

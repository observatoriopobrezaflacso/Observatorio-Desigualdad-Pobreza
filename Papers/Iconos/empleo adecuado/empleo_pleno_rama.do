*==============================================================================
* Educación universitaria y empleo pleno/adecuado por rama de actividad
* ENEMDU (INEC) 2001, 2010, 2011 y 2024 — ramas CIIU 4.0 homogeneizadas
*
*   1. Parámetros y utilidades      4. Crecimiento del empleo (pares de años)
*   2. Base rama x año              5. Educación y empleo pleno (por año)
*   3. Etiquetas de ramas           6. Salidas
*==============================================================================

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off

*------------------------------------------------ 1. Parámetros y utilidades --
global limpias "$gd/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global root    "$gd/Papers/Íconos"

local anios  2001 2010 2011 2024      // años comparados
local pares  2001-2010 2011-2024 2001-2024
local ntop   8                        // ramas mostradas en los gráficos de barras
local filtro 0                        // 0 = nacional, 1 = urbano, 2 = rural
global minobs 50                      // mínimo de casos por rama-año en las regresiones

local ambito : word `=`filtro'+1' of nacional urbano rural
global out "$root/outputs/rama_educ/`ambito'"
cap mkdir "$root/outputs"
cap mkdir "$root/outputs/rama_educ"
cap mkdir "$out"

* Estilo común y notas al pie reutilizadas por todos los gráficos.
* Las notas deben ir en líneas cortas: Stata no las parte y una línea larga
* desplaza y recorta el resto del gráfico.
global gopts  graphregion(color(white)) plotregion(color(white)) scheme(s2color)
global fuente "Fuente: ENEMDU (INEC), ponderada por el factor de expansión. Ámbito: `ambito'."
global defs   "Empleo pleno/adecuado: condición de actividad = 1. Universitario: superior universitario o posgrado."
global cav01  "En 2001 el nivel 'superior' no distingue universitario de no universitario."

* Exporta la figura activa en pdf/gph/png (en batch el png se obtiene del pdf)
cap program drop savefig
program define savefig
    args f
    graph export "${out}/`f'.pdf", replace
    graph save   "${out}/`f'.gph", replace
    cap graph export "${out}/`f'.png", replace width(2200)
    if _rc shell sips -s format png --resampleWidth 2200 "${out}/`f'.pdf" ///
        --out "${out}/`f'.png" > /dev/null 2>&1
end

* Dispersión ponderada por empleo + recta MCO, con la pendiente en la leyenda.
* Con la opción -compacto- omite leyenda y notas (versión para graph combine)
* y no exporta el archivo.
cap program drop fig_scatter
program define fig_scatter
    syntax varlist(min=2 max=2) [if], peso(varname) archivo(string) ///
        title(string) [ subtitle(string) xtitle(string) ytitle(string) ///
        xlab(string) ylab(string) nombre(varname) nrot(integer 5) ///
        nesq(integer 2) nota(string) cero compacto ]

    gettoken y x : varlist
    marksample touse
    markout `touse' `y' `x' `peso'

    qui reg `y' `x' [aweight=`peso'] if `touse'
    local b  = strtrim("`: di %6.2f _b[`x']'")
    local se = strtrim("`: di %6.2f _se[`x']'")
    local r2 = strtrim("`: di %5.2f e(r2)'")
    local nr = e(N)

    * Rótulos: las `nrot' observaciones de mayor peso —las que mandan en el
    * ajuste— más las `nesq' más extremas hacia la esquina superior derecha,
    * que suelen ser pequeñas pero son las que dan sentido a la pendiente.
    * La posición se adapta: centrada dentro de los círculos grandes, y a la
    * izquierda del punto en la mitad derecha del gráfico para no salirse.
    local rotulos ""
    local nrecta 2                            // nº de plot de la recta de ajuste
    if "`nombre'" != "" {
        tempvar rw xr yr resq pos etiq
        qui egen `rw' = rank(-`peso') if `touse', unique
        qui egen `xr' = rank(`x')     if `touse'      // ranking: evita que la
        qui egen `yr' = rank(`y')     if `touse'      // escala de un eje mande
        qui egen `resq' = rank(-(`xr' + `yr')) if `touse', unique
        qui clonevar `etiq' = `nombre'
        qui replace `etiq' = "" if !`touse' | (`rw' > `nrot' & `resq' > `nesq')

        qui sum `x' if `touse'
        local xmed = (r(min) + r(max))/2
        local xlo  = r(min) + 0.15*(r(max) - r(min))   // franjas donde un rótulo
        local xhi  = r(max) - 0.15*(r(max) - r(min))   // centrado se saldría
        qui sum `peso' if `touse'
        local grande = 0.35*r(max)
        qui gen byte `pos' = cond(`peso' >= `grande' & inrange(`x', `xlo', `xhi'), 0, ///
                                  cond(`x' > `xmed', 9, 3))

        local rotulos = "(scatter `y' `x' if `touse', msymbol(none) mlabel(`etiq')" + ///
            " mlabsize(vsmall) mlabcolor(gs5) mlabvposition(`pos') mlabgap(*1.5))"
        local nrecta 3
    }
    local cero = cond("`cero'"=="", "", "yline(0, lcolor(gs9) lpattern(dash))")
    local xlab = cond("`xlab'"=="", "", "xlabel(`xlab')")

    * msize(*#) reescala los símbolos sin perder la proporcionalidad del peso
    local msz = cond("`compacto'"=="", "*0.7", "*0.45")

    if "`compacto'" != "" {
        local subtitle "pendiente = `b' (EE `se')"
        local leg  legend(off)
        local note note("")
    }
    else {
        local leg legend(order(1 "Rama de actividad (tamaño proporcional al empleo)" ///
                               `nrecta' "Ajuste MCO ponderado: pendiente = `b' (EE `se')") ///
                         cols(1) size(vsmall) region(lstyle(none)))
        local note note("Pendiente por MCO ponderado por el empleo de la rama." ///
                        "R2 = `r2'. `nr' ramas incluidas (mínimo ${minobs} casos por rama-año)." ///
                        "${fuente}" "${defs}" "`nota'", size(vsmall))
    }

    twoway ///
      (scatter `y' `x' [aweight=`peso'] if `touse', ///
            msymbol(Oh) mcolor(navy) msize(`msz')) ///
      `rotulos' ///
      (lfit `y' `x' [aweight=`peso'] if `touse', lcolor(cranberry)) ///
      , title("`title'", size(medium)) subtitle("`subtitle'", size(small)) ///
        xtitle("`xtitle'", size(small)) ytitle("`ytitle'", size(small)) ///
        `xlab' ylabel(`ylab', angle(0) grid glcolor(gs14)) `cero' ///
        `leg' `note' xsize(7.5) ysize(5) $gopts name(`archivo', replace)

    if "`compacto'" == "" savefig "`archivo'"
end

*----------------------------------------------------- 2. Base rama x año -----
* Cada año trae su propia variable educativa y sus propios códigos de condición
* de actividad para la población NO ocupada, que se excluye del denominador:
*   2001      nivinst  6-7 = superior/posgrado   condact 7,8,9 = inact./menores/indet.
*   2010-2011 p10a     9-10 = univ./posgrado     condact 7,8   = inactividad/menores
*   2024      p10a     9-10 = univ./posgrado     condact 0,9   = menores/inactivos

tempfile pool
clear
save `pool', emptyok

foreach y of local anios {
    local educ   = cond(`y'==2001, "nivinst", "p10a")
    local univ   = cond(`y'==2001, "6, 7", "9, 10")
    local noocup = cond(`y'==2001, "7, 8, 9", cond(`y'==2024, "0, 9", "7, 8"))

    use rama1 fexp area condact `educ' using "$limpias/empleo`y'_isic4.dta", clear
    if `filtro' keep if area == `filtro'

    gen int  anio  = `y'
    gen byte univ  = inlist(`educ', `univ')
    gen byte pleno = (condact == 1) if !inlist(condact, `noocup') & !missing(condact)

    keep if !missing(rama1, pleno, fexp)   // ocupados con rama y condición válidas
    keep anio rama1 fexp univ pleno
    append using `pool'
    save `pool', replace
}

use `pool', clear
gen double emp       = fexp
gen double emp_uni   = fexp * univ
gen double emp_pleno = fexp * pleno

collapse (sum) emp emp_uni emp_pleno (count) obs = fexp, by(rama1 anio)

gen double emp_nouni = emp - emp_uni
gen double p_uni     = 100 * emp_uni   / emp   // % de ocupados con universidad
gen double p_pleno   = 100 * emp_pleno / emp   // % de ocupados con empleo pleno

reshape wide emp emp_uni emp_nouni emp_pleno p_uni p_pleno obs, i(rama1) j(anio)

*--------------------------------------------------- 3. Etiquetas de ramas ----
label define rama_corta ///
     1 "Agricultura y pesca"    2 "Minas y canteras"      3 "Manufactura"        ///
     4 "Electricidad y gas"     5 "Agua y saneamiento"    6 "Construcción"       ///
     7 "Comercio"               8 "Transporte"            9 "Alojamiento/comida" ///
    10 "Información y com."    11 "Finanzas y seguros"   12 "Inmobiliarias"      ///
    13 "Prof. y científicas"   14 "Serv. administrativos" 15 "Adm. pública"      ///
    16 "Enseñanza"             17 "Salud"                18 "Arte y recreación"  ///
    19 "Otros servicios"       20 "Hogares empleadores"  21 "Org. extraterrit.", replace
label values rama1 rama_corta
label var rama1 "Rama de actividad (CIIU 4.0)"
decode rama1, gen(rama_txt)     // versión string para rotular los puntos

*------------------------------ 4. Crecimiento del empleo (pares de años) -----
foreach par of local pares {
    local y0  = substr("`par'", 1, 4)
    local y1  = substr("`par'", 6, 4)
    local cav = cond(`y0'==2001, "${cav01}", "")

    * Variación del empleo por nivel educativo
    gen double g_uni_`y0'_`y1'   = 100 * (emp_uni`y1'   / emp_uni`y0'   - 1)
    gen double g_nouni_`y0'_`y1' = 100 * (emp_nouni`y1' / emp_nouni`y0' - 1)
    gen double g_tot_`y0'_`y1'   = 100 * (emp`y1'       / emp`y0'       - 1)

    * Ramas con muestra suficiente en ambos años, y las `ntop' de mayor empleo
    cap drop ok
    cap drop top
    gen byte ok = obs`y0' >= $minobs & obs`y1' >= $minobs & !missing(obs`y0', obs`y1')
    gsort -emp`y1'
    gen byte top = (_n <= `ntop') & ok

    * (a) Barras: crecimiento del empleo por rama y nivel educativo
    graph hbar (asis) g_uni_`y0'_`y1' g_nouni_`y0'_`y1' if top, ///
        over(rama1, sort(emp`y1') descending label(labsize(small))) ///
        blabel(bar, format(%4.0f) size(vsmall)) ///
        yline(0, lcolor(gs9)) ///
        ytitle("Variación del empleo `y0'-`y1' (%)", size(small)) ///
        title("Crecimiento del empleo por rama y nivel educativo", size(medium)) ///
        subtitle("Ecuador `ambito', `y0'-`y1'. Las `ntop' ramas de mayor empleo en `y1'", size(small)) ///
        legend(order(1 "Con educación universitaria" 2 "Sin educación universitaria") ///
               rows(1) size(small) region(lstyle(none))) ///
        note("${fuente}" "${defs}" "`cav'", size(vsmall)) ///
        bar(1, color(navy)) bar(2, color(cranberry)) ///
        xsize(7.5) ysize(5.5) $gopts name(fig_crecimiento_`y0'_`y1', replace)
    savefig "fig_crecimiento_`y0'_`y1'"

    * (b) Dispersión: universitarios en el año base vs crecimiento posterior
    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') ///
        archivo(fig_educ_crecimiento_`y0'_`y1') nombre(rama_txt) cero ///
        title("Ramas más universitarias en `y0' y crecimiento del empleo") ///
        subtitle("Ecuador `ambito', `y0'-`y1'") ///
        xtitle("Ocupados con educación universitaria en `y0' (%)") ///
        ytitle("Variación del empleo total `y0'-`y1' (%)") ///
        nota("`cav'")

    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') compacto cero ///
        archivo(panelc_`y0'_`y1') nombre(rama_txt) nrot(2) nesq(1) ///
        title("`y0'-`y1'") xlab(0(20)80) ///
        xtitle("% con universidad en `y0'") ytitle("Variación del empleo (%)")
}

* Dos paneles arriba y el tercero centrado abajo. graph combine llena la grilla
* por filas y da a todas las celdas de una fila el mismo ancho, así que el
* tercer panel se deja en la celda inferior izquierda —con lo que conserva el
* tamaño de los de arriba— y se corre media celda a la derecha con el editor
* de gráficos. Armarlo con gráficos vacíos a los costados también lo centra,
* pero lo deja a dos tercios del ancho de los otros dos.
graph combine panelc_2001_2010 panelc_2011_2024 panelc_2001_2024, ///
    cols(2) holes(4) imargin(small) ///
    title("Educación universitaria inicial y crecimiento posterior del empleo", size(medium)) ///
    subtitle("Ecuador `ambito'. Cada círculo es una rama (tamaño: empleo del año inicial)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "Ojo: cada panel cubre un horizonte distinto, por lo que la escala vertical no es comparable entre paneles." ///
         "${fuente}" "${defs}" "${cav01}", size(vsmall)) ///
    xsize(9) ysize(7.5) $gopts name(fig_educ_crecimiento_panel, replace)
gr_edit .plotregion1.graph3.xoffset = 25
savefig "fig_educ_crecimiento_panel"

*------------------------------ 5. Educación y empleo pleno (por año) ---------
foreach y of local anios {
    local cav = cond(`y'==2001, "${cav01}", "")

    * versión individual (con leyenda y notas) y versión compacta para el panel
    fig_scatter p_uni`y' p_pleno`y' if obs`y' >= $minobs, peso(emp`y') ///
        archivo(fig_educ_pleno_`y') nombre(rama_txt) xlab(0(20)100) ylab(0(20)100) ///
        title("Educación universitaria y empleo pleno por rama") ///
        subtitle("Ecuador `ambito', `y'") ///
        xtitle("Ocupados con empleo pleno/adecuado (%)") ///
        ytitle("Ocupados con educación universitaria (%)") ///
        nota("`cav'")

    fig_scatter p_uni`y' p_pleno`y' if obs`y' >= $minobs, peso(emp`y') compacto ///
        archivo(panel_`y') nombre(rama_txt) nrot(3) nesq(1) ///
        xlab(0(20)100) ylab(0(20)100) title("`y'") ///
        xtitle("% con empleo pleno/adecuado") ytitle("% con universidad")
}

graph combine panel_2001 panel_2010 panel_2011 panel_2024, cols(2) imargin(small) ///
    title("Educación universitaria y empleo pleno por rama de actividad", size(medium)) ///
    subtitle("Ecuador `ambito', 2001-2024. Cada círculo es una rama (tamaño: empleo total)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "${fuente}" "${defs}" "${cav01}", size(vsmall)) ///
    xsize(9) ysize(7) $gopts name(fig_educ_pleno_panel, replace)
savefig "fig_educ_pleno_panel"

*--------------------------------------------------------------- 6. Salidas ---
cap drop ok
cap drop top

* Nombres autoexplicativos para la base exportada: <concepto>_<año> o
* <concepto>_<año inicial>_<año final>. Los "emp" son personas expandidas por
* el factor de expansión; "casos" son observaciones muestrales sin ponderar.
rename rama1    rama_cod
rename rama_txt rama
label var rama_cod "Código de rama, CIIU 4.0"
label var rama     "Rama de actividad, CIIU 4.0"

foreach y of local anios {
    rename emp`y'       ocupados_`y'
    rename emp_uni`y'   ocupados_univ_`y'
    rename emp_nouni`y' ocupados_nouniv_`y'
    rename emp_pleno`y' ocupados_pleno_`y'
    rename p_uni`y'     pct_univ_`y'
    rename p_pleno`y'   pct_pleno_`y'
    rename obs`y'       casos_`y'
    label var ocupados_`y'        "Ocupados, `y'"
    label var ocupados_univ_`y'   "Ocupados con universidad, `y'"
    label var ocupados_nouniv_`y' "Ocupados sin universidad, `y'"
    label var ocupados_pleno_`y'  "Ocupados con empleo pleno/adecuado, `y'"
    label var pct_univ_`y'        "% de ocupados con universidad, `y'"
    label var pct_pleno_`y'       "% de ocupados con empleo pleno/adecuado, `y'"
    label var casos_`y'           "Casos muestrales sin ponderar, `y'"
}

foreach par of local pares {
    local y0 = substr("`par'", 1, 4)
    local y1 = substr("`par'", 6, 4)
    rename g_uni_`y0'_`y1'   var_pct_ocup_univ_`y0'_`y1'
    rename g_nouni_`y0'_`y1' var_pct_ocup_nouniv_`y0'_`y1'
    rename g_tot_`y0'_`y1'   var_pct_ocup_`y0'_`y1'
    label var var_pct_ocup_univ_`y0'_`y1'   "Variación % ocupados con universidad, `y0'-`y1'"
    label var var_pct_ocup_nouniv_`y0'_`y1' "Variación % ocupados sin universidad, `y0'-`y1'"
    label var var_pct_ocup_`y0'_`y1'        "Variación % ocupados totales, `y0'-`y1'"
}

order rama_cod rama ocupados_* pct_* var_pct_* casos_*
sort rama_cod
format ocupados_* %12.0f
format pct_*      %6.1f
format var_pct_*  %7.1f
compress
save "$out/base_rama_educ.dta", replace

* nolabel: rama_cod sale como código numérico (el nombre ya está en rama)
* datafmt: respeta los formatos de arriba en vez de volcar 15 decimales
export delimited using "$out/base_rama_educ.csv", replace nolabel datafmt

list rama pct_univ_2001 pct_univ_2024 pct_pleno_2001 pct_pleno_2024 ///
     var_pct_ocup_univ_2001_2024 var_pct_ocup_nouniv_2001_2024 ///
     if casos_2024 >= $minobs, noobs

di as txt "Listo. Salidas en: $out"

*==============================================================================
* Educación superior y empleo pleno por rama de actividad
* — VERSIÓN CON LA DEFINICIÓN OFICIAL DE LA BASE (condact) —
* ENEMDU (INEC) 1992, 1999, 2001, 2010, 2011 y 2024 — ramas CIIU 4.0 homogeneizadas
*
*   1. Parámetros y utilidades      3. Etiquetas de ramas
*   2. Base rama x año              4. Crecimiento del empleo (pares de años)
*                                   5. Educación y empleo pleno (por año)
*                                   6. Salidas
*
*------------------------------------------------------------------------------
* QUÉ ES ESTE ARCHIVO
*
* Gemelo de "empleo_pleno_rama.do" que conserva la definición ANTERIOR de
* empleo pleno: la que trae la propia ENEMDU en su variable de condición de
* actividad (condact == 1), sin reconstruirla. Se mantiene para poder cotejar
* los dos criterios: el archivo principal usa el empleo adecuado armonizado de
* "empleo_adecuado_serie.do" (ingreso laboral >= SBU vigente y jornada, con
* umbral y códigos homogeneizados año a año), que sí es comparable a lo largo
* del período; éste usa la clasificación oficial, que NO lo es.
*
* La diferencia entre ambos criterios es grande y cambia de signo: en 1992 la
* clasificación oficial da un empleo pleno bastante mayor que el armonizado y
* en 1999 bastante menor (ver "diagnostico_rama_educ.csv" del archivo
* principal). Salvo que se quiera exactamente la etiqueta que publica el INEC
* en cada año, el archivo a usar es "empleo_pleno_rama.do".
*
* Escribe en su propia carpeta ($root/outputs/rama_educ_condact) para no
* pisar las salidas del archivo principal.
*
*------------------------------------------------------------------------------
* ADVERTENCIAS DE COMPARABILIDAD
*
* - La categoría "empleo pleno" no significa lo mismo en todos los años. Hasta
*   2006 es "ocupados plenos" (esquema viejo, con subempleo visible/invisible e
*   informales aparte); desde 2007 es "Ocupación Plena" y desde 2014 "Empleo
*   Adecuado/Pleno", con una metodología revisada. Ésa es justamente la razón
*   por la que existe la versión armonizada.
* - 1992-1999 la ENEMDU de diciembre es SÓLO URBANA (no existe la variable
*   `area`). Con filtro = 0 esos años son urbanos y 2001-2024 nacionales; para
*   una serie homogénea conviene correr el archivo con filtro = 1.
* - 1992-1999 `nivinst` tiene una única categoría "superior" (código 5): no
*   separa universitario de no universitario ni identifica posgrado. En 2001
*   `nivinst` distingue posgrado (6 y 7) pero no el superior universitario del
*   no universitario; desde 2010 `p10a` sí lo separa (9 y 10). Por eso no se
*   arman pares de crecimiento que crucen esos bloques.
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

* Años comparados y pares de crecimiento. Los pares no cruzan bloques de
* definición educativa (90s / 2001 / 2010+), que no son comparables entre sí.
local anios  1992 1999 2001 2010 2011 2024
local pares  1992-1999 2001-2010 2011-2024 2001-2024

local ntop   8                        // ramas mostradas en los gráficos de barras
local filtro 0                        // 0 = nacional, 1 = urbano, 2 = rural
global minobs 50                      // mínimo de casos por rama-año en las regresiones

local ambito : word `=`filtro'+1' of nacional urbano rural
global out "$root/outputs/rama_educ_condact/`ambito'"
cap mkdir "$root/outputs"
cap mkdir "$root/outputs/rama_educ_condact"
cap mkdir "$out"

* Estilo común y notas al pie reutilizadas por todos los gráficos.
* Las notas deben ir en líneas cortas: Stata no las parte y una línea larga
* desplaza y recorta el resto del gráfico.
global gopts  graphregion(color(white)) plotregion(color(white)) scheme(s2color)
global fuente "Fuente: ENEMDU de diciembre (INEC), ponderada por el factor de expansión. Ámbito: `ambito'."
global defs   "Empleo pleno: condición de actividad de la base = 1 (etiqueta oficial del año, no armonizada)."
global cav01  "En 1992-1999 y 2001 el nivel 'superior' no distingue universitario de no universitario."
global cav90  "1992-1999: muestra sólo urbana y 'superior' sin posgrado identificable."
global cavdef "La etiqueta oficial de empleo pleno cambia de metodología en 2007 y 2014: los niveles no son comparables entre bloques."

* Nota de ámbito mixto: sólo aplica si se mezclan los 90 (urbanos por diseño)
* con años posteriores tomados a nivel nacional.
global cavamb ""
if `filtro' == 0 {
    foreach y of local anios {
        if `y' <= 1999 global cavamb "Ojo: 1992-1999 son urbanos por diseño y 2001-2024 nacionales. Correr con filtro = 1 para homogeneizar."
    }
}
if "${cavamb}" != "" di as error _n "ADVERTENCIA: ${cavamb}"

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
*   1992-1999 nivinst  5     = superior              condact 7,8,9 = inact./menores/otros
*   2001      nivinst  6-7   = superior/posgrado     condact 7,8,9 = inact./menores/indet.
*   2010-2011 p10a     9-10  = univ./posgrado        condact 7,8   = inactividad/menores
*   2024      p10a     9-10  = univ./posgrado        condact 0,9   = menores/inactivos
*
* En 1992-1999 y 2001 condact es el esquema viejo de 10 categorías:
*   0 ocupados no bien definidos   1 ocupados plenos      2 subempleo invisible
*   3 subempleo visible            4 informales           5 desocupados cesantes
*   6 desocupados primera vez      7 inactivos            8 menores
*   9 otros inactivos / indeterminados

tempfile pool
clear
save `pool', emptyok

tempname D
tempfile diag
postfile `D' int anio double pleno_ocup long n_denom long n_rama ///
        using `diag', replace

local anios_ok ""

foreach y of local anios {

    di as txt _n "{hline 60}"
    di as txt "  `y'"
    di as txt "{hline 60}"

    if `y' <= 1999 {
        local educ   "nivinst"
        local univ   "5"
        local noocup "7, 8, 9"
    }
    else if `y' == 2001 {
        local educ   "nivinst"
        local univ   "6, 7"
        local noocup "7, 8, 9"
    }
    else if `y' == 2024 {
        local educ   "p10a"
        local univ   "9, 10"
        local noocup "0, 9"
    }
    else {
        local educ   "p10a"
        local univ   "9, 10"
        local noocup "7, 8"
    }

    * 1992-1999 no traen `area`: la ENEMDU de diciembre es urbana por diseño
    qui use "$limpias/empleo`y'_isic4.dta", clear

    local tiene_area = 0
    capture confirm variable area
    if !_rc {
        local tiene_area = 1
        capture destring area, replace
    }

    if `filtro' & `tiene_area' qui keep if area == `filtro'
    if `filtro' == 2 & !`tiene_area' {
        di as error "  `y' no tiene muestra rural: año omitido."
        continue
    }

    capture confirm variable `educ'
    if _rc {
        di as error "  `y': falta la variable educativa `educ'; año omitido."
        continue
    }

    * las bases traen su propio `anio`; se reescribe para no depender de él
    cap drop anio
    gen int  anio  = `y'
    gen byte univ  = inlist(`educ', `univ') if !missing(`educ')
    gen byte pleno = (condact == 1) if !inlist(condact, `noocup') & !missing(condact)

    qui count if !missing(pleno)
    local n_denom = r(N)
    qui sum pleno [aw = fexp]
    local pleno_r = r(mean) * 100

    keep if !missing(rama1, pleno, fexp)   // ocupados con rama y condición válidas
    local n_rama = _N

    di as txt "  pleno/denominador = " as res %5.2f `pleno_r' as txt "%" ///
              "   denominador = `n_denom'   con rama = `n_rama'"

    post `D' (`y') (`pleno_r') (`n_denom') (`n_rama')

    keep anio rama1 fexp univ pleno
    append using `pool'
    qui save `pool', replace

    local anios_ok "`anios_ok' `y'"
}

postclose `D'

local anios `anios_ok'
local nan : word count `anios'
if `nan' == 0 {
    di as error "No quedó ningún año con datos utilizables."
    exit 459
}

use `pool', clear
gen double emp       = fexp
gen double emp_uni   = fexp * univ
gen double emp_pleno = fexp * pleno

collapse (sum) emp emp_uni emp_pleno (count) obs = fexp, by(rama1 anio)

gen double emp_nouni = emp - emp_uni
gen double p_uni     = 100 * emp_uni   / emp   // % de ocupados con superior
gen double p_pleno   = 100 * emp_pleno / emp   // % de ocupados con empleo pleno

reshape wide emp emp_uni emp_nouni emp_pleno p_uni p_pleno obs, i(rama1) j(anio)

* Una rama puede no aparecer en un año (la 12, inmobiliarias, no existe en los
* 90): la reshape deja missing y la marca -ok- de más abajo la excluye.
foreach y of local anios {
    capture confirm variable obs`y'
    if _rc {
        di as error "El año `y' no dejó ninguna rama; revisar la base."
        exit 459
    }
}

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
* Sólo se conservan los pares cuyos dos años sobrevivieron a la sección 2.
local pares_ok ""
foreach par of local pares {
    local y0 = substr("`par'", 1, 4)
    local y1 = substr("`par'", 6, 4)
    local hay0 : list posof "`y0'" in anios
    local hay1 : list posof "`y1'" in anios
    if `hay0' & `hay1' local pares_ok "`pares_ok' `par'"
    else di as error "Par `par' omitido: falta al menos uno de los dos años."
}
local pares `pares_ok'

local paneles_c ""

foreach par of local pares {
    local y0  = substr("`par'", 1, 4)
    local y1  = substr("`par'", 6, 4)
    local cav = cond(`y0' <= 2001, "${cav01}", "")
    local c90 = cond(`y0' <= 1999, "${cav90}", "")

    * Variación del empleo por nivel educativo
    gen double g_uni_`y0'_`y1'   = 100 * (emp_uni`y1'   / emp_uni`y0'   - 1)
    gen double g_nouni_`y0'_`y1' = 100 * (emp_nouni`y1' / emp_nouni`y0' - 1)
    gen double g_tot_`y0'_`y1'   = 100 * (emp`y1'       / emp`y0'       - 1)

    * Ramas con muestra suficiente en ambos años, y las `ntop' de mayor empleo.
    * El orden se construye sobre una copia con las ramas inválidas al fondo:
    * -gsort -x- pone los missing PRIMERO y se llevaría los primeros puestos.
    cap drop ok
    cap drop top
    gen byte ok = obs`y0' >= $minobs & obs`y1' >= $minobs & !missing(obs`y0', obs`y1')
    tempvar orden
    gen double `orden' = cond(ok & !missing(emp`y1'), emp`y1', -1)
    gsort -`orden'
    gen byte top = (_n <= `ntop') & ok
    drop `orden'

    * (a) Barras: crecimiento del empleo por rama y nivel educativo
    graph hbar (asis) g_uni_`y0'_`y1' g_nouni_`y0'_`y1' if top, ///
        over(rama1, sort(emp`y1') descending label(labsize(small))) ///
        blabel(bar, format(%4.0f) size(vsmall)) ///
        yline(0, lcolor(gs9)) ///
        ytitle("Variación del empleo `y0'-`y1' (%)", size(small)) ///
        title("Crecimiento del empleo por rama y nivel educativo", size(medium)) ///
        subtitle("Ecuador `ambito', `y0'-`y1'. Las `ntop' ramas de mayor empleo en `y1'", size(small)) ///
        legend(order(1 "Con educación superior" 2 "Sin educación superior") ///
               rows(1) size(small) region(lstyle(none))) ///
        note("${fuente}" "${defs}" "`cav'" "`c90'" "${cavamb}", size(vsmall)) ///
        bar(1, color(navy)) bar(2, color(cranberry)) ///
        xsize(7.5) ysize(5.5) $gopts name(fig_crecimiento_`y0'_`y1', replace)
    savefig "fig_crecimiento_`y0'_`y1'"

    * (b) Dispersión: con superior en el año base vs crecimiento posterior
    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') ///
        archivo(fig_educ_crecimiento_`y0'_`y1') nombre(rama_txt) cero ///
        title("Ramas con más educación superior en `y0' y crecimiento del empleo") ///
        subtitle("Ecuador `ambito', `y0'-`y1'") ///
        xtitle("Ocupados con educación superior en `y0' (%)") ///
        ytitle("Variación del empleo total `y0'-`y1' (%)") ///
        nota("`cav' `c90'")

    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') compacto cero ///
        archivo(panelc_`y0'_`y1') nombre(rama_txt) nrot(2) nesq(1) ///
        title("`y0'-`y1'") xlab(0(20)80) ///
        xtitle("% con superior en `y0'") ytitle("Variación del empleo (%)")

    local paneles_c "`paneles_c' panelc_`y0'_`y1'"
}

* Con tres paneles: dos arriba y el tercero centrado abajo. graph combine llena
* la grilla por filas y da a todas las celdas de una fila el mismo ancho, así
* que el tercer panel se deja en la celda inferior izquierda —con lo que
* conserva el tamaño de los de arriba— y se corre media celda a la derecha con
* el editor de gráficos. Armarlo con gráficos vacíos a los costados también lo
* centra, pero lo deja a dos tercios del ancho de los otros dos.
local npc : word count `paneles_c'
local layout "cols(2)"
if `npc' == 3 local layout "cols(2) holes(4)"

graph combine `paneles_c', `layout' imargin(small) ///
    title("Educación superior inicial y crecimiento posterior del empleo", size(medium)) ///
    subtitle("Ecuador `ambito'. Cada círculo es una rama (tamaño: empleo del año inicial)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "Ojo: cada panel cubre un horizonte distinto, por lo que la escala vertical no es comparable entre paneles." ///
         "${fuente}" "${defs}" "${cav01}" "${cav90}" "${cavamb}", size(vsmall)) ///
    xsize(9) ysize(7.5) $gopts name(fig_educ_crecimiento_panel, replace)
if `npc' == 3 gr_edit .plotregion1.graph3.xoffset = 25
savefig "fig_educ_crecimiento_panel"

*------------------------------ 5. Educación y empleo pleno (por año) ---------
local paneles_a ""

foreach y of local anios {
    local cav = cond(`y' <= 2001, "${cav01}", "")
    local c90 = cond(`y' <= 1999, "${cav90}", "")

    * versión individual (con leyenda y notas) y versión compacta para el panel
    fig_scatter p_uni`y' p_pleno`y' if obs`y' >= $minobs & !missing(obs`y'), peso(emp`y') ///
        archivo(fig_educ_pleno_`y') nombre(rama_txt) xlab(0(20)100) ylab(0(20)100) ///
        title("Educación superior y empleo pleno por rama") ///
        subtitle("Ecuador `ambito', `y'") ///
        xtitle("Ocupados con empleo pleno (%)") ///
        ytitle("Ocupados con educación superior (%)") ///
        nota("`cav' `c90'")

    fig_scatter p_uni`y' p_pleno`y' if obs`y' >= $minobs & !missing(obs`y'), peso(emp`y') compacto ///
        archivo(panel_`y') nombre(rama_txt) nrot(3) nesq(1) ///
        xlab(0(20)100) ylab(0(20)100) title("`y'") ///
        xtitle("% con empleo pleno") ytitle("% con superior")

    local paneles_a "`paneles_a' panel_`y'"
}

* Hasta cuatro años caben en dos columnas; con más, tres columnas mantienen
* legibles los rótulos sin estirar el alto de la lámina.
local cols = cond(`nan' <= 4, 2, 3)
local xs   = cond(`cols' == 2, 9, 12)

graph combine `paneles_a', cols(`cols') imargin(small) ///
    title("Educación superior y empleo pleno por rama de actividad", size(medium)) ///
    subtitle("Ecuador `ambito'. Cada círculo es una rama (tamaño: empleo total)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "${fuente}" "${defs}" "${cav01}" "${cav90}" "${cavdef}" "${cavamb}", size(vsmall)) ///
    xsize(`xs') ysize(7) $gopts name(fig_educ_pleno_panel, replace)
savefig "fig_educ_pleno_panel"

*--------------------------------------------------------------- 6. Salidas ---
cap drop ok
cap drop top

* Nombres autoexplicativos para la base exportada: <concepto>_<año> o
* <concepto>_<año inicial>_<año final>. Los "ocupados" son personas expandidas
* por el factor de expansión; "casos" son observaciones muestrales sin ponderar.
rename rama1    rama_cod
rename rama_txt rama
label var rama_cod "Código de rama, CIIU 4.0"
label var rama     "Rama de actividad, CIIU 4.0"

foreach y of local anios {
    rename emp`y'       ocupados_`y'
    rename emp_uni`y'   ocupados_sup_`y'
    rename emp_nouni`y' ocupados_nosup_`y'
    rename emp_pleno`y' ocupados_pleno_`y'
    rename p_uni`y'     pct_sup_`y'
    rename p_pleno`y'   pct_pleno_`y'
    rename obs`y'       casos_`y'
    label var ocupados_`y'        "Ocupados, `y'"
    label var ocupados_sup_`y'    "Ocupados con educación superior, `y'"
    label var ocupados_nosup_`y'  "Ocupados sin educación superior, `y'"
    label var ocupados_pleno_`y'  "Ocupados con empleo pleno (condact = 1), `y'"
    label var pct_sup_`y'         "% de ocupados con educación superior, `y'"
    label var pct_pleno_`y'       "% de ocupados con empleo pleno (condact = 1), `y'"
    label var casos_`y'           "Casos muestrales sin ponderar, `y'"
}

foreach par of local pares {
    local y0 = substr("`par'", 1, 4)
    local y1 = substr("`par'", 6, 4)
    rename g_uni_`y0'_`y1'   var_pct_ocup_sup_`y0'_`y1'
    rename g_nouni_`y0'_`y1' var_pct_ocup_nosup_`y0'_`y1'
    rename g_tot_`y0'_`y1'   var_pct_ocup_`y0'_`y1'
    label var var_pct_ocup_sup_`y0'_`y1'   "Variación % ocupados con superior, `y0'-`y1'"
    label var var_pct_ocup_nosup_`y0'_`y1' "Variación % ocupados sin superior, `y0'-`y1'"
    label var var_pct_ocup_`y0'_`y1'       "Variación % ocupados totales, `y0'-`y1'"
}

order rama_cod rama ocupados_* pct_* var_pct_* casos_*
sort rama_cod
format ocupados_* %12.0f
format pct_*      %6.1f
format var_pct_*  %7.1f
compress
save "$out/base_rama_educ_condact.dta", replace

* nolabel: rama_cod sale como código numérico (el nombre ya está en rama)
* datafmt: respeta los formatos de arriba en vez de volcar 15 decimales
export delimited using "$out/base_rama_educ_condact.csv", replace nolabel datafmt

local y_ini : word 1 of `anios'
local y_fin : word `nan' of `anios'

di as txt _n "{hline 78}"
di as txt "RAMAS: educación superior y empleo pleno oficial, `y_ini' vs `y_fin'"
di as txt "{hline 78}"
list rama pct_sup_`y_ini' pct_sup_`y_fin' pct_pleno_`y_ini' pct_pleno_`y_fin' ///
     if casos_`y_fin' >= $minobs & !missing(casos_`y_fin'), noobs

*--- diagnóstico: tasa global por año, para cotejar con la versión armonizada
preserve
    use `diag', clear
    label var anio       "Año"
    label var pleno_ocup "Empleo pleno oficial (% del denominador del año)"
    label var n_denom    "Observaciones en el denominador (no inactivos)"
    label var n_rama     "Observaciones con rama válida"
    format pleno_ocup %6.2f

    di as txt _n "{hline 78}"
    di as txt "DIAGNÓSTICO (definición oficial de la base)"
    di as txt "{hline 78}"
    list, sep(0) noobs

    save "$out/diagnostico_rama_educ_condact.dta", replace
    export delimited using "$out/diagnostico_rama_educ_condact.csv", replace datafmt
restore

di as txt _n "Listo. Salidas en: $out"

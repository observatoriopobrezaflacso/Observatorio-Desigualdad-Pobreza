*------------------------------------------------------------------------------*
* 01_panel.do — Construye el panel armonizado 2001-2025 de pobreza laboral
*------------------------------------------------------------------------------*
* Guarda DOS juegos de insumos:
*   (a) las versiones corregidas  (sufijo _ok)
*   (b) las versiones tal como las produce el codigo original (sufijo _orig)
* Esto permite cuantificar el efecto de cada error sin volver a leer las bases.
*
* Mapa real de la condicion de actividad en las bases (verificado):
*   2001-2005  condact  (clasificacion ANTIGUA, 0/1-8; ocupado = 0..4)
*   2007-2013  CONDACT + CONDACTN  (MAYUSCULAS)
*   2014-2015  condact + condactn
*   2016-2017  condactn  unicamente
*   2018-2025  condact   unicamente, pero con la clasificacion NUEVA (0-9)
* En la clasificacion NUEVA ocupado = 1..6 (no ocupado = 0,7,8,9).
*------------------------------------------------------------------------------*

do "00_config.do"

*--- Lineas de pobreza anuales (diciembre, precios corrientes) ---*
tempfile lineas
import excel using "$lineas_xlsx", clear
rename A anio
rename C linea_pobreza
keep anio linea_pobreza
foreach v in anio linea_pobreza {
    capture confirm numeric variable `v'
    if _rc destring `v', replace force
}
drop if missing(anio) | missing(linea_pobreza)
duplicates drop anio, force
save `lineas', replace

*--- Procesamiento anio por anio ---*
local anios_all
foreach y of numlist $anios {
    local anios_all `anios_all' `y'
}

* Las variables de diseno muestral cambian de tipo entre anios (plan_muestreo y
* estrato son string en algunos, numericas en otros). Se guardan todas como
* string para que el append nunca falle por conflicto de tipos.
local svyvars ciudad zona sector plan_muestreo estrato upm

foreach y of local anios_all {

    local infile "$nacional/ing_perca_`y'_nac_precios2000.dta"

    capture confirm file "`infile'"
    if _rc {
        display as error "No existe el archivo: `infile'"
        error 601
    }

    * Linea de pobreza del anio
    quietly use `lineas', clear
    quietly keep if anio == `y'
    if _N != 1 {
        display as error "No hay linea de pobreza unica para `y'"
        error 459
    }
    local lp = linea_pobreza[1]

    * Solo se cargan las variables que existen en ese anio
    quietly describe using "`infile'", varlist
    local vl `r(varlist)'
    local loadv
    foreach v in ingtot_per ing_lab fexp area sexo p02 edad p03 p24 hortrasa ///
                 p25 p27 p28 nivinst nnivins p10a ///
                 condact condactn CONDACT CONDACTN `svyvars' {
        local h : list posof "`v'" in vl
        if `h' local loadv `loadv' `v'
    }

    quietly use `loadv' using "`infile'", clear
    quietly generate int anio = `y'

    *--- Armonizacion de nombres ---*
    capture confirm variable hortrasa
    if !_rc rename hortrasa p24

    capture confirm variable p03
    if !_rc rename p03 edad

    capture confirm variable sexo
    if _rc {
        capture confirm variable p02
        if !_rc  generate byte sexo = p02
        else     generate byte sexo = .
    }

    foreach v in p24 edad p25 p27 p28 {
        capture confirm variable `v'
        if _rc quietly generate double `v' = .
    }

    *--- Condicion de actividad: version CORREGIDA ---*
    * cond_nueva = clasificacion nueva (0-9); cond_vieja = clasificacion antigua
    quietly generate byte cond_nueva = .
    quietly generate byte cond_vieja = .

    if inrange(`y', 2001, 2005) {
        quietly replace cond_vieja = condact
    }
    else if inrange(`y', 2007, 2013) {
        quietly replace cond_nueva = CONDACTN
        quietly replace cond_vieja = CONDACT
    }
    else if inrange(`y', 2014, 2015) {
        quietly replace cond_nueva = condactn
        quietly replace cond_vieja = condact
    }
    else if inrange(`y', 2016, 2017) {
        quietly replace cond_nueva = condactn
    }
    else if `y' >= 2018 {
        quietly replace cond_nueva = condact
    }

    * Ocupado corregido: nunca imputa 1 a los valores perdidos.
    quietly generate byte ocupado_ok = .
    quietly replace ocupado_ok = inrange(cond_nueva, 1, 6) if !missing(cond_nueva)
    quietly replace ocupado_ok = inrange(cond_vieja, 0, 4) ///
        if missing(cond_nueva) & !missing(cond_vieja)

    *--- Condicion de actividad: replica EXACTA del codigo original ---*
    * El original hacia: cap confirm variable CONDACT / if !_rc rename CONDACTN*, lower
    * y despues keep ... condact*  (patron sensible a mayusculas).
    quietly generate byte condact_orig  = .
    quietly generate byte condactn_orig = .

    capture confirm variable CONDACTN
    if !_rc quietly replace condactn_orig = CONDACTN          // 2007-2013
    capture confirm variable condactn
    if !_rc quietly replace condactn_orig = condactn          // 2014-2017
    capture confirm variable condact
    if !_rc quietly replace condact_orig = condact            // 2001-2005, 2014-2015, 2018-2025
    * CONDACT en mayusculas se perdia con "keep condact*": se replica ese descarte.

    *--- Educacion superior ---*
    * Codigos verificados:
    *   2001        nivinst: 6=superior, 7=postgrado
    *   2003-2005   nivinst: 8=superior no univ., 9=superior univ., 10=postgrado
    *   2007+       p10a   : 8=superior no univ., 9=superior univ., 10=postgrado
    * _ok    = educacion superior en sentido amplio (incluye superior no universitaria),
    *          comparable con el codigo 6 de 2001.
    * _orig  = lo que hacia el codigo original (excluia superior no universitaria
    *          desde 2003, pero la incluia en 2001).
    quietly generate byte educsup_ok   = .
    quietly generate byte educsup_orig = .

    if `y' == 2001 {
        quietly replace educsup_ok   = inlist(nivinst, 6, 7) if !missing(nivinst)
        quietly replace educsup_orig = inlist(nivinst, 6, 7) if !missing(nivinst)
    }
    else if inrange(`y', 2003, 2005) {
        quietly replace educsup_ok   = inlist(nivinst, 8, 9, 10) if !missing(nivinst)
        quietly replace educsup_orig = inlist(nivinst, 9, 10)    if !missing(nivinst)
    }
    else {
        quietly replace educsup_ok   = inlist(p10a, 8, 9, 10) if !missing(p10a)
        quietly replace educsup_orig = inlist(p10a, 9, 10)    if !missing(p10a)
    }

    *--- Pobreza ---*
    * ingtot_per esta en precios corrientes, igual que linea_pobreza_dic. Coherente.
    quietly generate double linea_pobreza   = `lp'
    quietly generate double ingreso_pobreza = ingtot_per
    quietly generate byte   pobreza = (ingreso_pobreza < linea_pobreza) ///
        if !missing(ingreso_pobreza)

    *--- Variables de diseno muestral presentes ese anio ---*
    foreach v of local svyvars {
        capture confirm variable `v'
        if _rc {
            quietly generate str1 `v' = ""
        }
        else {
            capture confirm string variable `v'
            if _rc quietly tostring `v', replace force
        }
    }

    quietly keep anio fexp sexo area edad p24 p25 p27 p28 ///
                 ing_lab ingtot_per ingreso_pobreza linea_pobreza pobreza ///
                 cond_nueva cond_vieja ocupado_ok condact_orig condactn_orig ///
                 educsup_ok educsup_orig `svyvars'

    quietly compress
    tempfile a`y'
    quietly save `a`y''

    quietly count if pobreza == 1
    local np = r(N)
    quietly count if !missing(pobreza)
    local nv = r(N)
    display as text "`y': linea = " as result %7.2f `lp' ///
        as text "  pobres/validos = " as result %9.0fc `np' as text " / " as result %9.0fc `nv'
}

*--- Union de todos los anios ---*
clear
local first 1
foreach y of local anios_all {
    if `first' {
        use `a`y'', clear
        local first 0
    }
    else {
        append using `a`y''
    }
}

*--- Ocupado: replica EXACTA del error original ---*
* El original parchaba condactn solo para 2019-2025, dejando 2018 sin condactn,
* y usaba !inlist()/!inrange() sin excluir los valores perdidos (missing -> 1).
generate byte condactn_bug = condactn_orig
replace condactn_bug = condact_orig if inrange(anio, 2019, 2025)

generate byte ocupado_orig = !inlist(condactn_bug, 0, 7, 8, 9) if anio >= 2007
replace ocupado_orig = !inrange(condact_orig, 5, 8) if anio < 2007

label variable ocupado_ok   "Ocupado (corregido)"
label variable ocupado_orig "Ocupado (replica del codigo original)"
label variable educsup_ok   "Educacion superior (amplia, comparable)"
label variable educsup_orig "Educacion superior (definicion del codigo original)"
label variable pobreza      "Ingreso per capita del hogar bajo la linea de pobreza"

label define pobreza_lbl 0 "No pobre" 1 "Pobre", replace
label values pobreza pobreza_lbl

compress
save "$paneldir/panel_pobreza_laboral.dta", replace

display as text _n "Panel guardado: $paneldir/panel_pobreza_laboral.dta"
tabulate anio, missing

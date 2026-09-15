*------------------------------------------------------------------------------*
* 03_impacto.do — Cuantifica el efecto de cada error sobre los resultados
*------------------------------------------------------------------------------*
* Estrategia: partir de la version corregida y reintroducir UN error a la vez.
* La variante "orig" reproduce exactamente los archivos publicados (verificado
* contra pobreza_evolucion.xlsx y pobreza_laboral.xlsx del 16-jun).
*
* Variantes de la poblacion "ocupados":
*   ok      : correcta
*   e2018   : solo el error de 2018 (condactn ausente, parche desde 2019)
*   emiss   : solo la imputacion de ocupado=1 a los valores perdidos
*   orig    : ambas (replica del codigo publicado)
*------------------------------------------------------------------------------*

do "00_config.do"
use "$paneldir/panel_pobreza_laboral_final.dta", clear

*--- Variantes de "ocupado" que aislan cada error ---*
generate byte ocup_e2018 = ocupado_ok
replace     ocup_e2018 = ocupado_orig if anio == 2018

generate byte ocup_emiss = ocupado_orig
replace     ocup_emiss = ocupado_ok if anio == 2018

tempfile panel
save `panel', replace

*==============================================================================*
* A. Serie nacional de pobreza laboral (ocupados) — Grafico 9
*==============================================================================*
tempfile acum
local first 1

foreach v in ocupado_ok ocup_e2018 ocup_emiss ocupado_orig {
    use `panel', clear
    collapse (mean) t = pobreza [iw = fexp] if pobreza < . & fexp < . & `v' == 1, by(anio)
    generate str12 variante = "`v'"
    generate double tasa = 100 * t
    keep anio variante tasa
    if `first' {
        save `acum', replace
        local first 0
    }
    else {
        append using `acum'
        save `acum', replace
    }
}

* Variante: efecto de "drop if p24 == 999" sobre la serie corregida
use `panel', clear
drop if p24 == 999
collapse (mean) t = pobreza [iw = fexp] if pobreza < . & fexp < . & ocupado_ok == 1, by(anio)
generate str12 variante = "drop999"
generate double tasa = 100 * t
keep anio variante tasa
append using `acum'
save `acum', replace

* Variante: poblacion definida por ing_lab en vez de ocupados (colision de archivos)
use `panel', clear
collapse (mean) t = pobreza [iw = fexp] if pobreza < . & fexp < . & !missing(ing_lab), by(anio)
generate str12 variante = "inglab"
generate double tasa = 100 * t
keep anio variante tasa
append using `acum'
save `acum', replace

use `acum', clear
reshape wide tasa, i(anio) j(variante) string

generate double d_2018   = tasaocup_e2018   - tasaocupado_ok
generate double d_miss   = tasaocup_emiss   - tasaocupado_ok
generate double d_orig   = tasaocupado_orig - tasaocupado_ok
generate double d_drop   = tasadrop999      - tasaocupado_ok
generate double d_inglab = tasainglab       - tasaocupado_ok

format tasa* d_* %9.3f
label variable tasaocupado_ok  "Corregida"
label variable tasaocupado_orig "Original (publicada)"

list anio tasaocupado_ok tasaocupado_orig d_orig d_2018 d_miss d_drop d_inglab, ///
    noobs sep(0) abbreviate(18)

export excel using "$outdir/impacto_serie_nacional.xlsx", replace firstrow(varlabels)

*==============================================================================*
* B. Pobreza laboral por area — Grafico 10
*==============================================================================*
tempfile acum2
local first 1
foreach v in ocupado_ok ocupado_orig {
    use `panel', clear
    collapse (mean) t = pobreza [iw = fexp] ///
        if pobreza < . & fexp < . & `v' == 1 & area < ., by(anio area)
    generate str12 variante = "`v'"
    generate double tasa = 100 * t
    keep anio area variante tasa
    if `first' {
        save `acum2', replace
        local first 0
    }
    else {
        append using `acum2'
        save `acum2', replace
    }
}
use `acum2', clear
reshape wide tasa, i(anio area) j(variante) string
generate double dif = tasaocupado_orig - tasaocupado_ok
format tasa* dif %9.3f
di _n "=== AREA (1=urbana, 2=rural) ==="
list anio area tasaocupado_ok tasaocupado_orig dif, noobs sep(0) abbreviate(18)
export excel using "$outdir/impacto_area.xlsx", replace firstrow(var)

*==============================================================================*
* C. Pobreza laboral por educacion — Grafico 11
*==============================================================================*
tempfile acum3
local first 1
foreach spec in "ocupado_ok educsup_ok ok" "ocupado_orig educsup_orig orig" ///
                "ocupado_ok educsup_orig soloeduc" {
    local ov  : word 1 of `spec'
    local ev  : word 2 of `spec'
    local nm  : word 3 of `spec'
    use `panel', clear
    collapse (mean) t = pobreza [iw = fexp] ///
        if pobreza < . & fexp < . & `ov' == 1 & `ev' < ., by(anio `ev')
    rename `ev' educsup
    generate str12 variante = "`nm'"
    generate double tasa = 100 * t
    keep anio educsup variante tasa
    if `first' {
        save `acum3', replace
        local first 0
    }
    else {
        append using `acum3'
        save `acum3', replace
    }
}
use `acum3', clear
reshape wide tasa, i(anio educsup) j(variante) string
generate double d_total    = tasaorig     - tasaok
generate double d_soloeduc = tasasoloeduc - tasaok
format tasa* d_* %9.3f
di _n "=== EDUCACION SUPERIOR (0=sin, 1=con) ==="
list anio educsup tasaok tasaorig d_total d_soloeduc, noobs sep(0) abbreviate(18)
export excel using "$outdir/impacto_educacion.xlsx", replace firstrow(var)

*==============================================================================*
* D. Composicion de los ocupados pobres en 2025 (cifras 33.8% y 22.5%)
*==============================================================================*
use `panel', clear
keep if anio == 2025 & pobreza == 1 & fexp < .

di _n "=== Cuantos ocupados pobres hay en 2025 segun cada definicion ==="
count if ocupado_ok   == 1
count if ocupado_orig == 1

* --- Version ORIGINAL del fragmento "descriptivos?texto" ---
generate byte cuarenta_orig = p24 >= 40
generate byte a_orig = .
replace a_orig = 1 if inrange(p27, 1, 3) & p28 == 1
replace a_orig = . if inlist(., p27, p28)
replace a_orig = 0 if p27 == 4 | p25 == 9
generate byte b_orig = .
replace b_orig = 1 if cuarenta_orig == 1
replace b_orig = 2 if cuarenta_orig == 0 & a_orig == 1
replace b_orig = 3 if cuarenta_orig == 0 & a_orig == 0

* --- Version CORREGIDA ---
* horas ya excluye el codigo 999 ("no sabe")
generate byte cuarenta_ok = horas >= 40 if !missing(horas)
generate byte a_ok = .
replace a_ok = 0 if p27 == 4 | p25 == 9
replace a_ok = 1 if inrange(p27, 1, 3) & p28 == 1
generate byte b_ok = .
replace b_ok = 1 if cuarenta_ok == 1
replace b_ok = 2 if cuarenta_ok == 0 & a_ok == 1
replace b_ok = 3 if cuarenta_ok == 0 & a_ok == 0

di _n "=== ORIGINAL: b entre ocupados(orig) pobres 2025 ==="
tabulate b_orig if ocupado_orig == 1 [iw = fexp], missing
di _n "=== CORREGIDO: b entre ocupados(ok) pobres 2025 ==="
tabulate b_ok if ocupado_ok == 1 [iw = fexp], missing

di _n "=== p24 == 999 y horas perdidas entre ocupados pobres 2025 ==="
count if ocupado_ok == 1 & p24 == 999
count if ocupado_ok == 1 & missing(p24)

*==============================================================================*
* E. Cuantas observaciones toca cada error
*==============================================================================*
use `panel', clear
di _n "=== Discrepancias ocupado_orig vs ocupado_ok, por anio ==="
generate byte discrepa = (ocupado_orig != ocupado_ok)
tabulate anio discrepa, row nofreq

di _n "=== p24 == 999 por anio (observaciones eliminadas por drop) ==="
generate byte p999 = (p24 == 999)
tabulate anio p999, row nofreq

di _n "=== educsup_orig vs educsup_ok, por anio ==="
generate byte dedu = (educsup_orig != educsup_ok) & !missing(educsup_ok)
tabulate anio dedu, row nofreq

*==============================================================================*
* F. Cifras puntuales citadas en el boletin
*==============================================================================*
use `panel', clear

di _n "=== 2025: % de ocupados pobres SIN educacion superior (boletin: 97.8%) ==="
preserve
keep if anio == 2025 & pobreza == 1 & fexp < .
quietly summarize educsup_orig [iw = fexp] if ocupado_orig == 1 & educsup_orig < .
di "  ORIGINAL  : " %6.2f 100*(1 - r(mean)) "%"
quietly summarize educsup_ok [iw = fexp] if ocupado_ok == 1 & educsup_ok < .
di "  CORREGIDO : " %6.2f 100*(1 - r(mean)) "%"
restore

di _n "=== 2018: cuanta poblacion contaba el codigo original como 'ocupada' ==="
preserve
keep if anio == 2018 & fexp < .
quietly summarize fexp if ocupado_orig == 1
di "  ORIGINAL  : " %12.0fc r(sum) " personas (n = " r(N) ")"
quietly summarize fexp if ocupado_ok == 1
di "  CORREGIDO : " %12.0fc r(sum) " personas (n = " r(N) ")"
quietly summarize fexp
di "  Base 2018 : " %12.0fc r(sum) " personas (n = " r(N) ")"
restore

di _n "=== 2018: composicion de esos 'ocupados' segun la condicion de actividad ==="
preserve
keep if anio == 2018
label define cn_lbl 0 "Menores de 15" 1 "Empleo adecuado" 2 "Subempleo tiempo" ///
    3 "Subempleo ingresos" 4 "Otro empleo no pleno" 5 "Empleo no remunerado" ///
    6 "Empleo no clasificado" 7 "Desempleo abierto" 8 "Desempleo oculto" ///
    9 "Inactivos (PEI)", replace
label values cond_nueva cn_lbl
tabulate cond_nueva if ocupado_orig == 1, missing
restore

di _n "=== Observaciones con p24 == 999 (las que eliminaba el drop) ==="
count if p24 == 999
levelsof anio, local(ys)
foreach y of local ys {
    quietly count if anio == `y' & p24 == 999
    if r(N) > 0 di "  `y': " r(N) " casos"
}

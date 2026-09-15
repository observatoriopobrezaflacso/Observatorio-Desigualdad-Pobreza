*------------------------------------------------------------------------------*
* 04_descriptivos.do — Composicion de los ocupados en situacion de pobreza
*------------------------------------------------------------------------------*
* Produce las dos series que el boletin automatizado cita en el texto:
*   composicion_horas_ocupados_pobres.xlsx  -> reparto por horas trabajadas
*   composicion_educ_ocupados_pobres.xlsx   -> reparto por educacion superior
*
* Version corregida del fragmento suelto "descriptivos?texto".
*
* Correcciones:
*   1. "gen cuarenta_h_mas = p24 >= 40" clasificaba como "40 horas o mas" a todo
*      aquel con p24 perdido, porque en Stata missing >= 40 es verdadero. Sobre
*      los ocupados no cambia nada (todos tienen horas validas), pero sobre
*      cualquier otra poblacion infla el grupo de forma grave: entre TODOS los
*      pobres de 2025 pasaba de 437 a 2,891 casos.
*   2. "replace a = . if inlist(., p27, p28)" era codigo muerto (0 cambios) y
*      ademas estaba colocado antes del "replace a = 0". Se elimina y se ordena
*      como en adec.do: primero el 0, despues el 1.
*   3. Se explicita la restriccion a ocupados, que antes era implicita.
*
* Nota: p25, p27 y p28 solo existen desde 2007, asi que el reparto por horas
* empieza en ese anio. El reparto por educacion cubre toda la serie.
*------------------------------------------------------------------------------*

do "00_config.do"
use "$paneldir/panel_pobreza_laboral_final.dta", clear

local anio_horas 2007   // primer anio con p25/p27/p28

*--- Trabaja 40 horas o mas (horas ya trata el codigo 999 como perdido) ---*
generate byte cuarenta_h_mas = horas >= 40 if !missing(horas)
label variable cuarenta_h_mas "Trabaja 40 horas o mas a la semana"

*--- Desea trabajar mas horas y esta disponible (mismo criterio que adec.do) ---*
generate byte desea_disp = .
replace desea_disp = 0 if p27 == 4 | p25 == 9
replace desea_disp = 1 if inrange(p27, 1, 3) & p28 == 1
label variable desea_disp "Desea trabajar mas horas y esta disponible"

generate byte grupo_horas = .
replace grupo_horas = 1 if cuarenta_h_mas == 1
replace grupo_horas = 2 if cuarenta_h_mas == 0 & desea_disp == 1
replace grupo_horas = 3 if cuarenta_h_mas == 0 & desea_disp == 0
label define grupo_horas_lbl ///
    1 "40 horas o más" ///
    2 "Menos de 40 horas, desea y puede trabajar más" ///
    3 "Menos de 40 horas, no desea o no puede trabajar más", replace
label values grupo_horas grupo_horas_lbl
label variable grupo_horas "Composición por horas trabajadas"

*==============================================================================*
* Reparto por horas trabajadas entre los ocupados pobres
*==============================================================================*
preserve
keep if ocupado_ok == 1 & pobreza == 1 & fexp < . & !missing(grupo_horas)
keep if anio >= `anio_horas'

collapse (sum) personas = fexp, by(anio grupo_horas)
bysort anio: egen double total = total(personas)
generate double porcentaje = 100 * personas / total
drop total
format personas %12.0fc
format porcentaje %6.2f

export excel using "$outdir/composicion_horas_ocupados_pobres.xlsx", ///
    replace firstrow(var)

display as text _n "=== Reparto por horas, ocupados pobres (ultimo anio) ==="
quietly summarize anio
list grupo_horas personas porcentaje if anio == r(max), noobs abbreviate(20)
restore

*==============================================================================*
* Reparto por educacion superior entre los ocupados pobres
*==============================================================================*
preserve
keep if ocupado_ok == 1 & pobreza == 1 & fexp < . & !missing(educsup_ok)

collapse (sum) personas = fexp, by(anio educsup_ok)
bysort anio: egen double total = total(personas)
generate double porcentaje = 100 * personas / total
drop total
format personas %12.0fc
format porcentaje %6.2f

export excel using "$outdir/composicion_educ_ocupados_pobres.xlsx", ///
    replace firstrow(var)

display as text _n "=== Reparto por educación, ocupados pobres (ultimo anio) ==="
quietly summarize anio
list educsup_ok personas porcentaje if anio == r(max), noobs abbreviate(24)
restore

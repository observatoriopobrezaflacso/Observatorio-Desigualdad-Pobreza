/*******************************************************************************
* PROGRAMA SRI — Análisis de Movilidad Económica Intertemporal
*
* Construye un panel longitudinal a partir de las bases de ingresos por año,
* asigna deciles intra-año, estima matrices de transición entre períodos
* consecutivos y calcula medidas resumen de movilidad.
*
* Entrada : ingresos_renta_<año>.dta  (en $dir_data)
* Salida  : Movilidad_Economica.xlsx  y .dta en $dir_out
*******************************************************************************/

clear all
set more off
set maxvar 10000

* ============================================================================
* 1. CONFIGURACIÓN DE RUTAS
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"

global dir_data "$basedir/Resultados/Merged"
global dir_out  "$basedir/Resultados/Movilidad"

capture mkdir "$dir_out"

* ============================================================================
* 2. CONSTRUIR PANEL LONGITUDINAL
* ============================================================================

* --- Detectar años disponibles ---
local years ""
local files_ing : dir "$dir_data" files "ingresos_renta_*.dta"
foreach f of local files_ing {
    if regexm("`f'", "ingresos_renta_([0-9]+)\.dta") {
        local yr = regexs(1)
        local years "`years' `yr'"
    }
}
local years : list sort years

di as text _n "Años disponibles: `years'" _n

* --- Apilar todos los años ---
local first 1
foreach yr of local years {
    use CEDULA_PK anio INGRESOS_TOTAL using "$dir_data/ingresos_renta_`yr'.dta", clear
    if `first' {
        tempfile panel
        save "`panel'", replace
        local first 0
    }
    else {
        append using "`panel'"
        save "`panel'", replace
    }
}

use "`panel'", clear

* --- Filtrar: mantener solo ingresos positivos ---
drop if INGRESOS_TOTAL <= 0 | INGRESOS_TOTAL == .

di as text _n "Observaciones en el panel (ingreso > 0):"
tab anio

* ============================================================================
* 3. CONSTRUCCIÓN DE DECILES INTRA-AÑO
* ============================================================================
*
* Criterio: dentro de cada año t, se ordenan los individuos por INGRESOS_TOTAL
* y se asignan a 10 grupos de igual tamaño (deciles).
* xtile genera grupos 1 (más bajo) a 10 (más alto).
* El ranking es relativo: un individuo puede cambiar de decil entre años.

gen decil = .
levelsof anio, local(all_years)
foreach yr of local all_years {
    xtile temp_d = INGRESOS_TOTAL if anio == `yr', nq(10)
    replace decil = temp_d if anio == `yr'
    drop temp_d
}

label var decil "Decil de ingreso (intra-año)"

save "`panel'", replace

* ============================================================================
* 4. DETERMINAR PARES DE AÑOS CONSECUTIVOS
* ============================================================================

* Construir lista de pares consecutivos
local nyears : word count `years'
local pairs_t0 ""
local pairs_t1 ""

forvalues i = 1/`nyears' {
    local next = `i' + 1
    if `next' <= `nyears' {
        local y0 : word `i' of `years'
        local y1 : word `next' of `years'
        local pairs_t0 "`pairs_t0' `y0'"
        local pairs_t1 "`pairs_t1' `y1'"
    }
}

local npairs : word count `pairs_t0'
di as text _n "Pares de transición: `npairs'"
forvalues i = 1/`npairs' {
    local y0 : word `i' of `pairs_t0'
    local y1 : word `i' of `pairs_t1'
    di as text "  `y0' → `y1'"
}

* ============================================================================
* 5. MATRICES DE TRANSICIÓN
* ============================================================================

* --- Preparar archivo de resultados para matrices ---
tempname mat_post
tempfile mat_file

postfile `mat_post'                              ///
    int(anio_t0 anio_t1)                         ///
    int(decil_t0 decil_t1)                       ///
    long(freq)                                   ///
    double(prob_cond)                            ///
    using "`mat_file'", replace

* --- Preparar archivo de resultados para medidas resumen ---
tempname summ_post
tempfile summ_file

postfile `summ_post'                             ///
    int(anio_t0 anio_t1)                         ///
    double(shorrocks immobility                  ///
        prob_ascendente prob_descendente          ///
        persistencia_d1 persistencia_d10         ///
        rank_rank_beta rank_rank_se              ///
        rank_rank_r2)                            ///
    long(N_panel)                                ///
    using "`summ_file'", replace

* --- Preparar archivo para crecimiento por decil ---
tempname grow_post
tempfile grow_file

postfile `grow_post'                             ///
    int(anio_t0 anio_t1 decil_origen)            ///
    double(media_crec mediana_crec sd_crec        ///
        p25_crec p75_crec)                       ///
    long(N_crec)                                 ///
    using "`grow_file'", replace

* ============================================================================
* 5.1  LOOP POR CADA PAR DE AÑOS
* ============================================================================

forvalues p = 1/`npairs' {

    local y0 : word `p' of `pairs_t0'
    local y1 : word `p' of `pairs_t1'

    di as result _n "========== Transición `y0' → `y1' =========="

    * --- Construir panel pareado ---
    use "`panel'", clear
    keep if anio == `y0'
    rename decil decil_t0
    rename INGRESOS_TOTAL ingreso_t0
    drop anio
    tempfile t0
    save "`t0'", replace

    use "`panel'", clear
    keep if anio == `y1'
    rename decil decil_t1
    rename INGRESOS_TOTAL ingreso_t1
    drop anio
    tempfile t1
    save "`t1'", replace

    use "`t0'", clear
    merge 1:1 CEDULA_PK using "`t1'", keep(3) nogen

    local N_pair = _N
    di as text "  Individuos en ambos años: `N_pair'"

    if `N_pair' < 10 {
        di as error "  Insuficientes observaciones. Se omite este par."
        continue
    }

    * ------------------------------------------------------------------
    * 5.1.1  Matriz de transición
    * ------------------------------------------------------------------

    * Frecuencias
    preserve
    contract decil_t0 decil_t1, freq(freq)

    * Total por decil de origen (para probabilidades condicionales)
    bysort decil_t0: egen total_origen = total(freq)
    gen prob_cond = freq / total_origen

    * Postear resultados
    forvalues i = 1/`=_N' {
        post `mat_post' (`y0') (`y1')                                ///
            (decil_t0[`i']) (decil_t1[`i'])                          ///
            (freq[`i']) (prob_cond[`i'])
    }

    * --- Mostrar matriz en consola ---
    di as text _n "  Matriz de transición (probabilidades condicionales por fila):"
    drop total_origen
    reshape wide prob_cond freq, i(decil_t0) j(decil_t1)

    * Mostrar probabilidades
    di as text "  Decil_t0 |   D1      D2      D3      D4      D5      D6      D7      D8      D9      D10"
    di as text "  ---------+------------------------------------------------------------------------"
    forvalues d = 1/10 {
        local line "     `d'    |"
        forvalues j = 1/10 {
            capture local val = prob_cond`j'[`d']
            if _rc {
                local line "`line'   .   "
            }
            else {
                local val_fmt : di %6.3f `val'
                local line "`line' `val_fmt'"
            }
        }
        di as text "  `line'"
    }
    restore

    * ------------------------------------------------------------------
    * 5.1.2  Medidas resumen de movilidad
    * ------------------------------------------------------------------

    * --- Traza de la matriz (persistencia en la diagonal) ---
    * Inmobilidad = (1/n) * Σ P(i,i) para i=1..10
    * donde P(i,i) es la probabilidad de permanecer en el decil i

    local traza = 0
    forvalues d = 1/10 {
        quietly count if decil_t0 == `d' & decil_t1 == `d'
        local n_diag = r(N)
        quietly count if decil_t0 == `d'
        local n_orig = r(N)
        if `n_orig' > 0 {
            local traza = `traza' + (`n_diag' / `n_orig')
        }
    }
    local immobility = `traza' / 10

    * --- Índice de Shorrocks ---
    * S = (n - traza(P)) / (n - 1)
    * donde n = número de estados (10), traza(P) = Σ P(i,i)
    * S ∈ [0,1]: 0 = inmobilidad perfecta, 1 = movilidad perfecta
    local shorrocks = (10 - `traza') / (10 - 1)

    * --- Persistencia en deciles extremos ---
    quietly count if decil_t0 == 1 & decil_t1 == 1
    local n_d1_stay = r(N)
    quietly count if decil_t0 == 1
    local n_d1 = r(N)
    local persist_d1 = cond(`n_d1' > 0, `n_d1_stay' / `n_d1', .)

    quietly count if decil_t0 == 10 & decil_t1 == 10
    local n_d10_stay = r(N)
    quietly count if decil_t0 == 10
    local n_d10 = r(N)
    local persist_d10 = cond(`n_d10' > 0, `n_d10_stay' / `n_d10', .)

    * --- Probabilidad de movilidad ascendente y descendente ---
    * Ascendente: P(decil_t1 > decil_t0)
    * Descendente: P(decil_t1 < decil_t0)
    quietly count if decil_t1 > decil_t0
    local n_up = r(N)
    quietly count if decil_t1 < decil_t0
    local n_down = r(N)
    local prob_up   = `n_up' / `N_pair'
    local prob_down = `n_down' / `N_pair'

    * --- Rank-Rank Regression ---
    * Modelo: decil_t1 = α + β * decil_t0 + ε
    * β mide persistencia: β ≈ 1 → inmobilidad, β ≈ 0 → movilidad perfecta
    quietly regress decil_t1 decil_t0
    local rr_beta = _b[decil_t0]
    local rr_se   = _se[decil_t0]
    local rr_r2   = e(r2)

    * --- Postear medidas resumen ---
    post `summ_post' (`y0') (`y1')                               ///
        (`shorrocks') (`immobility')                             ///
        (`prob_up') (`prob_down')                                ///
        (`persist_d1') (`persist_d10')                           ///
        (`rr_beta') (`rr_se') (`rr_r2')                         ///
        (`N_pair')

    * --- Mostrar en consola ---
    di as text _n "  Medidas resumen:"
    di as text "    Índice de Shorrocks     = " %6.4f `shorrocks'
    di as text "    Índice de inmovilidad   = " %6.4f `immobility'
    di as text "    P(ascendente)           = " %6.4f `prob_up'
    di as text "    P(descendente)          = " %6.4f `prob_down'
    di as text "    Persistencia decil 1    = " %6.4f `persist_d1'
    di as text "    Persistencia decil 10   = " %6.4f `persist_d10'
    di as text "    Rank-rank β             = " %6.4f `rr_beta' " (se=" %6.4f `rr_se' ")"
    di as text "    Rank-rank R²            = " %6.4f `rr_r2'
    di as text "    N panel pareado         = " %12.0fc `N_pair'

    * ------------------------------------------------------------------
    * 5.1.3  Crecimiento intertemporal por decil de origen
    * ------------------------------------------------------------------

    * Tasa de crecimiento: g_i = (ingreso_t1 - ingreso_t0) / ingreso_t0
    * Solo para ingreso_t0 > 0 (ya filtrado)
    gen crec = (ingreso_t1 - ingreso_t0) / ingreso_t0

    di as text _n "  Crecimiento del ingreso por decil de origen:"
    di as text "  Decil |   Media   Mediana     SD       P25      P75       N"
    di as text "  ------+----------------------------------------------------"

    forvalues d = 1/10 {
        quietly summarize crec if decil_t0 == `d', detail
        if r(N) > 0 {
            post `grow_post' (`y0') (`y1') (`d')                   ///
                (r(mean)) (r(p50)) (r(sd))                         ///
                (r(p25)) (r(p75)) (r(N))

            di as text "    " %2.0f `d' "   | " ///
                %8.4f r(mean) " " %8.4f r(p50) " " ///
                %8.4f r(sd) " " %8.4f r(p25) " " ///
                %8.4f r(p75) "  " %6.0f r(N)
        }
    }
}

postclose `mat_post'
postclose `summ_post'
postclose `grow_post'

* ============================================================================
* 6. MOVILIDAD DE LARGO PLAZO: 2010 → 2024
* ============================================================================
*
* Movilidad absoluta: ¿los individuos tienen más ingreso en 2024 que en 2010?
* Movilidad relativa: ¿cambiaron de posición en la distribución?

di as result _n "========== Movilidad de largo plazo: 2010 → 2024 =========="

* --- Panel pareado 2010-2024 ---
use "`panel'", clear
keep if anio == 2010
rename decil decil_2010
rename INGRESOS_TOTAL ingreso_2010
drop anio
tempfile lp_2010
save "`lp_2010'", replace

use "`panel'", clear
keep if anio == 2024
rename decil decil_2024
rename INGRESOS_TOTAL ingreso_2024
drop anio

merge 1:1 CEDULA_PK using "`lp_2010'", keep(3) nogen

local N_lp = _N
di as text "  Individuos presentes en 2010 y 2024: `N_lp'"

* ------------------------------------------------------------------
* 6.1  MOVILIDAD ABSOLUTA
* ------------------------------------------------------------------
*
* Definición: un individuo experimenta movilidad absoluta ascendente si
*   ingreso_2024 > ingreso_2010
*
* Tasa de crecimiento individual: g_i = (Y_2024 - Y_2010) / Y_2010

gen crec_lp = (ingreso_2024 - ingreso_2010) / ingreso_2010
gen byte mov_abs_up   = (ingreso_2024 > ingreso_2010)
gen byte mov_abs_down = (ingreso_2024 < ingreso_2010)
gen byte mov_abs_same = (ingreso_2024 == ingreso_2010)

* Cambio absoluto en dólares
gen cambio_abs = ingreso_2024 - ingreso_2010

di as text _n "  --- Movilidad absoluta ---"
quietly summarize mov_abs_up
di as text "    Fracción con ingreso mayor en 2024: " %6.4f r(mean)
quietly summarize mov_abs_down
di as text "    Fracción con ingreso menor en 2024: " %6.4f r(mean)

di as text _n "    Crecimiento del ingreso 2010-2024 por decil de origen:"
di as text "    Decil | Media crec. | Mediana crec. | Media Δ$ | Mediana Δ$ | N"
di as text "    ------+-------------+---------------+----------+------------+---"

forvalues d = 1/10 {
    quietly summarize crec_lp if decil_2010 == `d', detail
    local m_crec = r(mean)
    local md_crec = r(p50)
    local n_d = r(N)
    quietly summarize cambio_abs if decil_2010 == `d', detail
    local m_abs = r(mean)
    local md_abs = r(p50)
    di as text "      " %2.0f `d' "   |  " %10.4f `m_crec' " |    " ///
        %10.4f `md_crec' "  | " %8.0f `m_abs' " |  " %8.0f `md_abs' "  | " %3.0f `n_d'
}

* ------------------------------------------------------------------
* 6.2  MOVILIDAD RELATIVA
* ------------------------------------------------------------------

* Transición de deciles
gen byte mov_rel_up   = (decil_2024 > decil_2010)
gen byte mov_rel_down = (decil_2024 < decil_2010)
gen byte mov_rel_same = (decil_2024 == decil_2010)
gen cambio_decil      = decil_2024 - decil_2010

di as text _n "  --- Movilidad relativa ---"
quietly summarize mov_rel_up
di as text "    Fracción que sube de decil:    " %6.4f r(mean)
quietly summarize mov_rel_down
di as text "    Fracción que baja de decil:    " %6.4f r(mean)
quietly summarize mov_rel_same
di as text "    Fracción que permanece:        " %6.4f r(mean)

* Rank-rank regression de largo plazo
quietly regress decil_2024 decil_2010
local rr_lp_beta = _b[decil_2010]
local rr_lp_se   = _se[decil_2010]
local rr_lp_r2   = e(r2)
di as text "    Rank-rank β (largo plazo):     " %6.4f `rr_lp_beta' ///
    " (se=" %6.4f `rr_lp_se' ")"
di as text "    Rank-rank R²:                  " %6.4f `rr_lp_r2'

* Matriz de transición de largo plazo
di as text _n "  Matriz de transición 2010 → 2024:"

preserve
contract decil_2010 decil_2024, freq(freq)
bysort decil_2010: egen total_origen = total(freq)
gen prob_cond = freq / total_origen

* Mostrar
drop total_origen
reshape wide prob_cond freq, i(decil_2010) j(decil_2024)
di as text "  Decil 2010 |   D1      D2      D3      D4      D5      D6      D7      D8      D9      D10"
di as text "  -----------+------------------------------------------------------------------------"
forvalues d = 1/10 {
    local line "       `d'    |"
    forvalues j = 1/10 {
        capture local val = prob_cond`j'[`d']
        if _rc {
            local line "`line'   .   "
        }
        else {
            local val_fmt : di %6.3f `val'
            local line "`line' `val_fmt'"
        }
    }
    di as text "  `line'"
}
restore

* Traza e índices para largo plazo
local traza_lp = 0
forvalues d = 1/10 {
    quietly count if decil_2010 == `d' & decil_2024 == `d'
    local n_diag = r(N)
    quietly count if decil_2010 == `d'
    local n_orig = r(N)
    if `n_orig' > 0 {
        local traza_lp = `traza_lp' + (`n_diag' / `n_orig')
    }
}
local immobility_lp = `traza_lp' / 10
local shorrocks_lp  = (10 - `traza_lp') / (10 - 1)

di as text _n "    Shorrocks (largo plazo):   " %6.4f `shorrocks_lp'
di as text "    Inmovilidad (largo plazo): " %6.4f `immobility_lp'

* Persistencia en extremos
quietly count if decil_2010 == 1 & decil_2024 == 1
local n_d1s = r(N)
quietly count if decil_2010 == 1
local n_d1o = r(N)
di as text "    Persistencia decil 1:      " %6.4f cond(`n_d1o'>0, `n_d1s'/`n_d1o', .)

quietly count if decil_2010 == 10 & decil_2024 == 10
local n_d10s = r(N)
quietly count if decil_2010 == 10
local n_d10o = r(N)
di as text "    Persistencia decil 10:     " %6.4f cond(`n_d10o'>0, `n_d10s'/`n_d10o', .)

* --- Guardar datos de largo plazo ---
save "$dir_out/panel_largo_plazo_2010_2024.dta", replace

* ============================================================================
* 7. GRÁFICOS
* ============================================================================

capture mkdir "$dir_out/Graficos"
set scheme s2color

* ------------------------------------------------------------------
* 7.1  Heatmap de la matriz de transición 2010→2024 (bubble chart)
* ------------------------------------------------------------------

use "$dir_out/panel_largo_plazo_2010_2024.dta", clear

preserve
contract decil_2010 decil_2024, freq(freq)
bysort decil_2010: egen total_origen = total(freq)
gen prob = freq / total_origen
gen prob_label = string(prob, "%4.2f")

twoway (scatter decil_2024 decil_2010 [w=prob],         ///
        msymbol(circle) mcolor(navy%60)                  ///
        mlabel(prob_label) mlabposition(0) mlabsize(vsmall) ///
        mlabcolor(black))                                ///
    , xlabel(1(1)10, valuelabel)                         ///
      ylabel(1(1)10, valuelabel angle(0))                ///
      xtitle("Decil de origen (2010)")                   ///
      ytitle("Decil de destino (2024)")                  ///
      title("Matriz de transición 2010 → 2024")         ///
      subtitle("Tamaño de burbuja = probabilidad condicional") ///
      legend(off)                                        ///
      graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/heatmap_transicion_2010_2024.pdf", replace
restore

* ------------------------------------------------------------------
* 7.2  Rank-rank scatter plot con línea de regresión (2010→2024)
* ------------------------------------------------------------------

twoway (scatter decil_2024 decil_2010,                   ///
        mcolor(navy%30) msymbol(circle) msize(small)     ///
        jitter(3))                                       ///
       (lfit decil_2024 decil_2010,                      ///
        lcolor(cranberry) lwidth(medthick))               ///
    , xlabel(1(1)10) ylabel(1(1)10, angle(0))            ///
      xtitle("Decil de ingreso 2010")                    ///
      ytitle("Decil de ingreso 2024")                    ///
      title("Rank-Rank Mobility: 2010 → 2024")          ///
      subtitle("β = `: di %5.3f `rr_lp_beta'', R² = `: di %5.3f `rr_lp_r2''") ///
      legend(order(1 "Individuos" 2 "Línea de regresión") ///
        position(6) rows(1))                             ///
      graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/rank_rank_2010_2024.pdf", replace

* ------------------------------------------------------------------
* 7.3  Crecimiento mediano del ingreso por decil de origen (2010→2024)
* ------------------------------------------------------------------

preserve
collapse (median) mediana_crec=crec_lp (mean) media_crec=crec_lp ///
    (count) N=crec_lp, by(decil_2010)

graph bar mediana_crec, over(decil_2010,                 ///
        relabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5"           ///
                6 "6" 7 "7" 8 "8" 9 "9" 10 "10"))       ///
    bar(1, color(navy%70))                                ///
    ytitle("Tasa de crecimiento mediana")                 ///
    title("Crecimiento mediano del ingreso por decil de origen") ///
    subtitle("2010 → 2024")                               ///
    blabel(bar, format(%6.2f) size(vsmall))               ///
    graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/crecimiento_mediano_decil_2010_2024.pdf", replace
restore

* ------------------------------------------------------------------
* 7.4  Persistencia por decil (probabilidad de permanecer) 2010→2024
* ------------------------------------------------------------------

preserve
gen byte same_decil = (decil_2010 == decil_2024)
collapse (mean) prob_persistencia=same_decil, by(decil_2010)

graph bar prob_persistencia, over(decil_2010,            ///
        relabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5"           ///
                6 "6" 7 "7" 8 "8" 9 "9" 10 "10"))       ///
    bar(1, color(dkorange%70))                            ///
    ytitle("Probabilidad de permanecer")                  ///
    title("Persistencia por decil de origen")             ///
    subtitle("2010 → 2024")                               ///
    blabel(bar, format(%4.2f) size(vsmall))               ///
    graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/persistencia_decil_2010_2024.pdf", replace
restore

* ------------------------------------------------------------------
* 7.5  Movilidad ascendente/descendente por decil de origen (2010→2024)
* ------------------------------------------------------------------

preserve
collapse (mean) prob_up=mov_rel_up prob_down=mov_rel_down ///
    prob_same=mov_rel_same, by(decil_2010)

graph bar prob_up prob_same prob_down, over(decil_2010,   ///
        relabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5"           ///
                6 "6" 7 "7" 8 "8" 9 "9" 10 "10"))       ///
    stack                                                 ///
    bar(1, color(forest_green%70))                        ///
    bar(2, color(gs10%70))                                ///
    bar(3, color(cranberry%70))                           ///
    ytitle("Proporción")                                  ///
    title("Movilidad relativa por decil de origen")       ///
    subtitle("2010 → 2024")                               ///
    legend(order(1 "Ascendente" 2 "Permanece" 3 "Descendente") ///
        position(6) rows(1))                             ///
    graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/movilidad_relativa_decil_2010_2024.pdf", replace
restore

* ------------------------------------------------------------------
* 7.6  Movilidad absoluta: fracción con ingreso mayor por decil (2010→2024)
* ------------------------------------------------------------------

preserve
collapse (mean) prob_abs_up=mov_abs_up, by(decil_2010)

graph bar prob_abs_up, over(decil_2010,                  ///
        relabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5"           ///
                6 "6" 7 "7" 8 "8" 9 "9" 10 "10"))       ///
    bar(1, color(midblue%70))                             ///
    ytitle("Proporción con ingreso mayor en 2024")        ///
    title("Movilidad absoluta ascendente por decil de origen") ///
    subtitle("Fracción de individuos con ingreso 2024 > ingreso 2010") ///
    blabel(bar, format(%4.2f) size(vsmall))               ///
    graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/movilidad_absoluta_decil_2010_2024.pdf", replace
restore

* ------------------------------------------------------------------
* 7.7  Evolución del índice de Shorrocks (transiciones consecutivas)
* ------------------------------------------------------------------

use "$dir_out/medidas_movilidad.dta", clear

gen str_trans = string(anio_t0) + "-" + string(anio_t1)
encode str_trans, gen(transicion)

twoway (connected shorrocks transicion,                  ///
        mcolor(navy) lcolor(navy) msymbol(circle)        ///
        msize(medium) lwidth(medthick))                  ///
    , xlabel(1(1)11, valuelabel angle(45) labsize(vsmall)) ///
      ylabel(, angle(0) format(%4.2f))                   ///
      xtitle("Transición")                               ///
      ytitle("Índice de Shorrocks")                      ///
      title("Evolución del índice de Shorrocks")         ///
      subtitle("Transiciones consecutivas")               ///
      graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/shorrocks_evolucion.pdf", replace

* ------------------------------------------------------------------
* 7.8  Evolución de persistencia en deciles extremos
* ------------------------------------------------------------------

twoway (connected persistencia_d1 transicion,            ///
        mcolor(cranberry) lcolor(cranberry)               ///
        msymbol(circle) lwidth(medthick))                ///
       (connected persistencia_d10 transicion,           ///
        mcolor(navy) lcolor(navy)                        ///
        msymbol(square) lwidth(medthick))                ///
    , xlabel(1(1)11, valuelabel angle(45) labsize(vsmall)) ///
      ylabel(, angle(0) format(%4.2f))                   ///
      xtitle("Transición")                               ///
      ytitle("Probabilidad de permanencia")               ///
      title("Persistencia en deciles extremos")           ///
      legend(order(1 "Decil 1 (inferior)" 2 "Decil 10 (superior)") ///
        position(6) rows(1))                             ///
      graphregion(color(white)) plotregion(color(white))
graph export "$dir_out/Graficos/persistencia_extremos_evolucion.pdf", replace

* ============================================================================
* 8. GUARDAR RESULTADOS
* ============================================================================

* --- Matrices de transición ---
use "`mat_file'", clear
label var anio_t0   "Año origen"
label var anio_t1   "Año destino"
label var decil_t0  "Decil origen"
label var decil_t1  "Decil destino"
label var freq      "Frecuencia"
label var prob_cond "Probabilidad condicional"
save "$dir_out/matrices_transicion.dta", replace

* --- Medidas resumen ---
use "`summ_file'", clear
label var anio_t0          "Año origen"
label var anio_t1          "Año destino"
label var shorrocks        "Índice de Shorrocks"
label var immobility       "Índice de inmovilidad"
label var prob_ascendente  "P(movilidad ascendente)"
label var prob_descendente "P(movilidad descendente)"
label var persistencia_d1  "Persistencia decil 1"
label var persistencia_d10 "Persistencia decil 10"
label var rank_rank_beta   "Pendiente rank-rank"
label var rank_rank_se     "Error estándar rank-rank"
label var rank_rank_r2     "R² rank-rank"
label var N_panel          "N panel pareado"
save "$dir_out/medidas_movilidad.dta", replace

* --- Crecimiento por decil ---
use "`grow_file'", clear
label var anio_t0      "Año origen"
label var anio_t1      "Año destino"
label var decil_origen "Decil de origen"
label var media_crec   "Media tasa de crecimiento"
label var mediana_crec "Mediana tasa de crecimiento"
label var sd_crec      "Desv. est. tasa de crecimiento"
label var p25_crec     "Percentil 25 crecimiento"
label var p75_crec     "Percentil 75 crecimiento"
label var N_crec       "N observaciones"
save "$dir_out/crecimiento_por_decil.dta", replace

* ============================================================================
* 7. EXPORTAR A EXCEL
* ============================================================================

local outfile "$dir_out/Movilidad_Economica.xlsx"

* --- Hoja 1: Medidas resumen ---
use "$dir_out/medidas_movilidad.dta", clear
format shorrocks immobility prob_ascendente prob_descendente ///
    persistencia_d1 persistencia_d10 rank_rank_beta          ///
    rank_rank_se rank_rank_r2 %8.4f
format N_panel %12.0fc

export excel using "`outfile'",                              ///
    sheet("Medidas resumen") firstrow(varlabel) replace

* --- Hojas de matrices: una por cada par de años ---
use "$dir_out/matrices_transicion.dta", clear
levelsof anio_t0, local(trans_years)
local all_t1 ""
foreach y0 of local trans_years {
    quietly levelsof anio_t1 if anio_t0 == `y0', local(dest_y)
    foreach y1 of local dest_y {
        local all_t1 "`all_t1' `y1'"
    }
}

local npairs_exp : word count `trans_years'
forvalues i = 1/`npairs_exp' {
    local y0 : word `i' of `trans_years'
    local y1 : word `i' of `all_t1'

    use "$dir_out/matrices_transicion.dta", clear
    keep if anio_t0 == `y0' & anio_t1 == `y1'
    keep decil_t0 decil_t1 prob_cond

    reshape wide prob_cond, i(decil_t0) j(decil_t1)

    * Renombrar columnas
    forvalues d = 1/10 {
        capture rename prob_cond`d' D`d'
        capture label var D`d' "Decil `d'"
        capture format D`d' %8.4f
    }
    label var decil_t0 "Decil origen"

    export excel using "`outfile'",                          ///
        sheet("Matriz `y0'-`y1'") firstrow(varlabel) sheetmodify
}

* --- Hoja: Crecimiento por decil ---
use "$dir_out/crecimiento_por_decil.dta", clear
format media_crec mediana_crec sd_crec p25_crec p75_crec %8.4f
format N_crec %12.0fc

export excel using "`outfile'",                                  ///
    sheet("Crecimiento por decil") firstrow(varlabel) sheetmodify

* --- Hoja: Largo plazo 2010-2024 (absoluta) ---
use "$dir_out/panel_largo_plazo_2010_2024.dta", clear
preserve
collapse (mean) frac_abs_up=mov_abs_up                           ///
    (mean) media_crec=crec_lp (median) mediana_crec=crec_lp      ///
    (mean) media_cambio_abs=cambio_abs                            ///
    (median) mediana_cambio_abs=cambio_abs                        ///
    (count) N=crec_lp, by(decil_2010)
rename decil_2010 decil_origen

label var decil_origen     "Decil de origen (2010)"
label var frac_abs_up      "Fracción con ingreso mayor en 2024"
label var media_crec       "Media tasa crecimiento"
label var mediana_crec     "Mediana tasa crecimiento"
label var media_cambio_abs "Media cambio absoluto ($)"
label var mediana_cambio_abs "Mediana cambio absoluto ($)"
label var N                "N observaciones"

format frac_abs_up media_crec mediana_crec %8.4f
format media_cambio_abs mediana_cambio_abs %12.2f
format N %8.0fc

export excel using "`outfile'",                                  ///
    sheet("Largo plazo absoluta") firstrow(varlabel) sheetmodify
restore

* --- Hoja: Largo plazo 2010-2024 (transición) ---
preserve
contract decil_2010 decil_2024, freq(freq)
bysort decil_2010: egen total_origen = total(freq)
gen prob_cond = freq / total_origen
keep decil_2010 decil_2024 prob_cond

reshape wide prob_cond, i(decil_2010) j(decil_2024)
forvalues d = 1/10 {
    capture rename prob_cond`d' D`d'
    capture label var D`d' "Decil `d'"
    capture format D`d' %8.4f
}
label var decil_2010 "Decil origen (2010)"

export excel using "`outfile'",                                  ///
    sheet("Matriz 2010-2024") firstrow(varlabel) sheetmodify
restore

* ============================================================================
* 11. FIN
* ============================================================================

di as result _n "============================================="
di as result    "  Análisis de movilidad completado"
di as result    "============================================="
di as text "Archivos generados:"
di as text "  $dir_out/matrices_transicion.dta"
di as text "  $dir_out/medidas_movilidad.dta"
di as text "  $dir_out/crecimiento_por_decil.dta"
di as text "  $dir_out/panel_largo_plazo_2010_2024.dta"
di as text "  `outfile'"
di as text "  $dir_out/Graficos/ (8 gráficos .pdf)"
di as text ""
di as text "Nota metodológica:"
di as text "  - Deciles construidos intra-año (ranking relativo)"
di as text "  - Panel no balanceado: cada transición usa solo individuos"
di as text "    presentes en ambos años del par"
di as text "  - Movilidad absoluta: fracción con ingreso real mayor"
di as text "  - Movilidad relativa: cambio de posición en la distribución"
di as text "  - Posibles sesgos: attrition selectiva, regresión a la media,"
di as text "    variación transitoria del ingreso"
di as text "  - La transición 2020-2024 cubre un gap de 4 años"
di as text ""

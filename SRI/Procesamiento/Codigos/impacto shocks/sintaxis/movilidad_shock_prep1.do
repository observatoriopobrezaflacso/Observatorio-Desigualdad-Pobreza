/*******************************************************************************
* movilidad_shock_prep1.do   --   VERSION B
*
* IDEM movilidad_shock.do, pero PARTIENDO DE LAS VARIABLES Y LA ESTRUCTURA
* DE DATOS TAL COMO LAS DEFINE data_preparation1.do.
*
* No reconstruye ingresos, deflactores ni rangos: toma los que ya vienen en
*       $dina/ranks/covid_unbalanced.dta   y   $dina/ranks/covid_balanced.dta
* Las DOS muestras se leen y se apilan, para que salgan lado a lado en los
* mismos Excel (data_preparation1.do ya calcula los rangos por separado en
* cada archivo, que es exactamente lo que hace falta).
*
* -----------------------------------------------------------------------------
* MAPEO DE NOMBRES  (data_preparation1.do  ->  este do)
*
*   VARIABLE DE INGRESO `v' in { ingreso, D1R, capital, liq_107 }
*   DEFINICION DE t0:  su "_1" = (a) nivel en $t0_year
*                      su "_2" = (b) promedio $t0_win_first-$t0_win_last
*
*   g_real_1_`v'      -> crecimiento real desde t0, def. (a)     -> g_a_`v'
*   g_real_2_`v'      -> crecimiento real desde t0, def. (b)     -> g_b_`v'
*   decil_t0_1_`v'    -> decil de origen, def. (a)               -> decil0_a_`v'
*   decil_t0_2_`v'    -> decil de origen, def. (b)               -> decil0_b_`v'
*   decil_t1_`v'      -> decil contemporaneo del anio            -> decil_`v'
*   pctl_t1_`v'       -> percentil contemporaneo del anio        -> pctl_`v'
*   pctl_t0_1_`v'     -> percentil de origen, def. (a)           -> pctl0_a_`v'
*   pctl_t0_2_`v'     -> percentil de origen, def. (b)           -> pctl0_b_`v'
*   real_t1_`v'       -> ingreso real del anio                   -> real_`v'
*   id_bal, anio      -> id, anio
*   covid_unbalanced / covid_balanced -> muestra = 1 / 2
*
* El bloque 03 es un ADAPTADOR: solo renombra/deriva/apila. A partir del
* bloque 06 el codigo es IDENTICO al de movilidad_shock.do (mismos analisis,
* mismos Excel), para que las dos versiones sean comparables linea a linea.
* Los bloques 04 y 05 no existen aqui: el dataset ya viene armado.
*
* -----------------------------------------------------------------------------
* DOS ARREGLOS MINIMOS (se pueden apagar con los globals del bloque 00)
*
* $rebuild_decil_t0_2  (por defecto 1)
*   En data_preparation1.do, decil_t0_2_`v' se genera dentro del -preserve-
*   de anio==2018 y el loop posterior propaga con -egen min()- pctl_t0_1,
*   decil_t0_1 y pctl_t0_2, pero NO decil_t0_2. Queda entonces solo en las
*   filas de 2018 y es inutilizable como decil de origen. Aca se reconstruye
*   a partir de pctl_t0_2_`v' (que si esta propagado) con el mismo -recode-
*   de deciles que usa data_preparation1.do.
*
* $fix_ingreso_base    (por defecto 1)
*   Para D1R, capital y liq_107, data_preparation1.do fija la base en t0
*   (lineas `x'_t0_1_t = `x'_l1 if anio==2019  +  egen min()). Para `ingreso'
*   NO: usa ingreso_t0_1 = L.PreTaxHHI y ingreso_t0_2 = rowmean(l1 l2 l3),
*   que se MUEVEN con el anio. Con eso, g_real_1_ingreso en 2021 es el
*   crecimiento 2020->2021, no 2018->2021, y no es comparable con las otras
*   tres variables ni con lo que pide el analisis. Con este global en 1 se le
*   aplica a `ingreso' exactamente la misma receta que a las otras tres,
*   usando sus propias variables ingreso_l1/l2/l3 e ipc.
*   Ponerlo en 0 deja las variables tal cual salen de data_preparation1.do.
*
* -----------------------------------------------------------------------------
* COMO SE USA: igual que la version A. Bloques 00 y 01 siempre primero;
* despues cada bloque numerado se puede correr solo.
* OJO: -putexcel ..., replace- falla si el .xlsx esta abierto en Excel.
*******************************************************************************/

clear all
set more off
set seed 20260828
capture set matsize 800
capture set maxvar 32000


* ============================================================================
* 00. PARAMETROS
* ============================================================================

global shock        "covid"

global t0_year      2018                // lo que en data_preparation1 es "_1"
global t0_win_first 2016                // lo que en data_preparation1 es "_2"
global t0_win_last  2018
global pre_year     2019                // anio de referencia PRE-shock
global post_years   "2020 2021 2022"    // anios POST-shock

global inc_vars     "ingreso D1R capital liq_107"

* --- Muestras: se leen los DOS archivos y se apilan ------------------------
global samples      "unbal bal"

global hi_decile    10
global lo_decile    6
global top_decile   10
global bot_decile   1

global wins_p       1               // winsorizar g en p / 100-p (0 = no)
global do_transmat  1
global do_lee       1               // cotas de Lee (bloque 10)

* --- Arreglos minimos sobre la salida de data_preparation1.do --------------
global rebuild_decil_t0_2  1
global fix_ingreso_base    1


* ============================================================================
* 01. RUTAS Y GLOBALS DERIVADOS   (correr siempre junto con el bloque 00)
* ============================================================================

global user_root  "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

global ipc        "$user_root/03 BDD/IPC"
global dina       "$user_root/03 BDD/SRI/IR/Merged/ingreso_dina"
global data_out   "$user_root/Proyectos/Impacto shocks/data"
global results    "$user_root/Proyectos/Impacto shocks/resultados"

* Archivo fuente de cada muestra (salida de data_preparation1.do)
global src_unbal  "$dina/ranks/covid_unbalanced.dta"
global src_bal    "$dina/ranks/covid_balanced.dta"

* --- Para probar con datos falsos: definir $fake_root ANTES de correr -------
if "$fake_root" != "" {
    global ipc       "$fake_root"
    global data_out  "$fake_root"
    global results   "$fake_root/resultados"
    global src_unbal "$fake_root/covid_unbalanced.dta"
    global src_bal   "$fake_root/covid_balanced.dta"
}

capture mkdir "$results"
capture mkdir "$results/movilidad"
global out    "$results/movilidad/${shock}_prep1"
capture mkdir "$out"
capture mkdir "$out/descriptivos"
capture mkdir "$out/regresiones"
capture mkdir "$out/tablas"

capture mkdir "$data_out/movilidad"
global work   "$data_out/movilidad"

* Prefijo de los .dta intermedios (distinto en cada version, para que la
* version A y la version B no se pisen los archivos de trabajo)
global fstem     "${shock}_prep1"

global out_years   "$pre_year $post_years"
global out_years_c = subinstr(trim("$out_years"), " ", ",", .)
global n_out_years = wordcount("$out_years")
global n_post      = wordcount("$post_years")
global n_inc       = wordcount("$inc_vars")
global n_pairs     = 2 * $n_inc
global n_samp      = wordcount("$samples")
global n_rows_y    = $n_samp * $n_out_years
global n_rows_p    = $n_samp * $n_post

global ABC "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
global XLCOL ""
forvalues i = 1/80 {
    local cl = cond(`i' <= 26, substr("$ABC", `i', 1),                     ///
                    substr("$ABC", int((`i'-1)/26), 1) +                   ///
                    substr("$ABC", mod(`i'-1, 26) + 1, 1))
    global XLCOL "$XLCOL `cl'"
}

global PAIRLAB ""
foreach v of global inc_vars {
    foreach j in a b {
        global PAIRLAB "$PAIRLAB `v'_`j'"
    }
}

global shock_lab "$shock (prep1) | base $pre_year | t0a=$t0_year | t0b=$t0_win_first-$t0_win_last"

di as result _n "== Shock: $shock_lab =="
di as text "   fuente unbal         : $src_unbal"
di as text "   fuente bal           : $src_bal"
di as text "   variables de ingreso : $inc_vars"
di as text "   columnas de los Excel: $PAIRLAB"
di as text "   salidas en           : $out"


* ============================================================================
* 03. ADAPTADOR  ->  $work/${fstem}_analysis.dta
* ============================================================================
* Lee covid_unbalanced y covid_balanced, los traduce a los nombres que usan
* los bloques 06-10 y los apila con la variable -muestra-.
* No recalcula ingresos, deflactores ni rangos.

capture erase "$work/${fstem}_analysis.dta"

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "########## armando la muestra: `s' ##########"

    if "`s'" == "unbal" use "$src_unbal", clear
    else                use "$src_bal", clear

    rename id_bal id
    keep if inlist(anio, $out_years_c)

    gen byte muestra = `si'
    label define muestra_lb 1 "unbal" 2 "bal", replace
    label values muestra muestra_lb
    label var muestra "Muestra (1 = no balanceada, 2 = balanceada)"

    * --- 03.1 Arreglo: base fija para ingreso (ver cabecera) --------------
    * Aplica a ingreso la MISMA receta que data_preparation1.do usa para D1R,
    * capital y liq_107: nivel de $t0_year y promedio de la ventana, fijos.
    if $fix_ingreso_base == 1 {

        capture confirm variable ingreso_l1
        if _rc {
            di as error "No estan ingreso_l1/l2/l3: no se puede fijar la base."
            di as error "  Poner global fix_ingreso_base 0 o revisar data_preparation1.do."
        }
        else {
            gen double _t1 = ingreso_l1 if anio == $pre_year
            bysort id: egen double ingreso_t0_1_fix = min(_t1)
            drop _t1

            egen double _t2 = rowmean(ingreso_l1 ingreso_l2 ingreso_l3)   ///
                if anio == $pre_year & !inlist(., ingreso_l1, ingreso_l2, ingreso_l3)
            bysort id: egen double ingreso_t0_2_fix = min(_t2)
            drop _t2

            replace real_t0_1_ingreso = ingreso_t0_1_fix / (ipc_t0/100)
            replace real_t0_2_ingreso = ingreso_t0_2_fix / (ipc_t0_2/100)
            replace g_real_1_ingreso  = real_t1_ingreso / real_t0_1_ingreso - 1
            replace g_real_2_ingreso  = real_t1_ingreso / real_t0_2_ingreso - 1

            di as text "  base de ingreso fijada en t0 (igual que D1R/capital/liq_107)"
        }
    }

    * --- 03.2 Arreglo: reconstruir decil_t0_2_`v' desde pctl_t0_2_`v' -----
    if $rebuild_decil_t0_2 == 1 {
        foreach v of global inc_vars {
            capture drop decil_t0_2_`v'
            recode pctl_t0_2_`v' (1/10 = 1) (11/20 = 2) (21/30 = 3)     ///
                                 (31/40 = 4) (41/50 = 5) (51/60 = 6)    ///
                                 (61/70 = 7) (71/80 = 8) (81/90 = 9)    ///
                                 (91/100 = 10), gen(decil_t0_2_`v')
        }
        di as text "  decil_t0_2_* reconstruido desde pctl_t0_2_*"
    }

    * --- 03.3 Renombrar a la nomenclatura de los bloques 06-10 ------------
    foreach v of global inc_vars {
        rename g_real_1_`v'    g_a_`v'
        rename g_real_2_`v'    g_b_`v'
        rename decil_t0_1_`v'  decil0_a_`v'
        rename decil_t0_2_`v'  decil0_b_`v'
        rename decil_t1_`v'    decil_`v'
        rename pctl_t1_`v'     pctl_`v'
        rename pctl_t0_1_`v'   pctl0_a_`v'
        rename pctl_t0_2_`v'   pctl0_b_`v'
        rename real_t1_`v'     real_`v'
    }

    * --- 03.4 Variables derivadas (identicas a la version A) -------------
    gen byte post = anio != $pre_year
    label var post "=1 anio posterior al shock"

    foreach v of global inc_vars {
        foreach j in a b {

            gen double gw_`j'_`v' = g_`j'_`v'
            gen double lg_`j'_`v' = ln(1 + g_`j'_`v')
            label var gw_`j'_`v' "Crecimiento winsorizado (def. `j'): `v'"
            label var lg_`j'_`v' "Log-crecimiento desde t0 (def. `j'): `v'"

            gen int  ddec_`j'_`v' = decil_`v' - decil0_`j'_`v'
            gen int  adec_`j'_`v' = abs(ddec_`j'_`v')
            gen byte up_`j'_`v'   = ddec_`j'_`v' >  0 if !missing(ddec_`j'_`v')
            gen byte down_`j'_`v' = ddec_`j'_`v' <  0 if !missing(ddec_`j'_`v')
            gen byte stay_`j'_`v' = ddec_`j'_`v' == 0 if !missing(ddec_`j'_`v')
            label var ddec_`j'_`v' "Cambio de decil desde t0 (def. `j'): `v'"
            label var adec_`j'_`v' "|Cambio de decil| desde t0 (def. `j'): `v'"
            label var up_`j'_`v'   "=1 sube de decil (def. `j'): `v'"
            label var down_`j'_`v' "=1 baja de decil (def. `j'): `v'"
            label var stay_`j'_`v' "=1 se mantiene de decil (def. `j'): `v'"

            gen byte top_`j'_`v' = (decil_`v' == $top_decile) if decil0_`j'_`v' == $top_decile
            gen byte bot_`j'_`v' = (decil_`v' == $bot_decile) if decil0_`j'_`v' == $bot_decile
            label var top_`j'_`v' "=1 sigue en D$top_decile (origen D$top_decile, def. `j'): `v'"
            label var bot_`j'_`v' "=1 sigue en D$bot_decile (origen D$bot_decile, def. `j'): `v'"

            gen byte hi_`j'_`v' = decil0_`j'_`v' == $hi_decile if !missing(decil0_`j'_`v')
            label var hi_`j'_`v' "=1 origen D$hi_decile (vs D$lo_decile, def. `j'): `v'"
        }
    }

    * --- Winsorizacion simetrica dentro de cada anio ---------------------
    if $wins_p > 0 {
        levelsof anio, local(yrs)
        foreach v of global inc_vars {
            foreach j in a b {
                foreach y of local yrs {
                    quietly _pctile g_`j'_`v' if anio == `y', ///
                        percentiles($wins_p `= 100 - $wins_p ')
                    quietly replace gw_`j'_`v' = r(r1) ///
                        if anio == `y' & g_`j'_`v' < r(r1) & !missing(g_`j'_`v')
                    quietly replace gw_`j'_`v' = r(r2) ///
                        if anio == `y' & g_`j'_`v' > r(r2) & !missing(g_`j'_`v')
                }
            }
        }
    }

    keep id anio muestra post real_* pctl_* pctl0_* decil_* decil0_* ///
         g_* gw_* lg_* ddec_* adec_* up_* down_* stay_* top_* bot_* hi_*
    compress
    if `si' > 1 append using "$work/${fstem}_analysis.dta"
    save "$work/${fstem}_analysis.dta", replace
}

use "$work/${fstem}_analysis.dta", clear
sort muestra id anio
save "$work/${fstem}_analysis.dta", replace

di as result _n "== Muestra de analisis (prep1) =="
tabulate anio muestra


* ---- 03.5 Archivos adelgazados para los descriptivos ----------------------

use "$work/${fstem}_analysis.dta", clear
keep id muestra anio real_* gw_* g_* adec_* ddec_* up_* down_* stay_* top_* bot_*
compress
save "$work/${fstem}_slim_desc.dta", replace

use "$work/${fstem}_analysis.dta", clear
keep muestra anio decil0_* gw_*
compress
save "$work/${fstem}_slim_gdec.dta", replace

use "$work/${fstem}_analysis.dta", clear
keep muestra anio decil_* decil0_*
compress
save "$work/${fstem}_slim_trans.dta", replace


* ============================================================================
* 06. DESCRIPTIVOS POR ANIO  (previos a la econometria)
* ============================================================================
* Todo sale de -collapse- sobre los archivos adelgazados del bloque 05.1.
* Filas = muestra x anio ; columnas = variable de ingreso x definicion de t0.

use "$work/${fstem}_slim_desc.dta", clear
gen byte n = 1
collapse (sum) n_obs = n (mean) real_* gw_* adec_* ddec_* up_* down_* stay_* ///
                          top_* bot_*, by(muestra anio)
sort muestra anio
list muestra anio n_obs, noobs

* --- Hoja 1: N por muestra y anio ------------------------------------------
putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("n_obs") replace
putexcel A1 = "Descriptivos por anio -- $shock_lab"
putexcel A3 = "muestra" B3 = "anio" C3 = "n_obs"
forvalues r = 1/`=_N' {
    local rw = 3 + `r'
    local ms : label (muestra) `=muestra[`r']'
    putexcel A`rw' = "`ms'" B`rw' = (anio[`r']) C`rw' = (n_obs[`r'])
}

* --- Hoja 2: ingreso real medio, una columna por variable ------------------
putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("ingreso_real") modify
putexcel A1 = "Ingreso real medio por muestra y anio"
putexcel A3 = "muestra" B3 = "anio"
local c = 2
foreach v of global inc_vars {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'3 = "`v'"
    forvalues r = 1/`=_N' {
        local rw = 3 + `r'
        putexcel `cl'`rw' = (real_`v'[`r'])
    }
}
forvalues r = 1/`=_N' {
    local rw = 3 + `r'
    local ms : label (muestra) `=muestra[`r']'
    putexcel A`rw' = "`ms'" B`rw' = (anio[`r'])
}

* --- Hojas 3-5: una columna por par variable x definicion de t0 ------------

foreach blk in g_medio mov_resumen extremos {

    putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("`blk'") modify

    if "`blk'" == "g_medio"     putexcel A1 = "Crecimiento real medio desde t0"
    if "`blk'" == "mov_resumen" putexcel A1 = "Movilidad relativa: |cambio de decil| medio"
    if "`blk'" == "extremos"    putexcel A1 = "P(permanecer en el decil de origen)"
    putexcel A2 = "columnas: variable de ingreso x definicion de t0 (a = $t0_year, b = $t0_win_first-$t0_win_last)"
    putexcel A4 = "muestra" B4 = "anio"

    forvalues r = 1/`=_N' {
        local rw = 4 + `r'
        local ms : label (muestra) `=muestra[`r']'
        putexcel A`rw' = "`ms'" B`rw' = (anio[`r'])
    }

    local c = 2
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            if "`blk'" == "extremos" putexcel `cl'4 = "`v'_`j'_top"
            else                     putexcel `cl'4 = "`v'_`j'"
            forvalues r = 1/`=_N' {
                local rw = 4 + `r'
                if "`blk'" == "g_medio"     putexcel `cl'`rw' = (gw_`j'_`v'[`r'])
                if "`blk'" == "mov_resumen" putexcel `cl'`rw' = (adec_`j'_`v'[`r'])
                if "`blk'" == "extremos"    putexcel `cl'`rw' = (top_`j'_`v'[`r'])
            }
        }
    }

    * columnas extra del bloque "extremos": permanencia en el fondo
    if "`blk'" == "extremos" {
        foreach v of global inc_vars {
            foreach j in a b {
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                putexcel `cl'4 = "`v'_`j'_bot"
                forvalues r = 1/`=_N' {
                    local rw = 4 + `r'
                    putexcel `cl'`rw' = (bot_`j'_`v'[`r'])
                }
            }
        }
    }
}

di as result "Excel escrito: $out/tablas/D_resumen_por_anio_${shock}.xlsx"


* ---- 06.1 Crecimiento medio por muestra x anio x decil de origen ---------
* Es el insumo directo del analisis (1).

putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("g_medio") replace
putexcel A1 = "Crecimiento real medio por muestra, anio y decil de origen -- $shock_lab"
putexcel A4 = "muestra" B4 = "anio" C4 = "decil_t0"

putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("n_obs") modify
putexcel A1 = "N por muestra, anio y decil de origen -- $shock_lab"
putexcel A4 = "muestra" B4 = "anio" C4 = "decil_t0"

* Esqueleto de filas: muestra x anio x decil (1..10), en orden fijo.
* Se escribe hoja por hoja: cada -putexcel set- reabre el archivo, asi que
* alternar de hoja dentro del loop lo hace inutilmente lento.
foreach hoja in g_medio n_obs {
    putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("`hoja'") modify
    local rw = 4
    foreach s of global samples {
        foreach y of global out_years {
            forvalues d = 1/10 {
                local rw = `rw' + 1
                putexcel A`rw' = "`s'" B`rw' = `y' C`rw' = `d'
            }
        }
    }
}

local OY "$out_years"
local c = 3
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        local cl : word `c' of $XLCOL

        use "$work/${fstem}_slim_gdec.dta", clear
        keep if !missing(decil0_`j'_`v')
        gen byte n = 1
        collapse (sum) n_obs = n (mean) g = gw_`j'_`v', ///
                 by(muestra anio decil0_`j'_`v')
        rename decil0_`j'_`v' decil_t0

        foreach hoja in g_medio n_obs {
            putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("`hoja'") modify
            putexcel `cl'4 = "`v'_`j'"
            forvalues r = 1/`=_N' {
                local _yy = anio[`r']
                local yi : list posof `"`_yy'"' in OY
                local si = muestra[`r']
                local dd = decil_t0[`r']
                if `yi' > 0 {
                    local rw = 4 + (`si'-1)*$n_out_years*10 + (`yi'-1)*10 + `dd'
                    if "`hoja'" == "g_medio" putexcel `cl'`rw' = (g[`r'])
                    else                     putexcel `cl'`rw' = (n_obs[`r'])
                }
            }
        }
        di as text "  g por decil: `v'_`j' listo"
    }
}
di as result "Excel escrito: $out/tablas/D_g_por_decil_${shock}.xlsx"


* ---- 06.2 Matrices de transicion decil de origen -> decil del anio -------

if $do_transmat == 1 {
    use "$work/${fstem}_slim_trans.dta", clear
    capture log close _all
    log using "$out/descriptivos/transiciones_${shock}.log", text replace
    di as result _n "== MATRICES DE TRANSICION (fila = decil de origen, % por fila) =="
    di as result    "   $shock_lab"
    local si = 0
    foreach s of global samples {
        local si = `si' + 1
        foreach v of global inc_vars {
            foreach j in a b {
                di as result _n "##### muestra `s' | `v' | definicion de t0: (`j') #####"
                foreach y of global out_years {
                    di as result _n "  anio = `y'"
                    tabulate decil0_`j'_`v' decil_`v' if anio == `y' & muestra == `si', ///
                        row nofreq
                }
            }
        }
    }
    log close
}


* ============================================================================
* 07. ANALISIS (1): CRECIMIENTO -- BRECHA D$hi_decile vs D$lo_decile
* ============================================================================
* Especificacion dif-en-dif, para cada muestra, variable de ingreso y def. t0:
*   g_it = a + SUM_t b_t 1[anio=t] + c 1[origen=D$hi_decile]
*            + SUM_t d_t 1[anio=t] 1[origen=D$hi_decile] + e_it
* con anio base $pre_year y decil base D$lo_decile. Entonces
*   d_t = [g(D$hi_decile,t) - g(D$lo_decile,t)]
*       - [g(D$hi_decile,$pre_year) - g(D$lo_decile,$pre_year)]
* EE agrupados por persona. Las regresiones se corren UNA sola vez: los
* resultados se acumulan en matrices y se vuelcan a Excel al final del bloque.

use "$work/${fstem}_analysis.dta", clear

matrix A1_dd = J($n_rows_p, $n_pairs, .)    // coeficiente dif-en-dif
matrix A1_se = J($n_rows_p, $n_pairs, .)    // error estandar
matrix A1_p  = J($n_rows_p, $n_pairs, .)    // p-valor
matrix A1_gp = J($n_rows_y, $n_pairs, .)    // nivel de la brecha por anio

capture log close _all
log using "$out/regresiones/A1_crecimiento_${shock}.log", text replace

di as result _n "===================================================================="
di as result    " (1) CRECIMIENTO: D$hi_decile vs D$lo_decile -- $shock_lab"
di as result    " dependiente: g winsorizado p$wins_p"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            * ---- 7.1 Solo los dos deciles de interes (dif-en-dif limpio) --
            di as result _n "-- [A1] anio x decil, solo D$lo_decile y D$hi_decile --"
            capture noisily reg gw_`j'_`v'                                    ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'             ///
                if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                vce(cluster id)

            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_post + `rr'
                    capture lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc {
                        matrix A1_dd[`row', `c'] = r(estimate)
                        matrix A1_se[`row', `c'] = r(se)
                        matrix A1_p[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                    }
                }
                local rr = 0
                foreach y of global out_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_out_years + `rr'
                    if `y' == $pre_year capture lincom ${hi_decile}.decil0_`j'_`v'
                    else capture lincom ${hi_decile}.decil0_`j'_`v' + `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc matrix A1_gp[`row', `c'] = r(estimate)
                }

                * ---- 7.2 Version 2x2 (post agrupado) ---------------------
                di as result _n "-- [A1] 2x2: post x D$hi_decile --"
                capture noisily reg gw_`j'_`v' i.post##i.hi_`j'_`v'           ///
                    if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                    vce(cluster id)

                * ---- 7.3 Todos los deciles de origen (contexto) ----------
                di as result _n "-- [A1] Todos los deciles de origen, base D$lo_decile --"
                capture noisily reg gw_`j'_`v'                                ///
                    ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'         ///
                    if muestra == `si', vce(cluster id)

                * ---- 7.4 Robustez: log-crecimiento -----------------------
                di as result _n "-- [A1] Robustez con log-crecimiento --"
                capture noisily reg lg_`j'_`v'                                ///
                    ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'         ///
                    if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                    vce(cluster id)
            }
            else di as error "  regresion no estimable para `v'_`j' en la muestra `s'"
        }
    }
}

log close

* ---- 07.5 Excel: resultados lado a lado -----------------------------------

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("did_coef") replace
putexcel A1 = "(1) Cambio de la brecha de crecimiento D$hi_decile - D$lo_decile respecto de $pre_year"
putexcel A2 = "Shock" B2 = "$shock"
putexcel A3 = "columnas: variable de ingreso x definicion de t0 (a = $t0_year, b = $t0_win_first-$t0_win_last)"
putexcel A5 = "muestra" B5 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'5 = "`pl'"
}
local rw = 5
foreach s of global samples {
    foreach y of global post_years {
        local rw = `rw' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
    }
}
putexcel C6 = matrix(A1_dd)

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("did_detalle") modify
putexcel A1 = "(1) dif-en-dif: coeficiente, error estandar y p-valor"
putexcel A4 = "muestra" B4 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    forvalues st = 1/3 {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        if `st' == 1 putexcel `cl'3 = "`pl'"
        if `st' == 1 putexcel `cl'4 = "coef"
        if `st' == 2 putexcel `cl'4 = "EE"
        if `st' == 3 putexcel `cl'4 = "p"
    }
}
local rw = 4
local row = 0
foreach s of global samples {
    foreach y of global post_years {
        local rw  = `rw' + 1
        local row = `row' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
        local c = 2
        forvalues k = 1/$n_pairs {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_dd[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_se[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_p[`row', `k'])
        }
    }
}

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("brecha_nivel") modify
putexcel A1 = "(1) Nivel de la brecha D$hi_decile - D$lo_decile en cada anio"
putexcel A3 = "muestra" B3 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'3 = "`pl'"
}
local rw = 3
foreach s of global samples {
    foreach y of global out_years {
        local rw = `rw' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
    }
}
putexcel C4 = matrix(A1_gp)

di as result "Excel escrito: $out/tablas/A1_crecimiento_${shock}.xlsx"


* ============================================================================
* 08. ANALISIS (2): MOVILIDAD RELATIVA BASADA EN CAMBIOS DE DECIL
* ============================================================================
* Por muestra y anio, siempre respecto del decil de ORIGEN fijado en t0:
*   - E|delta decil|, %sube, %baja, %se queda
*   - persistencia rango-rango: decil_t = a + b*decil_t0 (b alto = poca
*     movilidad relativa)
*   - indice de Shorrocks   M = (K - traza(P)) / (K - 1)
*   - indice de Bartholomew B = (1/K) SUM_i SUM_k p_ik |i - k|
*     (en ambos: mas alto = mas movilidad)
* Los indices se calculan con -contract- (rapido), no con -tabulate-.
* NOTA: con deciles de origen de igual tamano, Bartholomew y E|delta decil|
* coinciden casi exactamente por construccion; no es un error.

matrix A2_sh = J($n_rows_y, $n_pairs, .)   // Shorrocks
matrix A2_bt = J($n_rows_y, $n_pairs, .)   // Bartholomew
matrix A2_ad = J($n_rows_y, $n_pairs, .)   // |delta decil| medio
matrix A2_st = J($n_rows_y, $n_pairs, .)   // % se queda
matrix A2_up = J($n_rows_y, $n_pairs, .)   // % sube
matrix A2_dn = J($n_rows_y, $n_pairs, .)   // % baja
matrix A2_rr = J($n_rows_y, $n_pairs, .)   // pendiente rango-rango

* ---- 08.1 Descriptivos de movilidad por muestra y anio (collapse) --------

use "$work/${fstem}_slim_desc.dta", clear
collapse (mean) adec_* up_* down_* stay_*, by(muestra anio)
sort muestra anio

local OY "$out_years"
local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        forvalues r = 1/`=_N' {
            local _yy = anio[`r']
            local yi : list posof `"`_yy'"' in OY
            local si = muestra[`r']
            if `yi' > 0 {
                local row = (`si' - 1) * $n_out_years + `yi'
                local _v1 = adec_`j'_`v'[`r']
                local _v2 = stay_`j'_`v'[`r']
                local _v3 = up_`j'_`v'[`r']
                local _v4 = down_`j'_`v'[`r']
                matrix A2_ad[`row', `c'] = `_v1'
                matrix A2_st[`row', `c'] = `_v2'
                matrix A2_up[`row', `c'] = `_v3'
                matrix A2_dn[`row', `c'] = `_v4'
            }
        }
    }
}

* ---- 08.2 Shorrocks y Bartholomew (via contract) -------------------------

local si = 0
foreach s of global samples {
    local si = `si' + 1
    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1
            local yi = 0
            foreach y of global out_years {
                local yi = `yi' + 1
                local row = (`si' - 1) * $n_out_years + `yi'

                use "$work/${fstem}_slim_trans.dta", clear
                keep if muestra == `si' & anio == `y' &            ///
                        !missing(decil0_`j'_`v') & !missing(decil_`v')
                quietly count
                if r(N) > 0 {
                    contract decil0_`j'_`v' decil_`v', freq(nn)
                    rename decil0_`j'_`v' d0
                    rename decil_`v'       d1
                    bysort d0: egen double rowN = total(nn)
                    gen double p     = nn / rowN
                    gen double pdiag = p * (d0 == d1)
                    gen double pbart = p * abs(d0 - d1)
                    quietly summarize d0
                    local K = r(max)
                    collapse (sum) sumdiag = pdiag sumbart = pbart
                    local tr = sumdiag[1]
                    local bt = sumbart[1]
                    if `K' > 1 {
                        matrix A2_sh[`row', `c'] = (`K' - `tr') / (`K' - 1)
                        matrix A2_bt[`row', `c'] = `bt' / `K'
                    }
                }
            }
            di as text "  indices de movilidad: `s' | `v'_`j' listo"
        }
    }
}

* ---- 08.3 Regresiones de movilidad + pendiente rango-rango ---------------

use "$work/${fstem}_analysis.dta", clear

matrix A2_rdd = J($n_rows_p, $n_pairs, .)   // coef. del anio sobre |delta decil|
matrix A2_rse = J($n_rows_p, $n_pairs, .)
matrix A2_rp  = J($n_rows_p, $n_pairs, .)

capture log close _all
log using "$out/regresiones/A2_movilidad_relativa_${shock}.log", text replace

di as result _n "===================================================================="
di as result    " (2) MOVILIDAD RELATIVA (cambios de decil) -- $shock_lab"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            di as result _n "-- [A2] Magnitud: |delta decil| por anio (base $pre_year) --"
            capture noisily reg adec_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)
            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_post + `rr'
                    capture lincom `y'.anio
                    if !_rc {
                        matrix A2_rdd[`row', `c'] = r(estimate)
                        matrix A2_rse[`row', `c'] = r(se)
                        matrix A2_rp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                    }
                }
            }

            di as result _n "-- [A2] Direccion: probabilidad de subir de decil --"
            capture noisily reg up_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Direccion: probabilidad de bajar de decil --"
            capture noisily reg down_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Movimiento neto por decil de origen --"
            capture noisily reg ddec_`j'_`v'                          ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'     ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Persistencia rango-rango en deciles, por anio --"
            di as text     "   pendiente mas alta = mas persistencia = MENOS movilidad"
            capture noisily reg decil_`v' ib${pre_year}.anio##c.decil0_`j'_`v' ///
                if muestra == `si', vce(cluster id)
            if !_rc {
                local yi = 0
                foreach y of global out_years {
                    local yi = `yi' + 1
                    local row = (`si' - 1) * $n_out_years + `yi'
                    if `y' == $pre_year capture lincom c.decil0_`j'_`v'
                    else capture lincom c.decil0_`j'_`v' + `y'.anio#c.decil0_`j'_`v'
                    if !_rc matrix A2_rr[`row', `c'] = r(estimate)
                }
            }

            di as result _n "-- [A2] Persistencia rango-rango en percentiles --"
            capture noisily reg pctl_`v' ib${pre_year}.anio##c.pctl0_`j'_`v' ///
                if muestra == `si', vce(cluster id)
        }
    }
}

log close

* ---- 08.4 Excel: una hoja por indicador ---------------------------------

putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("shorrocks") replace
putexcel A1 = "(2) Indice de Shorrocks (mas alto = mas movilidad)"

foreach hoja in shorrocks bartholomew abs_delta pct_stay pct_up pct_down rank_rank {

    if "`hoja'" != "shorrocks" {
        putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("`hoja'") modify
    }
    if "`hoja'" == "bartholomew" putexcel A1 = "(2) Indice de Bartholomew (mas alto = mas movilidad)"
    if "`hoja'" == "abs_delta"   putexcel A1 = "(2) |Cambio de decil| medio"
    if "`hoja'" == "pct_stay"    putexcel A1 = "(2) Proporcion que se mantiene en su decil de origen"
    if "`hoja'" == "pct_up"      putexcel A1 = "(2) Proporcion que sube de decil"
    if "`hoja'" == "pct_down"    putexcel A1 = "(2) Proporcion que baja de decil"
    if "`hoja'" == "rank_rank"   putexcel A1 = "(2) Pendiente rango-rango (mas alta = MENOS movilidad)"

    putexcel A2 = "Shock" B2 = "$shock"
    putexcel A3 = "columnas: variable de ingreso x definicion de t0"
    putexcel A5 = "muestra" B5 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'5 = "`pl'"
    }
    local rw = 5
    foreach s of global samples {
        foreach y of global out_years {
            local rw = `rw' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
        }
    }
    if "`hoja'" == "shorrocks"   putexcel C6 = matrix(A2_sh)
    if "`hoja'" == "bartholomew" putexcel C6 = matrix(A2_bt)
    if "`hoja'" == "abs_delta"   putexcel C6 = matrix(A2_ad)
    if "`hoja'" == "pct_stay"    putexcel C6 = matrix(A2_st)
    if "`hoja'" == "pct_up"      putexcel C6 = matrix(A2_up)
    if "`hoja'" == "pct_down"    putexcel C6 = matrix(A2_dn)
    if "`hoja'" == "rank_rank"   putexcel C6 = matrix(A2_rr)
}

putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("reg_abs_delta") modify
putexcel A1 = "(2) Efecto del anio sobre |cambio de decil| (base $pre_year): coef, EE, p"
putexcel A4 = "muestra" B4 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    forvalues st = 1/3 {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        if `st' == 1 putexcel `cl'3 = "`pl'"
        if `st' == 1 putexcel `cl'4 = "coef"
        if `st' == 2 putexcel `cl'4 = "EE"
        if `st' == 3 putexcel `cl'4 = "p"
    }
}
local rw = 4
local row = 0
foreach s of global samples {
    foreach y of global post_years {
        local rw  = `rw' + 1
        local row = `row' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
        local c = 2
        forvalues k = 1/$n_pairs {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rdd[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rse[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rp[`row', `k'])
        }
    }
}
di as result "Excel escrito: $out/tablas/A2_movilidad_${shock}.xlsx"


* ============================================================================
* 09. ANALISIS (3): PROBABILIDAD DE PERMANECER EN LOS EXTREMOS
* ============================================================================
*   top_ = 1[decil_t = D$top_decile]  entre quienes empezaron en D$top_decile
*   bot_ = 1[decil_t = D$bot_decile]  entre quienes empezaron en D$bot_decile
* MPL (lectura en puntos porcentuales) y logit con -margins-, anio base
* $pre_year: cada coeficiente es el cambio de la probabilidad de permanecer
* respecto del anio pre-shock.

matrix A3_pt = J($n_rows_y, $n_pairs, .)   // P(seguir en la cima)
matrix A3_pb = J($n_rows_y, $n_pairs, .)   // P(seguir en el fondo)

use "$work/${fstem}_slim_desc.dta", clear
collapse (mean) top_* bot_*, by(muestra anio)
sort muestra anio
local OY "$out_years"
local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        forvalues r = 1/`=_N' {
            local _yy = anio[`r']
            local yi : list posof `"`_yy'"' in OY
            local si = muestra[`r']
            if `yi' > 0 {
                local row = (`si' - 1) * $n_out_years + `yi'
                local _v1 = top_`j'_`v'[`r']
                local _v2 = bot_`j'_`v'[`r']
                matrix A3_pt[`row', `c'] = `_v1'
                matrix A3_pb[`row', `c'] = `_v2'
            }
        }
    }
}

* ---- 09.1 Regresiones ------------------------------------------------------

use "$work/${fstem}_analysis.dta", clear

matrix A3_tdd = J($n_rows_p, $n_pairs, .)
matrix A3_tse = J($n_rows_p, $n_pairs, .)
matrix A3_tp  = J($n_rows_p, $n_pairs, .)
matrix A3_bdd = J($n_rows_p, $n_pairs, .)
matrix A3_bse = J($n_rows_p, $n_pairs, .)
matrix A3_bp  = J($n_rows_p, $n_pairs, .)

capture log close _all
log using "$out/regresiones/A3_permanencia_extremos_${shock}.log", text replace

di as result _n "===================================================================="
di as result    " (3) PERMANENCIA EN LOS EXTREMOS -- $shock_lab"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            foreach ext in top bot {

                if "`ext'" == "top" local decl = $top_decile
                if "`ext'" == "bot" local decl = $bot_decile

                di as result _n "-- [A3] P(seguir en D`decl' | origen D`decl') -- MPL base $pre_year"
                capture noisily reg `ext'_`j'_`v' ib${pre_year}.anio ///
                    if muestra == `si', vce(cluster id)
                if !_rc {
                    local rr = 0
                    foreach y of global post_years {
                        local rr = `rr' + 1
                        local row = (`si' - 1) * $n_post + `rr'
                        capture lincom `y'.anio
                        if !_rc {
                            if "`ext'" == "top" {
                                matrix A3_tdd[`row', `c'] = r(estimate)
                                matrix A3_tse[`row', `c'] = r(se)
                                matrix A3_tp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                            }
                            else {
                                matrix A3_bdd[`row', `c'] = r(estimate)
                                matrix A3_bse[`row', `c'] = r(se)
                                matrix A3_bp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                            }
                        }
                    }
                }

                di as result _n "   Logit + efectos marginales promedio:"
                capture noisily logit `ext'_`j'_`v' ib${pre_year}.anio ///
                    if muestra == `si', vce(cluster id)
                if !_rc capture noisily margins, dydx(anio)
            }
        }
    }
}

log close

* ---- 09.2 Excel ------------------------------------------------------------

foreach hoja in p_stay_top p_stay_bot {
    if "`hoja'" == "p_stay_top" {
        putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") replace
        putexcel A1 = "(3) P(seguir en el decil $top_decile | origen D$top_decile)"
    }
    else {
        putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") modify
        putexcel A1 = "(3) P(seguir en el decil $bot_decile | origen D$bot_decile)"
    }
    putexcel A2 = "Shock" B2 = "$shock"
    putexcel A3 = "columnas: variable de ingreso x definicion de t0"
    putexcel A5 = "muestra" B5 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'5 = "`pl'"
    }
    local rw = 5
    foreach s of global samples {
        foreach y of global out_years {
            local rw = `rw' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
        }
    }
    if "`hoja'" == "p_stay_top" putexcel C6 = matrix(A3_pt)
    if "`hoja'" == "p_stay_bot" putexcel C6 = matrix(A3_pb)
}

foreach hoja in reg_top reg_bot {
    putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") modify
    if "`hoja'" == "reg_top" putexcel A1 = "(3) Cambio de P(seguir en D$top_decile) vs $pre_year: coef, EE, p"
    if "`hoja'" == "reg_bot" putexcel A1 = "(3) Cambio de P(seguir en D$bot_decile) vs $pre_year: coef, EE, p"
    putexcel A4 = "muestra" B4 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        forvalues st = 1/3 {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            if `st' == 1 putexcel `cl'3 = "`pl'"
            if `st' == 1 putexcel `cl'4 = "coef"
            if `st' == 2 putexcel `cl'4 = "EE"
            if `st' == 3 putexcel `cl'4 = "p"
        }
    }
    local rw = 4
    local row = 0
    foreach s of global samples {
        foreach y of global post_years {
            local rw  = `rw' + 1
            local row = `row' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
            local c = 2
            forvalues k = 1/$n_pairs {
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tdd[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bdd[`row', `k'])
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tse[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bse[`row', `k'])
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tp[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bp[`row', `k'])
            }
        }
    }
}
di as result "Excel escrito: $out/tablas/A3_permanencia_${shock}.xlsx"


* ============================================================================
* 10. ANALISIS (4): COTAS DE LEE (2009) SOBRE EL ANALISIS (1)
* ============================================================================
* Solo tiene sentido en la muestra NO balanceada: en la balanceada, por
* construccion, no hay atricion.
*
* PROBLEMA. La probabilidad de seguir declarando cae con el shock y cae MAS
* abajo en la distribucion. Los que quedan en 2020-2022 no son los mismos que
* en $pre_year, asi que la comparacion del analisis (1) mezcla el efecto real
* con un cambio de composicion.
*
* SOLUCION (Lee 2009). Dentro de cada decil de ORIGEN se toma la tasa de
* retencion MINIMA entre los anios y se recorta el excedente de los demas
* anios, siempre por un extremo de la distribucion del crecimiento:
*   cota INFERIOR -> se recorta la cola ALTA  (se supone que los que se
*                    suman en los anios de mayor retencion son los mejores)
*   cota SUPERIOR -> se recorta la cola BAJA
* Con la muestra recortada se reestima el dif-en-dif del analisis (1).
* El efecto verdadero queda, bajo el supuesto de monotonicidad, dentro de
* [cota inferior, cota superior].
*
* Definiciones usadas:
*   en riesgo  = personas con decil de origen definido (estaban en t0)
*   presentes  = las que ademas tienen crecimiento observado ese anio
*   retencion  = presentes / en riesgo, dentro de cada (decil de origen, anio)

if $do_lee == 1 {

matrix A4_lo = J($n_post, $n_pairs, .)   // dif-en-dif con la cota inferior
matrix A4_hi = J($n_post, $n_pairs, .)   // dif-en-dif con la cota superior
matrix A4_rt = J($n_out_years, $n_pairs, .)  // tasa de retencion media del anio

capture log close _all
log using "$out/regresiones/A4_lee_bounds_${shock}.log", text replace

di as result _n "===================================================================="
di as result    " (4) COTAS DE LEE sobre el analisis (1) -- muestra NO balanceada"
di as result    "     $shock_lab"
di as result    "===================================================================="

local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1

        di as result _n "############ `v'  --  definicion de t0: (`j') ############"

        use "$work/${fstem}_analysis.dta", clear
        keep if muestra == 1                      // solo la NO balanceada
        keep if !missing(decil0_`j'_`v')

        * --- tasa de retencion por (decil de origen, anio) ----------------
        bysort id (anio): gen byte _fid = _n == 1
        bysort decil0_`j'_`v': egen double _nrisk = total(_fid)
        gen byte _pres = !missing(gw_`j'_`v')
        bysort decil0_`j'_`v' anio: egen double _npres = total(_pres)
        gen double _ret = _npres / _nrisk
        bysort decil0_`j'_`v': egen double _retmin = min(_ret)
        gen double _q = (_ret - _retmin) / _ret
        replace _q = 0 if missing(_q) | _q < 0

        * --- retencion media del anio (para el reporte) ------------------
        local yi = 0
        foreach y of global out_years {
            local yi = `yi' + 1
            quietly summarize _ret if anio == `y' & _fid
            if r(N) > 0 matrix A4_rt[`yi', `c'] = r(mean)
        }

        * --- posicion de g dentro de la celda (solo presentes) -----------
        gen double _u = runiform()
        sort decil0_`j'_`v' anio _pres gw_`j'_`v' _u
        by decil0_`j'_`v' anio _pres: gen double _rk = _n  if _pres
        by decil0_`j'_`v' anio _pres: gen double _nn = _N  if _pres
        gen double _pr = _rk / _nn

        gen byte lee_lo = _pres & _pr <= 1 - _q    // recorta arriba
        gen byte lee_hi = _pres & _pr >  _q        // recorta abajo
        label var lee_lo "=1 en la muestra recortada de la cota inferior"
        label var lee_hi "=1 en la muestra recortada de la cota superior"

        quietly count if _pres
        di as text "   presentes: " as result r(N)
        quietly count if lee_lo
        di as text "   cota inferior, N = " as result r(N)
        quietly count if lee_hi
        di as text "   cota superior, N = " as result r(N)

        * --- dif-en-dif bajo cada cota -----------------------------------
        foreach cota in lo hi {

            di as result _n "-- [A4] cota `cota' --"
            capture noisily reg gw_`j'_`v'                                    ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'             ///
                if lee_`cota' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                vce(cluster id)

            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    capture lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc {
                        if "`cota'" == "lo" matrix A4_lo[`rr', `c'] = r(estimate)
                        if "`cota'" == "hi" matrix A4_hi[`rr', `c'] = r(estimate)
                    }
                }
            }
            else di as error "  no estimable: `v'_`j' cota `cota'"
        }
    }
}

log close

* ---- 10.1 Excel ------------------------------------------------------------

putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("cotas") replace
putexcel A1 = "(4) Cotas de Lee sobre el dif-en-dif del analisis (1) -- muestra NO balanceada"
putexcel A2 = "Shock" B2 = "$shock"
putexcel A3 = "columnas: variable de ingreso x definicion de t0. El efecto esta entre lo y hi."
putexcel A5 = "cota" B5 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'5 = "`pl'"
}
local rw = 5
foreach cota in lo hi {
    foreach y of global post_years {
        local rw = `rw' + 1
        putexcel A`rw' = "`cota'" B`rw' = `y'
    }
}
putexcel C6 = matrix(A4_lo)
local rw6 = 6 + $n_post
putexcel C`rw6' = matrix(A4_hi)

putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("retencion") modify
putexcel A1 = "(4) Tasa de retencion media por anio (presentes / en riesgo en t0)"
putexcel A3 = "anio"
local c = 1
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'3 = "`pl'"
}
local rw = 3
foreach y of global out_years {
    local rw = `rw' + 1
    putexcel A`rw' = `y'
}
putexcel B4 = matrix(A4_rt)

di as result "Excel escrito: $out/tablas/A4_lee_bounds_${shock}.xlsx"

}


* ============================================================================
* 11. RESUMEN DE SALIDAS
* ============================================================================

di as result _n "===================================================================="
di as result    " LISTO -- $shock_lab"
di as result    "===================================================================="
di as text "Datos intermedios (permanentes):"
di as text "  $work/${fstem}_long.dta       panel persona-anio, ingreso real"
di as text "  $work/${fstem}_t0.dta         niveles de ingreso en t0, por persona"
di as text "  $work/${fstem}_analysis.dta   dataset de analisis (apilado por muestra)"
di as text "  $work/${fstem}_slim_*.dta     archivos adelgazados para descriptivos"
di as text "Excel (filas = muestra x anio ; columnas = variable x definicion de t0):"
di as text "  $out/tablas/D_resumen_por_anio_${shock}.xlsx"
di as text "  $out/tablas/D_g_por_decil_${shock}.xlsx"
di as text "  $out/tablas/A1_crecimiento_${shock}.xlsx"
di as text "  $out/tablas/A2_movilidad_${shock}.xlsx"
di as text "  $out/tablas/A3_permanencia_${shock}.xlsx"
di as text "  $out/tablas/A4_lee_bounds_${shock}.xlsx    (solo muestra no balanceada)"
di as text "Logs de regresiones: $out/regresiones/"

capture log close _all

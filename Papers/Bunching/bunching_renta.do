/*******************************************************************************
* bunching_renta.do
*
* Test de bunching (acumulación) alrededor de:
*   (a) los umbrales de la tabla del impuesto a la renta de personas naturales
*       (Ecuador, SRI), 2010-2024, con la reforma de 2022 como experimento
*       natural para asalariados;
*   (b) la línea de USD 20.000 del RIMPE (negocios populares/emprendedores),
*       desde 2022.
*
* Punto de partida: ingreso pre-impuesto (PreTaxHHI) construido por
*   SRI/Procesamiento/Codigos/Renta/construccion_ingreso_DINA.do
*   (archivos ingreso_dina_YYYY.dta, valores nominales por declarante).
*
* BASE IMPONIBLE (variable de prueba)
*   - Con 2+ empleadores en el F107: siempre la del F102 (el impuesto se debe
*     sobre la base conjunta y están obligados a declarar). Sin F102: se
*     excluyen (se reporta cuántos).
*   - Con un empleador: la del F102 si la hay y es > 0; si no, la del F107.
*   Placebo: PreTaxHHI (ingreso bruto; no tiene kinks en estos valores).
*
* GRUPOS
*   todos      todos los declarantes
*   f102       todos los F102, con y sin RIMPE (composición comparable entre
*              años; f102gen pierde a los sujetos RIMPE desde 2022)
*   f102gen    F102 en régimen general (antes de 2022, todos los F102)
*   f102rimpe  F102 sujetos a RIMPE (suj_reg_rimpe_4896 = SI; desde 2022).
*              Ojo: no está verificado si base_imponible_3480 incluye el
*              ingreso RIMPE; revisar con el diccionario del F102.
*   f107       todos los asalariados con un solo empleador, con la base del
*              F107, presenten o no F102. Los empleadores reportan a todos sus
*              trabajadores, así que esta muestra no está seleccionada por la
*              obligación de declarar en el umbral 1 (fracción básica).
*   f107solo   asalariados con un solo empleador que no presentan F102
*
* ESTIMADOR (Chetty et al. 2011; Kleven y Waseem 2013)
*   1. Declarantes en bins de ancho $delta centrados en el umbral.
*   2. Contrafactual: polinomio de orden $poly ajustado a los conteos por bin,
*      EXCLUYENDO una ventana alrededor del umbral, más dummies de números
*      redondos (bins que contienen un múltiplo de $round_bases USD). El
*      contrafactual conserva el efecto de redondeo, así que el exceso de masa
*      es neto de él.
*   3. Exceso de masa B = suma(observado - contrafactual) en la ventana;
*      b = B / contrafactual suave promedio por bin. También B_izq (exceso a la
*      izquierda, k <= 0) y B_der (masa faltante a la derecha, k > 0).
*   4. Errores estándar: bootstrap de residuos, $reps repeticiones.
*   5. Elasticidad: e = (b * delta) / ( z* * ln((1-t0)/(1-t1)) ).
*   Umbrales múltiplos de 5.000 (2022, umbral 9 = 100.000) no se pueden
*   separar del redondeo: se marcan con round_z = 1 y no entran a los
*   agrupados.
*
* REFORMA 2022 (experimento natural)
*   Hasta 2021 los gastos personales se deducían de la base; desde 2022 son una
*   rebaja del impuesto causado. Para los asalariados era casi el único canal
*   para mover la base: si su bunching venía de ahí, debe caer desde 2022.
*   Se estiman agrupados pre (< $reform_year) y post (>= $reform_year) con las
*   mismas ventanas y se prueba la diferencia de elasticidades. Lo más limpio
*   son los umbrales 1-4: en 2022 los tramos 5-8 bajaron de nivel y se creó el
*   de 37%. En 2023 la tabla cambió a mitad de año (retroactiva).
*
* RIMPE, LÍNEA DE USD 20.000
*   Negocio popular: ingresos brutos hasta 20.000; paga USD 60 fijos
*   (2022-2023) o USD 0-60 según tabla (desde 2024). Por encima: emprendedor,
*   USD 60 + 1% del excedente, más IVA y facturación electrónica. El impuesto
*   a la renta es continuo en 20.000 (pasa de 0% a 1% marginal); el salto está
*   en las obligaciones.
*   Variable: bas_imp_grav_reg_rimpe_5687 (ingresos brutos gravados RIMPE).
*   Muestra: todos los sujetos RIMPE, no solo los negocios populares (filtrar
*   por categoría cortaría la distribución en 20.000 por definición).
*   Placebos del redondeo en 20.000: ingresos empresariales brutos
*   (ingresos_aem_rie_1280) de F102 sin RIMPE desde 2022 y de todos los F102
*   antes de 2022. 20.000 es un número redondo: el exceso a la izquierda se
*   compara con los placebos; la masa faltante a la derecha no la produce el
*   redondeo.
*
* LIMITACIONES
*   - Sin restricción de integración.
*   - Con las bases falsas (n = 1000 por año) los conteos son muy pequeños;
*     los resultados solo sirven para probar el código.
*   - Se asume que el año de los archivos es el ejercicio fiscal.
*
* Salidas ($dir_out):
*   bunching_resultados.dta         umbrales: año/período x grupo x variable x kink
*   bunching_reforma2022.dta        diferencias pre/post 2022
*   bunching_rimpe20000.dta         línea de 20.000 del RIMPE
*   bunching_resultados.xlsx        hojas kinks, reforma_2022, rimpe_20000
*   Graficos/ (archivos png)        histograma + contrafactual
*******************************************************************************/

clear all
set more off
set linesize 160
set seed 20260928

* ============================================================================
* 0. PARÁMETROS
* ============================================================================

global code_dir     "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Papers/Bunching"   // carpeta de este código
global real_data    0        // 0 = bases falsas (Mac);  1 = bases reales (servidor SRI)
global years        "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"  // los que no existan se omiten

global delta        50       // ancho del bin (USD)
global maxwin       2000     // semiancho máximo de la ventana de análisis (USD)
global excl_bins    4        // bins excluidos a cada lado del umbral
global poly         5        // orden del polinomio contrafactual
global reps         200      // repeticiones del bootstrap de residuos
global minobs       100      // mínimo de observaciones en la ventana para estimar
global make_graphs  1        // 1 = exportar gráficos
global round_bases  "500 1000"   // dummies de números redondos ("" = sin control)

global reform_year  2022     // gastos personales pasan de deducción a rebaja
global rimpe_start  2022     // primer ejercicio del RIMPE

* Línea de 20.000 del RIMPE
global rimpe_z      20000
global rimpe_delta  100      // ancho del bin (USD)
global rimpe_K      30       // bins a cada lado (+/- 3.000)
global rimpe_lo     5        // bins excluidos a la izquierda (USD 500)
global rimpe_hi     10       // bins excluidos a la derecha (USD 1.000)

* Si un año no tiene tabla propia en la sección 2, usar la del 2026 (1) o
* omitir el año (0). Con 1 se aplican umbrales 2026 NOMINALES: solo para pruebas.
global fallback2026 0

* ============================================================================
* 1. RUTAS
* ============================================================================

if $real_data == 0 {
    global bunch_dir  "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching"   // datos y resultados: Google Drive (no van a GitHub)
    global dir_f107   "$bunch_dir/Datos_falsos/F107"
    global dir_f102   "$bunch_dir/Datos_falsos/F102"
    global f107_stub  "F107_"
    global f102_stub  "F102_"
    * F102 con bunching inyectado (inyectar_bunching_falso.do); solo trae
    * CEDULA_PK y base_imponible_3480. Para datos sin inyección: dir_f102
    global dir_base102 "$bunch_dir/Datos_falsos/F102_bunching"
    * Salida de construir_ingreso_dina_falso.do (o de construccion_ingreso_DINA.do)
    global dir_merged "$bunch_dir/Datos_falsos/Merged_DINA"
}
else {
    global sri_dir    "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Ruthy Intriago"
    global dir_f107   "$sri_dir/03 BDD/F107"
    global dir_f102   "$sri_dir/03 BDD/F102"
    global f107_stub  "F107_anonimizada_"
    global f102_stub  "F102_anonimizada_"
    global dir_base102 "$dir_f102"
    global dir_merged "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/Merged_DINA"
}

global dir_out  "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/Resultados"
global dir_graf "$dir_out/Graficos"
global dir_tmp  "`c(tmpdir)'/bunching_conteos"   // temporal, fuera de Drive

capture mkdir "$dir_out"
capture mkdir "$dir_graf"
capture mkdir "$dir_tmp"

* Borrar conteos de corridas anteriores (no mezclar parámetros distintos)
local oldfiles : dir "$dir_tmp" files "*.dta"
foreach f of local oldfiles {
    erase "$dir_tmp/`f'"
}

capture log close
log using "$dir_out/bunching_renta.log", replace text

* Dummies de redondeo: nombres de variables y opción para bunch_bin
local rvars ""
foreach R of global round_bases {
    local rvars "`rvars' r`R'"
}
local ropt = cond("$round_bases" == "", "", "round($round_bases)")

* ============================================================================
* 2. TABLAS DEL IMPUESTO A LA RENTA (locals thr_YYYY y rate_YYYY)
*    Ver tablas_impuesto_renta.do (umbrales 2010-2026, con fuentes).
* ============================================================================

include "$code_dir/tablas_impuesto_renta.do"

* ============================================================================
* 3. PROGRAMA MATA: ESTIMADOR DE BUNCHING
* ============================================================================

capture mata: mata drop bunch_X() bunch_stats() bunch_run()

mata:

real matrix bunch_X(real colvector ks, real scalar poly)
{
    real matrix X
    real scalar p
    X = J(rows(ks), 1, 1)
    for (p = 1; p <= poly; p++) X = X, ks:^p
    return(X)
}

// (B, c0, b, B_izq, B_der) dado el observado n, el contrafactual cf (con
// redondeo) y su parte suave cs (solo polinomio).
real rowvector bunch_stats(real colvector n, real colvector cf, real colvector cs,
                           real colvector exi, real colvector exl, real colvector exr)
{
    real scalar B, c0, Bl, Br
    B  = sum(n[exi] - cf[exi])
    c0 = mean(cs[exi])
    Bl = sum(n[exl] - cf[exl])
    Br = sum(cf[exr] - n[exr])
    return((B, c0, B / c0, Bl, Br))
}

// Ajusta el contrafactual (polinomio + dummies de redondeo rvars) fuera de la
// ventana [-lo, hi] (en bins) y calcula el exceso de masa con errores estándar
// por bootstrap de residuos. Guarda cf en cfvar y en la matriz resname:
// (B, c0, b, B_izq, B_der, se_B, se_c0, se_b, se_B_izq, se_B_der).
void bunch_run(string scalar nvar, string scalar kvar, string scalar cfvar,
               string scalar rvars, real scalar lo, real scalar hi,
               real scalar poly, real scalar reps, string scalar resname)
{
    real colvector n, k, ks, cf, cs, res, fitfull, nstar, e, bb, b0
    real colvector inwin, exi, ne, exl, exr
    real matrix X, Xne, XXi, S
    real rowvector st, se
    real scalar K, np, r, m

    n  = st_data(., nvar)
    k  = st_data(., kvar)
    K  = max(abs(k))
    ks = k :/ K
    X  = bunch_X(ks, poly)
    np = cols(X)
    if (rvars != "") X = X, st_data(., rvars)

    inwin = (k :>= -lo) :& (k :<= hi)
    exi   = selectindex(inwin)
    ne    = selectindex(!inwin)
    exl   = selectindex(inwin :& (k :<= 0))
    exr   = selectindex(inwin :& (k :> 0))

    Xne = X[ne, .]
    XXi = invsym(cross(Xne, Xne))
    b0  = XXi * cross(Xne, n[ne])
    cf  = X * b0
    cs  = X[., 1..np] * b0[1..np]
    st  = bunch_stats(n, cf, cs, exi, exl, exr)

    // Bootstrap de residuos: ajustado completo = cf fuera de la ventana y
    // observado dentro (conserva el exceso); residuos = los de fuera.
    res     = n[ne] - cf[ne]
    fitfull = cf
    fitfull[exi] = n[exi]
    m = rows(ne)
    S = J(reps, 5, .)
    for (r = 1; r <= reps; r++) {
        e     = res[1 :+ floor(runiform(rows(n), 1) :* m)]
        nstar = fitfull + e
        bb    = XXi * cross(Xne, nstar[ne])
        S[r, .] = bunch_stats(nstar, X * bb, X[., 1..np] * bb[1..np], exi, exl, exr)
    }
    se = J(1, 5, .)
    if (reps > 1) se = sqrt(diagonal(variance(S)))'

    st_store(., cfvar, cf)
    st_matrix(resname, (st, se))
}
end

* ============================================================================
* 4. PROGRAMAS STATA
* ============================================================================

* bunch_bin: cuenta declarantes por bin de distancia al umbral (k = 0 en z*).
*            Guarda la grilla completa k = -K..K con n (0 si vacío) y, con
*            round(), una dummy rR por base R: el bin contiene un múltiplo de R.
capture program drop bunch_bin
program define bunch_bin, rclass
    syntax varname [if], ZSTAR(real) DELTA(real) K(integer) OUTFILE(string) ///
        [ROUND(numlist)]
    marksample touse, novarlist
    preserve
    quietly {
        keep if `touse' & `varlist' > 0 & !missing(`varlist')
        gen long k = round((`varlist' - `zstar') / `delta')
        keep if abs(k) <= `k'
        gen long n = 1
        local nwin = _N
        if `nwin' > 0 {
            collapse (sum) n, by(k)
        }
        else {
            clear
            set obs 1
            gen long k = .
            gen long n = 0
        }
        tempfile cnt
        save `cnt'
        clear
        set obs `=2*`k'+1'
        gen long k = _n - `k' - 1
        merge 1:1 k using `cnt', nogen
        drop if missing(k)
        replace n = 0 if missing(n)
        gen double x = `zstar' + k * `delta'
        foreach R of local round {
            gen byte r`R' = ceil((x - `delta' / 2) / `R') * `R' < x + `delta' / 2
        }
        drop x
        save "`outfile'", replace
    }
    restore
    return scalar nwin = `nwin'
end

* bunch_fit: lee conteos por bin, estima bunching, (opcional) grafica.
*            Resultados en r() y matriz R_bunch.
capture program drop bunch_fit
program define bunch_fit, rclass
    syntax using/, K(integer) LO(integer) HI(integer) POLY(integer) REPS(integer) ///
        [RVARS(string) ZSTAR(real 0) DELTA(real 1) GRAPHFILE(string) ///
         TITLE(string) XTITLE(string)]
    preserve
    quietly {
        use "`using'", clear
        keep if abs(k) <= `k'
        gen double cf = .
        mata: bunch_run("n", "k", "cf", "`rvars'", `lo', `hi', `poly', `reps', "R_bunch")
    }
    return scalar B     = R_bunch[1,1]
    return scalar c0    = R_bunch[1,2]
    return scalar b     = R_bunch[1,3]
    return scalar Bl    = R_bunch[1,4]
    return scalar Br    = R_bunch[1,5]
    return scalar se_B  = R_bunch[1,6]
    return scalar se_b  = R_bunch[1,8]
    return scalar se_Bl = R_bunch[1,9]
    return scalar se_Br = R_bunch[1,10]

    if "`graphfile'" != "" {
        local bs  = string(R_bunch[1,3], "%5.2f")
        local ses = string(R_bunch[1,8], "%5.2f")
        gen double x = `zstar' + k * `delta'
        local xl = `zstar' - (`lo' + 0.5) * `delta'
        local xr = `zstar' + (`hi' + 0.5) * `delta'
        quietly twoway                                                        ///
            (bar n x, barwidth(`delta') fcolor(gs13) lcolor(gs11))            ///
            (line cf x, lcolor(cranberry) lwidth(medthick)),                  ///
            xline(`xl' `xr', lpattern(dash) lcolor(gs7))                      ///
            xline(`zstar', lcolor(navy))                                      ///
            title(`"`title'"', size(medsmall))                                ///
            xtitle(`"`xtitle'"') ytitle("Declarantes por bin")                ///
            legend(order(1 "Observado" 2 "Contrafactual (con redondeo)") rows(1) position(6)) ///
            note("Exceso de masa b = `bs' (EE = `ses'). Lineas discontinuas: ventana excluida.") ///
            graphregion(color(white))
        quietly graph export "`graphfile'", replace width(1600)
    }
end

* ============================================================================
* 5. PRE-PASO: UMBRALES, TASAS Y VENTANAS POR AÑO Y KINK
*
*   La ventana de cada kink se limita al 45% de la distancia al umbral vecino
*   más cercano para no mezclar kinks. Kpool_j = ventana común de los
*   agrupados (la más angosta entre años).
* ============================================================================

forvalues j = 1/9 {
    local Kpool_`j' = 9999
}

foreach yr of global years {

    local ty `yr'
    if "`thr_`yr''" == "" {
        if $fallback2026 == 1 {
            local ty 2026
            di as error "  ADVERTENCIA: sin tabla propia para `yr'; se usan umbrales 2026 nominales."
        }
        else {
            di as error "  Año `yr' omitido: no hay tabla en la sección 2 (fallback2026 = 0)."
            local skip_`yr' 1
            continue
        }
    }

    local nk : word count `thr_`ty''
    local nk_`yr' = `nk'

    forvalues j = 1/`nk' {
        local z`j' : word `j' of `thr_`ty''
    }

    forvalues j = 1/`nk' {
        local gap = `z`j''
        if `j' > 1 {
            local jm = `j' - 1
            local gap = `z`j'' - `z`jm''
        }
        if `j' < `nk' {
            local jp = `j' + 1
            local gap = min(`gap', `z`jp'' - `z`j'')
        }
        local jn = `j' + 1
        local K_`yr'_`j'  = floor(min($maxwin, 0.45 * `gap') / $delta)
        local zs_`yr'_`j' = `z`j''
        local rz_`yr'_`j' = mod(`z`j'', 5000) == 0
        local t0_`yr'_`j' : word `j'  of `rate_`ty''
        local t1_`yr'_`j' : word `jn' of `rate_`ty''
        local Kpool_`j' = min(`Kpool_`j'', `K_`yr'_`j'')
    }
}

* ============================================================================
* 6. LOOP PRINCIPAL: AÑO x GRUPO x VARIABLE x KINK
* ============================================================================

local groups "todos f102 f102gen f102rimpe f107 f107solo"
local gc_todos     "1 == 1"
local gc_f102      "has102 == 1"
local gc_f102gen   "has102 == 1 & rimpe == 0"
local gc_f102rimpe "has102 == 1 & rimpe == 1"
local gc_f107      "n_emp == 1"
local gc_f107solo  "has102 == 0 & n_emp == 1"
local gv_todos     "base_imp"
local gv_f102      "base_imp"
local gv_f102gen   "base_imp"
local gv_f102rimpe "base_imp"
local gv_f107      "base107"
local gv_f107solo  "base_imp"

* Acumuladores para el umbral promedio (ponderado) de cada agrupado
foreach g of local groups {
    foreach rvlab in base placebo {
        forvalues j = 1/9 {
            foreach p in todo pre post {
                local zw_`g'_`rvlab'_`j'_`p' = 0
                local nw_`g'_`rvlab'_`j'_`p' = 0
            }
        }
    }
}

tempname bh
tempfile res_file
postfile `bh'                                                            ///
    int(anio) str8(periodo) str10(grupo) str8(variable) byte(kink round_z) ///
    double(zstar t0 t1 delta) long(nwin)                                 ///
    double(B c0 b se_b zstat pval_pos pval_two B_izq B_der dz elast se_elast) ///
    using "`res_file'", replace

local years_done ""

foreach yr of global years {

    if "`skip_`yr''" == "1" continue

    capture confirm file "$dir_merged/ingreso_dina_`yr'.dta"
    if _rc {
        di as error "  `yr': no existe $dir_merged/ingreso_dina_`yr'.dta (correr construccion_ingreso_DINA.do); se omite."
        continue
    }
    capture confirm file "$dir_base102/${f102_stub}`yr'.dta"
    local rc1 = _rc
    capture confirm file "$dir_f102/${f102_stub}`yr'.dta"
    local rc2 = _rc
    capture confirm file "$dir_f107/${f107_stub}`yr'.dta"
    if `rc1' | `rc2' | _rc {
        di as error "  `yr': faltan F102/F107 crudos para la base imponible; se omite."
        continue
    }

    di as result _n "===== Bunching `yr' ====="

    * ------------------------------------------------------------------
    * 6.1  F102: base general, RIMPE e ingresos empresariales brutos
    * ------------------------------------------------------------------

    use CEDULA_PK base_imponible_3480 using "$dir_base102/${f102_stub}`yr'.dta", clear
    capture destring base_imponible_3480, replace force
    drop if CEDULA_PK == ""
    collapse (max) base102 = base_imponible_3480, by(CEDULA_PK)
    tempfile b102
    save `b102'

    * Las variables RIMPE solo existen en algunos años: tomar las disponibles
    quietly describe using "$dir_f102/${f102_stub}`yr'.dta", varlist
    local avail `r(varlist)'
    local want suj_reg_rimpe_4896 bas_imp_grav_reg_rimpe_5687 ingresos_aem_rie_1280
    local get : list want & avail
    use CEDULA_PK `get' using "$dir_f102/${f102_stub}`yr'.dta", clear
    drop if CEDULA_PK == ""

    gen byte rimpe = 0
    capture confirm variable suj_reg_rimpe_4896
    if !_rc {
        capture confirm string variable suj_reg_rimpe_4896
        if !_rc replace rimpe = upper(strtrim(suj_reg_rimpe_4896)) == "SI"
        else    replace rimpe = suj_reg_rimpe_4896 == 1
    }
    if `yr' < $rimpe_start replace rimpe = 0
    foreach v in bas_imp_grav_reg_rimpe_5687 ingresos_aem_rie_1280 {
        capture confirm variable `v'
        if _rc gen double `v' = .
        capture destring `v', replace force
    }
    collapse (max) rimpe rimpe_bruto = bas_imp_grav_reg_rimpe_5687 ///
        emp_bruto = ingresos_aem_rie_1280, by(CEDULA_PK)
    merge 1:1 CEDULA_PK using `b102', nogen
    gen byte has102 = 1
    save `b102', replace

    * ------------------------------------------------------------------
    * 6.2  F107: número de empleadores y base con un solo empleador
    * ------------------------------------------------------------------

    quietly describe using "$dir_f107/${f107_stub}`yr'.dta", varlist
    local avail `r(varlist)'
    local has_ruc : list posof "RUC_PK_empleador" in avail
    if `has_ruc' {
        use CEDULA_PK_empleado RUC_PK_empleador base_imponible ///
            using "$dir_f107/${f107_stub}`yr'.dta", clear
        capture tostring RUC_PK_empleador, replace
    }
    else {
        di as error "  `yr': F107 sin RUC_PK_empleador; cada registro cuenta como un empleador."
        use CEDULA_PK_empleado base_imponible using "$dir_f107/${f107_stub}`yr'.dta", clear
        gen str20 RUC_PK_empleador = ""
    }
    rename CEDULA_PK_empleado CEDULA_PK
    capture destring base_imponible, replace force
    drop if CEDULA_PK == ""
    replace RUC_PK_empleador = "sin_ruc_" + string(_n) if inlist(RUC_PK_empleador, "", ".")

    * Un registro por persona y empleador (sustitutivas: el máximo)
    collapse (max) base_imponible, by(CEDULA_PK RUC_PK_empleador)
    bysort CEDULA_PK: gen int n_emp = _N
    collapse (max) base107 = base_imponible n_emp, by(CEDULA_PK)
    replace base107 = . if n_emp > 1

    merge 1:1 CEDULA_PK using `b102', nogen
    replace has102 = 0 if missing(has102)
    replace rimpe  = 0 if missing(rimpe)
    replace n_emp  = 0 if missing(n_emp)

    * Base imponible: 2+ empleadores -> F102; un empleador -> F102 si > 0,
    * si no F107. 2+ empleadores sin F102 quedan en missing (excluidos).
    gen double base_imp = .
    replace base_imp = base102 if has102 == 1 & ///
        (n_emp > 1 | (base102 > 0 & !missing(base102)))
    replace base_imp = base107 if missing(base_imp) & n_emp == 1

    quietly count if n_emp > 1
    local nmult = r(N)
    quietly count if n_emp > 1 & has102 == 0
    di as text "  Con 2+ empleadores: `nmult'  (sin F102, excluidos: " r(N) ")"

    keep CEDULA_PK base_imp base107 n_emp has102 rimpe rimpe_bruto emp_bruto
    tempfile tb
    save `tb'

    * ------------------------------------------------------------------
    * 6.3  Ingreso pre-impuesto (DINA) + bases
    * ------------------------------------------------------------------

    use CEDULA_PK PreTaxHHI using "$dir_merged/ingreso_dina_`yr'.dta", clear
    merge m:1 CEDULA_PK using `tb', keep(1 3) nogen
    foreach v in has102 rimpe n_emp {
        replace `v' = 0 if missing(`v')
    }

    quietly count if base_imp > 0 & !missing(base_imp)
    di as text "  Declarantes con base imponible > 0: " r(N)
    if `yr' >= $rimpe_start {
        quietly count if rimpe == 1
        di as text "  Sujetos RIMPE: " r(N)
    }

    local years_done "`years_done' `yr'"
    local nkyr = `nk_`yr''
    local per  = cond(`yr' < $reform_year, "pre", "post")

    * ------------------------------------------------------------------
    * 6.4  Estimación por grupo, variable y kink
    * ------------------------------------------------------------------

    foreach g of local groups {

        if "`g'" == "f102rimpe" & `yr' < $rimpe_start continue

        foreach rvlab in base placebo {

            local rv = cond("`rvlab'" == "base", "`gv_`g''", "PreTaxHHI")

            forvalues j = 1/`nkyr' {

                local Kj = `K_`yr'_`j''
                local zs = `zs_`yr'_`j''
                local t0 = `t0_`yr'_`j''
                local t1 = `t1_`yr'_`j''
                local rz = `rz_`yr'_`j''

                if `Kj' < $excl_bins + 15 {
                    di as text "  kink `j' `yr': ventana muy angosta; se omite."
                    continue
                }

                local cnt "$dir_tmp/cnt_`yr'_`g'_`rvlab'_`j'.dta"

                bunch_bin `rv' if `gc_`g'', zstar(`zs') delta($delta) ///
                    k(`Kj') outfile("`cnt'") `ropt'
                local nwin = r(nwin)

                if !`rz' {
                    foreach p in todo `per' {
                        local zw_`g'_`rvlab'_`j'_`p' = `zw_`g'_`rvlab'_`j'_`p'' + `zs' * `nwin'
                        local nw_`g'_`rvlab'_`j'_`p' = `nw_`g'_`rvlab'_`j'_`p'' + `nwin'
                    }
                }

                if `nwin' < $minobs {
                    post `bh' (`yr') ("anual") ("`g'") ("`rvlab'") (`j') (`rz') ///
                        (`zs') (`t0') (`t1') ($delta) (`nwin')                  ///
                        (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
                    continue
                }

                local gf ""
                if $make_graphs == 1 & "`g'" == "todos" & "`rvlab'" == "base" {
                    local gf "$dir_graf/bunch_`yr'_kink`j'.png"
                }

                bunch_fit using "`cnt'", k(`Kj') lo($excl_bins) hi($excl_bins) ///
                    poly($poly) reps($reps) rvars(`rvars') zstar(`zs')         ///
                    delta($delta) graphfile("`gf'")                            ///
                    title("`yr' - umbral `j': USD `zs' (tasa `t0' a `t1')")    ///
                    xtitle("Base imponible (USD nominales)")

                local b   = r(b)
                local seb = r(se_b)
                local zst = `b' / `seb'
                local den = `zs' * ln((1 - `t0') / (1 - `t1'))

                post `bh' (`yr') ("anual") ("`g'") ("`rvlab'") (`j') (`rz')      ///
                    (`zs') (`t0') (`t1') ($delta) (`nwin')                      ///
                    (r(B)) (r(c0)) (`b') (`seb') (`zst')                        ///
                    (1 - normal(`zst')) (2 * (1 - normal(abs(`zst'))))          ///
                    (r(Bl)) (r(Br)) (`b' * $delta)                              ///
                    (`b' * $delta / `den') (`seb' * $delta / `den')
            }
        }
    }

    * ------------------------------------------------------------------
    * 6.5  RIMPE: conteos alrededor de la línea de 20.000
    * ------------------------------------------------------------------

    if `yr' >= $rimpe_start {
        bunch_bin rimpe_bruto if has102 == 1 & rimpe == 1, zstar($rimpe_z) ///
            delta($rimpe_delta) k($rimpe_K) outfile("$dir_tmp/rim_`yr'_rimpe.dta") `ropt'
        bunch_bin emp_bruto if has102 == 1 & rimpe == 0, zstar($rimpe_z) ///
            delta($rimpe_delta) k($rimpe_K) outfile("$dir_tmp/rim_`yr'_plac_post.dta") `ropt'
    }
    else {
        bunch_bin emp_bruto if has102 == 1, zstar($rimpe_z) ///
            delta($rimpe_delta) k($rimpe_K) outfile("$dir_tmp/rim_`yr'_plac_pre.dta") `ropt'
    }
}

* ============================================================================
* 7. AGRUPADOS (anio = 0): años apilados en distancia al umbral
*    periodo: todo (todos los años), pre (< reforma), post (>= reforma)
* ============================================================================

di as result _n "===== Bunching agrupado ====="

foreach g of local groups {
    foreach rvlab in base placebo {
        forvalues j = 1/9 {

            local Kp = `Kpool_`j''
            if `Kp' < $excl_bins + 15 continue
            local jn = `j' + 1
            local t0 : word `j'  of `r9'
            local t1 : word `jn' of `r9'

            foreach p in todo pre post {

                local have 0
                tempfile acc
                foreach yr of local years_done {
                    if "`p'" == "pre"  & `yr' >= $reform_year continue
                    if "`p'" == "post" & `yr' <  $reform_year continue
                    if `j' > `nk_`yr'' continue
                    if `rz_`yr'_`j'' continue
                    local cnt "$dir_tmp/cnt_`yr'_`g'_`rvlab'_`j'.dta"
                    capture confirm file "`cnt'"
                    if _rc continue
                    use "`cnt'", clear
                    keep if abs(k) <= `Kp'
                    if `have' append using `acc'
                    save `acc', replace
                    local have 1
                }
                if `have' == 0 continue

                * Redondeo: en el agrupado cada dummy cuenta en cuántos años
                * el bin contiene un número redondo
                collapse (sum) n `rvars', by(k)
                quietly summarize n, meanonly
                local nwin = r(sum)
                local pfile "$dir_tmp/cnt_pool_`p'_`g'_`rvlab'_`j'.dta"
                save "`pfile'", replace

                local zbar = .
                if `nw_`g'_`rvlab'_`j'_`p'' > 0 {
                    local zbar = `zw_`g'_`rvlab'_`j'_`p'' / `nw_`g'_`rvlab'_`j'_`p''
                }

                if `nwin' < $minobs {
                    post `bh' (0) ("`p'") ("`g'") ("`rvlab'") (`j') (0) (`zbar') ///
                        (`t0') (`t1') ($delta) (`nwin')                          ///
                        (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
                    continue
                }

                local gf ""
                if $make_graphs == 1 & "`rvlab'" == "base" {
                    local gf "$dir_graf/bunch_agrupado_`p'_`g'_kink`j'.png"
                }

                bunch_fit using "`pfile'", k(`Kp') lo($excl_bins) hi($excl_bins) ///
                    poly($poly) reps($reps) rvars(`rvars') zstar(0)             ///
                    delta($delta) graphfile("`gf'")                             ///
                    title("Agrupado `p' (`g') - umbral `j'")                    ///
                    xtitle("Distancia al umbral (USD nominales)")

                local b   = r(b)
                local seb = r(se_b)
                local zst = `b' / `seb'
                local den = `zbar' * ln((1 - `t0') / (1 - `t1'))

                post `bh' (0) ("`p'") ("`g'") ("`rvlab'") (`j') (0) (`zbar')     ///
                    (`t0') (`t1') ($delta) (`nwin')                              ///
                    (r(B)) (r(c0)) (`b') (`seb') (`zst')                         ///
                    (1 - normal(`zst')) (2 * (1 - normal(abs(`zst'))))           ///
                    (r(Bl)) (r(Br)) (`b' * $delta)                               ///
                    (`b' * $delta / `den') (`seb' * $delta / `den')
            }
        }
    }
}

postclose `bh'

* ============================================================================
* 8. RIMPE: LÍNEA DE 20.000
*    series: rimpe (sujetos RIMPE, 2022+), plac_post (F102 sin RIMPE, 2022+),
*    plac_pre (todos los F102, antes de 2022). anio = 0: agrupado.
* ============================================================================

di as result _n "===== RIMPE: línea de 20.000 ====="

tempname rh
tempfile rim_file
postfile `rh' str10(serie) int(anio) long(nwin)                          ///
    double(B c0 b se_b b_izq se_b_izq pval_izq b_der se_b_der pval_der)  ///
    using "`rim_file'", replace

foreach s in rimpe plac_post plac_pre {

    * Por año (solo la serie RIMPE) y agrupado
    local have 0
    tempfile acc
    foreach yr of local years_done {
        local cnt "$dir_tmp/rim_`yr'_`s'.dta"
        capture confirm file "`cnt'"
        if _rc continue

        if "`s'" == "rimpe" {
            use "`cnt'", clear
            quietly summarize n, meanonly
            local nwy = r(sum)
            if `nwy' >= $minobs {
                bunch_fit using "`cnt'", k($rimpe_K) lo($rimpe_lo) hi($rimpe_hi) ///
                    poly($poly) reps($reps) rvars(`rvars')
                local c0 = r(c0)
                post `rh' ("`s'") (`yr') (`nwy') (r(B)) (`c0') (r(b)) (r(se_b)) ///
                    (r(Bl) / `c0') (r(se_Bl) / `c0') (1 - normal(r(Bl) / r(se_Bl))) ///
                    (r(Br) / `c0') (r(se_Br) / `c0') (1 - normal(r(Br) / r(se_Br)))
            }
        }

        use "`cnt'", clear
        if `have' append using `acc'
        save `acc', replace
        local have 1
    }
    if `have' == 0 continue

    collapse (sum) n `rvars', by(k)
    quietly summarize n, meanonly
    local nwin = r(sum)
    local pfile "$dir_tmp/rim_pool_`s'.dta"
    save "`pfile'", replace

    if `nwin' < $minobs {
        post `rh' ("`s'") (0) (`nwin') (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
        continue
    }

    local gf ""
    if $make_graphs == 1 local gf "$dir_graf/rimpe20000_`s'.png"
    local xt = cond("`s'" == "rimpe", "Ingresos brutos RIMPE (USD)", ///
                                      "Ingresos empresariales brutos (USD)")

    bunch_fit using "`pfile'", k($rimpe_K) lo($rimpe_lo) hi($rimpe_hi)   ///
        poly($poly) reps($reps) rvars(`rvars') zstar($rimpe_z)             ///
        delta($rimpe_delta) graphfile("`gf'")                              ///
        title("Linea de 20.000 del RIMPE - `s' (agrupado)") xtitle("`xt'")

    local c0 = r(c0)
    post `rh' ("`s'") (0) (`nwin') (r(B)) (`c0') (r(b)) (r(se_b))            ///
        (r(Bl) / `c0') (r(se_Bl) / `c0') (1 - normal(r(Bl) / r(se_Bl)))    ///
        (r(Br) / `c0') (r(se_Br) / `c0') (1 - normal(r(Br) / r(se_Br)))
}

postclose `rh'

* ============================================================================
* 9. GUARDAR, DIFERENCIAS Y EXPORTAR
* ============================================================================

* --- 9.1 Umbrales ---
use "`res_file'", clear

label var anio      "Año (0 = agrupado)"
label var periodo   "anual / todo / pre (< reforma) / post (>= reforma)"
label var grupo     "Grupo"
label var variable  "base = base imponible; placebo = PreTaxHHI"
label var kink      "Umbral (1 = fracción exenta)"
label var round_z   "Umbral múltiplo de 5.000 (no separable del redondeo)"
label var zstar     "Umbral (USD nominales; agrupado: promedio ponderado)"
label var t0        "Tasa marginal debajo del umbral"
label var t1        "Tasa marginal encima del umbral"
label var delta     "Ancho del bin (USD)"
label var nwin      "Declarantes en la ventana"
label var B         "Exceso de masa (declarantes)"
label var c0        "Contrafactual suave promedio por bin"
label var b         "Bunching normalizado b = B/c0"
label var se_b      "EE bootstrap de b"
label var zstat     "b / EE"
label var pval_pos  "p-valor una cola (H1: b > 0)"
label var pval_two  "p-valor dos colas"
label var B_izq     "Exceso a la izquierda del umbral (k <= 0)"
label var B_der     "Masa faltante a la derecha (k > 0)"
label var dz        "Desplazamiento del bunching (USD) = b*delta"
label var elast     "Elasticidad del ingreso imponible"
label var se_elast  "EE de la elasticidad"

sort grupo variable periodo anio kink
save "$dir_out/bunching_resultados.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("kinks") firstrow(varlabels) replace

* --- 9.2 Reforma 2022: pre vs post ---
keep if anio == 0 & inlist(periodo, "pre", "post") & !missing(b)
keep grupo variable kink periodo nwin b se_b elast se_elast
reshape wide nwin b se_b elast se_elast, i(grupo variable kink) j(periodo) string
foreach v in nwin b se_b elast se_elast {
    capture confirm variable `v'pre
    if _rc gen double `v'pre = .
    capture confirm variable `v'post
    if _rc gen double `v'post = .
}
gen double dif_elast    = elastpost - elastpre
gen double se_dif_elast = sqrt(se_elastpost^2 + se_elastpre^2)
gen double z_dif        = dif_elast / se_dif_elast
gen double p_dif        = 2 * (1 - normal(abs(z_dif)))
order grupo variable kink nwinpre elastpre se_elastpre nwinpost elastpost ///
    se_elastpost dif_elast se_dif_elast p_dif bpre se_bpre bpost se_bpost
label var dif_elast    "Elasticidad post - pre"
label var se_dif_elast "EE de la diferencia"
label var p_dif        "p-valor dos colas de la diferencia"
sort grupo variable kink
save "$dir_out/bunching_reforma2022.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("reforma_2022", replace) firstrow(variables)

di as result _n "===== Reforma 2022: elasticidad pre vs post (base imponible) ====="
format elastpre se_elastpre elastpost se_elastpost dif_elast se_dif_elast p_dif %7.3f
foreach g in f107 f107solo f102 f102gen todos {
    di as text _n "--- Grupo: `g' ---"
    list kink nwinpre elastpre se_elastpre nwinpost elastpost se_elastpost dif_elast p_dif ///
        if variable == "base" & grupo == "`g'", noobs sep(0) abbreviate(12)
}

* --- 9.3 RIMPE ---
use "`rim_file'", clear
* Diferencias del exceso a la izquierda: RIMPE menos cada placebo (agrupados)
foreach pl in plac_post plac_pre {
    quietly summarize b_izq if serie == "rimpe" & anio == 0, meanonly
    local b1 = r(mean)
    quietly summarize se_b_izq if serie == "rimpe" & anio == 0, meanonly
    local s1 = r(mean)
    quietly summarize b_izq if serie == "`pl'" & anio == 0, meanonly
    local b2 = r(mean)
    quietly summarize se_b_izq if serie == "`pl'" & anio == 0, meanonly
    local s2 = r(mean)
    if "`b1'" != "" & "`b2'" != "" {
        local d  = `b1' - `b2'
        local sd = sqrt(`s1'^2 + `s2'^2)
        set obs `=_N + 1'
        replace serie    = "rim-`pl'" in L
        replace anio     = 0 in L
        replace b_izq    = `d' in L
        replace se_b_izq = `sd' in L
        replace pval_izq = 1 - normal(`d' / `sd') in L
    }
}
label var serie    "rimpe / plac_post / plac_pre / rim-placebo (diferencia)"
label var anio     "Año (0 = agrupado)"
label var nwin     "Declarantes en la ventana"
label var B        "Exceso neto en la ventana (declarantes)"
label var c0       "Contrafactual suave promedio por bin"
label var b        "Exceso neto normalizado B/c0"
label var b_izq    "Exceso a la izquierda de 20.000, normalizado"
label var pval_izq "p-valor una cola (exceso izquierda > 0)"
label var b_der    "Masa faltante a la derecha de 20.000, normalizada"
label var pval_der "p-valor una cola (masa faltante > 0)"
save "$dir_out/bunching_rimpe20000.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("rimpe_20000", replace) firstrow(variables)

di as result _n "===== RIMPE: línea de 20.000 ====="
format b_izq se_b_izq pval_izq b_der se_b_der pval_der %7.3f
list serie anio nwin b_izq se_b_izq pval_izq b_der se_b_der pval_der, noobs sep(0) abbreviate(10)

* --- 9.4 Resumen de agrupados (todos los años) ---
use "$dir_out/bunching_resultados.dta", clear
di as result _n "===== Bunching agrupado (todos los años): base imponible ====="
format b se_b pval_pos elast %8.3f
foreach g of local groups {
    di as text _n "--- Grupo: `g' ---"
    list kink nwin b se_b pval_pos elast ///
        if anio == 0 & periodo == "todo" & variable == "base" & grupo == "`g'", ///
        noobs sep(0)
}

di as result _n "===== Placebo agrupado (todos los años): ingreso bruto ====="
foreach g of local groups {
    di as text _n "--- Grupo: `g' ---"
    list kink nwin b se_b pval_pos ///
        if anio == 0 & periodo == "todo" & variable == "placebo" & grupo == "`g'", ///
        noobs sep(0)
}

di as result _n "Resultados: $dir_out"
di as result    "Gráficos  : $dir_graf"

log close

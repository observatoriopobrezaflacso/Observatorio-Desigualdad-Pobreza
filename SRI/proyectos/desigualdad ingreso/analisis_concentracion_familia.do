********************************************************************************
*  analisis_concentracion_familia.do
*  ---------------------------------------------------------------------------
*  Concentration of income / wealth BY FAMILY, using the identifiers built by
*  build_familias.do.  This is the family-level counterpart of the
*  individual-level analysis at the end of
*      construccion_ingreso_DINA.do
*  where the distribution is taken over CEDULA_PK.  Here the unit of
*  distribution is the family, and the same DINA convention is applied:
*  the family's income is the SUM of its members' incomes, and the family is
*  then counted ONCE (its total) or its income is EQUAL-SPLIT across members,
*  which are the two conventions that give different answers and are both
*  reported below.
*
*  ---------------------------------------------------------------------------
*  HOW TO PLUG THE REAL SRI DATA IN
*  ---------------------------------------------------------------------------
*  Set FUENTE to "sri" and point $dir_merged at the ingreso_dina_YYYY.dta files
*  written by construccion_ingreso_DINA.do.  The only thing needed is a
*  crosswalk from CEDULA_PK (the SRI anonymised key) to cod_inec_ci_actual (the
*  INEC key); name it in $xwalk with those two variables.  Everything else runs
*  unchanged.
*
*  With FUENTE = "sim" (the default here, because the synthetic cedulados file
*  carries no income) a wealth variable is simulated with a Pareto upper tail
*  AND a deliberate WITHIN-FAMILY CORRELATION, which is the whole point: if
*  wealth were independent across kin, family-level concentration would be
*  mechanically LOWER than individual-level concentration, and the exercise
*  would say nothing.  The parameter RHO_FAM below controls how much of the
*  variance is a family effect.
*
*  ---------------------------------------------------------------------------
*  OUTPUT
*  ---------------------------------------------------------------------------
*    $out/concentracion_por_unidad.dta   top shares and Gini for every unit of
*                                        analysis (individual, nuclear family,
*                                        extended family, dynasty) and both
*                                        weighting conventions
*    $out/top_familias.dta               the richest families, with the size
*                                        and composition of each
*    $out/kin_share_top.dta              how much of the wealth of the top
*                                        1 / 0.1% sits inside their own
*                                        second-degree kin network
********************************************************************************

clear all
set more off
set type double

global fake "G:/Mi unidad/Trabajos/Predoc/data/fake_data"
global ced  "$fake/Bases/Bases INEC/Cedulados/dta"
global out  "$fake/Investigadores/Santiago/Outputs/familias"
cap mkdir "$fake/Investigadores"
cap mkdir "$fake/Investigadores/Santiago"
cap mkdir "$fake/Investigadores/Santiago/Outputs"
cap mkdir "$out"

*------------------------------- parameters -----------------------------------
* "sim" = simulate the wealth variable; "sri" = merge the DINA income files
global FUENTE   "sim"
* share of the log-wealth variance that is a family effect (FUENTE = sim only)
global RHO_FAM  0.45
* only adults are counted as potential holders
global EDAD_MIN 18
* reference year
global ANIO_REF 2023
* for FUENTE = "sri"
global dir_merged ""
global xwalk      ""

set seed 20260903


********************************************************************************
* HELPER: top shares and Gini of a variable over the rows in memory
********************************************************************************
* Deliberately written with no external ado dependency, so the same code runs
* inside the SRI enclave.  Rows must already be one per unit of analysis.
* w = the number of people the row represents (1 for a unit-weighted
* distribution, the family size for an equal-split distribution).

* Like the reference script, the distribution is taken over POSITIVE values
* only (construccion_ingreso_DINA.do does `xtile decil = PreTaxHHI if
* PreTaxHHI > 0`).  Including the zeros would raise every top share and lower
* the bottom-50 share; the comparison across units of analysis is unaffected,
* because the same rule is applied to all of them.

capture program drop _conc
program define _conc, rclass
    syntax varname [if] [in], PESO(varname) UNIDAD(string) PONDERA(string)

    marksample touse
    qui replace `touse' = 0 if mi(`varlist') | `varlist' <= 0 | mi(`peso') | `peso' <= 0

    preserve
        qui keep if `touse'
        qui count
        local N = r(N)
        if `N' < 20 {
            di as err "  `unidad' / `pondera': fewer than 20 usable rows, skipped"
            exit 2000
        }

        * for an equal-split distribution one row stands for `peso' identical
        * people, so the ranking has to be on income PER PERSON
        gen double y = `varlist'/`peso'
        sort y
        gen double cw = sum(`peso')
        qui sum `peso', meanonly
        local W = r(sum)
        qui sum `varlist', meanonly
        local Y = r(sum)

        * Gini, Brown/trapezoid form on the weighted distribution of y
        gen double lag_cw = cw[_n-1]
        qui replace lag_cw = 0 in 1
        gen double area = `peso' * (cw + lag_cw) * y
        qui sum area, meanonly
        local gini = r(sum)/(`W' * `Y') - 1

        * top shares: share of total Y held by the top p% of the population
        foreach p in 10 5 1 0.1 {
            local tag = subinstr("`p'", ".", "_", .)
            qui sum `varlist' if cw > (1 - `p'/100)*`W', meanonly
            local top_`tag' = r(sum)/`Y'
        }
        qui sum `varlist' if cw <= 0.5*`W', meanonly
        local bot50 = r(sum)/`Y'
    restore

    * locals survive the restore; r() is only posted when the program exits,
    * so the display below has to use the locals, not r()
    di as txt "  " %-22s "`unidad'" %-14s "`pondera'" as res %10.0fc `N' ///
       as txt "   Gini " as res %6.4f `gini' as txt "   top1 " as res %6.4f `top_1'

    return scalar n     = `N'
    return scalar w     = `W'
    return scalar total = `Y'
    return scalar gini  = `gini'
    return scalar top10 = `top_10'
    return scalar top5  = `top_5'
    return scalar top1  = `top_1'
    return scalar top01 = `top_0_1'
    return scalar bot50 = `bot50'
end

* one row of results, built from r() straight after a _conc call
capture program drop _fila
program define _fila
    args unidad pondera archivo
    preserve
        foreach s in n w total gini top10 top5 top1 top01 bot50 {
            local v_`s' = r(`s')
        }
        clear
        qui set obs 1
        gen str24 unidad  = "`unidad'"
        gen str14 pondera = "`pondera'"
        foreach s in n w total gini top10 top5 top1 top01 bot50 {
            gen double `s' = `v_`s''
        }
        qui append using "`archivo'"
        qui save "`archivo'", replace
    restore
end


********************************************************************************
* 1. THE PERSON FILE, WITH THE FAMILY IDENTIFIERS AND A WEALTH VARIABLE
********************************************************************************

use "$ced/cedulados_familias.dta", clear
keep cod_inec_ci_actual id_fam_nuclear id_fam_nuclear2 rol_nuclear ///
     id_fam_extendida id_fam_extendida2 id_dinastia nf_tam nf_n_hijos nf_biparental  ///
     fe_tam fe_n_fam din_tam female yob yod age2023 vivo_ref       ///
     n_g2_total n_g2_cons n_g2_afin k_herm k_hijos

qui count
di as res _n "persons: " %12.0fc r(N)

if "$FUENTE" == "sri" {
    *-------------------------------------------------------------------------
    * real data: PreTaxHHI per declarant, mapped onto the INEC key
    *-------------------------------------------------------------------------
    if "$dir_merged" == "" | "$xwalk" == "" {
        di as err "FUENTE = sri requires \$dir_merged and \$xwalk to be set"
        exit 198
    }
    preserve
        use "$dir_merged/ingreso_dina_$ANIO_REF.dta", clear
        keep CEDULA_PK PreTaxHHI PostTaxHHI capital
        qui merge m:1 CEDULA_PK using "$xwalk", keep(match) nogen
        collapse (sum) PreTaxHHI PostTaxHHI capital, by(cod_inec_ci_actual)
        tempfile ing
        qui save `ing'
    restore
    qui merge 1:1 cod_inec_ci_actual using `ing', keep(master match) nogen
    gen double riqueza = PreTaxHHI
    qui replace riqueza = 0 if mi(riqueza)
    label var riqueza "PreTaxHHI, $ANIO_REF (0 = no declara)"
}
else {
    *-------------------------------------------------------------------------
    * simulated: log-normal body, Pareto tail, WITH a family effect
    *-------------------------------------------------------------------------
    * The family effect is attached to the EXTENDED family, so that it shows
    * up at every level of aggregation (nuclear families sit inside extended
    * ones), which is what a real inheritance process would do.
    bysort id_fam_extendida: gen byte _ff = _n == 1
    gen double _fe = rnormal(0, sqrt($RHO_FAM)) if _ff
    bysort id_fam_extendida (_ff): replace _fe = _fe[_N]
    drop _ff

    gen double riqueza = .
    qui replace riqueza = exp(9.2 + _fe + rnormal(0, sqrt(1 - $RHO_FAM))*1.35 ///
                              + 0.012*(age2023 - 40) - 0.15*female) ///
        if age2023 >= $EDAD_MIN & vivo_ref
    * a Pareto upper tail: 0.6% of adults draw from a Pareto(alpha = 1.6)
    qui replace riqueza = riqueza * (runiform())^(-1/1.6) ///
        if !mi(riqueza) & runiform() < 0.006
    * only 55% of adults hold anything measurable at all (as in tax records)
    qui replace riqueza = 0 if !mi(riqueza) & runiform() < 0.45
    qui replace riqueza = 0 if mi(riqueza)
    drop _fe
    label var riqueza "riqueza simulada (family effect = $RHO_FAM)"
}

qui sum riqueza if riqueza > 0
di as txt "holders with positive wealth: " as res %12.0fc r(N) ///
   as txt "   mean " as res %14.0fc r(mean) as txt "   max " as res %16.0fc r(max)

qui save "$fake/Bases/bases_temp/_rq.dta", replace


********************************************************************************
* 2. CONCENTRATION BY UNIT OF ANALYSIS
********************************************************************************
* Two conventions, both reported, because they answer different questions.
*
*   "unidad"      one row per family, weight 1.  The distribution is over
*                 families: "the richest 1% of families hold x% of wealth".
*                 This is the natural family-level statement, and it is the
*                 one that is NOT comparable with the individual-level number,
*                 because a rich family is usually a big family.
*
*   "equal-split" one row per family, weight = number of members, income
*                 divided equally among them.  The distribution is over
*                 PEOPLE, and it IS directly comparable with the
*                 individual-level number, because the population is the same
*                 in both.  This is the DINA convention.

global res "$fake/Bases/bases_temp/_res.dta"
clear
set obs 1
gen str24 unidad = ""
gen str14 pondera = ""
gen double n = .
gen double w = .
gen double total = .
gen double gini = .
gen double top10 = .
gen double top5 = .
gen double top1 = .
gen double top01 = .
gen double bot50 = .
drop in 1
qui save "$res", replace

di as txt _n "{hline 78}"
di as txt "CONCENTRATION BY UNIT OF ANALYSIS"
di as txt "{hline 78}"
di as txt "  unit                  weighting        rows"

*--- 2.1 individuals (the benchmark: exactly what the DINA script does) --------
use "$fake/Bases/bases_temp/_rq.dta", clear
gen double peso = 1
_conc riqueza if age2023 >= $EDAD_MIN & vivo_ref, peso(peso) ///
    unidad("individuo") pondera("por persona")
_fila "individuo" "por persona" "$res"

*--- 2.2 the family units ----------------------------------------------------
foreach u in id_fam_nuclear id_fam_nuclear2 id_fam_extendida id_fam_extendida2 id_dinastia {

    if "`u'" == "id_fam_nuclear"    local etq "familia nuclear"
    if "`u'" == "id_fam_nuclear2"   local etq "fam. nuclear (r2)"
    if "`u'" == "id_fam_extendida"  local etq "familia extendida"
    if "`u'" == "id_fam_extendida2" local etq "fam. ext. (2 gen)"
    if "`u'" == "id_dinastia"       local etq "dinastia"

    use "$fake/Bases/bases_temp/_rq.dta", clear
    * A family's wealth is the sum over its members.  For the equal-split
    * convention the denominator is the number of LIVING ADULTS, so that the
    * population behind the family rows is the same population as behind the
    * individual row above and the two are directly comparable.  A family with
    * no living adult gets a floor of 1 (its wealth is zero anyway).
    gen byte adulto_vivo = age2023 >= $EDAD_MIN & vivo_ref
    collapse (sum) riqueza (sum) n_adultos = adulto_vivo (sum) n_vivos = vivo_ref ///
             (count) n_pers = riqueza, by(`u')
    qui replace n_adultos = 1 if n_adultos == 0
    gen double peso1 = 1

    foreach pw in peso1 n_adultos {
        if "`pw'" == "peso1" local pe "por familia"
        else                 local pe "equal-split"
        capture _conc riqueza, peso(`pw') unidad("`etq'") pondera("`pe'")
        if _rc == 0 _fila "`etq'" "`pe'" "$res"
    }
}

use "$res", clear
gen byte ord = .
qui replace ord = 1 if unidad == "individuo"
qui replace ord = 2 if unidad == "familia nuclear"
qui replace ord = 3 if unidad == "fam. nuclear (r2)"
qui replace ord = 4 if unidad == "familia extendida"
qui replace ord = 5 if unidad == "fam. ext. (2 gen)"
qui replace ord = 6 if unidad == "dinastia"
sort ord pondera
drop ord
label var gini  "Gini"
label var top10 "share of the top 10%"
label var top1  "share of the top 1%"
label var top01 "share of the top 0.1%"
label var bot50 "share of the bottom 50%"
format gini top10 top5 top1 top01 bot50 %7.4f
compress
save "$out/concentracion_por_unidad.dta", replace

di as txt _n "{hline 78}"
di as txt "TOP SHARES AND GINI"
di as txt "{hline 78}"
di as txt "unidad             ponderacion       n     Gini   top10    top1   top0.1  bot50"
di as txt "{hline 78}"
forvalues i = 1/`=_N' {
    di as txt %-18s unidad[`i'] " " %-12s pondera[`i'] ///
       as res %8.0fc n[`i'] " " %7.4f gini[`i'] " " %7.4f top10[`i'] ///
       " " %7.4f top1[`i'] " " %7.4f top01[`i'] " " %7.4f bot50[`i']
}
di as txt "{hline 78}"

di as txt _n "Read it like this: comparing 'individuo / por persona' with"
di as txt "'familia * / equal-split' isolates how much of measured individual"
di as txt "inequality is inequality BETWEEN families rather than within them."
di as txt "The 'por familia' rows are a different population (families, not"
di as txt "people) and are not comparable with the individual row."


********************************************************************************
* 3. THE RICHEST FAMILIES
********************************************************************************

use "$fake/Bases/bases_temp/_rq.dta", clear
collapse (sum) riqueza_fam = riqueza (count) n_pers = riqueza    ///
         (sum) n_vivos = vivo_ref (sum) n_hijos = k_hijos        ///
         (first) id_fam_extendida id_dinastia                    ///
         (min) yob_min = yob (max) yob_max = yob, by(id_fam_nuclear)
gen double riqueza_pc = riqueza_fam/max(n_vivos, 1)
gsort -riqueza_fam
gen long rank_fam = _n
qui sum riqueza_fam, meanonly
gen double share_acum = sum(riqueza_fam)/r(sum)
label var riqueza_fam "riqueza total de la familia nuclear"
label var riqueza_pc  "riqueza por miembro vivo"
label var share_acum  "share acumulado de la riqueza total"
keep in 1/2000
compress
save "$out/top_familias.dta", replace

di as txt _n "{hline 78}"
di as txt "THE 15 RICHEST NUCLEAR FAMILIES"
di as txt "{hline 78}"
format riqueza_fam riqueza_pc %14.0fc
format share_acum %7.4f
list rank_fam n_pers n_vivos riqueza_fam riqueza_pc share_acum in 1/15, noobs

*--- how big are rich families? ----------------------------------------------
use "$fake/Bases/bases_temp/_rq.dta", clear
collapse (sum) riqueza_fam = riqueza (count) n_pers = riqueza (sum) n_vivos = vivo_ref, ///
    by(id_fam_nuclear)
qui replace n_vivos = 1 if n_vivos == 0
xtile decil_fam = riqueza_fam if riqueza_fam > 0, nq(10)
di as txt _n "family size by decile of family wealth"
di as txt "(if rich families are systematically bigger, the 'por familia' and"
di as txt " 'equal-split' rankings will disagree, which is exactly why both are"
di as txt " reported above)"
tabstat n_pers n_vivos riqueza_fam, by(decil_fam) stat(n mean) format(%12.2f)


********************************************************************************
* 4. HOW MUCH OF THE WEALTH OF THE RICH SITS INSIDE THEIR OWN KIN NETWORK?
********************************************************************************
* This is the question the partition cannot answer and the second-degree edge
* list can: take each person in the top 1%, and add up the wealth of their
* parents, children, grandparents, grandchildren, siblings, spouse and
* in-laws.  Overlap between ego networks is fine here, because the statistic
* is an average over egos, not a decomposition of the total.

capture confirm file "$ced/red_parentesco_g2.dta"
if _rc == 0 {

    use "$fake/Bases/bases_temp/_rq.dta", clear
    keep cod_inec_ci_actual riqueza vivo_ref age2023
    qui keep if age2023 >= $EDAD_MIN & vivo_ref

    * percentile of the individual distribution
    qui sum riqueza if riqueza > 0
    xtile pctl = riqueza if riqueza > 0, nq(1000)
    gen byte top1  = pctl > 990 & !mi(pctl)
    gen byte top01 = pctl > 999 & !mi(pctl)
    gen byte top10 = pctl > 900 & !mi(pctl)

    rename cod_inec_ci_actual ci
    qui save "$fake/Bases/bases_temp/_ego.dta", replace

    * the wealth of each alter
    keep ci riqueza
    rename ci      alter
    rename riqueza riqueza_alter
    qui save "$fake/Bases/bases_temp/_alt.dta", replace

    use "$ced/red_parentesco_g2.dta", clear
    qui keep if primaria
    qui merge m:1 alter using "$fake/Bases/bases_temp/_alt.dta", keep(match) nogen
    gen double rq_cons = riqueza_alter * (via == 1)
    gen double rq_afin = riqueza_alter * (via == 2)
    gen double rq_g1   = riqueza_alter * (grado == 1)
    collapse (sum) rq_kin = riqueza_alter rq_cons rq_afin rq_g1 ///
             (count) n_kin = riqueza_alter, by(ci)
    qui save "$fake/Bases/bases_temp/_kin.dta", replace

    use "$fake/Bases/bases_temp/_ego.dta", clear
    qui merge 1:1 ci using "$fake/Bases/bases_temp/_kin.dta", keep(master match) nogen
    foreach v in rq_kin rq_cons rq_afin rq_g1 n_kin {
        qui replace `v' = 0 if mi(`v')
    }
    gen double rq_ego_kin = riqueza + rq_kin
    gen double ratio_kin  = rq_kin/riqueza if riqueza > 0

    label var rq_kin      "riqueza de los parientes hasta 2do grado"
    label var rq_ego_kin  "riqueza del ego mas sus parientes hasta 2do grado"
    label var ratio_kin   "riqueza de los parientes / riqueza del ego"
    label var n_kin       "parientes hasta 2do grado con riqueza observada"

    di as txt _n "{hline 78}"
    di as txt "KIN WEALTH OF THE RICH  (second-degree network, per ego)"
    di as txt "{hline 78}"
    di as txt _n "mean over egos, by position in the individual distribution"
    gen byte grupo = 1
    qui replace grupo = 2 if top10
    qui replace grupo = 3 if top1
    qui replace grupo = 4 if top01
    label define grupo 1 "bottom 90" 2 "top 10-1" 3 "top 1-0.1" 4 "top 0.1", replace
    label values grupo grupo
    tabstat riqueza rq_kin rq_ego_kin n_kin ratio_kin, by(grupo) ///
        stat(n mean p50) format(%14.2f) longstub

    di as txt _n "share of total wealth reachable within two degrees of the top 1%"
    qui sum riqueza
    local TOT = r(sum)
    preserve
        qui keep if top1
        * a relative can be reachable from several egos: count each person once
        keep ci
        qui save "$fake/Bases/bases_temp/_t1.dta", replace
        use "$ced/red_parentesco_g2.dta", clear
        qui keep if primaria
        qui merge m:1 ci using "$fake/Bases/bases_temp/_t1.dta", keep(match) nogen
        keep alter
        qui duplicates drop
        rename alter ci
        qui append using "$fake/Bases/bases_temp/_t1.dta"
        qui duplicates drop
        qui merge 1:1 ci using "$fake/Bases/bases_temp/_ego.dta", keep(match) nogen
        qui sum riqueza
        di as res "  " %6.2f 100*r(sum)/`TOT' "% of total wealth, held by " ///
           %10.0fc r(N) " people (top 1% and their second-degree kin)"
    restore

    keep ci riqueza rq_kin rq_cons rq_afin rq_g1 n_kin rq_ego_kin ratio_kin grupo
    rename ci cod_inec_ci_actual
    compress
    save "$out/kin_share_top.dta", replace
}
else {
    di as err _n "red_parentesco_g2.dta not found - section 4 skipped."
    di as err "Run build_familias.do with HACER_RED = 1."
}

di as res _n "outputs written to $out"

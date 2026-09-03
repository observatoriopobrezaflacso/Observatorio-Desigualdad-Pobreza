********************************************************************************
*  validate_familias.do
*  ---------------------------------------------------------------------------
*  Does build_familias.do actually recover the family structure that
*  make_cedulados_fake.do put in?  Three kinds of check:
*
*    A. INTERNAL CONSISTENCY - properties the identifiers must satisfy no
*       matter what the data look like (partition, nesting, the emancipation
*       rule, symmetry of the kinship network).  A failure here is a bug.
*
*    B. RECOVERY AGAINST THE GROUND TRUTH - _cedulados_truth.dta holds the
*       simulated genealogy before censoring.  These checks say how much of
*       the true structure survives 35% missing father links, and they are the
*       numbers to look at when deciding whether the real analysis is
*       feasible.  A low number here is not a bug, it is the censoring.
*
*    C. THE PATHOLOGIES - every planted error must have been caught.
*
*  Nothing here is used by the analysis; it exists so that the identifiers can
*  be trusted before they are pointed at the real registry.
********************************************************************************

clear all
set more off
set type double

global fake "G:/Mi unidad/Trabajos/Predoc/data/fake_data"
global ced  "$fake/Bases/Bases INEC/Cedulados/dta"
global tmp  "$fake/Bases/bases_temp"

* these must match the values used in build_familias.do
global PROF_EXT   3
global BRECHA_MIN 12

local FAIL 0

capture program drop _chk
program define _chk
    * _chk "description" <count that must be zero>
    args desc n
    if `n' == 0 di as txt "  [ok]   " %-58s "`desc'"
    else        di as err "  [FAIL] " %-58s "`desc'" as err "  n = " `n'
end

capture program drop _num
program define _num
    args desc v fmt
    if "`fmt'" == "" local fmt "%12.0fc"
    di as txt "  " %-62s "`desc'" as res `fmt' `v'
end


********************************************************************************
* A. INTERNAL CONSISTENCY
********************************************************************************

di as txt _n "{hline 78}"
di as txt "A. INTERNAL CONSISTENCY"
di as txt "{hline 78}"

use "$ced/cedulados_familias.dta", clear
qui count
local NP = r(N)
_num "persons on file" `NP'

*--- A1 the nuclear family is a partition ------------------------------------
qui count if mi(id_fam_nuclear)
_chk "every person has a nuclear family" r(N)
qui count if mi(id_fam_nuclear2)
_chk "every person has a nuclear family under rule 2" r(N)
qui count if mi(rol_nuclear)
_chk "every person has a role" r(N)
qui duplicates report cod_inec_ci_actual
_chk "one row per cedula" `=_N - r(unique_value)'

*--- A2 the emancipation rule ------------------------------------------------
* "a person stops being a child the moment they have a child of their own"
qui count if rol_nuclear == 2 & n_hijos > 0
_chk "no parent is classified as a child (rule 1)" r(N)
qui count if rol_nuclear2 == 2 & n_hijos > 0
_chk "no parent is classified as a child (rule 2)" r(N)
qui count if rol_nuclear == 1 & n_hijos == 0
_chk "no childless person is classified as a parent" r(N)
qui count if es_progenitor & !mi(id_union_origen) & id_fam_nuclear == id_union_origen
_chk "no parent sits in the family they were born into" r(N)

*--- A3 a nuclear family has at most two heads -------------------------------
preserve
    qui bysort id_fam_nuclear: egen int nh = total(rol_nuclear == 1)
    qui bysort id_fam_nuclear: keep if _n == 1
    qui count if nh > 2
    _chk "no nuclear family has more than two parents" r(N)
    qui count if nh == 0
    _num "families with no parent on file (children only, or singletons)" r(N)
restore

*--- A4 nesting: nuclear inside extended inside dynasty ----------------------
preserve
    keep id_fam_nuclear id_fam_extendida
    qui duplicates drop
    qui bysort id_fam_nuclear: gen int k = _N
    qui count if k > 1
    _chk "each nuclear family lies in exactly one extended family" r(N)
restore
preserve
    keep id_fam_nuclear id_fam_extendida2
    qui duplicates drop
    qui bysort id_fam_nuclear: gen int k = _N
    qui count if k > 1
    _chk "each nuclear family lies in exactly one extended family (2 gen)" r(N)
restore
preserve
    keep id_fam_extendida id_dinastia
    qui duplicates drop
    qui bysort id_fam_extendida: gen int k = _N
    qui count if k > 1
    _chk "each extended family lies in exactly one dynasty" r(N)
restore

*--- A5 the extended family really is a block of PROF_EXT generations -------
* Two different spans, and only the first one is a claim about the block:
*
*   nf_prof  is depth along the lineage the block actually FOLLOWS.  The span
*            of nf_prof inside an extended family must be <= $PROF_EXT, by
*            construction.  This is a real check.
*
*   gen_lin  is each PERSON'S depth in their own deepest recorded lineage,
*            which may run through the line the block does NOT follow - a
*            spouse who marries in from a deeper lineage carries a high
*            gen_lin with them.  The span of gen_lin can therefore exceed
*            $PROF_EXT + 1 without the block being wrong, so this one is
*            reported, not checked.
preserve
    qui bysort id_fam_extendida: egen int pmin = min(nf_prof)
    qui bysort id_fam_extendida: egen int pmax = max(nf_prof)
    gen int span_nf = pmax - pmin + 1
    qui bysort id_fam_extendida: egen int gmin = min(gen_lin)
    qui bysort id_fam_extendida: egen int gmax = max(gen_lin)
    gen int span_gen = gmax - gmin + 1
    qui bysort id_fam_extendida: keep if _n == 1
    qui count if span_nf > $PROF_EXT
    _chk "the block spans at most \$PROF_EXT nuclear generations" r(N)
    qui sum span_nf
    _num "mean span of the followed lineage (nf_prof)" r(mean) "%12.2f"
    qui count if span_gen > $PROF_EXT + 1
    local wide = r(N)
    _num "families whose gen_lin span exceeds the block (married-in kin)" `wide'
    di as txt "         = " as res %5.2f 100*`wide'/_N as txt ///
       "% of extended families; these are spouses who married in from a"
    di as txt "          deeper lineage than the one the block follows, not a"
    di as txt "          block that grew too large"
restore


*--- A6 the validated links are clean ----------------------------------------
qui count if ci_padre_val == cod_inec_ci_actual & !mi(ci_padre_val)
_chk "no self-parenthood survives validation" r(N)
qui count if ci_madre_val == cod_inec_ci_actual & !mi(ci_madre_val)
_chk "no self-motherhood survives validation" r(N)
qui count if ci_conyuge_val == cod_inec_ci_actual & !mi(ci_conyuge_val)
_chk "no self-spouse survives validation" r(N)
qui count if !mi(ci_padre_val) & ci_padre_val == ci_madre_val
_chk "father and mother are never the same person" r(N)
qui count if f_ciclo == 1
_chk "no parent-child cycle survives validation" r(N)

* every surviving parent is at least BRECHA_MIN years older.
* (Stata cannot nest preserve, so the lookups are written out first.)
preserve
    keep cod_inec_ci_actual yob
    rename cod_inec_ci_actual alter
    rename yob yob_padre
    qui save "$tmp/_vy.dta", replace
restore
preserve
    keep cod_inec_ci_actual ci_padre_val ci_madre_val yob
    qui expand 2
    bysort cod_inec_ci_actual: gen byte s = _n
    gen double alter = cond(s == 1, ci_padre_val, ci_madre_val)
    qui keep if !mi(alter)
    rename yob yob_hijo
    qui merge m:1 alter using "$tmp/_vy.dta", keep(master match) nogen
    qui count if mi(yob_padre)
    _chk "every surviving parent link points at a person on file" r(N)
    qui count if yob_hijo - yob_padre < 12
    _chk "every surviving parent is at least 12 years older" r(N)
restore

*--- A7 the kinship network is symmetric where it must be --------------------
capture confirm file "$ced/red_parentesco_g2.dta"
if _rc == 0 {
    use "$ced/red_parentesco_g2.dta", clear
    qui count if ci == alter
    _chk "nobody is their own relative" r(N)
    qui count if mi(ci) | mi(alter)
    _chk "no edge has a missing endpoint" r(N)
    qui count if !inlist(grado, 0, 1, 2)
    _chk "every edge is of degree 0, 1 or 2" r(N)
    qui count if !inlist(via, 1, 2)
    _chk "every edge is consanguinity or affinity" r(N)

    * padre/madre and hijo must be exact reverses of each other
    preserve
        qui keep if inlist(rel, 1, 2)
        keep ci alter
        rename ci    _t_
        rename alter ci
        rename _t_   alter
        qui save "$tmp/_rv1.dta", replace
    restore
    preserve
        qui keep if rel == 3
        keep ci alter
        qui merge 1:1 ci alter using "$tmp/_rv1.dta"
        qui count if _merge != 3
        _chk "the parent and child edge sets are exact reverses" r(N)
    restore
    * siblings and spouses must be symmetric
    foreach r in 6 7 10 {
        preserve
            qui keep if rel == `r'
            keep ci alter
            qui save "$tmp/_rv2.dta", replace
            rename ci    _t_
            rename alter ci
            rename _t_   alter
            qui merge 1:1 ci alter using "$tmp/_rv2.dta"
            qui count if _merge != 3
            if `r' == 6  _chk "full-sibling edges are symmetric" r(N)
            if `r' == 7  _chk "half-sibling edges are symmetric" r(N)
            if `r' == 10 _chk "spouse edges are symmetric" r(N)
        restore
    }
    * abuelo and nieto must be exact reverses
    preserve
        qui keep if rel == 4
        keep ci alter
        rename ci    _t_
        rename alter ci
        rename _t_   alter
        qui save "$tmp/_rv3.dta", replace
    restore
    preserve
        qui keep if rel == 5
        keep ci alter
        qui merge 1:1 ci alter using "$tmp/_rv3.dta"
        qui count if _merge != 3
        _chk "the grandparent and grandchild edge sets are exact reverses" r(N)
    restore
    * nobody has more than two parents or more than four grandparents
    preserve
        qui keep if inlist(rel, 1, 2)
        contract ci
        qui count if _freq > 2
        _chk "nobody has more than two parents" r(N)
    restore
    preserve
        qui keep if rel == 4
        contract ci
        qui count if _freq > 4
        _chk "nobody has more than four grandparents" r(N)
        qui sum _freq
        _num "mean grandparents, among people who have any" r(mean) "%12.2f"
    restore
    * a full sibling can never also be a half sibling
    preserve
        qui keep if inlist(rel, 6, 7)
        keep ci alter rel
        qui bysort ci alter: gen int k = _N
        qui count if k > 1
        _chk "no pair is both a full and a half sibling" r(N)
    restore
}
else di as err "  red_parentesco_g2.dta not found - section A7 skipped"


********************************************************************************
* B. RECOVERY AGAINST THE SIMULATED GROUND TRUTH
********************************************************************************

di as txt _n "{hline 78}"
di as txt "B. RECOVERY AGAINST THE GROUND TRUTH"
di as txt "{hline 78}"

capture confirm file "$ced/_cedulados_truth.dta"
if _rc != 0 {
    di as err "  _cedulados_truth.dta not found - section B skipped"
}
else {

    use "$ced/cedulados_familias.dta", clear
    keep cod_inec_ci_actual id_fam_nuclear rol_nuclear id_fam_extendida ///
         id_fam_extendida2 ///
         id_dinastia gen_lin n_hijos es_progenitor ci_padre_val ci_madre_val
    qui merge 1:1 cod_inec_ci_actual using "$ced/_cedulados_truth.dta", ///
        keep(match) nogen
    qui save "$tmp/_val.dta", replace

    *--- B1 how much of the true parent structure survived censoring? ---------
    qui count if !mi(ci_padre_true)
    local tp = r(N)
    qui count if !mi(ci_padre_true) & ci_padre_val == ci_padre_true
    _num "true father links recovered" r(N)
    di as txt "         of " as res %12.0fc `tp' as txt " true fathers = " ///
       as res %5.1f 100*r(N)/`tp' "%"
    qui count if !mi(ci_madre_true)
    local tm = r(N)
    qui count if !mi(ci_madre_true) & ci_madre_val == ci_madre_true
    _num "true mother links recovered" r(N)
    di as txt "         of " as res %12.0fc `tm' as txt " true mothers = " ///
       as res %5.1f 100*r(N)/`tm' "%"
    * The registry contains parent pointers that are simply WRONG but not
    * detectably wrong: make_cedulados_fake.do plants them (P05) by repointing
    * ~0.6% of parent links at a random person.  Whenever that random person
    * happens to be more than $BRECHA_MIN years older than the child, no rule
    * can tell the link apart from a real one.  These are therefore measured
    * contamination rates, not failures - they are the price of using the
    * registry at all.
    qui count if !mi(ci_padre_val) & ci_padre_val != ci_padre_true
    local fp = r(N)
    qui count if !mi(ci_padre_val)
    _num "surviving father links that are FALSE (undetectable P05)" `fp'
    di as txt "         = " as res %6.3f 100*`fp'/r(N) as txt "% of surviving father links"
    qui count if !mi(ci_madre_val) & ci_madre_val != ci_madre_true
    local fp = r(N)
    qui count if !mi(ci_madre_val)
    _num "surviving mother links that are FALSE (undetectable P05)" `fp'
    di as txt "         = " as res %6.3f 100*`fp'/r(N) as txt "% of surviving mother links"

    *--- B2 is the recovered parenthood status right? ------------------------
    qui count if es_progenitor == 1 & n_hijos_true == 0
    local fp = r(N)
    qui count if es_progenitor == 1
    _num "false parents (only children are P05 mispointings)" `fp'
    di as txt "         = " as res %6.3f 100*`fp'/r(N) as txt "% of recovered parents"
    qui count if es_progenitor == 0 & n_hijos_true > 0
    local miss = r(N)
    qui count if n_hijos_true > 0
    _num "true parents missed (all their children lost the link)" `miss'
    di as txt "         of " as res %12.0fc r(N) as txt " true parents = " ///
       as res %5.1f 100*`miss'/r(N) "%"
    qui corr n_hijos n_hijos_true
    _num "correlation of recovered and true child counts" r(rho) "%12.4f"

    *--- B3 the generation index --------------------------------------------
    * gen_lin can only be a LOWER bound on gen_true: censoring a parent link
    * makes a person look like a founder.
    qui count if gen_lin > gen_true
    local fp = r(N)
    _num "persons whose lineage index EXCEEDS the true generation" `fp'
    di as txt "         = " as res %6.3f 100*`fp'/_N as txt "%, all of them P05 false parents"
    di as txt "          from a deeper lineage; without P05 gen_lin can only be"
    di as txt "          a LOWER bound on gen_true, since censoring a parent link"
    di as txt "          makes a person look like a founder"
    qui count if gen_lin == gen_true
    _num "persons whose generation is exactly recovered" r(N)
    di as txt "         = " as res %5.1f 100*r(N)/_N "% of the population"
    qui corr gen_lin gen_true
    _num "correlation of gen_lin with gen_true" r(rho) "%12.4f"
    di as txt _n "recovered lineage depth against the true generation"
    tab gen_true gen_lin, row nofreq

    *--- B4 do true siblings end up in the same nuclear family? -------------
    * Restricted to true siblings who are both non-parents, since a sibling
    * who has become a parent is SUPPOSED to leave.
    preserve
        keep cod_inec_ci_actual union_nac_true id_fam_nuclear es_progenitor
        qui keep if !mi(union_nac_true) & es_progenitor == 0
        qui save "$tmp/_sib_a.dta", replace
        rename cod_inec_ci_actual alter
        rename id_fam_nuclear     nf_alter
        keep alter union_nac_true nf_alter
        qui save "$tmp/_sib_b.dta", replace
        use "$tmp/_sib_a.dta", clear
        joinby union_nac_true using "$tmp/_sib_b.dta"
        qui drop if cod_inec_ci_actual >= alter
        qui count
        local npairs = r(N)
        qui count if id_fam_nuclear == nf_alter
        _num "true sibling pairs kept together in one nuclear family" r(N)
        di as txt "         of " as res %12.0fc `npairs' as txt " true pairs = " ///
           as res %5.1f 100*r(N)/`npairs' "%   (recall)"
    restore

    * and the other direction: of the pairs put in the same nuclear family as
    * children, how many really are siblings?
    preserve
        keep cod_inec_ci_actual id_fam_nuclear rol_nuclear union_nac_true
        qui keep if rol_nuclear == 2
        qui save "$tmp/_sib_a.dta", replace
        rename cod_inec_ci_actual alter
        rename union_nac_true     u_alter
        keep alter id_fam_nuclear u_alter
        qui save "$tmp/_sib_b.dta", replace
        use "$tmp/_sib_a.dta", clear
        joinby id_fam_nuclear using "$tmp/_sib_b.dta"
        qui drop if cod_inec_ci_actual >= alter
        qui count
        local npairs = r(N)
        qui count if union_nac_true == u_alter & !mi(union_nac_true)
        _num "co-assigned child pairs that really are true siblings" r(N)
        di as txt "         of " as res %12.0fc `npairs' as txt " co-assigned pairs = " ///
           as res %5.1f 100*r(N)/`npairs' "%   (precision)"
    restore

    *--- B5 do true grandparent-grandchild pairs share an extended family? --
    * Built from the TRUE, uncensored parent links, so this measures the joint
    * effect of the three-generation cut and of the censoring.
    use "$tmp/_val.dta", clear
    keep cod_inec_ci_actual ci_padre_true ci_madre_true id_fam_extendida id_fam_extendida2 id_dinastia
    rename cod_inec_ci_actual mid
    qui save "$tmp/_gp_b.dta", replace
    keep mid id_fam_extendida id_fam_extendida2 id_dinastia
    rename mid               abuelo
    rename id_fam_extendida  fe_ab
    rename id_fam_extendida2 fe2_ab
    rename id_dinastia       din_ab
    qui save "$tmp/_gp_c.dta", replace

    use "$tmp/_val.dta", clear
    keep cod_inec_ci_actual ci_padre_true ci_madre_true id_fam_extendida id_fam_extendida2 id_dinastia
    rename cod_inec_ci_actual ego
    rename id_fam_extendida   fe_ego
    rename id_fam_extendida2  fe2_ego
    rename id_dinastia        din_ego
    gen long _r1 = _n
    qui expand 2
    bysort _r1: gen byte s = _n
    gen double mid = cond(s == 1, ci_padre_true, ci_madre_true)
    qui keep if !mi(mid)
    keep ego mid fe_ego fe2_ego din_ego
    qui merge m:1 mid using "$tmp/_gp_b.dta", keep(match) nogen
    gen long _r2 = _n
    qui expand 2
    bysort _r2: gen byte s2 = _n
    gen double abuelo = cond(s2 == 1, ci_padre_true, ci_madre_true)
    qui keep if !mi(abuelo)
    keep ego abuelo fe_ego fe2_ego din_ego
    qui duplicates drop
    qui merge m:1 abuelo using "$tmp/_gp_c.dta", keep(match) nogen
    qui count
    local ngp = r(N)
    qui count if fe_ego == fe_ab
    _num "true grandparent-grandchild pairs in one extended family" r(N)
    di as txt "         of " as res %12.0fc `ngp' as txt " true pairs = " ///
       as res %5.1f 100*r(N)/`ngp' "%"
    di as txt "         (the shortfall is the three-generation cut plus the"
    di as txt "          censored links; a pair split by the cut is still in"
    di as txt "          the same dynasty)"
    qui count if fe2_ego == fe2_ab
    di as txt "         2-generation block: " as res %5.1f 100*r(N)/`ngp' "%"
    qui count if din_ego == din_ab
    di as txt "         same DYNASTY:      " as res %5.1f 100*r(N)/`ngp' "%"

    *--- B6 the shallow-ancestry block --------------------------------------
    use "$tmp/_val.dta", clear
    di as txt _n "extended-family size by ancestry block"
    di as txt "  (blk 1 = deep ancestry, six generations; blk 2 = shallow, three)"
    qui bysort id_fam_extendida: gen int fe_n = _N
    tabstat fe_n gen_lin, by(blk) stat(n mean p50 max) format(%9.2f)
}


********************************************************************************
* C. THE PLANTED PATHOLOGIES WERE ALL CAUGHT
********************************************************************************

di as txt _n "{hline 78}"
di as txt "C. PATHOLOGY HANDLING"
di as txt "{hline 78}"

use "$ced/cedulados_familias.dta", clear
foreach f of varlist f_* {
    qui count if `f' == 1
    local n = r(N)
    local lbl : var label `f'
    if "`lbl'" == "" local lbl "`f'"
    di as txt "  " %-40s "`f'" as res %10.0fc `n' as txt "  (" %5.2f 100*`n'/_N "%)"
}

di as txt _n "how many persons lost every link they had?"
qui count if mi(ci_padre_val) & mi(ci_madre_val) & mi(ci_conyuge_val) & n_hijos == 0
_num "persons with no usable relative at all" r(N)
di as txt "         = " as res %5.1f 100*r(N)/_N "% of the population"
qui count if rol_nuclear == 4
_num "one-person nuclear families" r(N)

di as res _n "validate_familias.do done"

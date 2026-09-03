********************************************************************************
*  build_familias.do
*  ---------------------------------------------------------------------------
*  Turns cedulados_full.dta (an individual-level registry with father, mother
*  and spouse pointers) into FAMILY IDENTIFIERS, so that a wealth- or income-
*  concentration analysis of the kind done at the individual level in
*      construccion_ingreso_DINA.do
*  can be run per family instead of per declarant.
*
*  ---------------------------------------------------------------------------
*  WHAT IS PRODUCED
*  ---------------------------------------------------------------------------
*  (1) id_fam_nuclear      NUCLEAR FAMILY - a strict partition of the
*                          population.  A nuclear family is one parental
*                          couple (or lone parent) plus their children, and
*                          the rule asked for is enforced literally:
*                          A PERSON STOPS BEING A CHILD THE MOMENT THEY HAVE
*                          A CHILD OF THEIR OWN.  A parent is therefore never
*                          counted inside their own parents' family.
*
*      id_fam_nuclear2     the same thing under the alternative emancipation
*                          rule, where MARRIAGE also emancipates: a married
*                          childless person forms a family with their spouse
*                          instead of staying in their parents' family.
*                          Under rule 1 (the literal one) a childless married
*                          couple is split across two families, which matters
*                          for a wealth analysis, so both are supplied.
*
*  (2) id_fam_extendida    EXTENDED FAMILY - also a strict partition, and a
*                          coarsening of id_fam_nuclear.  Consecutive
*                          generations of NUCLEAR families along the recorded
*                          lineage, anchored on nuclear families whose heads
*                          have no parents on file (the top of the recorded
*                          lineage) and cut every $PROF_EXT generations below
*                          the anchor.  The lineage followed is whichever of
*                          the head couple's two ancestries goes DEEPER in the
*                          file, so the block uses the richer of the two; the
*                          other one is kept in nf_up2.
*
*      id_fam_extendida2   the same with a two-generation block.  Since a
*                          nuclear family already holds a couple AND their
*                          children, two nuclear generations span exactly
*                          THREE person-generations - grandparents, their
*                          children and children-in-law, their grandchildren -
*                          which is the strict vertical reading of "second
*                          degree".  $PROF_EXT = 3 spans four person-
*                          generations instead: wider, but it keeps far more
*                          observed grandparent pairs together.  The coverage
*                          table at the end of section 8 quantifies the
*                          trade-off on whatever data is in front of you.
*
*      >>> WHY A CUT IS NEEDED.  "Everybody within two degrees of me" is an
*      >>> EGO-CENTRED set, and ego-centred sets overlap: my brother's
*      >>> second-degree circle is not mine.  There is therefore NO partition
*      >>> whose groups are exactly "all pairs within two degrees" - my uncle
*      >>> is three degrees from me but one from my father.  Any grouping
*      >>> variable has to choose, so:
*      >>>   - id_fam_extendida is the partition, for family-level totals,
*      >>>     Gini and top shares (no double counting);
*      >>>   - red_parentesco_g2.dta is the exact relation-by-relation
*      >>>     second-degree object, for ego-centred statistics ("how much of
*      >>>     the wealth of the top 1% sits inside their own second-degree
*      >>>     kin?"), where overlap is not a problem;
*      >>>   - id_dinastia is the unbounded alternative (see 4).
*
*  (3) red_parentesco_g2.dta   SECOND DEGREE OF CONSANGUINITY AND AFFINITY,
*                          exactly as the Civil Code counts it, as an
*                          ego-alter edge list with `grado` (0/1/2) and `via`
*                          (1 consanguinidad, 2 afinidad):
*                            consanguinidad grado 1  padre, madre, hijo/a
*                            consanguinidad grado 2  abuelo/a, nieto/a,
*                                                    hermano/a (pleno y medio)
*                            afinidad grado 0        conyuge
*                            afinidad grado 1        suegro/a, padrastro/
*                                                    madrastra, hijastro/a,
*                                                    yerno/nuera
*                            afinidad grado 2        cunado/a por el conyuge,
*                                                    cunado/a por el hermano,
*                                                    abuelo/a afin, nieto/a
*                                                    afin, conyuge del nieto/a
*                          Per-ego counts of every one of these are merged
*                          onto the person file (k_* and n_g2_*).
*
*  (4) id_dinastia         the connected component of the whole kinship graph
*                          (parent-child edges plus couple edges), unbounded.
*                          This is the "dynasty" used in dynastic-wealth work.
*                          Not a substitute for (2): components can be very
*                          large, because two dynasties merge as soon as one
*                          marriage links them.
*
*  ---------------------------------------------------------------------------
*  DIRTY DATA IS HANDLED, NOT ASSUMED AWAY
*  ---------------------------------------------------------------------------
*  Every link is validated before it is used, and every rejection is kept as
*  a flag (f_*) so the analyst can see how much of the family structure rests
*  on questionable records:
*     link = 0 or missing            -> no relative on file
*     link = own cedula              -> self-parenthood / self-spouse
*     link points at a nonexistent id-> dangling pointer
*     parent less than $BRECHA_MIN years older than the child -> rejected
*        (this also kills the parent-child cycles: two people cannot each be
*         twelve years older than the other)
*     "father" flagged female, "mother" flagged male -> KEPT but flagged,
*        because a sex-coding error is not evidence that the person is not a
*        parent, and dropping the link would lose a real family
*     mother died before the child was born -> KEPT but flagged
*     the same id in both the father and the mother field -> kept as father
*     several people naming the same spouse -> resolved to a matching, so the
*        conjugal union stays a partition; the losers are flagged
*
*  ---------------------------------------------------------------------------
*  OUTPUT FILES (all in $ced)
*  ---------------------------------------------------------------------------
*     cedulados_familias.dta    one row per person; merges 1:1 onto
*                               cedulados_full.dta and m:1 onto the SRI
*                               income files by cedula
*     familias_nucleares.dta    one row per nuclear family
*     familias_extendidas.dta   one row per extended family
*     red_parentesco_g2.dta     ego-alter second-degree kinship edge list
********************************************************************************

clear all
set more off
set type double

global fake "G:/Mi unidad/Trabajos/Predoc/data/fake_data"
global ced  "$fake/Bases/Bases INEC/Cedulados/dta"
global tmp  "$fake/Bases/bases_temp"
cap mkdir "$tmp"

*------------------------------- parameters -----------------------------------
* minimum plausible age gap, in years, between a parent and a child
global BRECHA_MIN   12
* depth of an extended family, in generations of nuclear families
global PROF_EXT     3
* reference year for "alive" / co-residence-style statistics
global ANIO_REF     2023
* build the unbounded dynasty component?              (slowest step)
global HACER_DINASTIA 1
* build the second-degree kinship edge list?
global HACER_RED      1

timer clear
timer on 1


********************************************************************************
* HELPER PROGRAMS
********************************************************************************
* Every kinship link is held as a two-column file (ci, alter).  Second-degree
* relations are then just compositions of first-degree ones.

capture program drop _rev
program define _rev
    * reverse a link file: (ci -> alter) becomes (alter -> ci)
    args A OUT
    use "`A'", clear
    rename ci    _t_
    rename alter ci
    rename _t_   alter
    keep ci alter
    qui save "`OUT'", replace
end

capture program drop _comp
program define _comp
    * compose: A is ci -> mid, B is ci -> alter, result is ci -> alter via mid
    args A B OUT
    use "`B'", clear
    rename ci mid
    keep mid alter
    qui save "$tmp/_cB_.dta", replace
    use "`A'", clear
    rename alter mid
    keep ci mid
    joinby mid using "$tmp/_cB_.dta"
    keep ci alter
    qui drop if ci == alter | mi(alter)
    qui duplicates drop ci alter, force
    qui save "`OUT'", replace
end

capture program drop _minus
program define _minus
    * A minus B, matching on the (ci, alter) pair
    args A B OUT
    use "`A'", clear
    qui merge 1:1 ci alter using "`B'", keep(master) nogen
    qui save "`OUT'", replace
end

capture program drop _ndist
program define _ndist
    * number of DISTINCT values of V inside each group G, saved keyed on G.
    * (egen's nvals() lives in egenmore, which is not assumed to be installed.)
    args G V NAME OUT
    preserve
        keep `G' `V'
        qui duplicates drop
        bysort `G': gen long `NAME' = _N
        by `G': keep if _n == 1
        keep `G' `NAME'
        qui save "`OUT'", replace
    restore
end

capture program drop _tag
program define _tag
    * stamp a link file with a relation code, degree and route, then append it
    * to the accumulating kinship network
    args A rel grado via
    use "`A'", clear
    qui count
    local nn = r(N)
    gen byte rel   = `rel'
    gen byte grado = `grado'
    gen byte via   = `via'
    qui append using "$tmp/_red.dta"
    qui save "$tmp/_red.dta", replace
    di as txt "   rel `rel' (grado `grado', via `via'): " as res %10.0fc `nn' as txt " edges"
end


********************************************************************************
* 1. LOAD, AND VALIDATE EVERY LINK
********************************************************************************

use "$ced/cedulados_full.dta", clear
keep cod_inec_ci_actual cod_inec_ci_padre cod_inec_ci_madre cod_inec_ci_conyugue ///
     cod_estado_civil cod_domicilio cod_lugar_nacimiento female yob yod age2023
rename cod_inec_ci_actual ci
isid ci

qui count
local NPERS = r(N)
di as res _n "persons on file: " %12.0fc `NPERS'

gen byte vivo_ref = mi(yod) | yod > $ANIO_REF
label var vivo_ref "1 if no death date on file by $ANIO_REF"

*--- a lookup of every person's own attributes, keyed on the pointer value ----
preserve
    keep ci female yob yod
    rename ci     alter
    rename female fem_a
    rename yob    yob_a
    rename yod    yod_a
    qui save "$tmp/_look.dta", replace
restore

foreach r in padre madre conyugue {
    gen double lnk_`r' = cod_inec_ci_`r'
    gen byte f_`r'_miss = mi(cod_inec_ci_`r')
    gen byte f_`r'_cero = cod_inec_ci_`r' == 0
    qui replace lnk_`r' = . if mi(lnk_`r') | lnk_`r' == 0

    gen byte f_`r'_self = !mi(lnk_`r') & lnk_`r' == ci
    qui replace lnk_`r' = . if f_`r'_self

    rename lnk_`r' alter
    qui merge m:1 alter using "$tmp/_look.dta", keep(master match) gen(_mm)
    gen byte f_`r'_inexist = !mi(alter) & _mm == 1
    drop _mm
    rename alter lnk_`r'
    rename fem_a fem_`r'
    rename yob_a yob_`r'
    rename yod_a yod_`r'
    qui replace lnk_`r' = . if f_`r'_inexist
}

* age and sex consistency of the parent links
gen byte f_padre_edad = !mi(lnk_padre) & !mi(yob_padre) & (yob - yob_padre) < $BRECHA_MIN
gen byte f_madre_edad = !mi(lnk_madre) & !mi(yob_madre) & (yob - yob_madre) < $BRECHA_MIN
gen byte f_padre_sexo = !mi(lnk_padre) & fem_padre == 1
gen byte f_madre_sexo = !mi(lnk_madre) & fem_madre == 0
gen byte f_madre_muerta_antes = !mi(lnk_madre) & !mi(yod_madre) & yod_madre < yob

* the clean parent pointers: everything above is applied except the sex and
* the mother-already-dead flags, which are recorded but not acted on
gen double pad = lnk_padre
gen double mad = lnk_madre
qui replace pad = . if f_padre_edad
qui replace mad = . if f_madre_edad
gen byte f_pad_igual_mad = !mi(pad) & pad == mad
qui replace mad = . if f_pad_igual_mad

* reciprocity of the spouse pointer
preserve
    keep ci lnk_conyugue
    rename ci alter
    rename lnk_conyugue con_del_alter
    qui save "$tmp/_lookc.dta", replace
restore
rename lnk_conyugue alter
qui merge m:1 alter using "$tmp/_lookc.dta", keep(master match) nogen
rename alter lnk_conyugue
gen byte f_con_reciproco = !mi(lnk_conyugue) & con_del_alter == ci
gen byte f_con_mismo_sexo = !mi(lnk_conyugue) & !mi(fem_conyugue) & fem_conyugue == female
drop con_del_alter

di as txt _n "{hline 78}"
di as txt "LINK VALIDATION"
di as txt "{hline 78}"
foreach r in padre madre conyugue {
    di as txt _n " cod_inec_ci_`r'"
    foreach f in miss cero self inexist {
        qui count if f_`r'_`f' == 1
        di as txt "   " %-26s "`f'" as res %10.0fc r(N) as txt "  (" %5.2f 100*r(N)/`NPERS' "%)"
    }
}
foreach f in padre_edad madre_edad padre_sexo madre_sexo madre_muerta_antes pad_igual_mad con_reciproco con_mismo_sexo {
    qui count if f_`f' == 1
    di as txt "   " %-30s "`f'" as res %10.0fc r(N)
}
qui count if !mi(pad) | !mi(mad)
di as txt _n " persons with at least one usable parent link: " as res %10.0fc r(N) ///
   as txt "  (" %5.2f 100*r(N)/`NPERS' "%)"
qui count if !mi(pad) & !mi(mad)
di as txt " persons with both parents usable:             " as res %10.0fc r(N)

drop lnk_padre lnk_madre yob_padre yob_madre yod_padre yod_madre fem_padre fem_madre
qui save "$tmp/_pers.dta", replace


********************************************************************************
* 2. WHO IS A PARENT?  ("a person stops being a child once they have a child")
********************************************************************************

use "$tmp/_pers.dta", clear
keep ci pad mad
qui expand 2
bysort ci: gen byte s = _n
gen double parent = cond(s == 1, pad, mad)
qui keep if !mi(parent)
contract parent
rename parent ci
rename _freq  n_hijos
qui save "$tmp/_nhijos.dta", replace

use "$tmp/_pers.dta", clear
qui merge 1:1 ci using "$tmp/_nhijos.dta", keep(master match) nogen
qui replace n_hijos = 0 if mi(n_hijos)
gen byte es_progenitor = n_hijos > 0
label var n_hijos       "children on file with this person as parent"
label var es_progenitor "1 if the person has at least one child on file"

di as txt _n "children per person on file"
tabstat n_hijos, stat(n mean p50 p90 max) format(%9.2f)
qui count if es_progenitor
di as res " progenitores: " %12.0fc r(N) as txt "  of " as res %12.0fc `NPERS'
qui save "$tmp/_pers.dta", replace


********************************************************************************
* 3. UNIONS
********************************************************************************
* A union is the unit a nuclear family is built on.  Two kinds:
*   tipo 1  reproductive: a distinct (father, mother) pair observed among the
*           children on file.  A lone parent gives the pair (0, mother).
*   tipo 2  conjugal: a couple linked only by the spouse pointer, with no
*           children on file.  Needed so that childless couples are a family.

*--- reproductive unions ------------------------------------------------------
use "$tmp/_pers.dta", clear
keep ci pad mad
gen double up = cond(mi(pad), 0, pad)
gen double um = cond(mi(mad), 0, mad)
qui keep if up != 0 | um != 0
contract up um
rename _freq n_hijos_union
gen byte union_tipo = 1
qui save "$tmp/_un_rep.dta", replace
di as res _n "reproductive unions: " %10.0fc _N

*--- conjugal unions ----------------------------------------------------------
* A pointer is directed, so A->B and B->A collapse to the same unordered pair.
* One person can be named by several others (a real pathology), so the pairs
* are reduced to a MATCHING: a pair survives only if it is the first choice of
* both of its members.  That keeps the conjugal union a partition.
use "$tmp/_pers.dta", clear
keep ci lnk_conyugue female fem_conyugue f_con_reciproco
qui keep if !mi(lnk_conyugue)
gen byte mismo_sexo = !mi(fem_conyugue) & fem_conyugue == female
gen double up = cond(mismo_sexo, min(ci, lnk_conyugue), cond(female == 0, ci, lnk_conyugue))
gen double um = cond(mismo_sexo, max(ci, lnk_conyugue), cond(female == 0, lnk_conyugue, ci))
collapse (max) f_con_reciproco, by(up um)
gen long prow = _n
gen byte neg_rec = -f_con_reciproco
qui count
local npair0 = r(N)
qui save "$tmp/_pairs0.dta", replace

qui expand 2
bysort prow: gen byte s = _n
gen double who = cond(s == 1, up, um)
bysort who (neg_rec prow): gen byte rk = _n
bysort prow: egen byte peor = max(rk)
qui keep if peor == 1
keep prow
qui duplicates drop
qui merge 1:1 prow using "$tmp/_pairs0.dta", keep(match) nogen
qui count
di as res "conjugal pairs: " %10.0fc r(N) as txt " kept of " as res %10.0fc `npair0' ///
   as txt " (the rest lose the matching: someone was named by several people)"
keep up um
gen byte union_tipo   = 2
gen long n_hijos_union = 0
qui save "$tmp/_un_con.dta", replace

*--- the union table ----------------------------------------------------------
use "$tmp/_un_rep.dta", clear
append using "$tmp/_un_con.dta"
* a conjugal pair that already is a reproductive union is redundant
bysort up um (union_tipo): keep if _n == 1
sort up um
gen long id_union = _n
global MAXU = _N
label var id_union      "union id (basis of the nuclear family)"
label var union_tipo    "1 reproductive, 2 conjugal only"
label var n_hijos_union "children on file born to this union"
qui save "$tmp/_unions.dta", replace
di as res _n "unions in total: " %10.0fc $MAXU
tab union_tipo

*--- the union each person was BORN INTO --------------------------------------
use "$tmp/_pers.dta", clear
gen double up = cond(mi(pad), 0, pad)
gen double um = cond(mi(mad), 0, mad)
qui merge m:1 up um using "$tmp/_unions.dta", keepusing(id_union) keep(master match) nogen
rename id_union id_union_origen
label var id_union_origen "union the person was born into (their parents')"
drop up um
qui save "$tmp/_pers.dta", replace

*--- first and last child of each union --------------------------------------
preserve
    keep id_union_origen yob
    qui keep if !mi(id_union_origen)
    collapse (max) yob_ult_hijo = yob (min) yob_pri_hijo = yob, by(id_union_origen)
    rename id_union_origen id_union
    qui save "$tmp/_uyob.dta", replace
restore

*--- membership, long ---------------------------------------------------------
use "$tmp/_unions.dta", clear
qui expand 2
bysort id_union: gen byte s = _n
gen double ci     = cond(s == 1, up, um)
gen double copart = cond(s == 1, um, up)
qui keep if ci != 0 & !mi(ci)
keep ci copart id_union union_tipo n_hijos_union
qui merge m:1 id_union using "$tmp/_uyob.dta", keep(master match) nogen
qui save "$tmp/_memb.dta", replace

*--- the PRIMARY union of each person ----------------------------------------
* A person can head several unions (serial unions).  Since a nuclear family
* has to be a partition, one of them is the primary one, chosen as:
*   1. the union whose co-parent is the person's recorded spouse
*   2. failing that, the union with the most children
*   3. failing that, the union with the most recent child
*   4. failing that, the lowest union id
use "$tmp/_memb.dta", clear
preserve
    use "$tmp/_pers.dta", clear
    keep ci lnk_conyugue
    qui save "$tmp/_pc.dta", replace
restore
qui merge m:1 ci using "$tmp/_pc.dta", keep(master match) nogen
gen byte neg_cony  = -(!mi(lnk_conyugue) & copart == lnk_conyugue)
gen long neg_hijos = -n_hijos_union
gen int  neg_yob   = -yob_ult_hijo

preserve
    qui keep if union_tipo == 1
    bysort ci (neg_cony neg_hijos neg_yob id_union): keep if _n == 1
    keep ci id_union n_hijos_union
    rename id_union      id_union_rep
    rename n_hijos_union n_hijos_union_rep
    qui save "$tmp/_prim_rep.dta", replace
restore
qui keep if union_tipo == 2
bysort ci (neg_cony id_union): keep if _n == 1
keep ci id_union
rename id_union id_union_cony
qui save "$tmp/_prim_con.dta", replace

use "$tmp/_pers.dta", clear
qui merge 1:1 ci using "$tmp/_prim_rep.dta", keep(master match) nogen
qui merge 1:1 ci using "$tmp/_prim_con.dta", keep(master match) nogen
label var id_union_rep  "primary reproductive union headed by the person"
label var id_union_cony "primary conjugal-only union of the person"
qui save "$tmp/_pers.dta", replace


********************************************************************************
* 4. THE NUCLEAR FAMILY
********************************************************************************
* Rule as asked for (id_fam_nuclear):
*   1. a progenitor heads their own primary reproductive union
*   2. otherwise, the person belongs to the union they were born into
*   3. otherwise, to their conjugal union
*   4. otherwise, they are a one-person family
* Alternative rule (id_fam_nuclear2): steps 2 and 3 swap, so marriage
* emancipates as well as parenthood.

use "$tmp/_pers.dta", clear

gen long id_fam_nuclear = .
gen byte rol_nuclear    = .
qui replace id_fam_nuclear = id_union_rep    if es_progenitor & !mi(id_union_rep)
qui replace rol_nuclear    = 1               if !mi(id_fam_nuclear)
qui replace id_fam_nuclear = id_union_origen if mi(id_fam_nuclear) & !mi(id_union_origen)
qui replace rol_nuclear    = 2               if mi(rol_nuclear) & !mi(id_fam_nuclear)
qui replace id_fam_nuclear = id_union_cony   if mi(id_fam_nuclear) & !mi(id_union_cony)
qui replace rol_nuclear    = 3               if mi(rol_nuclear) & !mi(id_fam_nuclear)

gen long id_fam_nuclear2 = .
gen byte rol_nuclear2    = .
qui replace id_fam_nuclear2 = id_union_rep    if es_progenitor & !mi(id_union_rep)
qui replace rol_nuclear2    = 1               if !mi(id_fam_nuclear2)
qui replace id_fam_nuclear2 = id_union_cony   if mi(id_fam_nuclear2) & !mi(id_union_cony)
qui replace rol_nuclear2    = 3               if mi(rol_nuclear2) & !mi(id_fam_nuclear2)
qui replace id_fam_nuclear2 = id_union_origen if mi(id_fam_nuclear2) & !mi(id_union_origen)
qui replace rol_nuclear2    = 2               if mi(rol_nuclear2) & !mi(id_fam_nuclear2)

* one-person families get ids above the last real union id, in both variants
sort ci
gen long _s1 = sum(mi(id_fam_nuclear))
qui replace id_fam_nuclear = $MAXU + _s1 if mi(id_fam_nuclear)
qui replace rol_nuclear    = 4           if mi(rol_nuclear)
gen long _s2 = sum(mi(id_fam_nuclear2))
qui replace id_fam_nuclear2 = $MAXU + _s2 if mi(id_fam_nuclear2)
qui replace rol_nuclear2    = 4           if mi(rol_nuclear2)
drop _s1 _s2

label define rol 1 "progenitor (jefe/a o conyuge)" 2 "hijo/a" ///
                 3 "conyuge sin hijos" 4 "persona sola", replace
label values rol_nuclear rol
label values rol_nuclear2 rol
label var id_fam_nuclear  "familia nuclear (la paternidad emancipa)"
label var id_fam_nuclear2 "familia nuclear (la paternidad o el matrimonio emancipan)"
label var rol_nuclear     "rol en id_fam_nuclear"
label var rol_nuclear2    "rol en id_fam_nuclear2"

*--- family-level descriptives, carried back onto the person -------------------
foreach v in "" 2 {
    bysort id_fam_nuclear`v': gen long nf`v'_tam       = _N
    bysort id_fam_nuclear`v': egen int nf`v'_n_padres  = total(rol_nuclear`v' == 1)
    bysort id_fam_nuclear`v': egen int nf`v'_n_hijos   = total(rol_nuclear`v' == 2)
    bysort id_fam_nuclear`v': egen int nf`v'_n_vivos   = total(vivo_ref)
    gen byte nf`v'_biparental = nf`v'_n_padres == 2
    label var nf`v'_tam        "personas en la familia nuclear"
    label var nf`v'_n_padres   "progenitores en la familia nuclear"
    label var nf`v'_n_hijos    "hijos/as en la familia nuclear"
    label var nf`v'_n_vivos    "miembros sin fecha de defuncion a $ANIO_REF"
    label var nf`v'_biparental "1 si la familia nuclear tiene dos progenitores"
}

di as txt _n "{hline 78}"
di as txt "NUCLEAR FAMILY"
di as txt "{hline 78}"
di as txt _n "role, rule 1 (only parenthood emancipates)"
tab rol_nuclear
di as txt _n "role, rule 2 (parenthood or marriage emancipate)"
tab rol_nuclear2
qui bysort id_fam_nuclear: gen byte _first = _n == 1
qui count if _first
di as res _n "nuclear families: " %10.0fc r(N)
di as txt _n "size of the nuclear family"
tabstat nf_tam if _first, stat(n mean p50 p90 max) format(%9.2f)
di as txt _n "single-parent vs two-parent families (families, not persons)"
tab nf_biparental if _first & nf_n_padres > 0
drop _first

qui save "$tmp/_pers.dta", replace


********************************************************************************
* 5. LINEAGE GENERATION INDEX
********************************************************************************
* gen_lin = 0 for a person with no parent on file, otherwise one more than the
* deepest parent.  Resolved by iteration; anything that never resolves is part
* of a parent-child cycle and is flagged (the $BRECHA_MIN rule should already
* have removed every cycle, so this is a safety net).

use "$tmp/_pers.dta", clear
gen int gen_lin = 0 if mi(pad) & mi(mad)

local it = 0
local pend = 1
while `pend' > 0 & `it' < 40 {
    local it = `it' + 1
    preserve
        keep ci gen_lin
        rename ci      pad
        rename gen_lin g_pad
        qui save "$tmp/_gp.dta", replace
        rename pad   mad
        rename g_pad g_mad
        qui save "$tmp/_gm.dta", replace
    restore
    qui merge m:1 pad using "$tmp/_gp.dta", keep(master match) nogen
    qui merge m:1 mad using "$tmp/_gm.dta", keep(master match) nogen
    qui replace gen_lin = 1 + max(g_pad, g_mad) ///
        if mi(gen_lin) & (mi(pad) | !mi(g_pad)) & (mi(mad) | !mi(g_mad))
    drop g_pad g_mad
    qui count if mi(gen_lin)
    local pend = r(N)
}
gen byte f_ciclo = mi(gen_lin)
label var gen_lin "generacion en el linaje registrado (0 = sin padres en el archivo)"
label var f_ciclo "1 si el linaje no resuelve (ciclo padre-hijo)"
di as res _n "generation index resolved in " `it' " iterations; unresolved (cycles): " `pend'
tab gen_lin, missing
qui save "$tmp/_pers.dta", replace


********************************************************************************
* 6. THE EXTENDED FAMILY
********************************************************************************
* The nuclear families form a forest: every nuclear family points up at the
* nuclear family in which its head was a child.  The extended family is a
* three-generation block of that forest, anchored at the top of the recorded
* lineage.

*--- the upward edge of each union -------------------------------------------
preserve
    use "$tmp/_pers.dta", clear
    keep ci id_union_origen gen_lin
    rename ci              up
    rename id_union_origen orig_up
    rename gen_lin         gen_up
    qui save "$tmp/_oup.dta", replace
    rename up      um
    rename orig_up orig_um
    rename gen_up  gen_um
    qui save "$tmp/_oum.dta", replace
restore

use "$tmp/_unions.dta", clear
qui merge m:1 up using "$tmp/_oup.dta", keep(master match) nogen
qui merge m:1 um using "$tmp/_oum.dta", keep(master match) nogen
* Both lineages of the head couple are kept.  The lineage the block FOLLOWS is
* whichever of the two goes deeper in the file, so the extended family uses the
* richer of the two recorded ancestries rather than always the father's.  A
* partition can only follow one line at a time - see the header - so the other
* line is kept in nf_up2 for anyone who wants the alternative.
gen long nf_up  = orig_up
gen long nf_up2 = orig_um
gen int  nf_gen = min(gen_up, gen_um)
label var nf_up  "parental union of the head in the pad slot"
label var nf_up2 "parental union of the head in the mad slot"
label var nf_gen "generation of the head couple"

*--- depth below the top of the recorded lineage -----------------------------
* nf_prof = 0 when neither head has parents on file, otherwise one more than
* the DEEPER of the two parental unions.
gen int nf_prof = 0 if mi(nf_up) & mi(nf_up2)
local it = 0
local pend = 1
while `pend' > 0 & `it' < 40 {
    local it = `it' + 1
    preserve
        keep id_union nf_prof
        rename id_union nf_up
        rename nf_prof  prof_1
        qui save "$tmp/_pu1.dta", replace
        rename nf_up  nf_up2
        rename prof_1 prof_2
        qui save "$tmp/_pu2.dta", replace
    restore
    qui merge m:1 nf_up  using "$tmp/_pu1.dta", keep(master match) nogen
    qui merge m:1 nf_up2 using "$tmp/_pu2.dta", keep(master match) nogen
    qui replace nf_prof = 1 + max(prof_1, prof_2) ///
        if mi(nf_prof) & (mi(nf_up) | !mi(prof_1)) & (mi(nf_up2) | !mi(prof_2))
    drop prof_1 prof_2
    qui count if mi(nf_prof)
    local pend = r(N)
}
qui replace nf_prof = 0 if mi(nf_prof)
label var nf_prof "generations of nuclear families above this one on file"
di as res _n "nuclear-family depth resolved in " `it' " iterations; unresolved: " `pend'
tab nf_prof

* the edge the block follows: the deeper parental union
preserve
    keep id_union nf_prof
    rename id_union nf_up
    rename nf_prof  prof_1
    qui save "$tmp/_pu1.dta", replace
    rename nf_up  nf_up2
    rename prof_1 prof_2
    qui save "$tmp/_pu2.dta", replace
restore
qui merge m:1 nf_up  using "$tmp/_pu1.dta", keep(master match) nogen
qui merge m:1 nf_up2 using "$tmp/_pu2.dta", keep(master match) nogen
gen long nf_padre = nf_up
qui replace nf_padre = nf_up2 if !mi(nf_up2) & (mi(nf_up) | prof_2 > prof_1)
drop prof_1 prof_2
label var nf_padre "the parental union the extended-family block follows"

*--- anchor: walk up until the depth is a multiple of the block size ---------
* Two block sizes are produced, because they mean different things:
*
*   id_fam_extendida   $PROF_EXT = 3 generations of NUCLEAR families.  A
*                      nuclear family holds a couple AND their children, so
*                      three of them span FOUR person-generations: this is the
*                      wider unit, and it keeps far more recorded grandparent
*                      pairs together (see the coverage table at the end of
*                      section 8).
*
*   id_fam_extendida2  2 generations of nuclear families = exactly THREE
*                      person-generations, i.e. grandparents, their children
*                      and children-in-law, and their grandchildren.  This is
*                      the strict reading of "second degree" on the vertical
*                      axis, at the cost of splitting more real kin pairs.
*
* Both are strict partitions and both are coarsenings of id_fam_nuclear.
forvalues j = 1/2 {
    if `j' == 1 {
        local v ""
        local B $PROF_EXT
    }
    else {
        local v "2"
        local B 2
        * if the block size is already 2 the two variants coincide
        if $PROF_EXT == 2 {
            gen long id_fam_extendida2 = id_fam_extendida
            label var id_fam_extendida2 "familia extendida (bloque de 2 gen. de familias nucleares)"
            continue
        }
    }

    gen long id_fam_extendida`v' = id_union if mod(nf_prof, `B') == 0
    forvalues k = 1/`B' {
        preserve
            keep id_union id_fam_extendida`v'
            rename id_union            nf_padre
            rename id_fam_extendida`v' anc_up
            qui save "$tmp/_au.dta", replace
        restore
        qui merge m:1 nf_padre using "$tmp/_au.dta", keep(master match) nogen
        qui replace id_fam_extendida`v' = anc_up if mi(id_fam_extendida`v') & !mi(anc_up)
        drop anc_up
    }
    qui replace id_fam_extendida`v' = id_union if mi(id_fam_extendida`v')
    label var id_fam_extendida`v' "familia extendida (bloque de `B' gen. de familias nucleares)"
}

keep id_union union_tipo n_hijos_union up um nf_up nf_up2 nf_padre nf_gen nf_prof ///
     id_fam_extendida id_fam_extendida2
qui save "$tmp/_unions2.dta", replace

*--- carry it onto the person ------------------------------------------------
use "$tmp/_pers.dta", clear
preserve
    use "$tmp/_unions2.dta", clear
    keep id_union id_fam_extendida id_fam_extendida2 nf_prof nf_gen
    rename id_union id_fam_nuclear
    qui save "$tmp/_efmap.dta", replace
restore
qui merge m:1 id_fam_nuclear using "$tmp/_efmap.dta", keep(master match) nogen
* a one-person family is its own extended family
qui replace id_fam_extendida  = id_fam_nuclear if mi(id_fam_extendida)
qui replace id_fam_extendida2 = id_fam_nuclear if mi(id_fam_extendida2)
qui replace nf_prof = 0 if mi(nf_prof)

bysort id_fam_extendida: gen long fe_tam     = _N
bysort id_fam_extendida: egen long fe_n_vivos = total(vivo_ref)
_ndist id_fam_extendida id_fam_nuclear fe_n_fam "$tmp/_d1.dta"
_ndist id_fam_extendida gen_lin        fe_n_gen "$tmp/_d2.dta"
qui merge m:1 id_fam_extendida using "$tmp/_d1.dta", keep(master match) nogen
qui merge m:1 id_fam_extendida using "$tmp/_d2.dta", keep(master match) nogen
label var fe_tam     "personas en la familia extendida"
label var fe_n_fam   "familias nucleares en la familia extendida"
label var fe_n_gen   "generaciones distintas en la familia extendida"
label var fe_n_vivos "miembros sin fecha de defuncion a $ANIO_REF"

di as txt _n "{hline 78}"
di as txt "EXTENDED FAMILY"
di as txt "{hline 78}"
qui bysort id_fam_extendida: gen byte _first = _n == 1
qui count if _first
di as res _n "extended families: " %10.0fc r(N)
di as txt _n "size of the extended family"
tabstat fe_tam if _first, stat(n mean p50 p90 p99 max) format(%9.2f)
di as txt _n "nuclear families per extended family"
tabstat fe_n_fam if _first, stat(mean p50 p90 max) format(%9.2f)
di as txt _n "generations per extended family"
tab fe_n_gen if _first
drop _first
qui save "$tmp/_pers.dta", replace


********************************************************************************
* 7. DYNASTY: THE UNBOUNDED KINSHIP COMPONENT
********************************************************************************
* Connected components of the graph with parent-child and couple edges, by
* minimum-label propagation with path compression (so it converges in about
* log(diameter) passes rather than diameter passes).

if $HACER_DINASTIA {

    use "$tmp/_pers.dta", clear
    keep ci pad mad lnk_conyugue
    qui expand 3
    bysort ci: gen byte s = _n
    gen double b = cond(s == 1, pad, cond(s == 2, mad, lnk_conyugue))
    qui keep if !mi(b) & b != ci
    rename ci a
    keep a b
    preserve
        rename a _t_
        rename b a
        rename _t_ b
        qui save "$tmp/_e2.dta", replace
    restore
    append using "$tmp/_e2.dta"
    qui duplicates drop a b, force
    qui count
    di as res _n "kinship edges (both directions): " %12.0fc r(N)
    qui save "$tmp/_edges.dta", replace

    use "$tmp/_pers.dta", clear
    keep ci
    gen double lab = ci
    qui save "$tmp/_lab.dta", replace

    local it = 0
    local changed = 1
    while `changed' == 1 & `it' < 60 {
        local it = `it' + 1

        use "$tmp/_edges.dta", clear
        rename b ci
        qui merge m:1 ci using "$tmp/_lab.dta", keep(match) nogen
        rename lab lab_b
        collapse (min) lab_b, by(a)
        rename a ci
        qui save "$tmp/_nb.dta", replace

        use "$tmp/_lab.dta", clear
        qui merge 1:1 ci using "$tmp/_nb.dta", keep(master match) nogen
        gen double lab_new = min(lab, lab_b)
        drop lab_b

        * path compression: replace my label by the label of my label
        preserve
            keep ci lab_new
            rename ci      k_
            rename lab_new lab_of_k
            qui save "$tmp/_ll.dta", replace
        restore
        gen double k_ = lab_new
        qui merge m:1 k_ using "$tmp/_ll.dta", keep(master match) nogen
        qui replace lab_new = min(lab_new, lab_of_k)
        drop k_ lab_of_k

        qui count if lab_new < lab
        local changed = (r(N) > 0)
        di as txt "   pass `it': " as res %10.0fc r(N) as txt " labels still falling"
        qui replace lab = lab_new
        drop lab_new
        qui save "$tmp/_lab.dta", replace
    }

    use "$tmp/_lab.dta", clear
    egen long id_dinastia = group(lab)
    keep ci id_dinastia
    qui save "$tmp/_din.dta", replace

    use "$tmp/_pers.dta", clear
    qui merge 1:1 ci using "$tmp/_din.dta", keep(master match) nogen
    bysort id_dinastia: gen long din_tam = _N
    _ndist id_dinastia id_fam_nuclear din_n_fam "$tmp/_d3.dta"
    qui merge m:1 id_dinastia using "$tmp/_d3.dta", keep(master match) nogen
    label var id_dinastia "componente conexa del grafo de parentesco (dinastia)"
    label var din_tam     "personas en la dinastia"
    label var din_n_fam   "familias nucleares en la dinastia"

    di as txt _n "{hline 78}"
    di as txt "DYNASTY (unbounded component)"
    di as txt "{hline 78}"
    qui bysort id_dinastia: gen byte _first = _n == 1
    qui count if _first
    di as res _n "dynasties: " %10.0fc r(N)
    tabstat din_tam if _first, stat(n mean p50 p90 p99 max) format(%12.1f)
    di as txt _n "the ten largest dynasties, as a share of the population:"
    preserve
        qui keep if _first
        gsort -din_tam
        qui keep in 1/10
        gen double pct = 100*din_tam/`NPERS'
        format pct %8.3f
        list id_dinastia din_tam din_n_fam pct, noobs
    restore
    qui sum din_tam
    di as txt _n "   largest dynasty = " as res %6.2f 100*r(max)/`NPERS' as txt "% of the population."
    di as txt "   One marriage merges two lineages for good, so these components"
    di as txt "   grow without bound as registry coverage improves.  That is why"
    di as txt "   id_dinastia is a robustness check, not the main family id."
    drop _first
    qui save "$tmp/_pers.dta", replace
}


********************************************************************************
* 8. SECOND DEGREE OF CONSANGUINITY AND AFFINITY
********************************************************************************

if $HACER_RED {

    di as txt _n "{hline 78}"
    di as txt "SECOND-DEGREE KINSHIP NETWORK"
    di as txt "{hline 78}"

    clear
    set obs 1
    gen double ci    = .
    gen double alter = .
    gen byte   rel   = .
    gen byte   grado = .
    gen byte   via   = .
    drop in 1
    qui save "$tmp/_red.dta", replace

    *--- first-degree building blocks -----------------------------------------
    * parents
    use "$tmp/_pers.dta", clear
    keep ci pad mad
    qui expand 2
    bysort ci: gen byte s = _n
    gen double alter = cond(s == 1, pad, mad)
    gen byte rol_p   = s
    qui keep if !mi(alter)
    keep ci alter rol_p
    qui save "$tmp/_L_par_r.dta", replace
    keep ci alter
    qui save "$tmp/_L_par.dta", replace
    _rev "$tmp/_L_par.dta" "$tmp/_L_hij.dta"

    * the accepted conjugal partner: symmetric by construction
    use "$tmp/_unions2.dta", clear
    qui keep if up != 0 & um != 0 & !mi(up) & !mi(um)
    keep up um
    gen double ci    = up
    gen double alter = um
    keep ci alter
    preserve
        rename ci _t_
        rename alter ci
        rename _t_ alter
        qui save "$tmp/_cv.dta", replace
    restore
    append using "$tmp/_cv.dta"
    qui duplicates drop ci alter, force
    qui save "$tmp/_L_con.dta", replace

    * grandparents / grandchildren
    _comp "$tmp/_L_par.dta" "$tmp/_L_par.dta" "$tmp/_L_ab.dta"
    _rev  "$tmp/_L_ab.dta" "$tmp/_L_ni.dta"

    * siblings: full (both parents shared) and half (exactly one shared)
    use "$tmp/_pers.dta", clear
    keep ci pad mad
    qui keep if !mi(pad) & !mi(mad)
    egen long g_ = group(pad mad)
    keep ci g_
    qui save "$tmp/_sa.dta", replace
    rename ci alter
    qui save "$tmp/_sb.dta", replace
    use "$tmp/_sa.dta", clear
    joinby g_ using "$tmp/_sb.dta"
    qui drop if ci == alter
    keep ci alter
    qui duplicates drop ci alter, force
    qui save "$tmp/_L_hermc.dta", replace

    * anyone sharing at least one parent
    use "$tmp/_L_par.dta", clear
    rename alter g_
    qui save "$tmp/_sa.dta", replace
    rename ci alter
    qui save "$tmp/_sb.dta", replace
    use "$tmp/_sa.dta", clear
    joinby g_ using "$tmp/_sb.dta"
    qui drop if ci == alter
    keep ci alter
    qui duplicates drop ci alter, force
    qui save "$tmp/_L_hermx.dta", replace
    _minus "$tmp/_L_hermx.dta" "$tmp/_L_hermc.dta" "$tmp/_L_hermm.dta"
    * every sibling, full or half, for composing the in-law relations
    use "$tmp/_L_hermx.dta", clear
    qui save "$tmp/_L_herm.dta", replace

    *--- consanguinidad --------------------------------------------------------
    * grado 1: padre, madre, hijo/a
    use "$tmp/_L_par_r.dta", clear
    qui keep if rol_p == 1
    keep ci alter
    qui save "$tmp/_x.dta", replace
    _tag "$tmp/_x.dta" 1 1 1
    use "$tmp/_L_par_r.dta", clear
    qui keep if rol_p == 2
    keep ci alter
    qui save "$tmp/_x.dta", replace
    _tag "$tmp/_x.dta" 2 1 1
    _tag "$tmp/_L_hij.dta"   3 1 1
    * grado 2: abuelo/a, nieto/a, hermano/a
    _tag "$tmp/_L_ab.dta"    4 2 1
    _tag "$tmp/_L_ni.dta"    5 2 1
    _tag "$tmp/_L_hermc.dta" 6 2 1
    _tag "$tmp/_L_hermm.dta" 7 2 1

    *--- afinidad --------------------------------------------------------------
    * grado 0: the spouse
    _tag "$tmp/_L_con.dta" 10 0 2
    * grado 1: suegro/a, padrastro/madrastra, hijastro/a, yerno/nuera
    _comp  "$tmp/_L_con.dta" "$tmp/_L_par.dta" "$tmp/_L_sue.dta"
    _tag   "$tmp/_L_sue.dta" 11 1 2
    _comp  "$tmp/_L_par.dta" "$tmp/_L_con.dta" "$tmp/_L_pad0.dta"
    _minus "$tmp/_L_pad0.dta" "$tmp/_L_par.dta" "$tmp/_L_pad1.dta"
    _tag   "$tmp/_L_pad1.dta" 12 1 2
    _comp  "$tmp/_L_con.dta" "$tmp/_L_hij.dta" "$tmp/_L_hst0.dta"
    _minus "$tmp/_L_hst0.dta" "$tmp/_L_hij.dta" "$tmp/_L_hst1.dta"
    _tag   "$tmp/_L_hst1.dta" 13 1 2
    _comp  "$tmp/_L_hij.dta" "$tmp/_L_con.dta" "$tmp/_L_yer.dta"
    _tag   "$tmp/_L_yer.dta" 14 1 2
    * grado 2: cunado/a por el conyuge y por el hermano, abuelo/a y nieto/a
    *          afines, conyuge del nieto/a
    _comp  "$tmp/_L_con.dta" "$tmp/_L_herm.dta" "$tmp/_L_cu1.dta"
    _tag   "$tmp/_L_cu1.dta" 15 2 2
    _comp  "$tmp/_L_herm.dta" "$tmp/_L_con.dta" "$tmp/_L_cu2.dta"
    _tag   "$tmp/_L_cu2.dta" 16 2 2
    _comp  "$tmp/_L_con.dta" "$tmp/_L_ab.dta" "$tmp/_L_aba.dta"
    _tag   "$tmp/_L_aba.dta" 17 2 2
    _comp  "$tmp/_L_con.dta" "$tmp/_L_ni.dta" "$tmp/_L_nia0.dta"
    _minus "$tmp/_L_nia0.dta" "$tmp/_L_ni.dta" "$tmp/_L_nia1.dta"
    _tag   "$tmp/_L_nia1.dta" 18 2 2
    _comp  "$tmp/_L_ni.dta" "$tmp/_L_con.dta" "$tmp/_L_nic.dta"
    _tag   "$tmp/_L_nic.dta" 19 2 2

    *--- the finished network -------------------------------------------------
    use "$tmp/_red.dta", clear
    * a pair can qualify under more than one heading (half-sibling who is also
    * an in-law, and so on); the closest tie is kept as the primary one
    bysort ci alter (grado rel): gen byte primaria = _n == 1

    label define rel                                        ///
         1 "padre"                 2 "madre"                ///
         3 "hijo/a"                4 "abuelo/a"             ///
         5 "nieto/a"               6 "hermano/a pleno"      ///
         7 "hermano/a medio"      10 "conyuge"              ///
        11 "suegro/a"             12 "padrastro/madrastra"  ///
        13 "hijastro/a"           14 "yerno/nuera"          ///
        15 "cunado/a (herm. del conyuge)"                   ///
        16 "cunado/a (conyuge del herm.)"                   ///
        17 "abuelo/a afin"        18 "nieto/a afin"         ///
        19 "conyuge del nieto/a", replace
    label values rel rel
    label define via 1 "consanguinidad" 2 "afinidad", replace
    label values via via
    label var ci       "ego (cod_inec_ci_actual)"
    label var alter    "pariente (cod_inec_ci_actual)"
    label var rel      "tipo de parentesco"
    label var grado    "grado (0 conyuge, 1 primero, 2 segundo)"
    label var via      "consanguinidad o afinidad"
    label var primaria "1 = vinculo mas cercano para este par ego-pariente"
    order ci alter rel grado via primaria
    sort ci alter rel
    compress
    save "$ced/red_parentesco_g2.dta", replace

    di as txt _n "edges by relation"
    tab rel
    di as txt _n "edges by degree and route"
    tab grado via

    *--- per-ego counts -------------------------------------------------------
    keep if primaria
    gen byte k_padres  = inlist(rel, 1, 2)
    gen byte k_hijos   = rel == 3
    gen byte k_abuelos = rel == 4
    gen byte k_nietos  = rel == 5
    gen byte k_herm    = inlist(rel, 6, 7)
    gen byte k_hermc   = rel == 6
    gen byte k_conyuge = rel == 10
    gen byte k_suegros = rel == 11
    gen byte k_hijast  = inlist(rel, 12, 13)
    gen byte k_yernos  = rel == 14
    gen byte k_cunados = inlist(rel, 15, 16)
    gen byte k_otros_af = inlist(rel, 17, 18, 19)
    gen byte n_g2_cons = via == 1
    gen byte n_g2_afin = via == 2
    gen byte n_g2_g1   = grado == 1
    gen byte n_g2_g2   = grado == 2
    collapse (sum) k_padres k_hijos k_abuelos k_nietos k_herm k_hermc k_conyuge ///
                   k_suegros k_hijast k_yernos k_cunados k_otros_af             ///
                   n_g2_cons n_g2_afin n_g2_g1 n_g2_g2, by(ci)
    egen int n_g2_total = rowtotal(n_g2_cons n_g2_afin)
    qui save "$tmp/_kcounts.dta", replace

    use "$tmp/_pers.dta", clear
    qui merge 1:1 ci using "$tmp/_kcounts.dta", keep(master match) nogen
    foreach v of varlist k_* n_g2_* {
        qui replace `v' = 0 if mi(`v')
    }
    label var k_padres   "padre/madre en el archivo"
    label var k_hijos    "hijos/as"
    label var k_abuelos  "abuelos/as"
    label var k_nietos   "nietos/as"
    label var k_herm     "hermanos/as (plenos y medios)"
    label var k_hermc    "hermanos/as plenos"
    label var k_conyuge  "conyuge"
    label var k_suegros  "suegros/as"
    label var k_hijast   "hijastros/as y padrastros/madrastras"
    label var k_yernos   "yernos/nueras"
    label var k_cunados  "cunados/as"
    label var k_otros_af "otros afines de segundo grado"
    label var n_g2_cons  "parientes de consanguinidad hasta 2do grado"
    label var n_g2_afin  "parientes de afinidad hasta 2do grado"
    label var n_g2_g1    "parientes de primer grado"
    label var n_g2_g2    "parientes de segundo grado"
    label var n_g2_total "parientes hasta segundo grado (consang. + afin.)"

    di as txt _n "second-degree kin per person"
    tabstat n_g2_total n_g2_cons n_g2_afin k_herm k_abuelos k_nietos k_cunados, ///
        stat(mean p50 p90 max) format(%9.2f) columns(statistics)
    qui count if n_g2_total == 0
    di as res _n "persons with no relative at all on file: " %10.0fc r(N) ///
       as txt "  (" %5.2f 100*r(N)/`NPERS' "%)"


    qui save "$tmp/_pers.dta", replace

    ****************************************************************************
    *  HOW MUCH REAL KINSHIP DOES EACH GROUPING VARIABLE KEEP TOGETHER?
    ****************************************************************************
    * This is the table to read before choosing a unit of analysis, and it needs
    * no ground truth, so it works exactly the same on the real registry.  For
    * every kind of second-degree tie actually observed in the file, it reports
    * the share of those pairs that fall inside the same nuclear family, the
    * same extended family (both block sizes) and the same dynasty.
    *
    * A nuclear family is SUPPOSED to split grandparent and cousin ties - that
    * is what makes it nuclear - so a low number in the first column is correct
    * behaviour, not a defect.  What matters is the second and third columns:
    * how much of the vertical (grandparent/grandchild) and lateral
    * (sibling/in-law) structure the extended family retains.

    use "$tmp/_pers.dta", clear
    keep ci id_fam_nuclear id_fam_extendida id_fam_extendida2 id_dinastia
    qui save "$tmp/_gmap_a.dta", replace
    rename ci               alter
    rename id_fam_nuclear   g_nf_b
    rename id_fam_extendida g_fe_b
    rename id_fam_extendida2 g_fe2_b
    rename id_dinastia      g_din_b
    qui save "$tmp/_gmap_b.dta", replace

    use "$ced/red_parentesco_g2.dta", clear
    qui keep if primaria
    qui merge m:1 ci    using "$tmp/_gmap_a.dta", keep(match) nogen
    qui merge m:1 alter using "$tmp/_gmap_b.dta", keep(match) nogen
    gen byte junto_nf  = id_fam_nuclear   == g_nf_b
    gen byte junto_fe  = id_fam_extendida == g_fe_b
    gen byte junto_fe2 = id_fam_extendida2 == g_fe2_b
    gen byte junto_din = id_dinastia      == g_din_b
    label var junto_nf  "misma fam. nuclear"
    label var junto_fe  "misma fam. extendida"
    label var junto_fe2 "misma fam. ext. (2 gen)"
    label var junto_din "misma dinastia"

    di as txt _n "share of OBSERVED kin pairs falling inside the same group"
    table rel, statistic(mean junto_nf junto_fe junto_fe2 junto_din) ///
        statistic(frequency) nformat(%6.3f mean) nformat(%9.0fc frequency)
    di as txt _n "the same, collapsed by degree and route"
    table grado via, statistic(mean junto_nf junto_fe junto_fe2 junto_din) ///
        nformat(%6.3f mean)
}


********************************************************************************
* 9. SAVE
********************************************************************************

use "$tmp/_pers.dta", clear
rename ci cod_inec_ci_actual
rename lnk_conyugue ci_conyuge_val
rename pad ci_padre_val
rename mad ci_madre_val
label var ci_padre_val   "father cedula after validation (. = not usable)"
label var ci_madre_val   "mother cedula after validation (. = not usable)"
label var ci_conyuge_val "spouse cedula after validation (. = not usable)"

drop cod_inec_ci_padre cod_inec_ci_madre cod_inec_ci_conyugue ///
     fem_conyugue yob_conyugue yod_conyugue

order cod_inec_ci_actual id_fam_nuclear rol_nuclear id_fam_nuclear2 rol_nuclear2 ///
      id_fam_extendida id_fam_extendida2 id_dinastia
sort cod_inec_ci_actual
compress
save "$ced/cedulados_familias.dta", replace
di as res _n "saved: $ced/cedulados_familias.dta"
describe

*--- family-level files -------------------------------------------------------
local din ""
if $HACER_DINASTIA local din "id_dinastia"

use "$ced/cedulados_familias.dta", clear
collapse (first) id_fam_extendida `din' nf_biparental                ///
         (max) nf_tam nf_n_padres nf_n_hijos nf_n_vivos nf_prof      ///
         (min) yob_min = yob (max) yob_max = yob                     ///
         (count) n_miembros = cod_inec_ci_actual, by(id_fam_nuclear)
label var n_miembros "personas en la familia nuclear"
label var yob_min    "ano de nacimiento del miembro mas viejo"
label var yob_max    "ano de nacimiento del miembro mas joven"
sort id_fam_nuclear
compress
save "$ced/familias_nucleares.dta", replace
di as res "saved: $ced/familias_nucleares.dta  (" _N " families)"

use "$ced/cedulados_familias.dta", clear
collapse (first) `din' (max) fe_tam fe_n_fam fe_n_gen fe_n_vivos ///
         (min) yob_min = yob (max) yob_max = yob                 ///
         (count) n_miembros = cod_inec_ci_actual, by(id_fam_extendida)
label var n_miembros "personas en la familia extendida"
sort id_fam_extendida
compress
save "$ced/familias_extendidas.dta", replace
di as res "saved: $ced/familias_extendidas.dta  (" _N " families)"

timer off 1
qui timer list 1
di as res _n "build_familias.do done in " %6.1f r(t1) " seconds"

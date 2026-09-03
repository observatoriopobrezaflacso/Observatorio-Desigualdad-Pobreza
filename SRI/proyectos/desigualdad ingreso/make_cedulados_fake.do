********************************************************************************
*  make_cedulados_fake.do
*  ---------------------------------------------------------------------------
*  Synthetic replica of
*      Bases/Bases INEC/Cedulados/dta/cedulados_full.dta
*  built from the statistical specification in
*      G:/Mi unidad/Trabajos/Predoc/data/descriptives/cedulados_full.yaml
*      (23 variables, n_original = 21,757,803)
*
*  WHY THIS IS NOT A PLAIN MARGINAL DRAW
*  -------------------------------------
*  cedulados is a *relational* file: cod_inec_ci_padre, cod_inec_ci_madre and
*  cod_inec_ci_conyugue point at other rows of the same file.  Drawing those
*  three columns independently from their yaml marginals - which is all the
*  yaml by itself supports - produces a file in which not one single family can
*  be reconstructed: every "father" id is a random number that either matches
*  nobody or matches somebody younger than the child.
*
*  So the backbone here is a genealogy simulated FORWARD in time (assortative
*  mating, age-specific fertility, serial unions, six generations), and the
*  yaml marginals are then imposed ON TOP of it:
*    - the link columns are CENSORED (0 = "no relative on file") until the
*      share of zeros and of missings matches the yaml;
*    - the non-relational columns are drawn to the yaml's categorical
*      probabilities / quantiles.
*  The result satisfies the yaml AND is internally consistent, so
*  build_familias.do has something real to recover.
*
*  PATHOLOGIES DELIBERATELY BUILT IN (each one exercises a code path in
*  build_familias.do; every one of them exists in the real file)
*  ---------------------------------------------------------------------------
*   P01  35% of father links and 32% of mother links are 0 ("not on file")
*   P02  6.7% / 7.0% / 8.5% of padre / madre / conyugue links are MISSING (.)
*   P03  dangling links: ~1.2% of parent ids match no row of the file
*   P04  self-parenthood: rows with cod_inec_ci_padre == cod_inec_ci_actual
*   P05  age-impossible parents: parent younger than, or <12y older than, child
*   P06  sex-inconsistent links: "father" flagged female, "mother" flagged male
*   P07  non-reciprocal spouse links (A -> B but B -> C or B -> 0)
*   P08  self-spouse
*   P09  same-sex spouse pairs
*   P10  one person listed as spouse by several people
*   P11  two-cycles: A is parent of B and B is parent of A
*   P12  anomalous ids in the 8.8e9 range (the yaml max), incl. as parent ids
*   P13  parents with children by more than one partner (serial unions)
*   P14  yob outliers down to 1800 -> age2023 up to 223
*   P15  dates out of order: dod < dob, dom < dob, drb < dob
*   P16  censored middle generations: grandparent link survives, parent link 0
*   P17  a large block of the population with no ancestry at all on file, i.e.
*        2-3 generation families with no grandparents anywhere
*
*  OUTPUT
*  ------
*   $ced/cedulados_full.dta       23 variables, yaml order, yaml labels/formats
*   $ced/_cedulados_truth.dta     simulated ground truth (NOT part of the
*                                 synthetic base; validate_familias.do only)
********************************************************************************

clear all
set more off
set seed 20260903
set type double

global fake "G:/Mi unidad/Trabajos/Predoc/data/fake_data"
global ced  "$fake/Bases/Bases INEC/Cedulados/dta"
global tmp  "$fake/Bases/bases_temp"

cap mkdir "$fake/Bases"
cap mkdir "$fake/Bases/Bases INEC"
cap mkdir "$fake/Bases/Bases INEC/Cedulados"
cap mkdir "$ced"
cap mkdir "$tmp"

timer clear 1
timer on 1

********************************************************************************
* 1. GENEALOGICAL BACKBONE
********************************************************************************
* Two blocks.
*   block 1 - deep ancestry: 9,000 founders born 1878-1912, five rounds of
*             reproduction -> six generations.  This is what makes
*             grandparents, great-grandparents, cousins and dynasties exist.
*   block 2 - shallow ancestry (pathology P17): 40,000 founders born 1955-1992,
*             two rounds -> three generations, no older ancestry anywhere on
*             file.  This is the mass of the real registry: people whose
*             parents never held a cedula.  It also pulls the yob distribution
*             towards the young shape the yaml shows.

*--- empty accumulators --------------------------------------------------------
clear
set obs 1
gen long pid            = .
gen byte blk            = .
gen byte gen_true       = .
gen int  yob            = .
gen byte female         = .
gen long pid_padre_true = .
gen long pid_madre_true = .
gen long union_nac_true = .
drop in 1
save "$tmp/_pop.dta", replace

clear
set obs 1
gen long union_id = .
gen long pid_h    = .
gen long pid_w    = .
gen byte tipo     = .
gen byte gen_true = .
gen byte blk      = .
drop in 1
save "$tmp/_unions.dta", replace

local nextpid   = 0
local nextunion = 0

forvalues b = 1/2 {

    if `b' == 1 {
        local nfound 6000
        local lo     1888
        local hi     1920
        local rounds 5
        local fert  "5.0  4.6  4.0  3.2  2.4"
        local crate "0.85 0.82 0.80 0.76 0.62"
        local chldl "0.05 0.06 0.07 0.09 0.14"
    }
    else {
        local nfound 78000
        local lo     1958
        local hi     1995
        local rounds 2
        local fert  "2.4  1.6"
        local crate "0.80 0.50"
        local chldl "0.10 0.20"
    }

    *---------------------------- founders -------------------------------------
    clear
    qui set obs `nfound'
    gen long pid = `nextpid' + _n
    local nextpid = `nextpid' + _N
    gen byte blk      = `b'
    gen byte gen_true = 0
    gen int  yob      = `lo' + int(runiform()*(`hi' - `lo' + 1))
    * P14: a thin tail of implausibly old records (the yaml min yob is 1800)
    if `b' == 1 qui replace yob = 1800 + int(runiform()*88) if runiform() < 0.004
    gen byte female = runiform() < 0.502
    gen long pid_padre_true = .
    gen long pid_madre_true = .
    gen long union_nac_true = .
    append using "$tmp/_pop.dta"
    save "$tmp/_pop.dta", replace

    *---------------------------- reproduction rounds --------------------------
    local lastround = `rounds' - 1
    forvalues t = 0/`lastround' {

        local j  = `t' + 1
        local fe : word `j' of `fert'
        local cr : word `j' of `crate'
        local cl : word `j' of `chldl'
        local tn = `t' + 1

        di as txt _n "-- block `b': generation `t' -> `tn'   (fertility `fe', couple rate `cr')"

        use "$tmp/_pop.dta", clear
        qui keep if blk == `b' & gen_true == `t'
        qui count
        if r(N) < 50 continue
        keep pid yob female

        * assortative mating: rank men and women on yob plus noise and pair by
        * rank, so spousal age gaps are small but not zero
        gen double sk = yob + rnormal(0, 3)
        qui save "$tmp/_gen.dta", replace

        qui keep if female == 0
        sort sk pid
        gen long k = _n
        rename pid pid_h
        rename yob yob_h
        keep pid_h yob_h k
        qui save "$tmp/_m.dta", replace

        use "$tmp/_gen.dta", clear
        qui keep if female == 1
        sort sk pid
        gen long k = _n
        rename pid pid_w
        rename yob yob_w
        keep pid_w yob_w k
        qui merge 1:1 k using "$tmp/_m.dta", keep(match) nogen
        drop k
        qui keep if runiform() < `cr'
        gen byte tipo = 1
        qui save "$tmp/_u1.dta", replace

        * P13 - serial unions: re-pair a random 12% of the generation at random
        * (not assortatively).  People already in a primary union who turn up
        * here end up with children by two different partners, which is exactly
        * what makes the "primary union" rule in build_familias.do necessary.
        use "$tmp/_gen.dta", clear
        qui keep if runiform() < 0.12
        gen double rr = runiform()
        qui save "$tmp/_gen2.dta", replace
        qui keep if female == 0
        sort rr pid
        gen long k = _n
        rename pid pid_h
        rename yob yob_h
        keep pid_h yob_h k
        qui save "$tmp/_m2.dta", replace
        use "$tmp/_gen2.dta", clear
        qui keep if female == 1
        sort rr pid
        gen long k = _n
        rename pid pid_w
        rename yob yob_w
        keep pid_w yob_w k
        qui merge 1:1 k using "$tmp/_m2.dta", keep(match) nogen
        drop k
        gen byte tipo = 2

        append using "$tmp/_u1.dta"
        qui drop if pid_h == pid_w
        gen long union_id = `nextunion' + _n
        local nextunion = `nextunion' + _N

        * every union, fertile or not, is a couple on file
        preserve
            gen byte gen_true = `t'
            gen byte blk      = `b'
            keep union_id pid_h pid_w tipo gen_true blk
            append using "$tmp/_unions.dta"
            qui save "$tmp/_unions.dta", replace
        restore

        *------------------------- births --------------------------------------
        gen int nk = rpoisson(`fe')
        qui replace nk = rpoisson(`fe'*0.45) if tipo == 2
        qui replace nk = 0 if runiform() < `cl'
        qui keep if nk > 0 & nk < .
        qui expand nk

        * maternal age 17-45, children of one union spaced at least a year apart
        gen int agem = 17 + int(rgamma(4, 2.3))
        qui replace agem = 45 if agem > 45
        bysort union_id (agem): replace agem = agem[_n-1] + 1 if _n > 1 & agem <= agem[_n-1]
        gen int yob_c = yob_w + agem
        qui replace yob_c = yob_h + 15 if yob_c - yob_h < 15
        qui drop if yob_c > 2023

        qui count
        if r(N) == 0 continue

        gen long pid = `nextpid' + _n
        local nextpid = `nextpid' + _N
        gen byte female   = runiform() < 0.502
        gen byte blk      = `b'
        gen byte gen_true = `tn'
        rename pid_h  pid_padre_true
        rename pid_w  pid_madre_true
        rename union_id union_nac_true
        rename yob_c  yob
        keep pid blk gen_true yob female pid_padre_true pid_madre_true union_nac_true
        append using "$tmp/_pop.dta"
        qui save "$tmp/_pop.dta", replace
        qui count
        di as res "   births kept: " %9.0fc r(N)
    }
}

use "$tmp/_pop.dta", clear
di as txt _n "=== simulated population by block and generation ==="
tab gen_true blk
di as txt _n "yob by generation"
tabstat yob, by(gen_true) stat(n mean min max) format(%9.0f)


********************************************************************************
* 2. TRUE PARTNER (for cod_inec_ci_conyugue) AND CHILD COUNTS
********************************************************************************
* A person can sit in several unions (P13).  The primary partner is the one
* from the assortative (tipo==1) union; ties broken by the lowest union id.

use "$tmp/_unions.dta", clear
qui expand 2
bysort union_id: gen byte side = _n
gen long pid     = cond(side == 1, pid_h, pid_w)
gen long pid_par = cond(side == 1, pid_w, pid_h)
keep pid pid_par tipo union_id
bysort pid: gen byte n_uniones_true = _N
bysort pid (tipo union_id): keep if _n == 1
rename pid_par pid_conyuge_true
keep pid pid_conyuge_true n_uniones_true
qui save "$tmp/_partner.dta", replace

use "$tmp/_pop.dta", clear
qui merge 1:1 pid using "$tmp/_partner.dta", nogen
qui replace n_uniones_true = 0 if mi(n_uniones_true)

* true number of own children (used only by validate_familias.do)
preserve
    keep pid pid_padre_true pid_madre_true
    qui expand 2
    bysort pid: gen byte side = _n
    gen long parent = cond(side == 1, pid_padre_true, pid_madre_true)
    qui keep if !mi(parent)
    contract parent
    rename parent pid
    rename _freq n_hijos_true
    qui save "$tmp/_nhijos.dta", replace
restore
qui merge 1:1 pid using "$tmp/_nhijos.dta", nogen
qui replace n_hijos_true = 0 if mi(n_hijos_true)

qui save "$tmp/_pop.dta", replace
di as txt _n "true children per person"
tabstat n_hijos_true, stat(n mean p50 max) format(%9.2f)
count if n_uniones_true > 1
di as res "people with more than one union (P13): " r(N)


********************************************************************************
* 3. CEDULA IDS
********************************************************************************
* In the real file cod_inec_ci_actual is a numeric surrogate key, not a real
* cedula: 21.8m unique values packed into [1.0000633e9, 1.032e9] with a handful
* of anomalies at 8.8e9.  Reproduced by inverting the yaml quantile function on
* a rank grid (so ids are unique by construction) and then permuting the
* assignment, so that the id carries NO information about generation or age -
* build_familias.do must not be able to lean on id ordering.

use "$tmp/_pop.dta", clear
qui count
local NP = r(N)
di as res "population: " %12.0fc `NP'

gen double rr = runiform()
sort rr pid
drop rr
gen long row = _n

qui gen double pp = (_n - 0.5)/_N
gen double cedula = .
local ps "0     .01        .05        .25        .50        .75        .95        .99        1"
local qs "1000063300 1010217400 1011087700 1015587900 1021132600 1026708900 1031117200 1031992500 1032100000"
forvalues s = 1/8 {
    local s2 = `s' + 1
    local p1 : word `s'  of `ps'
    local p2 : word `s2' of `ps'
    local q1 : word `s'  of `qs'
    local q2 : word `s2' of `qs'
    qui replace cedula = `q1' + (`q2' - `q1')*(pp - `p1')/(`p2' - `p1') if pp > `p1' & pp <= `p2'
}
qui replace cedula = 1000063300 if mi(cedula)
qui replace cedula = round(cedula)

* P12 - anomalous ids at the top of the range (yaml max 8.800069e9)
qui replace cedula = 8800044000 + row if row <= 30

qui isid cedula
rename cedula cod_inec_ci_actual
drop pp row

* map the genealogy from internal pid onto cedulas -----------------------------
preserve
    keep pid cod_inec_ci_actual
    rename pid pid_padre_true
    rename cod_inec_ci_actual ci_padre_true
    qui save "$tmp/_map_p.dta", replace
    rename pid_padre_true pid_madre_true
    rename ci_padre_true  ci_madre_true
    qui save "$tmp/_map_m.dta", replace
    rename pid_madre_true pid_conyuge_true
    rename ci_madre_true  ci_conyuge_true
    qui save "$tmp/_map_c.dta", replace
restore

qui merge m:1 pid_padre_true   using "$tmp/_map_p.dta", keep(master match) nogen
qui merge m:1 pid_madre_true   using "$tmp/_map_m.dta", keep(master match) nogen
qui merge m:1 pid_conyuge_true using "$tmp/_map_c.dta", keep(master match) nogen

qui save "$tmp/_pop.dta", replace


********************************************************************************
* 4. NON-RELATIONAL VARIABLES, DRAWN TO THE YAML
********************************************************************************

use "$tmp/_pop.dta", clear

*------------------------------------------------------------------------------
* 4.1  age2023
*------------------------------------------------------------------------------
gen int age2023 = 2023 - yob

*------------------------------------------------------------------------------
* 4.2  female  (yaml: mean 0.490532)  -- already generated at 0.502 male share
*------------------------------------------------------------------------------
qui replace female = runiform() < 0.4905 if runiform() < 0.02   // small reshuffle

*------------------------------------------------------------------------------
* 4.3  cod_condicion_cedulado  (76 categories, yaml category_probs verbatim)
*------------------------------------------------------------------------------
local ccats  "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 58 59 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78"
local cprobs ".5643234 .0018682 .001607 .0083145 .0011329 .2072649 .0169285 .0967419 .006341 .0001201 .0001071 .0014801 .0011832 .000121 .006295 .0365206 .0033286 .0003776 .0005698 .0003738 .000435 .0007452 4.136447e-07 2.7576314e-07 2.022263e-06 1.7510959e-05 .0002918 .0020737 1.3006828e-05 1.1903775e-05 1.406392e-05 1.057092e-06 9.1921046e-08 .0053852 .022457 .0005004 9.1921046e-08 .000625 .0007413 .0002247 7.1698416e-06 2.6657103e-05 .0001163 4.5960523e-08 1.3788157e-07 9.1921046e-08 3.6768418e-07 9.6517098e-07 9.1921046e-07 .0006154 7.3536836e-07 2.5829814e-05 2.2980261e-07 7.647831e-05 1.6545788e-06 9.1921046e-08 .0030115 1.9763025e-06 6.8940784e-07 2.0912038e-05 3.1253155e-06 2.2980261e-07 6.4344732e-07 4.8258549e-06 .001614 .0004341 1.2225499e-05 2.7576314e-07 .0010259 3.957201e-05 .0010396 6.3747245e-05 8.7370954e-05 6.6183153e-06 .0001463 .0030746"

gen double u_cc = runiform()
gen byte cod_condicion_cedulado = .
local ncc : word count `ccats'
local cum = 0
forvalues s = 1/`ncc' {
    local cc : word `s' of `ccats'
    local pp : word `s' of `cprobs'
    local cum = `cum' + `pp'
    qui replace cod_condicion_cedulado = `cc' if mi(cod_condicion_cedulado) & u_cc < `cum'
}
qui replace cod_condicion_cedulado = 0 if mi(cod_condicion_cedulado)
drop u_cc

*------------------------------------------------------------------------------
* 4.4  cod_estado_civil  (yaml category_probs) and the marriage-on-file flag
*------------------------------------------------------------------------------
* ever-married-on-file = estado civil 2/3/4/5 = 25.78+4.43+3.33+0.29 = 33.83%.
* Confined to people who reached 16, and made much more likely for people who
* really are in a simulated union - so the spouse link and the civil status
* agree with each other, as they do in the registry.
gen byte elegible_mat = age2023 >= 16 & yob <= 2007
gen double score_mat = runiform() + 0.55*(n_uniones_true > 0)
qui sum elegible_mat, meanonly
local share_el = r(mean)
local need = 0.3383/`share_el'
if `need' > 0.99 local need 0.99
local pctcut = 100*(1 - `need')
qui _pctile score_mat if elegible_mat, p(`pctcut')
local cut = r(r1)
gen byte mat_registrado = elegible_mat & score_mat > `cut'
drop score_mat elegible_mat

gen byte cod_estado_civil = 1
gen double u_ec = runiform()
qui replace cod_estado_civil = 2 if mat_registrado & u_ec <  .7620
qui replace cod_estado_civil = 3 if mat_registrado & u_ec >= .7620 & u_ec < .8929
qui replace cod_estado_civil = 4 if mat_registrado & u_ec >= .8929 & u_ec < .9913
qui replace cod_estado_civil = 5 if mat_registrado & u_ec >= .9913
qui replace cod_estado_civil = 99 if runiform() < 1.4e-06
drop u_ec

*------------------------------------------------------------------------------
* 4.5  cod_instruccion  (yaml category_probs, then capped by age)
*------------------------------------------------------------------------------
local icats  "0 2 3 4 6 9 11 13 99"
local iprobs ".2327042 .0564598 .0254833 .0494491 .2797074 .2523411 .1035531 .0003003 1.7464999e-06"
gen double u_in = runiform()
gen byte cod_instruccion = .
local nic : word count `icats'
local cum = 0
forvalues s = 1/`nic' {
    local cc : word `s' of `icats'
    local pp : word `s' of `iprobs'
    local cum = `cum' + `pp'
    qui replace cod_instruccion = `cc' if mi(cod_instruccion) & u_in < `cum'
}
qui replace cod_instruccion = 0 if mi(cod_instruccion)
drop u_in
* a five-year-old cannot hold a doctorate
qui replace cod_instruccion = 0 if age2023 <  5  & cod_instruccion != 99
qui replace cod_instruccion = 2 if age2023 <  10 & cod_instruccion > 2  & cod_instruccion != 99
qui replace cod_instruccion = 3 if age2023 <  15 & cod_instruccion > 3  & cod_instruccion != 99
qui replace cod_instruccion = 4 if age2023 <  18 & cod_instruccion > 4  & cod_instruccion != 99

*------------------------------------------------------------------------------
* 4.6  cod_nacionalidad / cod_nacionalidad_conyuge  (239 = Ecuador)
*------------------------------------------------------------------------------
gen int cod_nacionalidad = 239
qui replace cod_nacionalidad = 1 + int(runiform()*999) if runiform() < 0.045

*------------------------------------------------------------------------------
* 4.7  DPA geography: cod_lugar_nacimiento, _insc_nacimiento, cod_domicilio
*------------------------------------------------------------------------------
* Codes are prov*10000 + canton*100 + parish, with 888888 = abroad and
* 999999 = unknown, as in the DPA.  Province probabilities are chosen to hit
* the yaml quantiles (25% = 80650, 50% = 110101, 75% = 170107, 95% = 230251,
* 99% = 888888); canton counts are the real ones; parish codes use the DPA
* convention of 01-49 urban and 50+ rural.
* Children are born where their parents were born 70% of the time, so
* geography is correlated within families - which is what makes it usable as
* a family-level covariate later on.

local ncant "15 7 7 6 7 10 14 8 25 6 16 13 22 12 5 4 8 9 9 3 7 4 2 3"
local pprob ".055 .0307 .0307 .0307 .0307 .0307 .0307 .0307 .150 .020 .080 .020 .020 .020 .020 .020 .150 .0308 .0308 .0308 .0308 .0308 .0308 .003"
local parr  "1 2 3 6 7 50 51"

gen double u_pr = runiform()
gen int prov = .
local cum = 0
forvalues s = 1/24 {
    local pp : word `s' of `pprob'
    local cum = `cum' + `pp'
    qui replace prov = `s' if mi(prov) & u_pr < `cum'
}
qui replace prov = 9 if mi(prov)
gen int cant = .
forvalues s = 1/24 {
    local nc : word `s' of `ncant'
    qui replace cant = 1 + int(runiform()*`nc') if prov == `s'
}
local npar : word count `parr'
gen int parr = .
gen double u_pa = runiform()
forvalues s = 1/`npar' {
    local pv : word `s' of `parr'
    qui replace parr = `pv' if mi(parr) & u_pa < `s'/`npar'
}
qui replace parr = 1 if mi(parr)

gen long cod_lugar_nacimiento = prov*10000 + cant*100 + parr
qui replace cod_lugar_nacimiento = 888888 if u_pr >= 0.958 & u_pr < 0.994
qui replace cod_lugar_nacimiento = 999999 if u_pr >= 0.994
drop prov cant parr u_pr u_pa

* inherit the parents' birthplace 70% of the time
qui save "$tmp/_pop2.dta", replace
preserve
    keep cod_inec_ci_actual cod_lugar_nacimiento
    rename cod_inec_ci_actual ci_padre_true
    rename cod_lugar_nacimiento lug_padre
    qui save "$tmp/_lug_p.dta", replace
restore
qui merge m:1 ci_padre_true using "$tmp/_lug_p.dta", keep(master match) nogen
qui replace cod_lugar_nacimiento = lug_padre if !mi(lug_padre) & lug_padre < 888888 & runiform() < 0.70
drop lug_padre

* place of birth registration: same parish 88% of the time, neighbouring
* canton otherwise; 0.1436% missing per the yaml
gen long cod_lugar_insc_nacimiento = cod_lugar_nacimiento
qui replace cod_lugar_insc_nacimiento = ///
    int(cod_lugar_nacimiento/10000)*10000 + (1 + int(runiform()*6))*100 + ///
    cod_lugar_nacimiento - int(cod_lugar_nacimiento/100)*100 ///
    if runiform() < 0.12 & cod_lugar_nacimiento < 888888
qui replace cod_lugar_insc_nacimiento = 888888 if cod_lugar_nacimiento == 888888 & runiform() < 0.5
qui replace cod_lugar_insc_nacimiento = . if runiform() < 0.001436

* domicile: 60% still in the parish of birth, else Guayas/Pichincha pull
gen long cod_domicilio = cod_lugar_nacimiento
qui replace cod_domicilio = 90000 + (1 + int(runiform()*25))*100 + 1 + int(runiform()*3) ///
    if runiform() < 0.22
qui replace cod_domicilio = 170000 + (1 + int(runiform()*8))*100 + 1 + int(runiform()*3) ///
    if runiform() < 0.22
qui replace cod_domicilio = . if runiform() < 0.048797

*------------------------------------------------------------------------------
* 4.8  yod / dod  (yaml: 9.6746% of records carry a death date)
*------------------------------------------------------------------------------
gen double pd_lat = invlogit(-6.2 + 0.075*age2023)
gen double u_d = runiform()
gen byte muerto = u_d < pd_lat
* calibrate the share to the yaml exactly
qui sum muerto, meanonly
local cur = r(mean)
local tgt = 1 - 0.903254
if `cur' > `tgt' {
    local drop = (`cur' - `tgt')/`cur'
    qui replace muerto = 0 if muerto & runiform() < `drop'
}
else {
    local add = (`tgt' - `cur')/(1 - `cur')
    qui replace muerto = 1 if !muerto & runiform() < `add'
}
drop pd_lat u_d

* yod from its own yaml quantile function
gen double pp = runiform()
gen int yod = .
local ps "0    .01  .05  .25  .50  .75  .95  .99  1"
local qs "1900 1971 1981 1997 2009 2017 2022 2023 2023"
forvalues s = 1/8 {
    local s2 = `s' + 1
    local p1 : word `s'  of `ps'
    local p2 : word `s2' of `ps'
    local q1 : word `s'  of `qs'
    local q2 : word `s2' of `qs'
    qui replace yod = round(`q1' + (`q2' - `q1')*(pp - `p1')/(`p2' - `p1')) if pp > `p1' & pp <= `p2'
}
qui replace yod = 2009 if mi(yod)
* a death year must follow the birth year, and cannot be in the future
qui replace yod = yob + 1 + int(runiform()*(2024 - yob - 1)) if yod < yob & yob < 2023
qui replace yod = 2023 if yod > 2023
qui replace yod = 2023 if yod < yob
qui replace yod = . if !muerto
drop pp

*------------------------------------------------------------------------------
* 4.9  yom / dom  (yaml: 28.06% of records carry a marriage date)
*------------------------------------------------------------------------------
gen double pp = runiform()
gen int yom = .
local ps "0    .01  .05  .25  .50  .75  .95  .99  1"
local qs "1900 1955 1970 1987 1999 2010 2020 2022 2023"
forvalues s = 1/8 {
    local s2 = `s' + 1
    local p1 : word `s'  of `ps'
    local p2 : word `s2' of `ps'
    local q1 : word `s'  of `qs'
    local q2 : word `s2' of `qs'
    qui replace yom = round(`q1' + (`q2' - `q1')*(pp - `p1')/(`p2' - `p1')) if pp > `p1' & pp <= `p2'
}
qui replace yom = 1999 if mi(yom)
qui replace yom = yob + 18 + int(runiform()*22) if yom < yob + 16
qui replace yom = 2023 if yom > 2023
qui replace yom = . if yom < yob + 16
* only 83% of the ever-married carry a date (0.3383 * 0.83 = 0.281 = yaml)
qui replace yom = . if !mat_registrado | runiform() > 0.83
drop pp

*------------------------------------------------------------------------------
* 4.10  the five date variables
*------------------------------------------------------------------------------
gen int dob = mdy(1 + int(runiform()*12), 1 + int(runiform()*28), yob)
gen int dod = mdy(1 + int(runiform()*12), 1 + int(runiform()*28), yod) if !mi(yod)
qui replace dod = dob + 1 + int(runiform()*300) if !mi(dod) & dod <= dob
gen int dom = mdy(1 + int(runiform()*12), 1 + int(runiform()*28), yom) if !mi(yom)

* drb / drm: the date the birth / marriage was keyed into the registry.
* yaml: 16.4796% and 9.8554% non-missing.
gen int drb = dob + int(runiform()*365*8) if runiform() < 0.1720
gen int drm = dom + int(runiform()*365*6) if !mi(dom) & runiform() < 0.4400
qui replace drb = . if drb > mdy(12,31,2023)
qui replace drm = . if drm > mdy(12,31,2023)

* P15 - dates out of order, as in the real file
qui replace dod = dob - 1 - int(runiform()*400) if !mi(dod) & runiform() < 0.0008
qui replace dom = dob - 1 - int(runiform()*900) if !mi(dom) & runiform() < 0.0006
qui replace drb = dob - 1 - int(runiform()*200) if !mi(drb) & runiform() < 0.0010

qui save "$tmp/_pop2.dta", replace


********************************************************************************
* 5. THE THREE LINK COLUMNS: CENSORING AND ERRORS
********************************************************************************

use "$tmp/_pop2.dta", clear

gen double cod_inec_ci_padre    = ci_padre_true
gen double cod_inec_ci_madre    = ci_madre_true
gen double cod_inec_ci_conyugue = ci_conyuge_true

qui replace cod_inec_ci_padre    = 0 if mi(cod_inec_ci_padre)
qui replace cod_inec_ci_madre    = 0 if mi(cod_inec_ci_madre)
qui replace cod_inec_ci_conyugue = 0 if mi(cod_inec_ci_conyugue)

*------------------------------------------------------------------------------
* 5.1  P16 - registry coverage of the parent link falls with the birth cohort
*------------------------------------------------------------------------------
* Older cohorts had no civil-registry parent field at all; the drop is applied
* independently to father and mother, so single-parent-looking records appear
* naturally, and it is applied independently of the grandparent link, so
* skip-generation records appear too.
gen double pz = .
qui replace pz = 0.78 if yob <  1950
qui replace pz = 0.46 if yob >= 1950 & yob < 1980
qui replace pz = 0.20 if yob >= 1980 & yob < 2000
qui replace pz = 0.07 if yob >= 2000
qui replace cod_inec_ci_padre = 0 if runiform() < pz
qui replace cod_inec_ci_madre = 0 if runiform() < pz*0.90
drop pz

* Calibrate the zero share to the yaml (father 35%, mother 32%).  Two-sided:
* if the cohort rule censored too much, links are put back from the truth
* until the share matches.  Founders have no true parent at all, so the share
* of zeros can never fall below their population share - reported below.
foreach v in padre madre {
    if "`v'" == "padre" local tgt 0.350
    else                local tgt 0.320
    qui count if cod_inec_ci_`v' == 0 & mi(ci_`v'_true)
    local floor = r(N)/_N
    qui count if cod_inec_ci_`v' == 0
    local cur = r(N)/_N
    if `cur' < `tgt' {
        local add = (`tgt' - `cur')/(1 - `cur')
        qui replace cod_inec_ci_`v' = 0 if cod_inec_ci_`v' > 0 & runiform() < `add'
    }
    else if `cur' > `tgt' {
        qui count if cod_inec_ci_`v' == 0 & !mi(ci_`v'_true)
        local restorable = r(N)/_N
        if `restorable' > 0 {
            local prest = min(1, (`cur' - `tgt')/`restorable')
            qui replace cod_inec_ci_`v' = ci_`v'_true ///
                if cod_inec_ci_`v' == 0 & !mi(ci_`v'_true) & runiform() < `prest'
        }
    }
    qui count if cod_inec_ci_`v' == 0
    di as txt "  zeros in cod_inec_ci_`v': " as res %6.4f r(N)/_N ///
       as txt "   target " as res %6.4f `tgt' as txt "   structural floor " as res %6.4f `floor'
}

*------------------------------------------------------------------------------
* 5.2  the spouse link: only marriages actually keyed in are on file
*------------------------------------------------------------------------------
* yaml: 76.14% of non-missing cod_inec_ci_conyugue are 0.
qui replace cod_inec_ci_conyugue = 0 if !mat_registrado
qui count if cod_inec_ci_conyugue == 0
local cur = r(N)/_N
local tgt 0.7614
if `cur' < `tgt' {
    local add = (`tgt' - `cur')/(1 - `cur')
    qui replace cod_inec_ci_conyugue = 0 if cod_inec_ci_conyugue > 0 & runiform() < `add'
}

* nationality of the spouse is only keyed in when the spouse is on file
gen int cod_nacionalidad_conyuge = .
qui replace cod_nacionalidad_conyuge = 239 if cod_inec_ci_conyugue > 0 & runiform() < 0.695
qui replace cod_nacionalidad_conyuge = 1 + int(runiform()*999) ///
    if !mi(cod_nacionalidad_conyuge) & runiform() < 0.045

* foreign spouse held on a passport instead of a cedula: 24 upper-case chars
gen str24 cod_inec_ci_pas_conyugue = ""
gen byte haspas = mat_registrado & cod_inec_ci_conyugue == 0 & runiform() < 0.0035
local CS "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
forvalues c = 1/24 {
    qui replace cod_inec_ci_pas_conyugue = ///
        cod_inec_ci_pas_conyugue + substr("`CS'", 1 + int(runiform()*36), 1) if haspas
}
drop haspas

*------------------------------------------------------------------------------
* 5.3  P03-P11: the dirty links
*------------------------------------------------------------------------------
qui sum cod_inec_ci_actual, meanonly
local ci_min = r(min)
local ci_max = r(max)

* P03 dangling: point at an id that is inside the range but not in the file.
* The ids sit on a grid of ~130, so +7 is guaranteed to miss.
qui replace cod_inec_ci_padre = cod_inec_ci_padre + 7 if cod_inec_ci_padre > 0 & runiform() < 0.012
qui replace cod_inec_ci_madre = cod_inec_ci_madre + 7 if cod_inec_ci_madre > 0 & runiform() < 0.012
qui replace cod_inec_ci_conyugue = cod_inec_ci_conyugue + 7 if cod_inec_ci_conyugue > 0 & runiform() < 0.008

* P04 self-parenthood
qui replace cod_inec_ci_padre = cod_inec_ci_actual if runiform() < 0.00006
qui replace cod_inec_ci_madre = cod_inec_ci_actual if runiform() < 0.00004

* P08 self-spouse
qui replace cod_inec_ci_conyugue = cod_inec_ci_actual if cod_inec_ci_conyugue > 0 & runiform() < 0.0004

* P05 age-impossible parent: swap in the id of somebody born after the child
gen double rnd_ci = .
qui replace rnd_ci = cod_inec_ci_actual[1 + int(runiform()*_N)] if runiform() < 0.006
qui replace cod_inec_ci_padre = rnd_ci if !mi(rnd_ci) & cod_inec_ci_padre > 0 & runiform() < 0.5
qui replace cod_inec_ci_madre = rnd_ci if !mi(rnd_ci) & cod_inec_ci_madre > 0 & runiform() < 0.5
drop rnd_ci

* P07/P09/P10 spouse-link errors: repoint some spouse links at a random person,
* which simultaneously breaks reciprocity, creates same-sex pairs and makes a
* few people the declared spouse of several others
gen double rnd_sp = .
qui replace rnd_sp = cod_inec_ci_actual[1 + int(runiform()*_N)] if runiform() < 0.02
qui replace cod_inec_ci_conyugue = rnd_sp if !mi(rnd_sp) & cod_inec_ci_conyugue > 0
drop rnd_sp

* P02 missing (.) on top of everything: the yaml missing_prop
qui replace cod_inec_ci_padre    = . if runiform() < 0.067338
qui replace cod_inec_ci_madre    = . if runiform() < 0.069927
qui replace cod_inec_ci_conyugue = . if runiform() < 0.085260

* P11 two-cycles: make 10 parent-child pairs mutually parental, i.e. the child
* is recorded as the mother of its own father
preserve
    keep cod_inec_ci_actual cod_inec_ci_padre
    qui keep if !mi(cod_inec_ci_padre) & cod_inec_ci_padre > 0
    gen double rr = runiform()
    sort rr cod_inec_ci_actual
    qui keep in 1/10
    rename cod_inec_ci_actual hijo_ciclo
    rename cod_inec_ci_padre  cod_inec_ci_actual
    keep cod_inec_ci_actual hijo_ciclo
    qui duplicates drop cod_inec_ci_actual, force
    qui save "$tmp/_cyc.dta", replace
restore
qui merge 1:1 cod_inec_ci_actual using "$tmp/_cyc.dta", keep(master match) nogen
qui replace cod_inec_ci_madre = hijo_ciclo if !mi(hijo_ciclo)
drop hijo_ciclo

qui save "$tmp/_pop3.dta", replace


********************************************************************************
* 6. FINAL FILE: yaml variable order, labels and formats
********************************************************************************

use "$tmp/_pop3.dta", clear

* ---- the ground truth goes to its own file, not into the synthetic base ----
preserve
    keep cod_inec_ci_actual pid blk gen_true yob female ///
         pid_padre_true pid_madre_true pid_conyuge_true ///
         ci_padre_true ci_madre_true ci_conyuge_true ///
         union_nac_true n_uniones_true n_hijos_true mat_registrado
    label var gen_true       "true simulated generation (0 = founder)"
    label var union_nac_true "true union the person was born into"
    label var n_hijos_true   "true number of own children"
    label var ci_padre_true  "true father cedula, before censoring"
    label var ci_madre_true  "true mother cedula, before censoring"
    label var ci_conyuge_true "true partner cedula, before censoring"
    label var blk            "1 = deep ancestry block, 2 = shallow (P17)"
    order cod_inec_ci_actual pid blk gen_true
    sort cod_inec_ci_actual
    compress
    save "$ced/_cedulados_truth.dta", replace
    di as res _n "ground truth saved: $ced/_cedulados_truth.dta"
restore

keep cod_inec_ci_actual cod_condicion_cedulado cod_lugar_nacimiento         ///
     cod_lugar_insc_nacimiento cod_nacionalidad cod_estado_civil            ///
     cod_instruccion cod_domicilio cod_inec_ci_padre cod_inec_ci_madre      ///
     cod_inec_ci_conyugue cod_inec_ci_pas_conyugue cod_nacionalidad_conyuge ///
     female dob dod dom yob yod yom age2023 drb drm

order cod_inec_ci_actual cod_condicion_cedulado cod_lugar_nacimiento        ///
      cod_lugar_insc_nacimiento cod_nacionalidad cod_estado_civil           ///
      cod_instruccion cod_domicilio cod_inec_ci_padre cod_inec_ci_madre     ///
      cod_inec_ci_conyugue cod_inec_ci_pas_conyugue cod_nacionalidad_conyuge ///
      female dob dod dom yob yod yom age2023 drb drm

label var cod_inec_ci_actual       "ID national"
label var cod_condicion_cedulado   "ID condition code"
label var cod_lugar_nacimiento     "place of birth code"
label var cod_lugar_insc_nacimiento "birth registration code"
label var cod_nacionalidad         "nationality code"
label var cod_estado_civil         "civil status code"
label var cod_instruccion          "instruction code"
label var cod_domicilio            "address code"
label var cod_inec_ci_padre        "ID father"
label var cod_inec_ci_madre        "ID mother"
label var cod_inec_ci_conyugue     "ID spouse"
label var cod_inec_ci_pas_conyugue "ID Intl' spouse'"
label var cod_nacionalidad_conyuge "nationality code, spouse"
label var female                   "1 if female"
label var dob                      "date of birth, format"
label var dod                      "date of death, format"
label var dom                      "date of marriage, format"
label var yob                      "year of birth, format"
label var yod                      "year of death, format"
label var yom                      "year of marriage, format"
label var age2023                  "approx. age in 2023"
label var drb                      "date record birth"
label var drm                      "date record marriage"

format cod_inec_ci_actual cod_inec_ci_padre cod_inec_ci_madre cod_inec_ci_conyugue %10.0g
format cod_condicion_cedulado cod_nacionalidad cod_estado_civil cod_instruccion %8.0g
format cod_lugar_nacimiento cod_lugar_insc_nacimiento cod_domicilio %12.0g
format cod_nacionalidad_conyuge %8.0g
format female yob yod yom age2023 %9.0g
format dob dod dom drb drm %td
format cod_inec_ci_pas_conyugue %24s

sort cod_inec_ci_actual
compress
save "$ced/cedulados_full.dta", replace


********************************************************************************
* 7. HOW CLOSE DID WE GET TO THE YAML?
********************************************************************************

di as txt _n "{hline 78}"
di as txt "ACHIEVED vs YAML  (yaml n = 21,757,803)"
di as txt "{hline 78}"
describe

di as txt _n "--- missing_prop: achieved / yaml ---"
local ymiss "cod_lugar_insc_nacimiento .001436 cod_domicilio .048797 cod_inec_ci_padre .067338 cod_inec_ci_madre .069927 cod_inec_ci_conyugue .085260 cod_nacionalidad_conyuge .833909 dod .903254 dom .719418 yod .903254 yom .719418 drb .835204 drm .901446"
local nm : word count `ymiss'
forvalues s = 1(2)`nm' {
    local s2 = `s' + 1
    local v : word `s'  of `ymiss'
    local y : word `s2' of `ymiss'
    qui count if mi(`v')
    di as txt %-28s "`v'" as res %8.4f r(N)/_N as txt "   yaml " as res %8.4f `y'
}

di as txt _n "--- share of zeros in the link columns (yaml: .35 / .32 / .7614 of non-missing) ---"
foreach v in cod_inec_ci_padre cod_inec_ci_madre cod_inec_ci_conyugue {
    qui count if `v' == 0
    local z = r(N)
    qui count if !mi(`v')
    di as txt %-28s "`v'" as res %8.4f `z'/r(N)
}

di as txt _n "--- quantiles: yob ---"
di as txt "  yaml:  p1 1913  p5 1935  p25 1968  p50 1989  p75 2005  p95 2019  p99 2022"
qui _pctile yob, p(1 5 25 50 75 95 99)
di as txt "  fake:  p1 " %4.0f r(r1) "  p5 " %4.0f r(r2) "  p25 " %4.0f r(r3) ///
   "  p50 " %4.0f r(r4) "  p75 " %4.0f r(r5) "  p95 " %4.0f r(r6) "  p99 " %4.0f r(r7)
qui sum yob
di as txt "  yaml mean 1984.6  sd 25.87   |   fake mean " %6.1f r(mean) "  sd " %5.2f r(sd)

di as txt _n "--- quantiles: cod_inec_ci_actual ---"
di as txt "  yaml:  min 1.0000633e9  p50 1.0211326e9  p99 1.0319925e9  max 8.800069e9"
qui sum cod_inec_ci_actual, detail
di as txt "  fake:  min " %14.0f r(min) "  p50 " %14.0f r(p50) ///
   "  p99 " %14.0f r(p99) "  max " %14.0f r(max)
qui duplicates report cod_inec_ci_actual
di as txt "  duplicate ids: " as res r(unique_value) as txt " unique values in " as res _N as txt " rows"

di as txt _n "--- categorical marginals ---"
tab cod_estado_civil
tab cod_instruccion
di as txt "  (cod_condicion_cedulado: 76 categories, the 8 most frequent shown)"
tab cod_condicion_cedulado if inlist(cod_condicion_cedulado,0,5,7,15,34,6,33,14)

di as txt _n "--- planted pathologies, as they appear in the saved file ---"
qui count if cod_inec_ci_actual > 8e9
di as txt %-52s "P12 anomalous 8.8e9 ids"                as res %8.0fc r(N)
qui count if cod_inec_ci_padre == cod_inec_ci_actual | cod_inec_ci_madre == cod_inec_ci_actual
di as txt %-52s "P04 self-parenthood"                    as res %8.0fc r(N)
qui count if cod_inec_ci_conyugue == cod_inec_ci_actual
di as txt %-52s "P08 self-spouse"                        as res %8.0fc r(N)
qui count if !mi(dod) & dod < dob
di as txt %-52s "P15 dod before dob"                     as res %8.0fc r(N)
qui count if !mi(dom) & dom < dob
di as txt %-52s "P15 dom before dob"                     as res %8.0fc r(N)
qui count if !mi(drb) & drb < dob
di as txt %-52s "P15 drb before dob"                     as res %8.0fc r(N)
qui count if age2023 > 110
di as txt %-52s "P14 age2023 > 110"                      as res %8.0fc r(N)
qui count if cod_inec_ci_pas_conyugue != ""
di as txt %-52s "foreign spouse on a passport"           as res %8.0fc r(N)

timer off 1
qui timer list 1
di as res _n "cedulados_full.dta written to $ced"
di as res "elapsed: " %6.1f r(t1) " seconds"

*===============================================================
* GINI DECOMPOSITION ANALYSIS - ECUADOR INCOME INEQUALITY
* Source: ENEMDU Survey Data (1991-2025)
* Purpose: Compute Gini coefficients and decompose by income source
*===============================================================

clear all
set more off
set graphics off

*---------------------------------------------------------------
* SECTION 1: PATH CONFIGURATION
*---------------------------------------------------------------

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global gh_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"

global procesado      "$user_root/Bases/ENEMDU/Procesadas"          // Processed data directory
global out            "$user_root/Papers/Íconos/outputs/Gini decomposition"  // Output directory
global out_g          "$out/graficos"                               // Graph output directory
global out_dash       "$gh_root/Dashboards/data/Data final/desigualdad"

* Create output directories if they do not exist
cap mkdir "$user_root/Papers/Íconos/outputs"
cap mkdir "$out"
cap mkdir "$out_g"


*---------------------------------------------------------------
* SECTION 2: BUILD POOLED DATASET (1991–2025)
* Appends annual per capita income files across urban and national
* samples. Files before 2000 are urban-only; from 2000 onward,
* national samples include an area identifier.
*---------------------------------------------------------------

* Load base file (1991, urban)
use ing* anio fexp using "$procesado/ingresos_pc/Urbano/ing_perca_1991_urb_precios2000.dta", clear

* Append remaining years
foreach y of numlist 1992(1)2001 2003 2005 2006(1)2025 {

    di "***** Appending year: `y' *****"

    // Years before 2000: urban only — no area variable
    if `y' < 2000 local vars    ing* anio fexp
    else           local vars    ing* anio area fexp

    // Prefix and subfolder depend on whether sample is urban or national
    if `y' < 2000 local prefix  urb
    else           local prefix  nac

    if `y' < 2000 local folder  Urbano
    else           local folder  Nacional

    append using "$procesado/ingresos_pc/`folder'/ing_perca_`y'_`prefix'_precios2000.dta", ///
        keep(`vars')
}

* Pre-2000 files carry no area variable because they are urban-only by
* construction. Tag them as urban so the urban subsample below keeps them.
replace area = 1 if missing(area) & anio < 2000

* Save pooled dataset (all areas, all years)
save "$procesado/casi_completa.dta", replace

* Save urban-only subsample for analyses that require long time series (incl. 1990s)
keep if area == 1
save "$procesado/casi_completa_urb.dta", replace


*---------------------------------------------------------------
* SECTION 3: OVERALL GINI COEFFICIENTS (NATIONAL, 1991–2025)
* Uses both ineqdeco and sgini for cross-validation.
* Results are exported to Excel.
*---------------------------------------------------------------

use "$procesado/casi_completa.dta", clear

* Replace missing income components with zero so observations are retained
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

*--- 3a. Gini via ineqdeco ---
mat a = .   // initialise accumulator matrix

foreach y of numlist 1991/2001 2003 2005 2006 2007/2025 {

    di "***** ineqdeco Gini — year: `y' *****"

    preserve
        keep if anio == `y'
        ineqdeco ingtot_per [w = fexp]   // returns r(gini)
    restore

    mat a = a \ r(gini)
}

* Drop the initialisation row and label
mat a = a[2..rowsof(a), 1..1]
matrix rownames a = 1991 1992 1993 1994 1995 1996 1997 1998 1999 2000 2001 ///
                    2003 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014  ///
                    2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025
matrix colnames a = ineqdeco

matlist a

* Export to Excel (column A = year labels, column B = Gini values)
putexcel set "$out/Gini.xlsx", replace
putexcel A1 = ("")           // placeholder so row names align correctly
putexcel A2 = matrix(a), names


*--- 3b. Gini via sgini (for comparison) ---
mat a = .

foreach y of numlist 1991/2001 2003 2005 2006 2007/2025 {

    di "***** sgini Gini — year: `y' *****"

    preserve
        keep if anio == `y'
        sgini ingtot_per [pw = fexp]   // returns r(coeff)
    restore

    mat a = a \ r(coeff)
}

mat a = a[2..rowsof(a), 1..1]
matrix rownames a = 1991 1992 1993 1994 1995 1996 1997 1998 1999 2000 2001 ///
                    2003 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014  ///
                    2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025
matrix colnames a = sgini

matlist a

* Append sgini results to column C of the same Excel sheet
putexcel C2 = matrix(a), colnames


*---------------------------------------------------------------
* SECTION 4: GINI SOURCE DECOMPOSITION — NATIONAL, ODD YEARS
* Decomposes total Gini into contributions from:
*   Labour income (laboral), capital income (rentas),
*   remittances (remesas), and cash transfer Bono (bono).
* Computed for every other year 2001–2025 using sgini.
*---------------------------------------------------------------

* Initialise accumulator: 16 columns (s×4, g×4, r×4, e×4)
mat a = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .

foreach year of numlist 2001(2)2025 {

    di "***** Source decomposition — year: `year' *****"

    preserve
        keep if anio == `year'

        // sourcedecomposition returns:
        //   r(s)          — income shares (vector)
        //   r(coeffs)     — concentration coefficients (matrix)
        //   r(r)          — correlation with total income
        //   r(elasticity) — Gini elasticities
        qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

        mat b = r(coeffs)[1, 1..4]   // concentration coefficients for 4 sources
        mat a = a \ (r(s), b, r(r), r(elasticity))
    restore
}

* Drop initialisation row; label columns and rows
matrix a = a[2..14, 1..16]
matrix colnames a = slaboral srentas sremesas sbono   ///   income shares
                    glaboral grentas gremesas gbono    ///   concentration coefficients
                    rlaboral rrentas rremesas rbono    ///   rank correlations
                    elaboral erentas eremesas ebono        // Gini elasticities

matrix rownames a = 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 2025

mat list a


*--- Convert matrix to dataset for plotting ---
clear
svmat double a, names(col)

gen t = 2001 + 2*(_n - 1)   // year variable

* Express income shares as percentages
foreach var of varlist slaboral srentas sbono sremesas {
    replace `var' = `var' * 100
}

* Save results table

export excel using "$out/gini_decomposition.xlsx", replace firstrow(var)
export excel using "$out_dash/gini_decomposition.xlsx", replace firstrow(var)

* Keep a copy for the data sheet of the figure workbook (Section 8).
* t is moved first for readability there only — the column order of the
* exports above is left untouched because the dashboard reads them.
order t
save "`c(tmpdir)'/gini_dat_nac.dta", replace


*--- Individual series plots ---
foreach var of varlist s* g* e* {

    if substr("`var'", 1, 1) == "s" local ytitle "Participación ingreso (%)"
    if substr("`var'", 1, 1) == "g" local ytitle "Gini"
    if substr("`var'", 1, 1) == "e" local ytitle "Elasticidad ingreso - Gini"

    twoway connected `var' t,          ///
        ytitle(`ytitle')               ///
        xtitle("Año")                  ///
        lcolor(dknavy)                 ///
        name(`var', replace)           ///
        xlab(2001(4)2025)              ///
        legend(pos(6))
}

*--- Combined plots: all four sources on one graph, by metric type ---
* Full decomposition (s/g/e) combining all four income sources
foreach pref in s g e {

    if "`pref'" == "s" local ytitle "Participación ingreso (%)"
    if "`pref'" == "g" local ytitle "Gini"
    if "`pref'" == "e" local ytitle "Elasticidad ingreso - Gini"

    * All four sources
    twoway                                                        ///
        (connected `pref'laboral t)                              ///
        (connected `pref'rentas  t)                              ///
        (connected `pref'bono    t)                              ///
        (connected `pref'remesas t),                             ///
        ytitle("`ytitle'")                                       ///
        xtitle("Año")                                            ///
        xlabel(2001(4)2025)                                      ///
        legend(order(1 "Laboral" 2 "Rentas" 3 "Bono" 4 "Remesas") rows(1) pos(6)) ///
        name(comb_`pref', replace)

    graph export "$out_g/nac_comb_`pref'.pdf", name(comb_`pref') replace

    * Three sources (excluding Bono, for cleaner visual)
    twoway                                                        ///
        (connected `pref'laboral t)                              ///
        (connected `pref'rentas  t)                              ///
        (connected `pref'remesas t),                             ///
        ytitle("`ytitle'")                                       ///
        xtitle("Año")                                            ///
        xlabel(2001(4)2025)                                      ///
        legend(order(1 "Laboral" 2 "Rentas" 3 "Remesas") rows(1) pos(6)) ///
        name(comb_`pref'2, replace)

    graph export "$out_g/nac_comb_`pref'2.pdf", name(comb_`pref'2) replace
}


*---------------------------------------------------------------
* SECTION 5: URBAN GINI SOURCE DECOMPOSITION (1991–2025)
* Urban-only sample allows extending the series back to the 1990s.
* Only labour and capital income (rentas) are decomposed because
* remittances and Bono data are not available before 2000.
*
* Odd years give the complete every-two-years grid: there are no
* processed files for 1990, 2002 or 2004, so an even-year grid would
* have three gaps, while 1991(2)2025 is fully covered.
*---------------------------------------------------------------

use "$procesado/casi_completa_urb.dta", clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

* Initialise accumulator: 8 columns (s×2, g×2, r×2, e×2)
mat a = ., ., ., ., ., ., ., .

foreach year of numlist 1991(2)2025 {

    di "***** Urban source decomposition — year: `year' *****"

    preserve
        keep if anio == `year'
        if `year' >= 2000 keep if area == 1   // redundant safety filter for national files

        qui: sgini inglab_per ingrent_per [pw = fexp], sourcedecomposition

        mat b = r(coeffs)[1, 1..2]
        mat a = a \ (r(s), b, r(r), r(elasticity))
    restore
}

matrix a = a[2..19, 1..8]
matrix colnames a = slaboral srentas glaboral grentas rlaboral rrentas elaboral erentas
matrix rownames a = 1991 1993 1995 1997 1999 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 2023 2025

mat list a

clear
svmat double a, names(col)

gen t = 1991 + 2*(_n - 1)
order t

foreach var of varlist slaboral srentas {
    replace `var' = `var' * 100
}

export excel using "$out/gini_decomposition_urbano.xlsx", replace firstrow(var)

* Keep a copy for the data sheet of the figure workbook (Section 8)
save "`c(tmpdir)'/gini_dat_urb.dta", replace

*--- Individual series plots (urban) ---
foreach var of varlist s* g* e* {

    if substr("`var'", 1, 1) == "s" local ytitle "Participación ingreso (%)"
    if substr("`var'", 1, 1) == "g" local ytitle "Gini"
    if substr("`var'", 1, 1) == "e" local ytitle "Elasticidad ingreso - Gini"

    twoway connected `var' t,          ///
        ytitle(`ytitle')               ///
        xtitle("Año")                  ///
        lcolor(dknavy)                 ///
        name(`var', replace)           ///
        xlab(1991(4)2025)
}

*--- Combined plots: labour vs capital income (urban) ---
foreach pref in s g e {

    if "`pref'" == "s" local ytitle "Participación ingreso (%)"
    if "`pref'" == "g" local ytitle "Gini"
    if "`pref'" == "e" local ytitle "Elasticidad ingreso - Gini"

    twoway                                                        ///
        (connected `pref'laboral t)                              ///
        (connected `pref'rentas  t),                             ///
        ytitle("`ytitle'")                                       ///
        xtitle("Año")                                            ///
        xlabel(1991(4)2025)                                      ///
        legend(order(1 "Laboral" 2 "Rentas") rows(1))           ///
        name(comb_`pref', replace)

    graph export "$out_g/urb_comb_`pref'.pdf", name(comb_`pref') replace
}


*---------------------------------------------------------------
* SECTION 6: GINI DECOMPOSITION BY QUINTILE (NATIONAL, 2001–2025)
* Repeats source decomposition within each income quintile to
* examine how the contribution of each income source varies
* across the distribution.
*---------------------------------------------------------------

use ingtot_per inglab_per ingrent_per ingrem_per ingbo_per anio fexp ///
    using "$procesado/casi_completa.dta" if inrange(anio, 2001, 2025), clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

* Initialise accumulator: 16 columns × (7 years × 5 quintiles) rows
mat b = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .

foreach year of numlist 2001(4)2025 {

    di "***** Quintile decomposition — year: `year' *****"

    forval i = 1/5 {

        di "  Quintile: `i'"

        preserve
            keep if anio == `year'

            // Assign quintile based on weighted distribution of total per capita income
            xtile ing_quants = ingtot_per [w = fexp], nquant(5)
            keep if ing_quants == `i'

            qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

            mat a = r(coeffs)[1, 1..4]
            mat b = b \ (r(s), a, r(r), r(elasticity))
        restore
    }
}

matrix b = b[2..rowsof(b), 1..colsof(b)]
matrix colnames b = slaboral srentas sremesas sbono   ///
                    glaboral grentas gremesas gbono    ///
                    rlaboral rrentas rremesas rbono    ///
                    elaboral erentas eremesas ebono

matrix rownames b = 2001q1 2001q2 2001q3 2001q4 2001q5 ///
                    2005q1 2005q2 2005q3 2005q4 2005q5 ///
                    2009q1 2009q2 2009q3 2009q4 2009q5 ///
                    2013q1 2013q2 2013q3 2013q4 2013q5 ///
                    2017q1 2017q2 2017q3 2017q4 2017q5 ///
                    2021q1 2021q2 2021q3 2021q4 2021q5 ///
                    2025q1 2025q2 2025q3 2025q4 2025q5
mat list b

clear
svmat double b, names(col)

* Reconstruct year and quintile identifiers from row position
gen q = mod(_n - 1, 5) + 1
* 2001(4)2025 is a regular grid, so t needs no fix-up for the last group
gen t = 2001 + 4*floor((_n - 1)/5)
order t q

foreach var of varlist slaboral srentas sremesas sbono {
    replace `var' = `var' * 100
}

export excel using "$out/gini_decomposition_quintiles.xlsx", replace firstrow(var)

*--- Plot income shares by quintile for each income source ---
foreach suf in laboral rentas remesas bono {

    if "`suf'" == "laboral" local ytitle "Participación ingreso laboral (%)"
    if "`suf'" == "rentas"  local ytitle "Participación ingreso rentas (%)"
    if "`suf'" == "remesas" local ytitle "Participación ingreso remesas (%)"
    if "`suf'" == "bono"    local ytitle "Participación ingreso bono (%)"

    twoway                                    ///
        (connected s`suf' t if q == 1, sort)  ///
        (connected s`suf' t if q == 2, sort)  ///
        (connected s`suf' t if q == 3, sort)  ///
        (connected s`suf' t if q == 4, sort)  ///
        (connected s`suf' t if q == 5, sort), ///
        legend(title("Quintil", size(small)) order(1 "1" 2 "2" 3 "3" 4 "4" 5 "5") cols(5)) ///
        xtitle("Year")                         ///
        ytitle("`ytitle'")                     ///
        name("quintil_`suf'", replace)
}


*---------------------------------------------------------------
* SECTION 7: GINI DECOMPOSITION BY QUARTILE (NATIONAL, 2001–2025)
* Same as Section 6 but using quartiles (4 groups) instead of
* quintiles (5 groups).
*---------------------------------------------------------------

use ingtot_per inglab_per ingrent_per ingrem_per ingbo_per anio fexp ///
    using "$procesado/casi_completa.dta" if inrange(anio, 2001, 2025), clear
recode ingtot_per inglab_per ingrent_per ingrem_per ingbo_per (. = 0)

mat b = ., ., ., ., ., ., ., ., ., ., ., ., ., ., ., .

foreach year of numlist 2001(4)2025 {

    di "***** Quartile decomposition — year: `year' *****"

    forval i = 1/4 {

        di "  Quartile: `i'"

        preserve
            keep if anio == `year'

            xtile ing_quants = ingtot_per [w = fexp], nquant(4)
            keep if ing_quants == `i'

            qui: sgini inglab_per ingrent_per ingrem_per ingbo_per [pw = fexp], sourcedecomposition

            mat a = r(coeffs)[1, 1..4]
            mat b = b \ (r(s), a, r(r), r(elasticity))
        restore
    }
}

matrix b = b[2..rowsof(b), 1..colsof(b)]
matrix colnames b = slaboral srentas sremesas sbono   ///
                    glaboral grentas gremesas gbono    ///
                    rlaboral rrentas rremesas rbono    ///
                    elaboral erentas eremesas ebono

matrix rownames b = 2001q1 2001q2 2001q3 2001q4 ///
                    2005q1 2005q2 2005q3 2005q4 ///
                    2009q1 2009q2 2009q3 2009q4 ///
                    2013q1 2013q2 2013q3 2013q4 ///
                    2017q1 2017q2 2017q3 2017q4 ///
                    2021q1 2021q2 2021q3 2021q4 ///
                    2025q1 2025q2 2025q3 2025q4
mat list b

clear
svmat double b, names(col)

gen q = mod(_n - 1, 4) + 1
gen t = 2001 + 4*floor((_n - 1)/4)
order t q

foreach var of varlist slaboral srentas sremesas sbono {
    replace `var' = `var' * 100
}

export excel using "$out/gini_decomposition_cuartiles.xlsx", replace firstrow(var)

* Keep a copy for the data sheet of the figure workbook (Section 8)
save "`c(tmpdir)'/gini_dat_cuartil.dta", replace

*--- Plot income shares by quartile for each income source ---
foreach suf in laboral rentas remesas bono {

    if "`suf'" == "laboral" local ytitle "Participación ingreso laboral (%)"
    if "`suf'" == "rentas"  local ytitle "Participación ingreso rentas (%)"
    if "`suf'" == "remesas" local ytitle "Participación ingreso remesas (%)"
    if "`suf'" == "bono"    local ytitle "Participación ingreso bono (%)"

    twoway                                    ///
        (connected s`suf' t if q == 1, sort)  ///
        (connected s`suf' t if q == 2, sort)  ///
        (connected s`suf' t if q == 3, sort)  ///
        (connected s`suf' t if q == 4, sort), ///
        legend(title("Cuartil", size(small)) order(1 "1" 2 "2" 3 "3" 4 "4") cols(5)) ///
        xtitle("Year")                         ///
        ytitle("`ytitle'")                     ///
        name("cuartil_`suf'", replace)

    graph export "$out_g/cuartil_s`suf'.pdf", name(cuartil_`suf') replace
}


*---------------------------------------------------------------
* SECTION 8: FIGURE WORKBOOK (graficos.xlsx)
* Sheet 1 ("Datos") holds the series behind the figures; every
* retained figure then gets its own sheet.
* Only the combined figures (national and urban) and the quartile
* figures are included.
* The sections above export figures as PDF because this Stata build
* has no PNG translator, so each PDF is converted to PNG with the
* macOS `sips' utility before being embedded.
*---------------------------------------------------------------

* Figures, in reading order. Each name is both the PDF file name and
* the sheet name; d_<name> holds the sheet description.
local figs                                                          ///
    nac_comb_s nac_comb_s2 nac_comb_g nac_comb_g2                   ///
    nac_comb_e nac_comb_e2                                          ///
    urb_comb_s urb_comb_g urb_comb_e                                ///
    cuartil_slaboral cuartil_srentas cuartil_sremesas cuartil_sbono

* Section 4 — national, 4 sources, 2001-2025
local d_nac_comb_s   "Nacional - participación en el ingreso, 4 fuentes"
local d_nac_comb_s2  "Nacional - participación en el ingreso, sin bono"
local d_nac_comb_g   "Nacional - coeficiente de concentración, 4 fuentes"
local d_nac_comb_g2  "Nacional - coeficiente de concentración, sin bono"
local d_nac_comb_e   "Nacional - elasticidad ingreso-Gini, 4 fuentes"
local d_nac_comb_e2  "Nacional - elasticidad ingreso-Gini, sin bono"

* Section 5 — urban, labour vs capital income, 1991-2025
local d_urb_comb_s   "Urbano 1991-2025 - participación: laboral vs rentas"
local d_urb_comb_g   "Urbano 1991-2025 - coef. de concentración: laboral vs rentas"
local d_urb_comb_e   "Urbano 1991-2025 - elasticidad ingreso-Gini: laboral vs rentas"

* Section 7 — by quartile, 2001-2025
local d_cuartil_slaboral "Cuartiles - participación del ingreso laboral"
local d_cuartil_srentas  "Cuartiles - participación de las rentas"
local d_cuartil_sremesas "Cuartiles - participación de las remesas"
local d_cuartil_sbono    "Cuartiles - participación del bono"

* Temporary folder for the PNG conversions and for assembling the workbook.
* Building it locally avoids one rewrite per sheet of a file sitting on
* Google Drive; the finished workbook is copied to $out at the end.
local tmp "`c(tmpdir)'/gini_png"
cap mkdir "`tmp'"
local wb  "`tmp'/graficos.xlsx"
cap erase "`wb'"

* Column-prefix legend, repeated above each table
local leg "s: participación (%), g: coef. de concentración, r: correlación de rangos, e: elasticidad ingreso-Gini"

*--- Sheet 1: the data behind the figures ---
* Three stacked tables; each title sits one row above its header row.
use "`c(tmpdir)'/gini_dat_nac.dta", clear
export excel using "`wb'", sheet("Datos", replace) firstrow(var) cell(A2)

use "`c(tmpdir)'/gini_dat_urb.dta", clear
export excel using "`wb'", sheet("Datos", modify) firstrow(var) cell(A19)

use "`c(tmpdir)'/gini_dat_cuartil.dta", clear
export excel using "`wb'", sheet("Datos", modify) firstrow(var) cell(A41)

* Bare sheet() + file-level modify: sheet("Datos", replace) would wipe the
* tables that export excel just wrote.
putexcel set "`wb'", sheet("Datos") modify
putexcel A1  = ("Nacional, 4 fuentes, 2001-2025 (t = año). `leg'")
putexcel A18 = ("Urbano, laboral y rentas, 1991-2025 (t = año). `leg'")
putexcel A40 = ("Nacional por cuartil, 2001-2025 (t = año, q = cuartil). `leg'")

* Number formats: one decimal on the estimates, integers on the year and
* quartile identifiers. Set here so they survive a re-run of the script.
*   nacional  17 cols (A..Q), data rows  3-15
*   urbano     9 cols (A..I), data rows 20-37
*   cuartiles 18 cols (A..R), data rows 42-69
putexcel (A3:A15),  nformat("0")
putexcel (B3:Q15),  nformat("0.0")
putexcel (A20:A37), nformat("0")
putexcel (B20:I37), nformat("0.0")
putexcel (A42:B69), nformat("0")
putexcel (C42:R69), nformat("0.0")
putexcel save

*--- One sheet per figure ---
local n 0
foreach f of local figs {

    di "***** Sheet: `f' *****"

    // PDF -> PNG (Stata cannot write PNG in console mode)
    shell sips -s format png -s formatOptions best -Z 1000 "$out_g/`f'.pdf" --out "`tmp'/`f'.png" > /dev/null 2>&1

    capture confirm file "`tmp'/`f'.png"
    if _rc {
        di as error "  PNG conversion failed for `f' — sheet skipped"
        continue
    }

    * The image must be written BEFORE the title: putexcel silently drops a
    * text cell written earlier in the same session as an image() on the
    * same sheet (the string lands in sharedStrings but the cell is lost).
    putexcel set "`wb'", sheet("`f'", replace) modify
    putexcel A3 = image("`tmp'/`f'.png")
    putexcel A1 = ("`d_`f''")
    putexcel save

    erase "`tmp'/`f'.png"
    local ++n
}

di "***** Figures written to workbook: `n' of `: word count `figs'' *****"

* Move the finished workbook next to the other outputs
copy "`wb'" "$out/graficos_decomposición_gini.xlsx", replace
erase "`wb'"

di "***** DONE *****"

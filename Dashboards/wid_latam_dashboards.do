    /*******************************************************************************
* Dashboards América Latina — WID + World Bank
*
* Genera 4 archivos Excel Tableau-friendly (formato largo) para países de AL:
*   1. WID_ingreso_percentiles_ALC_tableau.xlsx  (participación en ingreso)
*   2. WID_riqueza_percentiles_ALC_tableau.xlsx  (participación en riqueza)
*   3. gini_panel_ALC_tableau.xlsx               (coeficiente de Gini, WID)
*   4. Pobreza_ALC_tableau.xlsx                  (pobreza, World Bank)
*******************************************************************************/

clear all
set more off

* ============================================================================
* 0. CONFIGURACIÓN
* ============================================================================

capture which wid
if _rc ssc install wid, replace

capture which wbopendata
if _rc ssc install wbopendata, replace

global dashdir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Dashboards"
global outdir  "$dashdir/Data"

* Códigos ISO-2 para América Latina (WID usa ISO-2)
local latam_wid "AR BO BR CL CO CR CU DO EC GT HN HT MX NI PA PE PY SV UY VE"

* ============================================================================
* 1. INGRESO NACIONAL — Participación por percentil (sptinc)
* ============================================================================

di as result _n "=== 1. Descargando participación en ingreso nacional ==="

wid, indicators(sptinc) areas(`latam_wid') ///
    perc(p99.9p100 p99p100 p90p100 p0p50) clear

* Mantener solo equal-split adults (992j), descartar individuos (992i)
keep if variable == "sptinc992j"
drop if missing(value)

* Etiqueta de percentil
gen str30 percentil = ""
replace percentil = "Top 0.1%"    if percentile == "p99.9p100"
replace percentil = "Top 1%"      if percentile == "p99p100"
replace percentil = "Top 10%"     if percentile == "p90p100"
replace percentil = "Bottom 50%"  if percentile == "p0p50"

* Nombre del país
rename country pais_code
gen str30 pais = ""
replace pais = "Argentina"        if pais_code == "AR"
replace pais = "Bolivia"          if pais_code == "BO"
replace pais = "Brasil"           if pais_code == "BR"
replace pais = "Chile"            if pais_code == "CL"
replace pais = "Colombia"         if pais_code == "CO"
replace pais = "Costa Rica"       if pais_code == "CR"
replace pais = "Cuba"             if pais_code == "CU"
replace pais = "Rep. Dominicana"  if pais_code == "DO"
replace pais = "Ecuador"          if pais_code == "EC"
replace pais = "El Salvador"      if pais_code == "SV"
replace pais = "Guatemala"        if pais_code == "GT"
replace pais = "Haití"            if pais_code == "HT"
replace pais = "Honduras"         if pais_code == "HN"
replace pais = "México"           if pais_code == "MX"
replace pais = "Nicaragua"        if pais_code == "NI"
replace pais = "Panamá"           if pais_code == "PA"
replace pais = "Paraguay"         if pais_code == "PY"
replace pais = "Perú"             if pais_code == "PE"
replace pais = "Uruguay"          if pais_code == "UY"
replace pais = "Venezuela"        if pais_code == "VE"

rename year anio
rename value participacion
replace participacion = participacion * 100

keep anio pais pais_code percentil participacion
order anio pais pais_code percentil participacion
sort pais anio percentil

label var anio          "Año"
label var pais          "País"
label var pais_code     "Código ISO"
label var percentil     "Percentil"
label var participacion "Participación en el ingreso nacional (%)"

export excel using "$outdir/WID_ingreso_percentiles_ALC_tableau.xlsx", ///
    firstrow(varlabel) replace
di as result "  Exportado: WID_ingreso_percentiles_ALC_tableau.xlsx"

* ============================================================================
* 2. RIQUEZA NACIONAL — Participación por percentil (shweal)
* ============================================================================

di as result _n "=== 2. Descargando participación en riqueza nacional ==="

wid, indicators(shweal) areas(`latam_wid') ///
    perc(p99.9p100 p99p100 p90p100 p0p50) clear

* Mantener solo equal-split adults (992j)
keep if variable == "shweal992j"
drop if missing(value)

gen str30 percentil = ""
replace percentil = "Top 0.1%"    if percentile == "p99.9p100"
replace percentil = "Top 1%"      if percentile == "p99p100"
replace percentil = "Top 10%"     if percentile == "p90p100"
replace percentil = "Bottom 50%"  if percentile == "p0p50"

rename country pais_code
gen str30 pais = ""
replace pais = "Argentina"        if pais_code == "AR"
replace pais = "Bolivia"          if pais_code == "BO"
replace pais = "Brasil"           if pais_code == "BR"
replace pais = "Chile"            if pais_code == "CL"
replace pais = "Colombia"         if pais_code == "CO"
replace pais = "Costa Rica"       if pais_code == "CR"
replace pais = "Cuba"             if pais_code == "CU"
replace pais = "Rep. Dominicana"  if pais_code == "DO"
replace pais = "Ecuador"          if pais_code == "EC"
replace pais = "El Salvador"      if pais_code == "SV"
replace pais = "Guatemala"        if pais_code == "GT"
replace pais = "Haití"            if pais_code == "HT"
replace pais = "Honduras"         if pais_code == "HN"
replace pais = "México"           if pais_code == "MX"
replace pais = "Nicaragua"        if pais_code == "NI"
replace pais = "Panamá"           if pais_code == "PA"
replace pais = "Paraguay"         if pais_code == "PY"
replace pais = "Perú"             if pais_code == "PE"
replace pais = "Uruguay"          if pais_code == "UY"
replace pais = "Venezuela"        if pais_code == "VE"

rename year anio
rename value participacion
replace participacion = participacion * 100

keep anio pais pais_code percentil participacion
order anio pais pais_code percentil participacion
sort pais anio percentil

label var anio          "Año"
label var pais          "País"
label var pais_code     "Código ISO"
label var percentil     "Percentil"
label var participacion "Participación en la riqueza nacional (%)"

export excel using "$outdir/WID_riqueza_percentiles_ALC_tableau.xlsx", ///
    firstrow(varlabel) replace
di as result "  Exportado: WID_riqueza_percentiles_ALC_tableau.xlsx"

* ============================================================================
* 3. GINI — Coeficiente de Gini (ingreso pre-tax, WID)
* ============================================================================

di as result _n "=== 3. Descargando coeficiente de Gini ==="

* gptinc = Gini coefficient of pre-tax national income
wid, indicators(gptinc) areas(`latam_wid') perc(p0p100) clear

* Mantener solo equal-split adults (992j)
keep if variable == "gptinc992j"
drop if missing(value)

rename country pais_code
gen str30 pais = ""
replace pais = "Argentina"        if pais_code == "AR"
replace pais = "Bolivia"          if pais_code == "BO"
replace pais = "Brasil"           if pais_code == "BR"
replace pais = "Chile"            if pais_code == "CL"
replace pais = "Colombia"         if pais_code == "CO"
replace pais = "Costa Rica"       if pais_code == "CR"
replace pais = "Cuba"             if pais_code == "CU"
replace pais = "Rep. Dominicana"  if pais_code == "DO"
replace pais = "Ecuador"          if pais_code == "EC"
replace pais = "El Salvador"      if pais_code == "SV"
replace pais = "Guatemala"        if pais_code == "GT"
replace pais = "Haití"            if pais_code == "HT"
replace pais = "Honduras"         if pais_code == "HN"
replace pais = "México"           if pais_code == "MX"
replace pais = "Nicaragua"        if pais_code == "NI"
replace pais = "Panamá"           if pais_code == "PA"
replace pais = "Paraguay"         if pais_code == "PY"
replace pais = "Perú"             if pais_code == "PE"
replace pais = "Uruguay"          if pais_code == "UY"
replace pais = "Venezuela"        if pais_code == "VE"

rename year anio
rename value gini

keep anio pais pais_code gini
order anio pais pais_code gini
sort pais anio

label var anio      "Año"
label var pais      "País"
label var pais_code "Código ISO"
label var gini      "Coeficiente de Gini"

export excel using "$outdir/gini_panel_ALC_tableau.xlsx", ///
    firstrow(varlabel) replace
di as result "  Exportado: gini_panel_ALC_tableau.xlsx"

* ============================================================================
* 4. POBREZA — World Bank (wbopendata)
* ============================================================================

di as result _n "=== 4. Descargando datos de pobreza (World Bank) ==="

* Códigos ISO-3 para World Bank (separados por ;)
local latam_wb "ARG;BOL;BRA;CHL;COL;CRI;CUB;DOM;ECU;GTM;HND;HTI;MEX;NIC;PAN;PER;PRY;SLV;URY;VEN"

* --- 4a. Pobreza extrema ($3.00/día, PPA 2021) ---
wbopendata, indicator(SI.POV.DDAY) country(`latam_wb') long clear
rename si_pov_dday pobreza_extrema
rename countrycode pais_code3
rename countryname pais_wb
keep pais_code3 pais_wb year pobreza_extrema
drop if missing(pobreza_extrema)
rename year anio
tempfile pov1
save "`pov1'", replace

* --- 4b. Pobreza moderada ($8.30/día, PPA 2021) ---
wbopendata, indicator(SI.POV.UMIC) country(`latam_wb') long clear
rename si_pov_umic pobreza_moderada
rename countrycode pais_code3
rename countryname pais_wb
keep pais_code3 pais_wb year pobreza_moderada
drop if missing(pobreza_moderada)
rename year anio
tempfile pov2
save "`pov2'", replace

* --- 4c. Gini World Bank ---
wbopendata, indicator(SI.POV.GINI) country(`latam_wb') long clear
rename si_pov_gini gini_wb
rename countrycode pais_code3
rename countryname pais_wb
keep pais_code3 pais_wb year gini_wb
drop if missing(gini_wb)
rename year anio
tempfile pov3
save "`pov3'", replace

* --- Merge all poverty indicators ---
use "`pov1'", clear
merge 1:1 pais_code3 anio using "`pov2'", nogen
merge 1:1 pais_code3 anio using "`pov3'", nogen

* Nombre en español
gen str30 pais = ""
replace pais = "Argentina"        if pais_code3 == "ARG"
replace pais = "Bolivia"          if pais_code3 == "BOL"
replace pais = "Brasil"           if pais_code3 == "BRA"
replace pais = "Chile"            if pais_code3 == "CHL"
replace pais = "Colombia"         if pais_code3 == "COL"
replace pais = "Costa Rica"       if pais_code3 == "CRI"
replace pais = "Cuba"             if pais_code3 == "CUB"
replace pais = "Rep. Dominicana"  if pais_code3 == "DOM"
replace pais = "Ecuador"          if pais_code3 == "ECU"
replace pais = "El Salvador"      if pais_code3 == "SLV"
replace pais = "Guatemala"        if pais_code3 == "GTM"
replace pais = "Haití"            if pais_code3 == "HTI"
replace pais = "Honduras"         if pais_code3 == "HND"
replace pais = "México"           if pais_code3 == "MEX"
replace pais = "Nicaragua"        if pais_code3 == "NIC"
replace pais = "Panamá"           if pais_code3 == "PAN"
replace pais = "Paraguay"         if pais_code3 == "PRY"
replace pais = "Perú"             if pais_code3 == "PER"
replace pais = "Uruguay"          if pais_code3 == "URY"
replace pais = "Venezuela"        if pais_code3 == "VEN"

* Stack en formato largo Tableau-friendly (una fila por indicador)
preserve
    keep anio pais pais_code3 pobreza_extrema
    drop if missing(pobreza_extrema)
    gen str40 indicador = "Pobreza extrema ($3.00/día)"
    rename pobreza_extrema valor
    tempfile s1
    save "`s1'"
restore

preserve
    keep anio pais pais_code3 pobreza_moderada
    drop if missing(pobreza_moderada)
    gen str40 indicador = "Pobreza ($8.30/día)"
    rename pobreza_moderada valor
    tempfile s2
    save "`s2'"
restore

preserve
    keep anio pais pais_code3 gini_wb
    drop if missing(gini_wb)
    gen str40 indicador = "Gini (World Bank)"
    rename gini_wb valor
    tempfile s3
    save "`s3'"
restore

use "`s1'", clear
append using "`s2'"
append using "`s3'"

order anio pais pais_code3 indicador valor
sort pais anio indicador

label var anio      "Año"
label var pais      "País"
label var pais_code3 "Código ISO"
label var indicador "Indicador"
label var valor     "Valor (%)"

export excel using "$outdir/Pobreza_ALC_tableau.xlsx", ///
    firstrow(varlabel) replace
di as result "  Exportado: Pobreza_ALC_tableau.xlsx"

* ============================================================================
* FIN
* ============================================================================

di as result _n "============================================="
di as result    "  Proceso completado"
di as result    "============================================="
di as text "Archivos generados en: $outdir"
di as text "  1. WID_ingreso_percentiles_ALC_tableau.xlsx"
di as text "  2. WID_riqueza_percentiles_ALC_tableau.xlsx"
di as text "  3. gini_panel_ALC_tableau.xlsx"
di as text "  4. Pobreza_ALC_tableau.xlsx"

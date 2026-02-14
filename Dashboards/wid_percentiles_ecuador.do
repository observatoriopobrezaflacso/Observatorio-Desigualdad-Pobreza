/*******************************************************************************
* WID — Participación de percentiles en ingreso y riqueza nacional (Ecuador)
*
* Descarga datos de World Inequality Database para Ecuador:
*   1. Participación en el ingreso nacional (pre-tax): p99.9, p99, p90, bottom 50
*   2. Participación en la riqueza nacional: p99.9, p99, p90, bottom 50
*
* Exporta archivos Excel en formato Tableau-friendly (formato largo).
*
* Salida:
*   - Dashboards/Data/WID_ingreso_percentiles_tableau.xlsx
*   - Dashboards/Data/WID_riqueza_percentiles_tableau.xlsx
*******************************************************************************/

clear all
set more off

* ============================================================================
* 0. CONFIGURACIÓN
* ============================================================================

* Instalar wid si no está disponible
capture which wid
if _rc {
    ssc install wid, replace
}

global dashdir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Dashboards"
global outdir  "$dashdir/Data"

* ============================================================================
* 1. INGRESO NACIONAL — Participación por percentil (sptinc)
* ============================================================================

* sptinc = share of pre-tax national income
* Top 0.1% (p99.9p100), Top 1% (p99p100), Top 10% (p90p100), Bottom 50% (p0p50)

wid, indicators(sptinc) areas(EC) perc(p99.9p100 p99p100 p90p100 p0p50) clear

* Limpiar y dar formato
drop if missing(value)

* Crear etiqueta legible del percentil
gen str30 percentil = ""
replace percentil = "Top 0.1%"    if percentile == "p99.9p100"
replace percentil = "Top 1%"      if percentile == "p99p100"
replace percentil = "Top 10%"     if percentile == "p90p100"
replace percentil = "Bottom 50%"  if percentile == "p0p50"

* Mantener solo variables relevantes
rename year anio
rename value participacion

keep anio percentil participacion percentile

* Multiplicar por 100 para expresar como porcentaje
replace participacion = participacion * 100

* Ordenar
sort anio percentil

* Etiquetas
label var anio          "Año"
label var percentil     "Percentil"
label var participacion "Participación en el ingreso nacional (%)"

* Exportar
drop percentile
order anio percentil participacion
export excel using "$outdir/WID_ingreso_percentiles_tableau.xlsx", ///
    firstrow(varlabel) replace

di as result "Exportado: WID_ingreso_percentiles_tableau.xlsx"

* ============================================================================
* 2. RIQUEZA NACIONAL — Participación por percentil (shweal)
* ============================================================================

* shweal = share of net personal wealth
* Mismos percentiles

wid, indicators(shweal) areas(EC) perc(p99.9p100 p99p100 p90p100 p0p50) clear

* Limpiar y dar formato
drop if missing(value)

gen str30 percentil = ""
replace percentil = "Top 0.1%"    if percentile == "p99.9p100"
replace percentil = "Top 1%"      if percentile == "p99p100"
replace percentil = "Top 10%"     if percentile == "p90p100"
replace percentil = "Bottom 50%"  if percentile == "p0p50"

rename year anio
rename value participacion

keep anio percentil participacion percentile

replace participacion = participacion * 100

sort anio percentil

label var anio          "Año"
label var percentil     "Percentil"
label var participacion "Participación en la riqueza nacional (%)"

drop percentile
order anio percentil participacion
export excel using "$outdir/WID_riqueza_percentiles_tableau.xlsx", ///
    firstrow(varlabel) replace

di as result "Exportado: WID_riqueza_percentiles_tableau.xlsx"

* ============================================================================
* FIN
* ============================================================================

di as result _n "Proceso completado."
di as text "Archivos generados en: $outdir"
di as text "  - WID_ingreso_percentiles_tableau.xlsx"
di as text "  - WID_riqueza_percentiles_tableau.xlsx"

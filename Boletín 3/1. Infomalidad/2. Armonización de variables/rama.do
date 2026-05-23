*-----------------------------------------------------------------------------
* descriptiva_ramas.do
*
* Apila las bases armonizadas (empleo<anio>_isic4.dta) y produce la
* distribucion porcentual de empleo por rama (Seccion CIIU Rev. 4) por anio.
*-----------------------------------------------------------------------------

clear all
set more off
set linesize 220

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global out       "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global wd        "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Boletín 3/2. Armonización de variables/rama"
global historicos "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"

*-----------------------------------------------------------------------------
* STEP 1: Apilar bases armonizadas
*-----------------------------------------------------------------------------

tempfile pooled
local first = 1

forval anio = 1991/2025 {

	local fp "$out/empleo`anio'_isic4.dta"
	capture confirm file "`fp'"
	if _rc {
		di as error "  Sin archivo armonizado para `anio'; se omite."
		continue
	}

	use rama1 fexp ausing "`fp'", clear
	gen int anio = `anio'

	if `first' {
		save `pooled', replace
		local first = 0
	}
	else {
		append using `pooled'
		save `pooled', replace
	}
}

use `pooled', clear

save "$historicos/historico_rama.dta", replace


* Conservar solo observaciones con rama identificada.
drop if missing(rama1)
decode rama1, gen(rama1_str)
replace rama1_str = "" if rama1_str == "."

* Etiqueta corta para la tabla (solo la letra de la seccion).
gen seccion = substr(rama1_str, 1, 1)
drop if missing(seccion) | seccion == ""

*-----------------------------------------------------------------------------
* STEP 2: Identificar las ramas mas grandes en el tiempo
*-----------------------------------------------------------------------------

preserve
	contract seccion
	egen total = total(_freq)
	gen share_total = 100 * _freq / total
	gsort -share_total
	di as text _newline "Top 8 ramas (Seccion) - share global de empleo 1991-2025"
	list seccion _freq share_total in 1/8, sep(0) noobs abbrev(15)
restore

*-----------------------------------------------------------------------------
* STEP 3: Distribucion porcentual por anio (tabla larga)
*-----------------------------------------------------------------------------

preserve
	contract anio seccion
	bysort anio: egen total_anio = total(_freq)
	gen share = 100 * _freq / total_anio
	keep anio seccion share
	reshape wide share, i(anio) j(seccion) string
	format share* %5.1f
	di as text _newline "Distribucion porcentual del empleo por rama (Seccion CIIU Rev. 4) por anio"
	list, sep(0) noobs abbrev(10)
	export delimited using "$wd/distribucion_ramas_por_anio.csv", replace
	di as text _newline "CSV guardado en: $wd/distribucion_ramas_por_anio.csv"
restore

*-----------------------------------------------------------------------------
* STEP 4: Tabla compacta con las 8 ramas mayores en el tiempo
*-----------------------------------------------------------------------------

* Las 8 ramas mas grandes globalmente 1991-2025 (segun share total):
*   A Agricultura, G Comercio, C Manufactura, P Ensenanza,
*   I Alojamiento/comidas, F Construccion, H Transporte, O Adm. publica.
preserve
	contract anio seccion
	bysort anio: egen total_anio = total(_freq)
	gen share = 100 * _freq / total_anio
	keep if inlist(seccion, "A","C","F","G","H","I","O","P")
	keep anio seccion share
	reshape wide share, i(anio) j(seccion) string
	order anio shareA shareG shareC shareP shareI shareF shareH shareO
	label var shareA "A.Agric"
	label var shareG "G.Comer"
	label var shareC "C.Manuf"
	label var shareP "P.Educ"
	label var shareI "I.Aloj/Com"
	label var shareF "F.Const"
	label var shareH "H.Tport"
	label var shareO "O.AdmPub"
	format share* %5.1f
	di as text _newline "Tabla compacta: % de empleo en las 8 ramas mas grandes (CIIU Rev. 4)"
	list anio share*, sep(5) noobs abbrev(10)
	export delimited using "$wd/ramas_top_por_anio.csv", replace
	di as text _newline "CSV guardado en: $wd/ramas_top_por_anio.csv"
restore

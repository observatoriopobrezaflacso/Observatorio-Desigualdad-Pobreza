*==============================================================================*
* CURVAS DE INCIDENCIA DEL CRECIMIENTO (GIC) — PAPER "ÍCONOS"
*
* Versión reducida de Dashboards/codigo/gic_curves.do: calcula SOLO las cinco
* curvas que usa el paper (Gráficos 5, 6 y 7), en vez de todos los pares de
* años posibles.
*
*   Urbano   : 1991-1998   y   2001-2025
*   Nacional : 2001-2010,  2011-2025  y  2001-2025
*
* Método: gicurve sobre el ingreso per cápita del hogar deflactado a precios
* de 2000, ponderado por fw. El crecimiento sale ANUALIZADO porque se pasa
* yp(<número de años del período>).
*
* Fuente: Bases/ENEMDU/Procesadas/ingresos_pc/{Urbano,Nacional}
*         ing_perca_<año>_{urb,nac}_precios2000.dta
* Requiere: gicurve (M. Lokshin, Banco Mundial). NO está en SSC; se instala con
*     net install gicurve, from("https://raw.githubusercontent.com/vavalomi/stata_tools/master/")
* La curva sale anualizada dentro del propio gicurve: ((1+g)^(1/yp)-1)*100.
*
* Salidas en $out/GIC:
*   gic_paper.xlsx
*       GIC_urbano   : pctl + una columna por curva urbana      -> gráfico
*       GIC_nacional : pctl + una columna por curva nacional    -> gráfico
*       GIC_ref      : líneas de referencia (crecimiento de la media, de la
*                      mediana y media del crecimiento) de cada curva
*       GIC_largo    : todo junto en formato largo, para revisar
*   gic_paper.dta    : el formato largo
*   dta/gic_<curva>.dta : la salida cruda de gicurve, curva por curva
*
* El formato ancho es el que se grafica en Excel: la columna pctl va al eje X
* y cada columna g_* es una serie. Las líneas horizontales de referencia se
* toman de GIC_ref.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}
if "$out" == "" global out "$gd/Papers/Íconos/outputs"

set more off
set varabbrev off

global gic_urb "$gd/Bases/ENEMDU/Procesadas/ingresos_pc/Urbano"
global gic_nac "$gd/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
global gic_out "$out/GIC"

capture mkdir "$out"
capture mkdir "$gic_out"
capture mkdir "$gic_out/dta"

* Número de puntos de la curva. 10 = deciles (lo mismo que el Boletín 1).
* Subirlo a 20 o 100 da una curva más fina sin cambiar el método.
if "$gic_np" == "" global gic_np 10

* La ruta de los tempfiles tampoco puede tener espacios, por lo mismo.
if strpos("`c(tmpdir)'", " ") {
    di as error "El directorio temporal tiene espacios: `c(tmpdir)'"
    di as error "gicurve no lo va a poder abrir. Cambiarlo con: set tmpdir"
    exit 198
}

capture which gicurve
if _rc {
    di as error "Falta el comando gicurve. No está en SSC. Instalar con:"
    di as error `"    net install gicurve, from("https://raw.githubusercontent.com/vavalomi/stata_tools/master/")"'
    exit 111
}

*==============================================================================*
* 1. CURVAS QUE PIDE EL PAPER
*
* Un local por curva: ámbito (urb/nac), año base y año final.
*==============================================================================*

local n = 0

local ++n
local amb`n' "urb"
local y1`n'  1991
local y2`n'  1998

local ++n
local amb`n' "urb"
local y1`n'  2001
local y2`n'  2025

local ++n
local amb`n' "nac"
local y1`n'  2001
local y2`n'  2010

local ++n
local amb`n' "nac"
local y1`n'  2011
local y2`n'  2025

local ++n
local amb`n' "nac"
local y1`n'  2001
local y2`n'  2025

*==============================================================================*
* 2. CÁLCULO
*==============================================================================*

tempfile largo
local hechas = 0
local faltantes ""

forvalues i = 1/`n' {

    local amb "`amb`i''"
    local y1  = `y1`i''
    local y2  = `y2`i''
    local per = `y2' - `y1'
    local serie "`amb'_`y1'_`y2'"

    if ("`amb'" == "urb") local dir "$gic_urb"
    else                  local dir "$gic_nac"

    local f1 "`dir'/ing_perca_`y1'_`amb'_precios2000.dta"
    local f2 "`dir'/ing_perca_`y2'_`amb'_precios2000.dta"

    capture confirm file "`f1'"
    local rc1 = _rc
    capture confirm file "`f2'"
    local rc2 = _rc
    if (`rc1' | `rc2') {
        if (`rc1') di as error "FALTA: `f1'"
        if (`rc2') di as error "FALTA: `f2'"
        local faltantes "`faltantes' `serie'"
        continue
    }

    di as res _n "--- GIC `serie' (`per' años) ---"

    * gicurve abre el archivo del año final y guarda su tabla de salida SIN
    * comillas, así que se atraganta con cualquier ruta que tenga espacios,
    * como "Mi unidad". Por eso entra y sale por tempfiles, cuyas rutas no
    * tienen espacios, y desde aquí se copia la tabla a su lugar definitivo.
    * La copia del año final se queda sólo con las dos variables que el
    * comando necesita, lo que además lo hace más rápido.
    tempfile f2sin
    use ingtot_per_deflated fw using "`f2'", clear
    save "`f2sin'"

    tempfile tabla
    use "`f1'", clear
    capture noisily gicurve using "`f2sin'" [fw=fw], ///
        var1(ingtot_per_deflated) var2(ingtot_per_deflated) ///
        yp(`per') np($gic_np) nograph ///
        outputfile("`tabla'")
    if _rc {
        di as error "gicurve falló en `serie' (_rc=`=_rc')"
        local faltantes "`faltantes' `serie'"
        continue
    }

    use "`tabla'", clear
    save "$gic_out/dta/gic_`serie'.dta", replace
    gen str3  ambito = "`amb'"
    gen int   anio1  = `y1'
    gen int   anio2  = `y2'
    gen byte  anios  = `per'
    gen str20 serie  = "`serie'"
    order ambito anio1 anio2 anios serie pctl

    if (`hechas' == 0) save "`largo'", replace
    else {
        append using "`largo'"
        save "`largo'", replace
    }
    local ++hechas
}

if (`hechas' == 0) {
    di as error "Ninguna curva se pudo calcular. No se escribe nada."
    exit 459
}

*==============================================================================*
* 3. FORMATO LARGO
*==============================================================================*

use "`largo'", clear
sort ambito anio1 anio2 pctl

label var ambito         "urb = urbano, nac = nacional"
label var anio1          "Año base"
label var anio2          "Año final"
label var anios          "Años del período"
label var serie          "Identificador de la curva"
label var pctl           "Percentil del ingreso per cápita"
label var pr_growth      "Crecimiento anual del ingreso en el percentil (%)"
label var gr_in_mean     "Crecimiento anual de la media (%)"
label var gr_in_median   "Crecimiento anual de la mediana (%)"
label var mean_of_growth "Media del crecimiento por percentil (%)"

save "$gic_out/gic_paper.dta", replace

*==============================================================================*
* 4. FORMATO ANCHO — UNA COLUMNA POR CURVA, LISTO PARA GRAFICAR EN EXCEL
*==============================================================================*

* El libro se arma en disco local y recién al final se copia a su lugar:
* escribir hoja por hoja directo sobre Google Drive falla al reabrir el
* archivo para el sheetreplace (r(603)).
tempfile tb
global gic_libro "`tb'.xlsx"

local primera = 1

foreach amb in urb nac {

    use "$gic_out/gic_paper.dta", clear
    keep if ambito == "`amb'"
    if (_N == 0) {
        di as error "Sin curvas de `amb': no se escribe la hoja"
        continue
    }

    keep pctl serie pr_growth
    reshape wide pr_growth, i(pctl) j(serie) string

    * pr_growthurb_1991_1998 -> g_urb_1991_1998
    foreach v of varlist pr_growth* {
        local nuevo = "g_" + subinstr("`v'", "pr_growth", "", 1)
        rename `v' `nuevo'
        label var `nuevo' "`nuevo' (% anual)"
    }

    order pctl
    sort pctl
    label var pctl "Percentil"

    if ("`amb'" == "urb") local hoja "GIC_urbano"
    else                  local hoja "GIC_nacional"

    if (`primera') export excel using "$gic_libro", ///
        sheet("`hoja'") firstrow(variables) replace
    else export excel using "$gic_libro", ///
        sheet("`hoja'") firstrow(variables) sheetreplace
    local primera = 0

    di as txt "  hoja `hoja': `=_N' filas"
}

*==============================================================================*
* 5. LÍNEAS DE REFERENCIA Y HOJA LARGA
*==============================================================================*

use "$gic_out/gic_paper.dta", clear
bysort serie (pctl): keep if _n == 1
keep ambito anio1 anio2 anios serie gr_in_mean gr_in_median mean_of_growth
order ambito anio1 anio2 anios serie
sort ambito anio1 anio2

export excel using "$gic_libro", ///
    sheet("GIC_ref") firstrow(variables) sheetreplace

use "$gic_out/gic_paper.dta", clear
export excel using "$gic_libro", ///
    sheet("GIC_largo") firstrow(variables) sheetreplace

copy "$gic_libro" "$gic_out/gic_paper.xlsx", replace

*==============================================================================*
* 6. CIERRE
*==============================================================================*

di as res _n "{hline 78}"
di as res "GIC del paper: `hechas' de `n' curvas"
if ("`faltantes'" != "") di as err "Sin calcular:`faltantes'"
di as res "Libro: $gic_out/gic_paper.xlsx"
di as res "Base : $gic_out/gic_paper.dta"
di as res "{hline 78}"

*==============================================================================*
* SIMULACIÓN: ¿QUÉ HUBIESE PASADO CON EL EMPLEO ADECUADO SI EL CRITERIO         *
* DE INGRESO HUBIERA SIDO EL SBU DE 2025 DEFLACTADO POR IPC?                    *
*                                                                                *
* Lógica:                                                                        *
* 1) Construir IPC promedio anual a partir de la serie histórica mensual del    *
*    INEC (hoja "1. ÍNDICE", base empalmada 2014=100).                          *
* 2) Calcular factor de deflactación: f_t = IPC_t / IPC_2025                    *
* 2b) Llevar el umbral simulado a la moneda de cada año (sucres hasta 1999) con *
*    el factor fijo de la dolarización, 25.000 S/$. Los ingresos NO se          *
*    convierten: quedan como los levantó la encuesta. El IPC es un índice y no  *
*    cambia la unidad monetaria, así que el cruce de moneda necesita ese factor *
*    y tiene que ser uno solo para toda la serie.                               *
* 3) Salario mínimo simulado en cada año: smin_sim_t = SBU_2025 * f_t           *
* 4) Reconstruir el indicador de empleo adecuado replicando exactamente la      *
*    lógica original, pero sustituyendo el umbral salarial vigente por el       *
*    SBU 2025 deflactado a precios del año t.                                   *
* 5) Comparar serie histórica oficial (adec) vs. serie simulada (adec_sim).     *
*==============================================================================*

clear all
set more off
capture log close

*------------------------------------------------------------------------------*
* 0. RUTAS
*------------------------------------------------------------------------------*
global user_root_drive "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases     "$user_root_drive/Bases"
global raw       "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios  "$bases/Salarios"
global ipc       "$bases/IPC"
global out       "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot  "$out"
global excel     "$out/serie_adec_pea_1991_2025.xlsx"

* SBU vigente en 2025 (USD). Ajustar si corresponde.
scalar sbu_2025 = 470

* Equivalencia sucre/dólar de la dolarización: el 13 de marzo de 2000 todos los
* precios, sueldos y contratos en sucres se convirtieron a 25.000 por dólar. Es
* el ÚNICO factor con que se cruza la frontera de moneda en este script, y va
* sobre el umbral simulado, no sobre los ingresos (ver sección 1c).
scalar tc_dolarizacion = 25000


*==============================================================================*
* 1. CONSTRUIR DEFLACTOR ANUAL (BASE 2025)                                      
*==============================================================================*

* La hoja "1. ÍNDICE" del INEC viene en formato wide:
*   col A = año, cols B..M = Enero..Diciembre
* Encabezados ocupan filas 1-4 ("ÍNDICE GENERAL NACIONAL", "MESES", etc.).
* Los datos comienzan en la fila 6 (1969) y llegan hasta 2025 (incompleto).

* Datos: filas 6..62 = años 1969..2025 (todos los meses completos).
* La fila 63 corresponde a 2026 (parcial) y se excluye del rango.
import excel "$ipc/SERIE HISTORICA IPC_03_2026.xls", ///
    sheet("1. ÍNDICE") cellrange(A6:M62) clear

rename A     anio
rename B     m01
rename C     m02
rename D     m03
rename E     m04
rename F     m05
rename G     m06
rename H     m07
rename I     m08
rename J     m09
rename K     m10
rename L     m11
rename M     m12

destring anio m01-m12, replace force
drop if missing(anio)

* Promedio del último trimestre (octubre, noviembre, diciembre)
egen ipc_anual = rowmean(m10 m11 m12)
keep anio ipc_anual

* IPC base 2025 = 1
sum ipc_anual if anio == 2025, meanonly
scalar ipc_2025 = r(mean)
gen ipc_base2025 = ipc_anual / ipc_2025

* Salario mínimo de 2025 traído a precios de cada año
gen salario_min_sim = sbu_2025 * ipc_base2025

label variable ipc_anual       "IPC general nacional, promedio Oct-Dic (base 2014=100)"
label variable ipc_base2025    "IPC diciembre reescalado a base 2025"
label variable salario_min_sim "SBU 2025 ($`=sbu_2025') a precios Q4 del año t"

tempfile ipc_tmp
save `ipc_tmp', replace


*------------------------------------------------------------------------------*
* 1b. HISTÓRICO DEL SALARIO MÍNIMO VIGENTE (PARA COMPARACIÓN)                  *
*------------------------------------------------------------------------------*
* Replica el armado original: SBU diciembre (2000+) + SMV+bonificaciones (90s).

* SBU 2000-2025 (diciembre)
import delimited "$salarios/Salario unificado y componentes salariales.csv", clear
encode componentesalarial, gen(componente)
drop componentesalarial
keep if componente == 6 & mes == "Diciembre"
rename (anio valorsalariocomponenteendolares) (anio salario_min)
replace salario_min = subinstr(salario_min, ",", ".", .)
destring salario_min, replace
keep anio salario_min
tempfile sbu_post2000
save `sbu_post2000'

* SMV + bonificaciones (años 90s)
import delimited "$salarios/SMV + bonificaciones.csv", clear
keep in 12/21
rename (periodo total) (anio salario_min)
keep anio salario_min
destring anio, replace

* Unión: 90s + 2000+
append using `sbu_post2000'

tempfile sbu_hist
save `sbu_hist', replace


* Combinar IPC + histórico salarial + tipo de cambio
use `ipc_tmp', clear
merge 1:1 anio using `sbu_hist', nogen

recast double salario_min_sim
replace salario_min_sim = salario_min_sim * tc_dolarizacion if anio <= 1999

label variable salario_min     "SBU vigente del año, en la moneda del año"
label variable salario_min_sim "SBU 2025 deflactado, en la moneda del año"

list anio ipc_anual ipc_base2025 salario_min salario_min_sim, sep(0) noobs

tempfile deflactor
save `deflactor', replace


*==============================================================================*
* 2. RECONSTRUIR EMPLEO ADECUADO CON UMBRAL SIMULADO                            
*==============================================================================*

* Inicializar acumulador (estructura mínima)
use "$raw/empleo1990.dta" in 1, clear
destring area, replace
drop in 1
tempfile adec_acumulado
save `adec_acumulado', replace

log using "$user_root", text replace

foreach y of numlist 1991(1)2025 {

    di "*****************   `y'   ************************"

    quietly {

        scalar edadmin = 15

        use "$raw/empleo`y'.dta", clear

        * Trae salario_min_sim del año correspondiente
        merge m:m anio using `deflactor', keep(3) nogen

        cap gen t = 1
        cap rename t t_a

        if inrange(`y', 1990, 2006) {
            rename edad     edad
            rename trabajo  p20
            rename actayuda p21
            rename aunotra  p22
            rename hortrasa p24
            rename ratmeh   p25
            rename bustrama p32
            rename motnobus p34
            rename deseatra p35
            rename hortrahp p51a
            rename hortrahs p51b
            rename hortraho p51c
            if `y' >= 2001 rename hormas p27
        }

        if inrange(anio, 1990, 2000) {
            cap drop p27
            cap gen p27 = 2 if p20 == 1 | p22 == 1
            capture replace p27 = 1 if ratmeh1 != .
            capture replace p27 = 1 if hormas  != .
        }

	
        *--------- PET ---------*
        cap confirm variable petn
        if !_rc drop petn
        gen petn = .
        replace petn = 0 if edad <  edadmin
        replace petn = 1 if edad >= edadmin
        label variable petn "Población en Edad de Trabajar"

        *--------- PEA ---------*
        cap confirm variable pean
        if !_rc drop pean
        gen pean = .
        replace pean = 0 if petn == 1
        replace pean = 1 if petn == 1 & p20 == 1

        if anio >= 2007 {
            replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 <= 10
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 1
        }
        else if inrange(anio, 2001, 2006) {
            replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 10
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 2 & p34 <= 7 & p34 != 4 & p35 == 1
        }
        else {
            replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 2 & p34 >= 7 & p34 < . & p35 == 1
        }
        label variable pean "Población Económicamente Activa"

        *--------- EMPLEO ---------*
        cap confirm variable empleo
        if !_rc drop empleo
		
        gen empleo = .
        replace empleo = 0 if pean == 1
        replace empleo = 1 if pean == 1 & p20 == 1

        if inrange(anio, 2001, 2006) {
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 10
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
        }
        else {
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 11
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
        }
        label variable empleo "Población con Empleo"

        *--------- 1. INGRESO LABORAL ---------*
        * En doble precisión: en float, el redondeo del umbral simulado (que en
        * los 90s es un número grande, en sucres) desplaza el corte para quien
        * gana justo el umbral.
        gen double ila = ingrl

        * Códigos de no respuesta / valor atípico, año por año. Cada lista
        * reproduce exactamente la rama de ese año en
        *   "Boletín 1/Procesamiento/Codigos/Ingresos/ingresos_anios_all_fn.do",
        * tomando sólo los componentes que entran en el ingreso LABORAL: los
        * códigos de rentas, remesas y bono no se aplican aquí. No hay una lista
        * transversal: el juego de códigos cambia con el cuestionario.
        *
        *   1991       ingpat
        *   1992-1999  ingpat ingasg ingepv ingdom
        *   2000       ingpat retpat ingasa ingasa1 ingasa2 ingsec
        *   2001-2009  recode ingrl (-1 = .) (999999 = .)
        *   2006       pe61 pe62b pe63 pe64 pe65b pe66 pe67b
        *   2010-2025  p63 p64b p65 p66 p67 p68b p69 p70b, y recode ingrl 999999
        *
        * 2002 y 2004 no tienen rama propia en ese script; se les aplica la de
        * los años vecinos (2001/2003/2005), que es idéntica entre sí.
        *
        * Sustituye a los topes nominales fijos "ila >= 900000" (90s) y
        * "ila >= 90000" (2000+). En sucres un tope fijo no es neutro: el SBU de
        * diciembre pasa de 94.333 (1991) a 596.667 (1999), así que 900.000 cae
        * de 9,5 a 1,5 veces el umbral y llegaba a anular al 47 % de los
        * ocupados en 1999. Como los no clasificables cuentan como no adecuados,
        * eso hundía artificialmente la serie de los 90s.
        *
        * Se decide con el local `y' y no con la variable anio: en un comando if
        * Stata evalúa sólo la primera observación.
        local invalidos ""
        if `y' == 1991                  local invalidos "9999998"
        if inrange(`y', 1992, 1999)     local invalidos "9999998 9999999 99999999"
        if `y' == 2000                  local invalidos "-1 9999 10000 99999 999999 9999999 39999999 89999999 99999999"
        if inrange(`y', 2001, 2005)     local invalidos "-1 999999"
        if `y' == 2006                  local invalidos "-1 999 9999 22150 99999 999999"
        if inrange(`y', 2007, 2009)     local invalidos "-1 999999"
        if `y' >= 2010                  local invalidos "-1 999999"

        foreach c of local invalidos {
            replace ila = . if ila == `c'
        }

        gen ineg = .
        replace ineg = 1 if ingrl == -1

        * UMBRAL DE INGRESO BASADO EN SBU 2025 DEFLACTADO
        gen w_sim = .
        replace w_sim = 0 if empleo == 1 & ila <  salario_min_sim
        replace w_sim = 1 if empleo == 1 & ila >= salario_min_sim & ila != .
        replace w_sim = . if ila == .
        label variable w_sim "Umbral de ingreso laboral (SBU 2025 deflactado)"
        label define w_lbl 0 "menor" 1 "mayor", replace
        label values w_sim w_lbl

        *--------- 2. TIEMPO DE TRABAJO ---------*
        * 999 = no responde también en p24 (hortrasa), no sólo en p51a-p51c.
        * Hay que limpiarlo ANTES de volcarlo en horas: si no, esas personas
        * quedan con 999 horas y por tanto con t = 1 (jornada completa).
        replace p24 = . if p24 == 999

        gen horas = .
        replace horas = 0 if empleo == 1
        replace horas = p24 if pean == 1 & p20 == 1
        if inrange(anio, 2001, 2006) replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 10
        else                         replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 11

        replace p51a = . if p51a == 999
        replace p51b = . if p51b == 999
        replace p51c = . if p51c == 999

        egen hh = rowtotal(p51a p51b p51c), missing
        replace hh = . if hh < 0

        if inrange(anio, 2001, 2006) {
            replace horas = hh if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
        }
        else {
            replace horas = hh if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
        }
        label variable horas "Horas de trabajo semanal"

        capture drop t
        gen t = .
        replace t = 0 if empleo == 1 & horas <  40
        replace t = 1 if empleo == 1 & horas >= 40 & horas != .
        replace t = 0 if empleo == 1 & horas <  30 & edad >= 12 & edad <= 17
        replace t = 1 if empleo == 1 & horas >= 30 & edad >= 12 & edad <= 17
        label variable t "Umbral de horas trabajadas"

        *--------- 3. DESEO Y DISPONIBILIDAD ---------*
        gen d_d = .
        replace d_d = 0 if empleo == 1

        if anio >= 2007 {
            replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
            replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
        }
        else if inrange(anio, 2001, 2006) {
            replace d_d = 0 if empleo == 1 & p27 == 2
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        else if inrange(anio, 1993, 2000) {
            replace d_d = 0 if empleo == 1 & (p25 == 3 | p27 == 2)
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        else {
            replace d_d = 0 if empleo == 1 & (p25 == 2 | p27 == 2)
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        label variable d_d "Deseo y disponibilidad de trabajar horas adicionales"
        label define d_d_lbl 0 "No desea" 1 "Si desea y está disponible", replace
        label values d_d d_d_lbl

        *--------- EMPLEO ADECUADO OFICIAL (umbral SBU vigente) ---------*
        * salario_min viene del deflactor (histórico SBU armado en sección 1b).
        gen w_off = .
        replace w_off = 0 if empleo == 1 & ila <  salario_min
        replace w_off = 1 if empleo == 1 & ila >= salario_min & ila != .
        replace w_off = . if ila == .
		
		cap confirm variable adec
		if !_rc drop adec

        gen adec = .
        replace adec = 0 if pean == 1 & edad >= edadmin
        replace adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w_off == 1 & t == 1
        replace adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w_off == 1 & t == 0 & d_d == 0
        label variable adec "Empleo adecuado (umbral SBU vigente)"

        *--------- EMPLEO ADECUADO SIMULADO ---------*
        gen adec_sim = .
        replace adec_sim = 0 if pean == 1 & edad >= edadmin
        replace adec_sim = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w_sim == 1 & t == 1
        replace adec_sim = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w_sim == 1 & t == 0 & d_d == 0
        label variable adec_sim "Empleo adecuado simulado (umbral = SBU 2025 deflactado)"

    }

	cap confirm variable condactn 
	if   !_rc local condact_var condactn
	else      local condact_var condact
	decode `condact_var', gen(condact_str)

	replace adec = 0 if condact_str == "Otro empleo no pleno"

	
    capture confirm variable area
    if !_rc {
        local area_var area
        destring area, replace
    }
    else local area_var

    * Conservamos ambas series (oficial y simulada) y ambos umbrales salariales
    keep id_persona anio `area_var' d_d t w_off ila  pean salario_min salario_min_sim adec adec_sim fexp

    append using `adec_acumulado'
    save `adec_acumulado', replace

    sum adec adec_sim
}

save "$out/historico_adec_sim.dta", replace
s
use "$out/historico_adec_sim.dta", clear

tab anio adec [iw = fexp], nofreq row

tab anio d_d [iw = fexp], nofreq row

s

tabstat adec adec_sim, by(anio) statistics(mean)



*==============================================================================*
* EMPLEO ADECUADO Y SUS COMPONENTES                                     
*==============================================================================*


* Colapsar los datos para obtener la media de cada variable por año
preserve

collapse (mean) mean_w_off=w_off mean_adec=adec mean_dd=d_d mean_t=t, by(anio)

* Panel 1: w_off
twoway (line mean_w_off anio, lcolor(navy) lwidth(medthick)), ///
    ytitle("Proporción (media)") ///
    xtitle("Año") ///
    title("w_off") ///
    ylabel(, format(%9.2f)) ///
    graphregion(color(white)) ///
    name(g_w_off, replace)

* Panel 2: adec
twoway (line mean_adec anio, lcolor(maroon) lwidth(medthick)), ///
    ytitle("Proporción (media)") ///
    xtitle("Año") ///
    title("adec") ///
    ylabel(, format(%9.2f)) ///
    graphregion(color(white)) ///
    name(g_adec, replace)

* Panel 3: dd
twoway (line mean_dd anio, lcolor(forest_green) lwidth(medthick)), ///
    ytitle("Proporción (media)") ///
    xtitle("Año") ///
    title("dd") ///
    ylabel(, format(%9.2f)) ///
    graphregion(color(white)) ///
    name(g_dd, replace)

* Panel 4: t
twoway (line mean_t anio, lcolor(orange) lwidth(medthick)), ///
    ytitle("Proporción (media)") ///
    xtitle("Año") ///
    title("t") ///
    ylabel(, format(%9.2f)) ///
    graphregion(color(white)) ///
    name(g_t, replace)

* Combinar los cuatro paneles en una sola imagen (2x2)
graph combine g_w_off g_adec g_dd g_t, ///
    cols(2) ///
    graphregion(color(white)) ///
    title("Evolución de las variables en el tiempo")

* Guardar el gráfico combinado
graph export "C:\Users\santy\Videos\Respaldos\Desktop\Programas de trabajo\evolucion_variables_paneles.png", replace width(2000)

restore




*==============================================================================*
* 3. COMPARACIÓN: SERIE OFICIAL vs SIMULADA                                     
*==============================================================================*

use "$out/historico_adec_sim.dta", clear
replace area = 1 if area == .

* Promedios nacionales y urbanos
preserve
    collapse (mean) adec adec_sim, by(anio area)
    keep if area == 1
    rename (adec adec_sim) (adec_urb adec_sim_urb)
    tempfile urb
    save `urb'
restore

collapse (mean) adec adec_sim if anio != 2002, by(anio)
rename (adec adec_sim) (adec_nac adec_sim_nac)
merge 1:1 anio using `urb', nogen
sort anio

format adec_nac adec_sim_nac adec_urb adec_sim_urb %9.3f
list anio adec_urb adec_sim_urb adec_nac adec_sim_nac, sep(0) noobs


* Gráfico comparativo
twoway (line adec_nac     anio , lcolor(navy)   lpattern(dash)) ///
       (line adec_sim_nac anio , lcolor(maroon)), ///
    legend(order(1 "Oficial - Nacional" 2 "Simulado SBU 2025 - Nacional") ///
           rows(2) size(small)) ///
    yscale(range(0 1)) ylabel(0(0.1)1, format(%9.1f)) ///
    ytitle("Tasa de empleo adecuado") xtitle("") ///
    title("Empleo adecuado: oficial vs. simulado con SBU 2025 deflactado") ///
    note("Umbral simulado = SBU 2025 (USD `=sbu_2025') deflactado por IPC promedio Oct-Dic, nacional (base 2014=100).")

graph export "$out_plot/historico_adec_sim_vs_oficial.pdf", replace


*==============================================================================*
* 4. SERIE AGREGADA Y EXPORTACIÓN A EXCEL
*==============================================================================*
* Una fila por año con las dos tasas (vigente y simulada) para el total nacional
* y para el área urbana. El denominador es la PEA: adec vale 0 para todo el que
* está en la PEA y no cumple las condiciones, así que los desempleados cuentan
* como no adecuados. Es otro denominador que el de "3. Analisis/analisis_
* descriptivo.do", que pone adec = . para desocupados e inactivos y por tanto
* calcula la tasa sobre OCUPADOS (sale entre 1 y 3 pp más alta).
*
* Hasta 1999 la ENEMDU de diciembre es urbana y no trae la variable area: en
* esos años la columna Nacional queda vacía en vez de repetir el dato urbano.

use "$out/historico_adec_sim.dta", clear

gen byte _nac = !missing(area)
gen byte _urb = (area == 1) if !missing(area)
replace  _urb = 1 if missing(area) & anio <= 1999

foreach a in nac urb {

    preserve
        qui keep if _`a' == 1

        * el número de observaciones va sin ponderar; con [iw=] la opción
        * (count) de collapse devuelve la suma de pesos, no el conteo
        tempfile n_`a'
        qui collapse (count) n_pea_`a' = adec, by(anio)
        qui save `n_`a''
    restore

    preserve
        qui keep if _`a' == 1
        qui collapse (mean) adec_`a' = adec (mean) adec_sim_`a' = adec_sim [iw = fexp], by(anio)
        qui replace adec_`a'     = 100 * adec_`a'
        qui replace adec_sim_`a' = 100 * adec_sim_`a'
        qui merge 1:1 anio using `n_`a'', nogen
        tempfile serie_`a'
        qui save `serie_`a''
    restore
}

use `serie_nac', clear
merge 1:1 anio using `serie_urb', nogen
sort anio

order anio adec_nac adec_urb adec_sim_nac adec_sim_urb n_pea_nac n_pea_urb

label variable anio         "Año"
label variable adec_nac     "Empleo adecuado, nacional (% PEA)"
label variable adec_urb     "Empleo adecuado, urbano (% PEA)"
label variable adec_sim_nac "Empleo adecuado simulado, nacional (% PEA)"
label variable adec_sim_urb "Empleo adecuado simulado, urbano (% PEA)"
label variable n_pea_nac    "Observaciones en la PEA, nacional"
label variable n_pea_urb    "Observaciones en la PEA, urbano"

format adec_nac adec_urb adec_sim_nac adec_sim_urb %8.2f

di as txt _n "{hline 72}"
di as txt "EMPLEO ADECUADO SOBRE LA PEA"
di as txt "{hline 72}"
list anio adec_nac adec_urb adec_sim_nac adec_sim_urb, sep(0) noobs

export excel using "$excel", sheet("Serie") firstrow(varlabels) replace
di as txt _n "Serie exportada a: $excel"

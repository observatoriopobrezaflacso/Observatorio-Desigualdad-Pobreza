*==============================================================================*
* SIMULACIÓN: ¿QUÉ HUBIESE PASADO CON EL EMPLEO ADECUADO SI EL CRITERIO         *
* DE INGRESO HUBIERA SIDO EL SBU DE 2025 DEFLACTADO POR IPC?                    *
*                                                                                *
* Lógica:                                                                        *
* 1) Construir IPC promedio anual a partir de la serie histórica mensual del    *
*    INEC (hoja "1. ÍNDICE", base empalmada 2014=100).                          *
* 2) Calcular factor de deflactación: f_t = IPC_t / IPC_2025                    *
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
global user_root_drive "H:\Mi unidad"
global bases     "$user_root_drive/Bases"
global raw       "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios  "$bases/Salarios"
global ipc       "$bases/IPC"
global out       "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot  "$out"

* SBU vigente en 2025 (USD). Ajustar si corresponde.
scalar sbu_2025 = 470


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
label variable ipc_base2025    "IPC Q4 reescalado a base 2025 Q4=1"
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

* Combinar IPC + histórico salarial
use `ipc_tmp', clear
merge 1:1 anio using `sbu_hist', nogen

label variable salario_min "SBU vigente del año (histórico)"

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
            if `y' >= 2000 rename hormas p27
        }

        if inrange(anio, 1990, 1999) {
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
        else if inrange(anio, 2000, 2006) {
            replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 10
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 2 & p34 <= 7 & p34 != 4 & p35 == 1
        }
        else {
            replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 1
            replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 2 & p34 >= 7 & p35 == 1
        }
        label variable pean "Población Económicamente Activa"

        *--------- EMPLEO ---------*
        cap confirm variable empleo
        if !_rc drop empleo
        gen empleo = .
        replace empleo = 0 if pean == 1
        replace empleo = 1 if pean == 1 & p20 == 1

        if inrange(anio, 2000, 2006) {
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 10
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
        }
        else {
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 11
            replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
        }
        label variable empleo "Población con Empleo"

        *--------- 1. INGRESO LABORAL ---------*
        gen ila = ingrl
        replace ila = . if inlist(ila, -1, 999999)
        if inrange(anio, 1990, 1999) replace ila = . if ila >= 900000
        else                         replace ila = . if ila >= 90000

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
        gen horas = .
        replace horas = 0 if empleo == 1
        replace horas = p24 if pean == 1 & p20 == 1
        if inrange(anio, 2000, 2006) replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 10
        else                         replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 11

        replace p51a = . if p51a == 999
        replace p51b = . if p51b == 999
        replace p51c = . if p51c == 999

        egen hh = rowtotal(p51a p51b p51c), missing
        replace hh = . if hh < 0

        if inrange(anio, 2000, 2006) {
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
        else if inrange(anio, 2000, 2006) {
            replace d_d = 0 if empleo == 1 & p27 == 2
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        else if inrange(anio, 1993, 1999) {
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
    keep id_persona anio `area_var' ila salario_min salario_min_sim adec adec_sim fexp

    append using `adec_acumulado'
    save `adec_acumulado', replace

    sum adec adec_sim
}

save "$out/historico_adec_sim.dta", replace


use "$out/historico_adec_sim.dta", clear

tab anio adec [iw = fexp], nofreq row

/*
s
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
twoway (line adec_nac     anio if anio >= 2000, lcolor(navy)   lpattern(dash)) ///
       (line adec_sim_nac anio if anio >= 2000, lcolor(maroon)), ///
    legend(order(1 "Oficial - Nacional" 2 "Simulado SBU 2025 - Nacional") ///
           rows(2) size(small)) ///
    yscale(range(0 1)) ylabel(0(0.1)1, format(%9.1f)) ///
    ytitle("Tasa de empleo adecuado") xtitle("") ///
    title("Empleo adecuado: oficial vs. simulado con SBU 2025 deflactado") ///
    note("Umbral simulado = SBU 2025 (USD `=sbu_2025') deflactado por IPC promedio Oct-Dic, nacional (base 2014=100).")

graph export "$out_plot/historico_adec_sim_vs_oficial.pdf", replace


*/

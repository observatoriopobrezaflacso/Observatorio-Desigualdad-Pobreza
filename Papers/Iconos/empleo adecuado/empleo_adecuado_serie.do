*==============================================================================*
* EMPLEO ADECUADO, ENEMDU DE DICIEMBRE 1991-2025: SERIE ARMONIZADA
*
* Versión revisada de
*   "Boletín 3/1. Infomalidad/2. Armonización de variables/main/componentes/adec.do"
*
* Produce, para cada año y ámbito (nacional / urbano):
*   adec     = empleo adecuado armonizado, umbral = SBU vigente de diciembre
*   adec_of  = clasificación oficial de la ENEMDU (condact/condactn), referencia
* y exporta la serie y su diagnóstico a Excel.
*
* Estructura:
*   0. Rutas y opciones          3. Cálculo de la serie
*   1. Deflactor IPC             4. Exportación a Excel
*   2. Umbral salarial           5. Gráfico
*
* El IPC no interviene en la construcción del indicador: se usa sólo para
* expresar el umbral vigente de cada año en dólares constantes de 2025, que es
* un dato necesario para leer la serie (el criterio de suficiencia de ingresos
* se vuelve más exigente en términos reales a lo largo del período).
*==============================================================================*
*
*------------------------------------------------------------------------------*
* CORRECCIONES RESPECTO DE main/componentes/adec.do                            *
*------------------------------------------------------------------------------*
*
* C1. rename año -> el CSV de salarios trae la columna como "anio" (ASCII), no
*     como "año": el rename original aborta con r(111) y el script no llega a
*     correr. Aquí se detectan ambas formas.
*
* C2. EL AJUSTE POR condact ES NECESARIO Y HAY QUE CUBRIR LAS DOS ETIQUETAS.
*     "replace adec = 0 if condact_str == 'Otro empleo no pleno'" es el ajuste
*     residual que hace que la serie armonizada reproduzca exactamente la
*     clasificación oficial en 2022-2025. Antes de 2022 no afecta a ningún caso,
*     porque la construcción ya clasifica a esas personas como no adecuadas.
*     El problema del original es que la etiqueta cambia de nombre entre años:
*       - 1991-2006: la codificación es "ocupados plenos"/"subempleo visible"/...
*                    y la categoría no existe;
*       - 2007-2015: condactn dice "Otro empleo Inadecuado";
*       - 2016-2025: dice "Otro empleo no pleno".
*     Aquí se reconocen ambas variantes. Verificado: con este ajuste la serie
*     coincide con adec_of hasta el cuarto decimal en todo 2007-2025.
*
* C3. merge m:m anio using <salarios>, keep(3) -> eliminado. Verificado que NO
*     truncaba la base (el using tiene una fila por año y Stata difunde el
*     valor), pero es innecesario: los umbrales se pasan como locales.
*
* C4. CÓDIGOS 999 EN HORAS. El original sólo limpiaba p51a/p51b/p51c. p24
*     (hortrasa) también trae 999 = no responde en 1991-2007 (hasta 13 casos en
*     1993). Sin limpiar, esas personas quedaban con horas = 999 -> t = 1.
*
* C5. MISSING EN COMPARACIONES ABIERTAS. En Stata . > cualquier número:
*       - "p34 >= 7" (rama PEA de los 90s) era verdadero con p34 missing;
*       - "horas >= 30" (jornada de 12-17 años) era verdadero con horas missing.
*     Se acotan ambas con "< .".
*
* C6. RAMIFICACIÓN POR PERÍODO. El original mezclaba if inrange(`y', ...) con
*     if inrange(anio, ...). anio es una VARIABLE y en un comando if Stata
*     evalúa sólo la primera observación. Aquí todo se decide con el local `y'.
*
* C7. HORAS DESCONOCIDAS. "replace horas = 0 if empleo == 1" hacía que quien no
*     tenía dato de horas terminara con t = 0 y, si w == 1 y d_d == 0, fuera
*     clasificado como ADECUADO. Por defecto quedan en missing (no adecuado);
*     $horas_legacy = 1 reproduce el comportamiento anterior. Sólo afecta a
*     1991-2006 y como mucho a un 0,6 % de los ocupados (columna p_sin_horas);
*     de 2007 en adelante no hay ningún caso, así que no altera el empate con
*     la serie oficial.
*
* C8. El acumulador se inicializaba con "use empleo1990 in 1" + "drop in 1" y el
*     append arrastraba las 94 variables de esa base al archivo final (99
*     variables en vez de 8). Aquí la serie se arma con postfile.
*
* C9. keep in 12/21 sobre "SMV + bonificaciones.csv" es indexación posicional.
*     Verificado que hoy devuelve el bloque "A DICIEMBRE" 1990-1999, que es el
*     correcto, pero aquí el bloque se localiza por contenido.
*
*------------------------------------------------------------------------------*
* VERIFICADO Y CONSERVADO (no eran errores)                                    *
*------------------------------------------------------------------------------*
* - cellrange(A6:M62) de la hoja "1. ÍNDICE" = 1969-2025 completos. Correcto.
* - componente == 6 = "Remuneraciones unificadas". Correcto.
* - rename edad edad no genera error (Stata lo acepta como no-op).
* - Denominador = PEA y los no clasificables cuentan como no adecuados: es la
*   convención de la tasa oficial. Se reporta cuánto pesan (hoja Sensibilidad).
*==============================================================================*

clear all
set more off
set linesize 200
capture log close

*------------------------------------------------------------------------------*
* 0. RUTAS Y OPCIONES
*------------------------------------------------------------------------------*

* Raíz del Google Drive: Windows (H:) o macOS.
if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global bases    "$gd/Bases"
global raw      "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global salarios "$bases/Salarios"
global ipc      "$bases/IPC"
global out      "$gd/Papers/Íconos/outputs/empleo adecuado"

capture mkdir "$gd/Papers/Íconos/outputs"
capture mkdir "$out"

global anio_ini 1991
global anio_fin 2025

* 1 = horas desconocidas valen 0, como en el script original (ver C7).
global horas_legacy 0

* 1 = aplicar el ajuste residual por condact (ver C2). Apagarlo desalinea la
*     serie respecto de la clasificación oficial en 2022-2025.
global ajuste_condact 1

global excel "$out/serie_empleo_adecuado_${anio_ini}_${anio_fin}.xlsx"

scalar edadmin = 15


*==============================================================================*
* 1. DEFLACTOR: IPC PROMEDIO OCTUBRE-DICIEMBRE, BASE 2025 Q4 = 1
*==============================================================================*
* Se usa el promedio del cuarto trimestre (no el de los 12 meses) porque el
* umbral es el SBU de DICIEMBRE. Sirve únicamente para expresar ese umbral en
* dólares constantes de 2025 (columna smin_real2025).
* Hoja "1. ÍNDICE", formato wide: col A = año, cols B..M = enero..diciembre.
* Encabezados en las filas 1-5; los datos van de la fila 6 (1969) a la 62 (2025).
* La fila 63 es 2026, incompleta, y queda fuera del rango.

import excel "$ipc/SERIE HISTORICA IPC_03_2026.xls", ///
    sheet("1. ÍNDICE") cellrange(A6:M62) clear

rename A anio
rename (B C D E F G H I J K L M) ///
       (m01 m02 m03 m04 m05 m06 m07 m08 m09 m10 m11 m12)

destring anio m01-m12, replace force
drop if missing(anio)

* control: el rango debe cubrir 1969-2025 sin huecos
qui sum anio
if r(min) != 1969 | r(max) != 2025 | r(N) != 57 {
    di as error "El rango A6:M62 ya no corresponde a 1969-2025 (min=" r(min) ///
                ", max=" r(max) ", N=" r(N) "). Revisar el archivo de IPC."
    exit 459
}

egen ipc_q4 = rowmean(m10 m11 m12)
keep anio ipc_q4

sum ipc_q4 if anio == 2025, meanonly
scalar ipc_2025 = r(mean)
gen double ipc_base2025 = ipc_q4 / ipc_2025

label variable ipc_q4       "IPC nacional, promedio oct-dic (base 2014 = 100)"
label variable ipc_base2025 "IPC oct-dic reescalado a 2025 = 1"

tempfile ipc_tmp
save `ipc_tmp', replace


*==============================================================================*
* 2. UMBRAL SALARIAL VIGENTE (SBU DE DICIEMBRE)
*==============================================================================*

*--- 2000-2025: SBU = "Remuneraciones unificadas", diciembre, USD -------------*
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html
import delimited "$salarios/Salario unificado y componentes salariales.csv", clear

* la columna del año viene como "anio" o como "año" según la descarga (C1)
capture confirm variable anio
if _rc {
    capture rename año anio
    if _rc {
        di as error "No se encontró la columna del año en el archivo de salarios."
        exit 459
    }
}

keep if strtrim(componentesalarial) == "Remuneraciones unificadas" ///
       & strtrim(mes) == "Diciembre"
rename valorsalariocomponenteendolares salario_min
replace salario_min = subinstr(salario_min, ",", ".", .)
destring salario_min anio, replace force
keep anio salario_min
drop if missing(anio) | missing(salario_min)
bysort anio: keep if _n == 1
tempfile sbu_usd
save `sbu_usd'

*--- 1990-1999: SMV + bonificaciones, TOTAL a diciembre, sucres ---------------*
* https://contenido.bce.fin.ec/documentos/PublicacionesNotas/Catalogo/IEMensual/
* El archivo trae primero el promedio anual y después un bloque "A DICIEMBRE".
* Se localiza ese bloque por contenido en vez de por posición (C9).
import delimited "$salarios/SMV + bonificaciones.csv", ///
        varnames(nonames) stringcols(_all) clear

gen long _row = _n
gen byte _dic = (strtrim(v1) == "A DICIEMBRE")
qui sum _row if _dic, meanonly
if r(N) == 0 {
    di as error "No se encontró el bloque 'A DICIEMBRE' en 'SMV + bonificaciones.csv'."
    exit 459
}
local fila_dic = r(min)

keep if _row > `fila_dic'
keep if regexm(strtrim(v1), "^[0-9][0-9][0-9][0-9]$")
gen int anio = real(strtrim(v1))
keep if inrange(anio, 1990, 1999)
replace v10 = subinstr(strtrim(v10), ",", "", .)
destring v10, gen(salario_min) force
keep anio salario_min
drop if missing(salario_min)
bysort anio: keep if _n == 1
tempfile sbu_sucres
save `sbu_sucres'

*--- tabla única de umbrales --------------------------------------------------*
use `sbu_usd', clear
append using `sbu_sucres'
merge 1:1 anio using `ipc_tmp', keep(2 3) nogen
sort anio
keep if inrange(anio, $anio_ini, $anio_fin)

gen str8 moneda = cond(anio < 2000, "sucres", "USD")

* umbral vigente expresado en dólares constantes de 2025 (sólo era dolarizado)
gen double smin_real2025 = salario_min / ipc_base2025 if anio >= 2000

label variable salario_min   "SBU vigente de diciembre (sucres <=1999, USD >=2000)"
label variable smin_real2025 "SBU vigente de diciembre, en USD de 2025"
label variable moneda        "Moneda del umbral y del ingreso"

di as txt _n "{hline 78}"
di as txt "UMBRALES POR AÑO"
di as txt "{hline 78}"
format salario_min smin_real2025 %14.2fc
format ipc_base2025 %8.4f
list anio moneda ipc_base2025 salario_min smin_real2025, sep(0) noobs

* control: ningún año del rango puede quedarse sin umbral vigente
qui count if missing(salario_min)
if r(N) > 0 {
    di as error "Hay `r(N)' año(s) sin SBU vigente; se calcularían tasas nulas."
    list anio if missing(salario_min), noobs
    exit 459
}

* a globals, para no depender de un merge dentro del loop (C3)
levelsof anio, local(anios_umbral)
foreach a of local anios_umbral {
    qui sum salario_min   if anio == `a', meanonly
    global smin_`a'  = r(mean)
    qui sum smin_real2025 if anio == `a', meanonly
    global sreal_`a' = cond(r(N) > 0, r(mean), .)
}

tempfile umbrales
save `umbrales', replace


*==============================================================================*
* 3. CÁLCULO DE LA SERIE
*==============================================================================*

tempname P
tempfile resultados

postfile `P' int anio str3 muestra str8 moneda                          ///
        double smin double smin_real2025                                ///
        double adec double adec_of double adec_sin_ajuste               ///
        double adec_cond double w_tasa double t_tasa                    ///
        long n_pea double pea_exp                                       ///
        double p_sin_ingreso double p_sin_horas                         ///
        long n_h999 long n_ajuste str32 var_condact str24 estado        ///
        using `resultados', replace

foreach y of numlist $anio_ini/$anio_fin {

    di as txt _n "{hline 60}"
    di as txt "  `y'"
    di as txt "{hline 60}"

    local estado "ok"
    capture confirm file "$raw/empleo`y'.dta"
    if _rc {
        di as error "  sin base"
        local estado "sin base"
    }

    if "`estado'" == "ok" {

        qui use "$raw/empleo`y'.dta", clear

        *----------------------------------------------------------------------*
        * 3.1 Nombres estándar p## (las bases 1991-2006 traen los nombres viejos)
        *----------------------------------------------------------------------*
        if `y' <= 2006 {
            capture rename trabajo  p20
            capture rename actayuda p21
            capture rename aunotra  p22
            capture rename hortrasa p24
            capture rename ratmeh   p25
            capture rename bustrama p32
            capture rename motnobus p34
            capture rename deseatra p35
            capture rename hortrahp p51a
            capture rename hortrahs p51b
            capture rename hortraho p51c
            if `y' >= 2000 capture rename hormas p27
        }

        * variables ausentes en algunos años: crearlas vacías para poder usarlas
        foreach v in p24 p25 p27 p28 p32 p34 p35 p51a p51b p51c {
            capture confirm variable `v'
            if _rc qui gen `v' = .
        }

        local faltan ""
        foreach v in edad p20 p21 p22 ingrl fexp {
            capture confirm variable `v'
            if _rc local faltan "`faltan' `v'"
        }
        if "`faltan'" != "" {
            di as error "  faltan variables:`faltan'"
            local estado "faltan variables"
        }
    }

    if "`estado'" == "ok" {

    qui {

        *----------------------------------------------------------------------*
        * 3.2 p27 en 1991-1999: no se pregunta, se construye
        *     (1991-1992 tienen ratmeh1; 1993-1999 tienen hormas)
        *----------------------------------------------------------------------*
        if `y' <= 1999 {
            capture drop p27
            gen byte p27 = 2 if p20 == 1 | p22 == 1
            capture confirm variable ratmeh1
            if !_rc replace p27 = 1 if ratmeh1 < .
            capture confirm variable hormas
            if !_rc replace p27 = 1 if hormas  < .
        }

        *--- 999 = no responde en las variables de horas (C4) ---
        count if p24 == 999
        local n_h999 = r(N)
        foreach v in p24 p51a p51b p51c {
            replace `v' = . if `v' == 999
        }

        *--- indicadores de período, siempre sobre el local `y' (C6) ---
        local p00 = (`y' >= 2000 & `y' <= 2006)
        local p07 = (`y' >= 2007)

        * categoría "no realizó ninguna actividad" de p21
        local p21_no = cond(`p00', 11, 12)
        local p21_si = `p21_no' - 1

        *----------------------------------------------------------------------*
        * 3.3 Poblaciones de referencia
        *----------------------------------------------------------------------*
        capture drop petn
        gen byte petn = (edad >= edadmin) if edad < .
        label variable petn "Población en Edad de Trabajar"

        capture drop pean
        gen byte pean = 0 if petn == 1
        replace  pean = 1 if petn == 1 & p20 == 1
        replace  pean = 1 if petn == 1 & p20 == 2 & p21 <= `p21_si'
        replace  pean = 1 if petn == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1

        if `p07' {
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 <= 10
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 11 ///
                              & p34 <= 7 & p35 == 1
        }
        else if `p00' {
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 1
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 2 ///
                              & p34 <= 7 & p34 != 4 & p35 == 1
        }
        else {
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 1
            * C5: sin el tope "< ." la condición es verdadera con p34 missing
            replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 2 ///
                              & p34 >= 7 & p34 < . & p35 == 1
        }
        label variable pean "Población Económicamente Activa"

        capture drop empleo
        gen byte empleo = 0 if pean == 1
        replace  empleo = 1 if pean == 1 & p20 == 1
        replace  empleo = 1 if pean == 1 & p20 == 2 & p21 <= `p21_si'
        replace  empleo = 1 if pean == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1
        label variable empleo "Población con Empleo"

        *----------------------------------------------------------------------*
        * 3.4 Dimensión 1: ingreso laboral vs. SBU vigente
        *----------------------------------------------------------------------*
        capture drop ila
        gen double ila = ingrl
        replace ila = . if inlist(ila, -1, 999999)
        if `y' <= 1999 replace ila = . if ila >= 900000
        else           replace ila = . if ila >=  90000

        local smin = ${smin_`y'}

        capture drop w
        gen byte w = .
        replace  w = 0 if empleo == 1 & ila <  `smin'
        replace  w = 1 if empleo == 1 & ila >= `smin' & ila < .
        replace  w = . if ila >= .
        label variable w "Ingreso laboral >= SBU vigente"

        *----------------------------------------------------------------------*
        * 3.5 Dimensión 2: horas trabajadas
        *----------------------------------------------------------------------*
        capture drop horas
        gen double horas = .
        if $horas_legacy replace horas = 0 if empleo == 1     // C7

        * horas efectivas (trabajó la semana pasada)
        replace horas = p24 if pean == 1 & p20 == 1
        replace horas = p24 if pean == 1 & p20 == 2 & p21 <= `p21_si'

        * horas habituales (tiene empleo pero no trabajó)
        capture drop hh
        egen double hh = rowtotal(p51a p51b p51c), missing
        replace hh = . if hh < 0
        replace horas = hh if pean == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1
        label variable horas "Horas de trabajo semanal"

        capture drop t
        gen byte t = .
        replace  t = 0 if empleo == 1 & horas <  40
        replace  t = 1 if empleo == 1 & horas >= 40 & horas < .
        * jornada reducida de 12-17 años (C5: acotar horas < .)
        replace  t = 0 if empleo == 1 & horas <  30             & inrange(edad, 12, 17)
        replace  t = 1 if empleo == 1 & horas >= 30 & horas < . & inrange(edad, 12, 17)
        label variable t "Cumple la jornada laboral"

        *----------------------------------------------------------------------*
        * 3.6 Dimensión 3: deseo y disponibilidad de trabajar más horas
        *----------------------------------------------------------------------*
        capture drop d_d
        gen byte d_d = 0 if empleo == 1

        if `p07' {
            replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
            replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
        }
        else if `p00' {
            replace d_d = 0 if empleo == 1 & p27 == 2
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        else if `y' >= 1993 {
            replace d_d = 0 if empleo == 1 & (p25 == 3 | p27 == 2)
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        else {
            replace d_d = 0 if empleo == 1 & (p25 == 2 | p27 == 2)
            replace d_d = 1 if empleo == 1 & p27 == 1
        }
        label variable d_d "Desea y está disponible para trabajar más horas"

        *----------------------------------------------------------------------*
        * 3.7 Empleo adecuado
        *----------------------------------------------------------------------*
        capture drop adec
        gen byte adec = 0 if pean == 1 & edad >= edadmin
        replace  adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w == 1 & t == 1
        replace  adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0

        * se guarda la versión previa al ajuste, para poder dimensionarlo
        capture drop adec_sin_ajuste
        gen byte adec_sin_ajuste = adec

        *----------------------------------------------------------------------*
        * 3.8 Clasificación oficial de la base y ajuste residual (C2)
        *----------------------------------------------------------------------*
        local cvar ""
        foreach c in condactn condact {
            if "`cvar'" == "" {
                capture confirm variable `c'
                if !_rc local cvar "`c'"
            }
        }

        capture drop adec_of
        gen byte adec_of = .
        local n_ajuste = 0

        if "`cvar'" != "" {
            capture drop _cs
            capture decode `cvar', gen(_cs)
            if !_rc {
                replace _cs = strtrim(_cs)

                * la etiqueta del empleo adecuado cambia de nombre entre años
                gen byte _ofi = regexm(lower(_cs), ///
                    "^(ocupados plenos|empleo adecuado|empleo adecuado/pleno)$")
                replace adec_of = 0 if pean == 1
                replace adec_of = 1 if pean == 1 & _ofi == 1
                drop _ofi

                * "Otro empleo no pleno" (2016+) == "Otro empleo Inadecuado" (2007-2015)
                gen byte _aj = regexm(lower(_cs), "^otro empleo (no pleno|inadecuado)$")
                count if _aj == 1
                local n_ajuste = r(N)
                if $ajuste_condact replace adec = 0 if _aj == 1 & adec < .
                drop _aj
            }
        }
        label variable adec    "Empleo adecuado (umbral: SBU vigente)"
        label variable adec_of "Empleo adecuado según la condición de actividad de la base"

        *----------------------------------------------------------------------*
        * 3.9 Ámbitos
        *----------------------------------------------------------------------*
        local tiene_area = 0
        capture confirm variable area
        if !_rc {
            local tiene_area = 1
            capture destring area, replace
        }
    }

    * 1991-1999 no tienen variable area: la muestra es urbana por diseño
    local ambitos = cond(`tiene_area', "nac urb", "urb")

    foreach m of local ambitos {

        if "`m'" == "urb" & `tiene_area' local cond "if area == 1"
        else                             local cond ""

        qui {
            local adec_r = .
            local of_r   = .
            local sin_r  = .
            local cond_r = .
            local w_r    = .
            local t_r    = .
            local n_pea  = .
            local pea_e  = .
            local sin_i  = .
            local sin_h  = .

            capture sum adec `cond' [aw = fexp]
            if !_rc & r(N) > 0 {
                local adec_r = r(mean) * 100
                local n_pea  = r(N)
            }
            capture sum adec_of `cond' [aw = fexp]
            if !_rc & r(N) > 0 local of_r = r(mean) * 100
            capture sum adec_sin_ajuste `cond' [aw = fexp]
            if !_rc & r(N) > 0 local sin_r = r(mean) * 100
            capture sum w `cond' [aw = fexp]
            if !_rc & r(N) > 0 local w_r = r(mean) * 100
            capture sum t `cond' [aw = fexp]
            if !_rc & r(N) > 0 local t_r = r(mean) * 100

            * tasa excluyendo del denominador a los ocupados sin dato de ingreso
            * (la convención oficial los cuenta como NO adecuados)
            if "`cond'" == "" local ccl "if !(empleo == 1 & ila >= .)"
            else              local ccl "`cond' & !(empleo == 1 & ila >= .)"
            capture sum adec `ccl' [aw = fexp]
            if !_rc & r(N) > 0 local cond_r = r(mean) * 100

            if "`cond'" == "" local cpea "if pean == 1"
            else              local cpea "`cond' & pean == 1"
            sum fexp `cpea', meanonly
            local pea_e = cond(r(N) > 0, r(sum), .)

            if "`cond'" == "" local cemp "if empleo == 1"
            else              local cemp "`cond' & empleo == 1"
            sum fexp `cemp', meanonly
            local emp_e = cond(r(N) > 0, r(sum), .)

            sum fexp `cemp' & ila >= ., meanonly
            local aux = cond(r(N) > 0, r(sum), 0)
            local sin_i = cond(`emp_e' < . & `emp_e' > 0, `aux'/`emp_e'*100, .)

            sum fexp `cemp' & horas >= ., meanonly
            local aux = cond(r(N) > 0, r(sum), 0)
            local sin_h = cond(`emp_e' < . & `emp_e' > 0, `aux'/`emp_e'*100, .)
        }

        local mon   = cond(`y' < 2000, "sucres", "USD")
        local sreal = ${sreal_`y'}
        post `P' (`y') ("`m'") ("`mon'") (`smin') (`sreal')             ///
                 (`adec_r') (`of_r') (`sin_r') (`cond_r')               ///
                 (`w_r') (`t_r') (`n_pea') (`pea_e')                    ///
                 (`sin_i') (`sin_h') (`n_h999') (`n_ajuste')            ///
                 ("`cvar'") ("`estado'")

        di as txt "  `m': armonizado = " as res %5.2f `adec_r' as txt "%" ///
                  "   oficial = " as res %5.2f `of_r' as txt "%" ///
                  "   dif = " as res %6.4f `adec_r' - `of_r' as txt " pp"
    }
    }
    else {
        post `P' (`y') ("nac") ("") (.) (.) (.) (.) (.) (.) (.) (.) ///
                 (.) (.) (.) (.) (.) (.) ("") ("`estado'")
    }
}

postclose `P'


*==============================================================================*
* 4. EXPORTACIÓN A EXCEL
*==============================================================================*

use `resultados', clear
gen byte _o = (muestra == "urb")
sort anio _o
drop _o

gen double dif_oficial = adec - adec_of

label variable anio          "Año"
label variable muestra       "Ámbito (nac = nacional, urb = urbano)"
label variable moneda        "Moneda del ingreso y del umbral"
label variable smin          "SBU vigente de diciembre"
label variable smin_real2025 "SBU vigente de diciembre, en USD de 2025"
label variable adec          "Empleo adecuado, serie armonizada (% PEA)"
label variable adec_of       "Empleo adecuado según la condición de actividad de la base (% PEA)"
label variable dif_oficial   "Diferencia armonizada - oficial (pp)"
label variable adec_sin_ajuste "Empleo adecuado antes del ajuste por condact (% PEA)"
label variable adec_cond     "Empleo adecuado excluyendo a los no clasificables (% PEA clasificable)"
label variable w_tasa        "Ocupados con ingreso >= SBU vigente (%)"
label variable t_tasa        "Ocupados que cumplen la jornada (%)"
label variable n_pea         "Observaciones en la PEA"
label variable pea_exp       "PEA expandida"
label variable p_sin_ingreso "Ocupados sin dato de ingreso laboral (%)"
label variable p_sin_horas   "Ocupados sin dato de horas (%)"
label variable n_h999        "Casos con horas = 999 recodificados a missing"
label variable n_ajuste      "Casos en la categoría 'otro empleo no pleno/inadecuado'"
label variable var_condact   "Variable de condición de actividad usada"
label variable estado        "Estado del cálculo"

format adec adec_of adec_sin_ajuste adec_cond w_tasa t_tasa %6.2f
format p_sin_ingreso p_sin_horas %6.2f
format dif_oficial %8.4f
format smin smin_real2025 %14.2fc
format pea_exp %14.0fc

di as txt _n "{hline 78}"
di as txt "SERIE"
di as txt "{hline 78}"
list anio muestra adec adec_of dif_oficial n_pea estado, sep(0) noobs

* control: en 2007-2025 la serie armonizada debe reproducir la oficial
qui sum dif_oficial if anio >= 2007, meanonly
local maxdif = 0
qui gen double _ad = abs(dif_oficial)
qui sum _ad if anio >= 2007, meanonly
local maxdif = r(max)
drop _ad
di as txt _n "Máxima diferencia |armonizada - oficial| en 2007-2025: " ///
      as res %8.5f `maxdif' as txt " pp"
if `maxdif' > 0.01 di as error "  ATENCIÓN: la serie ya no empata con la oficial."

save "$out/serie_empleo_adecuado_${anio_ini}_${anio_fin}.dta", replace

preserve
    keep  anio muestra moneda smin smin_real2025 adec adec_of dif_oficial n_pea pea_exp
    order anio muestra moneda smin smin_real2025 adec adec_of dif_oficial n_pea pea_exp
    export excel using "$excel", sheet("Serie") firstrow(varlabels) replace
restore

preserve
    keep  anio muestra adec adec_sin_ajuste n_ajuste var_condact w_tasa t_tasa ///
          p_sin_ingreso p_sin_horas n_h999 estado
    order anio muestra adec adec_sin_ajuste n_ajuste var_condact w_tasa t_tasa ///
          p_sin_ingreso p_sin_horas n_h999 estado
    export excel using "$excel", sheet("Diagnostico") firstrow(varlabels) sheetmodify
restore

* Sensibilidad a la no respuesta de ingresos: la convención oficial cuenta como
* NO adecuado a quien no declara ingreso laboral. La brecha entre ambas
* columnas mide cuánto de la serie depende de esa convención.
preserve
    gen double brecha_norespuesta = adec_cond - adec
    label variable brecha_norespuesta "Diferencia (pp)"
    keep  anio muestra adec adec_cond brecha_norespuesta p_sin_ingreso
    order anio muestra adec adec_cond brecha_norespuesta p_sin_ingreso
    export excel using "$excel", sheet("Sensibilidad") firstrow(varlabels) sheetmodify
restore

preserve
    use `umbrales', clear
    keep  anio moneda ipc_base2025 salario_min smin_real2025
    order anio moneda ipc_base2025 salario_min smin_real2025
    label variable ipc_base2025 "IPC oct-dic, base 2025 = 1"
    export excel using "$excel", sheet("Umbrales") firstrow(varlabels) sheetmodify
restore

di as txt _n "Excel guardado en: $excel"


*==============================================================================*
* 5. GRÁFICO
*==============================================================================*

use "$out/serie_empleo_adecuado_${anio_ini}_${anio_fin}.dta", clear
keep anio muestra adec
reshape wide adec, i(anio) j(muestra) string

twoway (line adecurb anio, lcolor(navy)) ///
       (line adecnac anio, lcolor(maroon) lpattern(dash)), ///
    legend(order(1 "Urbano" 2 "Nacional") rows(1) size(small)) ///
    ylabel(0(10)70, format(%3.0f)) yscale(range(0 70)) ///
    ytitle("Empleo adecuado (% de la PEA)") xtitle("") ///
    xlabel($anio_ini(5)$anio_fin) ///
    xline(1999.5, lcolor(gs10) lpattern(shortdash)) ///
    title("Empleo adecuado, Ecuador", size(medium)) ///
    note("ENEMDU de diciembre (INEC), ponderada. 1991-1999 sólo cuenta con muestra urbana." ///
         "La línea vertical marca la dolarización: los niveles no son comparables a través de ella.", ///
         size(vsmall)) ///
    graphregion(color(white)) plotregion(color(white))

capture mkdir "$out/graficos"
graph export "$out/graficos/empleo_adecuado_armonizado.pdf", replace

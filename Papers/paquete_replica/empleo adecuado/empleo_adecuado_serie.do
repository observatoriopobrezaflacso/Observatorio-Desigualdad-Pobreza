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

*==============================================================================*
* DOCUMENTACIÓN DE CAMBIOS: ADAPTACIÓN ENEMDU MULTI-AÑO                        *
*==============================================================================*
*
* RENOMBRADO DE VARIABLES (nombres originales → nombres estándar):
*   edad     → p03      (edad)
*   trabajo  → p20      (trabajó la semana pasada)
*   actayuda → p21      (actividad que realizó para ayudar en su hogar)
*   aunotra  → p22      (aunque no trabajó, ¿tiene trabajo?)
*   hortrasa → p24      (horas trabajadas la semana anterior)
*   ratmeh   → p25      (razón por la que trabajó menos de 40 horas)
*   hormas   → p27      (desea trabajar más horas) [solo 2000+]
*   bustrama → p32      (buscó trabajo el mes anterior)
*   motnobus → p34      (razón por la que no buscó trabajo)
*   deseatra → p35      (desea trabajar) - SUSTITUTO de p28
*   hortrahp → p51a     (horas trabajo principal)
*   hortrahs → p51b     (horas trabajo secundario)
*   hortraho → p51c     (horas otros trabajos)
*
*------------------------------------------------------------------------------*
* CAMBIOS EN CODIFICACIÓN DE VARIABLES:
*------------------------------------------------------------------------------*
*
* p21 - ACTIVIDAD QUE REALIZÓ PARA AYUDAR EN SU HOGAR:
*   1991/1995: 10 categorías (3-12) → 12 = "no realizó ninguna actividad"
*   2005:      11 categorías (1-11) → 11 = "no realizó ninguna actividad"
*   2015:      12 categorías (1-12) → 12 = "no realizó ninguna actividad"
*   AJUSTE:
*     - 2000-2006: realizó actividad = p21 <= 10; no realizó = p21 == 11
*     - 1990s/2007+: realizó actividad = p21 <= 11; no realizó = p21 == 12
*
* p25 - RAZÓN POR LA QUE TRABAJÓ MENOS DE 40 HORAS:
*   1991:      2 categorías → 2 = "no desea trabajar más horas"
*   1993-1999: 3 categorías → 3 = "no desea trabajar más horas"
*   2005:      8 categorías → NO existe "no desea"
*   2015:      9 categorías → 9 = "no desea o no necesita"
*   AJUSTE en d_d:
*     - 1991-1992: d_d = 0 si p25 == 2
*     - 1993-1999: d_d = 0 si p25 == 3
*     - 2007+: d_d = 0 si p25 == 9
*
* p27 - DESEA TRABAJAR MÁS HORAS:
*   1990-1999: Variable no existe directamente. Se construye:
*              p27 = 2 (no) por defecto para empleados
*              p27 = 1 (sí) si ratmeh1 != . o hormas != .
*   2000-2006: 2 categorías → 1 = "sí", 2 = "no"
*   2015:      4 categorías → 1-3 = opciones de sí, 4 = "no desea"
*   AJUSTE:
*     - 1990-1999: p27 == 1 (sí), p27 == 2 (no)
*     - 2000-2006: p27 == 1 (sí), p27 == 2 (no)
*     - 2007+: p27 <= 3 (sí), p27 == 4 (no)
*
* p28 - DISPONIBILIDAD PARA TRABAJAR MÁS HORAS:
*   1990-2006: NO EXISTE esta variable
*   2007+:     Existe p28 = 1 (sí disponible)
*   AJUSTE: Para 1990-2006 se asume disponibilidad si desea trabajar más
*
* p32 - BUSCÓ TRABAJO EL MES ANTERIOR:
*   1991-2006: 2 categorías → 1 = "sí", 2 = "no"
*   2007+:     11 categorías → 1-10 = formas de búsqueda, 11 = "no buscó"
*   AJUSTE:
*     - 1991-2006: buscó = p32 == 1; no buscó = p32 == 2
*     - 2007+: buscó = p32 <= 10; no buscó = p32 == 11
*
* p34 - RAZÓN POR LA QUE NO BUSCÓ TRABAJO:
*   1991/1995: 8 categorías
*              1 = "no tiene necesidad o deseos de trabajar"
*              2 = "no tiene tiempo"
*              3 = "está enfermo"
*              4 = "no está en edad de trabajar"
*              5 = "piensa que no le darán trabajo"
*              6 = "no cree poder encontrar"
*              7 = "espera respuesta a una gestión"
*              8 = "espera respuesta de un empleador"
*   2005:      11 categorías
*              1-7 = razones de desempleo oculto (excluyendo 4="cónyuge no permite")
*              4 = "su cónyuge o familia no le permite" → PEI
*              8-10 = otras razones → PEI
*              11 = "no tiene edad de trabajar"
*   2015:      12 categorías
*              1-7 = razones de desempleo oculto
*              8-11 = otras razones → PEI
*              12 = "no está en edad de trabajar"
*   AJUSTE para PEAN (desempleo oculto):
*     - 1990-1999: pean = 1 si p34 >= 7 & p35 == 1 (espera respuesta)
*     - 2000-2006: pean = 1 si p34 <= 7 & p34 != 4 & p35 == 1
*     - 2007+: pean = 1 si p34 <= 7 & p35 == 1
*
*------------------------------------------------------------------------------*
* NOTAS METODOLÓGICAS:
*------------------------------------------------------------------------------*
* 
* 1. En la década de los 90s, la pregunta sobre la disponibilidad para trabajar 
*    más horas se realizaba solo a las personas que trabajaron menos de 40h la 
*    semana pasada. Del 2000 en adelante se realiza también a quienes trabajaron
*    más de 40h. Esto no afecta el empleo adecuado porque la disponibilidad solo
*    es relevante cuando la persona trabajó menos de 40h.
*
* 2. Para 1990-1999, la variable p27 se construye a partir de ratmeh1 (razón
*    por la que desea trabajar más horas) o hormas. Si estas variables tienen
*    valor no missing, se interpreta como deseo de trabajar más horas.
*
* 3. La categoría "cónyuge/familia no le permite" (p34==4 en 2005) se excluye
*    del desempleo oculto y se asigna a la PEI.
*
*------------------------------------------------------------------------------*
* RESUMEN DE AJUSTES EN CONDICIONES LÓGICAS POR PERÍODO:
*------------------------------------------------------------------------------*
*
* PERÍODO 2007+:
*   - p21: realizó actividad = p21 <= 11; no realizó = p21 == 12
*   - p27: sí desea = p27 <= 3; no desea = p27 == 4
*   - p32: sí buscó = p32 <= 10; no buscó = p32 == 11
*   - p34: desempleo oculto = p34 <= 7
*   - p28: disponible = p28 == 1
*
* PERÍODO 2000-2006:
*   - p21: realizó actividad = p21 <= 10; no realizó = p21 == 11
*   - p27: sí desea = p27 == 1; no desea = p27 == 2
*   - p32: sí buscó = p32 == 1; no buscó = p32 == 2
*   - p34: desempleo oculto = p34 <= 7 & p34 != 4
*   - p28: no existe (se asume disponibilidad si p35 == 1)
*
* PERÍODO 1990-1999:
*   - p21: realizó actividad = p21 <= 11; no realizó = p21 == 12
*   - p27: construido de ratmeh1/hormas; sí = 1, no = 2
*   - p32: sí buscó = p32 == 1; no buscó = p32 == 2
*   - p34: desempleo oculto = p34 >= 7 (categorías 7-8)
*   - p25: no desea más horas = p25 == 2 (1991) o p25 == 3 (1993-1999)
*
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

        * Códigos de no respuesta / valor atípico, año por año (C10). Cada lista
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
        local invalidos ""
        if `y' == 1991                  local invalidos "9999998"
        if inrange(`y', 1992, 1999)     local invalidos "9999998 9999999 99999999"
        if `y' == 2000                  local invalidos "9999 10000 99999 999999 9999999 39999999 89999999 99999999"
        if inrange(`y', 2001, 2005)     local invalidos "-1 999999"
        if `y' == 2006                  local invalidos "999 9999 22150 99999 999999"
        if inrange(`y', 2007, 2009)     local invalidos "-1 999999"
        if `y' >= 2010                  local invalidos "999999"

        foreach c of local invalidos {
            replace ila = . if ila == `c'
        }

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

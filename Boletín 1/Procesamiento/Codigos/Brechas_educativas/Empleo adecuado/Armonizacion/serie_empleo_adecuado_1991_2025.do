*==============================================================================*
* SERIE DE EMPLEO ADECUADO — ENEMDU DICIEMBRE, 1991–2025                       *
*------------------------------------------------------------------------------*
* Versión de "armonizacion_empleo adecuado.do" que:                            *
*   (a) recorre TODOS los años disponibles (no sólo los impares),              *
*   (b) NO sobrescribe las bases de origen,                                    *
*   (c) exporta la serie a Excel.                                              *
*                                                                              *
* La armonización conceptual (definiciones de PET/PEA/empleo, umbrales w/t/d_d)*
* es la del script original; ver ahí la documentación de códigos por período.  *
*==============================================================================*
*
*------------------------------------------------------------------------------*
* CORRECCIONES RESPECTO DEL SCRIPT ORIGINAL                                    *
*------------------------------------------------------------------------------*
*
* 1. merge m:m  -> eliminado.
*    El original hacía  merge m:m anio using <salarios>, keep(3) nogen
*    Con m:m Stata empareja secuencialmente dentro de cada grupo: como la tabla
*    de salarios tiene UNA fila por año, sólo la PRIMERA observación de la
*    ENEMDU quedaba con _merge==3 y keep(3) descartaba todas las demás. La base
*    quedaba en 1 observación y ese resultado se guardaba con save, replace
*    sobre el archivo de origen. Aquí el salario mínimo se pasa como escalar.
*
* 2. save ..., replace sobre la base de origen -> eliminado por defecto.
*    El script original era además no idempotente: en la segunda corrida los
*    rename edad p03 fallaban porque las variables ya estaban renombradas.
*    Si se necesitan las bases enriquecidas, usar $guardar_bases (escribe en
*    una carpeta aparte, nunca sobre ingresos_pc).
*
* 3. Cobertura del loop.
*    Original: numlist 2001(2)2023 2024 (sólo impares + 2024).
*    Aquí: $anio_ini/$anio_fin, saltando con aviso los años sin base.
*
* 4. p24 == 999 (código de no respuesta en horas trabajadas) ahora se recodifica
*    a missing. El original sólo lo hacía con p51a/p51b/p51c. Verificado: en la
*    base 1991 hortrasa llega a 999. Sin la corrección esas personas quedaban
*    con horas=999 -> t=1 -> potencialmente contadas como empleo adecuado.
*
* 5. Missing propagado en comparaciones abiertas.
*    En Stata . es mayor que cualquier número, por lo que p34 >= 7 era TRUE
*    con p34 missing (rama 1990-1999 de la PEA) y horas >= 30 era TRUE con
*    horas missing (ajuste de menores). Se añadió el tope < . en ambos casos.
*
* 6. Horas desconocidas.
*    El original hacía replace horas = 0 if empleo == 1 como valor inicial, de
*    modo que quien no tenía dato de horas terminaba con horas=0 -> t=0 y, si
*    w==1 y d_d==0, era clasificado como ADECUADO. Aquí las horas desconocidas
*    quedan en missing (t=.) y esa persona cuenta como no adecuada.
*    Poner $horas_legacy = 1 para reproducir el comportamiento anterior.
*
* 7. Ramificación por período.
*    El original mezclaba if inrange(`y', ...) con if inrange(anio, ...).
*    anio es una VARIABLE: en un comando if Stata evalúa sólo la primera
*    observación. Aquí todo se decide con el local y del loop.
*
* 8. Lectura de los archivos de salarios.
*    - keep in 12/21 era indexación posicional frágil: según cómo
*      import delimited trate la línea en blanco del archivo, esas filas son
*      1990-1999 de diciembre o bien la etiqueta "A DICIEMBRE" + 1990-1998
*      (perdiendo 1999). Aquí se localiza el bloque por contenido.
*    - encode componentesalarial ... keep if componente == 6 dependía del
*      orden alfabético de las categorías presentes. Verificado que hoy 6 =
*      "Remuneraciones unificadas" (correcto), pero aquí se filtra por texto.
*
* 9. El comando s al final del do-file (comando inexistente que abortaba la
*    ejecución) -> eliminado.
*
*------------------------------------------------------------------------------*
* VERIFICADO Y CONSERVADO (no eran errores)                                    *
*------------------------------------------------------------------------------*
*
* - Unidades: pese al sufijo "precios2000" de los archivos, ingrl/ing_lab son
*   NOMINALES (las versiones deflactadas son *_deflated). Comparar contra el
*   salario mínimo nominal de diciembre es correcto. Comprobado en 1991:
*   mediana de ingrl ~ 100.000 sucres frente a un umbral de 94.333 sucres.
*
* - Variable de ingreso: la lógica "usa ingrl; si no existe, renombra ing_lab"
*   es consistente. En 2001/2003/2005/2007/2008 el pipeline de Ingresos hizo
*   rename ingrl ing_lab, así que en todos los años se termina usando el mismo
*   concepto (el ingreso laboral de la ENEMDU). La hoja "Diagnostico" reporta
*   qué variable se usó cada año.
*
* - Umbral 1990s = SMV + bonificaciones (total) y 2000+ = Remuneraciones
*   unificadas: es el puente correcto, porque la unificación salarial del 2000
*   absorbió el SMV y sus componentes en un solo SBU.
*
* - Denominador = PEA, y los no clasificables cuentan como no adecuados. Es la
*   convención de la tasa oficial. La hoja "Diagnostico" reporta qué porcentaje
*   de los ocupados no tiene dato de ingreso o de horas, para dimensionarlo.
*
*------------------------------------------------------------------------------*
* PENDIENTE DE DECISIÓN (ver hoja "Diagnostico")                               *
*------------------------------------------------------------------------------*
*
* - d_d en 2000-2006: la documentación del script original dice que p35 hace de
*   sustituto de p28 (disponibilidad), y "empleo adecuado 90s.do" efectivamente
*   exige p27 == 1 & p35 == 1. Pero el código de armonización sólo exigía
*   p27 == 1. Los dos scripts NO coinciden. Por defecto se mantiene el
*   comportamiento del script de armonización; $dd_p35 = 1 usa el otro criterio.
*
* - Ruptura de cobertura geográfica: 1991-1999 sólo existen bases urbanas, así
*   que esos años son URBANOS y 2000+ son NACIONALES si $muestra = "nac".
*   La columna "muestra" lo deja explícito. Para una serie homogénea en
*   cobertura, poner $muestra = "urb" (hay bases urbanas para todos los años).
*
* - Años sin base procesada: 2002, 2004 y 2025 no existen en ingresos_pc
*   (2025 tampoco existe como ENEMDU ni tiene SBU en el archivo de salarios).
*   Aparecen en el Excel con estado "sin base".
*
*==============================================================================*

clear all
set more off

*------------------------------------------------------------------------------*
* 0. RUTAS Y OPCIONES
*------------------------------------------------------------------------------*

global bases     "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global procesado "$bases/Procesadas"
global salarios  "$bases/Salarios"
global out       "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1"

global anio_ini 1991
global anio_fin 2025

* Muestra a usar desde 2000 en adelante: "nac" o "urb".
* (1991-1999 usa "urb" siempre, porque es la única disponible.)
global muestra   "nac"

* 1 = horas desconocidas valen 0, como en el script original
global horas_legacy 0

* 1 = en 2000-2006 exigir además p35 == 1 (disponibilidad) para d_d
global dd_p35 0

* 1 = guardar las bases con adec/w/t/d_d en $procesado/empleo_adecuado_armonizado
*     (NUNCA sobre ingresos_pc)
global guardar_bases 0

global excel "$out/Serie empleo adecuado ${anio_ini}-${anio_fin}.xlsx"

scalar edadmin = 15


*------------------------------------------------------------------------------*
* 1. UMBRAL DE INGRESO: SALARIO MÍNIMO NOMINAL DE DICIEMBRE
*------------------------------------------------------------------------------*

tempfile sal_usd sal_sucres

* --- 2000 en adelante: SBU ("Remuneraciones unificadas"), diciembre, USD ------
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html
import delimited "$salarios/Salario unificado y componentes salariales.csv", ///
        varnames(nonames) stringcols(_all) clear
drop in 1
rename (v1 v2 v3 v4) (componente anio_s mes valor)
replace componente = strtrim(componente)
replace mes        = strtrim(mes)
keep if componente == "Remuneraciones unificadas" & mes == "Diciembre"
replace valor = subinstr(valor, ",", ".", .)
destring anio_s valor, replace force
rename (anio_s valor) (anio salario_min)
keep anio salario_min
drop if missing(anio) | missing(salario_min)
save `sal_usd'

* --- 1990-1999: SMV + bonificaciones (TOTAL) a diciembre, en sucres ----------
* https://contenido.bce.fin.ec/documentos/PublicacionesNotas/Catalogo/IEMensual/
import delimited "$salarios/SMV + bonificaciones.csv", ///
        varnames(nonames) stringcols(_all) clear

capture confirm variable v10
if _rc {
    di as error "'SMV + bonificaciones.csv' no tiene la columna TOTAL esperada (v10)."
    exit 459
}

gen long _row = _n
gen byte _dic  = (strtrim(v1) == "A DICIEMBRE")
summarize _row if _dic, meanonly
if r(N) == 0 {
    di as error "No se encontró el bloque 'A DICIEMBRE' en 'SMV + bonificaciones.csv'."
    exit 459
}
local fila_dic = r(min)

* quedarse con las filas posteriores a la etiqueta cuyo PERIODO es un año puro
keep if _row > `fila_dic'
keep if regexm(strtrim(v1), "^[0-9][0-9][0-9][0-9]$")
gen anio = real(strtrim(v1))
keep if inrange(anio, 1990, 1999)

replace v10 = subinstr(strtrim(v10), ",", "", .)
destring v10, gen(salario_min) force
keep anio salario_min
drop if missing(salario_min)
bysort anio: keep if _n == 1
save `sal_sucres'

* --- tabla única -------------------------------------------------------------
use `sal_usd', clear
append using `sal_sucres'
sort anio
label variable salario_min "Salario mínimo nominal de diciembre"

di as txt _n "--- Umbral de ingreso por año ---"
list anio salario_min, noobs

* pasar a globals para no depender de un merge
levelsof anio, local(anios_salario)
foreach a of local anios_salario {
    summarize salario_min if anio == `a', meanonly
    global salmin_`a' = r(mean)
}


*------------------------------------------------------------------------------*
* 2. CÁLCULO DE LA SERIE
*------------------------------------------------------------------------------*

tempname P
tempfile resultados

postfile `P' int anio str3 muestra double salario_min                    ///
        double tasa_adec double tasa_adec_of double tasa_w double tasa_t ///
        long n_pea double pea_exp double adec_exp                        ///
        double p_sin_ingreso double p_sin_horas                          ///
        int p21max int p27max int p32max int p34max                      ///
        str8 var_ingreso str32 estado                                    ///
        using `resultados', replace

if $guardar_bases capture mkdir "$procesado/empleo_adecuado_armonizado"

foreach y of numlist $anio_ini/$anio_fin {

    *--- valores por defecto (se postean tal cual si el año no se puede calcular)
    local muestra  = cond(`y' <= 1999, "urb", "$muestra")
    local base     "$procesado/ingresos_pc/ing_perca_`y'_`muestra'_precios2000.dta"
    local estado   "ok"
    local vding    ""
    local tasa     = .
    local tasa_of  = .
    local tasa_w   = .
    local tasa_t   = .
    local n_pea    = .
    local pea_exp  = .
    local adec_exp = .
    local sin_ing  = .
    local sin_hrs  = .
    local p21max   = .
    local p27max   = .
    local p32max   = .
    local p34max   = .

    local smin = .
    if "${salmin_`y'}" != "" local smin = ${salmin_`y'}

    *--- ¿existe la base? ---
    capture confirm file "`base'"
    if _rc local estado "sin base"

    *--- ¿qué variable de ingreso laboral tiene? ---
    if "`estado'" == "ok" {
        capture describe ingrl using "`base'"
        if !_rc local vding "ingrl"
        else {
            capture describe ing_lab using "`base'"
            if !_rc local vding "ing_lab"
        }
        if "`vding'" == "" local estado "sin ingreso laboral"
    }

    *--- ¿hay umbral salarial para ese año? ---
    if "`estado'" == "ok" & `smin' >= . local estado "sin salario minimo"

    if "`estado'" != "ok" di as error "  [`y'] omitido: `estado'"

    if "`estado'" == "ok" {

    di as txt _n "==============  `y'  (`muestra')  =============="

    quietly {

        use "`base'", clear
        if "`vding'" == "ing_lab" rename ing_lab ingrl

        *----------------------------------------------------------------------*
        * 2.1 Nombres estándar p## (las bases 1991-2006 traen los nombres viejos)
        *----------------------------------------------------------------------*
        if `y' <= 2006 {
            capture rename edad     p03
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

        * variables ausentes en algunos años -> crear vacías para poder referirlas
        foreach v in p24 p25 p27 p28 p32 p34 p35 p51a p51b p51c {
            capture confirm variable `v'
            if _rc gen `v' = .
        }

        * verificación de variables imprescindibles
        local faltan ""
        foreach v in p03 p20 p21 p22 fexp {
            capture confirm variable `v'
            if _rc local faltan "`faltan' `v'"
        }

        if "`faltan'" != "" noisily di as error "  [`y'] faltan variables:`faltan'"

        if "`faltan'" == "" {

        *----------------------------------------------------------------------*
        * 2.2 p27 en 1991-1999: no se pregunta directamente, se construye
        *     (1991 sólo tiene ratmeh1; 1993-1999 sólo hormas; 1992 ambas)
        *----------------------------------------------------------------------*
        if `y' <= 1999 {
            capture drop p27
            gen byte p27 = 2 if p20 == 1 | p22 == 1
            capture confirm variable ratmeh1
            if !_rc replace p27 = 1 if ratmeh1 < .
            capture confirm variable hormas
            if !_rc replace p27 = 1 if hormas  < .
        }

        *--- códigos de no respuesta en horas (CORRECCIÓN 4) ---
        foreach v in p24 p51a p51b p51c {
            replace `v' = . if `v' == 999
        }

        *--- indicadores de período (CORRECCIÓN 7: todo sobre el local y) ---
        local p00 = (`y' >= 2000 & `y' <= 2006)
        local p07 = (`y' >= 2007)

        * categoría "no realizó ninguna actividad" en p21
        local p21_no = cond(`p00', 11, 12)
        local p21_si = `p21_no' - 1

        *----------------------------------------------------------------------*
        * 2.3 Poblaciones de referencia
        *----------------------------------------------------------------------*
        capture drop petn
        gen byte petn = (p03 >= edadmin) if p03 < .
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
            * CORRECCIÓN 5: acotar por arriba; si no, p34 >= 7 es TRUE con missing
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
        * 2.4 Dimensión 1: ingreso laboral vs. salario mínimo nominal
        *----------------------------------------------------------------------*
        capture drop ila
        gen double ila = ingrl
        replace ila = . if inlist(ila, -1, 999999)

        capture drop w
        gen byte w = .
        replace  w = 0 if empleo == 1 & ila <  `smin'
        replace  w = 1 if empleo == 1 & ila >= `smin' & ila < .
        replace  w = . if ila >= .
        label variable w "Ingreso laboral >= salario mínimo"

        *----------------------------------------------------------------------*
        * 2.5 Dimensión 2: horas trabajadas
        *----------------------------------------------------------------------*
        capture drop horas
        gen double horas = .
        * CORRECCIÓN 6: por defecto las horas desconocidas quedan en missing
        if $horas_legacy replace horas = 0 if empleo == 1

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
        * jornada reducida para 12-17 años (CORRECCIÓN 5: acotar horas < .)
        replace  t = 0 if empleo == 1 & horas <  30             & inrange(p03, 12, 17)
        replace  t = 1 if empleo == 1 & horas >= 30 & horas < . & inrange(p03, 12, 17)
        label variable t "Cumple la jornada laboral"

        *----------------------------------------------------------------------*
        * 2.6 Dimensión 3: deseo y disponibilidad de trabajar más horas
        *----------------------------------------------------------------------*
        capture drop d_d
        gen byte d_d = 0 if empleo == 1

        if `p07' {
            replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
            replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
        }
        else if `p00' {
            replace d_d = 0 if empleo == 1 & p27 == 2
            if $dd_p35 replace d_d = 1 if empleo == 1 & p27 == 1 & p35 == 1
            else       replace d_d = 1 if empleo == 1 & p27 == 1
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
        * 2.7 Empleo adecuado
        *----------------------------------------------------------------------*
        capture drop adec
        gen byte adec = 0 if pean == 1 & p03 >= edadmin
        replace  adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 1
        replace  adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0
        label variable adec "Empleo adecuado (armonizado)"

        *--- referencia: clasificación oficial de la base (codificación NO armonizada)
        local cvar ""
        if `p07' local orden CONDACTN condactn CONDACT condact
        else     local orden condact CONDACT
        foreach c of local orden {
            if "`cvar'" == "" {
                capture confirm variable `c'
                if !_rc local cvar "`c'"
            }
        }
        capture drop adec_of
        gen byte adec_of = .
        if "`cvar'" != "" {
            replace adec_of = 0 if pean == 1
            replace adec_of = 1 if pean == 1 & `cvar' == 1
        }

        *----------------------------------------------------------------------*
        * 2.8 Estadísticos ponderados
        *----------------------------------------------------------------------*
        capture summarize adec if pean == 1 [aw = fexp]
        if !_rc {
            local tasa  = r(mean) * 100
            local n_pea = r(N)
        }
        else noisily di as error "  [`y'] no se pudo calcular la tasa (PEA vacía)"

        summarize fexp if pean == 1, meanonly
        local pea_exp = cond(r(N) > 0, r(sum), .)

        summarize fexp if pean == 1 & adec == 1, meanonly
        local adec_exp = cond(r(N) > 0, r(sum), 0)

        if "`cvar'" != "" {
            capture summarize adec_of if pean == 1 [aw = fexp]
            if !_rc local tasa_of = cond(r(N) > 0, r(mean) * 100, .)
        }

        capture summarize w if empleo == 1 [aw = fexp]
        if !_rc local tasa_w = cond(r(N) > 0, r(mean) * 100, .)

        capture summarize t if empleo == 1 [aw = fexp]
        if !_rc local tasa_t = cond(r(N) > 0, r(mean) * 100, .)

        * cobertura de las dos dimensiones entre los ocupados
        summarize fexp if empleo == 1, meanonly
        local emp_exp = cond(r(N) > 0, r(sum), .)

        summarize fexp if empleo == 1 & ila >= ., meanonly
        local aux = cond(r(N) > 0, r(sum), 0)
        local sin_ing = cond(`emp_exp' < . & `emp_exp' > 0, `aux'/`emp_exp'*100, .)

        summarize fexp if empleo == 1 & horas >= ., meanonly
        local aux = cond(r(N) > 0, r(sum), 0)
        local sin_hrs = cond(`emp_exp' < . & `emp_exp' > 0, `aux'/`emp_exp'*100, .)

        * máximos de las categóricas: sirven para validar los supuestos de
        * recodificación por período documentados en la cabecera
        foreach v in p21 p27 p32 p34 {
            summarize `v', meanonly
            local `v'max = cond(r(N) > 0, r(max), .)
        }

        noisily di as txt "  empleo adecuado = " as res %6.2f `tasa' as txt "%" ///
                          "   (n PEA = " as res `n_pea' as txt ")"

        if $guardar_bases {
            keep petn pean empleo w t d_d horas ila adec adec_of anio fexp
            save "$procesado/empleo_adecuado_armonizado/adec_`y'_`muestra'.dta", replace
        }

        }
        else local estado "faltan variables"
    }
    }

    post `P' (`y') ("`muestra'") (`smin')                  ///
             (`tasa') (`tasa_of') (`tasa_w') (`tasa_t')    ///
             (`n_pea') (`pea_exp') (`adec_exp')            ///
             (`sin_ing') (`sin_hrs')                       ///
             (`p21max') (`p27max') (`p32max') (`p34max')   ///
             ("`vding'") ("`estado'")
}

postclose `P'


*------------------------------------------------------------------------------*
* 3. EXPORTACIÓN A EXCEL
*------------------------------------------------------------------------------*

use `resultados', clear
sort anio

label variable anio          "Año"
label variable muestra       "Muestra (urb = urbano, nac = nacional)"
label variable salario_min   "Salario mínimo diciembre (sucres <=1999, USD >=2000)"
label variable tasa_adec     "Empleo adecuado (% de la PEA)"
label variable tasa_adec_of  "Referencia condact==1 (% PEA, codificación no armonizada)"
label variable tasa_w        "Ocupados con ingreso >= salario mínimo (%)"
label variable tasa_t        "Ocupados que cumplen la jornada (%)"
label variable n_pea         "Observaciones en la PEA"
label variable pea_exp       "PEA expandida"
label variable adec_exp      "Empleo adecuado expandido"
label variable p_sin_ingreso "Ocupados sin dato de ingreso (%)"
label variable p_sin_horas   "Ocupados sin dato de horas (%)"
label variable p21max        "Máx. p21 (validar categoría ninguna actividad)"
label variable p27max        "Máx. p27 (validar categorías de desea más horas)"
label variable p32max        "Máx. p32 (validar categorías de búsqueda)"
label variable p34max        "Máx. p34 (validar razones de no búsqueda)"
label variable var_ingreso   "Variable de ingreso laboral utilizada"
label variable estado        "Estado del cálculo"

format tasa_adec tasa_adec_of tasa_w tasa_t p_sin_ingreso p_sin_horas %6.2f
format pea_exp adec_exp %14.0fc
format salario_min %12.2fc

di as txt _n "===================== SERIE ====================="
list anio muestra tasa_adec tasa_adec_of n_pea estado, noobs

save "$out/serie_empleo_adecuado_${anio_ini}_${anio_fin}.dta", replace

preserve
    keep  anio muestra salario_min tasa_adec tasa_adec_of n_pea pea_exp adec_exp estado
    order anio muestra salario_min tasa_adec tasa_adec_of n_pea pea_exp adec_exp estado
    export excel using "$excel", sheet("Serie") firstrow(varlabels) replace
restore

preserve
    keep  anio muestra var_ingreso tasa_w tasa_t p_sin_ingreso p_sin_horas ///
          p21max p27max p32max p34max estado
    order anio muestra var_ingreso tasa_w tasa_t p_sin_ingreso p_sin_horas ///
          p21max p27max p32max p34max estado
    export excel using "$excel", sheet("Diagnostico") firstrow(varlabels) sheetmodify
restore

di as txt _n "Excel exportado en:" _n "  $excel"

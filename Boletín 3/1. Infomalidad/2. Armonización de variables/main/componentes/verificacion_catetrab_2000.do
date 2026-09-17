*==============================================================================*
* verificacion_catetrab_2000.do                                                *
*                                                                              *
* EVIDENCIA: empleo2000.dta ya trae la codificacion de 'catetrab' de 2001      *
* (valores 1-12), pero conserva pegada la etiqueta de valores de los noventa   *
* (que solo define 3-9). Como familiar_no_remunerado.do procesa el 2000 con    *
* la rama 1990-2000 (`catetrab == 5`), en ese anio marca como trabajador       *
* familiar NO REMUNERADO a los CUENTA PROPIA.                                  *
*                                                                              *
* El do-file no modifica nada: solo lee las bases y lista resultados.          *
*                                                                              *
* Cuatro pruebas independientes:                                               *
*   1. La etiqueta de 2000 no cubre los valores que trae la variable.          *
*   2. La distribucion de codigos de 2000 calca la de 2001, no la de 1999.     *
*   3. Prueba SIN etiquetas: el ingreso laboral por codigo. Un trabajador      *
*      familiar no remunerado no puede tener ingreso; un cuenta propia si.     *
*   4. Efecto sobre el indicador publicado (regla vigente vs. regla de 2001).  *
*==============================================================================*

clear all
set more off
set linesize 130

if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global raw "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"

capture confirm file "$raw/empleo2000.dta"
if _rc {
    di as error "No se encuentra $raw/empleo2000.dta"
    exit 601
}


*------------------------------------------------------------------------------*
**# PRUEBA 1. La etiqueta pegada en 2000 no cubre los valores que hay en la base
*------------------------------------------------------------------------------*
* Si el .dta tuviera de verdad la codificacion de los noventa, todos los valores
* observados estarian dentro del rango que define su propia etiqueta (3-9).

di as text _n(2) "{hline 78}"
di as text "PRUEBA 1. Etiqueta declarada vs. valores realmente observados"
di as text "{hline 78}"

foreach y in 1999 2000 2001 {

    use catetrab using "$raw/empleo`y'.dta", clear

    local lb : value label catetrab

    qui summarize catetrab
    local vmin = r(min)
    local vmax = r(max)

    * Codigos presentes en los datos a los que la etiqueta no asigna texto
    local huerfanos ""
    qui levelsof catetrab, local(codigos)
    foreach c of local codigos {
        local txt ""
        if "`lb'" != "" local txt : label `lb' `c', strict
        if "`txt'" == "" local huerfanos "`huerfanos' `c'"
    }

    qui gen byte sin_etiqueta = 0
    foreach c of local huerfanos {
        qui replace sin_etiqueta = 1 if catetrab == `c'
    }
    qui count if sin_etiqueta == 1
    local n_sin = r(N)
    qui count if !missing(catetrab)
    local n_tot = r(N)

    di as result _n "--- `y' : catetrab (etiqueta: `lb') ---"
    di as text    "    rango observado          : `vmin' - `vmax'"
    di as text    "    codigos SIN etiqueta     :`huerfanos'"
    di as text    "    observaciones afectadas  : `n_sin' de `n_tot'"

    if "`lb'" != "" label list `lb'
}

di as text _n "Lectura: 1999 y 2001 son coherentes (ningun codigo huerfano)."
di as text "En 2000 la variable trae codigos que su propia etiqueta -la de los"
di as text "noventa- no define. La etiqueta quedo obsoleta frente a los datos."


*------------------------------------------------------------------------------*
**# PRUEBA 2. La distribucion de 2000 calca la de 2001, no la de 1999
*------------------------------------------------------------------------------*

di as text _n(2) "{hline 78}"
di as text "PRUEBA 2. Distribucion de catetrab por codigo (% de los declarantes)"
di as text "{hline 78}"

foreach y in 1999 2000 2001 {
    qui use catetrab using "$raw/empleo`y'.dta", clear
    qui drop if missing(catetrab)
    qui gen byte uno = 1
    qui collapse (sum) n = uno, by(catetrab)
    qui egen double tot = total(n)
    qui gen double p`y' = 100 * n / tot
    qui keep catetrab p`y'
    qui rename catetrab codigo
    tempfile d`y'
    qui save `d`y''
}

use `d1999', clear
qui merge 1:1 codigo using `d2000', nogen
qui merge 1:1 codigo using `d2001', nogen
sort codigo

* Se quita la etiqueta heredada de 1999: la tabla tiene que mostrar el CODIGO
* desnudo, porque el texto de esa etiqueta es justamente lo que esta en duda.
label values codigo

* Distancia entre distribuciones, sobre los codigos que ambas comparten
qui gen double dist_99 = abs(p2000 - p1999) if !missing(p2000) & !missing(p1999)
qui gen double dist_01 = abs(p2000 - p2001) if !missing(p2000) & !missing(p2001)
qui summarize dist_99, meanonly
local dist99 = r(sum)
qui summarize dist_01, meanonly
local dist01 = r(sum)
drop dist_99 dist_01

format p1999 p2000 p2001 %8.2f
list codigo p1999 p2000 p2001, noobs

di as text _n "Distancia total |2000 - 1999| = " %6.2f `dist99' " puntos porcentuales"
di as text    "Distancia total |2000 - 2001| = " %6.2f `dist01' " puntos porcentuales"
di as text _n "Lectura: 2000 se parece a 2001, no a 1999. Ademas 2000 usa codigos"
di as text "que en 1999 no existen y en 2001 si."


*------------------------------------------------------------------------------*
**# PRUEBA 3. Prueba sin etiquetas: el ingreso laboral por codigo
*------------------------------------------------------------------------------*
* Es la prueba decisiva porque no depende de ninguna etiqueta.
* Por definicion, un TRABAJADOR FAMILIAR NO REMUNERADO no percibe ingreso
* laboral. Un CUENTA PROPIA si. Se mira, para cada codigo, que porcentaje
* declara ingreso laboral positivo.

di as text _n(2) "{hline 78}"
di as text "PRUEBA 3. % con ingreso laboral positivo, por codigo de catetrab"
di as text "{hline 78}"

foreach y in 1999 2000 2001 {

    use catetrab ingrl using "$raw/empleo`y'.dta", clear
    qui drop if missing(catetrab)

    * Codigos de no respuesta del ingreso, segun el anio
    if `y' == 1999 local invalidos "9999998 9999999 99999999"
    else           local invalidos "-1 999999"
    foreach c of local invalidos {
        qui replace ingrl = . if ingrl == `c'
    }

    * Copia sin etiqueta, para que la tabla muestre el CODIGO y no un texto
    * que en 2000 es justamente el que esta mal.
    qui gen int codigo = catetrab
    qui gen byte con_ingreso = 100 * (ingrl > 0 & !missing(ingrl))

    di as result _n "--- `y' : % con ingreso laboral > 0, por codigo ---"
    tabstat con_ingreso, by(codigo) stat(mean n) format(%9.1f) nototal
}

di as text _n "Lectura: en 1999 el codigo 5 (trab. fam. no remunerado) practicamente"
di as text "no tiene ingreso. En 2000 el codigo 5 SI tiene ingreso, igual que el"
di as text "codigo 5 de 2001, que es CUENTA PROPIA. Los que no tienen ingreso en"
di as text "2000 son los codigos 6 y 11: los de la codificacion de 2001."


*------------------------------------------------------------------------------*
**# PRUEBA 4. Efecto sobre el indicador publicado
*------------------------------------------------------------------------------*
* Se reproduce el denominador de "3. Analisis/analisis_descriptivo.do":
* ocupados de 15 anios y mas (edad >= 15, condact fuera del rango 5-8).

di as text _n(2) "{hline 78}"
di as text "PRUEBA 4. Trabajo no remunerado (% de ocupados 15+)"
di as text "          regla vigente vs. regla de 2001 aplicada al anio 2000"
di as text "{hline 78}"

* La semilla se guarda con la memoria vacia: si no, arrastra los datos que
* dejo la prueba anterior y la tabla final sale con filas de relleno.
tempfile serie
qui clear
qui save `serie', emptyok replace

foreach y in 1998 1999 2000 2001 2003 {

    use "$raw/empleo`y'.dta", clear
    qui rename *, lower

    capture confirm variable edad
    if _rc capture rename p03 edad

    capture confirm variable cates
    if _rc qui gen double cates = .

    *--- Codigos de "no remunerado" que usa hoy familiar_no_remunerado.do ---*
    * 1990-2000 -> 5 ; 2001-2002 -> 6 y 11 ; 2003-2006 -> 8
    if inrange(`y', 1990, 2000)      local cods_vig "5"
    else if inrange(`y', 2001, 2002) local cods_vig "6, 11"
    else                             local cods_vig "8"

    *--- Regla propuesta: el 2000 pasa a tratarse como 2001 ---*
    if `y' == 2000 local cods_cor "6, 11"
    else           local cods_cor "`cods_vig'"

    foreach regla in vig cor {

        local cods "`cods_`regla''"

        qui gen double _cates = cates
        * La rama 2001-2002 limpia cates == 0 ("sin ocupacion secundaria").
        * La rama 1990-2000 no lo hace: se respeta esa diferencia.
        if "`cods'" == "6, 11" qui replace _cates = . if _cates == 0

        * .z es un centinela que nunca coincide: inlist() exige dos argumentos
        qui gen byte nr_`regla' = 0
        qui replace nr_`regla' = 1 if inlist(catetrab, `cods', .z)
        qui replace nr_`regla' = 1 if inlist(_cates,   `cods', .z)
        qui replace nr_`regla' = 0 if !missing(catetrab) & !inlist(catetrab, `cods', .z)
        qui replace nr_`regla' = 0 if !missing(_cates)   & !inlist(_cates,   `cods', .z)
        qui replace nr_`regla' = . if missing(catetrab) & missing(_cates)

        * Denominador de analisis_descriptivo.do: ocupados de 15 anios y mas
        qui replace nr_`regla' = . if edad < 15
        qui replace nr_`regla' = . if inrange(condact, 5, 8)

        drop _cates
    }

    qui summarize nr_vig [iw = fexp], meanonly
    local v = 100 * r(mean)
    qui summarize nr_cor [iw = fexp], meanonly
    local c = 100 * r(mean)

    qui clear
    qui set obs 1
    qui gen int    anio      = `y'
    qui gen double vigente   = `v'
    qui gen double corregido = `c'
    qui append using `serie'
    qui save `serie', replace
}

use `serie', clear
sort anio
label variable vigente   "Regla vigente"
label variable corregido "Regla 2001 en 2000"
format vigente corregido %8.2f
list anio vigente corregido, noobs

di as text _n "Lectura: con la regla vigente el 2000 salta a ~22%, cuatro veces el"
di as text "~5% de 1999 y muy por encima del ~9% de 2003. Tratando el 2000 con la"
di as text "codificacion de 2001 el salto desaparece. Los demas anios no cambian:"
di as text "sirven de control."

di as text _n(2) "{hline 78}"
di as text "FIN DE LA VERIFICACION"
di as text "{hline 78}"

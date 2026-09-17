*------------------------------------------------------------------*
* Cuidado de familiares como razón para no trabajar más horas
*------------------------------------------------------------------*
* Verifica la afirmación del boletín 3 (sección de género):
*   "un X% de las mujeres que trabajan menos de 40 horas explican
*    que no desean trabajar más horas porque tienen que cuidar un
*    familiar. Este porcentaje es de Y% en el caso de los hombres."
*
* Variable clave: p29a, "¿Cuál es la razón por la que no desea o no
* está disponible para trabajar más?", categoría 1 = "Tiene a cargo
* el cuidado de algún miembro de su hogar". Sólo se le pregunta a
* quienes trabajan menos de 40 horas y respondieron que no desean
* (p27 == 4) o no están disponibles (p28 == 2) para trabajar más.
*
* Fuente: ENEMDU diciembre, base original (no la armonizada: p29a
* no forma parte de las variables base del boletín).
*------------------------------------------------------------------*

clear all
set more off

if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global diciembres "$user_root/Bases/ENEMDU/Originales/Diciembres/2018-presente/Trimestrales"

local anio 2025

use "$diciembres/empleo`anio'.dta", clear

*------------------------------------------------------------------*
* 1. Universo
*------------------------------------------------------------------*
* Ocupados: condact 1 a 6 (empleo adecuado, subempleos, otro empleo
* no pleno, no remunerado). 7 y 8 son desempleo, 9 es inactividad.
gen byte ocupado = inrange(condact, 1, 6)

* "Trabajan menos de 40 horas": horas efectivas de la semana anterior.
* p24 con valor perdido no entra al universo.
gen byte menos40 = (p24 < 40) if p24 < .
replace menos40 = 0 if p24 >= .

label define sexo 1 "Hombre" 2 "Mujer", replace
label values p02 sexo

*------------------------------------------------------------------*
* 2. Indicador
*------------------------------------------------------------------*
* Numerador: declara el cuidado de un miembro del hogar como razón.
* A quien no se le hizo la pregunta (porque sí desea y puede trabajar
* más) le corresponde 0, no un valor perdido: forma parte del
* denominador y no dio esa razón.
gen byte cuida = (p29a == 1)

*------------------------------------------------------------------*
* 3. Resultado que respalda la frase del boletín
*------------------------------------------------------------------*
di as text _n "{hline 70}"
di as result "`anio': % que no trabaja más horas por cuidar a un familiar"
di as text   "Universo: ocupados que trabajan menos de 40 horas semanales"
di as text "{hline 70}"

tab cuida p02 [iw=fexp] if ocupado & menos40, col nofreq

* La cifra exacta, por si se la quiere citar con decimales.
forvalues s = 1/2 {
    local etiqueta : label sexo `s'
    quietly summarize cuida [iw=fexp] if ocupado & menos40 & p02 == `s'
    di as text "`etiqueta': " as result %5.2f 100 * r(mean) "%" ///
       as text "   (n = " %6.0f r(N) ")"
}

*------------------------------------------------------------------*
* 4. Contexto: composición completa de las razones
*------------------------------------------------------------------*
* Entre quienes sí contestaron p29a, para ver el peso relativo del
* cuidado frente a las demás razones.
di as text _n "Composición de p29a entre quienes respondieron:"
tab p29a p02 [iw=fexp] if ocupado & menos40, col nofreq

*------------------------------------------------------------------*
* 5. Serie corta, para saber si el dato es estable
*------------------------------------------------------------------*
di as text _n "{hline 70}"
di as result "Serie 2022-2025 (mismo universo, ponderado)"
di as text "{hline 70}"
di as text "anio      Hombres    Mujeres"

forvalues a = 2022/2025 {
    quietly use "$diciembres/empleo`a'.dta", clear
    quietly gen byte ocupado = inrange(condact, 1, 6)
    quietly gen byte menos40 = (p24 < 40) if p24 < .
    quietly replace menos40 = 0 if p24 >= .
    quietly gen byte cuida = (p29a == 1)

    quietly summarize cuida [iw=fexp] if ocupado & menos40 & p02 == 1
    local h = 100 * r(mean)
    quietly summarize cuida [iw=fexp] if ocupado & menos40 & p02 == 2
    local m = 100 * r(mean)
    di as text "`a'" as result %11.2f `h' %11.2f `m'
}

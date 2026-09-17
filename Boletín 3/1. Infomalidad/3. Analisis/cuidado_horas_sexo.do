*------------------------------------------------------------------*
* Cuidado de familiares como razón para no trabajar más horas
*------------------------------------------------------------------*
* Produce la serie que alimenta la frase del boletín 3 (sección de
* género):
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
* La pregunta se incorporó a la ENEMDU en 2022, así que la serie
* empieza ese año. Se lee la base original de diciembre: p29a no
* forma parte de las variables base armonizadas del boletín.
*
* Salida: Tablas/razon_cuidado_horas_sexo.xlsx
*   anio | sexo | porcentaje | N
*------------------------------------------------------------------*

clear all
set more off

if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

global diciembres  "$user_root/Bases/ENEMDU/Originales/Diciembres/2018-presente/Trimestrales"
global out_results "$user_root/Boletín 3/4. Resultados/informalidad"

* Primer y último año con la pregunta p29a en el cuestionario.
local primer_anio 2022
local ultimo_anio 2025

tempname R
postfile `R' int anio str6 sexo double porcentaje long N using "`c(tmpdir)'/cuidado.dta", replace

forvalues a = `primer_anio'/`ultimo_anio' {

    capture confirm file "$diciembres/empleo`a'.dta"
    if _rc {
        di as error "No se encuentra empleo`a'.dta; se omite el año `a'."
        continue
    }

    quietly use "$diciembres/empleo`a'.dta", clear

    * Si el año no trae la pregunta, no se fuerza: se salta.
    capture confirm variable p29a
    if _rc {
        di as error "empleo`a'.dta no tiene p29a; se omite el año `a'."
        continue
    }

    *--------------------------------------------------------------*
    * Universo
    *--------------------------------------------------------------*
    * Ocupados: condact 1 a 6 (empleo adecuado, subempleos, otro
    * empleo no pleno, no remunerado). 7 y 8 son desempleo, 9 es
    * inactividad.
    quietly gen byte ocupado = inrange(condact, 1, 6)

    * "Trabajan menos de 40 horas", por horas efectivas de la semana
    * anterior. Quien no declara horas no entra al universo: un valor
    * perdido no es "menos de 40".
    quietly gen byte menos40 = (p24 < 40) if p24 < .
    quietly replace menos40 = 0 if p24 >= .

    *--------------------------------------------------------------*
    * Indicador
    *--------------------------------------------------------------*
    * A quien no se le hizo la pregunta (porque sí desea y puede
    * trabajar más) le corresponde 0, no un valor perdido: forma
    * parte del denominador y no dio esa razón.
    quietly gen byte cuida = (p29a == 1)

    forvalues s = 1/2 {
        local etiqueta = cond(`s' == 1, "Hombre", "Mujer")
        quietly summarize cuida [iw=fexp] if ocupado & menos40 & p02 == `s'
        post `R' (`a') ("`etiqueta'") (100 * r(mean)) (r(N))
    }
}

postclose `R'

*------------------------------------------------------------------*
* Exportación
*------------------------------------------------------------------*
use "`c(tmpdir)'/cuidado.dta", clear
label variable porcentaje "% que no trabaja más horas por cuidar a un familiar"
label variable N          "Casos sin ponderar"
sort anio sexo

list, noobs sepby(anio)

capture mkdir "$out_results/Tablas"
export excel using "$out_results/Tablas/razon_cuidado_horas_sexo.xlsx", ///
    firstrow(variables) replace

di as result _n "Exportado: $out_results/Tablas/razon_cuidado_horas_sexo.xlsx"

****************************************************
* MORTALIDAD MATERNA Y NIVEL EDUCATIVO
* ECUADOR 2000
****************************************************

clear all
set more off

*---------------------------------------------------
* 1. Cargar base
*---------------------------------------------------
import spss using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\EDG_2000_defunciones.sav", clear

*---------------------------------------------------
* 2. Mantener mujeres 15–49 años
*---------------------------------------------------
keep if SEXO==2
keep if inrange(EDAD,15,49)

*---------------------------------------------------
* 3. Identificar muertes maternas (CIE-10 O00–O99)
*---------------------------------------------------
gen causa_trim = trim(CAUSA)
gen muerte_materna = substr(causa_trim,1,1)=="O"

keep if muerte_materna==1

*---------------------------------------------------
* 4. Agrupar causas maternas
*---------------------------------------------------
* Extraer número del código (ej: O15 -> 15)
gen cod_num = real(substr(causa_trim,2,2))

gen causa_grupo = .

* 1. Aborto O00–O08
replace causa_grupo = 1 if cod_num>=0 & cod_num<=8

* 2. Trastornos hipertensivos O10–O16
replace causa_grupo = 2 if cod_num>=10 & cod_num<=16

* 3. Hemorragias (O20, O44–O46, O67, O72)
replace causa_grupo = 3 if inlist(cod_num,20,44,45,46,67,72)

* 4. Sepsis O85
replace causa_grupo = 4 if cod_num==85

* 5. Otras
replace causa_grupo = 5 if missing(causa_grupo)


*---------------------------------------------------
* 5. Nivel educativo (codificación 0-5,9)
*---------------------------------------------------
gen nivel_agr = .

replace nivel_agr = 0 if NIVEL==0
replace nivel_agr = 1 if NIVEL==1
replace nivel_agr = 2 if NIVEL==2
replace nivel_agr = 3 if NIVEL==3
replace nivel_agr = 4 if NIVEL==4
replace nivel_agr = 5 if NIVEL==5
replace nivel_agr = 9 if NIVEL==9

label define nivel_lbl ///
0 "Ninguno" ///
1 "Alfabetización" ///
2 "Primaria" ///
3 "Secundaria" ///
4 "Superior" ///
5 "Postgrado" ///
9 "No especificado"

label values nivel_agr nivel_lbl
label var nivel_agr "Nivel educativo"

* Opcional: excluir no especificado
***drop if nivel_agr==9////


***********TABLAS***********

table nivel_agr causa_grupo, statistic(percent) nformat(%4.1f)
tab causa_grupo nivel_agr, row chi2


********GRAFICOS*************

graph bar (percent), ///
    over(causa_grupo, gap(15)) ///
    over(nivel_agr, gap(30)) ///
    stack ///
    asyvars ///
    legend(cols(1) size(small)) ///
    ytitle("Porcentaje dentro del nivel educativo") ///
    title("Causas de muerte materna según nivel educativo") ///
    subtitle("Mujeres 15-49 años, Ecuador 2000")
	
	
*****Agrupar por grupos***************
	
gen edu_2grupos = .

replace edu_2grupos = 1 if inlist(NIVEL,0,1,2)
replace edu_2grupos = 2 if inlist(NIVEL,3,4,5)

label define edu2 ///
1 "Primaria o menos" ///
2 "Secundaria y más"

label values edu_2grupos edu2
label var edu_2grupos "Nivel educativo (2 grupos)"

drop if NIVEL==9

tab causa_grupo edu_2grupos, row chi2

*****Graficos****************

graph bar (percent), ///
    over(edu_2grupos, gap(30)) ///
    over(causa_grupo) ///
    stack ///
    asyvars ///
    ytitle("Porcentaje") ///
    title("Causas de muerte materna según nivel educativo (2 grupos)") ///
    subtitle("Ecuador 2000")








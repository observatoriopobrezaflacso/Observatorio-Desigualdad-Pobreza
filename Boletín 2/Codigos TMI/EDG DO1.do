****************************************************
* MORTALIDAD MATERNA Y NIVEL DE INSTRUCCIÓN - 1990
****************************************************

clear all
set more off

*---------------------------------------------------
* 1. Importar base
*---------------------------------------------------
import spss using "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Defunciones\EDG_1990.sav", clear

*---------------------------------------------------
* 2. Identificar muertes maternas (CIE-9: 630–676)
*---------------------------------------------------
gen muerte_materna = inrange(CAUSA,630,676)
label var muerte_materna "Muerte materna (CIE-9 630-676)"

*---------------------------------------------------
* 3. Filtrar mujeres en edad reproductiva (15–49)
*---------------------------------------------------
keep if SEXO==2
keep if inrange(EDAD,15,49)

* Verificar cuántas muertes maternas hay
tab muerte_materna

*---------------------------------------------------
* 4. Agrupar nivel de instrucción
*---------------------------------------------------
gen nivel_agr = .

* Sin instrucción
replace nivel_agr = 0 if NIVEL==0

* Primaria
replace nivel_agr = 1 if inrange(NIVEL,31,36)

* Secundaria
replace nivel_agr = 2 if inrange(NIVEL,39,46)

* Superior
replace nivel_agr = 3 if inrange(NIVEL,49,59)

* No especificado
replace nivel_agr = 9 if NIVEL==99

label define nivel_lbl 0 "Sin instrucción" ///
                       1 "Primaria" ///
                       2 "Secundaria" ///
                       3 "Superior" ///
                       9 "No especificado"

label values nivel_agr nivel_lbl
label var nivel_agr "Nivel de instrucción (agrupado)"

*---------------------------------------------------
* 5. Agrupar causas maternas
*---------------------------------------------------
gen causa_grupo = .

replace causa_grupo = 1 if inrange(CAUSA,630,639)
replace causa_grupo = 2 if inrange(CAUSA,640,649)
replace causa_grupo = 3 if inrange(CAUSA,650,659)
replace causa_grupo = 4 if inrange(CAUSA,660,676)

label define causa_lbl 1 "Aborto (630-639)" ///
                       2 "Complicaciones embarazo (640-649)" ///
                       3 "Complicaciones parto (650-659)" ///
                       4 "Puerperio (660-676)"

label values causa_grupo causa_lbl
label var causa_grupo "Grupo de causa materna"

*---------------------------------------------------
* 6. Mantener solo muertes maternas
*---------------------------------------------------
keep if muerte_materna==1

*---------------------------------------------------
* 7. TABLAS ESTADÍSTICAS
*---------------------------------------------------

display "========================================="
display "Tabla 1: Causa específica x Nivel instrucción"
display "========================================="
tab CAUSA nivel_agr, row

display "========================================="
display "Tabla 2: Grupo causa materna x Nivel instrucción"
display "========================================="
tab causa_grupo nivel_agr, row

display "========================================="
display "Frecuencia total por nivel educativo"
display "========================================="
tab nivel_agr

display "========================================="
display "Frecuencia total por grupo de causa"
display "========================================="
tab causa_grupo

***********GRAFICOS*****************


graph bar (percent), ///
    over(nivel_agr, gap(30)) ///
    over(causa_grupo, label(nolabel)) ///
    stack ///
    asyvars ///
    legend(position(3) ring(0) cols(1)) ///
    ytitle("Porcentaje") ///
    title("Causas de muerte materna según nivel educativo")

	
*---------------------------------------------------
* 4.1 Recodificación binaria de educación (para tasas y desigualdad)
*---------------------------------------------------
gen educ_bin = .
replace educ_bin = 0 if inlist(nivel_agr, 0, 1, 2)   // Inferior a secundaria
replace educ_bin = 1 if nivel_agr == 3               // Superior a secundaria
* Opcional: trata el 9 como missing (ya está)

label define educ_bin_lbl 0 "Inferior a secundaria" ///
                          1 "Superior a secundaria"
label values educ_bin educ_bin_lbl
label var educ_bin "Nivel educativo binario de la madre"

* Ver distribución
tab educ_bin, miss
tab educ_bin nivel_agr, miss   // para chequear	


display "========================================="
display "Tabla: Grupo causa materna x Educación binaria"
display "========================================="
tab causa_grupo educ_bin, row col

display "========================================="
display "Frecuencia total por nivel educativo (binario)"
display "========================================="
tab educ_bin


graph bar (percent), ///
    over(educ_bin, gap(30) label(labsize(medium))) ///
    over(causa_grupo, label(nolabel)) ///
    stack ///
    asyvars ///
    legend(position(3) ring(0) cols(1) size(small)) ///
    ytitle("Porcentaje") ///
    title("Causas de muerte materna según nivel educativo (1990)", size(medlarge)) ///
    blabel(bar, format(%4.1f))




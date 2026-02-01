clear

* ============================================================
* 1. RUTAS Y CARGA DE BASES
* ============================================================

* Ruta global para facilitar portabilidad del código
global limpias "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brechas educacion/bases limpias"


* Cargar base 1991 con variables relevantes
use rama1 nivinst condact fexp anoinst using ///
    "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brecha educacion/Bases/bases limpias/empleo1991.dta", clear

rename *, lower                         // uniformidad en minúsculas
rename condact condact_1991             // diferenciación por año
rename nivinst nivinst2
gen anio = "1991_"                      // marca de año para reshape futuro

label drop nivinst

* Cargar base 1998 con variables relevantes
append using ///
    "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brecha educacion/Bases/bases limpias/empleo1998.dta", keep(rama1 anoinst nivinst condact fexp anoinst)

rename *, lower                         // uniformidad en minúsculas
rename condact condact_1998             // diferenciación por año
replace nivinst2 = nivinst if nivinst2 == .
drop nivinst
replace anio = "1998_" if anio == ""    // completar años faltantes
label drop nivinst



* ============================================================
* 2. VARIABLES CLAVES: EMPLEO PLENO Y NIVEL EDUCATIVO
* ============================================================

* Empleo pleno: condiciones 1 = pleno
gen empleo_pleno = inlist(1, condact_1991, condact_1998)

replace empleo_pleno = . if inrange(condact_1991, 7, 10) // El label 10 no tiene etiqueta, pero parece ser de inactivos. 
replace empleo_pleno = . if inlist(condact_1998, 7, 8)


* Escolaridad (anios 1991 y 1998)

gen escola= anoinst if nivinst2==3
replace escola=0 if nivinst2==1
replace escola=1 if nivinst2==2
replace escola=anoinst+6 if nivinst2==4
replace escola=anoinst+12 if nivinst2==5

generate calificado=1 if escola>12
replace calificado=0 if escola<=12
replace calificado=. if escola == .
drop if calificado == .

* Conservar solo variables necesarias
keep rama1 calificado empleo_pleno anio fexp

* ============================================================
* 3. ETIQUETAS PARA GRÁFICOS
* ============================================================


label define rama_graph  1 "Agricult./Silvicult./Pesca" 3 "Manufactura" 6 "Construcción" 7 "Comercio" 9 "Alojamiento y comida"

label value rama1 rama_graph

* ============================================================
* 3. GENERACIÓN DE N Y PONDERACIÓN
* ============================================================

* Crear contador de observaciones válidas
gen n_obs = !inlist(., rama1, calificado, empleo_pleno)
replace n_obs = . if n_obs == 0

gen n = n_obs
replace n = n_obs * fexp          // expansión con factor de expansión

* Codificar empleo pleno como string para pivotear después
tostring empleo_pleno, replace
replace empleo_pleno = "pleno"   if empleo_pleno == "1"
replace empleo_pleno = "nopleno" if empleo_pleno == "0"
keep if empleo_pleno !="."

* Codificar calificado como string
tostring calificado, replace
replace calificado = "uni_"    if calificado == "1"
replace calificado = "nouni_"  if calificado == "0"
s

* ============================================================
* 4. COLAPSOS PARA OBTENER TABLAS DE CONTINGENCIA
* ============================================================

collapse (sum) n, by(rama1 calificado anio empleo_pleno)

* Reordenar base a formato ancho: primero año
reshape wide n, i(rama1 calificado empleo_pleno) j(anio) string 

* Luego nivel educativo
reshape wide n*, i(rama1 empleo_pleno) j(calificado) string

* Finalmente empleo pleno
reshape wide n*, i(rama1) j(empleo_pleno) string


* ============================================================
* 1991-1998
* ============================================================

* ============================================================
* 5. PROPORCIONES DENTRO DE CADA GRUPO
* ============================================================

* Proporción sin universidad y sin empleo pleno en 1991
egen tot_1991_nouni_nopleno = total(n1991_nouni_nopleno)
gen per_1991_nouni_nopleno = n1991_nouni_nopleno / tot_1991_nouni_nopleno 

* Proporción sin universidad y con empleo pleno en 1998
egen tot_1998_nouni_pleno = total(n1998_nouni_pleno)
gen per_1998_nouni_pleno = n1998_nouni_pleno / tot_1998_nouni_pleno

* Proporciones para calificados
egen tot_1991_uni_nopleno = total(n1991_uni_nopleno)
gen per_1991_uni_nopleno = n1991_uni_nopleno / tot_1991_uni_nopleno 

egen tot_1998_uni_pleno = total(n1998_uni_pleno)
gen per_1998_uni_pleno = n1998_uni_pleno / tot_1998_uni_pleno

* ============================================================
* 6. AGRUPACIÓN: calificadoS vs NO calificadoS
* ============================================================

egen n1991_uni    = rowtotal(n1991_uni_pleno n1991_uni_nopleno)
egen n1991_nouni  = rowtotal(n1991_nouni_pleno n1991_nouni_nopleno)

egen n1998_uni    = rowtotal(n1998_uni_pleno n1998_uni_nopleno)
egen n1998_nouni  = rowtotal(n1998_nouni_pleno n1998_nouni_nopleno)

egen rowtot_1991 = rowtotal(n1991_nouni n1991_uni)  
gen rowper_1991_uni = n1991_uni / rowtot_1991

egen rowtot_1998 = rowtotal(n1998_nouni n1998_uni)
gen rowper_1998_uni = n1998_uni / rowtot_1998

* ============================================================
* CRECIMIENTO
* ============================================================

gen uni_crecimiento = ((n1998_uni/n1991_uni)-1)*100
gen nouni_crecimiento = ((n1998_nouni/n1991_nouni)-1)*100

gen rowtot_crecimiento = ((rowtot_1998/rowtot_1991)-1)*100

preserve

gsort - rowtot_1998

keep uni_crecimiento nouni_crecimiento rama1 rowtot_1998

keep if inlist(rama1, 1, 3, 6, 7, 9)

list
graph bar (mean) uni_crecimiento nouni_crecimiento, ///
    over(rama1, label(angle(45) labsize(small))) ///
    legend(order(1 "calificados" 2 "No calificados")) 

restore



* ============================================================
* 8. GRÁFICOS CRECIMIENTO Y EDUCACIÓN
* ============================================================

reg rowtot_crecimiento rowper_1991_uni [aweight = rowtot_1991] if rama1 != 18
local slope : display %6.3f _b[rowper_1991_uni]

summ rowper_1991_uni  
local midx = r(mean)

summ rowtot_crecimiento
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowtot_crecimiento rowper_1991_uni [aweight = rowtot_1991]) ///
    (lfit    rowtot_crecimiento rowper_1991_uni [aweight = rowtot_1991]) ///
    if rama1 != 18, text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_crec_1991_1998, replace) 



* ============================================================
* 9. AGRUPACIÓN: EMPLEO PLENO vs NO PLENO
* ============================================================

egen n1991_pleno    = rowtotal(n1991_uni_pleno n1991_nouni_pleno)
egen n1991_nopleno  = rowtotal(n1991_uni_nopleno n1991_nouni_nopleno)

egen n1998_pleno    = rowtotal(n1998_uni_pleno n1998_nouni_pleno)
egen n1998_nopleno  = rowtotal(n1998_uni_nopleno n1998_nouni_nopleno)

gen rowper_1991_pleno = n1991_pleno / rowtot_1991
gen rowper_1998_pleno = n1998_pleno / rowtot_1998


* ============================================================
* 10. GRÁFICOS CON RECTAS DE REGRESIÓN Y ETIQUETA DE PENDIENTE
* ============================================================

* ===== Gráfico 1991 =====
reg rowper_1991_uni rowper_1991_pleno [aweight = rowtot_1991]
local slope : display %6.3f _b[rowper_1991_pleno]

summ rowper_1991_pleno
local midx = r(mean)

summ rowper_1991_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_1991_uni rowper_1991_pleno [aweight = rowtot_1991] ) ///
    (lfit    rowper_1991_uni rowper_1991_pleno [aweight = rowtot_1991] ) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_1991, replace)


* ===== Gráfico 1998 =====
reg rowper_1998_uni rowper_1998_pleno [aweight = rowtot_1998]
local slope : display %6.3f _b[rowper_1998_pleno]

summ rowper_1998_pleno
local midx = r(mean)

summ rowper_1998_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_1998_uni rowper_1998_pleno [aweight = rowtot_1998]) ///
    (lfit    rowper_1998_uni rowper_1998_pleno [aweight = rowtot_1998]) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_1998, replace)


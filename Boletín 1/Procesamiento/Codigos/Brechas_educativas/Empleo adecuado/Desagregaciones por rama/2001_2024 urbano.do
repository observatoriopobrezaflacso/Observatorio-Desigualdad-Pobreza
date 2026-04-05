clear

* ============================================================
* 1. RUTAS Y CARGA DE BASES
* ============================================================

* Ruta global para facilitar portabilidad del código
global limpias "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases/Procesadas/ramas homogeneizadas"


* Cargar base 2001 con variables relevantes
use rama1 nivinst condact fexp area  using "$limpias/empleo2001.dta", clear

rename *, lower                         // uniformidad en minúsculas
rename condact condact_2001             // diferenciación por año
rename nivinst p10a_2001
gen anio = "2001_"                      // marca de año para reshape futuro


* Cargar base 2010 con variables relevantes
append using "$limpias/empleo2010.dta", keep(rama1 p10a CONDACT fexp are) 

rename *, lower                         // uniformidad en minúsculas
rename condact condact_2010             // diferenciación por año
replace anio = "2010_" if anio == ""    // completar años faltantes

* Cargar base 2011 con variables relevantes
append using ///
    "$limpias/empleo2011.dta", keep(rama1 p10a CONDACT fexp area ) 

rename *, lower                         // uniformidad en minúsculas
rename condact condact_2011             // diferenciación por año
replace anio = "2011_" if anio == ""    // completar años faltantes
	
* Añadir base 2024
append using ///
    "$limpias/empleo2024.dta", keep(condact fexp area  rama1 p10a) force

replace anio = "2024_" if anio == ""    // completar años faltantes
rename condact condact_2024

* ============================================================
* 2. FILTRO AREA
* ============================================================

keep if area == 1 
drop area

* ============================================================
* 2. VARIABLES CLAVES: EMPLEO PLENO Y NIVEL EDUCATIVO
* ============================================================

* Empleo pleno: condiciones 1 = pleno
gen empleo_pleno = inlist(1, condact_2001, condact_2010, condact_2011, condact_2024)

* Exclusión de categorías no válidas
replace empleo_pleno = . if inlist(condact_2001, 7, 8, 9)
replace empleo_pleno = . if inlist(condact_2010, 7, 8)
replace empleo_pleno = . if inlist(condact_2011, 7, 8)
replace empleo_pleno = . if inlist(condact_2024, 0, 9)



* Universitario
gen universitario = inlist(p10a, 9, 10)
replace universitario = 1 if p10a_2001 == 6 | p10a_2001 == 7
drop p10a

* Conservar solo variables necesarias
keep rama1 universitario empleo_pleno anio fexp 


* ============================================================
* 3. GENERACIÓN DE N Y PONDERACIÓN
* ============================================================

* Crear contador de observaciones válidas
gen n_obs = !inlist(., rama1, universitario, empleo_pleno)
replace n_obs = . if n_obs == 0

gen n = n_obs
replace n = n_obs * fexp           // expansión con factor de expansión

* Codificar empleo pleno como string para pivotear después
tostring empleo_pleno, replace
replace empleo_pleno = "pleno"   if empleo_pleno == "1"
replace empleo_pleno = "nopleno" if empleo_pleno == "0"
keep if empleo_pleno !="."

* Codificar universitario como string
tostring universitario, replace
replace universitario = "uni_"    if universitario == "1"
replace universitario = "nouni_"  if universitario == "0"


* ============================================================
* 3. ETIQUETAS PARA GRÁFICOS
* ============================================================


label define rama_graph  1 "Agricult./Silvicult./Pesca" 3 "Manufactura" 6 "Construcción" 7 "Comercio" 9 "Alojamiento y comida"

label value rama1 rama_graph



* ============================================================
* 4. COLAPSOS PARA OBTENER TABLAS DE CONTINGENCIA
* ============================================================

collapse (sum) n, by(rama1 universitario anio empleo_pleno)

* Reordenar base a formato ancho: primero año
reshape wide n, i(rama1 universitario empleo_pleno) j(anio) string 

* Luego nivel educativo
reshape wide n*, i(rama1 empleo_pleno) j(universitario) string

* Finalmente empleo pleno
reshape wide n*, i(rama1) j(empleo_pleno) string


* ============================================================
**# 2001-2010
* ============================================================

* ============================================================
* 5. PROPORCIONES DENTRO DE CADA GRUPO
* ============================================================

* Proporción sin universidad y sin empleo pleno en 2001
egen tot_2001_nouni_nopleno = total(n2001_nouni_nopleno)
gen per_2001_nouni_nopleno = n2001_nouni_nopleno / tot_2001_nouni_nopleno 

* Proporción sin universidad y con empleo pleno en 2010
egen tot_2010_nouni_pleno = total(n2010_nouni_pleno)
gen per_2010_nouni_pleno = n2010_nouni_pleno / tot_2010_nouni_pleno

* Proporciones para universitarios
egen tot_2001_uni_nopleno = total(n2001_uni_nopleno)
gen per_2001_uni_nopleno = n2001_uni_nopleno / tot_2001_uni_nopleno 

egen tot_2010_uni_pleno = total(n2010_uni_pleno)
gen per_2010_uni_pleno = n2010_uni_pleno / tot_2010_uni_pleno

* ============================================================
* 6. AGRUPACIÓN: UNIVERSITARIOS vs NO UNIVERSITARIOS
* ============================================================

egen n2001_uni    = rowtotal(n2001_uni_pleno n2001_uni_nopleno)
egen n2001_nouni  = rowtotal(n2001_nouni_pleno n2001_nouni_nopleno)

egen n2010_uni    = rowtotal(n2010_uni_pleno n2010_uni_nopleno)
egen n2010_nouni  = rowtotal(n2010_nouni_pleno n2010_nouni_nopleno)

egen rowtot_2001 = rowtotal(n2001_nouni n2001_uni)  
gen rowper_2001_uni = n2001_uni / rowtot_2001

egen rowtot_2010 = rowtotal(n2010_nouni n2010_uni)
gen rowper_2010_uni = n2010_uni / rowtot_2010

* ============================================================
* CRECIMIENTO
* ============================================================

gen uni_crecimiento = ((n2010_uni/n2001_uni)-1)*100
gen nouni_crecimiento = ((n2010_nouni/n2001_nouni)-1)*100

gen rowtot_crecimiento = ((rowtot_2010/rowtot_2001)-1)*100

preserve

keep uni_crecimiento nouni_crecimiento rama1 rowtot_2010
keep if inlist(rama1, 1, 3, 6, 7, 9)
graph bar (mean) uni_crecimiento nouni_crecimiento, ///
    over(rama1, label(angle(45) labsize(small))) ///
    legend(order(1 "Universitarios" 2 "No universitarios")) ///
	name(crec_01_10, replace)

restore



* ============================================================
* 8. GRÁFICOS CRECIMIENTO Y EDUCACIÓN
* ============================================================

reg rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001] if rama1 != 18
local slope : display %6.3f _b[rowper_2001_uni]

summ rowper_2001_uni  
local midx = r(mean)

summ rowtot_crecimiento
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001]) ///
    (lfit    rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001]) ///
    if rama1 != 18, text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_crec_2001_2010, replace) 



* ============================================================
* 9. AGRUPACIÓN: EMPLEO PLENO vs NO PLENO
* ============================================================

egen n2001_pleno    = rowtotal(n2001_uni_pleno n2001_nouni_pleno)
egen n2001_nopleno  = rowtotal(n2001_uni_nopleno n2001_nouni_nopleno)

egen n2010_pleno    = rowtotal(n2010_uni_pleno n2010_nouni_pleno)
egen n2010_nopleno  = rowtotal(n2010_uni_nopleno n2010_nouni_nopleno)

gen rowper_2001_pleno = n2001_pleno / rowtot_2001
gen rowper_2010_pleno = n2010_pleno / rowtot_2010


* ============================================================
* 10. GRÁFICOS CON RECTAS DE REGRESIÓN Y ETIQUETA DE PENDIENTE
* ============================================================

* ===== Gráfico 2001 =====
reg rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001]
local slope : display %6.3f _b[rowper_2001_pleno]

summ rowper_2001_pleno
local midx = r(mean)

summ rowper_2001_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001] ) ///
    (lfit    rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001] ) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2001, replace)


* ===== Gráfico 2010 =====
reg rowper_2010_uni rowper_2010_pleno [aweight = rowtot_2010]
local slope : display %6.3f _b[rowper_2010_pleno]

summ rowper_2010_pleno
local midx = r(mean)

summ rowper_2010_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2010_uni rowper_2010_pleno [aweight = rowtot_2010]) ///
    (lfit    rowper_2010_uni rowper_2010_pleno [aweight = rowtot_2010]) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2010, replace)



* ============================================================
* 2011-2024
* ============================================================

* ============================================================
* 5. PROPORCIONES DENTRO DE CADA GRUPO
* ============================================================

* Proporción sin universidad y sin empleo pleno en 2011
egen tot_2011_nouni_nopleno = total(n2011_nouni_nopleno)
gen per_2011_nouni_nopleno = n2011_nouni_nopleno / tot_2011_nouni_nopleno 

* Proporción sin universidad y con empleo pleno en 2024
egen tot_2024_nouni_pleno = total(n2024_nouni_pleno)
gen per_2024_nouni_pleno = n2024_nouni_pleno / tot_2024_nouni_pleno

* Proporciones para universitarios
egen tot_2011_uni_nopleno = total(n2011_uni_nopleno)
gen per_2011_uni_nopleno = n2011_uni_nopleno / tot_2011_uni_nopleno 

egen tot_2024_uni_pleno = total(n2024_uni_pleno)
gen per_2024_uni_pleno = n2024_uni_pleno / tot_2024_uni_pleno

* ============================================================
* 6. AGRUPACIÓN: UNIVERSITARIOS vs NO UNIVERSITARIOS
* ============================================================

egen n2011_uni    = rowtotal(n2011_uni_pleno n2011_uni_nopleno)
egen n2011_nouni  = rowtotal(n2011_nouni_pleno n2011_nouni_nopleno)

egen n2024_uni    = rowtotal(n2024_uni_pleno n2024_uni_nopleno)
egen n2024_nouni  = rowtotal(n2024_nouni_pleno n2024_nouni_nopleno)

egen rowtot_2011 = rowtotal(n2011_nouni n2011_uni)  
gen rowper_2011_uni = n2011_uni / rowtot_2011

egen rowtot_2024 = rowtotal(n2024_nouni n2024_uni)
gen rowper_2024_uni = n2024_uni / rowtot_2024

* ============================================================
* CRECIMIENTO
* ============================================================

gen uni_crecimiento_2 = ((n2024_uni/n2011_uni)-1)*100
gen nouni_crecimiento_2 = ((n2024_nouni/n2011_nouni)-1)*100

gen rowtot_crecimiento_2 = ((rowtot_2024/rowtot_2011)-1)*100

preserve

gsort - rowtot_2024

keep uni_crecimiento_2 nouni_crecimiento_2 rama1 rowtot_2024

keep in 1/5

list
graph bar (mean) uni_crecimiento_2 nouni_crecimiento_2, ///
    over(rama1, label(angle(45) labsize(small))) ///
    legend(order(1 "Universitarios" 2 "No universitarios")) 

restore

* ============================================================
* 7. AGRUPACIÓN: EMPLEO PLENO vs NO PLENO
* ============================================================

egen n2011_pleno    = rowtotal(n2011_uni_pleno n2011_nouni_pleno)
egen n2011_nopleno  = rowtotal(n2011_uni_nopleno n2011_nouni_nopleno)

egen n2024_pleno    = rowtotal(n2024_uni_pleno n2024_nouni_pleno)
egen n2024_nopleno  = rowtotal(n2024_uni_nopleno n2024_nouni_nopleno)

gen rowper_2011_pleno = n2011_pleno / rowtot_2011
gen rowper_2024_pleno = n2024_pleno / rowtot_2024


* ============================================================
* 8. GRÁFICOS CON RECTAS DE REGRESIÓN Y ETIQUETA DE PENDIENTE
* ============================================================

* ===== Gráfico 2011 =====
reg rowper_2011_uni rowper_2011_pleno [aweight = rowtot_2011]
local slope : display %6.3f _b[rowper_2011_pleno]

summ rowper_2011_pleno
local midx = r(mean)

summ rowper_2011_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2011_uni rowper_2011_pleno [aweight = rowtot_2011] ) ///
    (lfit    rowper_2011_uni rowper_2011_pleno [aweight = rowtot_2011] ) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2011, replace)


* ===== Gráfico 2024 =====
reg rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]
local slope : display %6.3f _b[rowper_2024_pleno]

summ rowper_2024_pleno
local midx = r(mean)

summ rowper_2024_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]) ///
    (lfit    rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2024, replace)

* ============================================================
* 8. GRÁFICOS CRECIMIENTO Y EDUCACIÓN
* ============================================================

reg rowtot_crecimiento_2 rowper_2011_uni [aweight = rowtot_2011] if rama1 != 18
local slope : display %6.3f _b[rowper_2011_uni]

summ rowper_2011_uni  
local midx = r(mean)

summ rowtot_crecimiento_2 
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowtot_crecimiento_2 rowper_2011_uni [aweight = rowtot_2011]) ///
    (lfit    rowtot_crecimiento_2 rowper_2011_uni [aweight = rowtot_2011]) ///
    if rama1 != 18, text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_crec_2011_2024, replace) 


	
* ============================================================
* 9. VERIFICACIÓN DE CATEGORÍAS CONDACT POR AÑO
* ============================================================

use "$limpias/empleo2011.dta", clear
rename *, lower
tab condact
tab condact, nol

use "$limpias/empleo2024.dta", clear
rename *, lower
tab condact
tab condact, nol



* ============================================================
* 2001-2024
* ============================================================

* ============================================================
* 5. PROPORCIONES DENTRO DE CADA GRUPO
* ============================================================

* Proporción sin universidad y sin empleo pleno en 2001
egen tot_2001_nouni_nopleno = total(n2001_nouni_nopleno)
gen per_2001_nouni_nopleno = n2001_nouni_nopleno / tot_2001_nouni_nopleno 

* Proporción sin universidad y con empleo pleno en 2024
egen tot_2024_nouni_pleno = total(n2024_nouni_pleno)
gen per_2024_nouni_pleno = n2024_nouni_pleno / tot_2024_nouni_pleno

* Proporciones para universitarios
egen tot_2001_uni_nopleno = total(n2001_uni_nopleno)
gen per_2001_uni_nopleno = n2001_uni_nopleno / tot_2001_uni_nopleno 

egen tot_2024_uni_pleno = total(n2024_uni_pleno)
gen per_2024_uni_pleno = n2024_uni_pleno / tot_2024_uni_pleno

* ============================================================
* 6. AGRUPACIÓN: UNIVERSITARIOS vs NO UNIVERSITARIOS
* ============================================================

egen n2001_uni    = rowtotal(n2001_uni_pleno n2001_uni_nopleno)
egen n2001_nouni  = rowtotal(n2001_nouni_pleno n2001_nouni_nopleno)

egen n2024_uni    = rowtotal(n2024_uni_pleno n2024_uni_nopleno)
egen n2024_nouni  = rowtotal(n2024_nouni_pleno n2024_nouni_nopleno)

egen rowtot_2001 = rowtotal(n2001_nouni n2001_uni)  
gen rowper_2001_uni = n2001_uni / rowtot_2001

egen rowtot_2024 = rowtotal(n2024_nouni n2024_uni)
gen rowper_2024_uni = n2024_uni / rowtot_2024

* ============================================================
* CRECIMIENTO
* ============================================================

gen uni_crecimiento = ((n2024_uni/n2001_uni)-1)*100
gen nouni_crecimiento = ((n2024_nouni/n2001_nouni)-1)*100

gen rowtot_crecimiento = ((rowtot_2024/rowtot_2001)-1)*100

preserve

keep uni_crecimiento nouni_crecimiento rama1 rowtot_2024
keep if inlist(rama1, 1, 3, 6, 7, 9)
graph bar (mean) uni_crecimiento nouni_crecimiento, ///
    over(rama1, label(angle(45) labsize(small))) ///
    legend(order(1 "Universitarios" 2 "No universitarios")) ///
	name(crec_01_10, replace)

restore



* ============================================================
* 8. GRÁFICOS CRECIMIENTO Y EDUCACIÓN
* ============================================================

reg rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001] if rama1 != 18
local slope : display %6.3f _b[rowper_2001_uni]

summ rowper_2001_uni  
local midx = r(mean)

summ rowtot_crecimiento
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001]) ///
    (lfit    rowtot_crecimiento rowper_2001_uni [aweight = rowtot_2001]) ///
    if rama1 != 18, text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_crec_2001_2024, replace) 



* ============================================================
* 9. AGRUPACIÓN: EMPLEO PLENO vs NO PLENO
* ============================================================

egen n2001_pleno    = rowtotal(n2001_uni_pleno n2001_nouni_pleno)
egen n2001_nopleno  = rowtotal(n2001_uni_nopleno n2001_nouni_nopleno)

egen n2024_pleno    = rowtotal(n2024_uni_pleno n2024_nouni_pleno)
egen n2024_nopleno  = rowtotal(n2024_uni_nopleno n2024_nouni_nopleno)

gen rowper_2001_pleno = n2001_pleno / rowtot_2001
gen rowper_2024_pleno = n2024_pleno / rowtot_2024


* ============================================================
* 10. GRÁFICOS CON RECTAS DE REGRESIÓN Y ETIQUETA DE PENDIENTE
* ============================================================

* ===== Gráfico 2001 =====
reg rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001]
local slope : display %6.3f _b[rowper_2001_pleno]

summ rowper_2001_pleno
local midx = r(mean)

summ rowper_2001_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001] ) ///
    (lfit    rowper_2001_uni rowper_2001_pleno [aweight = rowtot_2001] ) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2001, replace)


* ===== Gráfico 2024 =====
reg rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]
local slope : display %6.3f _b[rowper_2024_pleno]

summ rowper_2024_pleno
local midx = r(mean)

summ rowper_2024_uni
local midy = r(mean) + 0.05*(r(max)-r(min))

twoway ///
    (scatter rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]) ///
    (lfit    rowper_2024_uni rowper_2024_pleno [aweight = rowtot_2024]) ///
    , text(`midy' `midx' "Slope = `slope'", place(c)) ///
	name(edu_emp_2024, replace)








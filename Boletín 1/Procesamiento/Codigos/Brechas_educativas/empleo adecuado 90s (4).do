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




* Definición de rutas globales para facilitar la portabilidad del código
global bases "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases"
global raw "$bases/enemdu_diciembres"
global procesado "$bases/Procesadas"
global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Outcomes/Curvas de crecimiento"
global salarios "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Procesamiento/Bases/Salarios"



* SBUs (2000-2025)
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html#

import delimited "$salarios/Salario unificado y componentes salariales.csv", clear
encode componentesalarial, gen(componente)
drop componentesalarial 
keep if componente == 6 & mes == "Diciembre"
rename (año valor) (anio salario_min)
replace salario_min = subinstr(salario_min, ",", ".", .)
destring salario_min, replace
keep anio salario_min
tempfile tmp
save `tmp'


* Ingreso mínimo legal (SMV + bonificaciones:)
* https://contenido.bce.fin.ec/documentos/PublicacionesNotas/Catalogo/IEMensual/m1810/m1810_55.htm#:~:text=Table_content:%20header:%20%7C%20PERIODO%20%7C%20Salario%20M%C3%ADnimo,1991%20%7C%20Salario%20M%C3%ADnimo%20Vital:%2040000%20%7C

import delimited "$salarios/SMV + bonificaciones.csv", clear
keep in 12/21
rename (periodo total) (anio salario_min)
keep anio salario_min
tempfile tmp2
destring anio, replace
append using `tmp'

tempfile tm2
save `tmp2'

list 

foreach y of numlist 2001(2)2023 2024 {

di "*****************   `y'   ************************"

quietly {

	*==============================================================================*
	* PARÁMETROS DE EDAD MINIMA Y SBU                                              
	*==============================================================================*

	* Fijación de la edad mínima
	scalar edadmin = 15

	*==============================================================================*
	* PROCESAMIENTO 
	*==============================================================================*
	
	use "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", clear
	
	* Añade la variable salario mínimo a las ENEMDU
	merge m:m anio using "`tmp2'", keep(3) nogen

    *capture confirm variable area 
	*if !_rc keep if area == 1
	
	capture confirm variable ing_lab
	if !_rc capture confirm variable ingrl 
	if _rc rename ing_lab ingrl

	cap gen t = 1
	cap rename t t_a
	
	if inrange(`y', 1990, 2006) {

	rename edad p03
	rename trabajo p20
	rename actayuda p21 
	rename aunotra p22 
	rename hortrasa p24
	rename ratmeh p25
	rename bustrama  p32
	rename motnobus p34
	rename deseatra p35
	rename hortrahp p51a
	rename hortrahs p51b
	rename hortraho p51c
	if `y' >= 2000 rename hormas p27 
	
	}


	if inrange(anio, 1990, 1999) { 
	cap drop p27 
	cap gen p27 = 2  if p20 == 1 | p22 == 1 
	capture replace p27 = 1 if ratmeh1 != .
	capture replace p27 = 1 if hormas != .
	}


	*==============================================================================*
	* CONSTRUCCIÓN DE POBLACIONES DE REFERENCIA                                    
	*==============================================================================*

	* Población en Edad de Trabajar (PET)
	cap confirm variable petn
	if !_rc drop petn
	gen petn = .
	replace petn = 0 if p03 < edadmin
	replace petn = 1 if p03 >= edadmin
	label variable petn "Población en Edad de Trabajar"

	* Población Económicamente Activa (PEA)
	cap confirm variable pean
	if !_rc drop pean
	gen pean = .
	replace pean = 0 if petn == 1
	replace pean = 1 if petn == 1 & p20 == 1

	if anio >= 2007  {
		replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 <=10
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 1
	}


	else if inrange(anio, 2000, 2006)  {
		replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 10
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 2 & p34 <= 7 & p34 != 4 & p35 == 1
	}

	else {
		replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 2 & p34 >= 7 & p35 == 1
	}

	label variable pean "Población Económicamente Activa"

	* Población con Empleo (EMPLEO)
	cap confirm variable empleo
	if !_rc drop empleo
	gen empleo = .
	replace empleo = 0 if pean == 1
	replace empleo = 1 if pean == 1 & p20 == 1

	

	if inrange(anio, 2000, 2006) {
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 10
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
	}

	else {
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 11
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
	}

	label variable empleo "Población con Empleo"


	*==============================================================================*
	* 1. INGRESO LABORAL                                                           
	*==============================================================================*

	* Umbral normativo (Salario básico unificado)
	gen ila = ingrl
	replace ila = . if inlist(ila, -1, 999999)

	gen ineg = .
	replace ineg = 1 if ingrl == -1

	gen w = .
	replace w = 0 if empleo == 1 & ila < salario_min
	replace w = 1 if empleo == 1 & ila >= salario_min & ila != .
	replace w = . if ila == .
	label variable w "Umbral de ingreso laboral"
	label define w_lbl 0 "menor" 1 "mayor"
	label values w w_lbl

	*==============================================================================*
	* 2. TIEMPO DE TRABAJO                                                         
	*==============================================================================*

	* Horas de trabajo semanal
	gen horas = .
	replace horas = 0 if empleo == 1

	* Horas efectivas: persona con empleo y trabajando
	replace horas = p24 if pean == 1 & p20 == 1
	if inrange(anio, 2000, 2006) replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 10
	else                        replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 11

	* Horas habituales: persona con empleo y sin trabajar
	replace p51a = . if p51a == 999
	replace p51b = . if p51b == 999
	replace p51c = . if p51c == 999

	egen hh = rowtotal(p51a p51b p51c), missing
	replace hh = . if hh < 0

	if inrange(anio, 2000, 2006) {
		replace horas = hh if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
	} 

	else{
		replace horas = hh if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
	}

	label variable horas "Horas de trabajo semanal"

	* Umbral normativo (jornada máxima laboral)
	capture drop t
	gen t = .
	replace t = 0 if empleo == 1 & horas < 40
	replace t = 1 if empleo == 1 & horas >= 40 & horas != .
	* Ajuste para menores de edad (12-17 años)
	replace t = 0 if empleo == 1 & horas < 30 & p03 >= 12 & p03 <= 17
	replace t = 1 if empleo == 1 & horas >= 30 & p03 >= 12 & p03 <= 17
	label variable t "Umbral de horas trabajadas"

	*==============================================================================*
	* 3. DESEO Y DISPONIBILIDAD DE TRABAJAR HORAS ADICIONALES                      
	*==============================================================================*

	gen d_d = .
	replace d_d = 0 if empleo == 1

	if anio >= 2007 {
		replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
		replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
	}
	else if inrange(anio, 2000, 2006) {
		replace d_d = 0 if empleo == 1 &  p27 == 2
		replace d_d = 1 if empleo == 1 & p27 == 1 
	}

	else if inrange(anio, 1993, 1999) {
		replace d_d = 0 if empleo == 1 &  (p25 == 3 | p27 == 2)
		replace d_d = 1 if empleo == 1 & p27 == 1 	
	}
	else {
		replace d_d = 0 if empleo == 1 &  (p25 == 2 | p27 == 2)
		replace d_d = 1 if empleo == 1 & p27 == 1 	
	}


	label variable d_d "Deseo y disponibilidad de trabajar horas adicionales"
	label define d_d_lbl 0 "No desea" 1 "Si desea y está disponible"
	label values d_d d_d_lbl

	*==============================================================================*
	* AGREGACIÓN DE LA POBLACIÓN OCUPADA POR CONDICION DE ACTIVIDAD                
	*==============================================================================*
		
	* Empleo adecuado
	cap confirm variable adec
	if !_rc drop adec
	gen adec = .
	replace adec = 0 if pean == 1 & p03 >= edadmin
	replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 1
	replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0

}
	mean adec [iw = fexp]
	*mean w [iw = fexp]
	*mean t [iw = fexp]
	
    save "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", replace

}

s


tab p27 
tab p27 if p24 < 40

tab d_d
tab d_d if p24 < 40



/*

tostring idhogar, replace
bysort idhogar: gen i = _n
gen len = strlen(idhogar)
gen zero = "0"

egen idhogar1 = concat(zero zero zero idhogar) if len == 1
egen idhogar2 = concat(zero zero idhogar) if len == 2
egen idhogar3 = concat(zero idhogar) if len == 3

replace idhogar = idhogar1 if len == 1
replace idhogar = idhogar2 if len == 2
replace idhogar = idhogar3 if len == 3

gen len2 = strlen(idhogar)
bysort idhogar: gen i = _n
egen id = concat(idhogar i)
* Create subset of those who answered ratmeh1
preserve
keep if ratmeh1 != .
tempfile sub
save `sub'
restore

preserve 
keep if ratmeh !=. 

* Merge to verify subset relation
merge 1:1 id using `sub'

* Tabulate merge results
tab _merge

restore
*/









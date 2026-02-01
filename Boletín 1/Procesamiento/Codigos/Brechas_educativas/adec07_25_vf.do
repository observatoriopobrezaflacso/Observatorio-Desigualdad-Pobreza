*==============================================================================*
* DOCUMENTACIÓN DE CAMBIOS NUEVA METODOLOGÍA EMPLEO ADECUDO A 2001 -2005                     *
*==============================================================================*
*
* RENOMBRADO DE VARIABLES (nombres originales 2005 → nombres estándar):
*   edad     → p03      (edad)
*   trabajo  → p20      (trabajó la semana pasada)
*   actayuda → p21      (actividad que realizó para ayudar en su hogar)
*   aunotra  → p22      (aunque no trabajó, ¿tiene trabajo?)
*   hortrasa → p24      (horas trabajadas la semana anterior)
*   ratmeh   → p25      (razón por la que trabajó menos de 40 horas)
*   hormas   → p27      (desea trabajar más horas)
*   bustrama → p32      (buscó trabajo el mes anterior)
*   motnobus → p34      (razón por la que no buscó trabajo)
*   deseatra → p35      (desea trabajar) - SUSTITUTO de p28
*   hortrahp → p51a     (horas trabajo principal)
*   hortrahs → p51b     (horas trabajo secundario)
*   hortraho → p51c     (horas otros trabajos)
*
*------------------------------------------------------------------------------*
* CAMBIOS EN CODIFICACIÓN DE VARIABLES 2001-2001-2005:
*------------------------------------------------------------------------------*
*
* p21 - ACTIVIDAD QUE REALIZÓ PARA AYUDAR EN SU HOGAR:
*   2001-2005: 11 categorías → 11 = "no realizó ninguna actividad"
*   Nueva met: 12 categorías → 12 = "no realizó ninguna actividad"
*   AJUSTE: Usar <= 10 en lugar de <= 11; usar == 11 en lugar de == 12
*
* p25 - RAZÓN POR LA QUE TRABAJÓ MENOS DE 40 HORAS:
*   2001-2005: 8 categorías  → NO existe "No desea o no necesita"
*   Nueva met: 9 categorías  → 9 = "No desea o no necesita"
*   AJUSTE: No se puede usar condición p25 == 9 en 2005 (no existe)
*
* p27 - DESEA TRABAJAR MÁS HORAS:
*   2001-2005: 2 categorías → 1 = "sí", 2 = "no"
*   Nueva met: 4 categorías → 1-3 = opciones de sí, 4 = "no desea"
*   AJUSTE: Usar p27 == 1 en lugar de p27 <= 3; usar p27 == 2 en lugar de p27 == 4
*
* p28 - DISPONIBILIDAD PARA TRABAJAR MÁS HORAS:
*   2001-2005: NO EXISTE esta variable
*   Nueva met: Existe p28 = 1 (sí disponible)
*   AJUSTE: No se usa (se asume que si quiere trabajar más, también está dispoible)
*
* p32 - BUSCÓ TRABAJO EL MES ANTERIOR:
*   2001-2005: 2 categorías  → 1 = "sí", 2 = "no"
*   Nueva met: 11 categorías → 1-10 = formas de búsqueda, 11 = "no buscó"
*   AJUSTE: Usar p32 == 1 en lugar de p32 <= 10; usar p32 == 2 en lugar de p32 == 11
*
* p34 - RAZÓN POR LA QUE NO BUSCÓ TRABAJO:
*   2001-2005: 11 categorías → 11 = "no tiene edad de trabajar"
*   Nueva met: 12 categorías → 12 = "no está en edad de trabajar"
*   AJUSTE: El límite superior es <= 7 para desempleo oculto (categorías de 
*           desánimo), >= 8 & <= 11 para inactivos puros
*
*------------------------------------------------------------------------------*
* RESUMEN DE AJUSTES EN CONDICIONES LÓGICAS:
*------------------------------------------------------------------------------*
*   p21 <= 11 → p21 <= 10   (realizó actividad)
*   p21 == 12 → p21 == 11   (no realizó actividad)
*   p27 <= 3  → p27 == 1    (sí desea trabajar más)
*   p27 == 4  → p27 == 2    (no desea trabajar más)
*   p32 <= 10 → p32 == 1    (sí buscó trabajo)
*   p32 == 11 → p32 == 2    (no buscó trabajo)
*   p34 == 12 → p34 == 11   (no tiene edad de trabajar)
*   p28 == 1  → p35 == 1    (disponible/desea trabajar)
*
*==============================================================================*

* Salarios mensuales obtenidos de:
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html

*local sal_min 354 375 394
local sal_min 170

local i = 0

*foreach y of numlist  2015 2017 2019 {
foreach y of numlist 2007 {

di "*****************   `y'   ************************"

quietly {

	*==============================================================================*
	* PARÁMETROS DE EDAD MINIMA Y SBU                                              
	*==============================================================================*

		
	
	* Fijación de la edad mínima
	scalar edadmin = 15

	* Fijación del Salario Básico Unificado
	local i = `i' + 1
    local sal_min_`y' = real(word("`sal_min'", `i'))
	scalar salmin = `sal_min_`y''
    noisily: di salmin	

use "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", clear

   
   	capture confirm variable ing_lab
	if !_rc & `y' != 2015 capture rename ing_lab ingrl

   
    if inrange(`y', 2001, 2005) {
 
		gen t = 1
		cap rename t t_a

		rename edad p03
		rename trabajo p20
		rename actayuda p21 
		rename aunotra p22 
		rename hortrasa p24
		rename ratmeh p25
		rename hormas p27
		rename bustrama  p32
		rename motnobus p34
		rename deseatra p35
		rename hortrahp p51a
		rename hortrahs p51b
		rename hortraho p51c
	}

		* Missings
		replace p24 = . if p24 == 999
			*==============================================================================*
		* CONSTRUCCIÓN DE POBLACIONES DE REFERENCIA                                    
		*==============================================================================*
		

		* Población en Edad de Trabajar (PET)
		if `y' >= 2007 cap drop petn
		gen petn = .
		replace petn = 0 if p03 < edadmin
		replace petn = 1 if p03 >= edadmin
		label variable petn "Población en Edad de Trabajar"

		* Población Económicamente Activa (PEA)

		if `y' >= 2007 cap drop pean
		gen pean = .
		replace pean = 0 if petn == 1
		replace pean = 1 if petn == 1 & p20 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 11
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 1
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 <= 10
		replace pean = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 1

		
		
		
		* Label the variable
		label variable pean "Población Económicamente Activa"
		

		* Población Económicamente Inactiva (PEI)
		if `y' >= 2007 cap drop pein
		gen pein = .
		replace pein = 0 if petn == 1
		replace pein = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 2
		replace pein = 1 if petn == 1 & p20 == 2 & p21 == 12 & p22 == 2 & p32 == 11 & (p34 >= 8 & p34 <= 12)
		label variable pein "Población Económicamente Inactiva"		
		
		* Población con Empleo (EMPLEO)
		if `y' >= 2007 cap drop empleo
		gen empleo = .
		replace empleo = 0 if pean == 1
		replace empleo = 1 if pean == 1 & p20 == 1
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 11
		replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
		label variable empleo "Población con Empleo"
		
		*==============================================================================*
		* FIJACIÓN DE UMBRALES MÍNIMOS DE SATISFACCIÓN								   
*==============================================================================*

		*==============================================================================*
		* 1. INGRESO LABORAL 								   
		*==============================================================================*

		* Umbral normativo (Salario básico unificado)
		gen ila = ingrl
		recode ila (-1 = .) (999999 = .)
		gen ineg = .
		replace ineg = 1 if ingrl == -1
		gen w = .
		replace w = 0 if empleo == 1 & ila < salmin
		replace w = 1 if empleo == 1 & ila >= salmin
		replace w = . if missing(ila)
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
		replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 11

		* Horas habituales: persona con empleo y sin trabajar
		recode p51a p51b p51c (999 = .)
		egen hh = rowtotal(p51a p51b p51c), missing
		replace hh = . if hh < 0
		replace horas = hh if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
		label variable horas "Horas de trabajo semanal"

		* Umbral normativo (jornada máxima laboral)
		gen t = .
		replace t = 0 if empleo == 1 & horas < 40
		replace t = 1 if empleo == 1 & horas >= 40
		replace t = 0 if empleo == 1 & horas < 30 & p03 >= 12 & p03 <= 17
		replace t = 1 if empleo == 1 & horas >= 30 & p03 >= 12 & p03 <= 17
		label variable t "Umbral de horas trabajadas"

		*==============================================================================*
		* 3. DESEO Y DISPONIBILIDAD DE TRABAJAR HORAS ADICIONALES				  
		*==============================================================================*

		* Deseo y disponibilidad de trabajar horas adicionales
		gen d_d = .
		replace d_d = 0 if empleo == 1
		replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
		replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
		label variable d_d "Deseo y disponibilidad de trabajar horas adicionales"
		label define d_d_lbl 0 "No desea" 1 "Si desea y está disponible"
		label values d_d d_d_lbl

		*==============================================================================*
		* AGREGACIÓN DE LA POBLACIÓN OCUPADA POR CONDICION DE ACTIVIDAD				   
		*==============================================================================*

		* Empleo adecuado
		if `y' >= 2007 cap drop adec
		gen adec = .
		replace adec = 0 if pean == 1 & p03 >= edadmin
		replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 1
		replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0
	}
	
	mean adec [iw = fexp]	
	*mean t [iw = fexp]	
	*mean w [iw = fexp]	

    *save "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", replace
}

stop

tab1 pean empleo w t d_d
tab1 pean empleo 


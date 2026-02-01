*==============================================================================*
* DOCUMENTACIÓN DE CAMBIOS: ADAPTACIÓN ENEMDU 2015 → 2005                      *
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
* CAMBIOS EN CODIFICACIÓN DE VARIABLES:
*------------------------------------------------------------------------------*
*
* p21 - ACTIVIDAD QUE REALIZÓ PARA AYUDAR EN SU HOGAR:
*   2005: 11 categorías → 11 = "no realizó ninguna actividad"
*   2015: 12 categorías → 12 = "no realizó ninguna actividad"
*   AJUSTE: Usar <= 10 en lugar de <= 11; usar == 11 en lugar de == 12
*
* p25 - RAZÓN POR LA QUE TRABAJÓ MENOS DE 40 HORAS:
*   2005: 8 categorías  → NO existe "No desea o no necesita"
*   2015: 9 categorías  → 9 = "No desea o no necesita"
*   AJUSTE: No se puede usar condición p25 == 9 en 2005 (no existe)
*
* p27 - DESEA TRABAJAR MÁS HORAS:
*   2005: 2 categorías → 1 = "sí", 2 = "no"
*   2015: 4 categorías → 1-3 = opciones de sí, 4 = "no desea"
*   AJUSTE: Usar p27 == 1 en lugar de p27 <= 3; usar p27 == 2 en lugar de p27 == 4
*
* p28 - DISPONIBILIDAD PARA TRABAJAR MÁS HORAS:
*   2005: NO EXISTE esta variable
*   2015: Existe p28 = 1 (sí disponible)
*   AJUSTE: Se usa p35 (deseatra) como sustituto de p28
*
* p32 - BUSCÓ TRABAJO EL MES ANTERIOR:
*   2005: 2 categorías  → 1 = "sí", 2 = "no"
*   2015: 11 categorías → 1-10 = formas de búsqueda, 11 = "no buscó"
*   AJUSTE: Usar p32 == 1 en lugar de p32 <= 10; usar p32 == 2 en lugar de p32 == 11
*
* p34 - RAZÓN POR LA QUE NO BUSCÓ TRABAJO:
*   2005: 11 categorías → 11 = "no tiene edad de trabajar"
*   2015: 12 categorías → 12 = "no está en edad de trabajar"
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

use "$procesado/ingresos_pc/ing_perca_2005_urb_precios2000.dta", clear


gen t = 1
rename t t_a

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

*replace p27 = . if p24 < 40
tab p27 if p24 < 40


*==============================================================================*
* PARÁMETROS DE EDAD MINIMA Y SBU                                              
*==============================================================================*

* Fijación de la edad mínima
scalar edadmin = 15

* Fijación del Salario Básico Unificado
scalar salmin = 174.9

*==============================================================================*
* CONSTRUCCIÓN DE POBLACIONES DE REFERENCIA                                    
*==============================================================================*

* Población en Edad de Trabajar (PET)
gen petn = .
replace petn = 0 if p03 < edadmin
replace petn = 1 if p03 >= edadmin
label variable petn "Población en Edad de Trabajar"

* Población Económicamente Activa (PEA)
gen pean = .
replace pean = 0 if petn == 1
replace pean = 1 if petn == 1 & p20 == 1
replace pean = 1 if petn == 1 & p20 == 2 & p21 <= 10
replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 1
replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 1
replace pean = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 2 & p34 <= 7 & p35 == 1
label variable pean "Población Económicamente Activa"

* Población Económicamente Inactiva (PEI)
gen pein = .
replace pein = 0 if petn == 1
replace pein = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 2
replace pein = 1 if petn == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 11 & (p34 >= 8 & p34 <= 11)
label variable pein "Población Económicamente Inactiva"

* Población con Empleo (EMPLEO)
gen empleo = .
replace empleo = 0 if pean == 1
replace empleo = 1 if pean == 1 & p20 == 1
replace empleo = 1 if pean == 1 & p20 == 2 & p21 <= 10
replace empleo = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
label variable empleo "Población con Empleo"

* Población Desempleada (DESEM)
gen desem = .
replace desem = 0 if pean == 1
replace desem = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 <= 10
replace desem = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 1
label variable desem "Población Desempleada"

* Desempleo Abierto (DESEMAB)
gen desemab = .
replace desemab = 0 if pean == 1
replace desemab = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 <= 10
label variable desemab "Desempleo abierto"

* Desempleo Oculto (DESEMOC)
gen desemoc = .
replace desemoc = 0 if pean == 1
replace desemoc = 1 if pean == 1 & p20 == 2 & p21 == 11 & p22 == 2 & p32 == 11 & p34 <= 7 & p35 == 1
label variable desemoc "Desempleo oculto"



*==============================================================================*
* 1. INGRESO LABORAL                                                           
*==============================================================================*

* Umbral normativo (Salario básico unificado)
gen ila = ing_lab
replace ila = . if inlist(ila, -1, 999999)

gen ineg = .
replace ineg = 1 if ing_lab == -1

gen w = .
replace w = 0 if empleo == 1 & ila < salmin
replace w = 1 if empleo == 1 & ila >= salmin & ila != .
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
replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 10

* Horas habituales: persona con empleo y sin trabajar
replace p51a = . if p51a == 999
replace p51b = . if p51b == 999
replace p51c = . if p51c == 999

egen hh = rowtotal(p51a p51b p51c), missing
replace hh = . if hh < 0
replace horas = hh if pean == 1 & p20 == 2 & p21 == 11 & p22 == 1
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
*replace d_d = 0 if empleo == 1 & p27 == 2
replace d_d = 1 if empleo == 1 & p27 == 1 
label variable d_d "Deseo y disponibilidad de trabajar horas adicionales"
label define d_d_lbl 0 "No desea" 1 "Si desea y está disponible"
label values d_d d_d_lbl

*==============================================================================*
* AGREGACIÓN DE LA POBLACIÓN OCUPADA POR CONDICION DE ACTIVIDAD                
*==============================================================================*

* Empleo adecuado
gen adec = .
replace adec = 0 if pean == 1 & p03 >= edadmin
replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 1
replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0

mean adec [iw = fexp]
s

/* 
En la década de los 90s, la pregunta sobre la disponibilidad para trabajar más 
horas se realizaba solo a las personas que trabajaron menos de 40h la semana    pasada. Del 2000 en adelante se realiza también a las que trabajaron más de 40h. 
Esto, sin embargo, no afecta el empleo adecuado porque la disponibilidad solo afecta este indicador cuando la persona trabajó menos de 40h. En particular, si una persona trabaja más de 40h y quiere trabajar más, se considera que tiene empleo adecuado. Si una persona trabaja menos de 40h y quiere trabajar más, se considera que no tiene empleo adecuado.  
*/

/*
d_d es mayor en comparación con 1991 porque incluye los que tienen disponibilidad de trabajar y que trabajan más de 40 horas. Sin embargo, d_d solo afecta al empleo adecuado cuando t = 0 y d_d = 1. Cuando t = 0, los números de 1991 y 2005 son muy similares
*/

/*


**2005**


. tab d_d if p24 < 40

 Deseo y disponibilidad de |
trabajar horas adicionales |      Freq.     Percent        Cum.
---------------------------+-----------------------------------
                  No desea |      1,694       36.07       36.07
Si desea y está disponible |      3,002       63.93      100.00
---------------------------+-----------------------------------
                     Total |      4,696      100.00
 

 
pe27. desea |
   trabajar |
  mas horas |      Freq.     Percent        Cum.
------------+-----------------------------------
         si |      3,091       62.18       62.18
         no |      1,880       37.82      100.00
------------+-----------------------------------
      Total |      4,971      100.00


 

**1991**

. tab p27 if p24 < 40

        p27 |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      2,903       82.21       82.21
          2 |        628       17.79      100.00
------------+-----------------------------------
      Total |      3,531      100.00



. tab d_d if p24 < 40

 Deseo y disponibilidad de |
trabajar horas adicionales |      Freq.     Percent        Cum.
---------------------------+-----------------------------------
                  No desea |        570       17.42       17.42
Si desea y está disponible |      2,703       82.58      100.00
---------------------------+-----------------------------------
                     Total |      3,273      100.00







*/

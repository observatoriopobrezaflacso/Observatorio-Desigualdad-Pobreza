
use "$procesado/ingresos_pc/ing_perca_2015_nac_precios2000.dta", clear




*==============================================================================*
* 1. INGRESO LABORAL                                                           
*==============================================================================*

* Umbral normativo (Salario básico unificado)
gen ila = ingrl
replace ila = . if inlist(ila, -1, 999999)

gen ineg = .
replace ineg = 1 if ingrl == -1

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
replace horas = p24 if pean == 1 & p20 == 2 & p21 <= 11

* Horas habituales: persona con empleo y sin trabajar
replace p51a = . if p51a == 999
replace p51b = . if p51b == 999
replace p51c = . if p51c == 999

egen hh = rowtotal(p51a p51b p51c), missing
replace hh = . if hh < 0
replace horas = hh if pean == 1 & p20 == 2 & p21 == 12 & p22 == 1
label variable horas "Horas de trabajo semanal"

* Umbral normativo (jornada máxima laboral)
drop t
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
*replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
label variable d_d "Deseo y disponibilidad de trabajar horas adicionales"
label define d_d_lbl 0 "No desea" 1 "Si desea y está disponible"
label values d_d d_d_lbl

*==============================================================================*
* AGREGACIÓN DE LA POBLACIÓN OCUPADA POR CONDICION DE ACTIVIDAD                
*==============================================================================*

* Empleo adecuado
*gen adec = .
replace adec = 0 if pean == 1 & p03 >= edadmin
replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 1
replace adec = 1 if pean == 1 & p03 >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0

mean adec [iw = fexp]

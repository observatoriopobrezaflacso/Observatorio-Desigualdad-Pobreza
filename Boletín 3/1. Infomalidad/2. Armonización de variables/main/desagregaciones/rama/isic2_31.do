clear

* Definicion de rutas globales para facilitar la portabilidad del codigo
if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"

global isic "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global out "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"

*-----------------------------------------------------------------------------
* STEP 1: Preparar correspondencia CIIU Rev. 2 -> CIIU Rev. 3.1
*------------------------------------------------------------------------------

import delimited using "$isic/ISIC2_ISIC31.txt", clear stringcols(_all)

rename (rev2 rev31) (isic2code isic31code)
destring partial2 partial31, replace ignore("\")

replace isic2code  = strtrim(isic2code)
replace isic31code = strtrim(isic31code)
drop if missing(isic2code) | missing(isic31code)

replace isic2code  = substr("0000" + isic2code,  -4, .)
replace isic31code = substr("0000" + isic31code, -4, .)

* En codigos con multiples correspondencias (un codigo viejo que se reparte
* entre varios nuevos) se elige primero la SECCION a la que apunta la mayoria
* de los destinos, y dentro de ella (o en empate) el orden anterior:
* 1) correspondencia no parcial, 2) destino no parcial, 3) mismo codigo,
* 4) codigo menor. Antes el orden anterior decidia solo, y terminaba en el
* codigo menor: el 5000 "Construccion" de la Rev. 2 iba al 1120 (servicios
* petroleros, seccion C = minas), y con el toda la construccion de los 90.
gen str2 _div = substr(isic31code, 1, 2)
gen str1 _sec = ""
replace _sec = "A" if _div >= "01" & _div <= "02"
replace _sec = "B" if _div == "05"
replace _sec = "C" if _div >= "10" & _div <= "14"
replace _sec = "D" if _div >= "15" & _div <= "37"
replace _sec = "E" if _div >= "40" & _div <= "41"
replace _sec = "F" if _div == "45"
replace _sec = "G" if _div >= "50" & _div <= "52"
replace _sec = "H" if _div == "55"
replace _sec = "I" if _div >= "60" & _div <= "64"
replace _sec = "J" if _div >= "65" & _div <= "67"
replace _sec = "K" if _div >= "70" & _div <= "74"
replace _sec = "L" if _div == "75"
replace _sec = "M" if _div == "80"
replace _sec = "N" if _div == "85"
replace _sec = "O" if _div >= "90" & _div <= "93"
replace _sec = "P" if _div >= "95" & _div <= "97"
replace _sec = "Q" if _div == "99"
bysort isic2code _sec: gen int _n_sec = _N
bysort isic2code: egen int _max_sec = max(_n_sec)
gen byte _en_modal = _n_sec == _max_sec
gen byte exact_match = isic2code == isic31code
gsort isic2code -_en_modal partial2 partial31 -exact_match isic31code
duplicates drop isic2code, force
drop _div _sec _n_sec _max_sec _en_modal

rename isic2code p40_old
rename isic31code p40

keep p40_old p40
tempfile crosswalk_clean_2_31
save `crosswalk_clean_2_31'

* Tablas de respaldo para codigos que no estan en la correspondencia: las
* subclases nacionales de la ENEMDU (p. ej. 6217, un tipo de comercio al por
* menor, cuando la tabla solo trae la clase 6200) se emparejan por su grupo
* de 3 digitos y, si no, por su division de 2 digitos.
gen str3 p3 = substr(p40_old, 1, 3)
bysort p3 (p40_old): keep if _n == 1
keep p3 p40
rename p40 p40_p3
tempfile crosswalk_clean_2_31_p3
save `crosswalk_clean_2_31_p3'
use `crosswalk_clean_2_31', clear
gen str2 p2 = substr(p40_old, 1, 2)
bysort p2 (p40_old): keep if _n == 1
keep p2 p40
rename p40 p40_p2
tempfile crosswalk_clean_2_31_p2
save `crosswalk_clean_2_31_p2'

*-----------------------------------------------------------------------------
* STEP 2: Actualizar bases 1990-1999 de CIIU Rev. 2 a Rev. 3.1
*------------------------------------------------------------------------------

forval anio = 1990/1999 {

	di "********************************`anio'********************************"

	* 1990 fue grabado en latin1; los demas anos abren sin problema.
	capture noisily use "$bases/empleo`anio'.dta", clear
	if _rc {
		di as error "  AVISO: empleo`anio'.dta no se pudo abrir directamente."
		di as error "  Intente: unicode encoding set Latin1 ; unicode translate ""$bases/empleo`anio'.dta"""
		continue
	}

	* Algunos anos (p.ej. 1999) ya traen una variable rama1 con el codigo de 4
	* digitos; se preserva como respaldo para evitar conflictos de nombres.
	capture confirm variable rama1
	if !_rc rename rama1 rama1_codigo_orig

	rename rama p40_old
	tostring p40_old, replace force
	replace p40_old = strtrim(p40_old)
	replace p40_old = substr("0000" + p40_old, -4, .) if p40_old != "" & p40_old != "."

	merge m:1 p40_old using `crosswalk_clean_2_31', keep(master match)

	* Respaldo por grupo (3 digitos) y division (2 digitos) para los codigos
	* que no estan en la tabla. "0000" es quien no tiene rama (no ocupado).
	gen str3 p3 = substr(p40_old, 1, 3)
	merge m:1 p3 using `crosswalk_clean_2_31_p3', keep(master match) nogen
	gen str2 p2 = substr(p40_old, 1, 2)
	merge m:1 p2 using `crosswalk_clean_2_31_p2', keep(master match) nogen
	replace p40 = p40_p3 if missing(p40) & !inlist(p40_old, "", ".", "0000")
	replace p40 = p40_p2 if missing(p40) & !inlist(p40_old, "", ".", "0000")
	drop p3 p2 p40_p3 p40_p2

	* Lista codigos que siguen sin mapear para revision manual.
	tab p40_old if missing(p40) & !inlist(p40_old, "", ".", "0000")

	rename p40_old rama_old_isic2
	drop _merge

	* Extrae los primeros 2 digitos del nuevo codigo CIIU Rev. 3.1.
	gen isic2 = substr(p40, 1, 2)
	gen rama_new = ""

	* Mapeo de divisiones a secciones CIIU Rev. 3.1.
	replace rama_new = "A" if isic2 >= "01" & isic2 <= "02"
	replace rama_new = "B" if isic2 == "05"
	replace rama_new = "C" if isic2 >= "10" & isic2 <= "14"
	replace rama_new = "D" if isic2 >= "15" & isic2 <= "37"
	replace rama_new = "E" if isic2 >= "40" & isic2 <= "41"
	replace rama_new = "F" if isic2 == "45"
	replace rama_new = "G" if isic2 >= "50" & isic2 <= "52"
	replace rama_new = "H" if isic2 == "55"
	replace rama_new = "I" if isic2 >= "60" & isic2 <= "64"
	replace rama_new = "J" if isic2 >= "65" & isic2 <= "67"
	replace rama_new = "K" if isic2 >= "70" & isic2 <= "74"
	replace rama_new = "L" if isic2 == "75"
	replace rama_new = "M" if isic2 == "80"
	replace rama_new = "N" if isic2 == "85"
	replace rama_new = "O" if isic2 >= "90" & isic2 <= "93"
	replace rama_new = "P" if isic2 >= "95" & isic2 <= "97"
	replace rama_new = "Q" if isic2 == "99"

	* Codificacion deterministica: la letra define directamente el numero
	* (A=1, B=2, ..., Q=17) independiente de las secciones presentes.
	* strpos retorna 1 cuando la aguja es vacia, asi que se filtra explicito.
	gen byte rama_final = strpos("ABCDEFGHIJKLMNOPQ", rama_new) if rama_new != ""
	replace rama_final = . if rama_final == 0

	label define isic31_secciones ///
		1 "Agricultura, caza y silvicultura" ///
		2 "Pesca" ///
		3 "Explotacion de minas y canteras" ///
		4 "Industria manufacturera" ///
		5 "Electricidad, gas y agua" ///
		6 "Construccion" ///
		7 "Comercio al por mayor y al por menor; reparacion de vehiculos automotores, motocicletas y efectos personales y enseres domesticos" ///
		8 "Hoteles y restaurantes" ///
		9 "Transporte, almacenamiento y comunicaciones" ///
		10 "Intermediacion financiera" ///
		11 "Actividades inmobiliarias, empresariales y de alquiler" ///
		12 "Administracion publica y defensa; seguridad social de afiliacion obligatoria" ///
		13 "Educacion" ///
		14 "Servicios sociales y de salud" ///
		15 "Otras actividades de servicios comunitarios, sociales y personales" ///
		16 "Actividades de los hogares como empleadores y actividades de produccion no diferenciada de los hogares" ///
		17 "Organizaciones y organos extraterritoriales", replace

	label values rama_final isic31_secciones
	rename rama_final rama1

	drop isic2 rama_new

	save "$out/empleo`anio'_isic31.dta", replace

}

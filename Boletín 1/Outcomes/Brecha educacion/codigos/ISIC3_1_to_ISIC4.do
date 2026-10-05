clear

* Definicion de rutas globales para facilitar la portabilidad del codigo

if "`c(username)'" == "vero" global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
else                         global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"


global isic "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global out "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"

*-----------------------------------------------------------------------------
* STEP 1: Preparar correspondencia CIIU Rev. 3.1 -> CIIU Rev. 4
*------------------------------------------------------------------------------

import delimited using "$isic/ISIC31_ISIC4.txt", clear

tostring isic31code, replace
tostring isic4code,  replace
replace isic31code = strtrim(isic31code)
replace isic4code  = strtrim(isic4code)
drop if missing(isic31code) | missing(isic4code)

replace isic31code = substr("0000" + isic31code, -4, .)
replace isic4code  = substr("0000" + isic4code,  -4, .)

* En codigos con multiples correspondencias se elige primero la SECCION a la
* que apunta la mayoria de los destinos, y dentro de ella (o en empate) el
* orden anterior: 1) correspondencia no parcial, 2) destino no parcial,
* 3) mismo codigo, 4) codigo menor. Ojo: partialISIC4 = 0 no marca el destino
* principal del codigo viejo, sino que la clase NUEVA sale entera de el; por
* eso, ordenando solo por los parciales, el 4540 "terminacion de edificios"
* iba al 3320 (instalacion de maquinaria, manufactura) y no a construccion.
gen str2 _div = substr(isic4code, 1, 2)
gen str1 _sec = ""
replace _sec = "A" if _div >= "01" & _div <= "03"
replace _sec = "B" if _div >= "05" & _div <= "09"
replace _sec = "C" if _div >= "10" & _div <= "33"
replace _sec = "D" if _div >= "35" & _div <= "35"
replace _sec = "E" if _div >= "36" & _div <= "39"
replace _sec = "F" if _div >= "41" & _div <= "43"
replace _sec = "G" if _div >= "45" & _div <= "47"
replace _sec = "H" if _div >= "49" & _div <= "53"
replace _sec = "I" if _div >= "55" & _div <= "56"
replace _sec = "J" if _div >= "58" & _div <= "63"
replace _sec = "K" if _div >= "64" & _div <= "66"
replace _sec = "L" if _div >= "68" & _div <= "68"
replace _sec = "M" if _div >= "69" & _div <= "75"
replace _sec = "N" if _div >= "77" & _div <= "82"
replace _sec = "O" if _div >= "84" & _div <= "84"
replace _sec = "P" if _div >= "85" & _div <= "85"
replace _sec = "Q" if _div >= "86" & _div <= "88"
replace _sec = "R" if _div >= "90" & _div <= "93"
replace _sec = "S" if _div >= "94" & _div <= "96"
replace _sec = "T" if _div >= "97" & _div <= "98"
replace _sec = "U" if _div >= "99" & _div <= "99"
bysort isic31code _sec: gen int _n_sec = _N
bysort isic31code: egen int _max_sec = max(_n_sec)
gen byte _en_modal = _n_sec == _max_sec
gen byte exact_match = isic31code == isic4code
gsort isic31code -_en_modal partialisic31 partialisic4 -exact_match isic4code
duplicates drop isic31code, force
drop _div _sec _n_sec _max_sec _en_modal

* Tres codigos donde la mayoria de los destinos no es el destino principal:
replace isic4code = "6820" if isic31code == "7020"   // corretaje inmobiliario -> L, no 8110
replace isic4code = "9000" if isic31code == "9214"   // artes escenicas -> R, no 7990 (venta de entradas)
replace isic4code = "9101" if isic31code == "9231"   // bibliotecas y archivos -> R, no 5912

rename isic31code p40
rename isic4code  p40_rev4_new

keep p40 p40_rev4_new
tempfile crosswalk_clean
save `crosswalk_clean'

* Respaldo para codigos que no estan en la tabla: grupo de 3 digitos y, si
* no, division de 2 digitos.
gen str3 p3 = substr(p40, 1, 3)
bysort p3 (p40): keep if _n == 1
keep p3 p40_rev4_new
rename p40_rev4_new p40_p3
tempfile crosswalk_clean_p3
save `crosswalk_clean_p3'
use `crosswalk_clean', clear
gen str2 p2 = substr(p40, 1, 2)
bysort p2 (p40): keep if _n == 1
keep p2 p40_rev4_new
rename p40_rev4_new p40_p2
tempfile crosswalk_clean_p2
save `crosswalk_clean_p2'

*-----------------------------------------------------------------------------
* STEP 2: Actualizar bases 1991-2012 de CIIU Rev. 3.1 a Rev. 4
*
* Fuentes de entrada:
*   - 1991-1999: $out/empleo`anio'_isic31.dta (salida de isic2_31.do)
*   - 2000-2006: $out/empleo`anio'_isic31.dta (salida de isic3_31.do)
*   - 2007-2012: empleo`anio'.dta original (ya estan en Rev. 3.1)
*------------------------------------------------------------------------------

forval anio = 1991/2012 {

	di "********************************`anio'********************************"

	if (inrange(`anio', 1991, 2006)) {
		capture noisily use "$out/empleo`anio'_isic31.dta", clear
		if _rc {
			di as error "  AVISO: falta empleo`anio'_isic31.dta. Ejecute isic2_31.do / isic3_31.do primero."
			continue
		}
	}
	else {
		use "$bases/empleo`anio'.dta", clear
	}

	* Asegura que p40 sea string de 4 digitos (ej. "0111").
	tostring p40, replace force
	replace p40 = strtrim(p40)
	replace p40 = substr("0000" + p40, -4, .) if p40 != "" & p40 != "."

	* Fusiona con el crosswalk Rev. 3.1 -> Rev. 4.
	merge m:1 p40 using `crosswalk_clean', keep(master match)

	drop _merge

	* Respaldo por grupo y division para los codigos que no estan en la tabla.
	gen str3 p3 = substr(p40, 1, 3)
	merge m:1 p3 using `crosswalk_clean_p3', keep(master match) nogen
	gen str2 p2 = substr(p40, 1, 2)
	merge m:1 p2 using `crosswalk_clean_p2', keep(master match) nogen
	replace p40_rev4_new = p40_p3 if missing(p40_rev4_new) & !inlist(p40, "", ".", "0000")
	replace p40_rev4_new = p40_p2 if missing(p40_rev4_new) & !inlist(p40, "", ".", "0000")
	drop p3 p2 p40_p3 p40_p2

	* Lista codigos que siguen sin mapear para revision manual.
	tab p40 if missing(p40_rev4_new) & !inlist(p40, "", ".", "0000")

	rename p40           p40_old_isic31
	rename p40_rev4_new  p40

	*--------------------------------------------------------------------------
	* STEP 3: Generar la nueva 'rama1' (Secciones A-U) bajo CIIU Rev. 4
	*--------------------------------------------------------------------------

	gen rama_new = ""
	gen isic2 = substr(p40, 1, 2)

	replace rama_new = "A" if isic2 >= "01" & isic2 <= "03"
	replace rama_new = "B" if isic2 >= "05" & isic2 <= "09"
	replace rama_new = "C" if isic2 >= "10" & isic2 <= "33"
	replace rama_new = "D" if isic2 == "35"
	replace rama_new = "E" if isic2 >= "36" & isic2 <= "39"
	replace rama_new = "F" if isic2 >= "41" & isic2 <= "43"
	replace rama_new = "G" if isic2 >= "45" & isic2 <= "47"
	replace rama_new = "H" if isic2 >= "49" & isic2 <= "53"
	replace rama_new = "I" if isic2 >= "55" & isic2 <= "56"
	replace rama_new = "J" if isic2 >= "58" & isic2 <= "63"
	replace rama_new = "K" if isic2 >= "64" & isic2 <= "66"
	replace rama_new = "L" if isic2 == "68"
	replace rama_new = "M" if isic2 >= "69" & isic2 <= "75"
	replace rama_new = "N" if isic2 >= "77" & isic2 <= "82"
	replace rama_new = "O" if isic2 == "84"
	replace rama_new = "P" if isic2 == "85"
	replace rama_new = "Q" if isic2 >= "86" & isic2 <= "88"
	replace rama_new = "R" if isic2 >= "90" & isic2 <= "93"
	replace rama_new = "S" if isic2 >= "94" & isic2 <= "96"
	replace rama_new = "T" if isic2 >= "97" & isic2 <= "98"
	replace rama_new = "U" if isic2 == "99"

	* Conserva la seccion anterior (Rev. 3.1) como respaldo si existia.
	capture confirm variable rama1
	if !_rc rename rama1 rama_old_isic31

	* Codificacion deterministica: la letra define directamente el numero
	* (A=1, B=2, ..., U=21) independiente de las secciones presentes.
	* strpos retorna 1 cuando la aguja es vacia, asi que se filtra explicito.
	gen byte rama1 = strpos("ABCDEFGHIJKLMNOPQRSTU", rama_new) if rama_new != ""
	replace rama1 = . if rama1 == 0
	drop isic2 rama_new

	label define rama_isic4 ///
		1  "A. Agricultura, ganaderia, silvicultura y pesca" ///
		2  "B. Explotacion de minas y canteras" ///
		3  "C. Industrias manufactureras" ///
		4  "D. Suministros de electricidad, gas, vapor y aire acondicionado" ///
		5  "E. Distribucion de agua; alcantarillado, gestion de desechos y saneamiento" ///
		6  "F. Construccion" ///
		7  "G. Comercio al por mayor y al por menor; reparacion de vehiculos automotores y motocicletas" ///
		8  "H. Transporte y almacenamiento" ///
		9  "I. Actividades de alojamiento y de servicio de comidas" ///
		10 "J. Informacion y comunicaciones" ///
		11 "K. Actividades financieras y de seguros" ///
		12 "L. Actividades inmobiliarias" ///
		13 "M. Actividades profesionales, cientificas y tecnicas" ///
		14 "N. Actividades de servicios administrativos y de apoyo" ///
		15 "O. Administracion publica y defensa; seguridad social de afiliacion obligatoria" ///
		16 "P. Ensenanza" ///
		17 "Q. Actividades de atencion de la salud humana y de asistencia social" ///
		18 "R. Actividades artisticas, de entretenimiento y recreativas" ///
		19 "S. Otras actividades de servicios" ///
		20 "T. Actividades de los hogares como empleadores" ///
		21 "U. Actividades de organizaciones y organos extraterritoriales", replace

	label values rama1 rama_isic4

	save "$out/empleo`anio'_isic4.dta", replace
}

*-----------------------------------------------------------------------------
* STEP 4: Pass-through 2013-2025 (ya estan en CIIU Rev. 4 nativamente)
*
* Solo se renormaliza la etiqueta de rama1 al mismo formato Rev. 4 y se guarda
* con sufijo _isic4 para mantener la nomenclatura uniforme de salida.
*------------------------------------------------------------------------------

forval anio = 2013/2025 {

	di "********************************`anio' (nativo Rev. 4)********************************"

	capture confirm file "$bases/empleo`anio'.dta"
	if _rc continue
	use "$bases/empleo`anio'.dta", clear

	* Normaliza p40 a string de 4 digitos.
	capture confirm variable p40
	if !_rc {
		tostring p40, replace force
		replace p40 = strtrim(p40)
		replace p40 = substr("0000" + p40, -4, .) if p40 != "" & p40 != "."
	}

	* Asegura tipo numerico de rama1 con la misma etiqueta Rev. 4.
	capture confirm variable rama1
	if !_rc {
		capture confirm numeric variable rama1
		if _rc {
			destring rama1, replace force
		}
		label define rama_isic4 ///
			1  "A. Agricultura, ganaderia, silvicultura y pesca" ///
			2  "B. Explotacion de minas y canteras" ///
			3  "C. Industrias manufactureras" ///
			4  "D. Suministros de electricidad, gas, vapor y aire acondicionado" ///
			5  "E. Distribucion de agua; alcantarillado, gestion de desechos y saneamiento" ///
			6  "F. Construccion" ///
			7  "G. Comercio al por mayor y al por menor; reparacion de vehiculos automotores y motocicletas" ///
			8  "H. Transporte y almacenamiento" ///
			9  "I. Actividades de alojamiento y de servicio de comidas" ///
			10 "J. Informacion y comunicaciones" ///
			11 "K. Actividades financieras y de seguros" ///
			12 "L. Actividades inmobiliarias" ///
			13 "M. Actividades profesionales, cientificas y tecnicas" ///
			14 "N. Actividades de servicios administrativos y de apoyo" ///
			15 "O. Administracion publica y defensa; seguridad social de afiliacion obligatoria" ///
			16 "P. Ensenanza" ///
			17 "Q. Actividades de atencion de la salud humana y de asistencia social" ///
			18 "R. Actividades artisticas, de entretenimiento y recreativas" ///
			19 "S. Otras actividades de servicios" ///
			20 "T. Actividades de los hogares como empleadores" ///
			21 "U. Actividades de organizaciones y organos extraterritoriales", replace
		label values rama1 rama_isic4
	}

	save "$out/empleo`anio'_isic4.dta", replace
}

clear

* Definicion de rutas globales para facilitar la portabilidad del codigo

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

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

* En codigos con multiples correspondencias se prioriza:
* 1) correspondencia no parcial, 2) destino no parcial, 3) mismo codigo.
gen byte exact_match = isic31code == isic4code
gsort isic31code partialisic31 partialisic4 -exact_match isic4code
duplicates drop isic31code, force

rename isic31code p40
rename isic4code  p40_rev4_new

keep p40 p40_rev4_new
tempfile crosswalk_clean
save `crosswalk_clean'

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

	* Lista codigos no mapeados para revision manual.
	tab p40 if missing(p40_rev4_new) & p40 != ""
	drop _merge

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

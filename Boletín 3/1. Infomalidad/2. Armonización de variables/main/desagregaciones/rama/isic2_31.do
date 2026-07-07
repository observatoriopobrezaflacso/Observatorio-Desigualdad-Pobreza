clear

* Definicion de rutas globales para facilitar la portabilidad del codigo
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

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

* En codigos con multiples correspondencias se prioriza:
* 1) correspondencia no parcial, 2) destino no parcial, 3) mismo codigo.
gen byte exact_match = isic2code == isic31code
gsort isic2code partial2 partial31 -exact_match isic31code
duplicates drop isic2code, force

rename isic2code  p40_old
rename isic31code p40

keep p40_old p40
tempfile crosswalk_clean_2_31
save `crosswalk_clean_2_31'

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

	* Lista codigos no mapeados para revision manual.
	tab p40_old if missing(p40) & p40_old != ""

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

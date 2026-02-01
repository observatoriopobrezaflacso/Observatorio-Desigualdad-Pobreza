clear

* Definición de rutas globales para facilitar la portabilidad del código
global raw "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Bases/enemdu_diciembres"

global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brecha educacion/Bases/bases limpias"


foreach anio of numlist 1991 1998 {


	*-----------------------------------------------------------------------------
	* STEP 1: Prepare the Crosswalk (using the structure from your image)
	* ------------------------------------------------------------------------------

	* Load your crosswalk file (assuming it is saved as crosswalk.dta)
	import delimited using "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\Bases\ISIC2_ISIC31.txt", clear


	* Suponiendo que 'crosswalk_2_to_31.dta' ya tiene las columnas:
	* isic2code (ISIC Rev. 2 code)
	* isic31code (ISIC Rev. 3.1 code)

	rename (rev2 rev3) (isic2code isic31code)

	* Asegura que los códigos sean strings y maneja los ceros iniciales si es necesario.
	tostring isic2code, replace
	tostring isic31code, replace

	* Manejo de la relación de muchos a muchos (M:M) de la tabla original[cite: 6150].
	* Se mantiene la primera ocurrencia (la que tenga la parte más grande o la principal)[cite: 5860, 5863].
	duplicates drop isic2code, force

	* Renombra para fusionar
	rename isic2code p40_old
	rename isic31code p40_new

	tempfile crosswalk_clean_2_31


	save `crosswalk_clean_2_31'


	* Carga su conjunto de datos de 2011 (asumiendo que contiene códigos Rev. 2)
	use "$raw/empleo`anio'.dta", clear

	* Renombra la variable actual de 4 dígitos (Rev 2) y crea la clave de fusión.
	rename rama p40_old
	tostring p40_old, replace 

	* Fusiona con el crosswalk limpio
	merge m:1 p40_old using `crosswalk_clean_2_31'

	* Crea la nueva variable de código CIIU Rev. 3.1 (p40)
	rename p40_new p40 

	* Mantiene solo los registros fusionados (puede ajustar el 'keep' si necesita los no fusionados)
	keep if _merge == 3 | _merge == 1
	drop _merge

	* Lista códigos no mapeados para revisión manual
	tab p40_old if p40 == ""


	* Renombra la variable de sección original como respaldo.
	rename rama rama_old_rev2 

	* Extrae los primeros 2 dígitos del nuevo código (Rev 3.1)
	gen isic2 = substr(p40, 1, 2)
	gen rama_new = ""

	* Mapeo de Divisiones a Secciones CIIU Rev. 3.1 [cite: 4316, 4319, 4322]
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

	* Crea la variable final 'rama' como numérica con etiquetas completas (como solicitó anteriormente)
	encode rama_new, gen(rama_final)

	* Define y aplica las etiquetas de valor (tomando la lista de 17 Secciones Rev. 3.1)
	label define isic31_secciones 1 "Agricultura, caza y silvicultura" ///
	2 "Pesca" ///
	3 "Explotación de minas y canteras" ///
	4 "Industria manufacturera" ///
	5 "Electricidad, gas y agua" ///
	6 "Construcción" ///
	7 "Comercio al por mayor y al por menor; reparación de vehículos automotores, motocicletas y efectos personales y enseres domésticos" ///
	8 "Hoteles y restaurantes" ///
	9 "Transporte, almacenamiento y comunicaciones" ///
	10 "Intermediación financiera" ///
	11 "Actividades inmobiliarias, empresariales y de alquiler" ///
	12 "Administración pública y defensa; seguridad social de afiliación obligatoria" ///
	13 "Educación" ///
	14 "Servicios sociales y de salud" ///
	15 "Otras actividades de servicios comunitarios, sociales y personales" ///
	16 "Actividades de los hogares como empleadores y actividades de producción no diferenciada de los hogares" ///
	17 "Organizaciones y órganos extraterritoriales" ///, replace

	label values rama_final isic31_secciones
	rename rama_final rama 

	drop isic2 rama_new p40_old


	save "$raw/empleo`anio'_isic31", replace

}


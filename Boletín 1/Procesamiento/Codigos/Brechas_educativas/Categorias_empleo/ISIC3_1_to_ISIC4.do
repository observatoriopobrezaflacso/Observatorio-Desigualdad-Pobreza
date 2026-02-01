clear

* Definición de rutas globales para facilitar la portabilidad del código
global raw "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Bases/enemdu_diciembres"

global out "G:/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 1/Brecha educacion/Bases/bases limpias"


*-----------------------------------------------------------------------------
* STEP 1: Prepare the Crosswalk (using the structure from your image)
* ------------------------------------------------------------------------------

* Load your crosswalk file (assuming it is saved as crosswalk.dta)
import delimited using "G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Boletín 1\Brecha educacion\Bases\ISIC31_ISIC4.txt", clear

* 1. Standardize the matching variable (ISIC 3.1)
* Your 2011 dataset likely uses "p40" as a 4-digit string (e.g., "0111").
* Your crosswalk has "isic31code" as numeric (e.g., 111). We must align them.
tostring isic31code, replace
replace isic31code = substr("0000" + isic31code, -4, .)

* 2. Standardize the target variable (ISIC 4)
* We also pad the target code to 4 digits for consistency with your 2024 data.
tostring isic4code, replace
replace isic4code = substr("0000" + isic4code, -4, .)

* 3. Handle Duplicates (One-to-Many issue)
* As seen in your image, code 111 maps to many Rev4 codes. 
* We must keep only one to merge successfully. We will arbitrarily keep the first.
* (Ideally, you would keep the one where partialisic31 == 0 if available, but most seem to be 1).
duplicates drop isic31code, force

* 4. Rename for merging
rename isic31code p40
rename isic4code p40_rev4_new

* Save temporary crosswalk
tempfile crosswalk_clean
save `crosswalk_clean'
 ------------------------------------------------------------------------------
* STEP 2: Update the 2011 Dataset ------------------------------------------------------------------------------

foreach anio of numlist 2001 2010 2011 {

* Load your dataset
use "$raw/empleo`anio'.dta", clear

if `anio' == 2001 gen p40 = rama

* Ensure p40 is string and 4 digits (e.g., "0111")
tostring p40, replace force
replace p40 = substr("0000" + p40, -4, .)

* Merge with the crosswalk
merge m:1 p40 using `crosswalk_clean', keep(master match)


* Update p40 to the new ISIC 4 code
* We save the old one as backup and overwrite p40 with the 2024 standard
rename p40 p40_old_isic31
rename p40_rev4_new p40

* ------------------------------------------------------------------------------
* STEP 3: Generate the new 'rama' (1-digit Section) for 2024 Standards
* This maps the NEW p40 (ISIC 4) to the Sections A-U.
* ------------------------------------------------------------------------------

gen rama_new = ""

* Extract first 2 digits for classification
gen isic2 = substr(p40, 1, 2)

* Mapping based on ISIC Rev. 4 Structure (UN Standard)
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

* Update the main variable
* If your 2024 rama is numeric (1-21), use `encode` below.
* If it is string (A-U), just replace.

capture confirm variable rama1 

if !_rc rename rama1 rama_old_isic31
rename rama_new rama1

* Cleanup
drop isic2


encode rama1, gen(rama_numeric)
drop rama1
rename rama_numeric rama1


label define rama 1 "Agricultura, silvicultura y pesca" ///
2 "Explotación de minas y canteras" ///
3 "Industria manufacturera" ///
4 "Suministro de electricidad, gas, vapor y aire acondicionado" ///
5 "Suministro de agua; evacuación de aguas residuales, gestión de desechos y actividades de saneamiento" ///
6 "Construcción" ///
7 "Comercio al por mayor y al por menor; reparación de vehículos automotores y motocicletas" ///
8 "Transporte y almacenamiento" ///
9 "Actividades de alojamiento y de servicio de comidas" ///
10 "Información y comunicaciones" ///
11 "Actividades financieras y de seguros" ///
12 "Actividades inmobiliarias" ///
13 "Actividades profesionales, científicas y técnicas" ///
14 "Actividades de servicios administrativos y de apoyo" ///
15 "Administración pública y defensa; seguridad social de afiliación obligatoria" ///
16 "Educación" ///
17 "Actividades de atención de la salud humana y de asistencia social" ///
18 "Actividades artísticas, de entretenimiento y recreativas" ///
19 "Otras actividades de servicios" ///
20 "Actividades de los hogares como empleadores; actividades no diferenciadas de los hogares como productores de bienes y servicios para uso propio" ///
21 "Actividades de organizaciones y órganos extraterritoriales", replace

label values rama1 rama


save "$out/empleo`anio'.dta", replace

}

use "$raw/empleo2024.dta", clear
save "$out/empleo2024.dta", replace

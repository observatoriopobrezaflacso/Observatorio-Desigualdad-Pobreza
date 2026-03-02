* Definir rutas
local carpeta_env "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV"
local base_nacimientos "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta"

clear
set obs 0
gen anio = .
gen NV = .
save "`base_nacimientos'", emptyok replace

forvalues y = 1990/2024 {
    di "Procesando Nacidos Vivos año `y'..."
    
    * Importar el archivo SAV (ajustado al nombre que mencionas)
    capture import spss using "`carpeta_env'\ENV_`y'.sav", clear
    
    * Si el nombre tiene un espacio como pusiste en el ejemplo "ENV_ 2021"
    if _rc capture import spss using "`carpeta_env'\ENV_ `y'.sav", clear

    if _rc {
        di "Error: No se pudo encontrar el archivo del año `y'"
        continue
    }

    * En las ENV, cada fila es un nacido vivo, así que solo contamos observaciones
    gen NV = 1
    collapse (sum) NV
    gen anio = `y'

    append using "`base_nacimientos'"
	gsort anio
    save "`base_nacimientos'", replace
}

* Preparar Nacimientos
use "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta", clear
destring anio, replace // Por si acaso sea string
recast int anio
save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta", replace

* Preparar Defunciones
use "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta", clear
destring anio, replace
recast int anio
save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta", replace

clear
use "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta"

* El comando clave:
merge 1:1 anio using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta"

* REVISA ESTO EN LA PANTALLA:
* Debería decir: "Matched: 35"
tab _merge
* Configurar directorio
cd "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"

* Importar el archivo del 2022
import spss using "EDG_2022.sav", clear

* Estandarizar nombres (Lógica original)
capture confirm variable COD_EDA
if !_rc rename COD_EDA cod_edad
capture confirm variable EDAD
if !_rc rename EDAD edad
destring cod_edad, replace force

* Crear indicador de muerte infantil (< 1 año)
gen menor1 = inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)

* --- Estandarización Geográfica (Residencia Habitual) ---
* En 2022 las variables suelen ser prov_res, cant_res, parr_res
gen id_parroquia = string(prov_res, "%02.0f") + string(cant_res, "%02.0f") + string(parr_res, "%02.0f")
drop if id_parroquia == ""

* Colapsar por Parroquia
collapse (sum) MI=menor1, by(id_parroquia)
save "mi_parroquial_2022.dta", replace
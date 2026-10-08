/*******************************************************************************
* construir_ingreso_dina_falso.do
*
* Construye ingreso_dina_YYYY.dta con los datos falsos usando el mismo código
* que en el servidor (Papers/Desigualdad ingreso):
*   1. limpiar_F102.do               -> F102_clean_YYYY_2.dta
*   2. construccion_ingreso_DINA.do  -> ingreso_dina_YYYY.dta
* Ambos toman la raíz de datos de $dir_sri si ya está definida; aquí se apunta
* a la copia falsa con la estructura del servidor (Falso/SRI), que arma
* inyectar_bunching_falso.do.
*
* Salida: Falso/SRI/03 BDD/SRI/IR/Merged/ingreso_dina/ingreso_dina_YYYY.dta
*******************************************************************************/

global dina_code "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Papers/Desigualdad ingreso"
global dir_sri   "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/SRI/Falso/SRI"

capture mkdir "$dir_sri/03 BDD/SRI/IR/Merged"

do "$dina_code/limpiar_F102.do"
do "$dina_code/construccion_ingreso_DINA.do"

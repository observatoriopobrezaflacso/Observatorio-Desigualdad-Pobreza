/*******************************************************************************
* inyectar_bunching_falso.do
*
* Inyecta bunching artificial en la base imponible de los F102 falsos, para
* verificar que bunching_renta.do lo detecta. Los datos falsos originales NO
* se modifican: se escribe una copia con solo CEDULA_PK y base_imponible_3480
* en Datos_falsos/F102_bunching/.
*
* Mecanismo (Saez 2010, con todos los tramos de la tabla): la base original
* z0 se toma como el ingreso sin impuesto. Con utilidad isoelástica, en el
* tramo con tasa t el ingreso óptimo es z0 * (1 - t)^e. Con una tabla convexa
* el óptimo se obtiene recorriendo los umbrales de abajo hacia arriba:
*      z = z0
*      para cada umbral Z_j:  si z > Z_j  ->  z = max(Z_j, z0 * (1 - t_{j+1})^e)
* Quien queda exactamente en Z_j está "bunched" (se le suma ruido N(0, $noise_sd)).
* Todos los que están por encima del umbral bajan su ingreso, no solo los
* cercanos: no se abre un hueco a la derecha del umbral (el mecanismo anterior
* sí lo abría y sesgaba el estimador).
*
* Una fracción 1 - $share_adjust no ajusta (fricciones) y conserva z0. La
* elasticidad que debería recuperar bunching_renta.do es aproximadamente
* $share_adjust * $elast_true.
*
* Solo se toca F102: los asalariados (F107) y el ingreso bruto PreTaxHHI
* (placebo) quedan intactos.
*
* Correr después de arreglar_ids_falsos.do y antes de bunching_renta.do.
*******************************************************************************/

clear all
set more off
set seed 20260929

global code_dir  "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Papers/Bunching"
global bunch_dir "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching"
global dir_f102  "$bunch_dir/Datos_falsos/F102"
global dir_out   "$bunch_dir/Datos_falsos/F102_bunching"
capture mkdir "$dir_out"

global elast_true   0.5      // elasticidad "verdadera"
global share_adjust 1        // fracción que ajusta (el resto conserva z0)
global noise_sd     10       // dispersión alrededor del umbral (USD)
global years        "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

include "$code_dir/tablas_impuesto_renta.do"

foreach yr of global years {

    use CEDULA_PK base_imponible_3480 using "$dir_f102/F102_`yr'.dta", clear
    capture destring base_imponible_3480, replace force
    replace base_imponible_3480 = 0 if missing(base_imponible_3480)

    gen double z0 = base_imponible_3480
    gen double z  = z0
    gen byte bunched = 0
    local nk : word count `thr_`yr''

    forvalues j = 1/`nk' {
        local Z  : word `j' of `thr_`yr''
        local jn = `j' + 1
        local t1 : word `jn' of `rate_`yr''
        replace bunched = 0 if z > `Z'
        replace z = max(`Z', z0 * (1 - `t1')^$elast_true) if z > `Z'
        replace bunched = `j' if z == `Z'
    }

    gen byte ajusta = runiform() < $share_adjust
    replace base_imponible_3480 = z if ajusta & z0 > 0
    replace base_imponible_3480 = z + rnormal(0, $noise_sd) if ajusta & bunched > 0

    quietly count if ajusta & bunched > 0
    di as text "`yr': `nk' umbrales; declarantes en un umbral: " r(N)
    keep CEDULA_PK base_imponible_3480
    save "$dir_out/F102_`yr'.dta", replace
}

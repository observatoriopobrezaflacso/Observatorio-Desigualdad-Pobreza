/*******************************************************************************
* inyectar_bunching_falso.do
*
* Prepara los formularios falsos con la misma estructura que en el servidor
* del SRI e inyecta bunching artificial en la base imponible del F102, para
* verificar que bunching_renta.do lo detecta.
*
* Entrada: Datos_falsos/F102/F102_YYYY.dta y F107/F107_YYYY.dta (generados por
*          generar_datos_falsos.R, con IDs arreglados por arreglar_ids_falsos.do;
*          no se modifican).
* Salida : $fake_sri/03 BDD/SRI/IR/F102/F102_anonimizada_YYYY.dta
*          $fake_sri/03 BDD/SRI/IR/F107/F107_anonimizada_YYYY.dta
*          (las rutas y nombres que esperan limpiar_F102.do y
*          construccion_ingreso_DINA.do con dir_sri = $fake_sri)
*
* F102: como en el F102 anonimizado real, una fila por CEDULA_PK (el generador
* crea algunos IDs repetidos; se conserva la primera fila) y las variables
* continuas guardadas como texto.
*
* Mecanismo del bunching (Saez 2010, con todos los tramos de la tabla): la base
* original z0 se toma como el ingreso sin impuesto. Con utilidad isoelástica,
* en el tramo con tasa t el ingreso óptimo es z0 * (1 - t)^e. Con una tabla
* convexa el óptimo se obtiene recorriendo los umbrales de abajo hacia arriba:
*      z = z0
*      para cada umbral Z_j:  si z > Z_j  ->  z = max(Z_j, z0 * (1 - t_{j+1})^e)
* Quien queda exactamente en Z_j está "bunched" (se le suma ruido N(0, $noise_sd)).
* Todos los que están por encima del umbral bajan su ingreso, no solo los
* cercanos: no se abre un hueco a la derecha del umbral.
*
* Una fracción 1 - $share_adjust no ajusta (fricciones) y conserva z0. La
* elasticidad que debería recuperar bunching_renta.do es aproximadamente
* $share_adjust * $elast_true.
*
* Solo se toca la base del F102: los asalariados (F107) y el ingreso bruto
* PreTaxHHI (placebo) quedan intactos.
*
* Orden: generar_datos_falsos.R -> arreglar_ids_falsos.do -> este archivo ->
*        construir_ingreso_dina_falso.do -> bunching_renta.do (real_data = 0)
*******************************************************************************/

clear all
set more off
set seed 20260929

global code_dir  "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Papers/Bunching/code"
global bunch_dir "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/SRI/Falso"
global dir_gen   "$bunch_dir/Datos_falsos"          // formularios generados
global fake_sri  "$bunch_dir/SRI"                   // equivale a dir_sri del servidor
global fake_ir   "$fake_sri/03 BDD/SRI/IR"

foreach d in "$fake_sri" "$fake_sri/03 BDD" "$fake_sri/03 BDD/SRI" "$fake_ir" ///
             "$fake_ir/F102" "$fake_ir/F107" {
    capture mkdir "`d'"
}

global elast_true   0.5      // elasticidad "verdadera"
global share_adjust 1        // fracción que ajusta (el resto conserva z0)
global noise_sd     10       // dispersión alrededor del umbral (USD)
global years        "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"

include "$code_dir/tablas_impuesto_renta.do"

foreach yr of global years {

    * --- F107: misma base, con el nombre del servidor ---
    use "$dir_gen/F107/F107_`yr'.dta", clear
    save "$fake_ir/F107/F107_anonimizada_`yr'.dta", replace

    * --- F102: una fila por CEDULA_PK ---
    use "$dir_gen/F102/F102_`yr'.dta", clear
    bysort CEDULA_PK: keep if _n == 1 | CEDULA_PK == ""

    * --- Bunching en la base imponible ---
    capture destring base_imponible_3480, replace force
    replace base_imponible_3480 = 0 if missing(base_imponible_3480)

    gen double z0 = base_imponible_3480
    gen double z  = z0
    gen byte bunched = 0
    local nk : word count ${thr_`yr'}

    forvalues j = 1/`nk' {
        local Z  : word `j' of ${thr_`yr'}
        local jn = `j' + 1
        local t1 : word `jn' of ${rate_`yr'}
        replace bunched = 0 if z > `Z'
        replace z = max(`Z', z0 * (1 - `t1')^$elast_true) if z > `Z'
        replace bunched = `j' if z == `Z'
    }

    gen byte ajusta = runiform() < $share_adjust
    replace base_imponible_3480 = z if ajusta & z0 > 0
    replace base_imponible_3480 = z + rnormal(0, $noise_sd) if ajusta & bunched > 0

    quietly count if ajusta & bunched > 0
    di as text "`yr': `nk' umbrales; declarantes en un umbral: " r(N)
    drop z0 z bunched ajusta

    * --- Variables continuas como texto, como en el F102 original ---
    foreach v of varlist _all {
        capture confirm numeric variable `v'
        if !_rc tostring `v', replace force format(%20.2f)
    }

    save "$fake_ir/F102/F102_anonimizada_`yr'.dta", replace
}

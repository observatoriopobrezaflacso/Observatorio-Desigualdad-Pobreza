*------------------------------------------------------------------*
* DISEÑO MUESTRAL ENEMDU 1991-2025
* Construye estrato y UPM (unidad primaria de muestreo) armonizados
* para poder estimar errores estándar e intervalos de confianza.
*------------------------------------------------------------------*
* Resultado: $bases_armonizadas/historico_diseno_muestral.dta
*   id_persona anio
*   estrato_svy  (numérico, único por año)   <- strata() de svyset
*   upm_svy      (numérico, único por año)   <- psu de svyset
*   estrato_str upm_str                      <- códigos originales
*   diseno_fuente                            <- de dónde sale cada uno
*
* Fuentes por período (verificado sobre los archivos empleo`y'.dta):
*   UPM:
*     1991-2017  ciudad + zona + sector  (sector censal = UPM)
*     2018-2025  upm                     (identificador INEC)
*   Estrato:
*     1991-2014  provincia x area        (no hay variable de estrato;
*                                         0-1 estratos con una sola UPM)
*     2015-2017  plan_muestreo           (140-142 estratos INEC)
*     2018-2025  estrato                 (150-160 estratos INEC)
*
* Nota: 1991-1992 traen una variable 'estrato' (0-3) que NO es el
*       estrato de muestreo (son 4 categorías para todo el país), por
*       eso no se usa.
* Nota: 'conglomerado' (2017+) tiene solo 31 valores distintos, no es
*       identificador de UPM.
*------------------------------------------------------------------*

clear all
set more off

global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global raw "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global bases_armonizadas "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"

* Rango de años (se puede reducir para pruebas)
global d_anio_ini 1991
global d_anio_fin 2025

tempfile acumulado
qui save `acumulado', emptyok replace

forval y = $d_anio_ini/$d_anio_fin {

    di as txt "************** `y' ********************"

    * --- qué variables de diseño existen en este año ---
    qui describe using "$raw/empleo`y'.dta", varlist
    local vlist `r(varlist)'
    local hay_area : list posof "area" in vlist

    local dv
    if `y' <= 2017              local dv ciudad zona sector
    if inrange(`y', 2015, 2017) local dv `dv' plan_muestreo
    if `y' >= 2018              local dv estrato upm
    if `hay_area'               local dv `dv' area

    use id_persona anio provincia `dv' using "$raw/empleo`y'.dta", clear

    * --- area: antes de 2000 la ENEMDU es solo urbana ---
    if !`hay_area' gen byte area = 1
    qui replace area = 1 if missing(area)

    * --- UPM ---
    if `y' <= 2017 {
        gen str psu_str = trim(ciudad) + "-" + trim(zona) + "-" + trim(sector)
        local f_psu "ciudad+zona+sector"
    }
    else {
        gen str psu_str = trim(upm)
        local f_psu "upm"
    }

    * --- Estrato ---
    if `y' >= 2018 {
        gen str est_str = trim(estrato)
        local f_est "estrato"
    }
    else if inrange(`y', 2015, 2017) {
        gen str est_str = trim(plan_muestreo)
        local f_est "plan_muestreo"
    }
    else {
        gen str est_str = trim(provincia) + "-" + string(area, "%1.0f")
        local f_est "provincia x area"
    }

    gen str32 diseno_fuente = "`f_est' / `f_psu'"

    * --- control de calidad del año ---
    qui count if est_str == "" | psu_str == "" | psu_str == "--"
    local nmiss = r(N)

    qui egen __tp = tag(est_str psu_str)
    qui bysort est_str: egen __k = total(__tp)
    qui egen __te = tag(est_str)
    qui count if __te
    local nest = r(N)
    qui count if __te & __k == 1
    local nsing = r(N)
    qui egen __tu = tag(psu_str)
    qui count if __tu
    local nupm = r(N)
    drop __*

    di as txt "   diseño: `f_est' / `f_psu'"
    di as txt "   estratos = `nest' (con una sola UPM: `nsing') ; UPM = `nupm' ; sin diseño = `nmiss'"
    if `nmiss' > 0 di as error "   ATENCION: `nmiss' observaciones sin variables de diseño en `y'"

    keep id_persona anio est_str psu_str diseno_fuente
    append using `acumulado'
    qui save `acumulado', replace
}

use `acumulado', clear

* --- Identificadores numéricos (svyset no acepta strings) ---
* El grupo incluye 'anio' para que estratos y UPM nunca se mezclen
* entre años: cada año se svysetea por separado.
egen long estrato_svy = group(anio est_str)
egen long upm_svy     = group(anio psu_str)

rename est_str estrato_str
rename psu_str upm_str

label var estrato_svy   "Estrato de muestreo (numérico, único por año)"
label var upm_svy       "UPM (numérico, único por año)"
label var estrato_str   "Código original del estrato"
label var upm_str       "Código original de la UPM"
label var diseno_fuente "Origen de estrato/UPM"

order id_persona anio estrato_svy upm_svy estrato_str upm_str diseno_fuente
compress

cap isid id_persona anio
if _rc di as error "ATENCION: id_persona-anio no identifica unívocamente las observaciones"

save "$bases_armonizadas/historico_diseno_muestral.dta", replace

* --- Resumen final ---
preserve
    egen te = tag(anio estrato_svy)
    egen tu = tag(anio upm_svy)
    gen byte uno = 1
    collapse (sum) n_estratos = te n_upm = tu n_obs = uno, by(anio diseno_fuente)
    list anio diseno_fuente n_estratos n_upm n_obs, noobs sepby(diseno_fuente)
restore

*==============================================================================
* EXPANSIÓN RECURSIVA DE ACCIONISTAS HASTA PERSONAS NATURALES (REBEFICS / APS)
*
* Para cada sociedad informante reemplaza a sus accionistas que son sociedades por
* los accionistas de esas sociedades (multiplicando porcentajes), hasta que solo
* queden personas naturales o nodos que no se pueden resolver.
*
*  - Sociedades nacionales accionistas (siempre nivel_aps = 1): se buscan como
*    informantes en la misma base y se expanden recursivamente.
*  - Sociedades extranjeras accionistas: no presentan anexo; su cadena viene
*    declarada en el anexo del propio informante (nivel_aps 2, 3, ...). Se usan las
*    personas naturales (y sociedades nacionales) de esas filas con su
*    porcentaje_efectivo_r (% sobre el informante). La parte del % extranjero que
*    la cadena no cubre queda como EXT_SIN_CADENA.
*  - Lo que el informante no declara (total de nivel 1 < 100%) queda como
*    NO_DECLARADO.
*  - Ciclos de propiedad cruzada: la cadena se corta y ese % queda como CICLO.
*
* Validación: el resultado se compara con la solución matricial exacta
*   P = (I - A)^-1 B = B + A B + A^2 B + ...
* calculada con joins sucesivos (no necesita rutas).
*
* Uso:  do expandir_accionistas_PN.do ["entrada.dta"] ["carpeta_salida"] [sufijo]
*==============================================================================
version 17
clear all
set more off
set varabbrev off
set type double

args entrada salida sufijo
if `"`entrada'"' == "" local entrada "BDD_PN_accionistas_falsa.dta"
if `"`salida'"'  == "" local salida  "."
if `"`sufijo'"'  == "" local sufijo  "_falsa"
local umbral 1e-10     // peso mínimo (fracción) para seguir expandiendo una cadena
local max_it 100       // tope de saltos entre sociedades
local max_leon 200     // tope de términos de la serie A^k B
local tol 1e-6         // tolerancia para residuos (fracción)

timer clear 1
timer on 1
tempfile base vig inf prop cuadre h r1 r2 res final A T P extsin noenc

*------------------------------------------------------------------------------
* 0. Cargar variables necesarias
*------------------------------------------------------------------------------
use codigo_registro_anexo numero_ruc registro_actual periodo_procesado      ///
    tipo_id_accionista id_accionista tipo_accionista tipo_relacion_accionista ///
    nivel_aps porcentaje_participacion_r porcentaje_efectivo_r              ///
    using `"`entrada'"', clear
foreach v in codigo_registro_anexo numero_ruc registro_actual periodo_procesado ///
             tipo_id_accionista id_accionista tipo_accionista                   ///
             tipo_relacion_accionista nivel_aps {
    quietly replace `v' = strtrim(`v')
}
local n_orig = _N
save `base'

*------------------------------------------------------------------------------
* 1. Un solo registro por informante: el vigente (registro_actual = S); si no
*    hay, el de periodo procesado más reciente.
*------------------------------------------------------------------------------
keep numero_ruc codigo_registro_anexo registro_actual periodo_procesado
duplicates drop
local n_reg = _N
gen byte es_s = registro_actual == "S"
gen double cod = real(codigo_registro_anexo)
gsort numero_ruc -es_s -periodo_procesado -cod
by numero_ruc: keep if _n == 1
local n_vig = _N
keep numero_ruc codigo_registro_anexo
save `vig'
keep numero_ruc
save `inf'

use `base', clear
merge m:1 numero_ruc codigo_registro_anexo using `vig', keep(match) nogen

*------------------------------------------------------------------------------
* 2. Relaciones de propiedad
*------------------------------------------------------------------------------
keep if inlist(tipo_relacion_accionista, "TITULARES DE DERECHO", "SOCIO FUNDADOR")
local n_rel = _N
gen int nivel = real(nivel_aps)
gen clase = cond(tipo_accionista == "PERSONAS NATURALES",  "PN",      ///
            cond(tipo_accionista == "SOCIEDADES",          "SOC_NAC", ///
            cond(tipo_accionista == "SOCIEDAD EXTRANJERA", "SOC_EXT", "OTRO")))
* persona natural con RUC (cédula + 001) -> misma persona que su cédula
gen byte ruc_pn = clase == "PN" & tipo_id_accionista == "R" & ///
                  strlen(id_accionista) == 13 & substr(id_accionista, -3, 3) == "001"
replace id_accionista      = substr(id_accionista, 1, 10) if ruc_pn
replace tipo_id_accionista = "C"                          if ruc_pn
drop ruc_pn
save `prop'

* cuadre por informante
gen double p1    = porcentaje_participacion_r / 100 if nivel == 1
gen double pext1 = porcentaje_participacion_r / 100 if nivel == 1 & clase == "SOC_EXT"
gen byte   iext1 = nivel == 1 & clase == "SOC_EXT"
gen double pcad  = porcentaje_efectivo_r / 100 if nivel > 1 & inlist(clase, "PN", "SOC_NAC")
gen byte   icad  = nivel > 1
collapse (sum) tot1=p1 ext1=pext1 n_ext1=iext1 cad=pcad n_cadena=icad, by(numero_ruc)
merge 1:1 numero_ruc using `inf', nogen
foreach v in tot1 ext1 n_ext1 cad n_cadena {
    quietly replace `v' = 0 if missing(`v')
}
gen double residuo_ext = max(0, ext1 - cad)
gen double no_decl     = max(0, 1 - tot1)
* tolerancia: los % vienen redondeados a 0.01 pp; residuos menores a 1e-6 son ruido numérico
replace residuo_ext = 0 if residuo_ext < `tol'
replace no_decl     = 0 if no_decl     < `tol'
save `cuadre'

*------------------------------------------------------------------------------
* 3. Tenencias directas h(informante -> dueño, peso)
*------------------------------------------------------------------------------
use `prop', clear
keep if inlist(clase, "PN", "SOC_NAC")
* nivel 1: % de participación; niveles 2+ (cadena extranjera): % efectivo
gen double peso   = cond(nivel == 1, porcentaje_participacion_r, porcentaje_efectivo_r) / 100
gen byte  directo = nivel == 1
rename (numero_ruc id_accionista tipo_id_accionista) (inf holder tipo_id)
keep inf holder tipo_id clase peso directo
save `h'

foreach x in ext nodecl {
    use `cuadre', clear
    if "`x'" == "ext" {
        keep if residuo_ext > 0
        gen double peso = residuo_ext
        gen clase = "EXT_SIN_CADENA"
    }
    else {
        keep if no_decl > 0
        gen double peso = no_decl
        gen clase = "NO_DECLARADO"
    }
    gen holder  = clase
    gen tipo_id = ""
    gen byte directo = 1
    rename numero_ruc inf
    keep inf holder tipo_id clase peso directo
    if "`x'" == "ext" save `r1'
    else              save `r2'
}
use `h', clear
append using `r1' `r2'
collapse (sum) peso, by(inf holder tipo_id clase directo)
drop if peso <= 0
* sociedades nacionales que no están como informantes
gen numero_ruc = holder
merge m:1 numero_ruc using `inf', keep(master match) gen(_m)
replace clase = "SOC_NAC_NO_ENCONTRADA" if clase == "SOC_NAC" & _m == 1
drop numero_ruc _m
save `h', replace

*------------------------------------------------------------------------------
* 4. Expansión recursiva (joins iterativos con control de ciclos)
*------------------------------------------------------------------------------
gen raiz = inf
gen int salto = 1
gen ruta = "|" + inf + "|"
keep raiz holder tipo_id clase peso directo salto ruta
local it = 0
while 1 {
    local ++it
    quietly replace clase = "CICLO" if clase == "SOC_NAC" & strpos(ruta, "|" + holder + "|") > 0
    quietly replace clase = "TRUNCADO" if clase == "SOC_NAC" & peso < `umbral'
    if `it' == `max_it' quietly replace clase = "TRUNCADO" if clase == "SOC_NAC"
    preserve
    quietly keep if clase != "SOC_NAC"
    if `it' > 1 append using `res'
    quietly save `res', replace
    restore
    quietly keep if clase == "SOC_NAC"
    if _N == 0 continue, break
    keep raiz holder peso salto ruta
    rename (holder peso) (inf peso_p)
    quietly joinby inf using `h'
    quietly replace peso    = peso_p * peso
    quietly replace directo = 0
    quietly replace salto   = salto + 1
    quietly replace ruta    = ruta + inf + "|"
    drop inf peso_p
    display as text "  salto " %2.0f `it' + 1 ": " %9.0fc _N " cadenas por expandir"
}
local saltos_max = `it'

use `res', clear
gen double peso_dir = peso * (directo == 1 & salto == 1)
gen long uno = 1
collapse (sum) pct_total=peso pct_directo=peso_dir n_caminos=uno ///
         (min) saltos_min=salto (max) saltos_max=salto, by(raiz holder tipo_id clase)
replace pct_total   = 100 * pct_total
replace pct_directo = 100 * pct_directo
gen double pct_indirecto = pct_total - pct_directo
rename (raiz holder) (numero_ruc id_final)
order numero_ruc clase id_final tipo_id pct_total pct_directo pct_indirecto ///
      n_caminos saltos_min saltos_max
gsort numero_ruc clase -pct_total
label variable numero_ruc    "RUC de la sociedad informante"
label variable clase         "PN / SOC_NAC_NO_ENCONTRADA / EXT_SIN_CADENA / NO_DECLARADO / CICLO / TRUNCADO"
label variable id_final      "Identificación del dueño final (cédula/pasaporte) o del nodo no resuelto"
label variable tipo_id       "Tipo de identificación del dueño final"
label variable pct_total     "% final sobre la sociedad (directo + indirecto)"
label variable pct_directo   "% como accionista directo (nivel 1)"
label variable pct_indirecto "% a través de otras sociedades"
label variable n_caminos     "Número de cadenas de propiedad que llegan a este dueño"
label variable saltos_min    "Mínimo de sociedades recorridas (1 = directo)"
label variable saltos_max    "Máximo de sociedades recorridas"
compress
save `final'
save `"`salida'/BDD_PN_accionistas_finales`sufijo'.dta"', replace

* indicadores para el reporte
quietly count
local n_final = _N
quietly count if clase == "PN"
local n_final_pn = r(N)
preserve
quietly keep if clase == "PN"
quietly duplicates drop id_final, force
local n_pn_unicas = _N
restore
preserve
quietly keep if inlist(clase, "CICLO", "TRUNCADO")
quietly duplicates drop numero_ruc, force
local n_ciclo = _N
restore
* composición final (promedio simple entre informantes, incluye ceros)
preserve
egen byte tag = tag(numero_ruc clase)
collapse (sum) pct=pct_total n_soc=tag, by(clase)
replace pct = pct / `n_vig'
gsort -pct
local n_comp = _N
forvalues i = 1/`n_comp' {
    local comp_cl`i'  : display %-24s clase[`i']
    local comp_pct`i' : display %9.2f pct[`i']
    local comp_n`i'   : display %10.0fc n_soc[`i']
}
restore

*------------------------------------------------------------------------------
* 5. Validación: serie P = sum_k A^k B con joins (equivale a (I - A)^-1 B)
*------------------------------------------------------------------------------
use `h', clear
keep if clase == "SOC_NAC"
keep inf holder peso
rename (holder peso) (soc w)
save `A'
use `h', clear
keep if clase != "SOC_NAC"
gen nodo = clase + ":" + holder
collapse (sum) peso, by(inf nodo)
save `P'
save `T'
local k = 0
local converge "NO converge: hay ciclos con participaciones cruzadas >= 100%"
while `k' < `max_leon' {
    local ++k
    use `T', clear
    rename (inf peso) (soc pt)
    quietly joinby soc using `A'
    if _N == 0 {
        local converge "converge"
        continue, break
    }
    quietly gen double peso = w * pt
    quietly collapse (sum) peso, by(inf nodo)
    quietly drop if abs(peso) < 1e-14
    if _N == 0 {
        local converge "converge"
        continue, break
    }
    quietly save `T', replace
    tempfile t`k'
    quietly save `t`k''
    local terminos `terminos' `t`k''
}
local n_terminos = `k'
use `P', clear
if "`terminos'" != "" append using `terminos'
collapse (sum) peso, by(inf nodo)
gen double pct_leon = 100 * peso
rename inf numero_ruc
keep numero_ruc nodo pct_leon
save `P', replace

use `final', clear
gen byte cic = inlist(clase, "CICLO", "TRUNCADO")
bysort numero_ruc: egen byte con_ciclo = max(cic)
gen nodo = clase + ":" + id_final
collapse (sum) pct_total (max) con_ciclo, by(numero_ruc nodo)
merge 1:1 numero_ruc nodo using `P'
bysort numero_ruc: egen byte cc = max(con_ciclo)
replace pct_total = 0 if missing(pct_total)
replace pct_leon  = 0 if missing(pct_leon)
gen double dif = abs(pct_total - pct_leon)
quietly summarize dif if cc != 1
local dif_max : display %9.2e r(max)
* empresas con ciclos: % en personas naturales según cada método
quietly keep if cc == 1 & substr(nodo, 1, 3) == "PN:"
if _N > 0 {
    collapse (sum) pct_total pct_leon, by(numero_ruc)
    quietly summarize pct_total
    local cic_exp : display %6.2f r(mean)
    quietly summarize pct_leon
    local cic_leo : display %6.2f r(mean)
}
else {
    local cic_exp "n.d."
    local cic_leo "n.d."
}

*------------------------------------------------------------------------------
* 6. Sociedades accionistas que no están como informantes en el REBEFICS
*------------------------------------------------------------------------------
* extranjeras de nivel 1 en informantes sin ninguna cadena declarada
use `prop', clear
keep if nivel == 1 & clase == "SOC_EXT"
merge m:1 numero_ruc using `cuadre', keepusing(n_cadena) keep(match) nogen
keep if n_cadena == 0
keep id_accionista clase
duplicates drop
save `extsin'

use `prop', clear
keep if inlist(clase, "SOC_NAC", "SOC_EXT")
gen double pct = cond(nivel == 1, porcentaje_participacion_r, porcentaje_efectivo_r)
egen byte tag_inf = tag(id_accionista clase numero_ruc)
gen long uno = 1
collapse (sum) n_relaciones=uno n_informantes=tag_inf (mean) pct_promedio=pct, ///
         by(id_accionista clase)
gen numero_ruc = id_accionista
merge m:1 numero_ruc using `inf', keep(master match)
gen byte en_rebefics = _merge == 3
drop _merge numero_ruc
merge 1:1 id_accionista clase using `extsin', keep(master match)
gen byte extranjera_sin_cadena = _merge == 3
drop _merge

quietly count if clase == "SOC_NAC"
local nac_tot = r(N)
quietly count if clase == "SOC_NAC" & !en_rebefics
local nac_no = r(N)
quietly summarize n_relaciones if clase == "SOC_NAC"
local nac_rel_tot = r(sum)
quietly summarize n_relaciones if clase == "SOC_NAC" & !en_rebefics
local nac_rel_no = r(sum)
quietly count if clase == "SOC_EXT"
local ext_tot = r(N)
quietly count if clase == "SOC_EXT" & !en_rebefics
local ext_no = r(N)
quietly count if extranjera_sin_cadena
local ext_sin = r(N)
quietly count if !en_rebefics
local tot_no = r(N)

label variable id_accionista         "Identificación de la sociedad accionista"
label variable clase                 "SOC_NAC = nacional, SOC_EXT = extranjera"
label variable n_relaciones          "Filas en que aparece como accionista (registros vigentes)"
label variable n_informantes         "Informantes de los que es accionista"
label variable pct_promedio          "% promedio (participación nivel 1 / efectivo niveles 2+)"
label variable en_rebefics           "1 = aparece como informante en el REBEFICS"
label variable extranjera_sin_cadena "1 = extranjera sin cadena declarada en algún informante"
keep if !en_rebefics
gsort clase -n_relaciones
compress
save `"`salida'/sociedades_accionistas_no_encontradas`sufijo'.dta"', replace

* otros indicadores
use `h', clear
quietly keep if clase == "SOC_NAC_NO_ENCONTRADA" & directo == 1
quietly duplicates drop inf, force
local inf_nac_no = _N
use `cuadre', clear
quietly count if residuo_ext > 0.0005
local inf_res_ext = r(N)
quietly count if cad - ext1 > 0.0005
local inf_cad_mayor = r(N)
quietly count if tot1 > 1 + `tol'
local inf_sobre100 = r(N)

timer off 1
quietly timer list 1
local tiempo : display %9.1f r(t1)

*------------------------------------------------------------------------------
* 7. Reporte
*------------------------------------------------------------------------------
foreach x in n_orig n_vig n_rel nac_tot nac_no nac_rel_tot nac_rel_no ext_tot ext_no ///
             ext_sin tot_no inf_nac_no inf_res_ext inf_cad_mayor inf_sobre100       ///
             n_final n_final_pn n_pn_unicas n_ciclo {
    local f_`x' : display %12.0fc ``x''
    local f_`x' = strtrim("`f_`x''")
}
local f_desc : display %12.0fc `n_reg' - `n_vig'
local f_desc = strtrim("`f_desc'")
local pnac : display %6.2f 100 * `nac_no' / `nac_tot'
local pext : display %6.2f 100 * `ext_no' / max(1, `ext_tot')
foreach x in pnac pext dif_max cic_exp cic_leo tiempo {
    local `x' = strtrim("``x''")
}
local linea = 70 * "="
local guion = 70 * "-"

tempname fh
file open `fh' using `"`salida'/reporte_expansion_accionistas`sufijo'.txt"', write replace
file write `fh' "REPORTE - EXPANSIÓN RECURSIVA DE ACCIONISTAS (Stata)" _n "`linea'" _n
file write `fh' `"Base de entrada: `entrada'"' _n
file write `fh' "Filas originales: `f_n_orig' | registros no vigentes descartados: `f_desc'" _n
file write `fh' "Sociedades informantes (registro vigente): `f_n_vig'" _n
file write `fh' "Relaciones de propiedad usadas (titulares / socios fundadores): `f_n_rel'" _n _n
file write `fh' "SOCIEDADES ACCIONISTAS QUE NO ESTÁN EN EL REBEFICS COMO INFORMANTES" _n "`guion'" _n
file write `fh' "Nacionales: `f_nac_no' de `f_nac_tot' sociedades únicas (`pnac'%) | `f_nac_rel_no' de `f_nac_rel_tot' relaciones" _n
file write `fh' "Extranjeras: `f_ext_no' de `f_ext_tot' sociedades únicas (`pext'%) - se resuelven con la cadena declarada" _n
file write `fh' "   de ellas, sin ninguna cadena declarada en el informante: `f_ext_sin'" _n
file write `fh' "TOTAL no encontradas como informantes: `f_tot_no' sociedades únicas" _n
file write `fh' "Informantes con al menos una sociedad nacional no encontrada (directa): `f_inf_nac_no'" _n
file write `fh' "Informantes con % extranjero sin cadena, total o parcial (> 0.05 pp): `f_inf_res_ext'" _n
file write `fh' "Informantes con cadena declarada mayor que su % extranjero (> 0.05 pp): `f_inf_cad_mayor'" _n _n
file write `fh' "COMPOSICIÓN FINAL (promedio simple entre informantes, % del capital)" _n "`guion'" _n
forvalues i = 1/`n_comp' {
    file write `fh' "  `comp_cl`i''`comp_pct`i''%  en `comp_n`i'' sociedades" _n
}
file write `fh' _n "EXPANSIÓN" _n "`guion'" _n
file write `fh' "Saltos entre sociedades: máximo `saltos_max'" _n
file write `fh' "Filas en la base final: `f_n_final' (personas naturales: `f_n_final_pn', únicas: `f_n_pn_unicas')" _n
file write `fh' "Informantes con % que vuelve a ellas mismas (ciclos): `f_n_ciclo'" _n
file write `fh' "Informantes con total declarado de nivel 1 > 100%: `f_inf_sobre100'" _n _n
file write `fh' "VALIDACIÓN CONTRA LA SOLUCIÓN MATRICIAL (I - A)^-1 B  (`n_terminos' términos, `converge')" _n "`guion'" _n
file write `fh' "Empresas sin ciclos: diferencia máxima = `dif_max' puntos porcentuales" _n
file write `fh' "Empresas con ciclos (`f_n_ciclo'): % en personas naturales, expansión = `cic_exp'% vs matricial = `cic_leo'% (promedios)" _n
file write `fh' "  (la matricial reparte el % del ciclo entre los dueños finales; la expansión lo deja en CICLO)" _n _n
file write `fh' "Tiempo: `tiempo' s" _n
file close `fh'
type `"`salida'/reporte_expansion_accionistas`sufijo'.txt"'

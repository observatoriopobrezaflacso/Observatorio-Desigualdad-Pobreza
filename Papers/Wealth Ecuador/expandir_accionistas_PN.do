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
* ORGANIZACIÓN: el bloque 0 define globals (rutas y parámetros). Cada bloque
* siguiente lee sus insumos de $temp y guarda ahí sus resultados, así que, una
* vez corrido el bloque 0, cualquier bloque se puede correr por separado si los
* bloques anteriores ya se corrieron alguna vez.
*
*   Bloque  Lee                         Guarda en $temp
*   1       $entrada                    base, vig, inf
*   2       base, vig, inf              prop, cuadre
*   3       prop, cuadre, inf           h  (y r1, r2)
*   4       h                           res, final  (+ base final en $salida)
*   5       h, final                    A, T, Tacum, P, validacion
*   6       prop, cuadre, inf           extsin, soc_acc  (+ no encontradas en $salida)
*   7       todas las anteriores        reporte en $salida
*   8       -                           borra $temp si $borrar_temp == 1
*
* Uso en batch: do expandir_accionistas_PN.do ["entrada.dta"] ["carpeta_salida"] [sufijo]
* (los argumentos, si se pasan, reemplazan a los globals del bloque 0)
*==============================================================================

*------------------------------------------------------------------------------
* 0. Configuración
*------------------------------------------------------------------------------
version 17
clear all
set more off
set varabbrev off
set type double     // toda variable numérica nueva se crea en doble precisión

global entrada     "BDD_PN_accionistas_falsa.dta"   // base REBEFICS de accionistas
global salida      "."                              // carpeta de resultados
global sufijo      "_falsa"                         // sufijo de los archivos de resultados
global borrar_temp 0        // 1 = eliminar $temp al finalizar; 0 = conservarla (default)
global umbral      1e-10    // peso mínimo (fracción) para seguir expandiendo una cadena
global max_it      100      // tope de saltos entre sociedades
global max_leon    200      // tope de términos de la serie A^k B
global tol         1e-6     // tolerancia para residuos (fracción)

args entrada salida sufijo
if `"`entrada'"' != "" global entrada `"`entrada'"'
if `"`salida'"'  != "" global salida  `"`salida'"'
if `"`sufijo'"'  != "" global sufijo  `"`sufijo'"'

global temp "$salida/bases_temp"
capture mkdir "$temp"

*------------------------------------------------------------------------------
* 1. Carga y registro vigente: un solo registro por informante, el vigente
*    (registro_actual = S); si no hay, el de periodo procesado más reciente.
*------------------------------------------------------------------------------
use codigo_registro_anexo numero_ruc registro_actual periodo_procesado      ///
    tipo_id_accionista id_accionista tipo_accionista tipo_relacion_accionista ///
    nivel_aps porcentaje_participacion_r porcentaje_efectivo_r              ///
    using "$entrada", clear
foreach v in codigo_registro_anexo numero_ruc registro_actual periodo_procesado ///
             tipo_id_accionista id_accionista tipo_accionista                   ///
             tipo_relacion_accionista nivel_aps {
    quietly replace `v' = strtrim(`v')
}
save "$temp/base.dta", replace

keep numero_ruc codigo_registro_anexo registro_actual periodo_procesado
duplicates drop
gen es_s = registro_actual == "S"
gen cod = real(codigo_registro_anexo)
gsort numero_ruc -es_s -periodo_procesado -cod
by numero_ruc: keep if _n == 1
keep numero_ruc codigo_registro_anexo
save "$temp/vig.dta", replace
keep numero_ruc
save "$temp/inf.dta", replace

*------------------------------------------------------------------------------
* 2. Relaciones de propiedad y cuadre por informante
*------------------------------------------------------------------------------
use "$temp/base.dta", clear
merge m:1 numero_ruc codigo_registro_anexo using "$temp/vig.dta", keep(match) nogen
keep if inlist(tipo_relacion_accionista, "TITULARES DE DERECHO", "SOCIO FUNDADOR")
gen nivel = real(nivel_aps)
gen clase = cond(tipo_accionista == "PERSONAS NATURALES",  "PN",      ///
            cond(tipo_accionista == "SOCIEDADES",          "SOC_NAC", ///
            cond(tipo_accionista == "SOCIEDAD EXTRANJERA", "SOC_EXT", "OTRO")))
* persona natural con RUC (cédula + 001) -> misma persona que su cédula
gen ruc_pn = clase == "PN" & tipo_id_accionista == "R" & ///
             strlen(id_accionista) == 13 & substr(id_accionista, -3, 3) == "001"
replace id_accionista      = substr(id_accionista, 1, 10) if ruc_pn
replace tipo_id_accionista = "C"                          if ruc_pn
drop ruc_pn
save "$temp/prop.dta", replace

gen p1    = porcentaje_participacion_r / 100 if nivel == 1
gen pext1 = porcentaje_participacion_r / 100 if nivel == 1 & clase == "SOC_EXT"
gen iext1 = nivel == 1 & clase == "SOC_EXT"
gen pcad  = porcentaje_efectivo_r / 100 if nivel > 1 & inlist(clase, "PN", "SOC_NAC")
gen icad  = nivel > 1
collapse (sum) tot1=p1 ext1=pext1 n_ext1=iext1 cad=pcad n_cadena=icad, by(numero_ruc)
merge 1:1 numero_ruc using "$temp/inf.dta", nogen
foreach v in tot1 ext1 n_ext1 cad n_cadena {
    quietly replace `v' = 0 if missing(`v')
}
gen residuo_ext = max(0, ext1 - cad)
gen no_decl     = max(0, 1 - tot1)
* tolerancia: los % vienen redondeados a 0.01 pp; residuos menores son ruido numérico
replace residuo_ext = 0 if residuo_ext < $tol
replace no_decl     = 0 if no_decl     < $tol
save "$temp/cuadre.dta", replace

*------------------------------------------------------------------------------
* 3. Tenencias directas h(informante -> dueño, peso)
*------------------------------------------------------------------------------
use "$temp/cuadre.dta", clear
keep if residuo_ext > 0
gen peso = residuo_ext
gen clase = "EXT_SIN_CADENA"
gen holder = clase
gen tipo_id = ""
gen directo = 1
rename numero_ruc inf
keep inf holder tipo_id clase peso directo
save "$temp/r1.dta", replace

use "$temp/cuadre.dta", clear
keep if no_decl > 0
gen peso = no_decl
gen clase = "NO_DECLARADO"
gen holder = clase
gen tipo_id = ""
gen directo = 1
rename numero_ruc inf
keep inf holder tipo_id clase peso directo
save "$temp/r2.dta", replace

use "$temp/prop.dta", clear
keep if inlist(clase, "PN", "SOC_NAC")
* nivel 1: % de participación; niveles 2+ (cadena extranjera): % efectivo
gen peso = cond(nivel == 1, porcentaje_participacion_r, porcentaje_efectivo_r) / 100
gen directo = nivel == 1
rename (numero_ruc id_accionista tipo_id_accionista) (inf holder tipo_id)
keep inf holder tipo_id clase peso directo
append using "$temp/r1.dta" "$temp/r2.dta"
collapse (sum) peso, by(inf holder tipo_id clase directo)
drop if peso <= 0
* sociedades nacionales que no están como informantes
gen numero_ruc = holder
merge m:1 numero_ruc using "$temp/inf.dta", keep(master match) gen(_m)
replace clase = "SOC_NAC_NO_ENCONTRADA" if clase == "SOC_NAC" & _m == 1
drop numero_ruc _m
save "$temp/h.dta", replace

*------------------------------------------------------------------------------
* 4. Expansión recursiva (joins iterativos con control de ciclos)
*------------------------------------------------------------------------------
use "$temp/h.dta", clear
gen raiz = inf
gen salto = 1
gen ruta = "|" + inf + "|"
keep raiz holder tipo_id clase peso directo salto ruta
local it = 0
while 1 {
    local ++it
    quietly replace clase = "CICLO" if clase == "SOC_NAC" & strpos(ruta, "|" + holder + "|") > 0
    quietly replace clase = "TRUNCADO" if clase == "SOC_NAC" & peso < $umbral
    if `it' == $max_it quietly replace clase = "TRUNCADO" if clase == "SOC_NAC"
    preserve
    quietly keep if clase != "SOC_NAC"
    if `it' > 1 append using "$temp/res.dta"
    quietly save "$temp/res.dta", replace
    restore
    quietly keep if clase == "SOC_NAC"
    if _N == 0 continue, break
    keep raiz holder peso salto ruta
    rename (holder peso) (inf peso_p)
    quietly joinby inf using "$temp/h.dta"
    quietly replace peso    = peso_p * peso
    quietly replace directo = 0
    quietly replace salto   = salto + 1
    quietly replace ruta    = ruta + inf + "|"
    drop inf peso_p
    display as text "  salto " %2.0f `it' + 1 ": " %9.0fc _N " cadenas por expandir"
}

use "$temp/res.dta", clear
gen peso_dir = peso * (directo == 1 & salto == 1)
gen uno = 1
collapse (sum) pct_total=peso pct_directo=peso_dir n_caminos=uno ///
         (min) saltos_min=salto (max) saltos_max=salto, by(raiz holder tipo_id clase)
replace pct_total   = 100 * pct_total
replace pct_directo = 100 * pct_directo
gen pct_indirecto = pct_total - pct_directo
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
save "$temp/final.dta", replace
save "$salida/BDD_PN_accionistas_finales$sufijo.dta", replace

*------------------------------------------------------------------------------
* 5. Validación: serie P = sum_k A^k B con joins (equivale a (I - A)^-1 B).
*    En empresas sin ciclos debe coincidir con la expansión.
*------------------------------------------------------------------------------
use "$temp/h.dta", clear
keep if clase == "SOC_NAC"
keep inf holder peso
rename (holder peso) (soc w)
save "$temp/A.dta", replace

use "$temp/h.dta", clear
keep if clase != "SOC_NAC"
gen nodo = clase + ":" + holder
collapse (sum) peso, by(inf nodo)
save "$temp/P.dta", replace
save "$temp/T.dta", replace
capture erase "$temp/Tacum.dta"
local k = 0
local converge "NO converge: hay ciclos con participaciones cruzadas >= 100%"
while `k' < $max_leon {
    local ++k
    use "$temp/T.dta", clear
    rename (inf peso) (soc pt)
    quietly joinby soc using "$temp/A.dta"
    if _N == 0 {
        local converge "converge"
        continue, break
    }
    quietly gen peso = w * pt
    quietly collapse (sum) peso, by(inf nodo)
    quietly drop if abs(peso) < 1e-14
    if _N == 0 {
        local converge "converge"
        continue, break
    }
    quietly save "$temp/T.dta", replace
    * acumular los términos A^k B (se suman una sola vez al final)
    capture confirm file "$temp/Tacum.dta"
    if !_rc quietly append using "$temp/Tacum.dta"
    quietly save "$temp/Tacum.dta", replace
}
local n_terminos = `k'
use "$temp/P.dta", clear
capture confirm file "$temp/Tacum.dta"
if !_rc append using "$temp/Tacum.dta"
collapse (sum) peso, by(inf nodo)
gen pct_leon = 100 * peso
rename inf numero_ruc
keep numero_ruc nodo pct_leon
save "$temp/P.dta", replace

use "$temp/final.dta", clear
gen cic = inlist(clase, "CICLO", "TRUNCADO")
bysort numero_ruc: egen con_ciclo = max(cic)
gen nodo = clase + ":" + id_final
collapse (sum) pct_total (max) con_ciclo, by(numero_ruc nodo)
merge 1:1 numero_ruc nodo using "$temp/P.dta"
bysort numero_ruc: egen cc = max(con_ciclo)
replace pct_total = 0 if missing(pct_total)
replace pct_leon  = 0 if missing(pct_leon)
gen dif = abs(pct_total - pct_leon)
quietly summarize dif if cc != 1
local dif_max = r(max)
* empresas con ciclos: % en personas naturales según cada método
local cic_exp = .
local cic_leo = .
quietly keep if cc == 1 & substr(nodo, 1, 3) == "PN:"
if _N > 0 {
    collapse (sum) pct_total pct_leon, by(numero_ruc)
    quietly summarize pct_total
    local cic_exp = r(mean)
    quietly summarize pct_leon
    local cic_leo = r(mean)
}
clear
set obs 1
gen n_terminos = `n_terminos'
gen converge = "`converge'"
gen dif_max = `dif_max'
gen cic_exp = `cic_exp'
gen cic_leo = `cic_leo'
save "$temp/validacion.dta", replace

*------------------------------------------------------------------------------
* 6. Sociedades accionistas que no están como informantes en el REBEFICS
*------------------------------------------------------------------------------
* extranjeras de nivel 1 en informantes sin ninguna cadena declarada
use "$temp/prop.dta", clear
keep if nivel == 1 & clase == "SOC_EXT"
merge m:1 numero_ruc using "$temp/cuadre.dta", keepusing(n_cadena) keep(match) nogen
keep if n_cadena == 0
keep id_accionista clase
duplicates drop
save "$temp/extsin.dta", replace

use "$temp/prop.dta", clear
keep if inlist(clase, "SOC_NAC", "SOC_EXT")
gen pct = cond(nivel == 1, porcentaje_participacion_r, porcentaje_efectivo_r)
egen tag_inf = tag(id_accionista clase numero_ruc)
gen uno = 1
collapse (sum) n_relaciones=uno n_informantes=tag_inf (mean) pct_promedio=pct, ///
         by(id_accionista clase)
gen numero_ruc = id_accionista
merge m:1 numero_ruc using "$temp/inf.dta", keep(master match)
gen en_rebefics = _merge == 3
drop _merge numero_ruc
merge 1:1 id_accionista clase using "$temp/extsin.dta", keep(master match)
gen extranjera_sin_cadena = _merge == 3
drop _merge
label variable id_accionista         "Identificación de la sociedad accionista"
label variable clase                 "SOC_NAC = nacional, SOC_EXT = extranjera"
label variable n_relaciones          "Filas en que aparece como accionista (registros vigentes)"
label variable n_informantes         "Informantes de los que es accionista"
label variable pct_promedio          "% promedio (participación nivel 1 / efectivo niveles 2+)"
label variable en_rebefics           "1 = aparece como informante en el REBEFICS"
label variable extranjera_sin_cadena "1 = extranjera sin cadena declarada en algún informante"
gsort clase -n_relaciones
compress
save "$temp/soc_acc.dta", replace
keep if !en_rebefics
save "$salida/sociedades_accionistas_no_encontradas$sufijo.dta", replace

*------------------------------------------------------------------------------
* 7. Reporte (todos los indicadores se calculan a partir de las bases guardadas)
*------------------------------------------------------------------------------
quietly describe using "$temp/base.dta"
local n_orig = r(N)
quietly describe using "$temp/vig.dta"
local n_vig = r(N)
quietly describe using "$temp/prop.dta"
local n_rel = r(N)
use numero_ruc codigo_registro_anexo using "$temp/base.dta", clear
quietly duplicates drop
local n_desc = _N - `n_vig'

use "$temp/soc_acc.dta", clear
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

use "$temp/h.dta", clear
quietly keep if clase == "SOC_NAC_NO_ENCONTRADA" & directo == 1
quietly duplicates drop inf, force
local inf_nac_no = _N

use "$temp/cuadre.dta", clear
quietly count if residuo_ext > 0.0005
local inf_res_ext = r(N)
quietly count if cad - ext1 > 0.0005
local inf_cad_mayor = r(N)
quietly count if tot1 > 1 + $tol
local inf_sobre100 = r(N)

use "$temp/final.dta", clear
local n_final = _N
quietly summarize saltos_max
local saltos_max = r(max)
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
egen tag = tag(numero_ruc clase)
collapse (sum) pct=pct_total n_soc=tag, by(clase)
replace pct = pct / `n_vig'
gsort -pct
local n_comp = _N
forvalues i = 1/`n_comp' {
    local comp_cl`i'  : display %-24s clase[`i']
    local comp_pct`i' : display %9.2f pct[`i']
    local comp_n`i'   : display %10.0fc n_soc[`i']
}

use "$temp/validacion.dta", clear
local n_terminos = n_terminos[1]
local converge   = converge[1]
local dif_max : display %9.2e dif_max[1]
local cic_exp : display %6.2f cic_exp[1]
local cic_leo : display %6.2f cic_leo[1]

foreach x in n_orig n_desc n_vig n_rel nac_tot nac_no nac_rel_tot nac_rel_no ext_tot ///
             ext_no ext_sin tot_no inf_nac_no inf_res_ext inf_cad_mayor inf_sobre100 ///
             n_final n_final_pn n_pn_unicas n_ciclo {
    local f_`x' : display %12.0fc ``x''
    local f_`x' = strtrim("`f_`x''")
}
local pnac : display %6.2f 100 * `nac_no' / max(1, `nac_tot')
local pext : display %6.2f 100 * `ext_no' / max(1, `ext_tot')
foreach x in pnac pext dif_max cic_exp cic_leo {
    local `x' = strtrim("``x''")
}
local linea = 70 * "="
local guion = 70 * "-"

tempname fh
file open `fh' using "$salida/reporte_expansion_accionistas$sufijo.txt", write replace
file write `fh' "REPORTE - EXPANSIÓN RECURSIVA DE ACCIONISTAS (Stata)" _n "`linea'" _n
file write `fh' "Base de entrada: $entrada" _n
file write `fh' "Filas originales: `f_n_orig' | registros no vigentes descartados: `f_n_desc'" _n
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
file write `fh' "  (la matricial reparte el % del ciclo entre los dueños finales; la expansión lo deja en CICLO)" _n
file close `fh'
type "$salida/reporte_expansion_accionistas$sufijo.txt"

*------------------------------------------------------------------------------
* 8. Bases temporales
*------------------------------------------------------------------------------
if $borrar_temp {
    local archivos : dir "$temp" files "*.dta"
    foreach f of local archivos {
        erase "$temp/`f'"
    }
    capture rmdir "$temp"
    display as text "Bases temporales eliminadas."
}
else display as text "Bases temporales conservadas en: $temp"

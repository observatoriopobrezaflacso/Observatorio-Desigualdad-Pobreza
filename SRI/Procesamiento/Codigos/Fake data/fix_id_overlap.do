/*******************************************************************************
* Fix fake-data ID overlap
*
* Ensures:
*   - Within each year, ≥ 50 % of CEDULA_PK match between F107 and F102
*   - Across years,     ≥ 70 % of all unique IDs appear in more than one year
*
* Strategy:
*   1. Generate a global pool of 15 000 synthetic 10-character IDs.
*   2. For each year, draw IDs for F107 and F102 from the pool, forcing
*      at least 55 % overlap within year.
*   3. Because the pool is 15 000 and each year draws ~10 000, virtually all
*      IDs appear in multiple years (pigeonhole principle).
*   4. Replace CEDULA_PK in every .dta file with the new IDs.
*******************************************************************************/

clear all
set more off
set seed 42

* ============================================================================
* 1. CONFIGURACIÓN
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento"

global dir_f107 "$basedir/Bases/Fake/F107"
global dir_f102 "$basedir/Bases/Fake/F102"

local pool_size   15000
local id_len      10
local min_shared  0.55      // target within-year shared fraction (> 50 %)

* ============================================================================
* 2. GENERAR POOL DE IDs
* ============================================================================

di as result "Generando pool de `pool_size' IDs..."

clear
set obs `pool_size'
gen long pool_idx = _n

* Generar IDs alfanuméricos aleatorios de `id_len' caracteres
local chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local nchars = strlen("`chars'")

gen str`id_len' pool_id = ""
forvalues i = 1/`id_len' {
    gen byte _pos = ceil(runiform() * `nchars')
    replace pool_id = pool_id + substr("`chars'", _pos, 1)
    drop _pos
}

* Verificar unicidad (extremadamente improbable con 36^10 combinaciones)
duplicates report pool_id
quietly duplicates tag pool_id, gen(_dup)
quietly count if _dup > 0
if r(N) > 0 {
    di as error "¡Se encontraron IDs duplicados en el pool! Cambiar el seed."
    exit 198
}
drop _dup

tempfile pool
save "`pool'"

di as text "  Pool generado: `pool_size' IDs únicos de `id_len' caracteres"

* ============================================================================
* 3. DETECTAR AÑOS DISPONIBLES
* ============================================================================

local years_107 ""
local files_107 : dir "$dir_f107" files "F107_*.dta"
foreach f of local files_107 {
    if regexm("`f'", "F107_([0-9]+)\.dta") {
        local years_107 "`years_107' `=regexs(1)'"
    }
}

local years_102 ""
local files_102 : dir "$dir_f102" files "F102_*.dta"
foreach f of local files_102 {
    if regexm("`f'", "F102_([0-9]+)\.dta") {
        local years_102 "`years_102' `=regexs(1)'"
    }
}

local all_years : list years_107 | years_102
local all_years : list sort all_years

di as text "F107: `years_107'"
di as text "F102: `years_102'"
di as text "Todos: `all_years'"

* ============================================================================
* 4. LOOP: REASIGNAR IDs POR AÑO
* ============================================================================

foreach yr of local all_years {

    di as result _n "========== Año `yr' =========="

    local has_107 : list posof "`yr'" in years_107
    local has_102 : list posof "`yr'" in years_102

    * ------------------------------------------------------------------
    * 4.1  Contar IDs únicos en cada formulario
    * ------------------------------------------------------------------

    local n107 0
    local n102 0

    if `has_107' {
        use CEDULA_PK_empleado using "$dir_f107/F107_`yr'.dta", clear
        drop if CEDULA_PK_empleado == ""
        bysort CEDULA_PK_empleado: keep if _n == 1
        local n107 = _N
        gen long seq = _n
        rename CEDULA_PK_empleado old_id
        tempfile uniq_107
        save "`uniq_107'"
    }

    if `has_102' {
        * Corregir formatos numéricos con display string (artefacto fake data)
        use CEDULA_PK using "$dir_f102/F102_`yr'.dta", clear
        drop if CEDULA_PK == ""
        bysort CEDULA_PK: keep if _n == 1
        local n102 = _N
        gen long seq = _n
        rename CEDULA_PK old_id
        tempfile uniq_102
        save "`uniq_102'"
    }

    di as text "  F107 IDs únicos: `n107'"
    di as text "  F102 IDs únicos: `n102'"

    * ------------------------------------------------------------------
    * 4.2  Calcular cuántos IDs compartidos / exclusivos
    * ------------------------------------------------------------------

    local n_shared = ceil(`min_shared' * max(`n107', `n102'))
    if `n_shared' > `n107' local n_shared = `n107'
    if `n_shared' > `n102' local n_shared = `n102'
    * Si solo existe un formulario, no hay compartidos
    if `n107' == 0 | `n102' == 0  local n_shared 0

    local n_f107_only = `n107' - `n_shared'
    local n_f102_only = `n102' - `n_shared'
    local total_needed = `n_shared' + `n_f107_only' + `n_f102_only'

    di as text "  Compartidos: `n_shared'  |  Solo F107: `n_f107_only'  |  Solo F102: `n_f102_only'"

    if `total_needed' > `pool_size' {
        di as error "  Año `yr': necesita `total_needed' IDs pero el pool tiene `pool_size'"
        exit 198
    }

    * ------------------------------------------------------------------
    * 4.3  Sortear IDs del pool
    * ------------------------------------------------------------------

    use "`pool'", clear
    gen double _sort = runiform()
    sort _sort
    drop _sort

    * Asignar roles: shared → f107_only → f102_only
    gen byte _role = 0              // 0 = no asignado
    replace _role = 1 if _n <= `n_shared'                                       // shared
    replace _role = 2 if _n >  `n_shared' & _n <= `n_shared' + `n_f107_only'    // f107 only
    replace _role = 3 if _n >  `n_shared' + `n_f107_only' & _n <= `total_needed' // f102 only
    keep if _role > 0

    * --- Mapping para F107: shared (1) + f107-only (2) ---
    if `n107' > 0 {
        preserve
        keep if _role == 1 | _role == 2
        gen double _s2 = runiform()
        sort _s2
        gen long seq = _n
        rename pool_id new_id
        keep seq new_id
        tempfile map_107
        save "`map_107'"
        restore
    }

    * --- Mapping para F102: shared (1) + f102-only (3) ---
    if `n102' > 0 {
        preserve
        keep if _role == 1 | _role == 3
        gen double _s2 = runiform()
        sort _s2
        gen long seq = _n
        rename pool_id new_id
        keep seq new_id
        tempfile map_102
        save "`map_102'"
        restore
    }

    * ------------------------------------------------------------------
    * 4.4  Aplicar mapping a F107
    * ------------------------------------------------------------------

    if `has_107' {
        * Unir old_id (seq) con new_id
        use "`uniq_107'", clear
        merge 1:1 seq using "`map_107'", nogen
        keep old_id new_id
        tempfile f107_remap
        save "`f107_remap'"

        * Aplicar al archivo completo
        use "$dir_f107/F107_`yr'.dta", clear
        rename CEDULA_PK_empleado old_id
        merge m:1 old_id using "`f107_remap'", keep(master match) nogen
        * Observaciones con old_id == "" no matchean → mantener vacías
        gen str`id_len' CEDULA_PK_empleado = cond(new_id != "", new_id, old_id)
        drop old_id new_id
        order CEDULA_PK_empleado, first
        * Actualizar RUC_PK_empleado si existe
        capture replace RUC_PK_empleado = CEDULA_PK_empleado

        save "$dir_f107/F107_`yr'.dta", replace
        di as text "  F107_`yr'.dta  ✓  (`n107' IDs remapeados)"
    }

    * ------------------------------------------------------------------
    * 4.5  Aplicar mapping a F102
    * ------------------------------------------------------------------

    if `has_102' {
        use "`uniq_102'", clear
        merge 1:1 seq using "`map_102'", nogen
        keep old_id new_id
        tempfile f102_remap
        save "`f102_remap'"

        use "$dir_f102/F102_`yr'.dta", clear

        * Corregir formatos numéricos con display string
        foreach v of varlist _all {
            capture confirm numeric variable `v'
            if !_rc {
                local fmt : format `v'
                if regexm("`fmt'", "s$") {
                    format `v' %12.0g
                }
            }
        }

        rename CEDULA_PK old_id
        merge m:1 old_id using "`f102_remap'", keep(master match) nogen
        gen str`id_len' CEDULA_PK = cond(new_id != "", new_id, old_id)
        drop old_id new_id
        order CEDULA_PK, first
        capture replace RUC_PK = CEDULA_PK

        save "$dir_f102/F102_`yr'.dta", replace
        di as text "  F102_`yr'.dta  ✓  (`n102' IDs remapeados)"
    }
}

* ============================================================================
* 5. VERIFICACIÓN
* ============================================================================

di as result _n "========== Verificación =========="

* --- 5.1  Overlap dentro de cada año ---
di as text _n "Within-year overlap (F107 ∩ F102):"

local years_both ""
foreach yr of local years_107 {
    local found : list posof "`yr'" in years_102
    if `found' local years_both "`years_both' `yr'"
}
local years_both : list sort years_both

foreach yr of local years_both {
    * IDs únicos de F107
    use CEDULA_PK_empleado using "$dir_f107/F107_`yr'.dta", clear
    drop if CEDULA_PK_empleado == ""
    bysort CEDULA_PK_empleado: keep if _n == 1
    local n107 = _N
    rename CEDULA_PK_empleado CEDULA_PK
    tempfile v107
    save "`v107'"

    * IDs únicos de F102
    use CEDULA_PK using "$dir_f102/F102_`yr'.dta", clear
    drop if CEDULA_PK == ""
    bysort CEDULA_PK: keep if _n == 1
    local n102 = _N

    * Merge para contar overlap
    merge 1:1 CEDULA_PK using "`v107'"
    quietly count if _merge == 3
    local overlap = r(N)
    local pct107 = `overlap' / `n107' * 100
    local pct102 = `overlap' / `n102' * 100
    local ok = cond(`pct107' >= 50 & `pct102' >= 50, "✓", "✗")

    di as text "  `yr': overlap = " %6.0fc `overlap' ///
        "   F107 = " %4.1f `pct107' "%   F102 = " %4.1f `pct102' "%   `ok'"
}

* --- 5.2  Overlap entre años ---
di as text _n "Across-year overlap:"

* Recolectar todos los IDs de todos los años con su año
clear
tempfile all_ids
gen str10 CEDULA_PK = ""
gen int anio = .
save "`all_ids'", replace emptyok

foreach yr of local all_years {
    local has_107 : list posof "`yr'" in years_107
    local has_102 : list posof "`yr'" in years_102

    if `has_107' {
        use CEDULA_PK_empleado using "$dir_f107/F107_`yr'.dta", clear
        drop if CEDULA_PK_empleado == ""
        rename CEDULA_PK_empleado CEDULA_PK
        gen int anio = `yr'
        append using "`all_ids'"
        save "`all_ids'", replace
    }
    if `has_102' {
        use CEDULA_PK using "$dir_f102/F102_`yr'.dta", clear
        drop if CEDULA_PK == ""
        gen int anio = `yr'
        append using "`all_ids'"
        save "`all_ids'", replace
    }
}

use "`all_ids'", clear
* Quedarse con combinaciones únicas id × año
bysort CEDULA_PK anio: keep if _n == 1
* Contar en cuántos años aparece cada ID
bysort CEDULA_PK: gen n_years = _N
bysort CEDULA_PK: keep if _n == 1

quietly count
local total_unique = r(N)
quietly count if n_years > 1
local multi_year = r(N)
local pct = `multi_year' / `total_unique' * 100
local ok = cond(`pct' >= 70, "✓", "✗")

di as text "  Total IDs únicos:  " %7.0fc `total_unique'
di as text "  IDs en 2+ años:   " %7.0fc `multi_year' " (" %4.1f `pct' "%)"
di as text "  Target ≥ 70 %:    `ok'"

* ============================================================================
* 6. FIN
* ============================================================================

di as result _n "========== Proceso completado =========="

* ═══════════════════════════════════════════════════════════════════════════════
* SERIE HISTÓRICA TMI 1990-2024 CON DETECCIÓN DE ETNIA Y ÁREA
* ═══════════════════════════════════════════════════════════════════════════════

local carpeta_edg "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"
local carpeta_env "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV"

* Bases acumuladas
tempfile base_acumulada base_nacimientos base_disponibilidad

clear
set obs 0
gen anio       = .
gen MI         = .
gen tiene_etnia = .
gen tiene_area  = .
gen var_etnia  = ""
gen var_area   = ""
save `base_acumulada', emptyok replace

clear
set obs 0
gen anio = .
gen NV   = .
gen tiene_etnia_env = .
gen tiene_area_env  = .
gen var_etnia_env   = ""
gen var_area_env    = ""
save `base_nacimientos', emptyok replace

* ── DEFUNCIONES (EDG) ────────────────────────────────────────────────────────
forvalues y = 1990/2024 {
    di "═══ EDG `y' ═══"
    
    capture import spss using "`carpeta_edg'\EDG_`y'.sav", clear
    if _rc {
        di "EDG_`y'.sav no encontrado, se salta..."
        continue
    }

    * Estandarizar nombres de edad
    foreach v in ANOF ANON MESF MESN COD_EDA EDAD {
        capture confirm variable `v'
        if !_rc rename `v' `=lower("`v'")'
    }
    capture confirm string variable cod_edad
    if !_rc destring cod_edad, replace force

    * Crear menor1
    capture confirm variable cod_edad
    if !_rc {
        gen menor1 = inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)
    }
    else {
        capture confirm variable aniof anion mesf mesn
        if !_rc {
            gen edad_meses = (aniof - anion)*12 + (mesf - mesn)
            gen menor1 = (edad_meses >= 0 & edad_meses < 12)
        }
        else {
            gen menor1 = 0
        }
    }

    * ── DETECCIÓN DE ETNIA (EDG) ─────────────────────────────────────────────
    * Busca por nombre exacto y también por sinónimos/variantes
    local var_etnia_encontrada ""
    foreach candidato in etnia p18 sec_a_p18 autoidentificacion ///
                         auto_identif etnia_dec p_etnia etnia_fall ///
                         etnias grupoetnico grupo_etnico raza {
        capture confirm variable `candidato'
        if !_rc {
            local var_etnia_encontrada "`candidato'"
            continue, break
        }
    }
    * Si no encontró por nombre exacto, busca por patrón en el label
    if "`var_etnia_encontrada'" == "" {
        quietly ds, has(type numeric)
        foreach v in `r(varlist)' {
            local lbl : variable label `v'
            if regexm(lower("`lbl'"), "etni|autoident|raza|indigena|pueblo") {
                local var_etnia_encontrada "`v'"
                continue, break
            }
        }
    }

    * ── DETECCIÓN DE ÁREA (EDG) ──────────────────────────────────────────────
    local var_area_encontrada ""
    foreach candidato in area_res area_fall area areares areafall ///
                         zona_res zona_fall zona area_residencia {
        capture confirm variable `candidato'
        if !_rc {
            local var_area_encontrada "`candidato'"
            continue, break
        }
    }
    if "`var_area_encontrada'" == "" {
        quietly ds, has(type numeric)
        foreach v in `r(varlist)' {
            local lbl : variable label `v'
            if regexm(lower("`lbl'"), "area|zona|urbano|rural|residencia") {
                local var_area_encontrada "`v'"
                continue, break
            }
        }
    }

    * Reportar hallazgos del año
    if "`var_etnia_encontrada'" != "" {
        di "  ✔ ETNIA encontrada: `var_etnia_encontrada'"
    }
    else {
        di "  ✘ ETNIA NO encontrada en EDG `y'"
    }
    if "`var_area_encontrada'" != "" {
        di "  ✔ ÁREA encontrada: `var_area_encontrada'"
    }
    else {
        di "  ✘ ÁREA NO encontrada en EDG `y'"
    }

    * Colapsar
    gen tiene_etnia_flag = ("`var_etnia_encontrada'" != "")
    gen tiene_area_flag  = ("`var_area_encontrada'"  != "")
    gen var_etnia_str    = "`var_etnia_encontrada'"
    gen var_area_str     = "`var_area_encontrada'"

    collapse (sum) MI=menor1 ///
             (max) tiene_etnia=tiene_etnia_flag tiene_area=tiene_area_flag ///
             (firstnm) var_etnia=var_etnia_str var_area=var_area_str
    gen anio = `y'

    append using `base_acumulada'
    save `base_acumulada', replace
}

* ── NACIMIENTOS (ENV) ────────────────────────────────────────────────────────
forvalues y = 1990/2024 {
    di "═══ ENV `y' ═══"

    capture import spss using "`carpeta_env'\ENV_`y'.sav", clear
    if _rc capture import spss using "`carpeta_env'\ENV_ `y'.sav", clear
    if _rc {
        di "ENV_`y'.sav no encontrado, se salta..."
        continue
    }

    * ── DETECCIÓN DE ETNIA MADRE (ENV) ───────────────────────────────────────
    local var_etnia_env ""
    foreach candidato in etnia_m etnia_mad etnia_madre p_etnia etnia ///
                         autoident_m auto_m alfabet alfabet_m ///
                         grupo_etnico_m raza_m pueblo_m {
        capture confirm variable `candidato'
        if !_rc {
            local var_etnia_env "`candidato'"
            continue, break
        }
    }
    if "`var_etnia_env'" == "" {
        quietly ds, has(type numeric)
        foreach v in `r(varlist)' {
            local lbl : variable label `v'
            if regexm(lower("`lbl'"), "etni|autoident|raza|indigena|madre|pueblo") {
                local var_etnia_env "`v'"
                continue, break
            }
        }
    }

    * ── DETECCIÓN DE ÁREA MADRE (ENV) ────────────────────────────────────────
    local var_area_env ""
    foreach candidato in area_res area_m area areares zona_res zona ///
                         area_madre area_residencia {
        capture confirm variable `candidato'
        if !_rc {
            local var_area_env "`candidato'"
            continue, break
        }
    }
    if "`var_area_env'" == "" {
        quietly ds, has(type numeric)
        foreach v in `r(varlist)' {
            local lbl : variable label `v'
            if regexm(lower("`lbl'"), "area|zona|urbano|rural|residencia") {
                local var_area_env "`v'"
                continue, break
            }
        }
    }

    if "`var_etnia_env'" != "" di "  ✔ ETNIA MADRE encontrada: `var_etnia_env'"
    else                        di "  ✘ ETNIA MADRE NO encontrada en ENV `y'"
    if "`var_area_env'"  != "" di "  ✔ ÁREA encontrada: `var_area_env'"
    else                        di "  ✘ ÁREA NO encontrada en ENV `y'"

    gen NV = 1
    gen tiene_etnia_flag = ("`var_etnia_env'" != "")
    gen tiene_area_flag  = ("`var_area_env'"  != "")
    gen var_etnia_str    = "`var_etnia_env'"
    gen var_area_str     = "`var_area_env'"

    collapse (sum) NV ///
             (max) tiene_etnia_env=tiene_etnia_flag tiene_area_env=tiene_area_flag ///
             (firstnm) var_etnia_env=var_etnia_str var_area_env=var_area_str
    gen anio = `y'

    append using `base_nacimientos'
    save `base_nacimientos', replace
}

* ── MERGE Y TMI FINAL ────────────────────────────────────────────────────────

use `base_acumulada', clear
merge 1:1 anio using `base_nacimientos'
keep if _merge == 3
drop _merge

gen tmi = (MI / NV) * 1000
label var tmi "Tasa de Mortalidad Infantil (por 1.000 NV)"
gsort anio

save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\TMI_Final_90_24.dta", replace

* ── REPORTE DE DISPONIBILIDAD ────────────────────────────────────────────────
di ""
di "══════════════════════════════════════════════════════"
di "DISPONIBILIDAD DE VARIABLES POR AÑO"
di "══════════════════════════════════════════════════════"
list anio MI NV tmi tiene_etnia var_etnia tiene_area var_area ///
          tiene_etnia_env var_etnia_env tiene_area_env var_area_env, ///
          separator(5) noobs

* Desde qué año están disponibles ambas variables en ambas bases
di ""
di "Primer año con ETNIA en EDG:"
list anio var_etnia if tiene_etnia==1, noobs clean
di ""
di "Primer año con ETNIA en ENV:"  
list anio var_etnia_env if tiene_etnia_env==1, noobs clean
/*******************************************************************************
PARTE 1: Numerador RMM - AÑOS 1990-1996 (CIE-9) - CON CLASIFICACIÓN DIRECTA/INDIRECTA
*******************************************************************************/

clear all
set more off
set maxvar 32767

*=== DIRECTORIOS ===*
global input_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Defunciones\"
global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

*=== ARCHIVOS TEMPORALES ===*
tempfile acumulado_numerador_cie9

*=== LOOP 1990-1996 ===*
forvalues anio = 1990/1996 {
    
    di _n(3) "=== PROCESANDO AÑO CIE-9: `anio' ==="
    
    *--- 1. IMPORTAR BASE ---*
    local archivo = "${input_dir}EDG_`anio'.sav"
    
    capture confirm file "`archivo'"
    if _rc != 0 {
        di "Archivo EDG_`anio'.sav no encontrado. Continuando."
        continue
    }
    
    capture import spss using "`archivo'", clear
    if _rc != 0 {
        capture usespss using "`archivo'", clear
        if _rc != 0 {
            di "ERROR: No se pudo importar EDG_`anio'.sav"
            continue
        }
    }
    
    *--- 2. ESTANDARIZAR NOMBRES ---*
    rename *, lower
    
    *--- 3. FILTRO POBLACIONAL ---*
    * Verificar sexo
    capture confirm numeric variable sexo
    if _rc == 0 {
        keep if sexo == 2 & inrange(edad, 15, 49)
    }
    else {
        keep if inlist(lower(sexo), "f", "fem", "femenino", "mujer") & inrange(edad, 15, 49)
    }
    
    *--- 4. IDENTIFICAR VARIABLE DE CAUSA ---*
    local causa_var = ""
    foreach var in causa4 causa CAUSA {
        capture confirm variable `var'
        if _rc == 0 {
            local causa_var "`var'"
            di "Variable de causa encontrada: `var'"
            continue, break
        }
    }
    
    if "`causa_var'" == "" {
        di "ERROR: No se encontró variable de causa en `anio'"
        continue
    }
    
    *--- 5. CREAR VARIABLE NUMÉRICA DE CAUSA ---*
    capture confirm numeric variable `causa_var'
    if _rc == 0 {
        gen causa_num = `causa_var'
    }
    else {
        * Es string - extraer números
        clonevar causa_clean = `causa_var'
        replace causa_clean = strtrim(causa_clean)
        replace causa_clean = subinstr(causa_clean, ".", "", .)
        gen causa_num = real(regexs(0)) if regexm(causa_clean, "([0-9]+)")
        drop causa_clean
    }
    
    *--- 6. IDENTIFICAR MUERTES MATERNAS ---*
    gen muerte_materna = inrange(causa_num, 630, 676)
    
    *--- 7. CLASIFICAR TIPO DE MUERTE ---*
    gen tipo_mm = 0
    
    * Directas (630-646, 651-676)
    replace tipo_mm = 1 if inrange(causa_num, 630, 646) & muerte_materna == 1
    replace tipo_mm = 1 if inrange(causa_num, 651, 676) & muerte_materna == 1
    
    * Indirectas (647-648)
    replace tipo_mm = 2 if inrange(causa_num, 647, 648) & muerte_materna == 1
    
    * No especificadas
    replace tipo_mm = 4 if inrange(causa_num, 630, 676) & muerte_materna == 1 & tipo_mm == 0
    
    *--- 8. EDUCACIÓN ---*
    gen nivel_estandar = .
    
    capture confirm variable nivel
    if _rc != 0 {
        capture confirm variable NIVEL
        if _rc == 0 rename NIVEL nivel
    }
    
    capture confirm variable nivel
    if _rc == 0 {
        replace nivel_estandar = 0 if nivel == 0
        replace nivel_estandar = 1 if inrange(nivel, 31, 36)
        replace nivel_estandar = 2 if inrange(nivel, 39, 46)
        replace nivel_estandar = 3 if inrange(nivel, 49, 59)
        replace nivel_estandar = 9 if nivel == 99
        
        count if inlist(nivel, 10, 20, 30) & muerte_materna == 1
        if r(N) > 0 {
            di "Año `anio': `r(N)' muertes maternas con nivel no clasificado (10,20,30)"
        }
    }
    
    label define nivel_lbl 0 "Sin instrucción" 1 "Primaria" 2 "Secundaria" 3 "Superior" 9 "No especificado"
    label values nivel_estandar nivel_lbl
    
    *--- 9. CONTAR ---*
    count if muerte_materna == 1
    local mm_total = r(N)
    
    count if tipo_mm == 1
    local mm_directas = r(N)
    
    count if tipo_mm == 2
    local mm_indirectas = r(N)
    
    count if tipo_mm == 4
    local mm_no_espec = r(N)
    
    * Por nivel educativo
    count if muerte_materna == 1 & nivel_estandar == 0
    local mm_sin_inst = r(N)
    count if muerte_materna == 1 & nivel_estandar == 1
    local mm_primaria = r(N)
    count if muerte_materna == 1 & nivel_estandar == 2
    local mm_secundaria = r(N)
    count if muerte_materna == 1 & nivel_estandar == 3
    local mm_superior = r(N)
    count if muerte_materna == 1 & nivel_estandar == 9
    local mm_no_espec_educ = r(N)
    count if muerte_materna == 1 & missing(nivel_estandar)
    local mm_sin_educ = r(N)
    
    * Mostrar resultados
    di "Año `anio': Total MM = `mm_total'"
    di "  Directas: `mm_directas'"
    di "  Indirectas: `mm_indirectas'"
    di "  No especificadas: `mm_no_espec'"
    di "  Por nivel educativo:"
    di "    Sin instrucción: `mm_sin_inst'"
    di "    Primaria: `mm_primaria'"
    di "    Secundaria: `mm_secundaria'"
    di "    Superior: `mm_superior'"
    di "    No especificado: `mm_no_espec_educ'"
    di "    Sin dato: `mm_sin_educ'"
    
    *--- 10. GUARDAR EN BASE ACUMULADA ---*
    clear
    set obs 1
    gen anio = `anio'
    gen mm_total = `mm_total'
    gen mm_directas = `mm_directas'
    gen mm_indirectas = `mm_indirectas'
    gen mm_covid = 0
    gen mm_no_especificadas = `mm_no_espec'
    
    gen mm_sin_instruccion = `mm_sin_inst'
    gen mm_primaria = `mm_primaria'
    gen mm_secundaria = `mm_secundaria'
    gen mm_superior = `mm_superior'
    gen mm_no_especificado_educ = `mm_no_espec_educ'
    gen mm_sin_educacion = `mm_sin_educ'
    
    capture confirm file `acumulado_numerador_cie9'
    if _rc != 0 save `acumulado_numerador_cie9', emptyok
    else {
        append using `acumulado_numerador_cie9'
        save `acumulado_numerador_cie9', replace
    }
}

*--- 11. GUARDAR RESULTADOS FINALES ---*
capture confirm file `acumulado_numerador_cie9'
if _rc == 0 {
    use `acumulado_numerador_cie9', clear
    sort anio
    save "${output_dir}numerador_rmm_1990_1996_CLASIFICADO.dta", replace
    export excel using "${output_dir}numerador_rmm_1990_1996_CLASIFICADO.xlsx", firstrow(var) replace
    
    * Mostrar resumen
    list anio mm_total mm_directas mm_indirectas mm_no_especificadas, sep(5)
}

di _n(3) "=== PARTE 1 (CIE-9) COMPLETADA: 1990-1996 ==="








/*******************************************************************************
PARTE 2A: Numerador RMM - AÑOS 1997-2024 (EXCEPTO 2011)
*******************************************************************************/

clear all
set more off
set maxvar 32767

*=== DIRECTORIOS ===*
global input_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Defunciones\"
global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

*=== ARCHIVOS TEMPORALES ===*
tempfile acumulado_numerador_cie10

*=== LOOP 1997-2024 (EXCLUYENDO 2011) ===*
forvalues anio = 1997/2024 {
    
    * Saltar 2011
    if `anio' == 2011 {
        continue
    }
    
    di _n(3) "=== PROCESANDO AÑO CIE-10: `anio' ==="
    
    *--- 1. IMPORTAR BASE ---*
    local archivo = "${input_dir}EDG_`anio'.sav"
    
    capture confirm file "`archivo'"
    if _rc != 0 {
        di "Archivo EDG_`anio'.sav no encontrado. Continuando."
        continue
    }
    
    capture import spss using "`archivo'", clear
    if _rc != 0 {
        capture usespss using "`archivo'", clear
        if _rc != 0 {
            di "ERROR: No se pudo importar EDG_`anio'.sav"
            continue
        }
    }
    
    *--- 2. ESTANDARIZAR NOMBRES ---*
    rename *, lower
    
    *--- 3. FILTRO POBLACIONAL ---*
    capture confirm numeric variable sexo
    if _rc == 0 {
        keep if sexo == 2 & inrange(edad, 15, 49)
    }
    else {
        keep if inlist(lower(sexo), "f", "fem", "femenino", "mujer") & inrange(edad, 15, 49)
    }
    
    *--- 4. IDENTIFICAR VARIABLE DE CAUSA ---*
    local causa_var = ""
    foreach var in causa4 causa CAUSA {
        capture confirm variable `var'
        if _rc == 0 {
            local causa_var "`var'"
            continue, break
        }
    }
    
    if "`causa_var'" == "" {
        di "ERROR: No se encontró variable de causa en `anio'"
        continue
    }
    
    *--- 5. CREAR VARIABLE STRING DE CAUSA ---*
    capture confirm numeric variable `causa_var'
    if _rc == 0 {
        tostring `causa_var', gen(causa_str) force
    }
    else {
        clonevar causa_str = `causa_var'
    }
    
    replace causa_str = upper(strtrim(causa_str))
    replace causa_str = subinstr(causa_str, ".", "", .)
    
    *--- 6. IDENTIFICAR MUERTES MATERNAS ---*
    gen muerte_materna = regexm(causa_str, "^O[0-9][0-9]")
    
    * COVID-19 para 2020-2022
    if inrange(`anio', 2020, 2022) {
        replace muerte_materna = 1 if inlist(causa_str, "U071", "U072", "U07.1", "U07.2")
    }
    
    *--- 7. CLASIFICAR TIPO DE MUERTE ---*
    gen tipo_mm = 0
    
    * Directas
    replace tipo_mm = 1 if regexm(causa_str, "^O0[0-8]") & muerte_materna == 1
    replace tipo_mm = 1 if regexm(causa_str, "^O20|^O44|^O45|^O46|^O67|^O72") & muerte_materna == 1
    replace tipo_mm = 1 if regexm(causa_str, "^O85|^O86|^O91") & muerte_materna == 1
    
    * Indirectas
    replace tipo_mm = 2 if regexm(causa_str, "^O1[0-6]") & muerte_materna == 1 & tipo_mm == 0
    replace tipo_mm = 2 if regexm(causa_str, "^O98|^O99") & muerte_materna == 1 & tipo_mm == 0
    
    * COVID-19
    if inrange(`anio', 2020, 2022) {
        replace tipo_mm = 3 if inlist(causa_str, "U071", "U072", "U07.1", "U07.2") & muerte_materna == 1
    }
    
    * No especificadas
    replace tipo_mm = 4 if regexm(causa_str, "^O95|^O96|^O97") & muerte_materna == 1 & tipo_mm == 0
    
    * Otras directas
    replace tipo_mm = 1 if muerte_materna == 1 & tipo_mm == 0
    
    *--- 8. EDUCACIÓN ---*
    gen nivel_estandar = .
    
    * 1997-2009
    if inrange(`anio', 1997, 2009) {
        capture confirm variable nivel
        if _rc == 0 {
            replace nivel_estandar = 0 if nivel == 0
            replace nivel_estandar = 1 if inlist(nivel, 1, 2)
            replace nivel_estandar = 2 if inlist(nivel, 3, 4, 5, 6)
            replace nivel_estandar = 3 if inlist(nivel, 7, 8)
            replace nivel_estandar = 9 if nivel == 9
        }
    }
    
    * 2010
    if `anio' == 2010 {
        capture confirm variable nivel
        if _rc == 0 {
            replace nivel_estandar = 0 if nivel == 0
            replace nivel_estandar = 1 if inlist(nivel, 1, 2)
            replace nivel_estandar = 2 if inlist(nivel, 3, 4, 5, 6)
            replace nivel_estandar = 3 if inlist(nivel, 7, 8)
            replace nivel_estandar = 9 if nivel == 9
        }
    }
    
    * 2012-2024
    if `anio' >= 2012 {
        capture confirm variable niv_inst
        if _rc == 0 {
            capture tostring niv_inst, replace force
            replace nivel_estandar = 0 if inlist(niv_inst, "0", "00")
            replace nivel_estandar = 1 if inlist(niv_inst, "1", "01", "2", "02")
            replace nivel_estandar = 2 if inlist(niv_inst, "3", "03", "4", "04", "5", "05", "6", "06")
            replace nivel_estandar = 3 if inlist(niv_inst, "7", "07", "8", "08")
            replace nivel_estandar = 9 if inlist(niv_inst, "9", "09", "99")
        }
    }
    
    label define nivel_lbl 0 "Sin instrucción" 1 "Primaria" 2 "Secundaria" 3 "Superior" 9 "No especificado"
    label values nivel_estandar nivel_lbl
    
    *--- 9. CONTAR ---*
    count if muerte_materna == 1
    local mm_total = r(N)
    
    count if tipo_mm == 1
    local mm_directas = r(N)
    
    count if tipo_mm == 2
    local mm_indirectas = r(N)
    
    count if tipo_mm == 3
    local mm_covid = r(N)
    
    count if tipo_mm == 4
    local mm_no_espec = r(N)
    
    *--- 10. CONTAR POR NIVEL EDUCATIVO ---*
    count if muerte_materna == 1 & nivel_estandar == 0
    local mm_sin_inst = r(N)
    
    count if muerte_materna == 1 & nivel_estandar == 1
    local mm_primaria = r(N)
    
    count if muerte_materna == 1 & nivel_estandar == 2
    local mm_secundaria = r(N)
    
    count if muerte_materna == 1 & nivel_estandar == 3
    local mm_superior = r(N)
    
    count if muerte_materna == 1 & nivel_estandar == 9
    local mm_no_espec_educ = r(N)
    
    count if muerte_materna == 1 & missing(nivel_estandar)
    local mm_sin_educ = r(N)
    
    *--- 11. GUARDAR EN BASE ACUMULADA ---*
    clear
    set obs 1
    gen anio = `anio'
    gen mm_total = `mm_total'
    gen mm_directas = `mm_directas'
    gen mm_indirectas = `mm_indirectas'
    gen mm_covid = `mm_covid'
    gen mm_no_especificadas = `mm_no_espec'
    
    gen mm_sin_instruccion = `mm_sin_inst'
    gen mm_primaria = `mm_primaria'
    gen mm_secundaria = `mm_secundaria'
    gen mm_superior = `mm_superior'
    gen mm_no_especificado_educ = `mm_no_espec_educ'
    gen mm_sin_educacion = `mm_sin_educ'
    
    capture confirm file `acumulado_numerador_cie10'
    if _rc != 0 save `acumulado_numerador_cie10', emptyok
    else {
        append using `acumulado_numerador_cie10'
        save `acumulado_numerador_cie10', replace
    }
}

*--- 12. GUARDAR BASE SIN 2011 ---*
capture confirm file `acumulado_numerador_cie10'
if _rc == 0 {
    use `acumulado_numerador_cie10', clear
    sort anio
    save "${output_dir}numerador_rmm_1997_2024_SIN_2011.dta", replace
}

di _n(3) "=== PARTE 2A COMPLETADA (1997-2024 excepto 2011) ==="





/*******************************************************************************
PARTE 2B: Procesamiento ESPECIAL de 2011 (con documentación)
*******************************************************************************/

clear all
set more off

global input_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Defunciones\"
global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

local anio = 2011
di _n(3) "=== PROCESANDO AÑO 2011 (BLOQUE ESPECIAL) ==="

*--- 1. IMPORTAR BASE 2011 ---*
local archivo = "${input_dir}EDG_`anio'.sav"
import spss using "`archivo'", clear
rename *, lower

*--- 2. FILTRO POBLACIONAL (con diagnóstico) ---*
di _n(2) "=== DIAGNÓSTICO DE VARIABLES EN 2011 ==="
ds

* Ver tipo de variable sexo
di "Tipo de variable sexo:"
describe sexo

* Convertir sexo a numérico si es necesario
capture confirm numeric variable sexo
if _rc != 0 {
    di "Variable sexo es string, convirtiendo..."
    destring sexo, replace force
}

* Aplicar filtro
keep if sexo == 2 & inrange(edad, 15, 49)

*--- 3. IDENTIFICAR VARIABLE DE CAUSA ---*
* En 2011, la variable de causa es 'causa4'
local causa_var "causa4"
di "Variable de causa utilizada en 2011: `causa_var'"

*--- 4. CREAR VARIABLE STRING PARA ANÁLISIS ---*
clonevar causa_str = `causa_var'
replace causa_str = upper(strtrim(causa_str))
replace causa_str = subinstr(causa_str, ".", "", .)

*--- 5. IDENTIFICAR CÓDIGOS MATERNOS (O00-O99) ---*
gen es_materna = regexm(causa_str, "^O[0-9][0-9]")

*--- 6. MOSTRAR DISTRIBUCIÓN DE CÓDIGOS O ---*
di _n(2) "=== DISTRIBUCIÓN DE CÓDIGOS O EN 2011 ==="
tab causa_str if es_materna == 1, sort

*--- 7. CLASIFICAR POR TIPO ---*
gen tipo = ""

* Directas
replace tipo = "Directa" if regexm(causa_str, "^O0[0-8]") & es_materna == 1
replace tipo = "Directa" if regexm(causa_str, "^O20|^O44|^O45|^O46|^O67|^O72") & es_materna == 1
replace tipo = "Directa" if regexm(causa_str, "^O85|^O86|^O91") & es_materna == 1

* Indirectas
replace tipo = "Indirecta" if regexm(causa_str, "^O1[0-6]") & es_materna == 1
replace tipo = "Indirecta" if regexm(causa_str, "^O98|^O99") & es_materna == 1

* No especificadas
replace tipo = "No especificada" if regexm(causa_str, "^O95|^O96|^O97") & es_materna == 1

* El resto son directas
replace tipo = "Directa" if es_materna == 1 & tipo == ""

*--- 8. MOSTRAR CLASIFICACIÓN POR TIPO ---*
di _n(2) "=== CLASIFICACIÓN POR TIPO EN 2011 ==="
tab tipo

*--- 9. EDUCACIÓN EN 2011 ---*
gen nivel_estandar = .

di _n(2) "=== DISTRIBUCIÓN DE EDUCACIÓN EN 2011 (TODAS LAS MUJERES) ==="
tab niv_inst, missing

di _n(2) "=== DISTRIBUCIÓN DE EDUCACIÓN EN 2011 (SOLO MUERTES MATERNAS) ==="
tab niv_inst if es_materna == 1, missing

* Clasificar según estandarización
replace nivel_estandar = 0 if niv_inst == "00"      // Sin instrucción
replace nivel_estandar = 1 if inlist(niv_inst, "01", "02")   // Primaria
replace nivel_estandar = 2 if inlist(niv_inst, "03", "04", "05", "06") // Secundaria
replace nivel_estandar = 3 if niv_inst == "07"      // Superior
replace nivel_estandar = 9 if inlist(niv_inst, "09", "99")   // No especificado

*--- 10. CONTAR ---*
count if es_materna == 1
local mm_total = r(N)

count if tipo == "Directa"
local mm_directas = r(N)

count if tipo == "Indirecta"
local mm_indirectas = r(N)

count if tipo == "No especificada"
local mm_no_espec = r(N)

local mm_covid = 0

* Por nivel educativo
count if es_materna == 1 & nivel_estandar == 0
local mm_sin_inst = r(N)

count if es_materna == 1 & nivel_estandar == 1
local mm_primaria = r(N)

count if es_materna == 1 & nivel_estandar == 2
local mm_secundaria = r(N)

count if es_materna == 1 & nivel_estandar == 3
local mm_superior = r(N)

count if es_materna == 1 & nivel_estandar == 9
local mm_no_espec_educ = r(N)

count if es_materna == 1 & missing(nivel_estandar)
local mm_sin_educ = r(N)

*--- 11. MOSTRAR RESULTADOS FINALES ---*
di _n(2) "=== RESULTADOS FINALES 2011 ==="
di "Total muertes maternas: `mm_total'"
di "  Directas: `mm_directas'"
di "  Indirectas: `mm_indirectas'"
di "  No especificadas: `mm_no_espec'"
di "Por nivel educativo:"
di "  Sin instrucción: `mm_sin_inst'"
di "  Primaria: `mm_primaria'"
di "  Secundaria: `mm_secundaria'"
di "  Superior: `mm_superior'"
di "  No especificado: `mm_no_espec_educ'"

*--- 12. CREAR BASE PARA 2011 ---*
clear
set obs 1
gen anio = 2011
gen mm_total = `mm_total'
gen mm_directas = `mm_directas'
gen mm_indirectas = `mm_indirectas'
gen mm_covid = `mm_covid'
gen mm_no_especificadas = `mm_no_espec'

gen mm_sin_instruccion = `mm_sin_inst'
gen mm_primaria = `mm_primaria'
gen mm_secundaria = `mm_secundaria'
gen mm_superior = `mm_superior'
gen mm_no_especificado_educ = `mm_no_espec_educ'
gen mm_sin_educacion = `mm_sin_educ'

save "${output_dir}numerador_rmm_2011_ESPECIAL.dta", replace

di _n(3) "=== PARTE 2B COMPLETADA (2011) ==="


/*******************************************************************************
PARTE 2C: Unir bases (1997-2010 + 2011 + 2012-2024)
*******************************************************************************/

clear all
set more off

global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

* Cargar base sin 2011
use "${output_dir}numerador_rmm_1997_2024_SIN_2011.dta", clear

* Agregar 2011
append using "${output_dir}numerador_rmm_2011_ESPECIAL.dta"

* Ordenar
sort anio

* Verificar
list anio mm_total mm_directas mm_indirectas mm_covid mm_no_especificadas, sep(5)

* Guardar base completa
save "${output_dir}numerador_rmm_1997_2024_COMPLETO.dta", replace
export excel using "${output_dir}numerador_rmm_1997_2024_COMPLETO.xlsx", firstrow(var) replace

di _n(3) "=== PARTE 2C COMPLETADA ==="
di "Ahora 2011 está incluido con sus valores correctos"


/*******************************************************************************
PARTE 3: Unir CIE-9 (1990-1996) con CIE-10 completo (1997-2024)
*******************************************************************************/

clear all
set more off

global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

* Cargar CIE-9
use "${output_dir}numerador_rmm_1990_1996_CLASIFICADO.dta", clear

* Agregar CIE-10 completo
append using "${output_dir}numerador_rmm_1997_2024_COMPLETO.dta"

* Ordenar
sort anio

* Verificar (especialmente 2011)
list anio mm_total if inlist(anio, 1990, 1995, 2000, 2005, 2010, 2011, 2015, 2020, 2024)

* Guardar base final
save "${output_dir}numerador_rmm_1990_2024_FINAL.dta", replace
export excel using "${output_dir}numerador_rmm_1990_2024_FINAL.xlsx", firstrow(var) replace

di _n(3) "=== PROCESO COMPLETO ==="
di "Base final: ${output_dir}numerador_rmm_1990_2024_FINAL.dta"




/*******************************************************************************
DENOMINADOR: Nacidos Vivos Ecuador 1990-2024 - VERSIÓN ADAPTADA
Incluye:
- Procesamiento anual de archivos ENV_año.sav
- Armonización de nivel educativo (misma clasificación que defunciones)
- Corrección especial para 2011
- Variable agrupada para gráficos (hasta secundaria / superior)
*******************************************************************************/

clear all
set more off
set maxvar 32767

*=== DIRECTORIO ===*
global input_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Nacidos vivos\"
global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

* Verificar que la carpeta existe
di "Buscando archivos en: ${input_dir}"
dir "${input_dir}*.sav"

*=== ARCHIVO TEMPORAL ===*
tempfile acumulado_nacimientos

*=== LOOP PRINCIPAL 1990-2024 ===*
forvalues anio = 1990/2024 {
    
    di _n(3) "=== PROCESANDO AÑO: `anio' (Nacidos Vivos) ==="
    
    *--- 1. IMPORTAR BASE ---*
    local archivo = "${input_dir}ENV_`anio'.sav"
    
    capture confirm file "`archivo'"
    if _rc != 0 {
        di "Archivo ENV_`anio'.sav no encontrado"
        continue
    }
    
    capture import spss using "`archivo'", clear
    if _rc != 0 {
        capture usespss using "`archivo'", clear
        if _rc != 0 {
            di "ERROR: No se pudo importar ENV_`anio'.sav"
            continue
        }
    }
    
    di "Archivo ENV_`anio'.sav importado correctamente"
    
    *--- 2. ESTANDARIZAR NOMBRES A MINÚSCULAS ---*
    rename *, lower
    
    *--- 3. IDENTIFICAR VARIABLE DE EDUCACIÓN ---*
    local educ_var = ""
    
    if `anio' <= 2010 {
        foreach var in niv_inst nivel_instruc nivel {
            capture confirm variable `var'
            if _rc == 0 {
                local educ_var "`var'"
                di "Variable de educación encontrada: `var' (período 1990-2010)"
                continue, break
            }
        }
    }
    
    if `anio' >= 2011 {
        capture confirm variable niv_inst
        if _rc == 0 {
            local educ_var "niv_inst"
            di "Variable de educación encontrada: niv_inst (período 2011-2024)"
        }
    }
    
    if "`educ_var'" == "" {
        di "ADVERTENCIA: No se encontró variable de educación para `anio'"
    }
    
    *--- 4. DIAGNÓSTICO: VER VALORES DE LA VARIABLE DE EDUCACIÓN ---*
    if "`educ_var'" != "" {
        di "=== DIAGNÓSTICO `anio' - Variable: `educ_var' ==="
        di "Tipo de variable:"
        describe `educ_var'
        
        di "Primeros 10 valores:"
        list `educ_var' in 1/10
        
        di "Distribución de valores (frecuencias):"
        tab `educ_var', missing
    }
    
    *--- 5. ARMONIZAR NIVEL EDUCATIVO ---*
    gen nivel_estandar = .
    
    if "`educ_var'" != "" {
        
        *--- 5.1 PERÍODO 1990-2010 ---*
        if `anio' <= 2010 {
            
            * Verificar si es numérica
            capture confirm numeric variable `educ_var'
            if _rc == 0 {
                * ES NUMÉRICA
                replace nivel_estandar = 0 if `educ_var' == 0
                replace nivel_estandar = 1 if inlist(`educ_var', 1, 2)
                replace nivel_estandar = 2 if inlist(`educ_var', 3, 4, 5, 6)
                replace nivel_estandar = 3 if inlist(`educ_var', 7, 8)
                replace nivel_estandar = 9 if inlist(`educ_var', 9, 99)
            }
            else {
                * ES STRING
                capture drop educ_clean
                clonevar educ_clean = `educ_var'
                replace educ_clean = strtrim(educ_clean)
                replace educ_clean = subinstr(educ_clean, ".", "", .)
                
                capture destring educ_clean, gen(educ_num) force
                
                if _rc == 0 {
                    replace nivel_estandar = 0 if educ_num == 0
                    replace nivel_estandar = 1 if inlist(educ_num, 1, 2)
                    replace nivel_estandar = 2 if inlist(educ_num, 3, 4, 5, 6)
                    replace nivel_estandar = 3 if inlist(educ_num, 7, 8)
                    replace nivel_estandar = 9 if inlist(educ_num, 9, 99)
                    drop educ_num
                }
                else {
                    gen educ_num2 = real(regexs(0)) if regexm(educ_clean, "([0-9]+)")
                    replace nivel_estandar = 0 if educ_num2 == 0
                    replace nivel_estandar = 1 if inlist(educ_num2, 1, 2)
                    replace nivel_estandar = 2 if inlist(educ_num2, 3, 4, 5, 6)
                    replace nivel_estandar = 3 if inlist(educ_num2, 7, 8)
                    replace nivel_estandar = 9 if inlist(educ_num2, 9, 99)
                    drop educ_num2
                }
                drop educ_clean
            }
        }
        
        *--- 5.2 PERÍODO 2011-2024 ---*
        if `anio' >= 2011 {
            
            capture confirm string variable `educ_var'
            if _rc != 0 {
                tostring `educ_var', replace force
            }
            
            replace nivel_estandar = 0 if inlist(`educ_var', "0", "00")
            replace nivel_estandar = 1 if inlist(`educ_var', "1", "01", "2", "02")
            replace nivel_estandar = 2 if inlist(`educ_var', "3", "03", "4", "04", "5", "05", "6", "06")
            replace nivel_estandar = 3 if inlist(`educ_var', "7", "07", "8", "08")
            replace nivel_estandar = 9 if inlist(`educ_var', "9", "09", "99")
        }
    }
    
    *--- 6. CORRECCIÓN ESPECIAL PARA 2011 (si es necesario) ---*
    * Nota: En caso de que 2011 tenga problemas similares a defunciones,
    * podemos agregar un diagnóstico aquí
    
    *--- 7. ETIQUETAR ---*
    label define nivel_lbl 0 "Sin instrucción" 1 "Primaria" 2 "Secundaria" 3 "Superior" 9 "No especificado"
    label values nivel_estandar nivel_lbl
    
    *--- 8. CREAR VARIABLE AGRUPADA PARA GRÁFICOS ---*
    gen nivel_graf = ""
    replace nivel_graf = "Hasta secundaria" if inlist(nivel_estandar, 0, 1, 2)
    replace nivel_graf = "Superior" if nivel_estandar == 3
    replace nivel_graf = "No especificado" if nivel_estandar == 9
    
    *--- 9. VERIFICAR ARMONIZACIÓN ---*
    di "=== RESULTADO ARMONIZACIÓN `anio' ==="
    tab nivel_estandar, missing
    tab nivel_graf, missing
    
    *--- 10. CONTAR ---*
    count
    local total_nv = r(N)
    
    count if nivel_estandar == 0
    local nv_sin_inst = r(N)
    count if nivel_estandar == 1
    local nv_primaria = r(N)
    count if nivel_estandar == 2
    local nv_secundaria = r(N)
    count if nivel_estandar == 3
    local nv_superior = r(N)
    count if nivel_estandar == 9
    local nv_no_espec = r(N)
    count if missing(nivel_estandar)
    local nv_sin_educ = r(N)
    
    * Contar por grupo para gráficos
    count if nivel_graf == "Hasta secundaria"
    local nv_hasta_sec = r(N)
    
    count if nivel_graf == "Superior"
    local nv_superior_graf = r(N)
    
    di "Año `anio': Total NV = `total_nv'"
    di "  Sin instrucción: `nv_sin_inst'"
    di "  Primaria: `nv_primaria'"
    di "  Secundaria: `nv_secundaria'"
    di "  Superior: `nv_superior'"
    di "  No especificado: `nv_no_espec'"
    di "  Sin dato educación: `nv_sin_educ'"
    di "  --- Para gráficos ---"
    di "  Hasta secundaria: `nv_hasta_sec'"
    di "  Superior: `nv_superior_graf'"
    
    *--- 11. GUARDAR ---*
    clear
    set obs 1
    gen anio = `anio'
    gen nv_total = `total_nv'
    gen nv_sin_instruccion = `nv_sin_inst'
    gen nv_primaria = `nv_primaria'
    gen nv_secundaria = `nv_secundaria'
    gen nv_superior = `nv_superior'
    gen nv_no_especificado = `nv_no_espec'
    gen nv_sin_educacion = `nv_sin_educ'
    
    * Variables para gráficos
    gen nv_hasta_secundaria = `nv_hasta_sec'
    gen nv_superior_graf = `nv_superior_graf'
    
    capture confirm file `acumulado_nacimientos'
    if _rc != 0 save `acumulado_nacimientos', emptyok
    else {
        append using `acumulado_nacimientos'
        save `acumulado_nacimientos', replace
    }
}

*--- 12. GUARDAR BASE FINAL ---*
capture confirm file `acumulado_nacimientos'
if _rc == 0 {
    use `acumulado_nacimientos', clear
    sort anio
    
    di _n(3) "=== AÑOS PROCESADOS ==="
    list anio nv_total nv_hasta_secundaria nv_superior_graf, sep(10)
    
    save "${output_dir}nacidos_vivos_1990_2024.dta", replace
    export excel using "${output_dir}nacidos_vivos_1990_2024.xlsx", firstrow(var) replace
    
    di _n(3) "=== PROCESO COMPLETADO ==="
    di "Base guardada: ${output_dir}nacidos_vivos_1990_2024.dta"
    di "Variables incluidas:"
    di "  - nv_total: Total nacidos vivos"
    di "  - nv_sin_instruccion / primaria / secundaria / superior / no_especificado"
    di "  - nv_hasta_secundaria: Para gráficos (hasta secundaria)"
    di "  - nv_superior_graf: Para gráficos (superior)"
}
else {
    di "ERROR: No se procesó ningún año"
}




/*******************************************************************************
CALCULAR RMM ECUADOR 1990-2024 (FINAL) - VERSIÓN CORREGIDA
*******************************************************************************/

clear all
set more off

global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

*--- 1. CARGAR NUMERADOR (defunciones) ---*
* Primero unimos las partes de defunciones si no lo hicimos
capture confirm file "${output_dir}numerador_rmm_1990_2024_FINAL.dta"
if _rc != 0 {
    * Unir CIE-9 y CIE-10
    use "${output_dir}numerador_rmm_1990_1996_CLASIFICADO.dta", clear
    append using "${output_dir}numerador_rmm_1997_2024_COMPLETO.dta"
    sort anio
    save "${output_dir}numerador_rmm_1990_2024_FINAL.dta", replace
}

use "${output_dir}numerador_rmm_1990_2024_FINAL.dta", clear
sort anio
save temp_mm, replace

*--- 2. CARGAR DENOMINADOR (nacidos vivos) ---*
use "${output_dir}nacidos_vivos_1990_2024.dta", clear
sort anio

*--- 3. COMBINAR ---*
merge 1:1 anio using temp_mm

* Verificar merge
tab _merge
drop _merge

*--- 4. CALCULAR RMM GENERAL ---*
gen rmm_general = (mm_total / nv_total) * 100000
format rmm_general %9.2f

*--- 5. CALCULAR RMM POR TIPO ---*
gen rmm_directas = (mm_directas / nv_total) * 100000
gen rmm_indirectas = (mm_indirectas / nv_total) * 100000
gen rmm_covid = (mm_covid / nv_total) * 100000
gen rmm_no_especificadas = (mm_no_especificadas / nv_total) * 100000
format rmm_* %9.2f

*--- 6. CALCULAR RMM POR NIVEL EDUCATIVO (usando nv_total como denominador) ---*
* Esto mide la CONTRIBUCIÓN de cada grupo a la RMM general
gen rmm_sin_instruccion = (mm_sin_instruccion / nv_total) * 100000
gen rmm_primaria = (mm_primaria / nv_total) * 100000
gen rmm_secundaria = (mm_secundaria / nv_total) * 100000
gen rmm_superior = (mm_superior / nv_total) * 100000
gen rmm_no_especificado_educ = (mm_no_especificado_educ / nv_total) * 100000
format rmm_* %9.2f

*--- 7. CALCULAR RMM POR GRUPO EDUCATIVO (para gráficos - también con nv_total) ---*
gen rmm_hasta_secundaria = ((mm_sin_instruccion + mm_primaria + mm_secundaria) / nv_total) * 100000
gen rmm_superior_graf = (mm_superior / nv_total) * 100000
format rmm_hasta_secundaria rmm_superior_graf %9.2f

*--- 8. GUARDAR BASE FINAL ---*
sort anio
save "${output_dir}rmm_ecuador_1990_2024_FINAL.dta", replace
export excel using "${output_dir}rmm_ecuador_1990_2024_FINAL.xlsx", firstrow(var) replace

*--- 9. MOSTRAR RESULTADOS ---*
list anio mm_total nv_total rmm_general, sep(5)

*--- 10. GRÁFICO 1: RMM General ---*
twoway (line rmm_general anio, lwidth(medium) lcolor(red)), ///
    title("Razón de Mortalidad Materna - Ecuador 1990-2024") ///
    ytitle("RMM (por 100,000 nacidos vivos)") xtitle("Año") ///
    xlabel(1990(5)2024) graphregion(color(white))
    
graph export "${output_dir}grafico_rmm_general.png", replace

*--- 11. GRÁFICO 2: RMM por tipo (Directas vs Indirectas vs COVID) ---*
twoway (line rmm_directas anio, lcolor(blue)) ///
       (line rmm_indirectas anio, lcolor(green)) ///
       (line rmm_covid anio, lcolor(red)), ///
    title("RMM por Tipo - Ecuador 1990-2024") ///
    ytitle("RMM (por 100,000 nacidos vivos)") xtitle("Año") ///
    legend(label(1 "Directas") label(2 "Indirectas") label(3 "COVID-19")) ///
    xlabel(1990(5)2024) graphregion(color(white))
    
graph export "${output_dir}grafico_rmm_por_tipo.png", replace

*--- 12. GRÁFICO 3: RMM por nivel educativo (Hasta secundaria vs Superior) ---*
twoway (line rmm_hasta_secundaria anio, lcolor(blue)) ///
       (line rmm_superior_graf anio, lcolor(green)), ///
    title("Razón de Mortalidad Materna por Nivel Educativo - Ecuador 1990-2024") ///
    subtitle("(Contribución a la RMM general por nivel educativo de la madre)") ///
    ytitle("RMM (por 100,000 nacidos vivos)") xtitle("Año") ///
    legend(label(1 "Hasta secundaria") label(2 "Superior")) ///
    xlabel(1990(5)2024) graphregion(color(white)) ///
    note("Nota: Muestra cuántas muertes de cada grupo aportan a la RMM general. No es tasa específica del grupo.")
    
graph export "${output_dir}grafico_rmm_educacion.png", replace

*--- 13. ESTADÍSTICAS DESCRIPTIVAS ---*
di _n(3) "=== ESTADÍSTICAS RMM GENERAL ==="
summarize rmm_general, detail

di _n(3) "=== RMM PROMEDIO POR DÉCADA ==="
gen decada = floor(anio/10)*10
tabstat rmm_general, by(decada) statistics(mean min max)

di _n(3) "=== PROCESO COMPLETO ==="
di "Archivos generados:"
di "1. ${output_dir}rmm_ecuador_1990_2024_FINAL.dta"
di "2. ${output_dir}rmm_ecuador_1990_2024_FINAL.xlsx"
di "3. ${output_dir}grafico_rmm_general.png"
di "4. ${output_dir}grafico_rmm_por_tipo.png"
di "5. ${output_dir}grafico_rmm_educacion.png"


*--- GRÁFICO 1: RMM General (años en 45°) ---*
twoway (line rmm_general anio, lwidth(thick) lcolor(red)), ///
    title("Razón de Mortalidad Materna", size(medium)) ///
    subtitle("Ecuador 1990-2024", size(small)) ///
    ytitle("RMM (por 100,000 nacidos vivos)", size(small)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(2)2024, labsize(small) angle(45)) ///  <- Cada 2 años, incluyendo 2024, a 45°
    ylabel(0(50)400, labsize(small) format(%9.0f)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(color(white)) ///
    note("Fuente: INEC - Estadísticas Vitales. Elaboración propia.", size(vsmall))
    
graph export "${output_dir}grafico_rmm_general_45grados.png", replace width(1300) height(800)


*--- GRÁFICO 2: RMM por Tipo (todos los años, con nota clara) ---*
twoway (line rmm_directas anio, lwidth(thick) lcolor(blue)) ///
       (line rmm_indirectas anio, lwidth(thick) lcolor(green)) ///
       (line rmm_covid anio, lwidth(vthin) lcolor(gray) lpattern(dash)), ///
    title("Razón de Mortalidad Materna por Tipo", size(medium)) ///
    subtitle("Ecuador 1990-2024", size(small)) ///
    ytitle("RMM (por 100,000 nacidos vivos)", size(small)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(2)2024, labsize(vsmall) angle(45)) ///
    ylabel(0(20)120, labsize(small) format(%9.0f)) ///
    legend(label(1 "Directas") label(2 "Indirectas") label(3 "COVID-19") ///
           size(small) position(11) ring(0) cols(1)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(color(white) margin(small)) ///
    note("Definiciones: " ///
         "{bf:Directas}: Muertes por complicaciones obstétricas del embarazo, parto o puerperio " ///
         "(ej. hemorragias, infecciones, aborto). " ///
         "{bf:Indirectas}: Muertes por enfermedades preexistentes o que aparecen en el embarazo " ///
         "y se agravan por él (ej. cardiopatías, hipertensión crónica, diabetes). " ///
         "{bf:COVID-19}: Muertes por COVID-19 en mujeres gestantes (clasificadas como indirectas por norma INEC). " ///
         "Fuente: INEC - Estadísticas Vitales. Elaboración propia.", size(vsmall))
    
graph export "${output_dir}grafico_rmm_por_tipo_final.png", replace width(1300) height(800)


*--- GRÁFICO 3: RMM por Nivel Educativo (estilo final) ---*
twoway (line rmm_hasta_secundaria anio, lwidth(thick) lcolor(blue)) ///
       (line rmm_superior_graf anio, lwidth(thick) lcolor(green)), ///
    title("Razón de Mortalidad Materna por Nivel Educativo", size(medium)) ///
    subtitle("Contribución a la RMM general - Ecuador 1990-2024", size(small)) ///
    ytitle("RMM (por 100,000 nacidos vivos)", size(small)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(2)2024, labsize(vsmall) angle(45)) ///
    ylabel(0(10)80, labsize(small) format(%9.0f)) ///
    legend(label(1 "Hasta secundaria") label(2 "Superior") ///
           size(small) position(11) ring(0) cols(1)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(color(white) margin(small)) ///
    note("Nota: Las líneas muestran la {bf:contribución} de cada grupo educativo a la RMM general. " ///
         "No representan el riesgo específico del grupo (para ello se necesitaría el total de nacidos vivos " ///
         "de madres con ese nivel, el cual no está disponible para todos los años). " ///
         "Fuente: INEC - Estadísticas Vitales. Elaboración propia.", size(vsmall))
    
graph export "${output_dir}grafico_rmm_educacion_final.png", replace width(1300) height(800)





/*******************************************************************************
PROGRAMA COMPLETO: Tasa de Mortalidad Infantil (TMI) - Ecuador 1990-2024
INCLUYE:
  - Procesamiento de defunciones de menores de 1 año
  - Armonización de edad (8 períodos diferentes)
  - Cálculo de TMI general (exacta)
  - Cálculo de TMI por educación (proxy)
  - Gráficos finales
*******************************************************************************/

clear all
set more off
set maxvar 32767

*=== DIRECTORIOS ===*
global input_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\Defunciones\"
global output_dir "C:\Users\Wilson\Documents\GitHub\Observatorio-Desigualdad-Pobreza\Boletín 2\Procesamiento\Bases\"

*===============================================================================
* PARTE 1: DEFINIR FUNCIÓN DE ARMONIZACIÓN DE EDAD
*===============================================================================

capture program drop armonizar_edad
program define armonizar_edad
    syntax, anio(integer)
    
    *--- 1. DETECTAR PERÍODO Y SISTEMA ---*
    if `anio' <= 2002 {
        * PERÍODO 1990-2002: EDAD combinada
        di "✓ Usando sistema 1990-2002 (EDAD combinada)"
        
        * Calcular edad en años
        gen edad_anios = .
        replace edad_anios = 0 if edad == 1                          // Horas -> 0 años
        replace edad_anios = (edad - 2) / 365 if edad == 2           // Días
        replace edad_anios = (edad - 3) / 12 if edad == 3            // Meses
        replace edad_anios = edad - 1 if inrange(edad, 4, 98)        // Años
        * ignorados (99) quedan como missing
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if `anio' == 2003 {
        * PERÍODO 2003: Dual (CODI + EDAD) o EDAD antigua
        di "✓ Usando sistema 2003 (Dual)"
        
        capture confirm variable codi
        if _rc == 0 {
            * Usar sistema nuevo
            gen edad_anios = .
            replace edad_anios = 0 if codi == 1
            replace edad_anios = edad / 365 if codi == 2
            replace edad_anios = edad / 12 if codi == 3
            replace edad_anios = edad - 1 if codi == 4
        }
        else {
            * Fallback al sistema antiguo
            gen edad_anios = .
            replace edad_anios = 0 if edad == 1
            replace edad_anios = (edad - 2) / 365 if edad == 2
            replace edad_anios = (edad - 3) / 12 if edad == 3
            replace edad_anios = edad - 1 if inrange(edad, 4, 98)
        }
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if inrange(`anio', 2004, 2007) {
        * PERÍODO 2004-2007: CODI (numérico) + EDAD
        di "✓ Usando sistema 2004-2007 (CODI + EDAD)"
        
        gen edad_anios = .
        replace edad_anios = 0 if codi == 1
        replace edad_anios = edad / 365 if codi == 2
        replace edad_anios = edad / 12 if codi == 3
        replace edad_anios = edad - 1 if codi == 4
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if inrange(`anio', 2008, 2009) {
        * PERÍODO 2008-2009: COD_EDA + EDAD
        di "✓ Usando sistema 2008-2009 (COD_EDA + EDAD)"
        
        gen edad_anios = .
        replace edad_anios = 0 if cod_eda == 1
        replace edad_anios = edad / 365 if cod_eda == 2
        replace edad_anios = edad / 12 if cod_eda == 3
        replace edad_anios = edad - 1 if cod_eda == 4
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if `anio' == 2010 {
        * PERÍODO 2010: cod_eda (numérico) + edad
        di "✓ Usando sistema 2010 (cod_eda + edad)"
        
        gen edad_anios = .
        replace edad_anios = 0 if cod_eda == 1
        replace edad_anios = edad / 365 if cod_eda == 2
        replace edad_anios = edad / 12 if cod_eda == 3
        replace edad_anios = edad - 1 if cod_eda == 4
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if `anio' == 2011 {
        * PERÍODO 2011: cod_edad (string) + edad (numérica)
        di "✓ Usando sistema 2011 (cod_edad string + edad)"
        
        gen edad_anios = .
        replace edad_anios = 0 if cod_edad == "01"
        replace edad_anios = edad / 365 if cod_edad == "02"
        replace edad_anios = edad / 12 if cod_edad == "03"
        replace edad_anios = edad - 1 if cod_edad == "04"
        
        gen menor_1_anio = (edad_anios < 1 & edad_anios != .)
    }
    
    if `anio' >= 2012 {
        * PERÍODO 2012-2024: FECHAS EXACTAS
        di "✓ Usando sistema 2012-2024 (Fechas exactas)"
        
        * Convertir strings a fecha si es necesario
        capture confirm string variable fecha_nac
        if _rc == 0 {
            gen fecha_nac_date = date(fecha_nac, "YMD")
            gen fecha_fall_date = date(fecha_fall, "YMD")
            format fecha_nac_date fecha_fall_date %td
        }
        else {
            clonevar fecha_nac_date = fecha_nac
            clonevar fecha_fall_date = fecha_fall
        }
        
        * Calcular edad exacta en días
        gen edad_dias = fecha_fall_date - fecha_nac_date
        gen edad_anios = edad_dias / 365.25
        
        gen menor_1_anio = (edad_dias < 365)
    }
end

*===============================================================================
* PARTE 2: PROCESAR DEFUNCIONES DE MENORES DE 1 AÑO (1990-2024)
*===============================================================================

tempfile acumulado_tmi

forvalues anio = 1990/2024 {
    
    di _n(3) "=== PROCESANDO DEFUNCIONES `anio' (menores de 1 año) ==="
    
    *--- 2.1 IMPORTAR BASE ---*
    local archivo = "${input_dir}EDG_`anio'.sav"
    
    capture confirm file "`archivo'"
    if _rc != 0 {
        di "Archivo no encontrado. Continuando."
        continue
    }
    
    capture import spss using "`archivo'", clear
    if _rc != 0 {
        capture usespss using "`archivo'", clear
        if _rc != 0 {
            di "ERROR: No se pudo importar"
            continue
        }
    }
    
    rename *, lower
    di "✓ Archivo leído: _N observaciones"
    
    *--- 2.2 ARMONIZAR EDAD ---*
    armonizar_edad, anio(`anio')
    
    *--- 2.3 CONTAR DEFUNCIONES DE MENORES DE 1 AÑO ---*
    count if menor_1_anio == 1
    local tmi_total = r(N)
    
    * Nota: La educación de la madre NO está en esta base
    * Solo guardamos totales, la desagregación por educación se hará después con proxy
    
    di "Año `anio': Total defunciones <1 año = `tmi_total'"
    
    *--- 2.4 GUARDAR EN BASE ACUMULADA ---*
    clear
    set obs 1
    gen anio = `anio'
    gen tmi_total = `tmi_total'
    
    capture confirm file `acumulado_tmi'
    if _rc != 0 save `acumulado_tmi', emptyok
    else {
        append using `acumulado_tmi'
        save `acumulado_tmi', replace
    }
}

*--- 2.5 GUARDAR BASE DE DEFUNCIONES INFANTILES ---*
capture confirm file `acumulado_tmi'
if _rc == 0 {
    use `acumulado_tmi', clear
    sort anio
    save "${output_dir}defunciones_infantiles_1990_2024.dta", replace
    export excel using "${output_dir}defunciones_infantiles_1990_2024.xlsx", firstrow(var) replace
    
    list anio tmi_total, sep(5)
}

di _n(3) "=== PARTE 2 COMPLETADA: Defunciones infantiles 1990-2024 ==="

*===============================================================================
* PARTE 3: CARGAR NACIDOS VIVOS
*===============================================================================

capture confirm file "${output_dir}nacidos_vivos_1990_2024.dta"
if _rc != 0 {
    di "Error: No se encuentra nacidos_vivos_1990_2024.dta"
    di "Primero debes ejecutar el procesamiento de nacidos vivos"
    exit
}

use "${output_dir}nacidos_vivos_1990_2024.dta", clear
sort anio
save temp_nv, replace

*===============================================================================
* PARTE 4: COMBINAR Y CALCULAR TMI
*===============================================================================

*--- 4.1 Cargar defunciones infantiles ---*
use "${output_dir}defunciones_infantiles_1990_2024.dta", clear
sort anio

*--- 4.2 Combinar con nacidos vivos ---*
merge 1:1 anio using temp_nv
tab _merge
drop _merge

*--- 4.3 TMI general (exacta) ---*
gen tmi_general = (tmi_total / nv_total) * 1000
format tmi_general %9.2f

*--- 4.4 Calcular proxy de TMI por nivel educativo ---*
* Proporciones de nacidos vivos
gen prop_sin_inst = nv_sin_instruccion / nv_total
gen prop_primaria = nv_primaria / nv_total
gen prop_secundaria = nv_secundaria / nv_total
gen prop_superior = nv_superior / nv_total
gen prop_no_espec = nv_no_especificado / nv_total

* TMI proxy por nivel
gen tmi_sin_inst_proxy = (tmi_total * prop_sin_inst / nv_sin_instruccion) * 1000
gen tmi_primaria_proxy = (tmi_total * prop_primaria / nv_primaria) * 1000
gen tmi_secundaria_proxy = (tmi_total * prop_secundaria / nv_secundaria) * 1000
gen tmi_superior_proxy = (tmi_total * prop_superior / nv_superior) * 1000
gen tmi_no_espec_proxy = (tmi_total * prop_no_espec / nv_no_especificado) * 1000

* Agrupar para gráficos
gen tmi_hasta_sec_proxy = tmi_sin_inst_proxy + tmi_primaria_proxy + tmi_secundaria_proxy
gen tmi_superior_proxy_graf = tmi_superior_proxy

format tmi_*_proxy %9.2f

*===============================================================================
* PARTE 5: GRÁFICOS
*===============================================================================

*--- 5.1 GRÁFICO 1: TMI General ---*
twoway (line tmi_general anio, lwidth(thick) lcolor(red)), ///
    title("Tasa de Mortalidad Infantil", size(medium)) ///
    subtitle("Ecuador 1990-2024", size(small)) ///
    ytitle("TMI (por 1,000 nacidos vivos)", size(small)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(2)2024, labsize(vsmall) angle(45)) ///
    ylabel(0(10)60, labsize(small) format(%9.0f)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(color(white)) ///
    note("Fuente: INEC - Estadísticas Vitales. Elaboración propia.", size(vsmall))
    
graph export "${output_dir}grafico_tmi_general.png", replace width(1300) height(800)

*--- 5.2 GRÁFICO 2: TMI por Nivel Educativo (PROXY) ---*
twoway (line tmi_hasta_sec_proxy anio, lwidth(thick) lcolor(blue)) ///
       (line tmi_superior_proxy_graf anio, lwidth(thick) lcolor(green)), ///
    title("Tasa de Mortalidad Infantil por Nivel Educativo (PROXY)", size(medium)) ///
    subtitle("Ecuador 1990-2024 - Basado en distribución de nacidos vivos", size(small)) ///
    ytitle("TMI (por 1,000 nacidos vivos)", size(small)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(2)2024, labsize(vsmall) angle(45)) ///
    ylabel(0(10)60, labsize(small) format(%9.0f)) ///
    legend(label(1 "Hasta secundaria") label(2 "Superior") ///
           size(small) position(11) ring(0) cols(1)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(color(white)) ///
    note("Nota: Estimación proxy asumiendo que la distribución educativa de las defunciones infantiles " ///
         "es similar a la de los nacidos vivos. No es una tasa exacta. " ///
         "Fuente: INEC - Estadísticas Vitales. Elaboración propia.", size(vsmall))
    
graph export "${output_dir}grafico_tmi_educacion_proxy.png", replace width(1300) height(800)

*===============================================================================
* PARTE 6: GUARDAR BASE FINAL
*===============================================================================

sort anio
save "${output_dir}tmi_ecuador_1990_2024_COMPLETA.dta", replace
export excel using "${output_dir}tmi_ecuador_1990_2024_COMPLETA.xlsx", firstrow(var) replace

*--- MOSTRAR RESUMEN ---*
di _n(3) "=== RESUMEN FINAL 1990-2024 ==="
list anio tmi_general tmi_hasta_sec_proxy tmi_superior_proxy_graf in 1/35

di _n(3) "=== PROCESO COMPLETADO ==="
di "Archivos generados:"
di "1. ${output_dir}defunciones_infantiles_1990_2024.dta"
di "2. ${output_dir}tmi_ecuador_1990_2024_COMPLETA.dta"
di "3. ${output_dir}grafico_tmi_general.png"
di "4. ${output_dir}grafico_tmi_educacion_proxy.png"






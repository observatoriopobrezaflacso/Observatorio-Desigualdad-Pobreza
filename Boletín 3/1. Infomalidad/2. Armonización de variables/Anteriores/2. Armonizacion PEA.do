* PEA armonizada	

* ======================================================================
* 0. CONFIGURACIÓN INICIAL Y RUTAS
* ======================================================================
clear all
set more off

global origen  "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases opcion 1"
global destino "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases_Clasificadas_PEA"

capture mkdir "$destino"

* ======================================================================
* 1. BUCLE DE PROCESAMIENTO CON TABLAS DE VALORES ABSOLUTOS
* ======================================================================
forvalues anio_loop = 1990/2024 {
    
    capture use "$origen\empleo`anio_loop'.dta", clear
    if _rc != 0 {
        display "⚠️ Archivo empleo`anio_loop'.dta no encontrado. Saltando..."
        continue
    }

    * --- A. PROCESAMIENTO SILENCIOSO ---
    quietly {
        capture rename p03 edad
        drop if edad < 15
        capture rename anio_encuesta anio
        capture rename periodo anio

        * Condición de Actividad
        capture confirm variable condactn
        if _rc == 0 local v_cond "condactn"
        else {
            capture confirm variable condact
            if _rc == 0 local v_cond "condact"
            else local v_cond ""
        }

        * Sectorización
        local v_sect ""
        foreach v in peamsiu SECEMP secemp {
            capture confirm variable `v'
            if _rc == 0 {
                local v_sect "`v'"
                continue, break
            }
        }

        * Creación de PEA
        if "`v_cond'" != "" {
            capture drop mi_pea
            gen mi_pea = 0
            if `anio_loop' <= 2013 replace mi_pea = 1 if inrange(`v_cond', 0, 6)
            else               replace mi_pea = 1 if inrange(`v_cond', 1, 8)
            
            label define lpea 1 "PEA" 0 "Inactivo", replace
            label values mi_pea lpea
        }
        
        gen sector_armonizado = .
        if "`v_sect'" != "" replace sector_armonizado = `v_sect'
    }

    * --- B. REPORTE VISIBLE (SOLO VALORES) ---
    display _dup(80) "="
    display "📊 VALORES ABSOLUTOS (EXPANDIDOS) - AÑO: `anio_loop'"
    display _dup(80) "-"
    
    * Tabla 1: Cruce de Condición de Actividad vs Nuestra PEA
    display "1. Población por Condición de Actividad (Expandida):"
    tab `v_cond' mi_pea [iw=fexp], missing
    
    * Tabla 2: Cruce de nuestra PEA con Sector
    if "`v_sect'" != "" {
        display "2. Distribución de la PEA por Sector (`v_sect'):"
        tab mi_pea `v_sect' [iw=fexp], missing
    }
    else {
        display "❌ No se detectó variable de sector en este año."
    }

    * --- C. GUARDADO ---
    quietly {
        capture confirm variable id_persona
        if _rc == 0 {
            keep id_persona anio mi_pea sector_armonizado fexp
            save "$destino\clasif_`anio_loop'.dta", replace
            local guardado "SÍ"
        }
        else local guardado "NO"
    }
    
    if "`guardado'" == "SÍ" display "✅ Base espejo guardada con éxito."
    display ""
}

use "$destino/Serie_PEA_Consolidada_90_24", clear
tab anio mi_pea, nofreq row
* ======================================================================
* 2. CONSOLIDACIÓN Y GRÁFICO FINAL
* ======================================================================
* 1. Consolidación (Excluyendo 2002)
clear
forvalues a = 1990/2024 {
    if `a' != 2002 {
        quietly capture append using "$destino\clasif_`a'.dta"
    }
}

* 2. GENERAR LA DICOTÓMICA (Método infalible)
* Primero, convertimos la variable a texto para estandarizar
decode mi_pea, gen(mi_pea_txt)

* Creamos la dicotómica buscando la palabra PEA (sin importar espacios o mayúsculas)
gen es_pea = 0
replace es_pea = 1 if strupper(strtrim(mi_pea_txt)) == "PEA"
replace es_pea = . if missing(mi_pea) // Mantener los missing como missing

* 3. COLAPSAR (PROMEDIO PONDERADO)
preserve
    collapse (mean) es_pea [iw=fexp] if anio != 2002, by(anio)
    
    * Aquí multiplicamos por 100 para que coincida con tu tabla (61.08, etc.)
    replace es_pea = es_pea * 100
    
    * VERIFICACIÓN: Si esto sale vacío en la consola, la dicotómica falló
    list anio es_pea in 1/10

    * 4. GRÁFICO
    twoway (line es_pea anio, lcolor(navy) lwidth(medthick) msize(small) msymbol(circle)), ///
        title("Evolución de la Tasa de Participación (PEA)") ///
        ytitle("Porcentaje (%)") xtitle("Año") ///
        xlabel(1990(2)2024, angle(45) grid) ///
        ylabel(0(10)100, grid) ///
        note("Fuente: ENEMDU. Excluye 2002.") ///
        graphregion(color(white))

    graph export "$destino\Grafico_PEA.png", replace
restore
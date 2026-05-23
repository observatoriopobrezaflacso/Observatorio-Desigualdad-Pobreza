* ======================================================================
* PROCESAMIENTO: EMPLEADOS Y DESEMPLEADOS (ARMONIZADO 1990-2024)
* ======================================================================
clear all
set more off

global origen  "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases opcion 1"
global destino "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases_Clasificadas_Mercado"

capture mkdir "$destino"

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

        * 1. Identificar variable de condición de actividad
        capture confirm variable condactn
        if _rc == 0 local v_cond "condactn"
        else {
            capture confirm variable condact
            if _rc == 0 local v_cond "condact"
            else local v_cond ""
        }

        * 2. Creación de Categorías Armonizadas
        if "`v_cond'" != "" {
            capture drop mercado_laboral
            gen mercado_laboral = .
            
            * Lógica PRE-2014 (Incluye el valor 0 de 1990)
            if `anio_loop' <= 2013 {
                replace mercado_laboral = 1 if inrange(`v_cond', 0, 4) // Empleados
                replace mercado_laboral = 0 if inrange(`v_cond', 5, 6) // Desempleados
            }
            * Lógica POST-2014 (Nueva Metodología)
            else {
                replace mercado_laboral = 1 if inrange(`v_cond', 0, 3) // Empleados
                replace mercado_laboral = 0 if inrange(`v_cond', 5, 6) // Desempleados
            }
            
            label define lmercado 1 "Empleado" 2 "Desempleado", replace
            label values mercado_laboral lmercado
        }
    }

	
    * --- B. REPORTE DE VALIDACIÓN ---
    display _dup(80) "="
    display "📊 MERCADO LABORAL (VALORES ABSOLUTOS) - AÑO: `anio_loop'"
    display _dup(80) "-"
    
    if "`v_cond'" != "" {
        display "Cruce: Variable INEC (`v_cond') vs Nuestra Clasificación:"
        tab `v_cond' mercado_laboral [iw=fexp], missing
    }
    else {
        display "❌ Error: No se encontró variable de condición de actividad."
    }

    * --- C. GUARDADO DE BASE ESPEJO ---
    quietly {
        capture confirm variable id_persona
        if _rc == 0 {
            keep id_persona anio mercado_laboral fexp
            save "$destino\mercado_`anio_loop'.dta", replace
            local guardado "SÍ"
        }
        else local guardado "NO"
    }
    
    if "`guardado'" == "SÍ" display "✅ Base espejo guardada con éxito."
}

* ======================================================================
* 2. CONSOLIDACIÓN Y GRÁFICO DE TENDENCIA
* ======================================================================
* --- CORRECCIÓN DEL CÁLCULO ---
use "$destino\Serie_Mercado_Consolidada_90_24.dta", clear

* 1. Colapsar asegurándonos de que SOLO tomamos a los que están en el mercado (PEA)
collapse (sum) fexp if anio != 2002 & (mercado_laboral == 0 | mercado_laboral == 1), by(anio mercado_laboral)

* 2. Calcular el total de la PEA por año (Denominador correcto)
bysort anio: egen total_pea = sum(fexp)

* 3. Generar la participación REAL sobre la PEA
gen participacion = (fexp / total_pea) * 100

* --- 4. GRAFICAR ---
twoway (line participacion anio if mercado_laboral == 1, lcolor(navy) lwidth(medthick) lpattern(solid)) ///
       (line participacion anio if mercado_laboral == 0, lcolor(cranberry) lwidth(medthick) lpattern(solid)), ///
    title("Composición del Mercado Laboral (1990-2024)") ///
    subtitle("Participación porcentual sobre la PEA (Tasa de Empleo y Desempleo)") ///
    xtitle("Año") ytitle("Porcentaje (%)") ///
    ylabel(0(10)100, grid gstyle(dot)) ///
    xlabel(1990(2)2024, angle(45) labsize(vsmall)) ///
    legend(label(1 "Empleados") label(2 "Desempleados")) ///
    graphregion(color(white))

graph export "$destino\Grafico_Estructura_Mercado_PEA.png", as(png) replace width(1800)
display "🏁 ¡GRÁFICO GUARDADO! Lo puedes encontrar en: $destino"


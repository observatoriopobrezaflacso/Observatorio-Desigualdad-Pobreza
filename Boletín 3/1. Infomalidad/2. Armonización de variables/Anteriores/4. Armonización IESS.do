* ======================================================================
* ARMONIZACIÓN ESTRICTA: SEGURIDAD SOCIAL (IESS) 1990-2024
* ======================================================================
clear all
set more off

* RUTAS
global origen  "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases opcion 1"
global destino "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases_Procesadas_IESS"

capture mkdir "$destino"

forvalues anio_loop = 1990/2024 {
    
    capture use "$origen\empleo`anio_loop'.dta", clear
    if _rc != 0 {
        display "⚠️ Archivo de `anio_loop' no encontrado."
        continue
    }

    * --- 1. LIMPIEZA INICIAL ---
    quietly {
        capture rename p03 edad
        drop if edad < 15
        capture rename anio_encuesta anio
        capture rename periodo anio
        * Asegurar que anio tenga el valor del loop si no existe
        capture gen anio = `anio_loop' if anio == .
    }

    * --- 2. APLICACIÓN DE REGLA ESTRICTA (LÓGICA PYTHON) ---
    quietly {
        capture drop col_iess
        gen col_iess = 0 

        * Periodo A: 1990 - 2000 (cods_iess = [1])
        if `anio_loop' <= 2000 {
            capture confirm variable iess
            if _rc == 0 replace col_iess = 1 if iess == 1
        }

        * Periodo B: 2001 - 2006 (cods_iess = [2])
        else if inrange(`anio_loop', 2001, 2006) {
            capture confirm variable iess
            if _rc == 0 replace col_iess = 1 if iess == 2
        }

        * Periodo C: 2007 - 2024 (cods_iess = [1])
        else if `anio_loop' >= 2007 {
            * Buscamos en p05a que es el estándar moderno para Seguro General
            capture confirm variable p05a
            if _rc == 0 replace col_iess = 1 if p05a == 1
        }
        
        label define liess 1 "Con IESS" 0 "Sin IESS", replace
        label values col_iess liess
    }

    * --- 3. REPORTE Y GUARDADO ---
    display "--------------------------------------------------------"
    display "📊 Reporte IESS `anio_loop' (Solo >= 15 años)"
    tab col_iess [iw=fexp], missing
    
    quietly {
        capture confirm variable id_persona
        if _rc == 0 {
            * Rescatamos solo las variables clave solicitadas
            keep id_persona anio col_iess fexp
            save "$destino\iess_`anio_loop'.dta", replace
            local edo "OK"
        }
        else local edo "ERROR (Sin ID)"
    }
    
    display "✅ Estado: `edo'"
}

* --- CONSOLIDACIÓN ---
clear
display "🚀 Uniendo serie histórica de IESS..."
forvalues a = 1990/2024 {
    quietly capture append using "$destino\iess_`a'.dta"
}
if _N > 0 {
    save "$destino\Serie_IESS_90_24.dta", replace
    display "🏁 Archivo 'Serie_IESS_90_24.dta' generado con éxito."
}




* ======================================================================
* 2. CONSOLIDACIÓN Y GRÁFICO DE TENDENCIA DE SEGURIDAD SOCIAL
* ======================================================================
clear
display "🚀 Consolidando serie de Seguridad Social..."

forvalues a = 1990/2024 {
    quietly capture append using "$destino\iess_`a'.dta"
}

if _N > 0 {
    * Guardamos la base maestra de IESS
    quietly save "$destino\Serie_IESS_90_24_Consolidada.dta", replace
    
    * Calculamos el porcentaje de cobertura por año
    * (Asegúrate de haber filtrado ocupados previamente si buscas tasa de formalidad)
    collapse (mean) col_iess [iw=fexp], by(anio)
    
    * Convertir a formato porcentaje (0-100)
    replace col_iess = col_iess * 100

    * Configuración del Gráfico
    twoway (line col_iess anio, lwidth(medthick) lcolor(teal) msize(small) msymbol(diamond)), ///
        title("Evolución de la Afiliación al IESS en Ecuador", size(medium)) ///
        subtitle("Población >= 15 años (1990-2024)", size(small)) ///
        xtitle("Año") ytitle("Porcentaje de Afiliación (%)") ///
        xlabel(1990(2)2024, angle(45) labsize(vsmall)) ///
        ylabel(0(10)60, grid gstyle(dot)) ///
        graphregion(color(white)) ///
        note("Fuente: ENEMDU (INEC) | Elaboración propia siguiendo lógica estricta de periodos.")

    * Exportar el resultado
    graph export "$destino\Grafico_Tendencia_IESS.png", replace
    display "🏁 GRÁFICO GENERADO: Revisa la carpeta Bases_Procesadas_IESS"
}
else {
    display "❌ Error: No se encontraron archivos para consolidar."
}
* PEA armonizada	

* ======================================================================
* 0. CONFIGURACIÓN INICIAL Y RUTAS
* ======================================================================
clear all
set more off

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"



* ======================================================================
* 1. BUCLE DE PROCESAMIENTO CON TABLAS DE VALORES ABSOLUTOS
* ======================================================================
forvalues anio_loop = 1990/2025 {
    
    use "$raw/empleo`anio_loop'.dta", clear
	
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

	
    * Tabla 1: Cruce de Condición de Actividad vs Nuestra PEA
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
			
			cap confirm variable area
			if !_rc local area_var area
			else    local area_var 
            keep id_persona anio mi_pea sector_armonizado fexp `area_var'
			tempfile clasif_`anio_loop'
            save `clasif_`anio_loop'', replace
            local guardado "SÍ"
        }
        else local guardado "NO"
    }
    
    if "`guardado'" == "SÍ" display "✅ Base espejo guardada con éxito."
    display ""
}


* ======================================================================
* 2. CONSOLIDACIÓN Y GRÁFICO FINAL
* ======================================================================
clear
display "🚀 Consolidando serie histórica para el gráfico..."
forvalues a = 1990/2025 { 
   capture confirm variable area
   if !_rc destring area, replace
   append using `clasif_`a'.dta'
}

save "$out/pea.dta", replace


use "$out/pea.dta", clear
replace area = 1 if area == .


global important_variable mi_pea

preserve
    collapse (mean) $important_variable if anio != 2002, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    collapse (mean) $important_variable if anio != 2002, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
    
    twoway (line ${important_variable}_nac anio if anio >= 2000)  ///
           (line ${important_variable}_urb anio), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f)) ///
           ytitle("Cuenta propistas") xtitle("Año") ///
           title("Cuenta propistas")
restore

graph export "$out_plot/historico_${important_variable}.pdf", replace

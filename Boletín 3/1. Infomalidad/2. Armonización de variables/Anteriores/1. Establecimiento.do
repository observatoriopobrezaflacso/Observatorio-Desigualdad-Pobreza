***************** Armonización de establecimiento
clear all
set more off

* --- RUTAS ---
global bases   "G:\Mi unidad\Bases\ENEMDU\Procesadas\Armonizacion\Variables base\Trimestrales"
global destino "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases establecimiento"

* Loop para recorrer toda la serie
forvalues anio = 1990/2024 {
    
    di "=> Procesando Año: `anio'"
    
    * 1. Carga inteligente (solo variables necesarias para no saturar memoria)
    * Usamos capture porque los nombres cambian entre pertrabn y p47a
    capture use id_persona anio pertrabn p47a using "$bases\empleo`anio'.dta", clear
    
    if _rc != 0 {
        * Si las variables no están con esos nombres, cargamos la base completa
        use "$bases\empleo`anio'.dta", clear
    }

    * 2. Creación de la variable ARMONIZADA
    gen tamano_armonizado = .
    
    * --- LÓGICA POR ÉPOCAS ---
    
    * B. Época pertrabn estándar (1993 - 2006)
    else if `anio' >= 1993 & `anio' <= 2006 {
        capture replace tamano_armonizado = 1 if pertrabn == 1
        capture replace tamano_armonizado = 2 if pertrabn == 2
    }
    
    * C. Época p47a estándar (2007 - 2024)
    else if `anio' >= 2007 {
        capture replace tamano_armonizado = 1 if p47a == 1
        capture replace tamano_armonizado = 2 if p47a == 2
    }

    * 3. Limpieza y Guardado del Componente
    label define lbl_tam 1 "Menos de 100" 2 "100 y más"
    label values tamano_armonizado lbl_tam
    label var tamano_armonizado "Tamaño del establecimiento (Armonizado 90-24)"
    
    keep id_persona anio tamano_armonizado
    save "$destino\comp_tamano_`anio'.dta", replace
}

* --- UNIÓN FINAL (APPEND) ---
di "📦 Uniendo todos los años..."
clear

cd "$destino"

* Usamos una forma más directa de listar archivos
local files : dir . files "comp_tamano_*.dta"

* Generamos una variable temporal para el primer archivo
tempfile master
save `master', emptyok

foreach f in `files' {
    di "Añadiendo: `f'"
    append using "`f'"
}

* Ordenamos para que quede estético
sort anio id_persona

* Guardamos el resultado final
save "MASTER_TAMANO_ESTABLECIMIENTO_90_24.dta", replace
di "🚀 ¡PROCESO COMPLETADO! Archivo maestro creado en $destino"


******GRÁFICO*******

* 1. Preparación de datos para la serie de tiempo
gen grande = (tamano_armonizado == 2) if !missing(tamano_armonizado)

* 2. Colapsamos para obtener la media anual
preserve
    collapse (mean) grande if anio != 2002, by(anio)
    replace grande = grande * 100 // Convertir a porcentaje
    
    * 3. Generación del Gráfico
    twoway (line grande anio, lcolor(navy) lwidth(medium)), ///
        title("Consistencia de la Armonización (1990-2024)", size(medium)) ///
        subtitle("% de Ocupados en Establecimientos de 100+ personas", size(small)) ///
        ytitle("Porcentaje (%)") xtitle("Año") ///
        xlabel(1990(2)2024, angle(45) grid) ///
        ylabel(0(10)60, grid) ///
        note("Fuente: ENEMDU (Bases Armonizadas). Elaboración propia.", size(vsmall)) ///
        graphregion(color(white))

    * 4. GUARDAR EL GRÁFICO
    graph export "$destino\Grafico_Consistencia_Tamaño.png", as(png) replace
    di "✅ Gráfico guardado en: $destino"


**** Auditoria
use "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases establecimiento\MASTER_TAMANO_ESTABLECIMIENTO_90_24.dta", clear
tab anio tamano_armonizado, nofreq row





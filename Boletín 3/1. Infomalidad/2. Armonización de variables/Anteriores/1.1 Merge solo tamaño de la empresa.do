clear all
set more off

* --- RUTAS ---
* 1. Origen: Bases armonizadas generales
global origen_arm "G:\Mi unidad\Bases\ENEMDU\Procesadas\Armonizacion\Variables base\Trimestrales"

* 2. Origen: Componentes de tamaño (los que creamos hace un momento)
global origen_tam "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Componentes de calculo"

* 3. Destino: Bases finales individuales
global destino    "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases opcion 1"

* Crear carpeta de destino si no existe
capture mkdir "$destino"

* --- PROCESO ---
forvalues anio = 1990/2024 {
    
    di "--------------------------------------------------------------"
    di "🔗 UNIENDO COMPONENTES: Año `anio'"
    
    * 1. Cargar el componente de tamaño 
    capture use "$origen_tam\comp_tamano_`anio'.dta", clear
    if _rc != 0 {
        di "⚠️ No se encontró el componente de tamaño para `anio'. Saltando..."
        continue
    }
    
    * 2. Merge con la base armonizada original
    * Usamos 1:1 porque ambas bases tienen la misma estructura de ID y Año
    merge 1:1 id_persona anio using "$origen_arm\empleo`anio'.dta"
    
    * 3. Limpieza de merge y organización
    * Mantendremos a todos los individuos, pero eliminamos la variable _merge
    drop _merge
    
    * 4. Guardar en la nueva ubicación con el nombre empleoXXXX.dta
    save "$destino\empleo`anio'.dta", replace
    di "✅ Archivo guardado: $destino\empleo`anio'.dta"
}

di "--------------------------------------------------------------"
di "🚀 ¡PROCESO FINALIZADO! Tienes 35 bases listas en la carpeta Opción 1."
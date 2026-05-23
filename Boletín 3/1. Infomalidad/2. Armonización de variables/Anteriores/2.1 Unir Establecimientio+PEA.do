* ======================================================================
* UNIÓN FINAL: BASES OPCIÓN 1 + PEA ARMONIZADA
* ======================================================================
clear all
set more off

* --- RUTAS ---
global principal "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases opcion 1"
global espejos   "C:\Users\Wilson\Documents\FLACSO\Observatorio\Calculo de informalidad\Bases_Clasificadas_PEA"

forvalues anio = 1990/2024 {
    
    display _dup(60) "-"
    display "🔗 UNIENDO BASES - AÑO: `anio'"
    
    * 1. Cargar base principal de la Opción 1
    capture use "$principal\empleo`anio'.dta", clear
    if _rc != 0 {
        display "⚠️ No se encontró empleo`anio'.dta en la carpeta principal."
        continue
    }
    
    * 2. El Merge 1:1 usando ID y AÑO
    * 'keep(master match)' asegura que no perdamos a nadie de la base original
    * 'nogenerate' evita que se cree la variable _merge en cada ciclo
    capture merge 1:1 id_persona anio using "$espejos\clasif_`anio'.dta", keep(master match) nogenerate
    
    if _rc == 0 {
        * 3. Guardar la base ya completa (sobreescribiendo la Opción 1)
        save "$principal\empleo`anio'.dta", replace
        display "✅ Unión exitosa y base actualizada para `anio'."
    }
    else {
        display "❌ ERROR en `anio': La llave id_persona + anio no es única."
        * Opcional: podrías probar m:1 si el error persiste en algún año específico
    }
}

display _dup(60) "="
display "🏁 ¡PROCESO FINALIZADO! Tus 35 bases en 'Opción 1' ya tienen la PEA."
display _dup(60) "="
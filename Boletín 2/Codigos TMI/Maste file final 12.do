* Entrar a la carpeta de los archivos

forvalues y = 1990/2024 {
    di "Procesando año `y'..."

    * Importar el archivo SAV
    capture import spss using "EDG_`y'.sav", clear
    if _rc {
        di "Archivo EDG_`y'.sav no encontrado, se salta..."
        continue
    }

    * Estandarizar nombres (Lógica original)
    capture confirm variable ANOF
    if !_rc rename ANOF aniof

    capture confirm variable ANON
    if !_rc rename ANON anion

    capture confirm variable MESF
    if !_rc rename MESF mesf

    capture confirm variable MESN
    if !_rc rename MESN mesn

    capture confirm variable COD_EDA
    if !_rc rename COD_EDA cod_edad

    capture confirm variable EDAD
    if !_rc rename EDAD edad

    capture confirm string variable cod_edad
    if !_rc destring cod_edad, replace force

    * Crear variable menor1
    capture confirm variable cod_edad
    if !_rc {
        gen menor1 = inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)
    }
    else {
        * Si no existen variables de edad, calcular por fechas
        capture confirm variable aniof anion mesf mesn
        if !_rc {
            gen edad_meses = (aniof - anion)*12 + (mesf - mesn)
            gen menor1 = (edad_meses >= 0 & edad_meses < 12)
        }
        else {
            gen menor1 = 0
        }
    }

    * Colapsar datos por año
    collapse (sum) MI=menor1
    gen anio = `y'

    * Pegar al acumulado temporal
    append using `base_acumulada'
    save `base_acumulada', replace
}

*  Cargar el temporal, ordenar y GUARDAR en el disco duro
use `base_acumulada', clear
gsort anio
save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta", replace

* Verificación final
count
list

* Definir rutas
local carpeta_env "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV"
local base_nacimientos "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta"

clear
set obs 0
gen anio = .
gen NV = .
save "`base_nacimientos'", emptyok replace

forvalues y = 1990/2024 {
    di "Procesando Nacidos Vivos año `y'..."
    
    * Importar el archivo SAV 
    capture import spss using "`carpeta_env'\ENV_`y'.sav", clear
    
    * Si el nombre tiene un espacio  "ENV_ 2021"
    if _rc capture import spss using "`carpeta_env'\ENV_ `y'.sav", clear

    if _rc {
        di "Error: No se pudo encontrar el archivo del año `y'"
        continue
    }

    * En las ENV, cada fila es un nacido vivo, así que solo se cuenta observaciones
    gen NV = 1
    collapse (sum) NV
    gen anio = `y'

    append using "`base_nacimientos'"
	gsort anio
    save "`base_nacimientos'", replace
}


* 1. Cargar la base de defunciones
use "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta", clear

* 2. Unir con la base de nacimientos
merge 1:1 anio using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\nacimientos_total.dta"

* 3. Verificar Matched: 35
tab _merge
keep if _merge == 3
drop _merge

* 4. Calcular la Tasa de Mortalidad Infantil (TMI)
gen tmi = (MI / NV) * 1000
label var tmi "Tasa de Mortalidad Infantil (por cada 1000 NV)"

* 5. Ordenar cronológicamente
gsort anio

* 6. Guardar la serie histórica final
save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\TMI_Final_90_24.dta", replace

* 7. Mostrar resultados finales
list anio MI NV tmi


* Configuración del gráfico de doble eje
twoway ///
    (bar MI anio, yaxis(1) color(navy%40) barw(0.7)) ///  <-- Defunciones en barras (eje izquierdo)
    (line tmi anio, yaxis(2) lcolor(red) lwidth(medium) lpattern(solid)) /// <-- Tasa en línea (eje derecho)
    (scatter tmi anio, yaxis(2) mcolor(red) msize(small)), /// <-- Puntos para marcar cada año
    title("Ecuador: Mortalidad Infantil (1990-2024)", size(medium) color(black)) ///
    subtitle("Relación entre defunciones absolutas y tasa por cada 1,000 NV", size(small)) ///
    ytitle("Número de Defunciones (< 1 año)", axis(1) size(small)) ///
    ytitle("Tasa de Mortalidad Infantil", axis(2) size(small) color(red)) ///
    xtitle("Año", size(small)) ///
    xlabel(1990(5)2024, grid gstyle(dot)) ///
    ylabel(0(1000)8000, axis(1) grid gstyle(dot)) ///
    ylabel(0(5)30, axis(2)) ///
    legend(order(1 "Defunciones Absolutas (MI)" 2 "Tasa de Mortalidad (TMI)") ///
           rows(1) size(vsmall) region(lcolor(white))) ///
    graphregion(color(white)) // Fondo blanco profesionalcd "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"

clear
tempfile base_acumulada
save `base_acumulada', emptyok replace

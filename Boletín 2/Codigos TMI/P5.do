clear
tempfile basefinal
save `basefinal', emptyok

forvalues y = 1990/2024 {

    di "Procesando año `y'..."

    import spss using "EDG_`y'.sav", clear

    * Verificar que existan variables
    capture confirm variable ANON
    if _rc != 0 {
        di "Variable ANON no existe en `y'"
        continue
    }

    * Limpieza básica
    drop if ANON == 9999
    drop if ANON < 1850
    drop if MESN < 1 | MESN > 12
    drop if MESF < 1 | MESF > 12

    * Edad en meses
    gen edad_meses = (ANOF - ANON)*12 + (MESF - MESN)
    drop if edad_meses < 0
    drop if edad_meses > 130*12

    * Muertes menores de 1 año
    gen menor1 = edad_meses >=0 & edad_meses <12

    collapse (sum) MI=menor1

    gen anio = `y'

    append using `basefinal'
    save `basefinal', replace
}

use `basefinal', clear
sort anio
list

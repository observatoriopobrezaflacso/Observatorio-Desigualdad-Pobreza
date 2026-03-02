cd "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"

clear
tempfile basefinal
save `basefinal', emptyok replace

forvalues y = 1990/2024 {
    di "Procesando año `y'..."

    capture import spss using "EDG_`y'.sav", clear
    if _rc {
        di "Archivo EDG_`y'.sav no encontrado, se salta..."
        continue
    }

    * Estandarizar nombres
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
        gen menor1 = inlist(cod_edad,1,2,3) | ///
                     (cod_edad==4 & edad==0)
    }
    else {
        gen edad_meses = (aniof - anion)*12 + (mesf - mesn)
        gen menor1 = edad_meses >=0 & edad_meses <12
    }

    collapse (sum) MI=menor1
    gen anio = `y'

    append using `basefinal'
gsort anio
    save `basefinal', replace
}


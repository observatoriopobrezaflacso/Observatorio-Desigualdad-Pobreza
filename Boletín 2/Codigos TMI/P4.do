clear
tempfile basefinal
save `basefinal', emptyok

forvalues y = 1990/2024 {

    di "Procesando año `y'..."

    import spss using "EDG_`y'.sav", clear

    capture confirm variable anio_nac

    if _rc == 0 {
        * FORMATO MODERNO
        gen menor1 = (edad==0 & cod_edad==1) | ///
                     (cod_edad==2) | ///
                     (cod_edad==3)
    }
    else {
        * FORMATO ANTIGUO
        gen edad_meses = (ANOF - ANON)*12 + (MESF - MESN)
        gen menor1 = edad_meses >=0 & edad_meses <12
    }

    collapse (sum) MI=menor1
    gen anio = `y'

    append using `basefinal'
    save `basefinal', replace
}

use `basefinal', clear
sort anio
list

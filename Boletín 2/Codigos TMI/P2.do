clear
tempfile basefinal
save `basefinal', emptyok

forvalues y = 1990/2024 {

    di "Procesando año `y'..."

    import spss using "EDG_`y'.sav", clear
	
capture confirm variable ANOF
if !_rc {
    rename ANOF aniof
}

capture confirm variable aniof
if !_rc {
    gen anio = aniof
}


    * ----- FORMATO 3 (2011+)
    capture confirm variable cod_edad
    if _rc == 0 {

        gen menor1 = inlist(cod_edad,1,2,3) | ///
                     (cod_edad==4 & edad==0)
    }

    else {

        * ----- FORMATO 2 (2000–2010)
        capture confirm variable COD_EDA
        if _rc == 0 {

            gen menor1 = inlist(COD_EDA,1,2,3) | ///
                         (COD_EDA==4 & EDAD==0)
        }

        else {

            * ----- FORMATO 1 (1990s)
            gen edad_meses = (ANOF - ANON)*12 + ///
                             (MESF - MESN)

            gen menor1 = edad_meses >=0 & edad_meses <12
        }
    }

    collapse (sum) MI=menor1
    gen anio = `y'

    append using `basefinal'
    save `basefinal', replace
}

use `basefinal', clear
sort anio
list

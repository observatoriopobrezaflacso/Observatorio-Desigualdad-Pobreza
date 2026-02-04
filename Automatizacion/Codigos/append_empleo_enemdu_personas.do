global wd "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Procesamiento/Bases/ENEMDU - copia"

cd "$wd"

global anio_inicio = 2023
global anio_fin = 2025


forval i = $anio_inicio/$anio_fin { 

    if (`i' != 2021) {
        local a = 1
    } 
    else {
        local a = 6
    }

    forval j = `a'/12 {
        
        if (strlen("`j'") == 1) local j2 = "0`j'"
        else local j2 = "`j'"

        mata : st_numscalar("OK", direxists("`i'/`j2'"))
        di "`i'/`j2'"
        di scalar(OK)

        if (scalar(OK) == 1) {
            di "asd"
            
            local personas1: dir "$wd/`i'/`j2'" files "*15anio*.dta", respectcase
            local personas2: dir "$wd/`i'/`j2'" files "*_per*.dta", respectcase

			di "asdasd"

            if ("`personas1'1" != "1") {
                local personas1 = `personas1'
            }

            if ("`personas2'1" != "1") {
                local personas2 = `personas2'
            }

			
            if ("`personas1'" != "") {
                use "`i'/`j2'/`personas1'", clear
                count
            }
            else {
                use "`i'/`j2'/`personas2'", clear
            }
			
		    local varlist area ciudad dominio plan_muestreo ced01a

		    foreach x in `varlist' {
			
			capture confirm variable `x'
			
				if _rc == 0 {

					local type_a: type `x'
					di "`type_a'"

					if ("type_a" != "byte") {
						destring `x', replace

						if ("`x'" == "area") {
							label value area areal
						}
					}
				}
			} // end foreach x
			
		gen anio = `i'
		gen mes = `j2'
		gen anio_mes = "`i'_`j'"	
			
		    save "Compatibles/`i'-`j2'" , replace
				
        } // end if OK == 1

    } // end forval j

} // end forval i



if $anio_inicio == 2014 {
use "$wd/Compatibles/${anio_inicio}-09", clear
} 
else {
use "$wd/Compatibles/${anio_inicio}-01", clear
}

forval i = $anio_inicio/$anio_fin {

    if (`i' != 2021) {
        local a = 1
    } 
    else {
        local a = 6
    }

    forval j = `a'/12 {
        
        if (strlen("`j'") == 1) local j2 = "0`j'"
        else local j2 = "`j'"

        mata : st_numscalar("OK", direxists("`i'/`j2'"))
        di "`i'/`j2'"
        di scalar(OK)

        if (scalar(OK) == 1) {
            
                append using "$wd/Compatibles/`i'-`j2'.dta"
 

        }
    }
}

save "$wd/Appended/${anio_inicio}_${anio_fin.dta}", replace



* Falta: Copiar la carpeta en el Drive Compartido a todos y subir los codigos a GH. 
*        Compatibilizar labels
*        Automatizar descarga
*        Anadir bases de todos los meses de 2024
*        Anadir anos anteriores a 2014 (baja prioridad) 
*        Hacer lo mismo para el resto de bases         


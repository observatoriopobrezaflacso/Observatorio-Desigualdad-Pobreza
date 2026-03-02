clear
tempfile acumulado
save `acumulado', emptyok replace

forvalues y = 1990/2024 {
    di "Procesando Defunciones año `y'..."
    
    * Importar el archivo SAV (ajustando la ruta a tu carpeta)
    capture import spss using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones\EDG_`y'.sav", clear
    
    if _rc == 0 {
        * Estandarización de variables (tu lógica original)
        capture confirm variable ANOF
        if !_rc rename ANOF aniof
        
        capture confirm variable ANON
        if !_rc rename ANON anion
        
        capture confirm variable COD_EDA
        if !_rc rename COD_EDA cod_edad
        
        capture confirm variable EDAD
        if !_rc rename EDAD edad

        * Identificar menores de 1 año
        capture confirm variable cod_edad
        if !_rc {
            gen menor1 = inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)
        }
        else {
            * Lógica por fechas si no hay código de edad
            capture confirm variable aniof
            if !_rc gen menor1 = (aniof - anion == 0) // Simplificación lógica
        }

        * Colapsar para obtener el total del año
        collapse (sum) MI=menor1
        gen anio = `y'
        
        * PEGADO ACUMULATIVO: Aquí es donde se construye la serie
        append using `acumulado'
        save `acumulado', replace
    }
    else {
        di "Error: No se encontró el archivo EDG_`y'.sav"
    }
}

* Cargar la serie completa y guardar
use `acumulado', clear
gsort anio
save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\defunciones_menores1.dta", replace

* VERIFICACIÓN FINAL: Debería salir 35
count
list
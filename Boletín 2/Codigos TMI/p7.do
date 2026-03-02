use "`base_nacimientos'", clear

* 1. Verificar el orden cronológico
list in 1/5   // Debería mostrar 1990, 1991...
list in -5/L  // Debería mostrar 2020, 2021... 2024

* 2. Verificar que no falten años (deberías tener 35 observaciones)
count
local n_esperado = 2024 - 1990 + 1
if `r(N)' == `n_esperado' {
    di "Check: Tienes todos los años completos."
}
else {
    di "Alerta: Faltan años en la serie."
}

* 3. Inspección visual rápida (Gráfico de tendencia)
* Los nacimientos en Ecuador suelen tener una tendencia conocida. 
* Si ves un pico o una caída a cero, hay un error en la importación.
line NV anio, title("Verificación de Nacidos Vivos (1990-2024)") ///
    ytitle("Total Nacimientos") xtitle("Año")
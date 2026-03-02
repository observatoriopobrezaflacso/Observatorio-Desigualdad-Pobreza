* --- CÁLCULO NBI 1990 CON TUS DATOS REALES ---

* 1. Vivienda Inadecuada (basado en tu fre TIPVIV)
gen c_vivienda = inlist(TIPVIV, 5, 6, 7)
replace c_vivienda = . if TIPVIV == 0  // Ignorar códigos 0 (faltantes)

* 2. Servicios Críticos (basado en tu fre SISABA y SERHIG)
* Carencia si: No hay tubería (4) O No tiene baño/es letrina (3, 4)
gen c_servicios = (SISABA == 4 | inlist(SERHIG, 3, 4))
replace c_servicios = . if SISABA == 0 | SERHIG == 0

* 3. Hacinamiento Crítico
* Más de 3 personas por dormitorio (Usamos tus variables TOTALPOB y CUADOR)
gen ratio_hac = TOTALPOB / CUADOR
gen c_hacinamiento = (ratio_hac > 3) if CUADOR > 0 & TOTALPOB > 0
replace c_hacinamiento = . if CUADOR == 0

* 4. Capacidad Económica (Basado en tu fre ACTECO)
* Combinamos alta dependencia con el "No" de actividad económica
gen ratio_dep = TOTALPOB / (HOMBRES + MUJERES)
gen c_economica = (ratio_dep > 3 & ACTECO == 2)
replace c_economica = . if ACTECO == 0

* --- INDICADOR FINAL PNBI ---
* Pobre si tiene al menos 1 de las 4 carencias
egen nbi_pobre = rowmax(c_vivienda c_servicios c_hacinamiento c_economica)

* --- COLAPSAR POR PARROQUIA (CON TUS CÓDIGOS) ---
* Creamos el ID de 6 dígitos
gen id_parroquia = string(PROVIN, "%02.0f") + string(CANTON, "%02.0f") + string(PARROQ, "%02.0f")

collapse (mean) pnbi_90 = nbi_pobre (sum) poblacion_90 = TOTALPOB, by(id_parroquia)
replace pnbi_90 = pnbi_90 * 100

list id_parroquia pnbi_90 in 1/10
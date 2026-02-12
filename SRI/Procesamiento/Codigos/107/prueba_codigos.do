
cd "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/Fake"

use "F102/F102_2010.dta", clear

tostring ret_fuente_div_atc_3520 , replace


gen anio_formulario = 2010

append using "F102/F102_2011.dta"


replace anio_formulario = 2011 if anio_formulario == .


describe using "F102/F102_2011.dta"


sort CEDULA_PK
br CEDULA_PK anio_formulario

rename CEDULA_PK CEDULA_PK_empleado

merge m:m CEDULA_PK using "F107/F107_2011.dta"




***********************************************************************************
*	                 DEPURACIÓN DE DÉCIMOS Y FONDO DE RESERVA                     *
***********************************************************************************
*ELABORADO POR: CARLA CHAMORRO 

*FECHA CREACION:		26-05-2021
*ÚLTIMA MODIFICACIÓN:	02-12-2025
***********************************************************************************

*=============* DECIMO CUARTO *=============*

/**** 1. Normativa revisada:

CÓDIGO DEL TRABAJO
Art. 113 .- Derecho a la decimocuarta remuneración.- Los trabajadores percibirán, además, sin perjuicio de todas las remuneraciones a las que actualmente tienen derecho, 
		una bonificación mensual equivalente a la doceava parte de la remuneración básica mínima unificada para los trabajadores en general.

		A pedido escrito de la trabajadora o el trabajador, este valor podrá recibirse de forma acumulada, hasta el 15 de marzo en las regiones de la Costa e Insular, y hasta el 15 de agosto en 
		las regiones de la Sierra y Amazónica. Para el pago de esta bonificación se observará el régimen escolar adoptado en cada una de las circunscripciones territoriales.

		La bonificación a la que se refiere el inciso anterior se pagará también a los jubilados por sus empleadores, a los jubilados del IESS, pensionistas del Seguro Militar y de la Policía Nacional.
		Si un trabajador, por cualquier causa, saliere o fuese separado de su trabajo antes de las fechas mencionadas, recibirá la parte proporcional de la décima cuarta remuneración al momento 
		del retiro o separación.

LEY DEL DÉCIMO CUARTO SUELDO

**** 2. Construcción decimo cuarto depurado 2024

 **NOTA : Es preciso depurar el décimo cuarto sueldo considerando los límites normativos que podría recibir una persona:
 a. Si tiene un solo empleador y cuenta con reliquidación:
 
	Normativamente corresponde a un valor 460 al 2024 maximo mas la reliquidación que corresponda en el año fiscal vigente. 
	Se toma como referencia el pago en abril que se hace en las provincias de la Costa, por lo que una persona maximo de reliquidación podría recibir (460/12*9). 
	Por ello, el valor declarado podría ser maximo 460 mas el valor de liquidacion 345 es decir hasta 805 USD.

 b. Si está en régimen costa, que se liquida en diciembre y tiene 3 trabajos en jornadas completas:
	Podria recibir 3 decimos cuarto en un año. Lo que seria para 2024: (460 + ((460/12)*9))*3) = 2.415.
	
*** Normativamente, cualquier número de meses es válido, pero 9 meses es un caso representativo y frecuente para estimar un máximo razonable de reliquidación.

*/

*Depuración a:

rename decimo_cuarto decimo_cuarto_dec
 
gen 	decimo_cuarto = decimo_cuarto_dec
replace decimo_cuarto = (((460/12) * 9) + 460) if decimo_cuarto_dec > (((460/12) * 9) + 460)
 
* Depuración b:

*El nombre "decimo_cuarto_805" se determina en función de la cantidad del máximo monto de décimo cuarto que podría recibir el contribuyente considerando la reliquidación de la Costa.

rename decimo_cuarto decimo_cuarto_805

gen decimo_cuarto_24 = min(decimo_cuarto_805, 2415)


*=============* DECIMO TERCERO *=============*

gen decimo_tercero_1 = min(decimo_tercero, (ingresos_liq_pagad + sob_suel_com_remu)/12)

*=============* CONSTRUCCION DE FONDOS DE RESERVA TEORICO *=============*

* Nota: Se realiza construyendo un valor teórico que es la suma de los ingresos liquidos pagados, sobre sueldos y participacion de utilidades por 8.33%. 

* 1. Fondo de reserva calculado teóricamente:
egen 	fondo_reserva_teo = rowtotal(ingresos_liq_pagados sob_suel_com_remu partic_utilidades)
replace fondo_reserva_teo = fondo_reserva_teo * 0.0833

* 2. Comparación con el valor declarado
gen dif_fres = fondo_reserva_teo - fondo_reserva
br sob_suel_com_remu fondo_reserva_teo fondo_reserva ingresos_liq_pagados partic_utilidades dif_fres 

*3. Renombrar variable
rename fondo_reserva_teo freserva_teorico 

*4. Coeficiente de fondo de reserva

** 4.1. Calcula el coeficiente real: Proporción del fondo de reserva sobre el ingreso gravado.
gen coef_fres = fondo_reserva / (ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades)

** 4.2. Redondea a 4 decimales
gen coef_fres_r = round(coef_fres,0.0001)	

** 4.3. Ordena de mayor a menor
gsort -coef_fres_r

*5. Identificación de datos atípicos
br fondo_reserva freserva_teorico coef_fres_r if coef_fres_r > 0.0833 & coef_fres_r != .			
count if coef_fres_r > 0.0833 & coef_fres_r != .	

*6. Corrección de fondos de reserva
	* Se crea una variable corregida (freserva_correc).
	* Si el fondo de reserva real es positivo y menor a missing, y además el coeficiente excede el 8,33%, se reemplaza por el valor teórico.
	* Resultado: se ajustan los casos que estaban fuera de norma.
	
gen 	freserva_correc = fondo_reserva
replace freserva_correc = freserva_teorico if (freserva_correc >0 & freserva_correc <.) & (coef_fres_r > 0.0833 & coef_fres_r != .)


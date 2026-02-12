*******************************
**********PROGRAMA SRI*********
*****Declaración de renta******
*************2023**************

*Ruthy Intriago
*Fecha: 1 de diciembre 2025
*Proyecto: FLACSO Observatorio

**********************************************
*=============* FORMULARIO 107 *=============*
**********************************************

clear all
set more off
use "D:\DTO_ESTUDIOS_E1\B_INVESTIGADORES_EXTERNOS\2025.12.01_Ruthy Intriago\03 BDD\Anexo RDEP\F107_anonimizada_2023.dta" 

drop numero_retenciones anio_retencion estado anio tipo_empleador ente_seguirdad_social numero_meses_trab_empleador residencia pais_residencia conv_doble_imp_pago porcen_discapa_trabaj cod_tipo_id_discapacitado trabajador_discapacitado codigo_tipo_identificacion

destring ingresos_liq_pagados, replace

*INGRESOS DE TRABAJO

*ingresos_liq_pagados
*sob_suel_com_remu
*partic_utilidades
*ingresos_otros_empleadores
*imp_renta_empleador
*decimo_tercero
*decimo_cuarto
*fondo_reserva
*salario_digno
*desahucio_otras_remun
*ingreso_grav_otr_empleador

*GASTOS

*aporte_iess_empleado
*reb_esp_discap
*reb_esp_ter_edad
*deduccion_vivienda
*deduccion_salud
*deduccion_educacion
*deduccion_educacion_arte
*deduccion_arte_cultura
*deduccion_alimentacion
*deduccion_vestimenta
*deduccion_turismo
*rebaja_gastos_personales
*impuesto_renta_rebaja_gp
*deduccion_otros_empleadores
*rebajas_otros_empleadores
*aporte_iess_otr_empleador
*valor_imp_ret_otr_empleador
*valor_imp_asum_empleado
*beneficio_galapagos

*base_imponible=ingresos_liq_pagados + sob_suel_com_remu + partic_utilidades + ingresos_otros_empleadores - aporte_iess_empleado -aporte_iess_otr_empleador
*ingreso = base_imponible + decimo_tercero + decimo_cuarto + fondo_reserva

keep ingresos_liq_pagados sob_suel_com_remu partic_utilidades ingresos_otros_empleadores imp_renta_empleador decimo_tercero decimo_cuarto fondo_reserva salario_digno desahucio_otras_remun ingreso_grav_otr_empleador aporte_iess_empleado base_imponible RUC_PK_empleador RUC_PK_empleado CEDULA_PK_empleado aporte_iess_otr_empleador

destring aporte_iess_empleado, replace
destring sob_suel_com_remu, replace
destring base_imponible, replace
destring decimo_tercero, replace
destring decimo_cuarto, replace
destring partic_utilidades, replace
destring imp_renta_empleador, replace
destring fondo_reserva, replace
destring desahucio_otras_remun, replace
destring ingresos_otros_empleadores, replace
destring salario_digno, replace
destring ingreso_grav_otr_empleador, replace
destring aporte_iess_otr_empleador, replace

* Depuración de décimos y fondos de reserva pendiente

*=============* DECIMO CUARTO *=============*

rename decimo_cuarto decimo_cuarto_dec
 
gen 	decimo_cuarto = decimo_cuarto_dec
replace decimo_cuarto = (((460/12) * 9) + 460) if decimo_cuarto_dec > (((460/12) * 9) + 460)
 

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



****TABLA****
gen ingreso_trabajo= base_imponible + decimo_tercero_1 + decimo_cuarto + freserva_correc

describe ingreso_trabajo
summ ingreso_trabajo, detail

centile ingreso_trabajo, centile (99)
scalar p99=r(c_1)
gen g_p99= ingreso_trabajo if (ingreso_trabajo>=p99)

centile ingreso_trabajo, centile (95)
scalar p95=r(c_1)
gen g_p95= ingreso_trabajo if (ingreso_trabajo>=p95)

centile ingreso_trabajo, centile (90)
scalar p90=r(c_1)
gen g_p90= ingreso_trabajo if (ingreso_trabajo>=p90)

centile ingreso_trabajo, centile (80)
scalar p80=r(c_1)
gen g_p80= ingreso_trabajo if (ingreso_trabajo>=p80 &ingreso_trabajo<p90)

centile ingreso_trabajo, centile (70)
scalar p70=r(c_1)
gen g_p70= ingreso_trabajo if (ingreso_trabajo>=p70 &ingreso_trabajo<p80)

centile ingreso_trabajo, centile (60)
scalar p60=r(c_1)
gen g_p60= ingreso_trabajo if (ingreso_trabajo>=p60 &ingreso_trabajo<p70)

centile ingreso_trabajo, centile (50)
scalar p50=r(c_1)
gen g_p50= ingreso_trabajo if (ingreso_trabajo>=p50 &ingreso_trabajo<p60)

gen g_p1_50= ingreso_trabajo if (ingreso_trabajo<=p50)

sum g_p99, detail
sum g_p99
sum g_p95, detail
sum g_p95
sum g_p90, detail
sum g_p90
sum g_p80, detail
sum g_p80
sum g_p70, detail
sum g_p70
sum g_p60, detail
sum g_p60
sum g_p50, detail
sum g_p50

sum g_p1_50, detail
sum g_p1_50



keep RUC_PK_empleador RUC_PK_empleado CEDULA_PK_empleado ingreso_trabajo g_p99 g_p95 g_p90 g_p80 g_p70 g_p60 g_p50 g_p1_50

rename RUC_PK_empleado RUC_PK 
rename CEDULA_PK_empleado CEDULA_PK

save Form_107_work_2023, replace

**********************************************
*=============* FORMULARIO 102 *=============*
**********************************************


clear all
set more off
use "D:\DTO_ESTUDIOS_E1\B_INVESTIGADORES_EXTERNOS\2025.12.01_Ruthy Intriago\F102_anonimizada_2024_dep.dta" 


***INGRESOS DE TRABAJO
*741 sueldos y salarios (ING_SYO_TRABAJO_RDE_3240)
*611 (INGRESOS_AEM_RIE_1280)
*612-613 libre ejercicio profesional o trabajo independiente (ING_LIBRE_EJE_PROFESIONAL_2990, ING_OCUPACION_LIBERAL_3010) 
*6999 actividad empresarial obligados (TOTAL_INGRESOS_1440)

destring ING_SYO_TRABAJO_RDE_3240, replace
destring ING_LIBRE_EJE_PROFESIONAL_2990, replace
destring ING_OCUPACION_LIBERAL_3010, replace
destring INGRESOS_AEM_RIE_1280, replace
destring TOTAL_INGRESOS_1440, replace


***INGRESOS DE CAPITAL
*614-615 arrendamiento de bienes inmuebles (ING_ARRIENDO_INMUEBLES_3040, ING_ARRIENDO_OTROS_ACT_3080)
*616 rentas agrícolas (RIM_PGR_ANT_ANIO_2008_3160)
*617 regalías (INGRESOS_REGALIAS_3170)
*618 rendimientos financieros (RENDIMIENTOS_FINANCIEROS_3190)
*619-620 dividendos (DIVIDEND_RECIB_SOC_RESID_5120, DIV_RECIB_SOC_NO_RESID_5130) 
*621 Enajenación de derechos de capital (INGR_ENAJ_DRC_NO_IRU_5110)
*622-623 otras rentas no registradas (INGRESOS_OTR_RGR_3193, OTR_ING_GRAVADOS_EXTERIOR_3180)

destring ING_ARRIENDO_INMUEBLES_3040, replace
destring ING_ARRIENDO_OTROS_ACT_3080, replace
destring RIM_PGR_ANT_ANIO_2008_3160, replace
destring INGRESOS_REGALIAS_3170, replace
destring RENDIMIENTOS_FINANCIEROS_3190, replace
destring DIVIDEND_RECIB_SOC_RESID_5120, replace
destring DIV_RECIB_SOC_NO_RESID_5130, replace
destring INGR_ENAJ_DRC_NO_IRU_5110, replace
destring INGRESOS_OTR_RGR_3193, replace
destring OTR_ING_GRAVADOS_EXTERIOR_3180, replace

*Que necesito
*1440 actividad empresarial obligados (INGRESO TRABAJO)
*3200 trabajo autonomo y capital no obligados (INGRESO TRABAJO Y CAPITAL)
*3240 trabajo en relacion de dependencia (RELACIONO CON F-102)


keep ING_SYO_TRABAJO_RDE_3240 ING_LIBRE_EJE_PROFESIONAL_2990 ING_OCUPACION_LIBERAL_3010 INGRESOS_AEM_RIE_1280 TOTAL_INGRESOS_1440 ING_ARRIENDO_INMUEBLES_3040 ING_ARRIENDO_OTROS_ACT_3080 RIM_PGR_ANT_ANIO_2008_3160 INGRESOS_REGALIAS_3170 RENDIMIENTOS_FINANCIEROS_3190 DIVIDEND_RECIB_SOC_RESID_5120 DIV_RECIB_SOC_NO_RESID_5130 INGR_ENAJ_DRC_NO_IRU_5110 INGRESOS_OTR_RGR_3193 OTR_ING_GRAVADOS_EXTERIOR_3180 RUC_PK CEDULA_PK

*Creo las variables
rename TOTAL_INGRESOS_1440 INGRESOS_TRABAJO_OBLIGADOS
rename ING_SYO_TRABAJO_RDE_3240 INGRESOS_TRABAJO_DEPENDENCIA
gen INGRESOS_TRABAJO_NO_OBLIGADOS= ING_LIBRE_EJE_PROFESIONAL_2990 + ING_OCUPACION_LIBERAL_3010 + INGRESOS_AEM_RIE_1280
gen INGRESOS_CAPITAL= ING_ARRIENDO_INMUEBLES_3040 + ING_ARRIENDO_OTROS_ACT_3080 + RIM_PGR_ANT_ANIO_2008_3160 + INGRESOS_REGALIAS_3170 + RENDIMIENTOS_FINANCIEROS_3190 + DIVIDEND_RECIB_SOC_RESID_5120 + DIV_RECIB_SOC_NO_RESID_5130 + INGR_ENAJ_DRC_NO_IRU_5110 + INGRESOS_OTR_RGR_3193 + OTR_ING_GRAVADOS_EXTERIOR_3180


keep INGRESOS_TRABAJO_OBLIGADOS INGRESOS_TRABAJO_DEPENDENCIA INGRESOS_TRABAJO_NO_OBLIGADOS INGRESOS_CAPITAL RUC_PK CEDULA_PK

save Form_102_work, replace

***JUNTO LAS BASES 102 Y 107
use "Form_107_work", clear
merge m:m CEDULA_PK using "Form_102_work"

egen INGRESOS_TRAB_TOTAL = rowtotal(ingreso_trabajo INGRESOS_TRABAJO_OBLIGADOS INGRESOS_TRABAJO_NO_OBLIGADOS)

* REVISAR *
* Si no hay F107 (ingreso_trabajo es missing) pero sí hay dato en F102 (3240), súmalo.
replace INGRESOS_TRAB_TOTAL = INGRESOS_TRAB_TOTAL + INGRESOS_TRABAJO_DEPENDENCIA if missing(ingreso_trabajo) & !missing(INGRESOS_TRABAJO_DEPENDENCIA)


egen INGRESOS_CAPITAL_TOTAL= rowtotal (INGRESOS_CAPITAL)
egen INGRESOS_TOTAL= rowtotal (INGRESOS_TRAB_TOTAL INGRESOS_CAPITAL_TOTAL)

collapse (sum) INGRESOS_TRAB_TOTAL INGRESOS_CAPITAL_TOTAL INGRESOS_TOTAL, by (CEDULA_PK)

duplicates report CEDULA_PK


*Tablas

*Ingresos de trabajo

describe INGRESOS_TRAB_TOTAL
summ INGRESOS_TRAB_TOTAL, detail

centile INGRESOS_TRAB_TOTAL, centile (99)
scalar p99_trab=r(c_1)
gen g_p99= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p99_trab)

centile INGRESOS_TRAB_TOTAL, centile (95)
scalar p95_trab=r(c_1)
gen g_p95= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p95_trab)

centile INGRESOS_TRAB_TOTAL, centile (90)
scalar p90_trab=r(c_1)
gen g_p90= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p90_trab)

centile INGRESOS_TRAB_TOTAL, centile (80)
scalar p80_trab=r(c_1)
gen g_p80= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p80_trab & INGRESOS_TRAB_TOTAL<p90_trab)

centile INGRESOS_TRAB_TOTAL, centile (70)
scalar p70_trab=r(c_1)
gen g_p70= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p70_trab & INGRESOS_TRAB_TOTAL<p80_trab)

centile INGRESOS_TRAB_TOTAL, centile (60)
scalar p60_trab=r(c_1)
gen g_p60= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p60_trab & INGRESOS_TRAB_TOTAL<p70_trab)

centile INGRESOS_TRAB_TOTAL, centile (50)
scalar p50_trab=r(c_1)
gen g_p50= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL>=p50_trab & INGRESOS_TRAB_TOTAL<p60_trab)

gen g_p1_50= INGRESOS_TRAB_TOTAL if (INGRESOS_TRAB_TOTAL<=p50_trab)

drop if INGRESOS_TRAB_TOTAL>9996428
sum g_p99, detail
sum g_p99

sum g_p95, detail
sum g_p95

sum g_p90, detail
sum g_p90

sum g_p80, detail
sum g_p80

sum g_p70, detail
sum g_p70

sum g_p60, detail
sum g_p60

sum g_p50, detail
sum g_p50

sum g_p1_50, detail
sum g_p1_50

sum INGRESOS_TRAB_TOTAL, detail

*Ingresos de capital

describe INGRESOS_CAPITAL_TOTAL
summ INGRESOS_CAPITAL_TOTAL, detail

*centile INGRESOS_CAPITAL_TOTAL, centile (99)
*scalar p99_cap=r(c_1)
*gen g_p99k= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL>=p99_cap)

*centile INGRESOS_CAPITAL_TOTAL, centile (95)
*scalar p95_cap=r(c_1)
*gen g_p95k= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL>=p95_cap)

*centile INGRESOS_CAPITAL_TOTAL, centile (90)
*scalar p90_cap=r(c_1)
*gen g_p90k= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL>=p90_cap)

*centile INGRESOS_CAPITAL_TOTAL, centile (40)
*scalar p40_cap=r(c_1)
*gen g_p40k= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL<=p40_cap)

*sum g_p99k 
*sum g_p95k
*sum g_p90k 
*sum g_p40k 
*sum INGRESOS_CAPITAL_TOTAL

*tabstat INGRESOS_CAPITAL_TOTAL, stats(mean median p1 p25 p50 p75 p90 p95 p99 max)
*count if INGRESOS_CAPITAL_TOTAL>0
*sum INGRESOS_CAPITAL_TOTAL

gen g_p99p100= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL>=6549.95)
gen g_p95p100= INGRESOS_CAPITAL_TOTAL if (INGRESOS_CAPITAL_TOTAL>=43.5)

sum g_p99p100, detail
sum g_p99p100

sum g_p95p100, detail
sum g_p95p100


*Ingresos totales
describe INGRESOS_TOTAL
summ INGRESOS_TOTAL, detail

centile INGRESOS_TOTAL, centile (99)
scalar p99_tot=r(c_1)
gen g_p99t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p99_tot)

centile INGRESOS_TOTAL, centile (95)
scalar p95_tot=r(c_1)
gen g_p95t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p95_tot)

centile INGRESOS_TOTAL, centile (90)
scalar p90_tot=r(c_1)
gen g_p90t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p90_tot)

centile INGRESOS_TOTAL, centile (80)
scalar p80_tot=r(c_1)
gen g_p80t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p80_tot & INGRESOS_TOTAL<p90_tot)

centile INGRESOS_TOTAL, centile (70)
scalar p70_tot=r(c_1)
gen g_p70t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p70_tot & INGRESOS_TOTAL<p80_tot)

centile INGRESOS_TOTAL, centile (60)
scalar p60_tot=r(c_1)
gen g_p60t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p60_tot & INGRESOS_TOTAL<p70_tot)

centile INGRESOS_TOTAL, centile (50)
scalar p50_tot=r(c_1)
gen g_p50t= INGRESOS_TOTAL if (INGRESOS_TOTAL>=p50_tot & INGRESOS_TOTAL<p60_tot)

gen g_p1_50t= INGRESOS_TOTAL if (INGRESOS_TOTAL<=p50_tot)


sum g_p99t, detail 
sum g_p99t

sum g_p95t, detail
sum g_p95t

sum g_p90t, detail
sum g_p90

sum g_p80t, detail
sum g_p80

sum g_p70t, detail
sum g_p70

sum g_p60t, detail
sum g_p60

sum g_p50t, detail
sum g_p50t

sum g_p1_50t, detail
sum g_p1_50t

sum INGRESOS_TOTAL

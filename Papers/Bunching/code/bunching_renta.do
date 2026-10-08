/*******************************************************************************
* bunching_renta.do
*
* Test de bunching (acumulación) alrededor de:
*   (a) los umbrales de la tabla del impuesto a la renta de personas naturales
*       (Ecuador, SRI), 2010-2024, con la reforma de 2022 como experimento
*       natural para asalariados;
*   (b) la línea de USD 20.000 del RIMPE (negocios populares/emprendedores),
*       desde 2022.
*
* Datos: solo ingreso_dina_YYYY.dta (valores nominales, una fila por
*   declarante), construidos por Papers/Desigualdad ingreso/
*   construccion_ingreso_DINA.do. Traen el ingreso pre-impuesto (PreTaxHHI) y
*   las variables del F102 y F107 del análisis (base102, base107_sum,
*   n_emp_107, rimpe, rimpe_bruto, emp_bruto); no se leen los formularios.
*
* BASE IMPONIBLE (variable de prueba)
*   - Con 2+ empleadores en el F107: la del F102 si lo presentan (el impuesto
*     se debe sobre la base conjunta). Sin F102: la suma de las bases de
*     todos sus F107 (base107_sum). Indicación del SRI: ingreso_grav_otr_
*     empleador no entra en base_imponible, así que sumar no duplica.
*     Decisión 10 del registro (reemplaza a la 9).
*   - Con un empleador: la del F102 si la hay y es > 0; si no, la del F107
*     (varios F107 del mismo empleador se suman).
*   Placebo: PreTaxHHI (ingreso bruto; no tiene kinks en estos valores).
*
* GRUPOS
*   todos      todos los declarantes
*   f102       todos los F102, con y sin RIMPE (composición comparable entre
*              años; f102gen pierde a los sujetos RIMPE desde 2022)
*   f102gen    F102 en régimen general (antes de 2022, todos los F102)
*   f102rimpe  F102 sujetos a RIMPE (suj_reg_rimpe_4896 = SI; desde 2022).
*              Ojo: no está verificado si base_imponible_3480 incluye el
*              ingreso RIMPE; revisar con el diccionario del F102.
*   f107       todos los asalariados con un solo empleador, con la base del
*              F107, presenten o no F102. Los empleadores reportan a todos sus
*              trabajadores, así que esta muestra no está seleccionada por la
*              obligación de declarar en el umbral 1 (fracción básica).
*   f107solo   asalariados con un solo empleador que no presentan F102: la
*              población "solo F107, un empleador", sin mezcla con la base
*              del F102 ni con la suma de varios empleadores
*   f107priv   f107 sin servidores públicos (publico_107 = 0), base del F107
*   f107pub    f107 solo servidores públicos (publico_107 = 1), base del F107
*   todospriv  todos sin servidores públicos
*   Servidor público (publico_107, de construccion_ingreso_DINA.do): tasa de
*   aporte personal al IESS de algún F107 cerca de 11,45% (privado: 9,45%).
*   Sin F107 o sin tasa se cuenta como no público.
*
* ESCALAS SALARIALES DEL SECTOR PÚBLICO ($scale_ctrl = 1)
*   Los grandes picos de la base imponible son servidores públicos y docentes
*   en la escala congelada: base = 12 x w x (1 - 0,1145); en el placebo
*   (ingreso bruto) 14 x w + SBU. En 2022, además, los valores de transición
*   de la homologación docente. Los conteos marcan los bins que contienen el
*   valor de cada grado (misma regla que el redondeo). Fuera de la ventana
*   excluida, cada bin de escala tiene su propia dummy en el contrafactual;
*   dentro, su exceso se mide con los servidores públicos del bin (n_pub
*   menos la mediana de sus vecinos) y se descuenta en b_sin_escalas.
*
* ESTIMADOR (Chetty et al. 2011; Kleven y Waseem 2013)
*   1. Declarantes en bins de ancho $delta centrados en el umbral.
*   2. Contrafactual: polinomio de orden $poly ajustado a los conteos por bin,
*      EXCLUYENDO una ventana alrededor del umbral, más dummies de números
*      redondos (bins que contienen un múltiplo de $round_bases USD). El
*      contrafactual conserva el efecto de redondeo, así que el exceso de masa
*      es neto de él.
*   3. Exceso de masa B = suma(observado - contrafactual) en la ventana;
*      b = B / contrafactual suave promedio por bin. También B_izq (exceso a la
*      izquierda, k <= 0) y B_der (masa faltante a la derecha, k > 0).
*   4. Errores estándar: bootstrap de residuos, $reps repeticiones.
*   5. Elasticidad: e = (b * delta) / ( z* * ln((1-t0)/(1-t1)) ).
*   Umbrales múltiplos de 5.000 (2022, umbral 9 = 100.000) no se pueden
*   separar del redondeo: se marcan con round_z = 1 y no entran a los
*   agrupados.
*
* REFORMA 2022 (experimento natural)
*   Hasta 2021 los gastos personales se deducían de la base; desde 2022 son una
*   rebaja del impuesto causado. Para los asalariados era casi el único canal
*   para mover la base: si su bunching venía de ahí, debe caer desde 2022.
*   Se estiman agrupados pre (< $reform_year) y post (>= $reform_year) con las
*   mismas ventanas y se prueba la diferencia de elasticidades. Lo más limpio
*   son los umbrales 1-4: en 2022 los tramos 5-8 bajaron de nivel y se creó el
*   de 37%. En 2023 la tabla cambió a mitad de año (retroactiva).
*
* RIMPE, LÍNEA DE USD 20.000
*   Negocio popular: ingresos brutos hasta 20.000; paga USD 60 fijos
*   (2022-2023) o USD 0-60 según tabla (desde 2024). Por encima: emprendedor,
*   USD 60 + 1% del excedente, más IVA y facturación electrónica. El impuesto
*   a la renta es continuo en 20.000 (pasa de 0% a 1% marginal); el salto está
*   en las obligaciones.
*   Variable: bas_imp_grav_reg_rimpe_5687 (ingresos brutos gravados RIMPE).
*   Muestra: todos los sujetos RIMPE, no solo los negocios populares (filtrar
*   por categoría cortaría la distribución en 20.000 por definición).
*   Placebos del redondeo en 20.000: ingresos empresariales brutos
*   (ingresos_aem_rie_1280) de F102 sin RIMPE desde 2022 y de todos los F102
*   antes de 2022. 20.000 es un número redondo: el exceso a la izquierda se
*   compara con los placebos; la masa faltante a la derecha no la produce el
*   redondeo.
*
* LIMITACIONES
*   - Sin restricción de integración.
*   - Con las bases falsas (n = 1000 por año) los conteos son muy pequeños;
*     los resultados solo sirven para probar el código.
*   - Se asume que el año de los archivos es el ejercicio fiscal.
*
* Salidas ($dir_out):
*   bunching_resultados.dta         umbrales: año/período x grupo x variable x kink
*   bunching_reforma2022.dta        diferencias pre/post 2022
*   bunching_rimpe20000.dta         línea de 20.000 del RIMPE
*   bunching_rimpe_categorias.dta   categorías RIMPE y declaración simplificada, por año
*   bunching_umbral1_asimetrico.dta umbral 1, ventana excluida simétrica vs asimétrica
*   bunching_bohne_nimczik.dta      réplica de Bohne y Nimczik (2025), figura 2
*   bunching_bohne_figura1.dta      conteos de la figura 1 (base vs ingreso antes de gastos)
*   bunching_contabilidad.dta       umbrales de la obligación de llevar contabilidad
*   bunching_contabilidad_conteos.dta  declarantes cerca de cada umbral, por año
*   bunching_resultados.xlsx        hojas kinks, reforma_2022, rimpe_20000,
*                                   umbral1_asim, bohne_nimczik, bohne_fig1, ...
*   Graficos/ (archivos png)        histograma + contrafactual
*
* ESTRUCTURA (cada sección se puede correr sola después de las secciones 0-2,
* que solo definen globals; la primera línea de cada sección dice qué
* archivos de secciones anteriores necesita)
*   0-2  Parámetros, rutas, tablas del impuesto y ventanas por año y kink
*   3    Bases por año y conteos por bin         -> $dir_tmp/cnt_*, rim_*, casos_anual
*   4    Conteos agrupados de los umbrales       -> $dir_tmp/cnt_pool_*, casos_agrupado
*   5    Conteos de la línea de 20.000 (RIMPE)   -> $dir_tmp/rim_pool_*, casos_rimpe
*   5b   Casos de los umbrales de contabilidad   -> $dir_tmp/cl_pool_*, casos_contab
*   6    Estimación de cada caso (+ gráficos)    -> $dir_tmp/casos, estimaciones
*   7    Resultados finales y exportación        -> $dir_out
*   Un "caso" es un histograma (conteos por bin) a estimar; la lista de casos
*   guarda todo lo necesario para estimarlo y reportarlo.
*******************************************************************************/

clear all
set more off
set linesize 160
set seed 20260928

* ============================================================================
* 0. PARÁMETROS
* ============================================================================

global real_data    1        // 0 = bases falsas (Mac);  1 = bases reales (servidor SRI)
global years        "2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"  // los que no existan se omiten

global delta        50       // ancho del bin (USD)
global maxwin       2000     // semiancho máximo de la ventana de análisis (USD)
global excl_bins    4        // bins excluidos a cada lado del umbral
global poly         5        // orden del polinomio contrafactual
global reps         200      // repeticiones del bootstrap de residuos
global boot_personas 1       // 1 = también bootstrap de personas (EE se_b_pers; sección 6.4b)

* Robustez (sección 6.0 y 7.6): se reestiman los casos de la base imponible
* (variable base) de los grupos $rob_grupos, anuales y agrupados todo/pre/post,
* cambiando UN parámetro a la vez desde la especificación principal ($poly,
* $excl_bins, $maxwin). Solo bootstrap de residuos. Salida:
* bunching_robustez.dta y hoja "robustez".
global robustez     1        // 1 = estimar la robustez; 0 = no
global rob_poly     "3 5 7"            // orden del polinomio
global rob_excl     "2 4 6"            // bins excluidos a cada lado
global rob_maxwin   "1500 2000 2500"   // semiancho máximo de la ventana (USD)
global rob_grupos   "todos f102 f107 f107solo f107priv f107pub todospriv"
global minobs       100      // mínimo de observaciones en la ventana para estimar

* Umbral 1 con ventana excluida asimétrica (sección 6.0b y 7.8). Bohne y
* Nimczik (2025, SJE) muestran que los asalariados usan los gastos personales
* para quedar hasta USD 1.000 por debajo de la fracción básica: el exceso se
* reparte en esos USD 1.000 y la ventana simétrica de +/- $excl_bins bins lo
* absorbe en el contrafactual. Se reestima el umbral 1 excluyendo $asim_lo
* bins a la izquierda y $asim_hi a la derecha. Como el umbral 1 no tiene
* vecino a la izquierda, la ventana izquierda llega a $maxwin (KL_YYYY_1),
* no al 45% de la distancia al umbral 2.
global asim_izq     1        // 1 = estimar el umbral 1 con ventana asimétrica
global asim_lo      20       // bins excluidos a la izquierda (USD 1.000)
global asim_hi      4        // bins excluidos a la derecha
global asim_grupos  "todos f102 f107 f107solo f107priv todospriv"

* Réplica de Bohne y Nimczik (2025), figura 1 y 2 (sección 3.6 y 7.9):
* asalariados privados (F107, publico == 0, todos sus empleadores).
*   Potenciales: ingreso antes de gastos personales en (Z, 2Z], Z = umbral 1
*   Bunchers   : potenciales con base imponible en (Z - $bn_win, Z]
* Ingreso antes de gastos personales, dos versiones: grav_107 (sueldos +
* sobresueldos + utilidades - aporte IESS) y base + gp_107 (hasta 2021).
global bn_win       1000     // ventana bajo el umbral 1 (USD)
global fig_lo       -6000    // rango de la figura, en USD respecto del umbral 1
global fig_hi       12000
global make_graphs  1        // 1 = exportar gráficos
global round_bases  "500 1000"   // dummies de números redondos ("" = sin control)

* Picos: bins con muchos más declarantes que sus vecinos en un valor que no es
* redondo (p. ej. escalas salariales de un mismo empleador). Un bin es pico si
* n > $pico_ratio x la mediana de sus $pico_vec vecinos a cada lado. Los picos
* fuera de la ventana excluida reciben su propia dummy en el contrafactual; los
* de dentro se reportan (no se pueden separar del bunching). Solo se evalúan
* bins cuyos vecinos tienen una mediana de al menos $pico_min declarantes.
global pico_ratio   3
global pico_vec     5
global pico_min     20       // mediana mínima de los vecinos (con pocos casos el ruido parece pico)
global pico_emp     0.5      // pico de "escala salarial": un empleador tiene más de esta parte del bin

global reform_year  2022     // gastos personales pasan de deducción a rebaja
global rimpe_start  2022     // primer ejercicio del RIMPE

* Línea de 20.000 del RIMPE
global rimpe_z      20000
global rimpe_delta  100      // ancho del bin (USD)
global rimpe_K      30       // bins a cada lado (+/- 3.000)
global rimpe_lo     5        // bins excluidos a la izquierda (USD 500)
global rimpe_hi     10       // bins excluidos a la derecha (USD 1.000)

* Umbrales de la obligación de llevar contabilidad (personas naturales con
* actividad económica; sección 3.7, 5b y 7.10). La obligación nace si en el
* ejercicio ANTERIOR se supera cualquiera de tres umbrales, así que se busca
* acumulación debajo de cada umbral en el ejercicio corriente (notch: costo
* de llevar contabilidad). Umbrales (fuentes: guías prácticas del SRI 2013 y
* 2016; Ley Orgánica para la Reactivación de la Economía, dic. 2017):
*   2010-2014: ingresos 100.000, capital propio 60.000, costos y gastos 80.000
*   2015-2017: 15, 9 y 12 fracciones básicas (FB del mismo ejercicio)
*   2018-    : 300.000, 180.000 y 240.000
*   Además, 300.000 de ingresos es el tope del régimen de microempresas
*   (2020-2021, 2% de los ingresos brutos, hasta 9 trabajadores) y de RIMPE
*   emprendedores (2022-). En 300.000: r1819 = solo contabilidad, r2021 = +
*   microempresas, r2224 = + RIMPE.
* Líneas (una por umbral y variable): i = ingresos (cont_ing), c = costos y
* gastos (cont_cyg), k = capital (cont_cap: solo lo reportan quienes llevan
* contabilidad, así que debajo del umbral casi no hay datos; se reporta pero
* no se puede interpretar como bunching), s = ingresos entre quienes no
* superan el umbral de costos del mismo año (cont_cyg <= umbral de la línea
* $cl_sc_L): sin el otro gatillo medible, el de ingresos es el que importa.
*   cl_v_L   variable;  cl_z_L umbral fijo (USD) o cl_m_L FB (umbral = m x FB)
*   cl_d_L   ancho del bin (0,5% del umbral);  cl_sc_L línea de costos de "s"
*   cl_pers_L periodos;  cl_y_L_<periodo> años de cada periodo
*   real = años con el umbral vigente; plac = años sin él (placebo, el mismo
*   umbral nominal o el mismo múltiplo de la FB): para 300.000, 2010-2017;
*   para 100.000, 2015-2024; para las FB, 2010-2014 y 2018-2024.
* Ventana: +/- $cl_K bins (15%); excluidos $cl_lo a la izquierda (2,5%) y
* $cl_hi a la derecha (5%), como en la línea de 20.000 del RIMPE. Dummies de
* redondeo: múltiplos de $cl_rscale x R (con bins de USD 300-1.500 casi todos
* los bins contienen un múltiplo de 500 o 1.000). 300.000, 100.000, etc. son
* números redondos: el placebo con el mismo umbral nominal descuenta el
* redondeo en el propio umbral.
global contab       1        // 1 = analizar los umbrales de contabilidad
global cl_K         30
global cl_lo        5
global cl_hi        10
global cl_rscale    10
global cl_lineas    "i300 c240 k180 s300 i100 c80 k60 s100 i15fb c12fb k9fb s15fb"
global cl_y_post    "2018 2019 2020 2021 2022 2023 2024"
global cl_y_pre17   "2010 2011 2012 2013 2014 2015 2016 2017"
global cl_y_1014    "2010 2011 2012 2013 2014"
global cl_y_15on    "2015 2016 2017 2018 2019 2020 2021 2022 2023 2024"
global cl_y_1517    "2015 2016 2017"
global cl_y_nofb    "2010 2011 2012 2013 2014 2018 2019 2020 2021 2022 2023 2024"
foreach L in i300 c240 k180 s300 {
    global cl_pers_`L'   "real plac"
    global cl_y_`L'_real "$cl_y_post"
    global cl_y_`L'_plac "$cl_y_pre17"
}
foreach L in i300 s300 {
    global cl_pers_`L'    "real plac r1819 r2021 r2224"
    global cl_y_`L'_r1819 "2018 2019"
    global cl_y_`L'_r2021 "2020 2021"
    global cl_y_`L'_r2224 "2022 2023 2024"
}
foreach L in i100 c80 k60 s100 {
    global cl_pers_`L'   "real plac"
    global cl_y_`L'_real "$cl_y_1014"
    global cl_y_`L'_plac "$cl_y_15on"
}
foreach L in i15fb c12fb k9fb s15fb {
    global cl_pers_`L'   "real plac"
    global cl_y_`L'_real "$cl_y_1517"
    global cl_y_`L'_plac "$cl_y_nofb"
}
global cl_v_i300 "cont_ing"
global cl_v_c240 "cont_cyg"
global cl_v_k180 "cont_cap"
global cl_v_s300 "cont_ing"
global cl_v_i100 "cont_ing"
global cl_v_c80  "cont_cyg"
global cl_v_k60  "cont_cap"
global cl_v_s100 "cont_ing"
global cl_v_i15fb "cont_ing"
global cl_v_c12fb "cont_cyg"
global cl_v_k9fb  "cont_cap"
global cl_v_s15fb "cont_ing"
global cl_z_i300 300000
global cl_z_c240 240000
global cl_z_k180 180000
global cl_z_s300 300000
global cl_z_i100 100000
global cl_z_c80  80000
global cl_z_k60  60000
global cl_z_s100 100000
global cl_m_i15fb 15
global cl_m_c12fb 12
global cl_m_k9fb  9
global cl_m_s15fb 15
global cl_d_i300 1500
global cl_d_c240 1200
global cl_d_k180 900
global cl_d_s300 1500
global cl_d_i100 500
global cl_d_c80  400
global cl_d_k60  300
global cl_d_s100 500
global cl_d_i15fb 800
global cl_d_c12fb 700
global cl_d_k9fb  500
global cl_d_s15fb 800
global cl_sc_s300  "c240"
global cl_sc_s100  "c80"
global cl_sc_s15fb "c12fb"

* Si un año no tiene tabla propia en tablas_impuesto_renta.do, usar la del 2026
* (1) o omitir el año (0). Con 1 se aplican umbrales 2026 NOMINALES: solo para
* pruebas.
global fallback2026 0

* Grupos: condición de muestra (gc_) y variable de base imponible (gv_)
global groups       "todos f102 f102gen f102rimpe f107 f107solo f107priv f107pub todospriv"
global gc_todos     "1 == 1"
global gc_f102      "has102 == 1"
global gc_f102gen   "has102 == 1 & rimpe == 0"
global gc_f102rimpe "has102 == 1 & rimpe == 1"
global gc_f107      "n_emp == 1"
global gc_f107solo  "has102 == 0 & n_emp == 1"
global gc_f107priv  "n_emp == 1 & publico == 0"
global gc_f107pub   "n_emp == 1 & publico == 1"
global gc_todospriv "publico == 0"
global gv_todos     "base_imp"
global gv_f102      "base_imp"
global gv_f102gen   "base_imp"
global gv_f102rimpe "base_imp"
global gv_f107      "base107"
global gv_f107solo  "base_imp"
global gv_f107priv  "base107"
global gv_f107pub   "base107"
global gv_todospriv "base_imp"

* Escalas salariales del sector público: dummies en los bins que contienen un
* valor conocido de la escala (sección 3.4) y exceso de los servidores públicos
* en los de la ventana excluida (sección 6). 1 = con control, 0 = sin control
* (resultados iguales a la versión sin escalas).
global scale_ctrl   1

* Escala general de remuneraciones mensuales unificadas (LOSEP, 20 grados;
* USD nominales). Grados y valores en el mismo orden. Para otra escala en un
* año, global escala_YYYY con los 20 valores en el mismo orden; si no, se usa
* $escala. Fuentes (búsqueda del 02/10/2026):
*   - 2012 en adelante: Acuerdo Ministerial MRL No. 22 (R.O. 133, 27/01/2012):
*     S1-S2 527 553, A1-A4 585 622 675 733, SP1-SP10 817 ... 2.308 y
*     SP11-SP14 2.472 2.641 2.967 3.542 (copia del acuerdo en slideshare
*     "losep-art-sueldo-unificado-servidores-publicos"; tabla "Escala-20-grados"
*     del GAD Montúfar). Los grados 1-16 siguen iguales en 2023-2024 (rol LOTAIP
*     de la Supercias, julio 2023; tabla del MDT 2024). Verificados con los
*     datos (picos en 2023 y 2024): SP1-SP6.
*   - 2010-2011: Acuerdos MRL-2010-00022 y MRL-2011-000020 (tabla del SRI,
*     biblioteca alfresco): 500 525 555 590 640 695, SP1-SP10 775 855 935 1.030
*     1.150 1.340 1.590 1.670 1.930 2.190, SP11-SP13 2.345 2.505 2.815; sin
*     SP14 (se pone 0, que no cae en ninguna ventana). Sin verificar con los
*     datos.
*   - Valores reducidos de SP11-SP14 (2.358 2.408 2.670 3.188): en el rol de
*     la Supercias (julio 2023) SP12 y SP13 aparecen con los dos valores
*     (2.641 y 2.408; 2.967 y 2.670), marcados "DCTO 135" (Decreto Ejecutivo
*     135, septiembre 2017, austeridad): al parecer, los puestos nuevos con el
*     valor reducido y los antiguos con el anterior. No se encontró el acuerdo
*     del MDT ni la fecha exacta (fines de 2017 o 2018). Por eso se usan LAS
*     DOS: $escala (todos los años) y los grados reducidos $escala2 desde
*     $escala2_desde. SP15 3.848 y SP16 4.500 no aparecen en ninguna tabla
*     oficial de 20 grados (probablemente grados del nivel jerárquico
*     superior); no se usan. Solo afectan bases de más de USD 25.000.
global escala_grados "S1 S2 A1 A2 A3 A4 SP1 SP2 SP3 SP4 SP5 SP6 SP7 SP8 SP9 SP10 SP11 SP12 SP13 SP14"
global escala        "527 553 585 622 675 733 817 901 986 1086 1212 1412 1676 1760 2034 2308 2472 2641 2967 3542"
global escala_2010   "500 525 555 590 640 695 775 855 935 1030 1150 1340 1590 1670 1930 2190 2345 2505 2815 0"
global escala_2011   "$escala_2010"
* Grados con el valor reducido del Decreto 135 (desde $escala2_desde; "" en
* escala2_grados = sin ellos)
global escala2_grados "SP11b SP12b SP13b SP14b"
global escala2        "2358 2408 2670 3188"
global escala2_desde  2018

* Aporte personal al IESS del sector público (11,45%; privado: 9,45%).
* Base imponible de un servidor sin otros ingresos = 12 x w x (1 - $iess_pub)
* (décimos y fondo de reserva no se gravan). Ingreso bruto (placebo,
* PreTaxHHI) = 12 x w + décimo tercero (w) + décimo cuarto (SBU) + fondo de
* reserva (w) = 14 x w + SBU.
global iess_pub     0.1145

* Bandas de la tasa de aporte personal al IESS para el diagnóstico de la
* sección 3.1b. La pública debe ser la misma de construccion_ingreso_DINA.do
* (bloque 3.2b, iess_pub_lo/hi), que es la que define publico_107.
global iess_pub_lo  0.110
global iess_pub_hi  0.125    // 0,119 hasta la corrida del 5 oct. 2026 (decisión 14)
global iess_priv_lo 0.090
global iess_priv_hi 0.099

* Militares y policías (ISSFA, ISSPOL). Ley de Fortalecimiento de los
* Regímenes de Seguridad Social de las FF.AA. y la Policía Nacional (R.O. S.
* 867, 21/10/2016): aporte personal 11,45% para los que ingresan desde la
* reforma (ya caen en la banda pública) y 23% (FF.AA.) / 23,10% (Policía)
* para los anteriores (antes de 2016, todos). SIN VERIFICAR: si el F107
* reporta esos aportes en el campo de aporte personal al IESS (no se encontró
* en el instructivo del SRI). Si los reporta, los antiguos no son públicos
* con la banda de 11,45%. fuerzas_107 = 1 los suma a publico con la tasa
* del F107 de la base más alta (tasa_iess_107) en [$fuerzas_lo, $fuerzas_hi].
* Por defecto 0; revisar antes la hoja diag_iess (pico cerca de 23%).
global fuerzas_107  0
global fuerzas_lo   0.225
global fuerzas_hi   0.236

* Salario básico unificado (USD mensuales) por año
global sbu_2010 240
global sbu_2011 264
global sbu_2012 292
global sbu_2013 318
global sbu_2014 340
global sbu_2015 354
global sbu_2016 366
global sbu_2017 375
global sbu_2018 386
global sbu_2019 394
global sbu_2020 400
global sbu_2021 400
global sbu_2022 425
global sbu_2023 450
global sbu_2024 460

* Docentes: homologación salarial con efecto desde los últimos 3 días de
* octubre de 2022. Salario anterior -> nuevo por categoría (A-J). En $doc_anio
* un docente cobró ~$doc_m_viejo meses con el salario anterior y
* ~$doc_m_nuevo con el nuevo: base = (9,9 x viejo + 2,1 x nuevo) x
* (1 - $iess_pub); ingreso bruto = W x 14/12 + SBU con W = 9,9 x viejo +
* 2,1 x nuevo. Son posiciones adicionales solo en $doc_anio. Desde 2023 los
* salarios nuevos coinciden con la escala general y antes de 2022 los
* anteriores también (ya están en $escala).
global doc_anio     2022
global doc_cat      "A B C D E F G H I J"
global doc_viejo    "1676 1412 1212 1086 986 901 817 733 675 527"
global doc_nuevo    "2034 1760 1676 1412 1212 1086 986 817 817 817"
global doc_m_viejo  9.9
global doc_m_nuevo  2.1

* Nombres de las dummies de escala: esc_<grado> y doc_<categoría>
global evars ""
foreach gr in $escala_grados $escala2_grados {
    global evars "$evars esc_`gr'"
}
foreach ct of global doc_cat {
    global evars "$evars doc_`ct'"
}

* Series de la línea de 20.000: condición de muestra (sc_), variable (sv_)
* y años en que existe (sy_: post = desde $rimpe_start, pre = antes; sl_ =
* lista explícita de años, si no está vacía)
* Composición (guía de llenado del SRI): en 2022-2023 los negocios populares
* con ingresos <= 20.000 y solo actividades RIMPE presentan una declaración
* simplificada SIN ingresos (rimpe_simpl = 1), así que no aparecen en
* rimpe_bruto; desde 2024 la declaración simplificada sí pide los ingresos.
* Por eso "rimpe" mezcla poblaciones distintas entre 2022-2023 y 2024:
*   rim_emp   emprendedores (siempre declaran ingresos): misma población
*             todos los años, la comparación limpia en el tiempo
*   rim_np    negocios populares desde 2024 (todos declaran ingresos)
*   rim_npc   negocios populares con declaración completa, 2022-2023
*             (actividades fuera del RIMPE o información del SRI): grupo
*             seleccionado
* rim_tipo (1 = emprendedor, 2 = negocio popular) sale de rimpe_cat. Los
* códigos de rimpe_cat (0-3) no están documentados: si $rimpe_cod_emp o
* $rimpe_cod_np están vacíos se identifican cada año (sección 3.5b): negocio
* popular = el código más frecuente entre quienes presentaron la declaración
* simplificada (o, sin ella, entre los RIMPE con ingresos de 0 a 20.000 que
* no tienen el código de emprendedor); emprendedor = el más frecuente entre
* los RIMPE con ingresos > 20.000. Revisar la hoja rimpe_categorias.
global rimpe_cod_emp ""
global rimpe_cod_np  ""
global series        "rimpe rim_emp rim_np rim_npc plac_post plac_pre"
global sc_rimpe      "has102 == 1 & rimpe == 1"
global sc_rim_emp    "has102 == 1 & rimpe == 1 & rim_tipo == 1"
global sc_rim_np     "has102 == 1 & rimpe == 1 & rim_tipo == 2"
global sc_rim_npc    "has102 == 1 & rimpe == 1 & rim_tipo == 2"
global sc_plac_post  "has102 == 1 & rimpe == 0"
global sc_plac_pre   "has102 == 1"
global sv_rimpe      "rimpe_bruto"
global sv_rim_emp    "rimpe_bruto"
global sv_rim_np     "rimpe_bruto"
global sv_rim_npc    "rimpe_bruto"
global sv_plac_post  "emp_bruto"
global sv_plac_pre   "emp_bruto"
global sy_rimpe      "post"
global sy_rim_emp    "post"
global sy_rim_np     "post"
global sy_rim_npc    "post"
global sy_plac_post  "post"
global sy_plac_pre   "pre"
global sl_rim_np     "2024 2025 2026"
global sl_rim_npc    "2022 2023"
* Series con casos por año (además del agrupado)
global series_anual  "rimpe rim_emp rim_np rim_npc"

* Dummies de redondeo: una variable rR por base R (el bin contiene un
* múltiplo de R USD)
global rvars ""
foreach R of global round_bases {
    global rvars "$rvars r`R'"
}

* Variables de la lista de casos (una fila por histograma a estimar):
*   tipo kink/rimpe; serie (solo RIMPE); anio (0 = agrupado); periodo;
*   grupo; variable; kink; round_z; zstar, t0, t1, delta, nwin (se reportan);
*   K = semiancho en bins; [-lo, hi] = ventana excluida (bins);
*   z_graf = centro del eje x del gráfico; archivo = conteos por bin;
*   grafico ("" = sin gráfico), titulo y xtitulo del gráfico.
global casos_vars str6(tipo) str10(serie) int(anio) str8(periodo)            ///
    str10(grupo) str8(variable) byte(kink round_z) double(zstar t0 t1 delta) ///
    long(nwin) int(K lo hi) double(z_graf) str500(archivo grafico)          ///
    str100(titulo xtitulo)

* ============================================================================
* 1. RUTAS
* ============================================================================

* dir_merged: carpeta con ingreso_dina_YYYY.dta (construccion_ingreso_DINA.do,
* Papers/Desigualdad ingreso), que ya trae todas las variables del F102 y del
* F107 que usa este análisis. No se leen los formularios originales.
if $real_data == 0 {
    global code_dir   "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza/Papers/Bunching/code"   // carpeta de este código
    global bunch_dir  "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Papers/Bunching/SRI/Falso"   // datos y resultados falsos: Google Drive (no van a GitHub)
    global dir_out    "$bunch_dir/Resultados"
    * Salida de construir_ingreso_dina_falso.do
    global dir_merged "$bunch_dir/SRI/03 BDD/SRI/IR/Merged/ingreso_dina"
}
else {
    * Mismas rutas que construccion_ingreso_DINA.do en el servidor
    global sri_dir    "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso"
    global dir_merged "$sri_dir/03 BDD/SRI/IR/Merged/ingreso_dina"
    * Proyecto en el servidor (resultados de la corrida del 29/09/2026)
    global proy_dir   "$sri_dir/Proyectos/Bunching"
    global code_dir   "$proy_dir"          // carpeta con bunching_renta.do y tablas_impuesto_renta.do
    global dir_out    "$proy_dir/Resultados"
}

global dir_graf "$dir_out/Graficos"
global dir_tmp  "`c(tmpdir)'/bunching_conteos"   // temporal, fuera de Drive

capture mkdir "$dir_out"
capture mkdir "$dir_graf"
capture mkdir "$dir_tmp"

capture log close
log using "$dir_out/bunching_renta.log", replace text

* ============================================================================
* 2. TABLAS DEL IMPUESTO A LA RENTA Y VENTANAS POR AÑO Y KINK
* ============================================================================

* --- 2.1 Tablas: globals thr_YYYY, rate_YYYY, r8, r9 (umbrales 2010-2026,
*         con fuentes, en tablas_impuesto_renta.do) ---
include "$code_dir/tablas_impuesto_renta.do"

* --- 2.2 Umbral, tasas y ventana de cada año y kink ---
*   Globals por año:        nk_YYYY (número de umbrales), skip_YYYY (1 = sin tabla)
*   Globals por año y kink: zs_ (umbral), t0_ y t1_ (tasas debajo y encima),
*                           rz_ (1 = múltiplo de 5.000), K_ (semiancho en bins)
*   La ventana de cada kink se limita al 45% de la distancia al umbral vecino
*   más cercano para no mezclar kinks. Kpool_j = ventana común de los
*   agrupados (la más angosta entre años).

global KLpool_1 = 9999
forvalues j = 1/9 {
    global Kpool_`j' = 9999
    foreach m of global rob_maxwin {
        global Km_0_`j'_`m' = 9999
    }
}

foreach yr of global years {

    global skip_`yr' 0
    local ty `yr'
    if "${thr_`yr'}" == "" {
        if $fallback2026 == 1 {
            local ty 2026
            di as error "  ADVERTENCIA: sin tabla propia para `yr'; se usan umbrales 2026 nominales."
        }
        else {
            di as error "  Año `yr' omitido: no hay tabla en la sección 2 (fallback2026 = 0)."
            global skip_`yr' 1
            continue
        }
    }

    local nk : word count ${thr_`ty'}
    global nk_`yr' = `nk'

    forvalues j = 1/`nk' {
        local z`j' : word `j' of ${thr_`ty'}
    }

    forvalues j = 1/`nk' {
        * Distancia al umbral vecino más cercano (el primero se compara con 0)
        local gap = `z`j''
        if `j' > 1 {
            local jm = `j' - 1
            local gap = `z`j'' - `z`jm''
        }
        if `j' < `nk' {
            local jp = `j' + 1
            local gap = min(`gap', `z`jp'' - `z`j'')
        }
        local jn = `j' + 1
        global K_`yr'_`j'  = floor(min($maxwin, 0.45 * `gap') / $delta)
        global zs_`yr'_`j' = `z`j''
        global rz_`yr'_`j' = mod(`z`j'', 5000) == 0
        global t0_`yr'_`j' : word `j'  of ${rate_`ty'}
        global t1_`yr'_`j' : word `jn' of ${rate_`ty'}
        global Kpool_`j' = min(${Kpool_`j'}, ${K_`yr'_`j'})

        * Robustez de la ventana: Km_YYYY_j_m = semiancho con maxwin = m;
        * Km_0_j_m = el de los agrupados (el más angosto entre años).
        * Kc_YYYY_j = semiancho de los conteos de la base (sección 3.4): el
        * más ancho de los dos, para estimar todas las ventanas con los
        * mismos archivos sin recontar (la sección 6 corta en K)
        global Kc_`yr'_`j' = ${K_`yr'_`j'}
        if $robustez == 1 {
            foreach m of global rob_maxwin {
                global Km_`yr'_`j'_`m' = floor(min(`m', 0.45 * `gap') / $delta)
                global Kc_`yr'_`j' = max(${Kc_`yr'_`j'}, ${Km_`yr'_`j'_`m'})
                global Km_0_`j'_`m' = min(${Km_0_`j'_`m'}, ${Km_`yr'_`j'_`m'})
            }
        }

        * Umbral 1: semiancho de la ventana izquierda para la ventana excluida
        * asimétrica (sin umbral vecino a la izquierda: hasta $maxwin)
        if `j' == 1 {
            global KL_`yr'_1 = floor(min($maxwin, 0.45 * `z1') / $delta)
            global KLpool_1 = min(${KLpool_1}, ${KL_`yr'_1})
            if $asim_izq == 1 global Kc_`yr'_1 = max(${Kc_`yr'_1}, ${KL_`yr'_1})
        }
    }
}

* Kc_0_j = semiancho de los conteos agrupados de la base (sección 4)
forvalues j = 1/9 {
    global Kc_0_`j' = ${Kpool_`j'}
    if $robustez == 1 {
        foreach m of global rob_maxwin {
            if ${Km_0_`j'_`m'} < 9999 global Kc_0_`j' = max(${Kc_0_`j'}, ${Km_0_`j'_`m'})
        }
    }
}
if $asim_izq == 1 & ${Kpool_1} < 9999 global Kc_0_1 = max(${Kc_0_1}, ${KLpool_1})

* --- 2.3 Placebo "base_ant": umbrales del año anterior ---
*   Se prueba la base imponible del año en los umbrales de la tabla del año
*   anterior. Si el bunching responde a la tabla vigente, no debería haber
*   exceso ahí. Solo cuando el umbral anterior está lejos de todos los umbrales
*   vigentes: ventana = 45% de la distancia al umbral vigente más cercano, y al
*   menos $excl_bins + 15 bins (en la práctica, 2022 y 2023, cuando la tabla
*   cambió de estructura).
*   Globals: pnk_YYYY (umbrales del año anterior), pz_ (umbral), pK_ (ventana;
*   . = no se usa), prz_ (múltiplo de 5.000), pt0_/pt1_ (tasas), pKpool_j.

forvalues j = 1/9 {
    global pKpool_`j' = 9999
}

foreach yr of global years {

    global pnk_`yr' = 0
    if ${skip_`yr'} continue
    local ya = `yr' - 1
    if "${thr_`ya'}" == "" continue
    local ty = cond("${thr_`yr'}" == "", 2026, `yr')

    local nka : word count ${thr_`ya'}
    global pnk_`yr' = `nka'

    forvalues j = 1/`nka' {
        local zp : word `j' of ${thr_`ya'}
        local dmin = .
        foreach zc of global thr_`ty' {
            local dmin = min(`dmin', abs(`zp' - `zc'))
        }
        local Kp = floor(min($maxwin, 0.45 * `dmin') / $delta)
        local jn = `j' + 1
        global pz_`yr'_`j'  = `zp'
        global pK_`yr'_`j'  = cond(`Kp' >= $excl_bins + 15, `Kp', .)
        global prz_`yr'_`j' = mod(`zp', 5000) == 0
        global pt0_`yr'_`j' : word `j'  of ${rate_`ya'}
        global pt1_`yr'_`j' : word `jn' of ${rate_`ya'}
        if ${pK_`yr'_`j'} < . global pKpool_`j' = min(${pKpool_`j'}, ${pK_`yr'_`j'})
    }
}

* ============================================================================
* 3. BASES POR AÑO Y CONTEOS POR BIN
*
*   Para cada año: arma la base imponible, cuenta declarantes por bin
*   alrededor de cada umbral (grupo x variable x kink) y alrededor de la línea
*   de 20.000 del RIMPE. Cada conteo es la grilla completa k = -K..K de bins
*   de ancho delta centrados en el umbral (k = 0; bins vacíos con n = 0), más
*   las dummies de redondeo. Los conteos de los umbrales se registran como
*   casos en $dir_tmp/casos_anual.dta.
*   Requiere: secciones 0-2 y $dir_merged/ingreso_dina_YYYY.dta.
* ============================================================================

* Borrar conteos de corridas anteriores (no mezclar parámetros distintos)
local oldfiles : dir "$dir_tmp" files "*.dta"
foreach f of local oldfiles {
    erase "$dir_tmp/`f'"
}

capture postclose h_casos
postfile h_casos $casos_vars using "$dir_tmp/casos_anual.dta", replace
capture postclose h_iess
postfile h_iess int(anio) str24(tramo) double(desde hasta) long(n) double(share) ///
    using "$dir_tmp/diag_iess.dta", replace
capture postclose h_rcat
postfile h_rcat int(anio) int(rimpe_cat) byte(rimpe_simpl) long(n n_ing n_le20 n_gt20) ///
    double(p50) int(cod_emp cod_np) using "$dir_tmp/rimpe_categorias.dta", replace
capture postclose h_cl
postfile h_cl int(anio) str6(linea) double(zstar) long(n_win n_5pct n_izq n_der n_oblig_win) ///
    using "$dir_tmp/contab_conteos.dta", replace
capture postclose h_bn
postfile h_bn int(anio) double(zstar) long(n_priv n_pot_g n_bun_g n_pot_p n_bun_p) ///
    double(share_g share_p share_gp sh_id_gp sh_id_sin)                          ///
    using "$dir_tmp/bohne.dta", replace

foreach yr of global years {

    if ${skip_`yr'} continue

    capture confirm file "$dir_merged/ingreso_dina_`yr'.dta"
    if _rc {
        di as error "  `yr': no existe $dir_merged/ingreso_dina_`yr'.dta (correr construccion_ingreso_DINA.do); se omite."
        continue
    }

    di as result _n "===== Bunching `yr' ====="

    * ------------------------------------------------------------------
    * 3.1  Variables del análisis (todas vienen de ingreso_dina)
    *   base102        base imponible del F102
    *   base107_sum    suma de las bases imponibles de todos los F107
    *   n_emp_107      número de empleadores distintos en el F107
    *   rimpe          sujeto a RIMPE; rimpe_bruto, emp_bruto: ingresos brutos
    *   _merge         1 = solo F107, 2 = solo F102, 3 = ambos
    *   RUC_PK_empleador1  empleador (con un solo empleador)
    *   publico_107    servidor público (aporte personal IESS ~11,45%)
    *   gp_107         gastos personales declarados en el F107
    *   grav_107       sueldos + sobresueldos + utilidades - aporte IESS (F107)
    *   cont_ing, cont_cyg, cont_cap, cont_oblig  umbrales de contabilidad
    *                  (ingresos, costos y gastos, patrimonio; llevó contabilidad)
    * ------------------------------------------------------------------

    use CEDULA_PK PreTaxHHI _merge base102 base107_sum n_emp_107 ///
        gp_107 grav_107 cont_ing cont_cyg cont_cap cont_oblig      ///
        rimpe_cat rimpe_simpl                                      ///
        rimpe rimpe_bruto emp_bruto RUC_PK_empleador1 publico_107  ///
        tasa_iess_107 using "$dir_merged/ingreso_dina_`yr'.dta", clear

    * Empleador (un solo empleador): para medir si un pico viene de un mismo
    * empleador (escala salarial)
    gen str40 emp_id = RUC_PK_empleador1 if n_emp_107 == 1
    replace emp_id = "" if missing(emp_id)

    gen byte has102 = inlist(_merge, 2, 3)
    gen int  n_emp  = n_emp_107
    replace n_emp = 0 if missing(n_emp)
    replace rimpe = 0 if missing(rimpe) | `yr' < $rimpe_start
    gen double base107 = base107_sum if n_emp == 1
    * Servidor público: sin F107 o sin tasa de aporte se cuenta como no público
    gen byte publico = publico_107 == 1
    if $fuerzas_107 == 1 replace publico = 1 if inrange(tasa_iess_107, $fuerzas_lo, $fuerzas_hi)

    quietly count if publico == 1
    di as text "  Servidores públicos (F107): " r(N)

    * ------------------------------------------------------------------
    * 3.1b Diagnóstico de la tasa de aporte personal al IESS (tasa_iess_107,
    *      del F107 con la base más alta): conteos en bins de 0,005 entre 0
    *      y 0,25, y participación en la banda pública [$iess_pub_lo,
    *      $iess_pub_hi] (publico_107, construccion_ingreso_DINA.do), en la
    *      privada [$iess_priv_lo, $iess_priv_hi] (9,45%) y en la de
    *      ISSFA/ISSPOL (sin verificar). Sirve para revisar la banda en el
    *      servidor: si la pública no tiene un pico claro en 11,45%, o hay
    *      masa cerca de los bordes, hay que moverla. share = sobre los que
    *      tienen tasa. -> $dir_tmp/diag_iess.dta (hoja diag_iess)
    * ------------------------------------------------------------------
    quietly {
        count if !missing(tasa_iess_107)
        local ntasa = r(N)
        gen int _bt = floor(tasa_iess_107 / 0.005 + 1e-9) if !missing(tasa_iess_107)
        forvalues bb = 0/49 {
            count if _bt == `bb'
            post h_iess (`yr') ("bin") (`bb' * 0.005) ((`bb' + 1) * 0.005) (r(N)) (r(N) / `ntasa')
        }
        count if tasa_iess_107 >= 0.25 & !missing(tasa_iess_107)
        post h_iess (`yr') ("mayor_0.25") (0.25) (.) (r(N)) (r(N) / `ntasa')
        count if tasa_iess_107 < 0
        post h_iess (`yr') ("negativa") (.) (0) (r(N)) (r(N) / `ntasa')
        count if inrange(tasa_iess_107, $iess_pub_lo, $iess_pub_hi)
        post h_iess (`yr') ("banda_publica") ($iess_pub_lo) ($iess_pub_hi) (r(N)) (r(N) / `ntasa')
        count if inrange(tasa_iess_107, $iess_priv_lo, $iess_priv_hi)
        post h_iess (`yr') ("banda_privada_9.45") ($iess_priv_lo) ($iess_priv_hi) (r(N)) (r(N) / `ntasa')
        count if inrange(tasa_iess_107, $fuerzas_lo, $fuerzas_hi)
        post h_iess (`yr') ("banda_issfa_isspol") ($fuerzas_lo) ($fuerzas_hi) (r(N)) (r(N) / `ntasa')
        count if publico_107 == 1
        post h_iess (`yr') ("publico_107") (.) (.) (r(N)) (r(N) / `ntasa')
        post h_iess (`yr') ("con_tasa") (.) (.) (`ntasa') (1)
        count if missing(tasa_iess_107)
        post h_iess (`yr') ("sin_tasa") (.) (.) (r(N)) (.)
        drop _bt
    }

    * ------------------------------------------------------------------
    * 3.2  Base imponible: un empleador -> F102 si > 0, si no F107.
    *      2+ empleadores -> F102; sin F102, la suma de sus F107
    *      (base107_sum).
    * ------------------------------------------------------------------

    gen double base_imp = .
    replace base_imp = base102 if has102 == 1 & ///
        (n_emp > 1 | (base102 > 0 & !missing(base102)))
    replace base_imp = base107 if missing(base_imp) & n_emp == 1
    gen byte base_multi = missing(base_imp) & n_emp > 1 & !missing(base107_sum)
    replace base_imp = base107_sum if base_multi == 1

    quietly count if n_emp > 1
    local nmult = r(N)
    quietly count if base_multi == 1
    di as text "  Con 2+ empleadores: `nmult'  (sin F102, suma de sus F107: " r(N) ")"

    quietly count if base_imp > 0 & !missing(base_imp)
    di as text "  Declarantes con base imponible > 0: " r(N)
    if `yr' >= $rimpe_start {
        quietly count if rimpe == 1
        di as text "  Sujetos RIMPE: " r(N)
    }

    * ------------------------------------------------------------------
    * 3.4  Conteos por bin alrededor de cada umbral: grupo x variable x kink
    *      (variable: base = base imponible del grupo en los umbrales
    *       vigentes; placebo = PreTaxHHI; base_ant = base imponible en los
    *       umbrales del año anterior, sección 2.3)
    * ------------------------------------------------------------------

    foreach g of global groups {

        if "`g'" == "f102rimpe" & `yr' < $rimpe_start continue

        foreach rvlab in base placebo base_ant {

            local rv = cond("`rvlab'" == "placebo", "PreTaxHHI", "${gv_`g'}")
            local nkv = cond("`rvlab'" == "base_ant", ${pnk_`yr'}, ${nk_`yr'})

            forvalues j = 1/`nkv' {

                if "`rvlab'" == "base_ant" {
                    local K  = ${pK_`yr'_`j'}
                    local zs = ${pz_`yr'_`j'}
                    local rz = ${prz_`yr'_`j'}
                    local t0 ${pt0_`yr'_`j'}
                    local t1 ${pt1_`yr'_`j'}
                    if `K' == . continue
                }
                else {
                    local K  = ${K_`yr'_`j'}
                    local zs = ${zs_`yr'_`j'}
                    local rz = ${rz_`yr'_`j'}
                    local t0 ${t0_`yr'_`j'}
                    local t1 ${t1_`yr'_`j'}
                    if `K' < $excl_bins + 15 {
                        if "`rvlab'" == "base" di as text "  kink `j' `yr': ventana muy angosta; se omite."
                        continue
                    }
                }

                local cnt "$dir_tmp/cnt_`yr'_`g'_`rvlab'_`j'.dta"

                * Semiancho de los conteos: K, salvo la base con robustez de
                * la ventana (Kc >= K, sección 2.2); nwin se cuenta en K
                local Kc = `K'
                if "`rvlab'" == "base" local Kc = ${Kc_`yr'_`j'}

                preserve
                quietly {
                    keep if ${gc_`g'} & `rv' > 0 & !missing(`rv')
                    gen long k = round((`rv' - `zs') / $delta)
                    count if abs(k) <= `K'
                    local nwin = r(N)
                    keep if abs(k) <= `Kc'
                    local nobs = _N

                    * Un bin vacío (n = 0) por cada k de la grilla, y sumar.
                    * top_emp = participación del empleador más frecuente del
                    * bin (con un solo empleador); n_pub = servidores públicos
                    keep k emp_id publico
                    gen long n = 1
                    set obs `=`nobs' + 2 * `Kc' + 1'
                    replace k = _n - `nobs' - `Kc' - 1 if _n > `nobs'
                    replace n = 0 if _n > `nobs'
                    replace publico = 0 if _n > `nobs'
                    bysort k emp_id: gen long ne = cond(emp_id != "", _N, 0)
                    collapse (sum) n n_pub = publico (max) top_emp = ne, by(k)
                    replace top_emp = cond(n > 0, top_emp / n, .)

                    * Dummies de redondeo: el bin contiene un múltiplo de R
                    gen double x = `zs' + k * $delta
                    foreach R of global round_bases {
                        gen byte r`R' = ceil((x - $delta / 2) / `R') * `R' < x + $delta / 2
                    }

                    * Dummies de escala: el bin [x - delta/2, x + delta/2)
                    * contiene el valor anual del grado (misma regla que el
                    * redondeo). base y base_ant: 12 x w x (1 - $iess_pub);
                    * placebo: 14 x w + SBU. Docentes: valores de transición
                    * solo en $doc_anio (en los demás años doc_* = 0).
                    local esc "$escala"
                    if "${escala_`yr'}" != "" local esc "${escala_`yr'}"
                    local ig 0
                    foreach gr of global escala_grados {
                        local ++ig
                        local w : word `ig' of `esc'
                        local v = 12 * `w' * (1 - $iess_pub)
                        if "`rvlab'" == "placebo" local v = 14 * `w' + ${sbu_`yr'}
                        gen byte esc_`gr' = `v' >= x - $delta / 2 & `v' < x + $delta / 2
                    }
                    * Grados reducidos (Decreto 135), solo desde $escala2_desde
                    local ig 0
                    foreach gr of global escala2_grados {
                        local ++ig
                        local w : word `ig' of $escala2
                        local v = 12 * `w' * (1 - $iess_pub)
                        if "`rvlab'" == "placebo" local v = 14 * `w' + ${sbu_`yr'}
                        gen byte esc_`gr' = `v' >= x - $delta / 2 & `v' < x + $delta / 2 & `yr' >= $escala2_desde
                    }
                    local ig 0
                    foreach ct of global doc_cat {
                        local ++ig
                        local wv : word `ig' of $doc_viejo
                        local wn : word `ig' of $doc_nuevo
                        local W = $doc_m_viejo * `wv' + $doc_m_nuevo * `wn'
                        local v = `W' * (1 - $iess_pub)
                        if "`rvlab'" == "placebo" local v = `W' * 14 / 12 + ${sbu_`yr'}
                        gen byte doc_`ct' = `v' >= x - $delta / 2 & `v' < x + $delta / 2 & `yr' == $doc_anio
                    }
                    drop x
                    save "`cnt'", replace
                }
                restore

                * Registrar el caso (gráficos solo para todos: base y base_ant)
                local gf ""
                local tit "`yr' - umbral `j': USD `zs' (tasa `t0' a `t1')"
                if "`rvlab'" == "base_ant" {
                    local tit "`yr' - placebo: umbral `j' de `=`yr'-1' (USD `zs')"
                }
                if $make_graphs == 1 & "`g'" == "todos" & "`rvlab'" == "base" {
                    local gf "$dir_graf/bunch_`yr'_kink`j'.png"
                }
                if $make_graphs == 1 & "`g'" == "todos" & "`rvlab'" == "base_ant" {
                    local gf "$dir_graf/bunch_`yr'_kink`j'_umbral_anterior.png"
                }
                post h_casos ("kink") ("") (`yr') ("anual") ("`g'") ("`rvlab'")  ///
                    (`j') (`rz') (`zs') (`t0') (`t1') ($delta) (`nwin')          ///
                    (`K') ($excl_bins) ($excl_bins) (`zs') ("`cnt'") ("`gf'")    ///
                    ("`tit'") ("Base imponible (USD nominales)")
            }
        }
    }

    * ------------------------------------------------------------------
    * 3.5  Conteos por bin alrededor de la línea de 20.000 del RIMPE
    *      (se registran como casos en la sección 5)
    * ------------------------------------------------------------------

    * ------------------------------------------------------------------
    * 3.5b Categorías RIMPE (desde $rimpe_start): códigos de emprendedor y
    *      negocio popular (globals o identificados con los datos) ->
    *      rim_tipo; y, por código y declaración simplificada, cuántos
    *      declaran ingresos (rimpe_bruto > 0), cuántos hasta 20.000 y
    *      cuántos más, y la mediana -> h_rcat (hoja rimpe_categorias)
    * ------------------------------------------------------------------
    gen byte rim_tipo = 0
    if `yr' >= $rimpe_start {
        local ce "$rimpe_cod_emp"
        local cn "$rimpe_cod_np"
        quietly {
            if "`ce'" == "" {
                preserve
                keep if rimpe == 1 & rimpe_bruto > $rimpe_z & !missing(rimpe_bruto, rimpe_cat)
                if _N > 0 {
                    contract rimpe_cat
                    gsort -_freq rimpe_cat
                    local ce = rimpe_cat[1]
                }
                restore
            }
            if "`cn'" == "" {
                preserve
                keep if rimpe == 1 & rimpe_simpl == 1 & !missing(rimpe_cat)
                if _N == 0 {
                    restore, preserve
                    keep if rimpe == 1 & rimpe_bruto > 0 & rimpe_bruto <= $rimpe_z & !missing(rimpe_cat)
                    if "`ce'" != "" drop if rimpe_cat == `ce'
                }
                if _N > 0 {
                    contract rimpe_cat
                    gsort -_freq rimpe_cat
                    local cn = rimpe_cat[1]
                }
                restore
            }
            if "`ce'" != "" replace rim_tipo = 1 if rimpe == 1 & rimpe_cat == `ce'
            if "`cn'" != "" & "`cn'" != "`ce'" replace rim_tipo = 2 if rimpe == 1 & rimpe_cat == `cn'
            levelsof rimpe_cat if rimpe == 1, local(cats) missing
            foreach c of local cats {
                foreach sp in 0 1 {
                    local cc = cond("`c'" == ".", "missing(rimpe_cat)", "rimpe_cat == `c'")
                    count if rimpe == 1 & `cc' & rimpe_simpl == `sp'
                    local n = r(N)
                    if `n' == 0 continue
                    count if rimpe == 1 & `cc' & rimpe_simpl == `sp' & rimpe_bruto > 0 & !missing(rimpe_bruto)
                    local ni = r(N)
                    count if rimpe == 1 & `cc' & rimpe_simpl == `sp' & rimpe_bruto > 0 & rimpe_bruto <= $rimpe_z
                    local nl = r(N)
                    count if rimpe == 1 & `cc' & rimpe_simpl == `sp' & rimpe_bruto > $rimpe_z & !missing(rimpe_bruto)
                    local ng = r(N)
                    local med = .
                    if `ni' > 0 {
                        summarize rimpe_bruto if rimpe == 1 & `cc' & rimpe_simpl == `sp' & rimpe_bruto > 0, detail
                        local med = r(p50)
                    }
                    post h_rcat (`yr') (`c') (`sp') (`n') (`ni') (`nl') (`ng') (`med') ///
                        (`=cond("`ce'" == "", ., 0`ce')') (`=cond("`cn'" == "", ., 0`cn')')
                }
            }
        }
        di as text "  RIMPE: código emprendedor = `ce', negocio popular = `cn'"
    }

    foreach s of global series {

        if "${sy_`s'}" == "post" & `yr' <  $rimpe_start continue
        if "${sy_`s'}" == "pre"  & `yr' >= $rimpe_start continue
        if "${sl_`s'}" != "" & !strpos(" ${sl_`s'} ", " `yr' ") continue

        local rv ${sv_`s'}

        preserve
        quietly {
            keep if ${sc_`s'} & `rv' > 0 & !missing(`rv')
            gen long k = round((`rv' - $rimpe_z) / $rimpe_delta)
            keep if abs(k) <= $rimpe_K
            local nwin = _N

            * Un bin vacío (n = 0) por cada k de la grilla, y sumar
            keep k
            gen long n = 1
            set obs `=`nwin' + 2 * $rimpe_K + 1'
            replace k = _n - `nwin' - $rimpe_K - 1 if _n > `nwin'
            replace n = 0 if _n > `nwin'
            collapse (sum) n, by(k)

            * Dummies de redondeo: el bin contiene un múltiplo de R
            gen double x = $rimpe_z + k * $rimpe_delta
            foreach R of global round_bases {
                gen byte r`R' = ceil((x - $rimpe_delta / 2) / `R') * `R' < x + $rimpe_delta / 2
            }
            drop x
            save "$dir_tmp/rim_`yr'_`s'.dta", replace
        }
        restore
    }

    * ------------------------------------------------------------------
    * 3.6  Réplica de Bohne y Nimczik (2025): asalariados privados (F107,
    *      publico == 0, todos sus empleadores; base = base107_sum).
    *      Ingreso antes de gastos personales:
    *        grav = grav_107 (sueldos + sobresueldos + utilidades - IESS)
    *        prep = base + gp_107 hasta 2021; desde $reform_year los gastos
    *               personales ya no reducen la base (prep = base)
    *      Z = umbral 1. Potenciales: antes de gastos en (Z, 2Z] (con el
    *      tope de 50% del ingreso podrían bajar a Z). Bunchers: potenciales
    *      con base en (Z - $bn_win, Z]. share_gp: potenciales (grav) con
    *      gastos personales > 0. Identidad: participación de los que tienen
    *      base > 0 con |grav - gp - base| <= 10 (sh_id_gp) y |grav - base|
    *      <= 10 (sh_id_sin): hasta 2021 debería dominar la primera y desde
    *      2022 la segunda; si no, revisar la definición de grav o gp.
    *      Conteos para la figura 1: bins de $delta entre $fig_lo y $fig_hi
    *      USD respecto de Z, de base, grav y prep -> $dir_tmp/fig_YYYY.dta
    * ------------------------------------------------------------------
    preserve
    quietly {
        keep if n_emp >= 1 & publico == 0
        local Z = ${zs_`yr'_1}
        gen double tax  = base107_sum
        gen double grav = grav_107
        gen double prep = base107_sum + cond(`yr' < $reform_year, gp_107, 0)
        replace prep = . if missing(base107_sum)
        count
        local n_priv = r(N)
        foreach v in g p {
            local iv = cond("`v'" == "g", "grav", "prep")
            gen byte pot_`v' = `iv' > `Z' & `iv' <= 2 * `Z' & !missing(`iv')
            gen byte bun_`v' = pot_`v' & tax > `Z' - $bn_win & tax <= `Z'
            count if pot_`v'
            local n_pot_`v' = r(N)
            count if bun_`v'
            local n_bun_`v' = r(N)
            local share_`v' = cond(`n_pot_`v'' > 0, `n_bun_`v'' / `n_pot_`v'', .)
        }
        count if pot_g & gp_107 > 0 & !missing(gp_107)
        local share_gp = cond(`n_pot_g' > 0, r(N) / `n_pot_g', .)
        count if tax > 0 & !missing(tax)
        local ntax = r(N)
        count if tax > 0 & !missing(tax) & abs(grav - gp_107 - tax) <= 10
        local sh_id_gp = cond(`ntax' > 0, r(N) / `ntax', .)
        count if tax > 0 & !missing(tax) & abs(grav - tax) <= 10
        local sh_id_sin = cond(`ntax' > 0, r(N) / `ntax', .)
        post h_bn (`yr') (`Z') (`n_priv') (`n_pot_g') (`n_bun_g') (`n_pot_p') ///
            (`n_bun_p') (`share_g') (`share_p') (`share_gp') (`sh_id_gp') (`sh_id_sin')

        * Conteos de la figura 1 (bins vacíos en 0)
        local kl = round($fig_lo / $delta)
        local kh = round($fig_hi / $delta)
        local nb = `kh' - `kl' + 1
        keep tax grav prep
        tempfile fig src
        save `src'
        local first 1
        foreach v in tax grav prep {
            use `src', clear
            gen long k = round((`v' - `Z') / $delta)
            keep if inrange(k, `kl', `kh') & `v' > 0 & !missing(`v')
            keep k
            gen long n = 1
            local nobs = _N
            set obs `=`nobs' + `nb''
            replace k = `kl' + _n - `nobs' - 1 if _n > `nobs'
            replace n = 0 if _n > `nobs'
            collapse (sum) n_`v' = n, by(k)
            if !`first' merge 1:1 k using `fig', nogen
            save `fig', replace
            local first 0
        }
        use `fig', clear
        gen int anio = `yr'
        save "$dir_tmp/fig_`yr'.dta", replace
    }
    restore
    di as text "  Bohne-Nimczik: potenciales (grav) `n_pot_g', bunchers `n_bun_g', share " %5.3f `share_g'

    * ------------------------------------------------------------------
    * 3.7  Umbrales de la obligación de llevar contabilidad ($contab = 1)
    *      Para cada línea L con año en alguno de sus periodos: umbral Z del
    *      año (fijo o m x FB), declarantes del F102 con la variable > 0 en
    *      bins de $cl_d_L alrededor de Z (+/- $cl_K bins) -> cl_YYYY_L.dta.
    *      Conteos (h_cl): en la ventana, a +/- 5% de Z, en la ventana
    *      excluida a cada lado y cuántos de la ventana llevaron contabilidad.
    * ------------------------------------------------------------------
    if $contab == 1 {
        local fb : word 1 of ${thr_`yr'}
        foreach L of global cl_lineas {
            local esta 0
            foreach p of global cl_pers_`L' {
                if strpos(" ${cl_y_`L'_`p'} ", " `yr' ") local esta 1
            }
            if !`esta' continue
            local Z = cond("${cl_z_`L'}" != "", 0${cl_z_`L'}, 0${cl_m_`L'} * `fb')
            local d = ${cl_d_`L'}
            local v ${cl_v_`L'}
            local cond "has102 == 1 & `v' > 0 & !missing(`v')"
            if "${cl_sc_`L'}" != "" {
                local Lc ${cl_sc_`L'}
                local Zc = cond("${cl_z_`Lc'}" != "", 0${cl_z_`Lc'}, 0${cl_m_`Lc'} * `fb')
                local cond "`cond' & cont_cyg <= `Zc'"
            }
            preserve
            quietly {
                keep if `cond'
                gen long k = round((`v' - `Z') / `d')
                count if abs(`v' - `Z') <= 0.05 * `Z'
                local n5 = r(N)
                keep if abs(k) <= $cl_K
                local nobs = _N
                count if inrange(k, -$cl_lo, 0)
                local nizq = r(N)
                count if inrange(k, 1, $cl_hi)
                local nder = r(N)
                count if cont_oblig == 1
                local nob = r(N)
                post h_cl (`yr') ("`L'") (`Z') (`nobs') (`n5') (`nizq') (`nder') (`nob')

                * Un bin vacío (n = 0) por cada k de la grilla, y sumar
                keep k
                gen long n = 1
                set obs `=`nobs' + 2 * $cl_K + 1'
                replace k = _n - `nobs' - $cl_K - 1 if _n > `nobs'
                replace n = 0 if _n > `nobs'
                collapse (sum) n, by(k)
                gen double x = `Z' + k * `d'
                foreach R of global round_bases {
                    local RR = $cl_rscale * `R'
                    gen byte r`R' = ceil((x - `d' / 2) / `RR') * `RR' < x + `d' / 2
                }
                drop x
                gen double zl = `Z'
                save "$dir_tmp/cl_`yr'_`L'.dta", replace
            }
            restore
        }
    }
}

postclose h_casos
postclose h_iess
postclose h_bn
postclose h_cl
postclose h_rcat

* ============================================================================
* 4. CONTEOS AGRUPADOS DE LOS UMBRALES (anio = 0): años apilados en
*    distancia al umbral. periodo: todo (todos los años), pre (< reforma),
*    post (>= reforma). Los umbrales múltiplos de 5.000 no entran.
*    Requiere: $dir_tmp/casos_anual.dta y los conteos cnt_* (sección 3).
* ============================================================================

di as result _n "===== Bunching agrupado ====="

capture postclose h_casos
postfile h_casos $casos_vars using "$dir_tmp/casos_agrupado.dta", replace

foreach g of global groups {
    foreach rvlab in base placebo base_ant {
        forvalues j = 1/9 {

            local K = cond("`rvlab'" == "base_ant", ${pKpool_`j'}, ${Kpool_`j'})
            if `K' < $excl_bins + 15 | `K' == 9999 continue
            local jn = `j' + 1
            local t0 : word `j'  of $r9
            local t1 : word `jn' of $r9

            foreach p in todo pre post {

                * Años que entran: casos anuales del mismo grupo, variable y kink
                use "$dir_tmp/casos_anual.dta", clear
                quietly keep if grupo == "`g'" & variable == "`rvlab'" & kink == `j' & round_z == 0
                if "`p'" == "pre"  quietly keep if anio <  $reform_year
                if "`p'" == "post" quietly keep if anio >= $reform_year
                if _N == 0 continue

                * Umbral promedio, ponderado por declarantes en la ventana anual
                quietly gen double zn = zstar * nwin
                quietly summarize zn, meanonly
                local zw = r(sum)
                quietly summarize nwin, meanonly
                local zbar = cond(r(sum) > 0, `zw' / r(sum), .)

                local files ""
                forvalues i = 1/`=_N' {
                    local files `"`files' "`=archivo[`i']'""'
                }

                * Apilar los conteos anuales en la ventana común. Redondeo y
                * escalas: en el agrupado cada dummy cuenta en cuántos años el
                * bin contiene un número redondo o el valor del grado; n_pub
                * suma los servidores públicos
                * Semiancho de los conteos: K, salvo la base con robustez de
                * la ventana (Kc_0_j >= K, sección 2.2); nwin se cuenta en K
                local Kc = `K'
                if "`rvlab'" == "base" local Kc = ${Kc_0_`j'}
                clear
                quietly append using `files'
                quietly keep if abs(k) <= `Kc'
                collapse (sum) n n_pub $rvars $evars, by(k)
                quietly summarize n if abs(k) <= `K', meanonly
                local nwin = r(sum)
                local pfile "$dir_tmp/cnt_pool_`p'_`g'_`rvlab'_`j'.dta"
                save "`pfile'", replace

                local gf ""
                if $make_graphs == 1 & "`rvlab'" == "base" {
                    local gf "$dir_graf/bunch_agrupado_`p'_`g'_kink`j'.png"
                }
                if $make_graphs == 1 & "`rvlab'" == "base_ant" & "`p'" == "todo" {
                    local gf "$dir_graf/bunch_agrupado_todo_`g'_kink`j'_umbral_anterior.png"
                }
                post h_casos ("kink") ("") (0) ("`p'") ("`g'") ("`rvlab'")      ///
                    (`j') (0) (`zbar') (`t0') (`t1') ($delta) (`nwin')           ///
                    (`K') ($excl_bins) ($excl_bins) (0) ("`pfile'") ("`gf'")     ///
                    ("Agrupado `p' (`g') - umbral `j'`=cond("`rvlab'"=="base_ant"," del año anterior","")'") ///
                    ("Distancia al umbral (USD nominales)")
            }
        }
    }
}

postclose h_casos

* ============================================================================
* 5. CONTEOS DE LA LÍNEA DE 20.000 DEL RIMPE
*    series: rimpe (sujetos RIMPE, 2022+), plac_post (F102 sin RIMPE, 2022+),
*    plac_pre (todos los F102, antes de 2022). Casos: por año (solo la serie
*    rimpe, con al menos $minobs declarantes) y agrupado (anio = 0).
*    Requiere: los conteos rim_* (sección 3).
* ============================================================================

di as result _n "===== RIMPE: línea de 20.000 ====="

capture postclose h_casos
postfile h_casos $casos_vars using "$dir_tmp/casos_rimpe.dta", replace

foreach s of global series {

    local xt = cond(substr("`s'", 1, 3) == "rim", "Ingresos brutos RIMPE (USD)", ///
                                      "Ingresos empresariales brutos (USD)")
    local files ""

    foreach yr of global years {
        local cnt "$dir_tmp/rim_`yr'_`s'.dta"
        capture confirm file "`cnt'"
        if _rc continue
        local files `"`files' "`cnt'""'

        * Por año: solo las series RIMPE ($series_anual)
        if strpos(" $series_anual ", " `s' ") {
            use "`cnt'", clear
            quietly summarize n, meanonly
            local nwin = r(sum)
            if `nwin' >= $minobs {
                post h_casos ("rimpe") ("`s'") (`yr') ("anual") ("") ("")     ///
                    (.) (.) ($rimpe_z) (.) (.) ($rimpe_delta) (`nwin')      ///
                    ($rimpe_K) ($rimpe_lo) ($rimpe_hi) ($rimpe_z) ("`cnt'") ///
                    ("") ("") ("")
            }
        }
    }
    if `"`files'"' == "" continue

    * Agrupado: sumar los conteos de todos los años
    clear
    quietly append using `files'
    collapse (sum) n $rvars, by(k)
    quietly summarize n, meanonly
    local nwin = r(sum)
    local pfile "$dir_tmp/rim_pool_`s'.dta"
    save "`pfile'", replace

    local gf ""
    if $make_graphs == 1 local gf "$dir_graf/rimpe20000_`s'.png"
    post h_casos ("rimpe") ("`s'") (0) ("todo") ("") ("")                ///
        (.) (.) ($rimpe_z) (.) (.) ($rimpe_delta) (`nwin')               ///
        ($rimpe_K) ($rimpe_lo) ($rimpe_hi) ($rimpe_z) ("`pfile'") ("`gf'") ///
        ("Linea de 20.000 del RIMPE - `s' (agrupado)") ("`xt'")
}

postclose h_casos

* ============================================================================
* 5b. CASOS DE LOS UMBRALES DE CONTABILIDAD ($contab = 1)
*    Por línea L y periodo p (cl_pers_L): suma de los conteos cl_YYYY_L de
*    los años del periodo (agrupado, anio = 0; distancia al umbral en bins,
*    así que las líneas en FB, cuyo umbral cambia cada año, se apilan igual).
*    Además, por año, los del periodo real. tipo = "contab", serie = L.
*    zstar = umbral promedio de los años del periodo.
*    Requiere: los conteos cl_* (sección 3.7).
* ============================================================================

capture postclose h_casos
postfile h_casos $casos_vars using "$dir_tmp/casos_contab.dta", replace
if $contab == 1 {
    di as result _n "===== Umbrales de contabilidad ====="
    foreach L of global cl_lineas {
        local d = ${cl_d_`L'}
        local vl = cond("${cl_v_`L'}" == "cont_ing", "Ingresos brutos", ///
                   cond("${cl_v_`L'}" == "cont_cyg", "Costos y gastos", "Patrimonio neto"))
        local fijo = "${cl_z_`L'}" != ""
        local zt = cond(`fijo', "USD ${cl_z_`L'}", "${cl_m_`L'} FB")
        foreach p of global cl_pers_`L' {
            local files ""
            local zsum 0
            local ny 0
            foreach yr of global cl_y_`L'_`p' {
                local cnt "$dir_tmp/cl_`yr'_`L'.dta"
                capture confirm file "`cnt'"
                if _rc continue
                local files `"`files' "`cnt'""'
                use "`cnt'", clear
                local zy = zl[1]
                local zsum = `zsum' + `zy'
                local ++ny
                quietly summarize n, meanonly
                local nwin = r(sum)
                if "`p'" == "real" & `nwin' >= $minobs {
                    post h_casos ("contab") ("`L'") (`yr') ("anual") ("contab") ("${cl_v_`L'}") ///
                        (.) (.) (`zy') (.) (.) (`d') (`nwin')                                ///
                        ($cl_K) ($cl_lo) ($cl_hi) (`zy') ("`cnt'") ("") ("") ("")
                }
            }
            if `ny' == 0 continue
            clear
            quietly append using `files'
            collapse (sum) n $rvars, by(k)
            quietly summarize n, meanonly
            local nwin = r(sum)
            local pfile "$dir_tmp/cl_pool_`p'_`L'.dta"
            save "`pfile'", replace
            local zg = cond(`fijo', `zsum' / `ny', 0)
            local xt = cond(`fijo', "`vl' (USD)", "`vl': distancia al umbral (USD)")
            local gf ""
            if $make_graphs == 1 local gf "$dir_graf/contabilidad_`L'_`p'.png"
            post h_casos ("contab") ("`L'") (0) ("`p'") ("contab") ("${cl_v_`L'}")        ///
                (.) (.) (`zsum' / `ny') (.) (.) (`d') (`nwin')                          ///
                ($cl_K) ($cl_lo) ($cl_hi) (`zg') ("`pfile'") ("`gf'")                   ///
                ("Umbral de contabilidad `zt' (`L') - `p'") ("`xt'")
        }
    }
}
postclose h_casos

* ============================================================================
* 6. ESTIMACIÓN DE CADA CASO (Chetty et al. 2011; Kleven y Waseem 2013)
*    Requiere: $dir_tmp/casos_anual, casos_agrupado y casos_rimpe (secciones
*    3-5) y sus conteos.
*
*   Con los conteos n por bin k = -K..K (ventana excluida: -lo <= k <= hi):
*   0. Picos: bin con n > $pico_ratio x la mediana de sus $pico_vec vecinos a
*      cada lado. Fuera de la ventana: una dummy propia por pico. Dentro: se
*      reportan (número, exceso sobre la mediana de sus vecinos y participación
*      del empleador más frecuente; si es alta, es una escala salarial y no
*      bunching).
*   0b. Escalas salariales ($scale_ctrl = 1; solo conteos de los umbrales):
*      bins de escala = bins con alguna dummy esc_* o doc_* > 0 (sección 3.4).
*      Fuera de la ventana: una dummy por bin de escala en el contrafactual
*      (como las de picos; en los agrupados el tamaño del pico de un grado
*      cambia entre años, ver 6.2a); esos bins no reciben además dummy de
*      pico. Dentro: exceso de escala =
*      n_pub - mediana de n_pub en sus $pico_vec vecinos a cada lado (sin el
*      propio bin, como la regla de picos), sumado en los bins de escala de la
*      ventana (B_esc_pub; puede ser negativo por ruido, no se trunca).
*      b_sin_escalas = (B - B_escalas) / c0, con B_escalas = B_esc_pub + exceso
*      de los picos de la ventana que NO son bins de escala y en los que un
*      empleador tiene más de $pico_emp del bin (regla general para picos que
*      no están en la escala). Así ningún bin se descuenta dos veces. Con
*      $scale_ctrl = 0: sin dummies de escala y B_escalas = exceso de los picos
*      de un solo empleador (versión anterior).
*   1. Contrafactual: regresión de n en un polinomio de orden $poly en k/K,
*      las dummies de redondeo, las de picos y las de escala (fuera), solo con
*      los bins fuera de la ventana. cf = predicción (con redondeo, picos y
*      escalas); cs = parte suave (solo polinomio).
*   2. En la ventana: B = suma(n - cf); c0 = promedio de cs; b = B / c0;
*      B_izq = suma(n - cf) con k <= 0; B_der = suma(cf - n) con k > 0.
*   3. Bootstrap de residuos ($reps repeticiones): ajustado completo = cf
*      fuera de la ventana y n dentro (conserva el exceso). En cada
*      repetición se sortea con reposición un residuo de los bins de fuera
*      para cada bin, nstar = ajustado + residuo, se reestima el contrafactual
*      con los bins de fuera y se recalculan los cinco estadísticos.
*      EE = desviación estándar entre repeticiones.
*   Casos con menos de $minobs declarantes: se reportan sin estimación.
* ============================================================================

use "$dir_tmp/casos_anual.dta", clear
append using "$dir_tmp/casos_agrupado.dta" "$dir_tmp/casos_rimpe.dta" "$dir_tmp/casos_contab.dta"
* pol = orden del polinomio del caso; spec/valor = especificación de robustez
* (base = principal); Kl = semiancho de la ventana a la izquierda (= K salvo
* la ventana excluida asimétrica del umbral 1, sección 6.0b)
gen int pol = $poly
gen int Kl = K
gen str8 spec = "base"
gen double valor = .
gen long id = _n
save "$dir_tmp/casos.dta", replace

* --- 6.0 Casos de robustez (tipo = "rob"; $robustez = 1) ---
*   Copias de los casos de la base imponible de $rob_grupos (anuales y
*   agrupados todo/pre/post) con UN parámetro cambiado:
*   poly   -> pol (mismos conteos)
*   excl   -> lo = hi = valor (mismos conteos); se omiten si K < valor + 15
*   maxwin -> K = Km_YYYY_j_m (anual) o Km_0_j_m (agrupado), sección 2.2.
*             Los conteos de la base ya cubren la ventana más ancha (Kc,
*             secciones 3.4 y 4), así que no se recuenta: la sección 6 corta
*             en K. En los agrupados zstar y los años que entran son los de
*             la ventana principal; nwin se recalcula (nwin_e).
*   Se agregan al final de la lista: los ids de los casos principales no
*   cambian. Sin gráficos ni bootstrap de personas.
if $robustez == 1 {
    keep if tipo == "kink" & variable == "base" & inlist(periodo, "anual", "todo", "pre", "post")
    gen byte _sel = 0
    foreach g of global rob_grupos {
        replace _sel = 1 if grupo == "`g'"
    }
    keep if _sel == 1
    drop _sel
    replace grafico = ""
    replace tipo = "rob"
    save "$dir_tmp/rob_src.dta", replace
    global nrob 0
    foreach sp in poly excl maxwin {
        local v0 = cond("`sp'" == "poly", $poly, cond("`sp'" == "excl", $excl_bins, $maxwin))
        foreach v of global rob_`sp' {
            if `v' == `v0' continue
            use "$dir_tmp/rob_src.dta", clear
            replace spec  = "`sp'"
            replace valor = `v'
            if "`sp'" == "poly" replace pol = `v'
            if "`sp'" == "excl" {
                replace lo = `v'
                replace hi = `v'
                drop if K < `v' + 15
            }
            if "`sp'" == "maxwin" {
                forvalues r = 1/`=_N' {
                    local a  = anio[`r']
                    local kk = kink[`r']
                    quietly replace K = ${Km_`a'_`kk'_`v'} in `r'
                }
                replace Kl = K
                drop if K < $excl_bins + 15 | K >= 9999
            }
            global nrob = $nrob + 1
            save "$dir_tmp/rob_$nrob.dta", replace
        }
    }
    use "$dir_tmp/casos.dta", clear
    forvalues r = 1/$nrob {
        append using "$dir_tmp/rob_`r'.dta"
    }
    replace id = _n
    save "$dir_tmp/casos.dta", replace
    quietly count if tipo == "rob"
    di as result "  Casos de robustez: " r(N)
}

* --- 6.0b Umbral 1 con ventana excluida asimétrica ($asim_izq = 1) ---
*   Copias de los casos de la base imponible del umbral 1 de $asim_grupos
*   (anuales y agrupados todo/pre/post) con lo = $asim_lo, hi = $asim_hi y la
*   ventana izquierda Kl = KL_YYYY_1 (anual) o KLpool_1 (agrupado). Se
*   omiten si quedan menos de 15 bins fuera de la ventana a la izquierda.
*   tipo = "rob", spec = "excl_izq": sin gráficos ni bootstrap de personas.
if $asim_izq == 1 {
    save "$dir_tmp/casos.dta", replace
    keep if tipo == "kink" & variable == "base" & kink == 1 & spec == "base" & ///
        inlist(periodo, "anual", "todo", "pre", "post")
    gen byte _sel = 0
    foreach g of global asim_grupos {
        replace _sel = 1 if grupo == "`g'"
    }
    keep if _sel == 1
    drop _sel
    replace grafico = ""
    replace tipo  = "rob"
    replace spec  = "excl_izq"
    replace valor = $asim_lo
    replace lo    = $asim_lo
    replace hi    = $asim_hi
    forvalues r = 1/`=_N' {
        local a = anio[`r']
        if `a' == 0 quietly replace Kl = ${KLpool_1} in `r'
        else        quietly replace Kl = ${KL_`a'_1} in `r'
    }
    drop if Kl < lo + 15 | K < hi + 15
    save "$dir_tmp/asim.dta", replace
    use "$dir_tmp/casos.dta", clear
    append using "$dir_tmp/asim.dta"
    replace id = _n
    save "$dir_tmp/casos.dta", replace
    quietly count if spec == "excl_izq"
    di as result "  Casos del umbral 1 con ventana asimétrica: " r(N)
}
local ncasos = _N
timer clear 1
timer on 1

capture postclose h_est
postfile h_est long(id) double(B c0 b B_izq B_der se_B se_c0 se_b se_B_izq se_B_der) ///
    double(se_bse se_b_pers se_bse_pers se_B_izq_pers se_B_der_pers) long(nwin_e)    ///
    int(n_pic_fuera n_pic_dentro n_esc_fuera n_esc_dentro)                        ///
    double(B_picos top_emp_dentro B_escalas B_esc_pub)                            ///
    using "$dir_tmp/estimaciones.dta", replace

forvalues i = 1/`ncasos' {

    * --- 6.1 Parámetros del caso ---
    use "$dir_tmp/casos.dta" in `i', clear
    if nwin[1] < $minobs continue
    foreach v in id K Kl lo hi z_graf delta archivo grafico titulo xtitulo pol tipo {
        local `v' = `v'[1]
    }

    use "`archivo'", clear
    * Declarantes en la ventana [-Kl, K] (igual a nwin, salvo robustez de
    * maxwin y ventana asimétrica)
    quietly keep if inrange(k, -`Kl', `K')
    quietly summarize n, meanonly
    local nwin_e = r(sum)
    if `nwin_e' < $minobs continue

    quietly {

        * --- 6.2 Picos: mediana de los vecinos (sin el propio bin) ---
        keep if inrange(k, -`Kl', `K')
        sort k
        gen byte dentro = inrange(k, -`lo', `hi')
        forvalues d = 1/$pico_vec {
            gen double _vm`d' = n[_n - `d']
            gen double _vp`d' = n[_n + `d']
        }
        egen double ref = rowmedian(_vm* _vp*)
        drop _vm* _vp*
        gen byte pico = n > $pico_ratio * ref & ref >= $pico_min & !missing(ref)
        capture confirm variable top_emp
        if _rc gen double top_emp = .

        * --- 6.2a Escalas salariales: esc = bin con algún valor de la escala
        *     (los conteos de la línea del RIMPE no tienen dummies de escala).
        *     Fuera de la ventana, una dummy por bin de escala. En un caso
        *     anual es lo mismo que una dummy por grado (cada grado cae en un
        *     solo bin). En los agrupados, una dummy por grado con el número de
        *     años (como el redondeo) obligaría a un mismo tamaño del pico en
        *     todos los años, y no lo es (p. ej. docentes en 2022 en los
        *     valores de transición): los residuos de esos bins inflaban el EE
        *     bootstrap. Por eso cada bin de escala tiene su propia dummy ---
        gen byte esc = 0
        if $scale_ctrl == 1 {
            foreach v of global evars {
                capture confirm variable `v'
                if _rc continue
                replace esc = 1 if `v' > 0
            }
        }
        local escs ""
        levelsof k if esc & !dentro, local(kesc)
        local ie 0
        foreach kk of local kesc {
            local ++ie
            gen byte ek`ie' = k == `kk'
            local escs "`escs' ek`ie'"
        }
        count if esc & !dentro
        local n_esc_fuera = r(N)
        count if esc & dentro
        local n_esc_dentro = r(N)

        * Exceso de los servidores públicos en los bins de escala de la
        * ventana: n_pub menos la mediana de n_pub de sus vecinos
        gen double exc_esc = .
        capture confirm variable n_pub
        if !_rc & `n_esc_dentro' > 0 {
            forvalues d = 1/$pico_vec {
                gen double _vm`d' = n_pub[_n - `d']
                gen double _vp`d' = n_pub[_n + `d']
            }
            egen double ref_pub = rowmedian(_vm* _vp*)
            drop _vm* _vp*
            replace exc_esc = n_pub - ref_pub if esc & dentro
        }
        summarize exc_esc, meanonly
        local B_esc_pub = cond(r(N) > 0, r(sum), 0)

        * Una dummy por pico fuera de la ventana (salvo bins de escala, que ya
        * tienen la suya)
        local pks ""
        levelsof k if pico & !dentro & !esc, local(kpicos)
        local ip 0
        foreach kk of local kpicos {
            local ++ip
            gen byte pk`ip' = k == `kk'
            local pks "`pks' pk`ip'"
        }
        count if pico & !dentro & !esc
        local n_pic_fuera = r(N)
        count if pico & dentro
        local n_pic_dentro = r(N)
        gen double exc_pico = n - ref if pico & dentro
        summarize exc_pico, meanonly
        local B_picos = cond(r(N) > 0, r(sum), 0)
        summarize top_emp if pico & dentro, meanonly
        local top_emp_dentro = cond(r(N) > 0, r(max), .)
        * Exceso de los picos de un solo empleador que no son bins de escala
        * (regla general) más el exceso de escala de los servidores públicos
        summarize exc_pico if top_emp > $pico_emp & !missing(top_emp) & !esc, meanonly
        local B_escalas = cond(r(N) > 0, r(sum), 0) + `B_esc_pub'

        * --- 6.2b Contrafactual con los bins fuera de la ventana ---
        forvalues p = 1/`pol' {
            gen double p`p' = (k / `K')^`p'
        }
        local xextra = strtrim("$rvars `pks' `escs'")

        regress n p1-p`pol' `xextra' if !dentro
        predict double cf, xb
        gen double cs = cf
        foreach R of local xextra {
            replace cs = cs - _b[`R'] * `R'
        }

        * --- 6.3 Exceso de masa en la ventana ---
        gen double dif = n - cf
        summarize dif if dentro, meanonly
        local B = r(sum)
        summarize cs if dentro, meanonly
        local c0 = r(mean)
        local b = `B' / `c0'
        summarize dif if dentro & k <= 0, meanonly
        local B_izq = r(sum)
        summarize dif if dentro & k > 0, meanonly
        local B_der = -r(sum)

        * --- 6.4 Bootstrap (Mata en línea, solo por velocidad) ---
        * Mismo cálculo que 6.2-6.3 repetido $reps veces, todas las
        * repeticiones a la vez (una columna por repetición). En Mata:
        *   Xp = polinomio y constante; X = Xp y dummies de redondeo y picos
        *   fuera/ein/eiz/ede = bins fuera de la ventana / en la ventana /
        *                       en la ventana con k <= 0 / con k > 0
        *   NS = conteos simulados (NP: de servidores públicos); CF =
        *   contrafactual; CS = su parte suave; BE = B_escalas recalculado
        *   S = una fila por repetición: B, c0, b, B_izq, B_der, b_sin_escalas
        * 6.4a Residuos (res): nstar = ajuste + residuo sorteado de los bins
        *   de fuera; NP = n_pub x nstar / n (misma participación pública).
        * 6.4b Personas (pers, $boot_personas = 1; no en robustez): se
        *   remuestrean con reposición los declarantes de la ventana, lo que
        *   equivale exactamente a sortear los conteos de un multinomial con
        *   probabilidades n/N. Celdas = bin x (público, no público), así n_pub
        *   se remuestrea junto con n. Multinomial por binomiales sucesivas:
        *   celda c ~ Bin(restantes, q_c / suma(q_c..q_fin)).
        *   El estado del generador se restaura después, así que el bootstrap
        *   de residuos (se_b) es el mismo con y sin $boot_personas.
        * B_escalas en cada repetición: con los mismos bins (picos de un solo
        *   empleador y de escala, elegidos con los datos), exceso sobre la
        *   mediana de los vecinos recalculada con NS (picos) y NP (escala).
        gen double ajuste = cond(dentro, n, cf)
        gen double res = n - cf
        gen byte izq = dentro & k <= 0
        gen byte der = dentro & k > 0
        gen byte uno = 1
        capture confirm variable n_pub
        if _rc gen double npb = 0
        else   gen double npb = n_pub
        gen double shp = cond(n > 0, npb / n, 0)
        gen long _fila = _n
        local nb = _N
        local tesc ""
        capture confirm variable n_pub
        if !_rc & `n_esc_dentro' > 0 levelsof _fila if esc & dentro, local(tesc)
        levelsof _fila if pico & dentro & top_emp > $pico_emp & !missing(top_emp) & !esc, local(tpic)

        mata: Xp = st_data(., "p1-p`pol' uno"); np = cols(Xp)
        if "`xextra'" != "" mata: X = Xp, st_data(., "`xextra'")
        else                mata: X = Xp
        mata: fuera = selectindex(st_data(., "dentro") :== 0); ein = selectindex(st_data(., "dentro"))
        mata: eiz = selectindex(st_data(., "izq")); ede = selectindex(st_data(., "der"))
        mata: aj = st_data(., "ajuste"); rs = st_data(fuera, "res"); m = rows(fuera); nb = rows(aj)

        local boots "res"
        if $boot_personas == 1 & "`tipo'" != "rob" local boots "res pers"
        foreach bt of local boots {
            if "`bt'" == "res" {
                mata: NS = aj :+ colshape(rs[1 :+ floor(runiform(nb * $reps, 1) :* m)], $reps)
                mata: NP = st_data(., "shp") :* NS
            }
            else {
                local rngs = c(rngstate)
                local nq = 2 * `nb'
                mata: Q = st_data(., "npb") \ (st_data(., "n") - st_data(., "npb")); T = runningsum(Q[`nq'::1]); T = T[`nq'::1]
                mata: REM = J(1, $reps, T[1]); D = J(`nq', $reps, 0)
                forvalues c = 1/`nq' {
                    mata: pc = Q[`c'] / max((T[`c'], 1)); D[`c', .] = (pc >= 1 ? REM : (pc <= 0 ? J(1, $reps, 0) : rbinomial(1, 1, REM :+ (REM :== 0), pc) :* (REM :> 0))); REM = REM - D[`c', .]
                }
                mata: NP = D[1::nb, .]; NS = NP + D[(nb + 1)::`nq', .]
                set rngstate `rngs'
            }
            mata: BB = invsym(cross(X[fuera, .], X[fuera, .])) * cross(X[fuera, .], NS[fuera, .])
            mata: CF = X * BB; CS = Xp * BB[1..np, .]
            mata: sB = colsum(NS[ein, .] - CF[ein, .]); sc0 = mean(CS[ein, .])
            * B_escalas de cada repetición (mediana de los vecinos sin el bin)
            mata: BE = J(1, $reps, 0)
            foreach src in esc pic {
                local M = cond("`src'" == "esc", "NP", "NS")
                foreach t of local t`src' {
                    local a = max(1, `t' - $pico_vec)
                    local z = min(`nb', `t' + $pico_vec)
                    mata: iv = (`a'::`z'); iv = select(iv, iv :!= `t'); V = `M'[iv, .]; md = J(1, $reps, .); for (r = 1; r <= $reps; r++) { v = sort(V[., r], 1); md[r] = (v[floor((rows(v) + 1) / 2)] + v[ceil((rows(v) + 1) / 2)]) / 2 ; }; BE = BE + `M'[`t', .] - md
                }
            }
            mata: S = (sB \ sc0 \ sB :/ sc0 \ colsum(NS[eiz, .] - CF[eiz, .]) \ colsum(CF[ede, .] - NS[ede, .]) \ (sB - BE) :/ sc0)'

            * EE = desviación estándar de cada estadístico entre repeticiones
            mata: st_matrix("SE", sqrt(diagonal(variance(S)))')
            forvalues c = 1/6 {
                local se`c'_`bt' = SE[1, `c']
                if "`bt'" == "res" local se`c' = SE[1, `c']
            }
        }
        if !strpos("`boots'", "pers") {
            forvalues c = 1/6 {
                local se`c'_pers = .
            }
        }

        post h_est (`id') (`B') (`c0') (`b') (`B_izq') (`B_der') ///
            (`se1') (`se2') (`se3') (`se4') (`se5')                 ///
            (`se6') (`se3_pers') (`se6_pers') (`se4_pers') (`se5_pers') (`nwin_e') ///
            (`n_pic_fuera') (`n_pic_dentro') (`n_esc_fuera') (`n_esc_dentro')  ///
            (`B_picos') (`top_emp_dentro') (`B_escalas') (`B_esc_pub')
    }

    * --- 6.5 Gráfico: histograma y contrafactual ---
    if "`grafico'" != "" {
        local bs  = string(`b', "%5.2f")
        local ses = string(`se3', "%5.2f")
        gen double x = `z_graf' + k * `delta'
        local xl = `z_graf' - (`lo' + 0.5) * `delta'
        * Picos en naranja y bins de escala salarial en verde (solo si hay;
        * un bin de escala que también es pico se pinta como escala)
        local capas ""
        local ley `"1 "Observado""'
        local nc 1
        quietly count if pico & !esc
        if r(N) > 0 {
            local ++nc
            local capas "`capas' (bar n x if pico & !esc, barwidth(`delta') fcolor(orange*0.6) lcolor(orange))"
            local ley `"`ley' `nc' "Pico""'
        }
        quietly count if esc
        if r(N) > 0 {
            local ++nc
            local capas "`capas' (bar n x if esc, barwidth(`delta') fcolor(green*0.5) lcolor(green))"
            local ley `"`ley' `nc' "Escala salarial""'
        }
        local ++nc
        local ley `"`ley' `nc' "Contrafactual (con redondeo, picos y escalas)""'
        local filas = cond(`nc' > 3, 2, 1)
        local xr = `z_graf' + (`hi' + 0.5) * `delta'
        quietly twoway                                                        ///
            (bar n x, barwidth(`delta') fcolor(gs13) lcolor(gs11))            ///
            `capas'                                                           ///
            (line cf x, lcolor(cranberry) lwidth(medthick)),                  ///
            xline(`xl' `xr', lpattern(dash) lcolor(gs7))                      ///
            xline(`z_graf', lcolor(navy))                                     ///
            title(`"`titulo'"', size(medsmall))                               ///
            xtitle(`"`xtitulo'"') ytitle("Declarantes por bin")               ///
            legend(order(`ley') rows(`filas') position(6))                    ///
            note("Exceso de masa b = `bs' (EE = `ses'). Lineas discontinuas: ventana excluida.") ///
            graphregion(color(white))
        quietly graph export "`grafico'", replace width(1600)
    }
}

postclose h_est
timer off 1
quietly timer list 1
di as result _n "  Sección 6 (estimación): " %8.1f r(t1) " segundos"

* ============================================================================
* 7. GUARDAR, DIFERENCIAS Y EXPORTAR
*    Requiere: $dir_tmp/casos.dta y $dir_tmp/estimaciones.dta (sección 6).
* ============================================================================

* --- 7.1 Umbrales ---
use "$dir_tmp/casos.dta", clear
merge 1:1 id using "$dir_tmp/estimaciones.dta", nogen
keep if tipo == "kink"

gen double zstat    = b / se_b
gen double pval_pos = 1 - normal(zstat)
gen double pval_two = 2 * (1 - normal(abs(zstat)))
gen double dz       = b * delta
gen double elast    = b * delta / (zstar * ln((1 - t0) / (1 - t1)))
gen double se_elast = se_b * delta / (zstar * ln((1 - t0) / (1 - t1)))
gen double b_picos  = B_picos / c0
gen double b_esc_pub         = B_esc_pub / c0
gen double b_sin_escalas     = (B - B_escalas) / c0
gen double elast_sin_escalas = b_sin_escalas * delta / (zstar * ln((1 - t0) / (1 - t1)))
* Bootstrap de personas (6.4b) y EE de b_sin_escalas (ambos bootstraps)
rename se_bse se_b_sin_escalas
rename se_bse_pers se_b_sin_escalas_pers
gen double zstat_pers    = b / se_b_pers
gen double pval_pos_pers = 1 - normal(zstat_pers)
gen double pval_two_pers = 2 * (1 - normal(abs(zstat_pers)))
gen double se_elast_pers = se_b_pers * delta / (zstar * ln((1 - t0) / (1 - t1)))
gen double se_elast_sin_escalas      = se_b_sin_escalas * delta / (zstar * ln((1 - t0) / (1 - t1)))
gen double se_elast_sin_escalas_pers = se_b_sin_escalas_pers * delta / (zstar * ln((1 - t0) / (1 - t1)))
gen double pval_pos_sin_escalas      = 1 - normal(b_sin_escalas / se_b_sin_escalas)
gen double pval_pos_sin_escalas_pers = 1 - normal(b_sin_escalas / se_b_sin_escalas_pers)
local vnuevas se_b_pers zstat_pers pval_pos_pers pval_two_pers se_elast_pers  ///
    se_b_sin_escalas se_b_sin_escalas_pers se_elast_sin_escalas             ///
    se_elast_sin_escalas_pers pval_pos_sin_escalas pval_pos_sin_escalas_pers

keep  anio periodo grupo variable kink round_z zstar t0 t1 delta nwin ///
      B c0 b se_b zstat pval_pos pval_two B_izq B_der dz elast se_elast ///
      n_pic_fuera n_pic_dentro b_picos top_emp_dentro n_esc_fuera n_esc_dentro ///
      b_esc_pub b_sin_escalas elast_sin_escalas `vnuevas'
order anio periodo grupo variable kink round_z zstar t0 t1 delta nwin ///
      B c0 b se_b zstat pval_pos pval_two B_izq B_der dz elast se_elast ///
      n_pic_fuera n_pic_dentro b_picos top_emp_dentro n_esc_fuera n_esc_dentro ///
      b_esc_pub b_sin_escalas elast_sin_escalas `vnuevas'

label var anio      "Año (0 = agrupado)"
label var periodo   "anual / todo / pre (< reforma) / post (>= reforma)"
label var grupo     "Grupo"
label var variable  "base: base imponible; placebo: PreTaxHHI; base_ant: base en umbrales del año anterior"
label var kink      "Umbral (1 = fracción exenta)"
label var round_z   "Umbral múltiplo de 5.000 (no separable del redondeo)"
label var zstar     "Umbral (USD nominales; agrupado: promedio ponderado)"
label var t0        "Tasa marginal debajo del umbral"
label var t1        "Tasa marginal encima del umbral"
label var delta     "Ancho del bin (USD)"
label var nwin      "Declarantes en la ventana"
label var B         "Exceso de masa (declarantes)"
label var c0        "Contrafactual suave promedio por bin"
label var b         "Bunching normalizado b = B/c0"
label var se_b      "EE bootstrap de b"
label var zstat     "b / EE"
label var pval_pos  "p-valor una cola (H1: b > 0)"
label var pval_two  "p-valor dos colas"
label var B_izq     "Exceso a la izquierda del umbral (k <= 0)"
label var B_der     "Masa faltante a la derecha (k > 0)"
label var dz        "Desplazamiento del bunching (USD) = b*delta"
label var elast     "Elasticidad del ingreso imponible"
label var se_elast  "EE de la elasticidad"
label var n_pic_fuera    "Picos fuera de la ventana (con dummy propia; sin bins de escala)"
label var n_pic_dentro   "Picos dentro de la ventana excluida"
label var b_picos        "Exceso de los picos dentro de la ventana, normalizado (parte de b)"
label var top_emp_dentro "Máx. participación del empleador más frecuente en picos dentro"
label var n_esc_fuera       "Bins de escala salarial fuera de la ventana (con dummy)"
label var n_esc_dentro      "Bins de escala salarial dentro de la ventana excluida"
label var b_esc_pub         "Exceso de servidores públicos en bins de escala de la ventana, normalizado"
label var b_sin_escalas     "b sin escalas: sin b_esc_pub ni picos de un solo empleador fuera de la escala"
label var elast_sin_escalas "Elasticidad sin escalas (de b_sin_escalas)"
label var se_b_pers         "EE de b, bootstrap de personas"
label var zstat_pers        "b / EE (personas)"
label var pval_pos_pers     "p-valor una cola (H1: b > 0), EE de personas"
label var pval_two_pers     "p-valor dos colas, EE de personas"
label var se_elast_pers     "EE de la elasticidad, bootstrap de personas"
label var se_b_sin_escalas          "EE de b_sin_escalas, bootstrap de residuos"
label var se_b_sin_escalas_pers     "EE de b_sin_escalas, bootstrap de personas"
label var se_elast_sin_escalas      "EE de elast_sin_escalas, bootstrap de residuos"
label var se_elast_sin_escalas_pers "EE de elast_sin_escalas, bootstrap de personas"
label var pval_pos_sin_escalas      "p-valor una cola de b_sin_escalas (residuos)"
label var pval_pos_sin_escalas_pers "p-valor una cola de b_sin_escalas (personas)"

sort grupo variable periodo anio kink
save "$dir_out/bunching_resultados.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("kinks") firstrow(varlabels) replace

* --- 7.2 Reforma 2022: pre vs post ---
*     Requiere: $dir_out/bunching_resultados.dta (7.1).
use "$dir_out/bunching_resultados.dta", clear
keep if anio == 0 & inlist(periodo, "pre", "post") & !missing(b)
keep grupo variable kink periodo nwin b se_b elast se_elast
reshape wide nwin b se_b elast se_elast, i(grupo variable kink) j(periodo) string
foreach v in nwin b se_b elast se_elast {
    capture confirm variable `v'pre
    if _rc gen double `v'pre = .
    capture confirm variable `v'post
    if _rc gen double `v'post = .
}
gen double dif_elast    = elastpost - elastpre
gen double se_dif_elast = sqrt(se_elastpost^2 + se_elastpre^2)
gen double z_dif        = dif_elast / se_dif_elast
gen double p_dif        = 2 * (1 - normal(abs(z_dif)))
order grupo variable kink nwinpre elastpre se_elastpre nwinpost elastpost ///
    se_elastpost dif_elast se_dif_elast p_dif bpre se_bpre bpost se_bpost
label var dif_elast    "Elasticidad post - pre"
label var se_dif_elast "EE de la diferencia"
label var p_dif        "p-valor dos colas de la diferencia"
sort grupo variable kink
save "$dir_out/bunching_reforma2022.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("reforma_2022", replace) firstrow(variables)

di as result _n "===== Reforma 2022: elasticidad pre vs post (base imponible) ====="
format elastpre se_elastpre elastpost se_elastpost dif_elast se_dif_elast p_dif %7.3f
foreach g in f107 f107priv f107pub f107solo f102 f102gen todos todospriv {
    di as text _n "--- Grupo: `g' ---"
    list kink nwinpre elastpre se_elastpre nwinpost elastpost se_elastpost dif_elast p_dif ///
        if variable == "base" & grupo == "`g'", noobs sep(0) abbreviate(12)
}

* --- 7.3 RIMPE ---
use "$dir_tmp/casos.dta", clear
merge 1:1 id using "$dir_tmp/estimaciones.dta", nogen
keep if tipo == "rimpe"
sort id

gen double b_izq    = B_izq / c0
gen double se_b_izq_pers = se_B_izq_pers / c0
gen double se_b_der_pers = se_B_der_pers / c0
gen double se_b_izq = se_B_izq / c0
gen double pval_izq = 1 - normal(B_izq / se_B_izq)
gen double b_der    = B_der / c0
gen double se_b_der = se_B_der / c0
gen double pval_der = 1 - normal(B_der / se_B_der)

keep  serie anio nwin B c0 b se_b b_izq se_b_izq pval_izq b_der se_b_der pval_der ///
      se_b_pers se_b_izq_pers se_b_der_pers
order serie anio nwin B c0 b se_b b_izq se_b_izq pval_izq b_der se_b_der pval_der ///
      se_b_pers se_b_izq_pers se_b_der_pers

* Diferencias del exceso a la izquierda: cada serie RIMPE menos cada
* placebo (agrupados)
foreach sr in rimpe rim_emp rim_np rim_npc {
foreach pl in plac_post plac_pre {
    quietly summarize b_izq if serie == "`sr'" & anio == 0, meanonly
    local b1 = r(mean)
    quietly summarize se_b_izq if serie == "`sr'" & anio == 0, meanonly
    local s1 = r(mean)
    quietly summarize b_izq if serie == "`pl'" & anio == 0, meanonly
    local b2 = r(mean)
    quietly summarize se_b_izq if serie == "`pl'" & anio == 0, meanonly
    local s2 = r(mean)
    if "`b1'" != "" & "`b2'" != "" {
        local d  = `b1' - `b2'
        local sd = sqrt(`s1'^2 + `s2'^2)
        set obs `=_N + 1'
        replace serie    = "`sr'-`pl'" in L
        replace anio     = 0 in L
        replace b_izq    = `d' in L
        replace se_b_izq = `sd' in L
        replace pval_izq = 1 - normal(`d' / `sd') in L
    }
}
}
label var serie    "rimpe (todos) / rim_emp / rim_np (2024+) / rim_npc (2022-23) / placebos / serie-placebo"
label var anio     "Año (0 = agrupado)"
label var nwin     "Declarantes en la ventana"
label var B        "Exceso neto en la ventana (declarantes)"
label var c0       "Contrafactual suave promedio por bin"
label var b        "Exceso neto normalizado B/c0"
label var b_izq    "Exceso a la izquierda de 20.000, normalizado"
label var pval_izq "p-valor una cola (exceso izquierda > 0)"
label var b_der    "Masa faltante a la derecha de 20.000, normalizada"
label var pval_der "p-valor una cola (masa faltante > 0)"
label var se_b_pers     "EE de b, bootstrap de personas"
label var se_b_izq_pers "EE de b_izq, bootstrap de personas"
label var se_b_der_pers "EE de b_der, bootstrap de personas"
save "$dir_out/bunching_rimpe20000.dta", replace

* Categorías RIMPE por año (sección 3.5b): sirve para verificar los
* códigos de emprendedor y negocio popular y cuántos no declaran ingresos
preserve
use "$dir_tmp/rimpe_categorias.dta", clear
label var rimpe_cat   "Código de categoría RIMPE (cat_reg_rimpe_4897)"
label var rimpe_simpl "Declaración simplificada de negocio popular (sin ingresos)"
label var n           "Sujetos RIMPE"
label var n_ing       "Con ingresos RIMPE > 0"
label var n_le20      "Con ingresos RIMPE en (0, 20.000]"
label var n_gt20      "Con ingresos RIMPE > 20.000"
label var p50         "Mediana de ingresos RIMPE (> 0)"
label var cod_emp     "Código usado como emprendedor"
label var cod_np      "Código usado como negocio popular"
save "$dir_out/bunching_rimpe_categorias.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("rimpe_categorias", replace) firstrow(variables)
di as result _n "===== RIMPE: categorías y declaración simplificada ====="
list, noobs sepby(anio) abbreviate(12)
restore
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("rimpe_20000", replace) firstrow(variables)

di as result _n "===== RIMPE: línea de 20.000 ====="
format b_izq se_b_izq pval_izq b_der se_b_der pval_der %7.3f
list serie anio nwin b_izq se_b_izq pval_izq b_der se_b_der pval_der, noobs sep(0) abbreviate(10)

* --- 7.4 Resumen de agrupados (todos los años) ---
use "$dir_out/bunching_resultados.dta", clear
di as result _n "===== Bunching agrupado (todos los años): base imponible ====="
format b se_b pval_pos elast b_picos b_esc_pub b_sin_escalas %8.3f
foreach g of global groups {
    di as text _n "--- Grupo: `g' ---"
    list kink nwin b se_b pval_pos elast n_pic_fuera n_pic_dentro b_picos ///
        n_esc_fuera n_esc_dentro b_esc_pub b_sin_escalas                    ///
        if anio == 0 & periodo == "todo" & variable == "base" & grupo == "`g'", ///
        noobs sep(0) abbreviate(12)
}

di as result _n "===== Placebo agrupado (todos los años): ingreso bruto ====="
foreach g of global groups {
    di as text _n "--- Grupo: `g' ---"
    list kink nwin b se_b pval_pos n_esc_dentro b_esc_pub b_sin_escalas ///
        if anio == 0 & periodo == "todo" & variable == "placebo" & grupo == "`g'", ///
        noobs sep(0) abbreviate(12)
}

di as result _n "===== Placebo agrupado: base imponible en los umbrales del año anterior ====="
foreach g of global groups {
    di as text _n "--- Grupo: `g' ---"
    list kink nwin b se_b pval_pos n_esc_dentro b_esc_pub b_sin_escalas ///
        if anio == 0 & periodo == "todo" & variable == "base_ant" & grupo == "`g'", ///
        noobs sep(0) abbreviate(12)
}

* --- 7.5 Escalas salariales: por año, umbrales 1-3, asalariados vs F102 ---
di as result _n "===== Por año, umbrales 1-3: b y b sin escalas (base imponible y placebo) ====="
format elast_sin_escalas %8.3f
foreach g in f102 f107 f107solo f107priv f107pub todos todospriv {
    di as text _n "--- Grupo: `g' ---"
    list anio variable kink nwin b se_b elast n_esc_fuera n_esc_dentro b_esc_pub ///
        b_sin_escalas elast_sin_escalas                                          ///
        if periodo == "anual" & inlist(variable, "base", "placebo") & kink <= 3 & grupo == "`g'", ///
        noobs sep(0) abbreviate(12)
}

* --- 7.6 Robustez: polinomio, ventana excluida y ventana máxima ---
*     Requiere: $dir_tmp/casos.dta y estimaciones.dta (sección 6, $robustez = 1).
*     Una fila por caso y especificación; spec = base son los casos
*     principales (poly = $poly, excl = $excl_bins, maxwin = $maxwin).
if $robustez == 1 {
    use "$dir_tmp/casos.dta", clear
    merge 1:1 id using "$dir_tmp/estimaciones.dta", nogen
    gen byte _sel = 0
    foreach g of global rob_grupos {
        replace _sel = 1 if grupo == "`g'"
    }
    keep if tipo == "rob" | (tipo == "kink" & variable == "base" & _sel == 1 & ///
        inlist(periodo, "anual", "todo", "pre", "post"))
    drop _sel
    replace nwin = nwin_e if !missing(nwin_e)
    gen double elast = b * delta / (zstar * ln((1 - t0) / (1 - t1)))
    gen double b_sin_escalas = (B - B_escalas) / c0
    gen double pval_pos = 1 - normal(b / se_b)
    gen str20 especificacion = cond(spec == "base", "base", spec + " = " + string(valor))
    keep  grupo variable anio periodo kink round_z spec valor especificacion K Kl lo hi pol nwin ///
          zstar b se_b pval_pos elast b_sin_escalas se_bse
    rename se_bse se_b_sin_escalas
    order grupo variable anio periodo kink round_z spec valor especificacion K Kl lo hi pol nwin ///
          zstar b se_b pval_pos elast b_sin_escalas se_b_sin_escalas
    label var spec           "Parámetro cambiado (base = especificación principal)"
    label var valor          "Valor del parámetro cambiado"
    label var especificacion "Especificación"
    label var K              "Semiancho de la ventana (bins)"
    label var Kl             "Semiancho de la ventana a la izquierda (bins)"
    label var lo             "Bins excluidos a la izquierda"
    label var hi             "Bins excluidos a la derecha"
    label var pol            "Orden del polinomio"
    label var se_b_sin_escalas "EE de b_sin_escalas (residuos)"
    sort grupo periodo anio kink spec valor
    save "$dir_out/bunching_robustez.dta", replace
    export excel using "$dir_out/bunching_resultados.xlsx", ///
        sheet("robustez", replace) firstrow(variables)

    di as result _n "===== Robustez: agrupados (todo), base imponible, b por especificación ====="
    preserve
    keep if anio == 0 & periodo == "todo" & !missing(b)
    keep grupo kink especificacion b
    replace especificacion = subinstr(subinstr(especificacion, " = ", "_", .), " ", "", .)
    reshape wide b, i(grupo kink) j(especificacion) string
    format b* %7.2f
    list, noobs sep(0) abbreviate(12)
    restore
}

* --- 7.7 Diagnóstico de la tasa de aporte al IESS (sección 3.1b) ---
use "$dir_tmp/diag_iess.dta", clear
label var tramo "bin (0,005) / banda / total"
label var desde "Desde (tasa)"
label var hasta "Hasta (tasa; bin: [desde, hasta))"
label var n     "Declarantes"
label var share "Participación entre los que tienen tasa"
save "$dir_out/bunching_diagnostico_iess.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("diag_iess", replace) firstrow(variables)
di as result _n "===== Tasa de aporte IESS: participación en las bandas ====="
list anio tramo n share if tramo != "bin", noobs sep(0) abbreviate(20)

* --- 7.8 Umbral 1 con ventana excluida asimétrica (sección 6.0b) ---
*     Una fila por caso: la especificación principal (simétrica, +/-
*     $excl_bins bins) y la asimétrica (-$asim_lo / +$asim_hi bins) lado a
*     lado. -> bunching_umbral1_asimetrico.dta y hoja "umbral1_asim"
if $asim_izq == 1 {
    use "$dir_tmp/casos.dta", clear
    merge 1:1 id using "$dir_tmp/estimaciones.dta", nogen
    gen byte _sel = 0
    foreach g of global asim_grupos {
        replace _sel = 1 if grupo == "`g'"
    }
    keep if variable == "base" & kink == 1 & _sel == 1 & inlist(periodo, "anual", "todo", "pre", "post") & ///
        (spec == "excl_izq" | (tipo == "kink" & spec == "base"))
    drop _sel
    replace nwin = nwin_e if !missing(nwin_e)
    gen double elast = b * delta / (zstar * ln((1 - t0) / (1 - t1)))
    gen double se_elast = se_b * delta / (zstar * ln((1 - t0) / (1 - t1)))
    gen double b_sin_escalas = (B - B_escalas) / c0
    gen str4 esp = cond(spec == "excl_izq", "asim", "sim")
    keep grupo anio periodo zstar esp nwin b se_b elast se_elast b_sin_escalas B_izq B_der c0
    gen double b_izq = B_izq / c0
    gen double b_der = B_der / c0
    drop B_izq B_der c0
    reshape wide nwin b se_b elast se_elast b_sin_escalas b_izq b_der, i(grupo anio periodo zstar) j(esp) string
    order grupo periodo anio zstar nwinsim bsim se_bsim elastsim se_elastsim b_sin_escalassim ///
        nwinasim basim se_basim elastasim se_elastasim b_sin_escalasasim b_izqasim b_derasim
    label var bsim    "b, ventana excluida simétrica (+/- $excl_bins bins)"
    label var basim   "b, ventana excluida asimétrica (-$asim_lo/+$asim_hi bins)"
    label var b_izqasim "Exceso a la izquierda / c0 (asimétrica)"
    label var b_derasim "Masa faltante a la derecha / c0 (asimétrica)"
    sort grupo periodo anio
    save "$dir_out/bunching_umbral1_asimetrico.dta", replace
    export excel using "$dir_out/bunching_resultados.xlsx", ///
        sheet("umbral1_asim", replace) firstrow(variables)

    di as result _n "===== Umbral 1: ventana excluida simétrica vs asimétrica (base imponible) ====="
    format bsim se_bsim elastsim basim se_basim elastasim b_izqasim b_derasim %7.3f
    foreach g of global asim_grupos {
        di as text _n "--- Grupo: `g' ---"
        list periodo anio bsim se_bsim elastsim basim se_basim elastasim b_izqasim b_derasim ///
            if grupo == "`g'", noobs sep(0) abbreviate(10)
    }
}

* --- 7.9 Réplica de Bohne y Nimczik (2025) (sección 3.6) ---
*     Serie por año (su figura 2) -> bunching_bohne_nimczik.dta, hoja
*     "bohne_nimczik"; conteos de la figura 1 apilados en distancia al umbral
*     1, por periodo (pre < $reform_year <= post) ->
*     bunching_bohne_figura1.dta, hoja "bohne_fig1", y gráficos.
use "$dir_tmp/bohne.dta", clear
label var zstar     "Umbral 1 (fracción básica, USD nominales)"
label var n_priv    "Asalariados privados (F107)"
label var n_pot_g   "Potenciales: grav_107 en (Z, 2Z]"
label var n_bun_g   "Bunchers: potenciales (grav) con base en (Z - $bn_win, Z]"
label var n_pot_p   "Potenciales: base + gastos personales en (Z, 2Z]"
label var n_bun_p   "Bunchers: potenciales (base + gp) con base en (Z - $bn_win, Z]"
label var share_g   "Bunchers / potenciales (grav)"
label var share_p   "Bunchers / potenciales (base + gp; 0 por construcción desde $reform_year)"
label var share_gp  "Potenciales (grav) con gastos personales > 0"
label var sh_id_gp  "Base > 0 con |grav - gp - base| <= 10"
label var sh_id_sin "Base > 0 con |grav - base| <= 10"
save "$dir_out/bunching_bohne_nimczik.dta", replace
export excel using "$dir_out/bunching_resultados.xlsx", ///
    sheet("bohne_nimczik", replace) firstrow(variables)
di as result _n "===== Bohne y Nimczik: asalariados privados en el umbral 1 ====="
format share_g share_p share_gp sh_id_gp sh_id_sin %6.3f
list anio zstar n_pot_g n_bun_g share_g share_p share_gp sh_id_gp sh_id_sin, noobs sep(0) abbreviate(10)
if $make_graphs == 1 & _N > 0 {
    twoway (connected share_g anio, lcolor(navy) mcolor(navy)),                     ///
        xline(`=$reform_year - 0.5', lcolor(cranberry) lpattern(dash))              ///
        ytitle("Bunchers / potenciales") xtitle("") xlabel(2010(2)2024)             ///
        title("Asalariados privados en el umbral 1") graphregion(color(white))
    graph export "$dir_graf/bohne_figura2.png", replace width(1600)
}

clear
foreach yr of global years {
    capture confirm file "$dir_tmp/fig_`yr'.dta"
    if !_rc append using "$dir_tmp/fig_`yr'.dta"
}
if _N > 0 {
    gen str4 periodo = cond(anio < $reform_year, "pre", "post")
    collapse (sum) n_tax n_grav n_prep, by(periodo k)
    gen double dist = k * $delta
    label var dist   "Distancia al umbral 1 (USD nominales)"
    label var n_tax  "Base imponible"
    label var n_grav "Sueldos + sobresueldos + utilidades - IESS"
    label var n_prep "Base + gastos personales (hasta 2021)"
    sort periodo k
    save "$dir_out/bunching_bohne_figura1.dta", replace
    export excel using "$dir_out/bunching_resultados.xlsx", ///
        sheet("bohne_fig1", replace) firstrow(variables)
    if $make_graphs == 1 {
        foreach p in pre post {
            local tit = cond("`p'" == "pre", "Hasta `=$reform_year - 1'", "Desde $reform_year")
            twoway (line n_grav dist if periodo == "`p'", lcolor(gs10) lwidth(medthick)) ///
                   (line n_tax dist if periodo == "`p'", lcolor(navy)),                  ///
                xline(0, lcolor(cranberry) lpattern(dash)) xline(-$bn_win, lcolor(gs12) lpattern(dot)) ///
                legend(order(1 "Antes de gastos personales" 2 "Base imponible") rows(1) position(6)) ///
                ytitle("Asalariados privados por bin de USD $delta") ///
                xtitle("Distancia al umbral 1 (USD)") title("`tit'") graphregion(color(white))
            graph export "$dir_graf/bohne_figura1_`p'.png", replace width(1600)
        }
    }
}

* --- 7.10 Umbrales de la obligación de llevar contabilidad (sección 5b) ---
*     Una fila por línea, periodo y año (0 = agrupado), con el exceso a la
*     izquierda del umbral (b_izq) y la masa faltante a la derecha (b_der),
*     como en la línea del RIMPE. Diferencias real - placebo (y r1819, r2021,
*     r2224 - placebo) del exceso a la izquierda, agrupados. Conteos por año
*     y línea (sección 3.7). -> bunching_contabilidad.dta (hoja
*     "contabilidad") y bunching_contabilidad_conteos.dta ("contab_conteos")
if $contab == 1 {
    use "$dir_tmp/contab_conteos.dta", clear
    label var zstar       "Umbral del año (USD)"
    label var n_win       "Declarantes en la ventana (+/- $cl_K bins)"
    label var n_5pct      "Declarantes a +/- 5% del umbral"
    label var n_izq       "En la ventana excluida a la izquierda (incluye el bin del umbral)"
    label var n_der       "En la ventana excluida a la derecha"
    label var n_oblig_win "De la ventana, llevaron contabilidad (balance o estado de resultados)"
    sort linea anio
    save "$dir_out/bunching_contabilidad_conteos.dta", replace
    export excel using "$dir_out/bunching_resultados.xlsx", ///
        sheet("contab_conteos", replace) firstrow(variables)
    di as result _n "===== Umbrales de contabilidad: declarantes cerca de cada umbral ====="
    list linea anio zstar n_win n_5pct n_izq n_der n_oblig_win, noobs sepby(linea) abbreviate(12)

    use "$dir_tmp/casos.dta", clear
    merge 1:1 id using "$dir_tmp/estimaciones.dta", nogen
    keep if tipo == "contab"
    gen double b_izq    = B_izq / c0
    gen double se_b_izq = se_B_izq / c0
    gen double pval_izq = 1 - normal(B_izq / se_B_izq)
    gen double b_der    = B_der / c0
    gen double se_b_der = se_B_der / c0
    gen double pval_der = 1 - normal(B_der / se_B_der)
    rename serie linea
    keep  linea variable periodo anio zstar delta nwin b se_b b_izq se_b_izq pval_izq ///
          b_der se_b_der pval_der se_b_pers
    order linea variable periodo anio zstar delta nwin b se_b b_izq se_b_izq pval_izq ///
          b_der se_b_der pval_der se_b_pers

    * Diferencias del exceso a la izquierda: cada periodo con el umbral
    * vigente menos el placebo (agrupados)
    foreach L of global cl_lineas {
        quietly summarize b_izq if linea == "`L'" & periodo == "plac" & anio == 0, meanonly
        local b2 = r(mean)
        quietly summarize se_b_izq if linea == "`L'" & periodo == "plac" & anio == 0, meanonly
        local s2 = r(mean)
        foreach p of global cl_pers_`L' {
            if "`p'" == "plac" continue
            quietly summarize b_izq if linea == "`L'" & periodo == "`p'" & anio == 0, meanonly
            local b1 = r(mean)
            quietly summarize se_b_izq if linea == "`L'" & periodo == "`p'" & anio == 0, meanonly
            local s1 = r(mean)
            if "`b1'" != "" & "`b2'" != "" {
                local dd = `b1' - `b2'
                local sd = sqrt(`s1'^2 + `s2'^2)
                quietly set obs `=_N + 1'
                quietly replace linea    = "`L'" in L
                quietly replace periodo  = "`p'-plac" in L
                quietly replace anio     = 0 in L
                quietly replace b_izq    = `dd' in L
                quietly replace se_b_izq = `sd' in L
                quietly replace pval_izq = 1 - normal(`dd' / `sd') in L
            }
        }
    }
    label var linea    "Línea: i/c/k/s = ingresos/costos/capital/ingresos sin gatillo de costos; umbral"
    label var periodo  "real / plac (placebo) / r1819, r2021, r2224 / X-plac (diferencia) / anual"
    label var anio     "Año (0 = agrupado)"
    label var zstar    "Umbral (promedio de los años en los agrupados)"
    label var delta    "Ancho del bin (USD)"
    label var b_izq    "Exceso a la izquierda del umbral, normalizado"
    label var pval_izq "p-valor una cola (exceso izquierda > 0)"
    label var b_der    "Masa faltante a la derecha del umbral, normalizada"
    label var pval_der "p-valor una cola (masa faltante > 0)"
    gen int _o = 0
    replace _o = 1 if anio > 0
    sort linea _o periodo anio
    drop _o
    save "$dir_out/bunching_contabilidad.dta", replace
    export excel using "$dir_out/bunching_resultados.xlsx", ///
        sheet("contabilidad", replace) firstrow(variables)
    di as result _n "===== Umbrales de contabilidad: agrupados ====="
    format b se_b b_izq se_b_izq pval_izq b_der se_b_der pval_der %7.3f
    list linea periodo zstar nwin b se_b b_izq se_b_izq pval_izq b_der se_b_der if anio == 0, ///
        noobs sepby(linea) abbreviate(10)
}

di as result _n "Resultados: $dir_out"
di as result    "Gráficos  : $dir_graf"

log close

/*******************************************************************************
* tablas_impuesto_renta.do
*
* Tablas del impuesto a la renta de personas naturales (Ecuador), 2010-2026.
* Se incluye con:  include "$code_dir/tablas_impuesto_renta.do"
* desde bunching_renta.do e inyectar_bunching_falso.do. Define GLOBALS
* (thr_YYYY, rate_YYYY, r8, r9), así que cualquier parte de esos do-files se
* puede correr por separado después de incluir este archivo.
*******************************************************************************/

* ============================================================================
* 2. TABLAS DEL IMPUESTO A LA RENTA (una por ejercicio fiscal)
*
*   thr_YYYY : límites superiores de los tramos = umbrales (kinks). Hasta 2021
*              hay 8 umbrales (tasa máxima 35%); desde 2022 hay 9 (37%).
*   rate_YYYY: tasa marginal de cada tramo (rate_j = tasa debajo del umbral j;
*              rate_{j+1} = tasa encima). El kink j corresponde al mismo cambio
*              de tasa en todos los años (1: 0->5%, 2: 5->10%, 3: 10->12%,
*              4: 12->15%, 5: 15->20%, 6: 20->25%, 7: 25->30%, 8: 30->35%,
*              9: 35->37%, solo desde 2022).
*
*   Se asume que YYYY (nombre de los archivos F102/F107) es el ejercicio fiscal.
*   Fuentes: tablas SRI "Tablas de cálculo de Impuesto a la Renta" (2010-2021 y
*   2023; resoluciones NAC-DGERCGC09-823 ... NAC-DGERCGC20-00000077),
*   Ley Orgánica de Desarrollo Económico y Sostenibilidad Fiscal (2022),
*   NAC-DGERCGC23-00000036 (2024), NAC-DGERCGC24-00000041 (2025),
*   NAC-DGERCGC25-00000043 (2026; uqa.com.ec).
* ============================================================================

global r8 "0 .05 .10 .12 .15 .20 .25 .30 .35"
global r9 "0 .05 .10 .12 .15 .20 .25 .30 .35 .37"

global thr_2010  "8910 11350 14190 17030 34060 51080 68110 90810"
global thr_2011  "9210 11730 14670 17610 35210 52810 70420 93890"
global thr_2012  "9720 12380 15480 18580 37160 55730 74320 99080"
global thr_2013  "10180 12970 16220 19470 38930 58390 77870 103810"
global thr_2014  "10410 13270 16590 19920 39830 59730 79660 106200"
global thr_2015  "10800 13770 17210 20670 41330 61980 82660 110190"
global thr_2016  "11170 14240 17800 21370 42740 64090 85470 113940"
global thr_2017  "11290 14390 17990 21600 43190 64770 86370 115140"
global thr_2018  "11270 14360 17950 21550 43100 64630 86180 114890"
global thr_2019  "11310 14410 18010 21630 43250 64860 86480 115290"
global thr_2020  "11315 14416 18018 21639 43268 64887 86516 115338"
global thr_2021  "11212 14285 17854 21442 42874 64297 85729 114288"
global thr_2022  "11310 14410 18010 21630 31630 41630 51630 61630 100000"
global thr_2023  "11722 14930 19385 25638 33738 44721 59537 79388 105580"
global thr_2024  "11902 15159 19682 26031 34255 45407 60450 80605 107199"
global thr_2025  "12081 15387 19978 26422 34770 46089 61359 81817 108810"
global thr_2026  "12208 15549 20188 26700 35136 46575 62005 82679 109956"

forvalues y = 2010/2021 {
    global rate_`y' "$r8"
}
forvalues y = 2022/2026 {
    global rate_`y' "$r9"
}


/*******************************************************************************
* movilidad_shock.do   --   VERSION A (reconstruye las variables desde el panel)
*                           v2, 28.09.2026 (ver CAMBIOS v2 mas abajo)
*
* EFECTO DE UN SHOCK MACROECONOMICO SOBRE LA MOVILIDAD DE INGRESOS
*
* -----------------------------------------------------------------------------
* CAMBIOS v2 (28.09.2026) respecto de la version del 03.09.2026
*
*   1. ANIOS DE ORDEN SEPARADOS DEL ANIO BASE. El decil de origen se arma con
*      el ingreso de anios ANTERIORES a la base del crecimiento:
*          covid   orden (a) 2017, (b) promedio 2015-2017 ; base 2018
*      Antes el mismo ingreso de 2018 ordenaba Y era el denominador, asi que
*      un shock transitorio en 2018 metia a la persona en D10 y ademas le
*      inflaba la base: reversion a la media mecanica. ($base_year, $base_mode)
*   2. LOG-CRECIMIENTO COMO RESULTADO PRINCIPAL del analisis (1). El
*      crecimiento y/y_base - 1 pasa a ser la robustez (bloque 7.4, hoja
*      did_robustez). Con logs el dif-en-dif entre el anio t y el pre es
*      ln y_t - ln y_pre: la base se cancela. ($main_growth)
*   3. PLACEBO. Preset "placebo2018" (orden 2013-2015, base 2016, pre 2017,
*      post 2018-2019): la misma estructura en anios sin shock. Si el
*      dif-en-dif no da cero ahi, eso es reversion a la media y no COVID.
*      Lanzador: movilidad_shock_placebo.do
*   4. BLOQUE 11 NUEVO: LOS QUE SE VAN. Poblacion = observados en el anio pre.
*      Para cada anio post: (i) compara a los que se van con los que se
*      quedan ANTES del shock, dentro de cada decil; (ii) dif-en-dif de los
*      que se quedan y dos escenarios para los que se van (mantienen su
*      ingreso pre / su ingreso cae a cero); (iii) cotas de PEOR CASO
*      (Horowitz-Manski) con piso y techo explicitos, con IC de Imbens-Manski,
*      en tres variantes: p1/p99, p10/p90 y p20/p80 de los que se quedan.
*      Sale en A5_desercion_<shock>.xlsx.
*   5. Salidas en .../resultados/movilidad_v2/ y .dta intermedios en
*      .../data/movilidad_v2/ ($run_tag): no pisan la corrida anterior.
*   6. HETEROGENEIDAD (bloques 05.2 y 12): el dif-en-dif del analisis (1)
*      por grupos de edad, sexo, estado civil (casado o no), educacion
*      universitaria (SENESCYT, el titulo mas alto) y etnia. Un switch
*      general ($do_het) y uno por dimension ($het_edad ... $het_etnia).
*      Sale en A6_heterogeneidad_<shock>.xlsx.
*   7. D$hi_decile CONTRA D7, D8 Y D9 (bloque 7.6): el mismo dif-en-dif con
*      cada decil de $lo_list. Hoja did_vs_deciles del A1 y tambien en la
*      heterogeneidad.
*
* Dos shocks vienen preconfigurados en el BLOQUE 00 ($shock):
*       covid         base 2019 vs 2020, 2021 y 2022
*       petroleo2014  base 2013 vs 2014, 2015 y 2016  (colapso del precio del
*                     petroleo desde mediados de 2014)
*
* Y cada uno se puede correr en VERSION DE DOS ANIOS ($two_period 1), que se
* queda solo con el pre y el primer post -- covid 2019 vs 2020, petroleo2014
* 2013 vs 2014 -- sin tocar las dos definiciones del t0. Sale a la subcarpeta
* /dos_anios. Ver movilidad_shock_dos_anios.do.
*
* Parte del dataset final de data_preparation1.do
*       $data_out/working_data_unbalanced.dta
* del que solo necesita: id_bal, anio y las variables de ingreso
* (PreTaxHHI, D1R, capital, liq_107). Ese archivo conserva TODOS los anios
* del panel, que es lo que hace falta para la ventana t0 de 3 anios.
*
* Si preferis usar las variables YA construidas por data_preparation1.do
* (g_real_1_*, g_real_2_*, decil_t0_1_*, decil_t0_2_*), usa la VERSION B:
*       movilidad_shock_prep1.do
*
* -----------------------------------------------------------------------------
* MUESTRA DE ANALISIS: SOLO LOS DECILES DE ORIGEN 6-10
*
*   Los rangos se calculan igual que siempre, sobre TODA la poblacion: D10
*   sigue siendo el 10% mas rico de todos y D6 el percentil 51-60 de todos.
*   Recien despues se restringe el ANALISIS a las personas cuyo decil de
*   ORIGEN (en t0) cae en $keep_dec_lo-$keep_dec_hi (por defecto 6-10).
*   El decil CONTEMPORANEO sigue midiendose contra la poblacion completa del
*   anio, asi que una persona de origen D6 puede aparecer en D3 en 2021: eso
*   es una caida real y no un artificio de la restriccion.
*
*   El filtro es a nivel PERSONA (el decil de origen es fijo en t0), asi que
*   NO altera la estructura de atricion de la que dependen las cotas de Lee.
*
*   Como el decil de origen es distinto en cada columna (variable de ingreso x
*   definicion de t0), el filtro tambien lo es: se aplica poniendo a missing
*   todas las variables del par cuando su decil de origen queda fuera. Una
*   persona puede entrar por PreTaxHHI y quedar fuera por capital.
*
*   Para volver a la poblacion completa: $keep_dec_lo 1 y $keep_dec_hi 10
*   (y $bot_decile 1).
*
* -----------------------------------------------------------------------------
* QUE SALE LADO A LADO EN CADA EXCEL
*
*   COLUMNAS = variable de ingreso x definicion del ingreso en t0
*       ingreso  = PreTaxHHI   (ingreso pre-impuesto total)
*       D1R      = ingreso laboral
*       capital  = ingreso de capital (D4R + B2R)
*       liq_107  = base salarial del F107
*     x (a) ingreso real de $t0_year
*       (b) promedio del ingreso real $t0_win_first-$t0_win_last
*     ->  ingreso_a | ingreso_b | D1R_a | D1R_b | capital_a | ... | liq_107_b
*
*   FILAS = muestra x anio
*       unbal = panel NO balanceado (todos los que aparecen ese anio)
*       bal   = panel balanceado (observados en TODOS los anios de resultado)
*     Las dos muestras salen en la MISMA corrida, una debajo de la otra.
*     Dentro de cada muestra los rangos (deciles contemporaneos y de origen)
*     se calculan SOBRE ESA MUESTRA, igual que hace data_preparation1.do al
*     armar covid_balanced y covid_unbalanced por separado.
*
* -----------------------------------------------------------------------------
* CUATRO ANALISIS
*   (1) CRECIMIENTO DEL INGRESO POR DECIL DE ORIGEN (D10 vs D6, dif-en-dif)
*   (2) MOVILIDAD RELATIVA: cambios de decil respecto de t0
*   (3) PERMANENCIA EN LOS EXTREMOS: P(seguir en D$top_decile) y
*       P(seguir en D$bot_decile). Con la restriccion a D6-10 el extremo de
*       abajo pasa a ser D6, el decil mas bajo que queda en la muestra.
*   (4) COTAS DE LEE (2009) sobre TODAS las regresiones de la muestra NO
*       balanceada: la atricion no es aleatoria (es peor abajo), asi que la
*       composicion de los que siguen en el panel cambia entre anios. Se
*       recorta la muestra para igualar la tasa de retencion de todos los
*       anios a la minima, dentro de cada decil de origen, y se reestima.
*
*       El recorte es DIRECCIONAL. Para acotar por abajo un contraste como
*           theta = [g(D10,t) - g(D6,t)] - [g(D10,pre) - g(D6,pre)]
*       hay que recortar la cola ALTA de las celdas que entran con signo (+),
*       o sea (D10,t) y (D6,pre), y la cola BAJA de las que entran con signo
*       (-), o sea (D6,t) y (D10,pre). Recortar siempre por el mismo lado,
*       como se hace al acotar una MEDIA suelta, NO acota una DIFERENCIA.
*       Los modelos usados estan saturados en anio (x decil), asi que cada
*       coeficiente es exactamente una combinacion de medias de celda y una
*       sola regresion por cota alcanza para todos los anios post.
*
*       Outcomes acotados (todos en la muestra unbal):
*         g     crecimiento real         -> dif-en-dif D$hi_decile vs D$lo_decile
*         lg    log-crecimiento          -> dif-en-dif D$hi_decile vs D$lo_decile
*         ddec  cambio de decil          -> dif-en-dif D$hi_decile vs D$lo_decile
*         adec  cambio absoluto de decil -> efecto del anio
*         up    P(subir de decil)        -> efecto del anio
*         down  P(bajar de decil)        -> efecto del anio
*         top   P(seguir en D$top_decile) -> efecto del anio
*         bot   P(seguir en D$bot_decile) -> efecto del anio
*       Las pendientes rango-rango (en deciles y en percentiles) NO son medias,
*       asi que no admiten cotas de Lee: para ellas se reporta el RANGO DE
*       SENSIBILIDAD que producen los dos recortes simetricos, en hojas aparte
*       y etiquetado como tal.
*       Las especificaciones auxiliares del bloque 07 (2x2 con post agrupado y
*       la version con todos los deciles de origen) no se acotan: son lecturas
*       alternativas del mismo contraste que ya esta acotado en cotas_g.
*
*       INFERENCIA: cada par de cotas viene con su IC de IMBENS-MANSKI (2004),
*       que es el IC correcto para un parametro identificado solo de forma
*       parcial. Pegar dos IC de 95% (uno por cota) sobre-cubre; el de
*       Imbens-Manski usa un factor c que va de z(1-alpha/2)=1.960 cuando el
*       conjunto identificado es un punto a z(1-alpha)=1.645 cuando es muy
*       ancho. Los EE de las cotas salen de la regresion recortada por defecto
*       ($im_se "reg") o de un bootstrap de personas que recalcula el recorte
*       en cada replica ($im_se "boot"), que es la opcion correcta para
*       reportar. Detalles en el encabezado del bloque 10.
*   (5) LOS QUE SE VAN (bloque 11, nuevo en v2): comparacion pre-shock de
*       los que se van y los que se quedan, escenarios para los que se van y
*       cotas de peor caso. Ver el encabezado del bloque 11.
*
* -----------------------------------------------------------------------------
* COMO SE USA
*   - Todo lo configurable esta en el BLOQUE 00. Para analizar OTRO shock
*     alcanza con cambiar $shock (si ya tiene preset) o agregar un preset.
*   - Se ejecuta POR BLOQUES: cada bloque numerado abre su propio .dta
*     permanente y no depende de locals ni de tempfiles de bloques anteriores.
*     Los unicos locals son iteradores de loops.
*   - EXCEPCION: los bloques 00 y 01 hay que correrlos siempre al abrir Stata,
*     porque definen los globals que usan todos los demas.
*   - VARIANTES: cada una se apila en su propia subcarpeta y le agrega un
*     sufijo al prefijo de los .dta, asi que ninguna corrida pisa a otra:
*         $two_period 1  ->  .../$shock/dos_anios/       (.dta *_2p_*)
*         $wins_p > 0    ->  .../$shock[/dos_anios]/winsorized/  (*_w<p>_*)
*     y todo cuelga de .../movilidad_$run_tag/ (v2: movilidad_v2).
*   - Se puede llamar desde otro do-file fijando ANTES los globals
*         $OVR_shock  $OVR_wins_p  $OVR_fake_root
*         $OVR_two_period  $OVR_im_se  $OVR_im_reps
*         $OVR_base_mode  $OVR_main_growth  $OVR_do_leavers  $OVR_run_tag
*         $OVR_do_het
*     (ver movilidad_shock_petroleo2014.do). El bloque 00 los lee, los BORRA
*     y recien despues los aplica, para que no queden pegados en la sesion.
*   - No se usa -tabstat- en ningun lado (es lento en paneles grandes): todos
*     los descriptivos salen de -collapse- sobre archivos ya adelgazados.
*   - Los logs se abren y se cierran POR NOMBRE (name(movlog)), asi que este
*     do-file ya no cierra logs que hayas abierto vos.
*   - OJO: -putexcel ..., replace- falla si el .xlsx esta abierto en Excel.
*     Cerrar los archivos de salida antes de re-correr los bloques de tablas.
*******************************************************************************/


* ============================================================================
* 00. PARAMETROS  --- LO UNICO QUE HAY QUE EDITAR PARA OTRO SHOCK ---
* ============================================================================

* --- Overrides opcionales, para poder llamar este do-file desde otro --------
* Se copian a locals y se BORRAN enseguida. OJO: -clear all- NO borra los
* globals (verificado en Stata 19), asi que si no se los borra a mano quedan
* pegados toda la sesion: correr el lanzador de petroleo2014 y despues este
* do-file a mano seguiria analizando petroleo2014 sin avisar.
local _ovr_shock "$OVR_shock"
local _ovr_wins  "$OVR_wins_p"
local _ovr_fake  "$OVR_fake_root"
local _ovr_two   "$OVR_two_period"
local _ovr_imse  "$OVR_im_se"
local _ovr_imrep "$OVR_im_reps"
local _ovr_base  "$OVR_base_mode"
local _ovr_main  "$OVR_main_growth"
local _ovr_lv    "$OVR_do_leavers"
local _ovr_tag   "$OVR_run_tag"
local _ovr_het   "$OVR_do_het"
* uno por linea: -macro drop A B C- se corta en el primero que no existe
capture macro drop OVR_shock
capture macro drop OVR_wins_p
capture macro drop OVR_fake_root
capture macro drop OVR_two_period
capture macro drop OVR_im_se
capture macro drop OVR_im_reps
capture macro drop OVR_base_mode
capture macro drop OVR_main_growth
capture macro drop OVR_do_leavers
capture macro drop OVR_run_tag
capture macro drop OVR_do_het

clear all
set more off
set seed 20260828
capture set matsize 800
capture set maxvar 32000

* --- Identificador del shock (se usa en TODOS los nombres de archivo) -------
* Valores con preset:  covid | petroleo2014 | placebo2018
global shock        "covid"
if "`_ovr_shock'" != "" global shock "`_ovr_shock'"

* --- Definicion temporal del shock (preset segun $shock) -------------------
* t0 = anios de ORDEN: con ellos se arma el decil de origen.
*   (a) nivel del ingreso real en $t0_year
*   (b) promedio del ingreso real $t0_win_first-$t0_win_last
* $base_year = base del crecimiento (con $base_mode "year"):
*   g_t = y_t / y_base - 1        lg_t = ln y_t - ln y_base
* Los anios de orden tienen que quedar ESTRICTAMENTE antes de la base: si se
* solapan, un shock transitorio del anio base ordena y a la vez infla el
* denominador (reversion a la media mecanica). Y la base tiene que quedar
* ESTRICTAMENTE antes de $pre_year: si no, el crecimiento del anio pre es
* cero por construccion y el dif-en-dif se queda sin periodo pre.
if "$shock" == "covid" {
    global t0_year      2017                // (a) orden: ingreso de 2017
    global t0_win_first 2015                // (b) orden: promedio 2015-2017
    global t0_win_last  2017
    global base_year    2018                // base del crecimiento
    global pre_year     2019                // anio de referencia PRE-shock
    global post_years   "2020 2021 2022"    // anios POST-shock a comparar
    global shock_desc   "Pandemia COVID-19"
}
else if "$shock" == "petroleo2014" {
    * El precio del crudo se derrumba a mediados de 2014, asi que 2014 ya es
    * un anio de shock y el ultimo anio normal es 2013.
    * OJO: la ventana (b) tiene 2 anios y no 3 porque el IPC del bloque 02
    * arranca en 2010. Si el panel tiene 2009, agregar el IPC 2009 y poner
    * t0_win_first 2009.
    global t0_year      2011
    global t0_win_first 2010
    global t0_win_last  2011
    global base_year    2012
    global pre_year     2013
    global post_years   "2014 2015 2016"
    global shock_desc   "Colapso del precio del petroleo (2014)"
}
else if "$shock" == "placebo2018" {
    * PLACEBO: la misma estructura pero SIN shock entre el pre y el post.
    * 2017-2019 no tienen un shock grande (despues de la recesion 2015-2016
    * y antes del COVID). Si el dif-en-dif D10 vs D6 no da cero aca, lo que
    * se mide con el COVID incluye reversion a la media.
    * Solo hay DOS anios post (2020 ya es COVID): se comparan con los dos
    * primeros horizontes del COVID (2020 y 2021).
    global t0_year      2015
    global t0_win_first 2013
    global t0_win_last  2015
    global base_year    2016
    global pre_year     2017
    global post_years   "2018 2019"
    global shock_desc   "Placebo sin shock (pre 2017, post 2018-2019)"
}
else {
    di as error "Shock sin preset: $shock"
    di as error "  Usar covid | petroleo2014 | placebo2018, o agregar el preset en el bloque 00."
    exit 198
}

* anios no-missing exigidos en (b): la ventana completa
global t0b_minyears = $t0_win_last - $t0_win_first + 1

* --- Base del crecimiento ---------------------------------------------------
* "year" = crecimiento desde $base_year, el mismo para (a) y (b)      (v2)
* "sort" = crecimiento desde el MISMO ingreso que ordena (y0_a o y0_b) (v1)
*          Para reproducir la v1 del COVID: base_mode "sort", t0_year 2018,
*          t0_win_first 2016, t0_win_last 2018 y main_growth "g".
* Con "year" solo entra al ranking quien tiene ingreso positivo en la base:
* sin base no hay crecimiento, y dejarlo en riesgo lo contaria como que se
* fue en TODOS los anios.
global base_mode    "year"
if "`_ovr_base'" != "" global base_mode "`_ovr_base'"

* --- Resultado principal del analisis (1) ----------------------------------
* "lg" = log-crecimiento (principal en v2) | "g" = y/y_base - 1
* El otro se estima igual como robustez (7.4) y sale en la hoja did_robustez.
global main_growth  "lg"
if "`_ovr_main'" != "" global main_growth "`_ovr_main'"

* --- VERSION DE DOS ANIOS: solo el pre y el PRIMER post --------------------
* 1 = se queda unicamente con $pre_year y el primer anio de $post_years:
*       covid         2019 vs 2020
*       petroleo2014  2013 vs 2014
*     Los anios de orden (t0) y la base del crecimiento no cambian: con
*     covid, orden 2017 / 2015-2017 y base 2018; con petroleo2014, orden
*     2011 / 2010-2011 y base 2012.
* 0 = version completa, con todos los anios post.
* Los resultados van a la subcarpeta /dos_anios para no mezclarse.
global two_period   0
if "`_ovr_two'" != "" global two_period `_ovr_two'

if $two_period == 1 {
    local _p1 : word 1 of $post_years
    global post_years "`_p1'"
}

* --- Variables de ingreso (etiqueta corta) y su nombre en el archivo -------
* Las dos listas van EN EL MISMO ORDEN. La etiqueta es la que aparece en los
* Excel; el nombre fuente es el de la variable en $src_file.
global inc_vars     "ingreso D1R capital liq_107"
global inc_source   "PreTaxHHI D1R capital liq_107"

* --- Muestras que se estiman en la misma corrida ---------------------------
* Dejar las dos para tenerlas lado a lado. Se puede dejar una sola.
global samples      "unbal bal"

* --- RESTRICCION DE LA MUESTRA: deciles de ORIGEN que se analizan ----------
* Por defecto 6-10. Poner 1 y 10 para volver a la poblacion completa.
global keep_dec_lo  6
global keep_dec_hi  10

* --- Deciles a contrastar en el analisis (1) -------------------------------
global hi_decile    10
global lo_decile    6
* Deciles de comparacion del bloque 7.6 y de la heterogeneidad (bloque 12):
* D$hi_decile contra cada uno. D$lo_decile repite el analisis principal.
* Los bloques 7.1-7.4, 10 y 11 siguen usando solo D$lo_decile.
global lo_list      "6 7 8 9"

* --- Deciles extremos para el analisis (3) ---------------------------------
* Con la restriccion a D6-10 el extremo de abajo es D6: D1 ya no existe en la
* muestra. Si se levanta la restriccion, volver a poner bot_decile 1.
global top_decile   10
global bot_decile   6

* --- Fuente -----------------------------------------------------------------
global src_id       "id_bal"
global src_year     "anio"

global min_t0       0               // ingreso real minimo en t0 (0 = sin filtro)
global wins_p       1               // winsorizar g en p / 100-p (0 = no winsorizar)
                                    // Por defecto 1 (p1 / p99): con la base separada
                                    // del orden, una base casi nula hace explotar
                                    // y_t / y_base. Solo afecta a g (gw); el
                                    // log-crecimiento no se winsoriza. Con > 0 todo
                                    // sale en la subcarpeta /winsorized.
if "`_ovr_wins'" != "" global wins_p `_ovr_wins'
global do_transmat  1               // 1 = exportar matrices de transicion al log
global do_lee       1               // 1 = correr las cotas de Lee (bloque 10)
global do_lee_all   1               // 1 = cotas para TODAS las regresiones unbal
                                    // 0 = solo para el analisis (1)

* --- IC de Imbens-Manski (2004) para las cotas de Lee ----------------------
global do_im        1               // 1 = calcular los IC (bloque 10.5)
global im_alpha     0.05            // 1 - nivel de confianza
global im_se        "reg"           // de donde salen los EE de las cotas:
                                    //  "reg"  EE de la regresion recortada,
                                    //         agrupados por persona. Rapido,
                                    //         pero IGNORA que la fraccion de
                                    //         recorte q tambien se estima.
                                    //  "boot" bootstrap de PERSONAS: recalcula
                                    //         el recorte en cada replica. Es
                                    //         lo correcto para el paper, y
                                    //         cuesta $im_reps veces mas.
global im_reps      200             // replicas del bootstrap (solo si "boot")
if "`_ovr_imse'"  != "" global im_se   "`_ovr_imse'"
if "`_ovr_imrep'" != "" global im_reps `_ovr_imrep'

* --- BLOQUE 11: los que se van ----------------------------------------------
global do_leavers   1               // 1 = correr el bloque 11
if "`_ovr_lv'" != "" global do_leavers `_ovr_lv'
* Cotas de PEOR CASO: el resultado de los que se van (crecimiento desde la
* base hasta t) se lleva al piso o al techo del de los que se QUEDAN, en su
* decil y anio. Una variante por par de percentiles, en el mismo orden en
* las dos listas: p1/p99, p10/p90 y p20/p80. Las variantes angostas NO son
* cotas de peor caso: suponen que los que se van no caen mas abajo del p10
* (p20) ni suben mas arriba del p90 (p80) de los que se quedan.
global wc_p_lo      "1 10 20"
global wc_p_hi      "99 90 80"
* En g (y/y_base - 1) la PRIMERA variante usa como piso -1 (ingreso cero),
* que es la cota natural del soporte, en vez del percentil. 0 = usar el
* percentil tambien ahi. Las demas variantes usan siempre los percentiles.
global wc_g_floor0  1
* Escenario "quedan, winsorizado": tope del crecimiento (base -> pre y base -> t)
* en este percentil, un solo umbral para D$lo_decile y D$hi_decile por anio.
global win_scen_p   99

* --- HETEROGENEIDAD (bloques 05.2 y 12) --------------------------------------
* El dif-en-dif del analisis (1) (resultado principal, D$hi_decile contra
* cada decil de $lo_list) por grupos. Un switch general y uno por dimension.
* Las caracteristicas son FIJAS por persona:
*   edad    grupo de edad en $base_year, con cortes en $het_age_cuts
*   sexo    genero del registro civil (1 hombre, 2 mujer)
*   civil   casado (codigos $het_married_codes de estado_civil) o no
*   educ    titulo universitario (tercer o cuarto nivel) en SENESCYT: el
*           titulo mas alto registrado de la persona
*   etnia   OJO: el registro civil real NO tiene etnia; la variable existe
*           solo en los datos falsos. Dejar en 0 hasta tener una fuente.
* Las fuentes (registro civil y SENESCYT) se fijan en el bloque 01.
global do_het            1          // 0 = apaga TODA la heterogeneidad
if "`_ovr_het'" != "" global do_het `_ovr_het'
global het_edad          1
global het_sexo          1
global het_civil         1
global het_educ          1
global het_etnia         0
global het_age_cuts      "30 45 60" // grupos: <30, 30-44, 45-59, 60+
global het_married_codes "2"        // codigos de estado_civil que cuentan como
                                    // casado. Registro civil: 1 soltero,
                                    // 2 casado, 3 divorciado, 4 viudo, 5 union
                                    // de hecho (VERIFICAR). "2 5" = incluir la
                                    // union de hecho.

* --- Etiqueta de la corrida -------------------------------------------------
* Todo va a .../movilidad_$run_tag/ (resultados) y .../data/movilidad_$run_tag/
* (.dta intermedios), para no pisar la corrida anterior. "none" = carpetas
* de la v1 (.../movilidad/).
global run_tag      "v2"
if "`_ovr_tag'" != "" global run_tag "`_ovr_tag'"
if "$run_tag" == "none" global run_tag ""

* --- Deflactor --------------------------------------------------------------
global ipc_source   "inline"        // "inline" (tabla del bloque 02) | "file"

* --- Datos falsos para pruebas (vacio en produccion) ------------------------
global fake_root    ""
if "`_ovr_fake'" != "" global fake_root "`_ovr_fake'"


* ============================================================================
* 01. RUTAS Y GLOBALS DERIVADOS   (correr siempre junto con el bloque 00)
* ============================================================================

* Rutas de la maquina del SRI. Son EXACTAMENTE las mismas que usan
* movilidad_shock_prep1.do (version B) y analysis.do: si alguna vez cambia la
* raiz, hay que cambiarla en los tres.
global user_root  "D:/DTO_ESTUDIOS_E1/B_INVESTIGADORES_EXTERNOS/2025.12.01_Santiago_Valdivieso/"

global ipc        "$user_root/03 BDD/IPC"
global dina       "$user_root/03 BDD/SRI/IR/Merged/ingreso_dina"
global data_out   "$user_root/Proyectos/Impacto shocks/data"
global results    "$user_root/Proyectos/Impacto shocks/resultados"

* Archivo fuente: el panel completo que deja data_preparation1.do.
* OJO: NO es el mismo que lee la version B. Esta version (A) reconstruye las
* variables desde el panel crudo, asi que necesita TODOS los anios:
*       $data_out/working_data_unbalanced.dta
* La version B (movilidad_shock_prep1.do) arranca de los archivos de rangos ya
* construidos, $dina/ranks/covid_unbalanced.dta y covid_balanced.dta.
global src_file   "$data_out/working_data_unbalanced.dta"

* --- Fuentes de la heterogeneidad (bloque 05.2) -----------------------------
* Registro civil: una fila por persona, con id_bal, genero, fecha_nac,
* estado_civil y cedula_pk.
global ced_file   "$user_root/Proyectos/Impacto shocks/temp/data/catastro_regciv_ruc.dta"
global ced_etnia  "etnia"           // variable de etnia (NO existe en el real)
* SENESCYT: registro de titulos, una fila por titulo. Es el cruce
* cruce_FLACSO_051218.dta (1.8 millones de titulos registrados hasta dic-2018).
*                                                        <<< AJUSTAR la ruta
global sen_file   "$user_root/03 BDD/SENESCYT/cruce_FLACSO_051218.dta"
* OJO CON EL ID. El archivo original trae la cedula REAL (variable cedula, 10
* digitos) y el registro civil del SRI solo trae la cedula ENMASCARADA
* (cedula_pk, "C14033860"). No se pueden cruzar tal cual: el SRI tiene que
* pasar la cedula de SENESCYT por su mismo enmascaramiento y dejarla en una
* variable con el formato de cedula_pk (o directamente en id_bal).
global sen_id      "cedula_pk"      // id de la persona en SENESCYT
global ced_xwalk_id "cedula_pk"     // variable del registro civil con el MISMO
                                    // formato que $sen_id (cruce a id_bal). Si
                                    // $sen_id es id_bal no se usa.
global sen_level  "niveldeformacion" // nivel del titulo, texto. En el archivo:
                                    // Nivel Tecnico Superior, Educacion Tecnica /
                                    // Tecnologica Superior..., TECNICO, TECNOLOGICO,
                                    // Tercer Nivel o Pregrado, TERCER_NIVEL,
                                    // Cuarto Nivel o Posgrado, CUARTO_NIVEL
global sen_date   "fecha_acta_grado fecha_registro"
                                    // fecha del titulo: se usa la PRIMERA que
                                    // tenga un anio valido (1940-2030). Solo
                                    // cuentan los titulos hasta $base_year.
                                    // Texto "AAAA-MM-DD ..." o fecha de Stata.
                                    // Vacio = sin filtro de fecha.

* --- Para probar con datos falsos: fijar $OVR_fake_root antes de correr -----
if "$fake_root" != "" {
    global ipc      "$fake_root"
    global data_out "$fake_root"
    global results  "$fake_root/resultados"
    global src_file "$fake_root/working_data_unbalanced.dta"
    global ced_file "$fake_root/catastro_regciv_ruc.dta"
    global sen_file "$fake_root/titulos_Senescyt.dta"
}

* Carpetas de salida (mkdir no crea anidados: se crean nivel por nivel)
* Las variantes se apilan en subcarpetas, para que ninguna corrida pise a
* otra:  .../movilidad/$shock[/dos_anios][/winsorized]/
global mov_dir "movilidad"
if "$run_tag" != "" global mov_dir "movilidad_${run_tag}"

capture mkdir "$results"
capture mkdir "$results/$mov_dir"

global out "$results/$mov_dir/$shock"
capture mkdir "$out"

if $two_period == 1 {
    global out "$out/dos_anios"
    capture mkdir "$out"
}
if $wins_p > 0 {
    global out "$out/winsorized"
    capture mkdir "$out"
}

capture mkdir "$out/descriptivos"
capture mkdir "$out/regresiones"
capture mkdir "$out/tablas"

* Carpeta de datos intermedios (archivos PERMANENTES, no tempfiles)
capture mkdir "$data_out/$mov_dir"
global work   "$data_out/$mov_dir"

* Prefijo de los .dta intermedios. Lleva un sufijo por cada variante activa,
* asi que las corridas nunca se pisan los archivos de trabajo.
global fstem "$shock"
if $two_period == 1 global fstem "${fstem}_2p"
if $wins_p > 0      global fstem "${fstem}_w${wins_p}"

* --- Anios de resultado (pre + post) ---------------------------------------
global out_years   "$pre_year $post_years"
global out_years_c = subinstr(trim("$out_years"), " ", ",", .)
global n_out_years = wordcount("$out_years")
global n_post      = wordcount("$post_years")

* --- Variables de ingreso y muestras ---------------------------------------
global n_inc       = wordcount("$inc_vars")
global n_pairs     = 2 * $n_inc          // (variable x definicion de t0)
global n_samp      = wordcount("$samples")

* --- Deciles conservados ----------------------------------------------------
global n_dec       = $keep_dec_hi - $keep_dec_lo + 1

* Filas de las tablas: muestra x anio  /  muestra x anio post
global n_rows_y    = $n_samp * $n_out_years
global n_rows_p    = $n_samp * $n_post

* Filas de la tabla de retencion por decil: decil x anio
global n_rows_d    = $n_dec * $n_out_years

* --- Rango de anios que hay que leer del panel -----------------------------
global yr_first    = min($t0_win_first, $t0_year, $base_year)
global yr_last     = max($pre_year, real(word("$post_years", wordcount("$post_years"))))

* --- Letras de columna de Excel (1=A ... 80=CB) ----------------------------
global ABC "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
global XLCOL ""
forvalues i = 1/80 {
    local cl = cond(`i' <= 26, substr("$ABC", `i', 1),                     ///
                    substr("$ABC", int((`i'-1)/26), 1) +                   ///
                    substr("$ABC", mod(`i'-1, 26) + 1, 1))
    global XLCOL "$XLCOL `cl'"
}

* --- Etiquetas de las columnas de los Excel (var x def), en orden ----------
global PAIRLAB ""
foreach v of global inc_vars {
    foreach j in a b {
        global PAIRLAB "$PAIRLAB `v'_`j'"
    }
}

if "$base_mode" == "year" global base_lab "$base_year"
else                      global base_lab "= orden"
global shock_lab "$shock | pre $pre_year | orden a=$t0_year b=$t0_win_first-$t0_win_last | base $base_lab | origen D$keep_dec_lo-D$keep_dec_hi | principal $main_growth"
if $two_period == 1 global shock_lab "$shock_lab | solo $pre_year vs $post_years"
if $wins_p > 0      global shock_lab "$shock_lab | winsorizado p$wins_p"

* --- Controles de coherencia de los parametros -----------------------------
if !inrange($hi_decile, $keep_dec_lo, $keep_dec_hi) | ///
   !inrange($lo_decile, $keep_dec_lo, $keep_dec_hi) {
    di as error "OJO: hi_decile ($hi_decile) o lo_decile ($lo_decile) caen FUERA"
    di as error "     de los deciles conservados ($keep_dec_lo-$keep_dec_hi):"
    di as error "     el analisis (1) va a salir vacio."
}
if !inrange($top_decile, $keep_dec_lo, $keep_dec_hi) | ///
   !inrange($bot_decile, $keep_dec_lo, $keep_dec_hi) {
    di as error "OJO: top_decile ($top_decile) o bot_decile ($bot_decile) caen"
    di as error "     FUERA de los deciles conservados ($keep_dec_lo-$keep_dec_hi):"
    di as error "     el analisis (3) va a salir vacio de ese lado."
}

foreach c of global lo_list {
    if !inrange(`c', $keep_dec_lo, $keep_dec_hi) | `c' >= $hi_decile {
        di as error "lo_list: el decil `c' tiene que estar en $keep_dec_lo-$keep_dec_hi y debajo de D$hi_decile"
        exit 198
    }
}
if "$base_mode" != "year" & "$base_mode" != "sort" {
    di as error "base_mode tiene que ser year o sort: $base_mode"
    exit 198
}
if "$main_growth" != "lg" & "$main_growth" != "g" {
    di as error "main_growth tiene que ser lg o g: $main_growth"
    exit 198
}
if "$base_mode" == "year" {
    if $base_year >= $pre_year {
        di as error "base_year ($base_year) tiene que ser ANTERIOR a pre_year ($pre_year)"
        exit 198
    }
    if max($t0_year, $t0_win_last) >= $base_year {
        di as error "OJO: los anios de orden (t0) se solapan con la base del"
        di as error "     crecimiento ($base_year): vuelve la reversion a la media mecanica."
    }
}
else if max($t0_year, $t0_win_last) >= $pre_year {
    di as error "t0 tiene que quedar ANTES de pre_year ($pre_year)"
    exit 198
}

di as result _n "== Shock: $shock_lab =="
di as text "   descripcion          : $shock_desc"
di as text "   variables de ingreso : $inc_vars"
di as text "   muestras             : $samples"
di as text "   deciles de origen    : $keep_dec_lo - $keep_dec_hi  ($n_dec deciles)"
di as text "   orden (t0)           : (a) $t0_year  (b) $t0_win_first-$t0_win_last"
di as text "   base del crecimiento : $base_lab   (base_mode = $base_mode)"
di as text "   resultado principal  : $main_growth"
if $two_period == 1 di as text "   modo                 : DOS ANIOS ($pre_year vs $post_years)"
if $do_lee == 1     di as text "   IC de Imbens-Manski  : alpha=$im_alpha, EE=$im_se" _newline ///
                              "                          (im_reps=$im_reps si EE=boot)"
di as text "   columnas de los Excel: $PAIRLAB"
di as text "   anios de resultado   : $out_years"
di as text "   panel a leer         : $yr_first - $yr_last"
di as text "   fuente               : $src_file"
di as text "   salidas en           : $out"

* Aviso temprano si la fuente no esta donde se la espera. Es un aviso y no un
* -exit-, para no cortar la corrida por bloques cuando ya estan los .dta
* intermedios del bloque 03 en adelante.
capture confirm file "$src_file"
if _rc {
    di as error _n "OJO: no encuentro el archivo fuente"
    di as error    "     $src_file"
    di as error    "  Es la salida de data_preparation1.do. Si en esta maquina esta"
    di as error    "  en otro lado, ajustar \$src_file (o \$data_out) en el bloque 01."
    di as error    "  El bloque 03 va a fallar; del 04 en adelante funciona si ya"
    di as error    "  corriste el 03 antes."
}
di as text "   .dta intermedios     : $work/${fstem}_*.dta"


* ============================================================================
* 02. DEFLACTOR  ->  $work/defl_${shock}.dta
* ============================================================================
* Hace falta IPC para TODOS los anios entre $yr_first y $yr_last.
* Cada anio se deflacta con SU PROPIO IPC y recien despues se promedia:
* promediar nominales y dividir por un IPC promedio NO es equivalente.

clear
if "$ipc_source" == "file" {
    use "$ipc/defl.dta", clear
    keep anio ipc
}
else {
    * IPC Ecuador, base 2014 = 100 (INEC). Actualizar/ampliar segun el shock.
    input int anio double ipc
    2010  85.10
    2011  89.00
    2012  93.50
    2013  96.10
    2014 100.00
    2015 103.97
    2016 105.75
    2017 105.16
    2018 105.28
    2019 105.21
    2020 104.23
    2021 106.26
    2022 110.23
    2023 112.61
    2024 113.90
    end
}
label var ipc "IPC (base 2014=100)"
keep if inrange(anio, $yr_first, $yr_last)
isid anio
save "$work/defl_${shock}.dta", replace

quietly count
if r(N) != ($yr_last - $yr_first + 1) {
    di as error "OJO: faltan anios de IPC entre $yr_first y $yr_last."
    tabulate anio
}
list, noobs sep(0)


* ============================================================================
* 03. PANEL DE INGRESO REAL  ->  $work/${fstem}_long.dta
* ============================================================================
* Una fila por (persona, anio) con el ingreso real de cada variable y el
* indicador bal_panel (observado en todos los anios de resultado).
* Los rangos NO se calculan aca: dependen de la muestra y se arman en el
* bloque 05, dentro de cada muestra.

use $src_id $src_year $inc_source using "$src_file", clear

rename $src_id   id
rename $src_year anio

* Renombrar las variables fuente a las etiquetas cortas de $inc_vars
forvalues k = 1/$n_inc {
    local src : word `k' of $inc_source
    local lab : word `k' of $inc_vars
    if "`src'" != "`lab'" rename `src' `lab'
}

drop if missing(id) | missing(anio)
duplicates drop id anio, force
keep if inrange(anio, $yr_first, $yr_last)

* Valores no positivos -> missing (crecimiento y logs no definidos en <=0).
* Se conserva la fila si AL MENOS UNA variable de ingreso es positiva.
foreach v of global inc_vars {
    replace `v' = . if `v' <= 0
}
egen byte _any = rownonmiss($inc_vars)
keep if _any > 0
drop _any

merge m:1 anio using "$work/defl_${shock}.dta", keep(1 3) nogenerate

foreach v of global inc_vars {
    gen double real_`v' = `v' / (ipc/100)
    drop `v'
    label var real_`v' "Ingreso real (base 2014=100): `v'"
}
drop ipc

* --- Indicador de panel balanceado en los anios de resultado ---------------
gen byte _out = inlist(anio, $out_years_c)
bysort id: egen int n_years_obs = total(_out)
drop _out
gen byte bal_panel = n_years_obs == $n_out_years
label var bal_panel "=1 observado en todos los anios de resultado"

compress
sort id anio
save "$work/${fstem}_long.dta", replace

* --- Control: el archivo fuente tiene que cubrir TODA la ventana -----------
quietly levelsof anio, local(yrs_hay)
forvalues y = $yr_first/$yr_last {
    local ok : list y in yrs_hay
    if !`ok' {
        di as error "FALTA el anio `y' en $src_file."
        di as error "  La definicion (b) de t0 necesita $t0_win_first-$t0_win_last."
    }
}

tabulate anio


* ============================================================================
* 04. INGRESO EN t0  ->  $work/${fstem}_t0.dta
* ============================================================================
* Una fila por persona con, para cada variable de ingreso, los dos NIVELES
* de ORDEN en t0 (no los deciles: esos dependen de la muestra y se calculan
* en 05) y la BASE del crecimiento.
*   y0_a_`v' = ingreso real de $t0_year
*   y0_b_`v' = promedio de los ingresos reales de $t0_win_first..$t0_win_last,
*              exigiendo al menos $t0b_minyears anios observados
*   yb_`v'   = ingreso real de $base_year (base del crecimiento si
*              $base_mode == "year"). Con "year", quien no tiene base queda
*              fuera del ranking: y0_a / y0_b a missing.

use "$work/${fstem}_long.dta", clear
keep id anio real_* bal_panel

foreach v of global inc_vars {

    gen double _yb = real_`v' if anio == $base_year
    bysort id: egen double yb_`v' = max(_yb)
    drop _yb
    label var yb_`v' "Ingreso real en la base $base_year: `v'"

    gen double _ya = real_`v' if anio == $t0_year
    bysort id: egen double y0_a_`v' = max(_ya)
    drop _ya

    gen double _yw = real_`v' if inrange(anio, $t0_win_first, $t0_win_last)
    bysort id: egen double y0_b_`v' = mean(_yw)
    bysort id: egen byte  n_win_`v' = count(_yw)
    replace y0_b_`v' = . if n_win_`v' < $t0b_minyears
    drop _yw

    label var y0_a_`v'  "Ingreso real en $t0_year: `v'"
    label var y0_b_`v'  "Ingreso real promedio $t0_win_first-$t0_win_last: `v'"
    label var n_win_`v' "Anios observados en la ventana t0: `v'"

    if "$base_mode" == "year" {
        replace y0_a_`v' = . if missing(yb_`v')
        replace y0_b_`v' = . if missing(yb_`v')
    }
}

bysort id: gen byte _first = _n == 1
keep if _first
keep id y0_* yb_* n_win_* bal_panel

* --- Filtro opcional de ingreso minimo en t0 -------------------------------
if $min_t0 > 0 {
    foreach v of global inc_vars {
        foreach j in a b {
            replace y0_`j'_`v' = . if y0_`j'_`v' < $min_t0
        }
    }
}

compress
isid id
save "$work/${fstem}_t0.dta", replace

foreach v of global inc_vars {
    foreach j in a b {
        quietly count if !missing(y0_`j'_`v')
        di as text "Personas con y0_`j'_`v': " as result r(N)
        if r(N) == 0 di as error "  VACIO: revisar la ventana t0 y el bloque 03."
    }
}


* ============================================================================
* 05. DATASET DE ANALISIS (APILADO POR MUESTRA) -> $work/${fstem}_analysis.dta
* ============================================================================
* Se arma una vez por muestra y se apila, con la variable -muestra-
* (1 = unbal, 2 = bal). Dentro de cada muestra se recalculan TODOS los rangos:
*   decil_`v'      decil contemporaneo, dentro del anio y de la muestra
*   decil0_`j'_`v' decil de origen, sobre la distribucion de y0 en la muestra
* Asi cada muestra es una estimacion autocontenida, igual que covid_balanced
* y covid_unbalanced en data_preparation1.do.
*
* AL FINAL se aplica la restriccion a los deciles de origen $keep_dec_lo -
* $keep_dec_hi: los rangos ya estan calculados sobre la poblacion completa,
* asi que la restriccion no los mueve.

capture erase "$work/${fstem}_analysis.dta"
capture erase "$work/${fstem}_dec_means.dta"

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "########## armando la muestra: `s' ##########"

    use "$work/${fstem}_long.dta", clear
    keep if inlist(anio, $out_years_c)
    if "`s'" == "bal" keep if bal_panel == 1

    merge m:1 id using "$work/${fstem}_t0.dta", keep(1 3) nogenerate ///
        keepusing(y0_* yb_* n_win_*)

    gen byte muestra = `si'
    label define muestra_lb 1 "unbal" 2 "bal", replace
    label values muestra muestra_lb
    label var muestra "Muestra (1 = no balanceada, 2 = balanceada)"

    gen byte post = anio != $pre_year
    label var post "=1 anio posterior al shock"

    * ---- Rangos contemporaneos, dentro del anio y de la muestra ----------
    * Rank directo en vez de -xtile-: identico con ingresos continuos y mucho
    * mas barato. Desempate aleatorio pero reproducible (set seed).
    * Se calculan sobre TODA la poblacion del anio, ANTES de restringir a los
    * deciles de origen 6-10: D3 en 2021 sigue significando "el 30% mas pobre
    * de todos en 2021".
    foreach v of global inc_vars {
        gen double _u = runiform()
        sort anio real_`v' _u                  // los missing quedan al final
        by anio: gen double _rk = _n if !missing(real_`v')
        by anio: egen double _nn = count(real_`v')
        gen int pctl_`v'  = ceil(100 * _rk / _nn)
        gen int decil_`v' = ceil( 10 * _rk / _nn)
        * OJO: en Stata  missing > k  es VERDADERO -> topes SIEMPRE con !missing()
        replace pctl_`v'  = 100 if pctl_`v'  > 100 & !missing(pctl_`v')
        replace decil_`v' =  10 if decil_`v' >  10 & !missing(decil_`v')
        replace pctl_`v'  =   1 if pctl_`v'  <   1 & !missing(pctl_`v')
        replace decil_`v' =   1 if decil_`v' <   1 & !missing(decil_`v')
        drop _u _rk _nn
        label var pctl_`v'  "Percentil dentro del anio: `v'"
        label var decil_`v' "Decil dentro del anio: `v'"
    }

    * ---- Deciles de origen, a nivel PERSONA y dentro de la muestra -------
    bysort id: gen byte _fid = _n == 1
    foreach v of global inc_vars {
        foreach j in a b {
            gen double _u   = runiform()
            gen double _key = y0_`j'_`v' if _fid
            sort _key _u                        // los missing quedan al final
            gen double _rk = _n if !missing(_key)
            quietly count if !missing(_key)
            local Nj = r(N)
            gen int _p = ceil(100 * _rk / `Nj')
            gen int _d = ceil( 10 * _rk / `Nj')
            replace _p = 100 if _p > 100 & !missing(_p)
            replace _d =  10 if _d >  10 & !missing(_d)
            replace _p =   1 if _p <   1 & !missing(_p)
            replace _d =   1 if _d <   1 & !missing(_d)
            bysort id: egen int pctl0_`j'_`v'  = max(_p)
            bysort id: egen int decil0_`j'_`v' = max(_d)
            drop _u _key _rk _p _d
            label var pctl0_`j'_`v'  "Percentil de origen (def. `j'): `v'"
            label var decil0_`j'_`v' "Decil de origen (def. `j'): `v'"
        }
    }
    drop _fid

    * ---- Crecimiento, movilidad y extremos -------------------------------
    foreach v of global inc_vars {
        foreach j in a b {

            * base: $base_year (base_mode year) o el propio ingreso de orden
            * (base_mode sort, v1). Sin decil de origen no hay crecimiento.
            if "$base_mode" == "year" local _b yb_`v'
            else                      local _b y0_`j'_`v'
            gen double g_`j'_`v'  = real_`v' / `_b' - 1       if !missing(y0_`j'_`v')
            gen double lg_`j'_`v' = ln(real_`v') - ln(`_b')   if !missing(y0_`j'_`v')
            gen double gw_`j'_`v' = g_`j'_`v'
            label var g_`j'_`v'  "Crecimiento real desde la base (def. `j'): `v'"
            label var lg_`j'_`v' "Log-crecimiento desde la base (def. `j'): `v'"
            label var gw_`j'_`v' "Crecimiento winsorizado (def. `j'): `v'"

            gen int  ddec_`j'_`v' = decil_`v' - decil0_`j'_`v'
            gen int  adec_`j'_`v' = abs(ddec_`j'_`v')
            gen byte up_`j'_`v'   = ddec_`j'_`v' >  0 if !missing(ddec_`j'_`v')
            gen byte down_`j'_`v' = ddec_`j'_`v' <  0 if !missing(ddec_`j'_`v')
            gen byte stay_`j'_`v' = ddec_`j'_`v' == 0 if !missing(ddec_`j'_`v')
            label var ddec_`j'_`v' "Cambio de decil desde t0 (def. `j'): `v'"
            label var adec_`j'_`v' "|Cambio de decil| desde t0 (def. `j'): `v'"
            label var up_`j'_`v'   "=1 sube de decil (def. `j'): `v'"
            label var down_`j'_`v' "=1 baja de decil (def. `j'): `v'"
            label var stay_`j'_`v' "=1 se mantiene de decil (def. `j'): `v'"

            gen byte top_`j'_`v' = (decil_`v' == $top_decile) if decil0_`j'_`v' == $top_decile
            gen byte bot_`j'_`v' = (decil_`v' == $bot_decile) if decil0_`j'_`v' == $bot_decile
            label var top_`j'_`v' "=1 sigue en D$top_decile (origen D$top_decile, def. `j'): `v'"
            label var bot_`j'_`v' "=1 sigue en D$bot_decile (origen D$bot_decile, def. `j'): `v'"

            gen byte hi_`j'_`v' = decil0_`j'_`v' == $hi_decile if !missing(decil0_`j'_`v')
            label var hi_`j'_`v' "=1 origen D$hi_decile (vs D$lo_decile, def. `j'): `v'"
        }
    }

    * ---- Crecimiento medio por decil de origen, LOS 10 (para el bloque 11) ---
    * ANTES de restringir a D$keep_dec_lo-D$keep_dec_hi. Para cada columna, anio
    * post y decil de origen 1-10: media del crecimiento base -> t (lg y g) de
    * los que estan en $pre_year y en t ("se quedan"). La usa el escenario
    * "rango de deciles" del bloque 11 -> $work/${fstem}_dec_means.dta
    * g todavia no esta winsorizado aca.
    if $do_leavers == 1 {
        preserve
            keep id anio decil0_* lg_* g_*
            tempfile _slim _dm
            quietly save `_slim'
            local _k = 0
            foreach v of global inc_vars {
                foreach j in a b {
                    use id anio decil0_`j'_`v' lg_`j'_`v' g_`j'_`v' using `_slim', clear
                    quietly {
                        gen byte _p = anio == $pre_year & !missing(lg_`j'_`v')
                        bysort id: egen byte _inpre = max(_p)
                        keep if _inpre & anio != $pre_year & !missing(lg_`j'_`v', decil0_`j'_`v')
                        gen byte _uno = 1
                        collapse (mean) m_lg = lg_`j'_`v' m_gw = g_`j'_`v' (sum) n = _uno, ///
                            by(anio decil0_`j'_`v')
                        rename decil0_`j'_`v' decil
                        gen str16 pair = "`v'_`j'"
                        gen byte muestra = `si'
                        if `_k' > 0 append using `_dm'
                        save `_dm', replace
                    }
                    local _k = 1
                }
            }
            if `si' > 1 append using "$work/${fstem}_dec_means.dta"
            save "$work/${fstem}_dec_means.dta", replace
        restore
    }

    * ---- RESTRICCION A LOS DECILES DE ORIGEN $keep_dec_lo-$keep_dec_hi ----
    * Los rangos ya estan calculados sobre la poblacion completa. Aca solo se
    * saca del ANALISIS a quien tiene un decil de origen fuera del rango,
    * poniendo a missing todas las variables de ESE par (variable x def. t0)
    * y el propio decil de origen. Como el decil de origen es fijo por
    * persona, el filtro es a nivel persona: no toca la atricion.
    * Se hace ANTES de winsorizar para que los percentiles de recorte se
    * calculen sobre la muestra que efectivamente se analiza.
    if $keep_dec_lo > 1 | $keep_dec_hi < 10 {
        di as text "   restringiendo a los deciles de origen $keep_dec_lo-$keep_dec_hi ..."
        foreach v of global inc_vars {
            foreach j in a b {
                quietly {
                    gen byte _keep = inrange(decil0_`j'_`v', $keep_dec_lo, $keep_dec_hi)
                    foreach x in g lg gw ddec adec up down stay top bot hi {
                        replace `x'_`j'_`v' = . if !_keep
                    }
                    replace pctl0_`j'_`v'  = . if !_keep
                    replace decil0_`j'_`v' = . if !_keep
                    drop _keep
                }
            }
        }
    }

    * ---- Winsorizacion simetrica, dentro de cada anio y muestra ----------
    if $wins_p > 0 {
        levelsof anio, local(yrs)
        foreach v of global inc_vars {
            foreach j in a b {
                foreach y of local yrs {
                    quietly _pctile g_`j'_`v' if anio == `y', ///
                        percentiles($wins_p `= 100 - $wins_p ')
                    quietly replace gw_`j'_`v' = r(r1) ///
                        if anio == `y' & g_`j'_`v' < r(r1) & !missing(g_`j'_`v')
                    quietly replace gw_`j'_`v' = r(r2) ///
                        if anio == `y' & g_`j'_`v' > r(r2) & !missing(g_`j'_`v')
                }
            }
        }
    }

    * ---- Se descartan las filas que no entran en NINGUNA columna ---------
    * (personas con decil de origen fuera de $keep_dec_lo-$keep_dec_hi en las
    * ocho combinaciones). No cambia ningun resultado: solo achica el archivo.
    local _d0list ""
    foreach v of global inc_vars {
        foreach j in a b {
            local _d0list "`_d0list' decil0_`j'_`v'"
        }
    }
    egen byte _anykeep = rownonmiss(`_d0list')
    quietly count if _anykeep == 0
    di as text "   filas descartadas (fuera del rango en las $n_pairs columnas): " as result r(N)
    keep if _anykeep > 0
    drop _anykeep

    compress
    if `si' > 1 append using "$work/${fstem}_analysis.dta"
    save "$work/${fstem}_analysis.dta", replace
}

use "$work/${fstem}_analysis.dta", clear
sort muestra id anio
save "$work/${fstem}_analysis.dta", replace

di as result _n "== Muestra de analisis =="
tabulate anio muestra


* ---- 05.1 Archivos adelgazados para los descriptivos ----------------------
* Evitan repetir -preserve/restore- sobre el dataset completo en cada collapse.
* realk_`j'_`v' = ingreso real de quienes ENTRAN en esa columna (decil de
* origen dentro del rango). npair_`j'_`v' = 1 si esa columna tiene dato.

use "$work/${fstem}_analysis.dta", clear
foreach v of global inc_vars {
    foreach j in a b {
        gen double realk_`j'_`v' = real_`v' if !missing(decil0_`j'_`v')
        gen byte   npair_`j'_`v' = !missing(gw_`j'_`v')
        label var realk_`j'_`v' "Ingreso real, muestra D$keep_dec_lo-D$keep_dec_hi (def. `j'): `v'"
        label var npair_`j'_`v' "=1 la columna `v'_`j' tiene dato"
    }
}
gen byte n = 1
keep id muestra anio n realk_* npair_* gw_* lg_* adec_* ddec_* up_* down_* ///
     stay_* top_* bot_*
compress
save "$work/${fstem}_slim_desc.dta", replace

use "$work/${fstem}_analysis.dta", clear
keep muestra anio decil0_* gw_* lg_*
compress
save "$work/${fstem}_slim_gdec.dta", replace

use "$work/${fstem}_analysis.dta", clear
keep muestra anio decil_* decil0_*
compress
save "$work/${fstem}_slim_trans.dta", replace


* ---- 05.2 Caracteristicas de la persona (heterogeneidad) ------------------
*      ->  $work/${fstem}_carac.dta   (una fila por persona del analisis)
* Todas fijas por persona:
*   het_edad   grupo de edad en $base_year                      (registro civil)
*   het_sexo   1 hombre, 2 mujer                                (registro civil)
*   het_civil  1 casado, 0 no casado. OJO: es el estado civil a la fecha del
*              registro, no necesariamente el de $base_year      (registro civil)
*   het_etnia  solo si $het_etnia == 1 y la variable existe      (registro civil)
*   het_educ   1 = el titulo MAS ALTO registrado es de tercer o cuarto nivel
*              (universitario); 0 = tecnico / tecnologico o ningun titulo.
*              Solo cuentan los titulos con fecha hasta $base_year (fecha del
*              acta de grado; si falta, la de registro, que es posterior: el
*              filtro es conservador). Sin $sen_date cuenta cualquier titulo.
*                                                                (SENESCYT)
* Quien no esta en el registro civil queda con missing en edad, sexo, estado
* civil y etnia; quien no esta en SENESCYT tiene het_educ = 0.
* Clasificacion del nivel SENESCYT (por texto, sin tildes, en mayusculas):
*   1 tecnico / tecnologico   contiene TECNIC o TECNOLOG (incluye el "tercer
*                             nivel tecnico-tecnologico")
*   2 tercer nivel            contiene TERCER
*   3 cuarto nivel            contiene CUARTO, POSGRADO, MAESTR, DOCTOR,
*                             ESPECIALI o PHD
*   0 no reconocido           se avisa en el log con la lista de valores

if $do_het == 1 {

    use id using "$work/${fstem}_analysis.dta", clear
    bysort id: keep if _n == 1
    save "$work/${fstem}_carac.dta", replace
    quietly count
    di as result _n "== 05.2 caracteristicas: " r(N) " personas en el analisis =="

    * ---- registro civil ----------------------------------------------------
    if $het_edad == 1 | $het_sexo == 1 | $het_civil == 1 | $het_etnia == 1 {
        capture confirm file "$ced_file"
        if _rc {
            di as error "OJO: no encuentro el registro civil: $ced_file"
            di as error "     sin edad, sexo, estado civil ni etnia."
        }
        else {
            local _cv "id_bal genero fecha_nac estado_civil"
            local _et = 0
            if $het_etnia == 1 {
                capture describe $ced_etnia using "$ced_file"
                if _rc di as error "OJO: el registro civil no tiene la variable $ced_etnia: se saltea etnia."
                else {
                    local _cv "`_cv' $ced_etnia"
                    local _et = 1
                }
            }
            use `_cv' using "$ced_file", clear
            rename id_bal id
            drop if missing(id)
            duplicates drop id, force
            merge 1:1 id using "$work/${fstem}_carac.dta", keep(2 3)
            quietly count if _merge == 3
            local _nm = r(N)
            quietly count
            di as text "   en el registro civil: " as result `_nm' as text " de " as result r(N)
            drop _merge

            if $het_edad == 1 {
                gen int edad_base = $base_year - year(fecha_nac)
                label var edad_base "Edad en $base_year"
                gen byte het_edad = .
                local k = 0
                local prev = 0
                foreach cut of global het_age_cuts {
                    local k = `k' + 1
                    quietly replace het_edad = `k' if missing(het_edad) & edad_base < `cut' & !missing(edad_base)
                    if `k' == 1 label define het_edad_lb `k' "<`cut'", replace
                    else        label define het_edad_lb `k' "`prev'-`=`cut'-1'", add
                    local prev = `cut'
                }
                local k = `k' + 1
                quietly replace het_edad = `k' if missing(het_edad) & !missing(edad_base)
                label define het_edad_lb `k' "`prev'+", add
                label values het_edad het_edad_lb
                label var het_edad "Grupo de edad en $base_year"
            }
            if $het_sexo == 1 {
                gen byte het_sexo = genero if inlist(genero, 1, 2)
                label define het_sexo_lb 1 "hombre" 2 "mujer", replace
                label values het_sexo het_sexo_lb
                label var het_sexo "Sexo"
            }
            if $het_civil == 1 {
                capture confirm string variable estado_civil
                if _rc {
                    tostring estado_civil, replace
                    quietly replace estado_civil = "" if estado_civil == "."
                }
                quietly replace estado_civil = strtrim(estado_civil)
                gen byte het_civil = 0 if estado_civil != ""
                foreach cc of global het_married_codes {
                    quietly replace het_civil = 1 if estado_civil == "`cc'"
                }
                label define het_civil_lb 0 "no casado" 1 "casado", replace
                label values het_civil het_civil_lb
                label var het_civil "Estado civil (codigos $het_married_codes = casado)"
            }
            if `_et' == 1 {
                capture confirm string variable $ced_etnia
                if !_rc encode $ced_etnia, gen(het_etnia)
                else {
                    gen int het_etnia = $ced_etnia
                    local _lb : value label $ced_etnia
                    if "`_lb'" != "" label values het_etnia `_lb'
                }
                label var het_etnia "Etnia"
            }
            capture drop genero fecha_nac estado_civil
            if `_et' == 1 capture drop $ced_etnia
            save "$work/${fstem}_carac.dta", replace
        }
    }

    * ---- SENESCYT: titulo mas alto -----------------------------------------
    if $het_educ == 1 {
        capture confirm file "$sen_file"
        local _ok = !_rc
        if !`_ok' di as error "OJO: no encuentro SENESCYT: $sen_file. Sin educacion."
        if `_ok' {
            capture describe $sen_id using "$sen_file"
            if _rc {
                di as error "OJO: SENESCYT no tiene la variable $sen_id. Si trae la cedula real"
                di as error "     (cedula), hay que enmascararla como cedula_pk antes (ver bloque 01)."
                di as error "     Sin educacion."
                local _ok = 0
            }
        }
        if `_ok' & "$sen_id" != "id_bal" {
            capture confirm file "$ced_file"
            if _rc {
                di as error "OJO: SENESCYT no trae id_bal y no hay registro civil para cruzar $sen_id. Sin educacion."
                local _ok = 0
            }
        }
        if `_ok' {
            * cruce $ced_xwalk_id -> id_bal del registro civil
            if "$sen_id" != "id_bal" {
                use $ced_xwalk_id id_bal using "$ced_file", clear
                capture confirm string variable $ced_xwalk_id
                if _rc tostring $ced_xwalk_id, replace
                quietly replace $ced_xwalk_id = strtrim($ced_xwalk_id)
                drop if missing(id_bal) | $ced_xwalk_id == ""
                duplicates drop $ced_xwalk_id, force
                rename $ced_xwalk_id _xid
                tempfile _xwalk
                save `_xwalk'
            }

            local _sv "$sen_id $sen_level"
            if "$sen_date" != "" local _sv "`_sv' $sen_date"
            use `_sv' using "$sen_file", clear
            quietly count
            di as text "   filas en SENESCYT: " as result r(N)

            * nivel -> rango 0-3
            capture confirm string variable $sen_level
            if _rc {
                capture decode $sen_level, gen(_niv)
                if _rc tostring $sen_level, gen(_niv)
            }
            else gen _niv = $sen_level
            quietly replace _niv = ustrupper(strtrim(_niv))
            foreach p in "Á A" "É E" "Í I" "Ó O" "Ú U" "Ü U" "Ñ N" {
                local _f : word 1 of `p'
                local _t : word 2 of `p'
                quietly replace _niv = usubinstr(_niv, "`_f'", "`_t'", .)
            }
            gen byte _rk = 0
            quietly replace _rk = 2 if strpos(_niv, "TERCER")
            quietly replace _rk = 3 if strpos(_niv, "CUARTO") | strpos(_niv, "POSGRADO") | ///
                strpos(_niv, "MAESTR") | strpos(_niv, "DOCTOR") | strpos(_niv, "ESPECIALI") | strpos(_niv, "PHD")
            quietly replace _rk = 1 if strpos(_niv, "TECNIC") | strpos(_niv, "TECNOLOG")
            di as text "   niveles SENESCYT (0 = no reconocido, 1 tecnico, 2 tercer, 3 cuarto):"
            tabulate _rk
            quietly count if _rk == 0
            if r(N) > 0 {
                di as error "OJO: " r(N) " titulos con nivel no reconocido (cuentan como sin universidad):"
                quietly levelsof _niv if _rk == 0, local(_nr) clean
                di as error `"     `_nr'"'
            }

            * solo los titulos hasta la base: anio de la primera fecha valida
            if "$sen_date" != "" {
                gen int _yt = .
                foreach dv of global sen_date {
                    capture confirm numeric variable `dv'
                    if _rc quietly gen int _y1 = real(substr(strtrim(`dv'), 1, 4))
                    else {
                        local _fm : format `dv'
                        if strpos("`_fm'", "%tc") | strpos("`_fm'", "%tC") quietly gen int _y1 = year(dofc(`dv'))
                        else if strpos("`_fm'", "%td")                     quietly gen int _y1 = year(`dv')
                        else                                               quietly gen int _y1 = `dv'
                    }
                    quietly replace _yt = _y1 if missing(_yt) & inrange(_y1, 1940, 2030)
                    drop _y1
                }
                quietly count if missing(_yt)
                di as text "   titulos sin fecha valida (se conservan): " as result r(N)
                quietly count if _yt > $base_year & !missing(_yt)
                di as text "   titulos posteriores a $base_year (se descartan): " as result r(N)
                quietly drop if _yt > $base_year & !missing(_yt)
            }

            * pasar a id_bal
            if "$sen_id" != "id_bal" {
                capture confirm string variable $sen_id
                if _rc tostring $sen_id, replace
                quietly replace $sen_id = strtrim($sen_id)
                rename $sen_id _xid
                quietly count
                local _nsen = r(N)
                merge m:1 _xid using `_xwalk', keep(1 3) keepusing(id_bal)
                quietly count if _merge == 3
                local _nmat = r(N)
                di as text "   titulos que cruzan con el registro civil: " as result `_nmat' ///
                   as text " de " as result `_nsen' as text " (" %4.1f 100*`_nmat'/max(`_nsen',1) "%)"
                quietly keep if _merge == 3
                drop _merge
            }
            else local _nmat = 1
            if `_nmat' == 0 {
                di as error "OJO: NINGUN titulo de SENESCYT cruza con el registro civil: $sen_id y"
                di as error "     $ced_xwalk_id no tienen el mismo formato. Sin educacion (no se pone a"
                di as error "     todos en 0)."
                use "$work/${fstem}_carac.dta", clear
            }
            else {
                rename id_bal id
                collapse (max) _rk, by(id)
                gen byte het_educ = _rk >= 2
                keep id het_educ
                merge 1:1 id using "$work/${fstem}_carac.dta", keep(2 3) nogenerate
                quietly replace het_educ = 0 if missing(het_educ)
                label define het_educ_lb 0 "sin universidad" 1 "universidad", replace
                label values het_educ het_educ_lb
                label var het_educ "Titulo universitario (tercer o cuarto nivel, SENESCYT)"
                save "$work/${fstem}_carac.dta", replace
            }
        }
    }

    use "$work/${fstem}_carac.dta", clear
    foreach d in edad sexo civil educ etnia {
        capture confirm variable het_`d'
        if !_rc tabulate het_`d', missing
    }
}


* ============================================================================
* 06. DESCRIPTIVOS POR ANIO  (previos a la econometria)
* ============================================================================
* Todo sale de -collapse- sobre los archivos adelgazados del bloque 05.1.
* Filas = muestra x anio ; columnas = variable de ingreso x definicion de t0.

use "$work/${fstem}_slim_desc.dta", clear
collapse (sum) n_filas = n npair_* ///
         (mean) realk_* gw_* lg_* adec_* ddec_* up_* down_* stay_* top_* bot_*, ///
         by(muestra anio)
sort muestra anio
list muestra anio n_filas, noobs

* --- Hoja 1: N por muestra y anio ------------------------------------------
putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("n_obs") replace
putexcel A1 = "Descriptivos por anio -- $shock_lab"
putexcel A2 = "n_filas = filas del dataset de analisis; el resto = N efectivo de cada columna"
putexcel A4 = "muestra" B4 = "anio" C4 = "n_filas"
local c = 3
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'4 = "`v'_`j'"
        forvalues r = 1/`=_N' {
            local rw = 4 + `r'
            putexcel `cl'`rw' = (npair_`j'_`v'[`r'])
        }
    }
}
forvalues r = 1/`=_N' {
    local rw = 4 + `r'
    local ms : label (muestra) `=muestra[`r']'
    putexcel A`rw' = "`ms'" B`rw' = (anio[`r']) C`rw' = (n_filas[`r'])
}

* --- Hoja 2: ingreso real medio, una columna por variable x definicion -----
putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("ingreso_real") modify
putexcel A1 = "Ingreso real medio por muestra y anio (solo origen D$keep_dec_lo-D$keep_dec_hi)"
putexcel A3 = "muestra" B3 = "anio"
local c = 2
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'3 = "`v'_`j'"
        forvalues r = 1/`=_N' {
            local rw = 3 + `r'
            putexcel `cl'`rw' = (realk_`j'_`v'[`r'])
        }
    }
}
forvalues r = 1/`=_N' {
    local rw = 3 + `r'
    local ms : label (muestra) `=muestra[`r']'
    putexcel A`rw' = "`ms'" B`rw' = (anio[`r'])
}

* --- Hojas 3-5: una columna por par variable x definicion de t0 ------------

foreach blk in g_medio lg_medio mov_resumen extremos {

    putexcel set "$out/tablas/D_resumen_por_anio_${shock}.xlsx", sheet("`blk'") modify

    if "`blk'" == "g_medio"     putexcel A1 = "Crecimiento real medio desde la base ($base_lab)"
    if "`blk'" == "lg_medio"    putexcel A1 = "Log-crecimiento medio desde la base ($base_lab)"
    if "`blk'" == "mov_resumen" putexcel A1 = "Movilidad relativa: |cambio de decil| medio"
    if "`blk'" == "extremos"    putexcel A1 = "P(permanecer en el decil de origen)"
    putexcel A2 = "columnas: variable de ingreso x definicion de t0 (orden a = $t0_year, b = $t0_win_first-$t0_win_last)"
    putexcel A3 = "muestra restringida a los deciles de origen $keep_dec_lo-$keep_dec_hi"
    putexcel A4 = "muestra" B4 = "anio"

    forvalues r = 1/`=_N' {
        local rw = 4 + `r'
        local ms : label (muestra) `=muestra[`r']'
        putexcel A`rw' = "`ms'" B`rw' = (anio[`r'])
    }

    local c = 2
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            if "`blk'" == "extremos" putexcel `cl'4 = "`v'_`j'_top"
            else                     putexcel `cl'4 = "`v'_`j'"
            forvalues r = 1/`=_N' {
                local rw = 4 + `r'
                if "`blk'" == "g_medio"     putexcel `cl'`rw' = (gw_`j'_`v'[`r'])
                if "`blk'" == "lg_medio"    putexcel `cl'`rw' = (lg_`j'_`v'[`r'])
                if "`blk'" == "mov_resumen" putexcel `cl'`rw' = (adec_`j'_`v'[`r'])
                if "`blk'" == "extremos"    putexcel `cl'`rw' = (top_`j'_`v'[`r'])
            }
        }
    }

    * columnas extra del bloque "extremos": permanencia en el decil de abajo
    if "`blk'" == "extremos" {
        foreach v of global inc_vars {
            foreach j in a b {
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                putexcel `cl'4 = "`v'_`j'_bot"
                forvalues r = 1/`=_N' {
                    local rw = 4 + `r'
                    putexcel `cl'`rw' = (bot_`j'_`v'[`r'])
                }
            }
        }
    }
}

di as result "Excel escrito: $out/tablas/D_resumen_por_anio_${shock}.xlsx"


* ---- 06.1 Crecimiento medio por muestra x anio x decil de origen ---------
* Es el insumo directo del analisis (1). Solo hay filas para los deciles de
* origen conservados ($keep_dec_lo-$keep_dec_hi).

putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("g_medio") replace
putexcel A1 = "Crecimiento real medio por muestra, anio y decil de origen -- $shock_lab"
putexcel A4 = "muestra" B4 = "anio" C4 = "decil_t0"

putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("lg_medio") modify
putexcel A1 = "Log-crecimiento medio por muestra, anio y decil de origen -- $shock_lab"
putexcel A4 = "muestra" B4 = "anio" C4 = "decil_t0"

putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("n_obs") modify
putexcel A1 = "N por muestra, anio y decil de origen -- $shock_lab"
putexcel A4 = "muestra" B4 = "anio" C4 = "decil_t0"

* Esqueleto de filas: muestra x anio x decil, en orden fijo.
* Se escribe hoja por hoja: cada -putexcel set- reabre el archivo, asi que
* alternar de hoja dentro del loop lo hace inutilmente lento.
foreach hoja in g_medio lg_medio n_obs {
    putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("`hoja'") modify
    local rw = 4
    foreach s of global samples {
        foreach y of global out_years {
            forvalues d = $keep_dec_lo/$keep_dec_hi {
                local rw = `rw' + 1
                putexcel A`rw' = "`s'" B`rw' = `y' C`rw' = `d'
            }
        }
    }
}

local OY "$out_years"
local c = 3
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        local cl : word `c' of $XLCOL

        use "$work/${fstem}_slim_gdec.dta", clear
        keep if !missing(decil0_`j'_`v')
        gen byte n = 1
        collapse (sum) n_obs = n (mean) g = gw_`j'_`v' lg = lg_`j'_`v', ///
                 by(muestra anio decil0_`j'_`v')
        rename decil0_`j'_`v' decil_t0

        foreach hoja in g_medio lg_medio n_obs {
            putexcel set "$out/tablas/D_g_por_decil_${shock}.xlsx", sheet("`hoja'") modify
            putexcel `cl'4 = "`v'_`j'"
            forvalues r = 1/`=_N' {
                local _yy = anio[`r']
                local yi : list posof `"`_yy'"' in OY
                local si = muestra[`r']
                local dd = decil_t0[`r']
                if `yi' > 0 & inrange(`dd', $keep_dec_lo, $keep_dec_hi) {
                    local rw = 4 + (`si'-1)*$n_out_years*$n_dec + ///
                                   (`yi'-1)*$n_dec + (`dd' - $keep_dec_lo + 1)
                    if "`hoja'" == "g_medio"  putexcel `cl'`rw' = (g[`r'])
                    if "`hoja'" == "lg_medio" putexcel `cl'`rw' = (lg[`r'])
                    if "`hoja'" == "n_obs"    putexcel `cl'`rw' = (n_obs[`r'])
                }
            }
        }
        di as text "  g por decil: `v'_`j' listo"
    }
}
di as result "Excel escrito: $out/tablas/D_g_por_decil_${shock}.xlsx"


* ---- 06.2 Matrices de transicion decil de origen -> decil del anio -------
* Las FILAS son los deciles de origen conservados ($keep_dec_lo-$keep_dec_hi);
* las COLUMNAS son los 10 deciles contemporaneos, porque el decil del anio se
* mide contra la poblacion completa.

if $do_transmat == 1 {
    use "$work/${fstem}_slim_trans.dta", clear
    capture log close movlog
    log using "$out/descriptivos/transiciones_${shock}.log", text replace name(movlog)
    di as result _n "== MATRICES DE TRANSICION (fila = decil de origen, % por fila) =="
    di as result    "   $shock_lab"
    local si = 0
    foreach s of global samples {
        local si = `si' + 1
        foreach v of global inc_vars {
            foreach j in a b {
                di as result _n "##### muestra `s' | `v' | definicion de t0: (`j') #####"
                foreach y of global out_years {
                    di as result _n "  anio = `y'"
                    tabulate decil0_`j'_`v' decil_`v' if anio == `y' & muestra == `si', ///
                        row nofreq
                }
            }
        }
    }
    capture log close movlog
}


* ============================================================================
* 07. ANALISIS (1): CRECIMIENTO -- BRECHA D$hi_decile vs D$lo_decile
* ============================================================================
* Especificacion dif-en-dif, para cada muestra, variable de ingreso y def. t0:
*   y_it = a + SUM_t b_t 1[anio=t] + c 1[origen=D$hi_decile]
*            + SUM_t d_t 1[anio=t] 1[origen=D$hi_decile] + e_it
* con anio base $pre_year y decil base D$lo_decile. Entonces
*   d_t = [y(D$hi_decile,t) - y(D$lo_decile,t)]
*       - [y(D$hi_decile,$pre_year) - y(D$lo_decile,$pre_year)]
* y = resultado principal ($main_growth): lg (log-crecimiento) en v2. Con lg,
* d_t compara  ln y_t - ln y_pre  entre D$hi_decile y D$lo_decile (la base se
* cancela). La otra medida del crecimiento va como robustez en 7.4 y sale en
* la hoja did_robustez.
* EE agrupados por persona. Las regresiones se corren UNA sola vez: los
* resultados se acumulan en matrices y se vuelcan a Excel al final del bloque.

use "$work/${fstem}_analysis.dta", clear

matrix A1_dd = J($n_rows_p, $n_pairs, .)    // coeficiente dif-en-dif
matrix A1_se = J($n_rows_p, $n_pairs, .)    // error estandar
matrix A1_p  = J($n_rows_p, $n_pairs, .)    // p-valor
matrix A1_gp = J($n_rows_y, $n_pairs, .)    // nivel de la brecha por anio
matrix A1R_dd = J($n_rows_p, $n_pairs, .)   // robustez (7.4): coeficiente
matrix A1R_se = J($n_rows_p, $n_pairs, .)
matrix A1R_p  = J($n_rows_p, $n_pairs, .)

if "$main_growth" == "lg" {
    local ymain "lg"
    local yrob  "gw"
    global main_lab "log-crecimiento  ln(y_t) - ln(y_base)"
    global rob_lab  "crecimiento  y_t/y_base - 1  (winsorizado p$wins_p)"
}
else {
    local ymain "gw"
    local yrob  "lg"
    global main_lab "crecimiento  y_t/y_base - 1  (winsorizado p$wins_p)"
    global rob_lab  "log-crecimiento  ln(y_t) - ln(y_base)"
}

capture log close movlog
log using "$out/regresiones/A1_crecimiento_${shock}.log", text replace name(movlog)

di as result _n "===================================================================="
di as result    " (1) CRECIMIENTO: D$hi_decile vs D$lo_decile -- $shock_lab"
di as result    " dependiente principal: $main_lab"
di as result    " robustez (7.4)       : $rob_lab"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            * ---- 7.1 Solo los dos deciles de interes (dif-en-dif limpio) --
            di as result _n "-- [A1] anio x decil, solo D$lo_decile y D$hi_decile --"
            capture noisily reg `ymain'_`j'_`v'                               ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'             ///
                if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                vce(cluster id)

            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_post + `rr'
                    capture lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc {
                        matrix A1_dd[`row', `c'] = r(estimate)
                        matrix A1_se[`row', `c'] = r(se)
                        matrix A1_p[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                    }
                }
                local rr = 0
                foreach y of global out_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_out_years + `rr'
                    if `y' == $pre_year capture lincom ${hi_decile}.decil0_`j'_`v'
                    else capture lincom ${hi_decile}.decil0_`j'_`v' + `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc matrix A1_gp[`row', `c'] = r(estimate)
                }

                * ---- 7.2 Version 2x2 (post agrupado) ---------------------
                * Con un solo anio post (modo de dos anios) es literalmente la
                * misma regresion que 7.1, asi que no se repite.
                if $n_post > 1 {
                    di as result _n "-- [A1] 2x2: post x D$hi_decile --"
                    capture noisily reg `ymain'_`j'_`v' i.post##i.hi_`j'_`v'  ///
                        if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                        vce(cluster id)
                }
                else di as text _n "-- [A1] 2x2 omitido: con un solo anio post coincide con 7.1 --"

                * ---- 7.3 Todos los deciles de origen de la muestra --------
                di as result _n "-- [A1] Deciles de origen $keep_dec_lo-$keep_dec_hi, base D$lo_decile --"
                capture noisily reg `ymain'_`j'_`v'                           ///
                    ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'         ///
                    if muestra == `si', vce(cluster id)

                * ---- 7.4 Robustez: la otra medida del crecimiento --------
                di as result _n "-- [A1] Robustez: $rob_lab --"
                capture noisily reg `yrob'_`j'_`v'                            ///
                    ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'         ///
                    if muestra == `si' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile), ///
                    vce(cluster id)
                if !_rc {
                    local rr = 0
                    foreach y of global post_years {
                        local rr = `rr' + 1
                        local row = (`si' - 1) * $n_post + `rr'
                        capture lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                        if !_rc {
                            matrix A1R_dd[`row', `c'] = r(estimate)
                            matrix A1R_se[`row', `c'] = r(se)
                            matrix A1R_p[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                        }
                    }
                }
            }
            else di as error "  regresion no estimable para `v'_`j' en la muestra `s'"
        }
    }
}

capture log close movlog

* ---- 07.5 Excel: resultados lado a lado -----------------------------------

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("did_coef") replace
putexcel A1 = "(1) Cambio de la brecha de crecimiento D$hi_decile - D$lo_decile respecto de $pre_year -- $main_lab"
putexcel A2 = "Shock" B2 = "$shock" C2 = "origen D$keep_dec_lo-D$keep_dec_hi"
putexcel A3 = "columnas: variable de ingreso x definicion de t0 (a = $t0_year, b = $t0_win_first-$t0_win_last)"
putexcel A5 = "muestra" B5 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'5 = "`pl'"
}
local rw = 5
foreach s of global samples {
    foreach y of global post_years {
        local rw = `rw' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
    }
}
putexcel C6 = matrix(A1_dd)

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("did_detalle") modify
putexcel A1 = "(1) dif-en-dif: coeficiente, error estandar y p-valor -- $main_lab"
putexcel A4 = "muestra" B4 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    forvalues st = 1/3 {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        if `st' == 1 putexcel `cl'3 = "`pl'"
        if `st' == 1 putexcel `cl'4 = "coef"
        if `st' == 2 putexcel `cl'4 = "EE"
        if `st' == 3 putexcel `cl'4 = "p"
    }
}
local rw = 4
local row = 0
foreach s of global samples {
    foreach y of global post_years {
        local rw  = `rw' + 1
        local row = `row' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
        local c = 2
        forvalues k = 1/$n_pairs {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_dd[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_se[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1_p[`row', `k'])
        }
    }
}

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("brecha_nivel") modify
putexcel A1 = "(1) Nivel de la brecha D$hi_decile - D$lo_decile en cada anio"
putexcel A3 = "muestra" B3 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    local c = `c' + 1
    local cl : word `c' of $XLCOL
    putexcel `cl'3 = "`pl'"
}
local rw = 3
foreach s of global samples {
    foreach y of global out_years {
        local rw = `rw' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
    }
}
putexcel C4 = matrix(A1_gp)

putexcel set "$out/tablas/A1_crecimiento_${shock}.xlsx", sheet("did_robustez") modify
putexcel A1 = "(1) Robustez: dif-en-dif con $rob_lab (coef, EE, p)"
putexcel A4 = "muestra" B4 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    forvalues st = 1/3 {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        if `st' == 1 putexcel `cl'3 = "`pl'"
        if `st' == 1 putexcel `cl'4 = "coef"
        if `st' == 2 putexcel `cl'4 = "EE"
        if `st' == 3 putexcel `cl'4 = "p"
    }
}
local rw = 4
local row = 0
foreach s of global samples {
    foreach y of global post_years {
        local rw  = `rw' + 1
        local row = `row' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
        local c = 2
        forvalues k = 1/$n_pairs {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1R_dd[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1R_se[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A1R_p[`row', `k'])
        }
    }
}


* ---- 07.6 D$hi_decile contra cada decil de $lo_list -------------------------
* El mismo dif-en-dif de 7.1 (resultado principal) contra cada decil de
* comparacion. La fila de D$lo_decile repite 7.1 (control). Hoja
* did_vs_deciles; log A1b_did_vs_deciles.

if "$main_growth" == "lg" local ymain "lg"
else                      local ymain "gw"

use "$work/${fstem}_analysis.dta", clear
tempname PD
postfile `PD' str16 pair byte muestra int contraste int anio byte stat double value ///
    using "$work/${fstem}_did_vs.dta", replace

capture log close movlog
log using "$out/regresiones/A1b_did_vs_deciles_${shock}.log", text replace name(movlog)
di as result _n "== (1b) D$hi_decile contra cada decil de $lo_list -- $main_lab =="

local si = 0
foreach s of global samples {
    local si = `si' + 1
    foreach v of global inc_vars {
        foreach j in a b {
            local pl "`v'_`j'"
            foreach c of global lo_list {
                capture quietly reg `ymain'_`j'_`v'                           ///
                    ib${pre_year}.anio##ib`c'.decil0_`j'_`v'                   ///
                    if muestra == `si' & inlist(decil0_`j'_`v', `c', $hi_decile), ///
                    vce(cluster id)
                if _rc continue
                local nobs = e(N)
                local line ""
                foreach y of global post_years {
                    capture quietly lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if _rc continue
                    post `PD' ("`pl'") (`si') (`c') (`y') (1) (r(estimate))
                    post `PD' ("`pl'") (`si') (`c') (`y') (2) (r(se))
                    post `PD' ("`pl'") (`si') (`c') (`y') (3) (2*ttail(r(df), abs(r(estimate)/r(se))))
                    post `PD' ("`pl'") (`si') (`c') (`y') (4) (`nobs')
                    local _b : display %7.4f r(estimate)
                    local _e : display %6.4f r(se)
                    local line "`line'  `y': `_b' (`_e')"
                }
                di as text "  `s' | `pl' | D$hi_decile vs D`c':`line'"
            }
        }
    }
}
postclose `PD'
capture log close movlog

use "$work/${fstem}_did_vs.dta", clear
label define dv_stat 1 "coef" 2 "EE" 3 "p" 4 "N obs", replace
label values stat dv_stat
label define muestra_lb 1 "unbal" 2 "bal", replace
label values muestra muestra_lb
quietly reshape wide value, i(muestra contraste anio stat) j(pair) string
rename value* *
gen str12 comparacion = "D$hi_decile vs D" + string(contraste)
capture order muestra comparacion contraste anio stat $PAIRLAB
sort muestra contraste anio stat
drop contraste
export excel using "$out/tablas/A1_crecimiento_${shock}.xlsx", ///
    sheet("did_vs_deciles", replace) firstrow(variables)

di as result "Excel escrito: $out/tablas/A1_crecimiento_${shock}.xlsx"


* ============================================================================
* 08. ANALISIS (2): MOVILIDAD RELATIVA BASADA EN CAMBIOS DE DECIL
* ============================================================================
* Por muestra y anio, siempre respecto del decil de ORIGEN fijado en t0:
*   - E|delta decil|, %sube, %baja, %se queda
*   - persistencia rango-rango: decil_t = a + b*decil_t0 (b alto = poca
*     movilidad relativa)
*   - indice de Shorrocks   M = (K - traza(P)) / (K - 1)
*   - indice de Bartholomew B = (1/K) SUM_i SUM_k p_ik |i - k|
*     (en ambos: mas alto = mas movilidad)
* Los indices se calculan con -contract- (rapido), no con -tabulate-.
*
* OJO CON K. La matriz de transicion ya NO es cuadrada: tiene $n_dec filas
* (deciles de origen conservados) y hasta 10 columnas (deciles del anio,
* medidos contra la poblacion completa). K es el numero de FILAS, es decir de
* deciles de origen efectivamente presentes, no el maximo decil observado.
* Con K = max(decil) las formulas quedarian mal escaladas.
*
* NOTA: con deciles de origen de igual tamano, Bartholomew y E|delta decil|
* coinciden casi exactamente por construccion; no es un error.

matrix A2_sh = J($n_rows_y, $n_pairs, .)   // Shorrocks
matrix A2_bt = J($n_rows_y, $n_pairs, .)   // Bartholomew
matrix A2_ad = J($n_rows_y, $n_pairs, .)   // |delta decil| medio
matrix A2_st = J($n_rows_y, $n_pairs, .)   // % se queda
matrix A2_up = J($n_rows_y, $n_pairs, .)   // % sube
matrix A2_dn = J($n_rows_y, $n_pairs, .)   // % baja
matrix A2_rr = J($n_rows_y, $n_pairs, .)   // pendiente rango-rango

* ---- 08.1 Descriptivos de movilidad por muestra y anio (collapse) --------

use "$work/${fstem}_slim_desc.dta", clear
collapse (mean) adec_* up_* down_* stay_*, by(muestra anio)
sort muestra anio

local OY "$out_years"
local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        forvalues r = 1/`=_N' {
            local _yy = anio[`r']
            local yi : list posof `"`_yy'"' in OY
            local si = muestra[`r']
            if `yi' > 0 {
                local row = (`si' - 1) * $n_out_years + `yi'
                local _v1 = adec_`j'_`v'[`r']
                local _v2 = stay_`j'_`v'[`r']
                local _v3 = up_`j'_`v'[`r']
                local _v4 = down_`j'_`v'[`r']
                matrix A2_ad[`row', `c'] = `_v1'
                matrix A2_st[`row', `c'] = `_v2'
                matrix A2_up[`row', `c'] = `_v3'
                matrix A2_dn[`row', `c'] = `_v4'
            }
        }
    }
}

* ---- 08.2 Shorrocks y Bartholomew (via contract) -------------------------

local si = 0
foreach s of global samples {
    local si = `si' + 1
    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1
            local yi = 0
            foreach y of global out_years {
                local yi = `yi' + 1
                local row = (`si' - 1) * $n_out_years + `yi'

                use "$work/${fstem}_slim_trans.dta", clear
                keep if muestra == `si' & anio == `y' &            ///
                        !missing(decil0_`j'_`v') & !missing(decil_`v')
                quietly count
                if r(N) > 0 {
                    contract decil0_`j'_`v' decil_`v', freq(nn)
                    rename decil0_`j'_`v' d0
                    rename decil_`v'       d1
                    bysort d0: egen double rowN = total(nn)
                    gen double p     = nn / rowN
                    gen double pdiag = p * (d0 == d1)
                    gen double pbart = p * abs(d0 - d1)
                    * K = numero de FILAS (deciles de origen presentes)
                    quietly levelsof d0, local(_d0lev)
                    local K : word count `_d0lev'
                    collapse (sum) sumdiag = pdiag sumbart = pbart
                    local tr = sumdiag[1]
                    local bt = sumbart[1]
                    if `K' > 1 {
                        matrix A2_sh[`row', `c'] = (`K' - `tr') / (`K' - 1)
                        matrix A2_bt[`row', `c'] = `bt' / `K'
                    }
                }
            }
            di as text "  indices de movilidad: `s' | `v'_`j' listo"
        }
    }
}

* ---- 08.3 Regresiones de movilidad + pendiente rango-rango ---------------

use "$work/${fstem}_analysis.dta", clear

matrix A2_rdd = J($n_rows_p, $n_pairs, .)   // coef. del anio sobre |delta decil|
matrix A2_rse = J($n_rows_p, $n_pairs, .)
matrix A2_rp  = J($n_rows_p, $n_pairs, .)

capture log close movlog
log using "$out/regresiones/A2_movilidad_relativa_${shock}.log", text replace name(movlog)

di as result _n "===================================================================="
di as result    " (2) MOVILIDAD RELATIVA (cambios de decil) -- $shock_lab"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            di as result _n "-- [A2] Magnitud: |delta decil| por anio (base $pre_year) --"
            capture noisily reg adec_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)
            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    local row = (`si' - 1) * $n_post + `rr'
                    capture lincom `y'.anio
                    if !_rc {
                        matrix A2_rdd[`row', `c'] = r(estimate)
                        matrix A2_rse[`row', `c'] = r(se)
                        matrix A2_rp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                    }
                }
            }

            di as result _n "-- [A2] Direccion: probabilidad de subir de decil --"
            capture noisily reg up_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Direccion: probabilidad de bajar de decil --"
            capture noisily reg down_`j'_`v' ib${pre_year}.anio ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Movimiento neto por decil de origen --"
            capture noisily reg ddec_`j'_`v'                          ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'     ///
                if muestra == `si', vce(cluster id)

            di as result _n "-- [A2] Persistencia rango-rango en deciles, por anio --"
            di as text     "   pendiente mas alta = mas persistencia = MENOS movilidad"
            capture noisily reg decil_`v' ib${pre_year}.anio##c.decil0_`j'_`v' ///
                if muestra == `si', vce(cluster id)
            if !_rc {
                local yi = 0
                foreach y of global out_years {
                    local yi = `yi' + 1
                    local row = (`si' - 1) * $n_out_years + `yi'
                    if `y' == $pre_year capture lincom c.decil0_`j'_`v'
                    else capture lincom c.decil0_`j'_`v' + `y'.anio#c.decil0_`j'_`v'
                    if !_rc matrix A2_rr[`row', `c'] = r(estimate)
                }
            }

            di as result _n "-- [A2] Persistencia rango-rango en percentiles --"
            capture noisily reg pctl_`v' ib${pre_year}.anio##c.pctl0_`j'_`v' ///
                if muestra == `si', vce(cluster id)
        }
    }
}

capture log close movlog

* ---- 08.4 Excel: una hoja por indicador ---------------------------------

putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("shorrocks") replace
putexcel A1 = "(2) Indice de Shorrocks (mas alto = mas movilidad)"

foreach hoja in shorrocks bartholomew abs_delta pct_stay pct_up pct_down rank_rank {

    if "`hoja'" != "shorrocks" {
        putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("`hoja'") modify
    }
    if "`hoja'" == "bartholomew" putexcel A1 = "(2) Indice de Bartholomew (mas alto = mas movilidad)"
    if "`hoja'" == "abs_delta"   putexcel A1 = "(2) |Cambio de decil| medio"
    if "`hoja'" == "pct_stay"    putexcel A1 = "(2) Proporcion que se mantiene en su decil de origen"
    if "`hoja'" == "pct_up"      putexcel A1 = "(2) Proporcion que sube de decil"
    if "`hoja'" == "pct_down"    putexcel A1 = "(2) Proporcion que baja de decil"
    if "`hoja'" == "rank_rank"   putexcel A1 = "(2) Pendiente rango-rango (mas alta = MENOS movilidad)"

    putexcel A2 = "Shock" B2 = "$shock" C2 = "origen D$keep_dec_lo-D$keep_dec_hi"
    putexcel A3 = "columnas: variable de ingreso x definicion de t0"
    putexcel A5 = "muestra" B5 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'5 = "`pl'"
    }
    local rw = 5
    foreach s of global samples {
        foreach y of global out_years {
            local rw = `rw' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
        }
    }
    if "`hoja'" == "shorrocks"   putexcel C6 = matrix(A2_sh)
    if "`hoja'" == "bartholomew" putexcel C6 = matrix(A2_bt)
    if "`hoja'" == "abs_delta"   putexcel C6 = matrix(A2_ad)
    if "`hoja'" == "pct_stay"    putexcel C6 = matrix(A2_st)
    if "`hoja'" == "pct_up"      putexcel C6 = matrix(A2_up)
    if "`hoja'" == "pct_down"    putexcel C6 = matrix(A2_dn)
    if "`hoja'" == "rank_rank"   putexcel C6 = matrix(A2_rr)
}

putexcel set "$out/tablas/A2_movilidad_${shock}.xlsx", sheet("reg_abs_delta") modify
putexcel A1 = "(2) Efecto del anio sobre |cambio de decil| (base $pre_year): coef, EE, p"
putexcel A4 = "muestra" B4 = "anio"
local c = 2
foreach pl of global PAIRLAB {
    forvalues st = 1/3 {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        if `st' == 1 putexcel `cl'3 = "`pl'"
        if `st' == 1 putexcel `cl'4 = "coef"
        if `st' == 2 putexcel `cl'4 = "EE"
        if `st' == 3 putexcel `cl'4 = "p"
    }
}
local rw = 4
local row = 0
foreach s of global samples {
    foreach y of global post_years {
        local rw  = `rw' + 1
        local row = `row' + 1
        putexcel A`rw' = "`s'" B`rw' = `y'
        local c = 2
        forvalues k = 1/$n_pairs {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rdd[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rse[`row', `k'])
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            putexcel `cl'`rw' = (A2_rp[`row', `k'])
        }
    }
}
di as result "Excel escrito: $out/tablas/A2_movilidad_${shock}.xlsx"


* ============================================================================
* 09. ANALISIS (3): PROBABILIDAD DE PERMANECER EN LOS EXTREMOS
* ============================================================================
*   top_ = 1[decil_t = D$top_decile]  entre quienes empezaron en D$top_decile
*   bot_ = 1[decil_t = D$bot_decile]  entre quienes empezaron en D$bot_decile
* Con la restriccion a D$keep_dec_lo-D$keep_dec_hi el "fondo" es D$bot_decile:
* es el decil mas bajo que queda en la muestra, y ademas es el grupo de
* control del analisis (1), asi que las dos lecturas quedan alineadas.
* MPL (lectura en puntos porcentuales) y logit con -margins-, anio base
* $pre_year: cada coeficiente es el cambio de la probabilidad de permanecer
* respecto del anio pre-shock.

matrix A3_pt = J($n_rows_y, $n_pairs, .)   // P(seguir en la cima)
matrix A3_pb = J($n_rows_y, $n_pairs, .)   // P(seguir en el fondo de la muestra)

use "$work/${fstem}_slim_desc.dta", clear
collapse (mean) top_* bot_*, by(muestra anio)
sort muestra anio
local OY "$out_years"
local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1
        forvalues r = 1/`=_N' {
            local _yy = anio[`r']
            local yi : list posof `"`_yy'"' in OY
            local si = muestra[`r']
            if `yi' > 0 {
                local row = (`si' - 1) * $n_out_years + `yi'
                local _v1 = top_`j'_`v'[`r']
                local _v2 = bot_`j'_`v'[`r']
                matrix A3_pt[`row', `c'] = `_v1'
                matrix A3_pb[`row', `c'] = `_v2'
            }
        }
    }
}

* ---- 09.1 Regresiones ------------------------------------------------------

use "$work/${fstem}_analysis.dta", clear

matrix A3_tdd = J($n_rows_p, $n_pairs, .)
matrix A3_tse = J($n_rows_p, $n_pairs, .)
matrix A3_tp  = J($n_rows_p, $n_pairs, .)
matrix A3_bdd = J($n_rows_p, $n_pairs, .)
matrix A3_bse = J($n_rows_p, $n_pairs, .)
matrix A3_bp  = J($n_rows_p, $n_pairs, .)

capture log close movlog
log using "$out/regresiones/A3_permanencia_extremos_${shock}.log", text replace name(movlog)

di as result _n "===================================================================="
di as result    " (3) PERMANENCIA EN LOS EXTREMOS -- $shock_lab"
di as result    "===================================================================="

local si = 0
foreach s of global samples {
    local si = `si' + 1

    di as result _n "%%%%%%%%%%%%%% MUESTRA: `s' %%%%%%%%%%%%%%"

    local c = 0
    foreach v of global inc_vars {
        foreach j in a b {
            local c = `c' + 1

            di as result _n "############ `v'  --  definicion de t0: (`j') ############"

            foreach ext in top bot {

                if "`ext'" == "top" local decl = $top_decile
                if "`ext'" == "bot" local decl = $bot_decile

                di as result _n "-- [A3] P(seguir en D`decl' | origen D`decl') -- MPL base $pre_year"
                capture noisily reg `ext'_`j'_`v' ib${pre_year}.anio ///
                    if muestra == `si', vce(cluster id)
                if !_rc {
                    local rr = 0
                    foreach y of global post_years {
                        local rr = `rr' + 1
                        local row = (`si' - 1) * $n_post + `rr'
                        capture lincom `y'.anio
                        if !_rc {
                            if "`ext'" == "top" {
                                matrix A3_tdd[`row', `c'] = r(estimate)
                                matrix A3_tse[`row', `c'] = r(se)
                                matrix A3_tp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                            }
                            else {
                                matrix A3_bdd[`row', `c'] = r(estimate)
                                matrix A3_bse[`row', `c'] = r(se)
                                matrix A3_bp[`row', `c']  = 2*ttail(r(df), abs(r(estimate)/r(se)))
                            }
                        }
                    }
                }

                di as result _n "   Logit + efectos marginales promedio:"
                capture noisily logit `ext'_`j'_`v' ib${pre_year}.anio ///
                    if muestra == `si', vce(cluster id)
                if !_rc capture noisily margins, dydx(anio)
            }
        }
    }
}

capture log close movlog

* ---- 09.2 Excel ------------------------------------------------------------

foreach hoja in p_stay_top p_stay_bot {
    if "`hoja'" == "p_stay_top" {
        putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") replace
        putexcel A1 = "(3) P(seguir en el decil $top_decile | origen D$top_decile)"
    }
    else {
        putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") modify
        putexcel A1 = "(3) P(seguir en el decil $bot_decile | origen D$bot_decile)"
    }
    putexcel A2 = "Shock" B2 = "$shock" C2 = "origen D$keep_dec_lo-D$keep_dec_hi"
    putexcel A3 = "columnas: variable de ingreso x definicion de t0"
    putexcel A5 = "muestra" B5 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        local c = `c' + 1
        local cl : word `c' of $XLCOL
        putexcel `cl'5 = "`pl'"
    }
    local rw = 5
    foreach s of global samples {
        foreach y of global out_years {
            local rw = `rw' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
        }
    }
    if "`hoja'" == "p_stay_top" putexcel C6 = matrix(A3_pt)
    if "`hoja'" == "p_stay_bot" putexcel C6 = matrix(A3_pb)
}

foreach hoja in reg_top reg_bot {
    putexcel set "$out/tablas/A3_permanencia_${shock}.xlsx", sheet("`hoja'") modify
    if "`hoja'" == "reg_top" putexcel A1 = "(3) Cambio de P(seguir en D$top_decile) vs $pre_year: coef, EE, p"
    if "`hoja'" == "reg_bot" putexcel A1 = "(3) Cambio de P(seguir en D$bot_decile) vs $pre_year: coef, EE, p"
    putexcel A4 = "muestra" B4 = "anio"
    local c = 2
    foreach pl of global PAIRLAB {
        forvalues st = 1/3 {
            local c = `c' + 1
            local cl : word `c' of $XLCOL
            if `st' == 1 putexcel `cl'3 = "`pl'"
            if `st' == 1 putexcel `cl'4 = "coef"
            if `st' == 2 putexcel `cl'4 = "EE"
            if `st' == 3 putexcel `cl'4 = "p"
        }
    }
    local rw = 4
    local row = 0
    foreach s of global samples {
        foreach y of global post_years {
            local rw  = `rw' + 1
            local row = `row' + 1
            putexcel A`rw' = "`s'" B`rw' = `y'
            local c = 2
            forvalues k = 1/$n_pairs {
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tdd[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bdd[`row', `k'])
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tse[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bse[`row', `k'])
                local c = `c' + 1
                local cl : word `c' of $XLCOL
                if "`hoja'" == "reg_top" putexcel `cl'`rw' = (A3_tp[`row', `k'])
                if "`hoja'" == "reg_bot" putexcel `cl'`rw' = (A3_bp[`row', `k'])
            }
        }
    }
}
di as result "Excel escrito: $out/tablas/A3_permanencia_${shock}.xlsx"



* ============================================================================
* 10. ANALISIS (4): COTAS DE LEE (2009) + IC DE IMBENS-MANSKI (2004)
* ============================================================================
* Solo tiene sentido en la muestra NO balanceada: en la balanceada, por
* construccion, no hay atricion.
*
* PROBLEMA. La probabilidad de seguir declarando cae con el shock y cae MAS
* abajo en la distribucion. Los que quedan en los anios post no son los
* mismos que en $pre_year, asi que la comparacion mezcla el efecto real con
* un cambio de composicion.
*
* SOLUCION (Lee 2009). Dentro de cada decil de ORIGEN se toma la tasa de
* retencion MINIMA entre los anios y se recorta el excedente de los demas
* anios por un extremo de la distribucion del OUTCOME.
*
* EL RECORTE ES DIRECCIONAL. Si el parametro de interes es una MEDIA suelta,
* recortar la cola alta da la cota inferior y la cola baja la superior. Pero
* aca los parametros son DIFERENCIAS de medias de celda:
*     theta_t = mu(t) - mu(pre)                       (efecto del anio)
*     theta_t = [mu(hi,t) - mu(lo,t)]
*             - [mu(hi,pre) - mu(lo,pre)]             (dif-en-dif)
* Para la cota INFERIOR de theta hay que llevar a su MINIMO las celdas que
* entran con signo (+) -recortando su cola alta- y a su MAXIMO las que entran
* con signo (-) -recortando su cola baja-. Recortar todo por el mismo lado,
* como si fuera una media, NO produce una cota valida de una diferencia.
* Por eso cada celda (decil de origen x anio) lleva un signo y el recorte se
* hace en la direccion que corresponde a ese signo.
*
* Los modelos estan SATURADOS en anio (y en anio x decil en el dif-en-dif),
* asi que cada coeficiente es exactamente una combinacion de medias de celda:
* como el patron de signos es el mismo para todos los anios post, UNA sola
* regresion por cota devuelve las cotas de todos los anios post a la vez.
*
* -----------------------------------------------------------------------------
* INFERENCIA: INTERVALO DE CONFIANZA DE IMBENS-MANSKI (2004)
*
* Las cotas [theta_L, theta_U] identifican a theta solo parcialmente. Poner
* un IC de 95% alrededor de CADA cota por separado y pegar los extremos NO da
* un IC de 95% para theta: sobre-cubre. El IC correcto (Imbens y Manski 2004,
* con la correccion de Stoye 2009) es
*
*     [ theta_L - c * se_L ,  theta_U + c * se_U ]
*
* donde c resuelve
*
*     Phi( c + (theta_U - theta_L) / max(se_L, se_U) ) - Phi(-c) = 1 - alpha
*
* Intuicion del factor c: no hay que pagar por cubrir las DOS cotas a la vez,
* porque theta esta en un solo lugar. Cuanto mas ancho el conjunto
* identificado, menos se solapan los dos problemas y menos hay que pagar:
*     conjunto de ancho 0  ->  c = z(1-alpha/2) = 1.960   (IC de dos colas)
*     conjunto muy ancho   ->  c = z(1-alpha)   = 1.645   (IC de una cola)
* Con alpha = 0.05 el c de cada celda SIEMPRE cae entre 1.645 y 1.960, lo que
* sirve como chequeo. c se resuelve por biseccion (programa im_c).
*
* OJO: es un IC para el EFECTO (theta), no para el conjunto identificado.
* Si el IC cruza el cero, la atricion sola alcanza para explicar el resultado.
*
* DE DONDE SALEN se_L y se_U  ($im_se)
*   "reg"  (por defecto) EE de la regresion sobre la muestra ya recortada,
*          agrupados por persona. Es rapido pero IGNORA que la fraccion de
*          recorte q tambien se estima: subestima algo la varianza, asi que
*          los IC quedan un poco angostos.
*   "boot" bootstrap de PERSONAS ($im_reps replicas). En cada replica se
*          remuestrean personas con reemplazo y se RECALCULA el recorte, asi
*          que la variabilidad de q y el agrupamiento por persona quedan los
*          dos dentro. Es la opcion correcta para reportar en el paper.
*          Cuesta $im_reps veces mas: para acotar el costo se puede correr con
*          $do_lee_all 0 (solo el outcome g) o subir $im_reps recien al final.
*
* -----------------------------------------------------------------------------
* Definiciones:
*   en riesgo  = personas con decil de origen definido (estaban en t0)
*   presentes  = las que ademas tienen el outcome observado ese anio
*   retencion  = presentes / en riesgo, dentro de cada (decil de origen, anio)
*
* LIMITE. Las pendientes rango-rango (en deciles y en percentiles) no son
* medias ni diferencias de medias, asi que no admiten cotas de Lee ni IC de
* Imbens-Manski. Para ellas se reporta el RANGO DE SENSIBILIDAD de los dos
* recortes simetricos, en las hojas sens_rank_decil y sens_rank_pctl y
* etiquetado como tal: es un diagnostico de cuanto puede mover la atricion a
* la pendiente, no una cota.

* ---- 10.0 Programa que arma las muestras recortadas ----------------------
* lee_flags OUTCOME, dec0(VAR) sgn(VAR) [id(VAR)]
*   crea  lee_lo / lee_hi  (=1 si la observacion sobrevive al recorte)
*   y     lee_ret          (tasa de retencion de la celda)
* sgn: +1 celda que entra con signo (+) en el contraste  -> cota inferior
*         recorta la cola ALTA; cota superior recorta la cola BAJA
*      -1 celda que entra con signo (-)  -> al reves
*       0 celda que no afecta al coeficiente -> no se recorta
* id(): variable que identifica a la persona. En el bootstrap hay que pasar
*       el id REMUESTREADO, no el original, porque una misma persona puede
*       salir sorteada varias veces y cada copia es una persona distinta.
* Se define FUERA del -if- porque -program define- no puede quedar dentro de
* un bloque de llaves de un do-file.

capture program drop lee_flags
program define lee_flags
    syntax varname, DEC0(varname) SGN(varname) [ID(varname)]

    if "`id'" == "" local id id

    capture drop lee_lo
    capture drop lee_hi
    capture drop lee_ret

    tempvar fid nrisk pres npres ret retmin q u rk nn pr

    * --- en riesgo: personas con decil de origen definido -----------------
    bysort `id' (anio): gen byte `fid' = _n == 1
    bysort `dec0': egen double `nrisk' = total(`fid')

    * --- presentes y retencion por (decil de origen, anio) ----------------
    gen byte `pres' = !missing(`varlist')
    bysort `dec0' anio: egen double `npres' = total(`pres')
    gen double `ret' = `npres' / `nrisk'
    bysort `dec0': egen double `retmin' = min(`ret')

    * --- fraccion a recortar en cada celda --------------------------------
    gen double `q' = (`ret' - `retmin') / `ret'
    replace `q' = 0 if missing(`q') | `q' < 0

    * --- posicion del outcome dentro de la celda (solo presentes) ---------
    * Orden unico antes de sortear el desempate: sin esto, el orden en que se
    * reparten los runiform() depende de como -sort- deshizo los empates en
    * los bysort de arriba, y el recorte de los valores empatados (ddec, up,
    * down, top, bot) cambia de corrida en corrida: las cotas no, pero sus EE
    * agrupados si.
    sort `id' anio
    gen double `u' = runiform()
    sort `dec0' anio `pres' `varlist' `u'
    by `dec0' anio `pres': gen double `rk' = _n if `pres'
    by `dec0' anio `pres': gen double `nn' = _N if `pres'
    gen double `pr' = `rk' / `nn'

    * --- recorte direccional ----------------------------------------------
    gen byte lee_lo = `pres'
    gen byte lee_hi = `pres'
    replace lee_lo = `pres' & `pr' <= 1 - `q' if `sgn' > 0 & !missing(`sgn')
    replace lee_hi = `pres' & `pr' >      `q' if `sgn' > 0 & !missing(`sgn')
    replace lee_lo = `pres' & `pr' >      `q' if `sgn' < 0
    replace lee_hi = `pres' & `pr' <= 1 - `q' if `sgn' < 0

    gen double lee_ret = `ret'
    label var lee_lo  "=1 sobrevive al recorte de la cota INFERIOR"
    label var lee_hi  "=1 sobrevive al recorte de la cota SUPERIOR"
    label var lee_ret "Retencion de la celda (decil de origen x anio)"
end


* ---- 10.0b Factor c del IC de Imbens-Manski (biseccion) ------------------
* Resuelve  Phi(c + delta/smax) - Phi(-c) = 1 - alpha  en c.
* La funcion es creciente en c y negativa en c = 0 (para alpha < 0.5), asi
* que hay una sola raiz y la biseccion sobre [0, 10] siempre converge.
* delta se trunca en 0: si las cotas se cruzan por ruido de muestreo, el
* conjunto identificado estimado es vacio y lo prudente es tratarlo como un
* punto, que es el caso mas exigente (c = z(1-alpha/2)).

capture program drop im_c
program define im_c, rclass
    syntax , Delta(real) Smax(real) [Alpha(real 0.05)]

    if `smax' <= 0 | missing(`smax') | missing(`delta') {
        return scalar c = .
        exit
    }

    local d  = max(0, `delta') / `smax'
    local lo = 0
    local hi = 10
    forvalues it = 1/80 {
        local cc = (`lo' + `hi') / 2
        local f  = normal(`cc' + `d') - normal(-`cc') - (1 - `alpha')
        if `f' < 0 local lo = `cc'
        else       local hi = `cc'
    }
    return scalar c = (`lo' + `hi') / 2
end


* ---- 10.0c Programa que calcula TODAS las cotas de una celda (v, j) ------
* Devuelve r(B) = vector columna con las cotas, en el orden de $LEE_ORDER,
* y (con la opcion -se-) r(S) con sus errores estandar.
* Se llama dos veces: una sobre los datos reales y, si $im_se == "boot",
* $im_reps veces sobre remuestreos de personas. Tener la estimacion en UN
* solo lugar evita que el pass principal y el bootstrap se desincronicen.
*   idvar() id de persona (el remuestreado en el bootstrap)
*   se      pide EE de regresion (agrupados por idvar) -> r(S)
*   log     manda la salida de las regresiones al log (solo el pass real)

capture program drop lee_all
program define lee_all, rclass
    syntax , Vname(string) Jdef(string) IDvar(varname) [SE LOG]

    local v "`vname'"
    local j "`jdef'"

    local NZ ""
    if "`log'" != "" local NZ "noisily"
    * La coma va DENTRO del local: en las replicas del bootstrap no se piden
    * EE, y -reg y x if cond,- con la coma colgando es fragil.
    local VCE ""
    if "`se'" != "" local VCE ", vce(cluster `idvar')"

    local LO "$LEE_ORDER"
    tempname B S
    matrix `B' = J($n_lee, 1, .)
    matrix `S' = J($n_lee, 1, .)

    * ---------- (a) dif-en-dif D$hi_decile vs D$lo_decile ----------------
    * signos del contraste  [hi,t] - [lo,t] - [hi,pre] + [lo,pre]
    capture drop _sgn
    quietly gen byte _sgn = 0
    quietly replace _sgn =  1 if decil0_`j'_`v' == $hi_decile & anio != $pre_year
    quietly replace _sgn = -1 if decil0_`j'_`v' == $lo_decile & anio != $pre_year
    quietly replace _sgn = -1 if decil0_`j'_`v' == $hi_decile & anio == $pre_year
    quietly replace _sgn =  1 if decil0_`j'_`v' == $lo_decile & anio == $pre_year

    foreach o of global LEE_DID {

        if "`o'" == "g" local yv gw_`j'_`v'
        else            local yv `o'_`j'_`v'

        if "`log'" != "" di as result _n "-- [A4] `o' : dif-en-dif D$hi_decile vs D$lo_decile --"
        quietly lee_flags `yv', dec0(decil0_`j'_`v') sgn(_sgn) id(`idvar')

        if "`log'" != "" {
            quietly count if lee_lo & inlist(decil0_`j'_`v', $lo_decile, $hi_decile)
            di as text "   N cota inferior: " as result r(N)
            quietly count if lee_hi & inlist(decil0_`j'_`v', $lo_decile, $hi_decile)
            di as text "   N cota superior: " as result r(N)
        }

        foreach cota in lo hi {
            if "`log'" != "" di as result _n "   ... cota `cota'"
            capture `NZ' reg `yv'                                             ///
                ib${pre_year}.anio##ib${lo_decile}.decil0_`j'_`v'             ///
                if lee_`cota' & inlist(decil0_`j'_`v', $lo_decile, $hi_decile) ///
                `VCE'
            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    capture lincom `y'.anio#${hi_decile}.decil0_`j'_`v'
                    if !_rc {
                        local k : list posof "`o'_`cota'_`rr'" in LO
                        if `k' > 0 {
                            matrix `B'[`k', 1] = r(estimate)
                            if "`se'" != "" matrix `S'[`k', 1] = r(se)
                        }
                    }
                }
            }
            else if "`log'" != "" di as error "   no estimable: `v'_`j' `o' cota `cota'"
        }
        capture drop lee_lo
        capture drop lee_hi
        capture drop lee_ret
    }
    capture drop _sgn

    * ---------- (b) efecto del anio (base $pre_year) ----------------------
    * signos del contraste  mu(t) - mu(pre)
    capture drop _sgn
    quietly gen byte _sgn = cond(anio == $pre_year, -1, 1)

    foreach o of global LEE_YR {

        if "`log'" != "" di as result _n "-- [A4] `o' : efecto del anio (base $pre_year) --"
        quietly lee_flags `o'_`j'_`v', dec0(decil0_`j'_`v') sgn(_sgn) id(`idvar')

        if "`log'" != "" {
            quietly count if lee_lo
            di as text "   N cota inferior: " as result r(N)
            quietly count if lee_hi
            di as text "   N cota superior: " as result r(N)
        }

        foreach cota in lo hi {
            if "`log'" != "" di as result _n "   ... cota `cota'"
            capture `NZ' reg `o'_`j'_`v' ib${pre_year}.anio if lee_`cota' `VCE'
            if !_rc {
                local rr = 0
                foreach y of global post_years {
                    local rr = `rr' + 1
                    capture lincom `y'.anio
                    if !_rc {
                        local k : list posof "`o'_`cota'_`rr'" in LO
                        if `k' > 0 {
                            matrix `B'[`k', 1] = r(estimate)
                            if "`se'" != "" matrix `S'[`k', 1] = r(se)
                        }
                    }
                }
            }
            else if "`log'" != "" di as error "   no estimable: `v'_`j' `o' cota `cota'"
        }
        capture drop lee_lo
        capture drop lee_hi
        capture drop lee_ret
    }
    capture drop _sgn

    return matrix B = `B'
    if "`se'" != "" return matrix S = `S'
end


if $do_lee == 1 {

* ---- 10.1 Outcomes, orden de las filas y matrices de resultados ----------

global LEE_DID "g lg ddec"                 // dif-en-dif D hi vs D lo
global LEE_YR  "adec up down top bot"      // efecto del anio
if $do_lee_all == 0 {
    global LEE_DID "g"
    global LEE_YR  ""
}
global LEE_ALL "$LEE_DID $LEE_YR"

* Orden fijo de las filas del vector que devuelve lee_all. lee_all busca cada
* fila POR NOMBRE en esta lista, asi que el orden puede cambiar sin romper
* nada; lo unico que importa es que la lista sea la misma en las dos puntas.
global LEE_ORDER ""
foreach o of global LEE_ALL {
    foreach cota in lo hi {
        forvalues rr = 1/$n_post {
            global LEE_ORDER "$LEE_ORDER `o'_`cota'_`rr'"
        }
    }
}
global n_lee = wordcount("$LEE_ORDER")

* Una matriz por outcome: cotas, EE, IC de Imbens-Manski y el factor c.
foreach o of global LEE_ALL {
    matrix A4L_`o'  = J($n_post, $n_pairs, .)   // cota inferior
    matrix A4H_`o'  = J($n_post, $n_pairs, .)   // cota superior
    matrix A4SL_`o' = J($n_post, $n_pairs, .)   // EE de la cota inferior
    matrix A4SU_`o' = J($n_post, $n_pairs, .)   // EE de la cota superior
    matrix A4CL_`o' = J($n_post, $n_pairs, .)   // IC inferior (Imbens-Manski)
    matrix A4CU_`o' = J($n_post, $n_pairs, .)   // IC superior (Imbens-Manski)
    matrix A4CF_`o' = J($n_post, $n_pairs, .)   // factor c de cada celda
}

* sensibilidad de las pendientes rango-rango (NO son cotas de Lee)
foreach o in rr rrp {
    matrix A4L_`o' = J($n_out_years, $n_pairs, .)
    matrix A4H_`o' = J($n_out_years, $n_pairs, .)
}

* diagnostico de atricion
matrix A4_rt  = J($n_out_years, $n_pairs, .)   // retencion global del anio
matrix A4_rtd = J($n_rows_d,    $n_pairs, .)   // retencion por decil x anio

capture log close movlog
log using "$out/regresiones/A4_lee_bounds_${shock}.log", text replace name(movlog)

di as result _n "===================================================================="
di as result    " (4) COTAS DE LEE + IC DE IMBENS-MANSKI -- muestra NO balanceada"
di as result    "     $shock_lab"
di as result    "     outcomes: $LEE_ALL"
di as result    "     EE de las cotas: $im_se" _continue
if "$im_se" == "boot" di as result "  ($im_reps replicas, bootstrap de personas)"
else                  di as result "  (regresion recortada, agrupada por persona)"
di as result    "     alpha del IC  : $im_alpha"
di as result    "===================================================================="

local c = 0
foreach v of global inc_vars {
    foreach j in a b {
        local c = `c' + 1

        di as result _n "############ `v'  --  definicion de t0: (`j') ############"

        use "$work/${fstem}_analysis.dta", clear
        keep if muestra == 1                      // solo la NO balanceada
        keep if !missing(decil0_`j'_`v')          // y solo D$keep_dec_lo-D$keep_dec_hi

        quietly count
        if r(N) == 0 {
            di as error "  sin observaciones para `v'_`j': se saltea"
            continue
        }

        * ---- 10.2 Diagnostico de atricion --------------------------------
        bysort id (anio): gen byte _fid = _n == 1
        quietly count if _fid
        local nrisk_all = r(N)
        di as text "   personas en riesgo (con decil de origen): " as result `nrisk_all'

        local yi = 0
        foreach y of global out_years {
            local yi = `yi' + 1
            quietly count if anio == `y' & !missing(gw_`j'_`v')
            if `nrisk_all' > 0 matrix A4_rt[`yi', `c'] = r(N) / `nrisk_all'
        }

        local di = 0
        forvalues d = $keep_dec_lo/$keep_dec_hi {
            local di = `di' + 1
            quietly count if _fid & decil0_`j'_`v' == `d'
            local nrisk_d = r(N)
            local yi = 0
            foreach y of global out_years {
                local yi = `yi' + 1
                local row = (`di' - 1) * $n_out_years + `yi'
                quietly count if anio == `y' & decil0_`j'_`v' == `d' & !missing(gw_`j'_`v')
                if `nrisk_d' > 0 matrix A4_rtd[`row', `c'] = r(N) / `nrisk_d'
            }
        }
        drop _fid

        * ---- 10.3 Pass principal: cotas y EE de regresion ----------------
        lee_all, vname(`v') jdef(`j') idvar(id) se log
        matrix LB = r(B)
        matrix LS = r(S)

        * ---- 10.4 Bootstrap de personas para los EE (opcional) -----------
        if "$im_se" == "boot" {

            di as result _n "-- [A4] bootstrap de personas: $im_reps replicas --"
            di as text    "   en cada replica se remuestrean personas con reemplazo"
            di as text    "   y se RECALCULA el recorte, asi que la variabilidad de q entra"

            tempfile cellf idsf
            quietly save "`cellf'", replace
            preserve
                quietly bysort id: keep if _n == 1
                keep id
                quietly save "`idsf'", replace
            restore

            matrix BS1 = J($n_lee, 1, 0)      // suma
            matrix BS2 = J($n_lee, 1, 0)      // suma de cuadrados
            matrix BSN = J($n_lee, 1, 0)      // replicas validas

            local nbad = 0
            forvalues b = 1/$im_reps {
                quietly {
                    use "`idsf'", clear
                    bsample
                    gen long bid = _n
                    joinby id using "`cellf'"
                }
                capture quietly lee_all, vname(`v') jdef(`j') idvar(bid)
                if _rc {
                    local nbad = `nbad' + 1
                    continue
                }
                matrix Bb = r(B)
                forvalues k = 1/$n_lee {
                    if !missing(Bb[`k', 1]) {
                        matrix BS1[`k', 1] = BS1[`k', 1] + Bb[`k', 1]
                        matrix BS2[`k', 1] = BS2[`k', 1] + Bb[`k', 1]^2
                        matrix BSN[`k', 1] = BSN[`k', 1] + 1
                    }
                }
                if mod(`b', 25) == 0 di as text "   ... replica `b' de $im_reps"
            }
            if `nbad' > 0 di as error "   replicas que fallaron por completo: `nbad'"

            * SD entre replicas -> reemplaza a los EE de regresion
            forvalues k = 1/$n_lee {
                scalar _nn = BSN[`k', 1]
                if _nn > 1 {
                    scalar _vv = (BS2[`k', 1] - BS1[`k', 1]^2 / _nn) / (_nn - 1)
                    if _vv > 0 matrix LS[`k', 1] = sqrt(_vv)
                    else       matrix LS[`k', 1] = .
                }
                else matrix LS[`k', 1] = .
            }
            capture scalar drop _nn _vv

            * volver a los datos reales de la celda
            use "`cellf'", clear
        }

        * ---- 10.5 IC de Imbens-Manski -------------------------------------
        local LO "$LEE_ORDER"
        foreach o of global LEE_ALL {
            forvalues rr = 1/$n_post {

                local kL : list posof "`o'_lo_`rr'" in LO
                local kU : list posof "`o'_hi_`rr'" in LO
                if `kL' == 0 | `kU' == 0 continue

                scalar _bL = LB[`kL', 1]
                scalar _bU = LB[`kU', 1]
                scalar _sL = LS[`kL', 1]
                scalar _sU = LS[`kU', 1]

                matrix A4L_`o'[`rr', `c']  = _bL
                matrix A4H_`o'[`rr', `c']  = _bU
                matrix A4SL_`o'[`rr', `c'] = _sL
                matrix A4SU_`o'[`rr', `c'] = _sU

                if $do_im == 1 & !missing(_bL) & !missing(_bU) ///
                   & !missing(_sL) & !missing(_sU) {
                    scalar _smax = max(_sL, _sU)
                    im_c, delta(`=_bU - _bL') smax(`=_smax') alpha($im_alpha)
                    scalar _cf = r(c)
                    if !missing(_cf) {
                        matrix A4CF_`o'[`rr', `c'] = _cf
                        matrix A4CL_`o'[`rr', `c'] = _bL - _cf * _sL
                        matrix A4CU_`o'[`rr', `c'] = _bU + _cf * _sU
                    }
                }
            }
        }
        capture scalar drop _bL _bU _sL _sU _smax _cf

        di as result _n "-- [A4] cotas e IC de `v'_`j' guardados --"
        local rr = 0
        foreach y of global post_years {
            local rr = `rr' + 1
            local kL : list posof "g_lo_`rr'" in LO
            local kU : list posof "g_hi_`rr'" in LO
            if `kL' > 0 & `kU' > 0 {
                di as text "   `y'  g: [" %7.4f LB[`kL',1] ", " %7.4f LB[`kU',1] "]" ///
                    "   IC$im_alpha: [" %7.4f A4CL_g[`rr',`c'] ", " %7.4f A4CU_g[`rr',`c'] "]" ///
                    "   c = " %5.3f A4CF_g[`rr',`c']
            }
        }

        * ---- 10.6 Pendientes rango-rango: RANGO DE SENSIBILIDAD ----------
        * No son cotas de Lee (una pendiente no es una media ni una diferencia
        * de medias, asi que el recorte direccional no la acota). Se recorta
        * simetricamente por arriba y por abajo y se reporta el rango que eso
        * genera, como diagnostico de cuanto puede mover la atricion a la
        * pendiente. Sin IC: no seria un IC de nada bien definido.
        *   rr  = pendiente en DECILES     (decil_t sobre decil_t0)
        *   rrp = pendiente en PERCENTILES (pctl_t  sobre pctl_t0)
        if $do_lee_all == 1 {
            foreach esc in rr rrp {

                if "`esc'" == "rr" {
                    local yv  decil_`v'
                    local xv  decil0_`j'_`v'
                    local etq "deciles"
                }
                else {
                    local yv  pctl_`v'
                    local xv  pctl0_`j'_`v'
                    local etq "percentiles"
                }

                di as result _n "-- [A4] rango-rango en `etq': SENSIBILIDAD (no es cota de Lee) --"
                capture drop _sgn
                gen byte _sgn = 1
                lee_flags `yv', dec0(decil0_`j'_`v') sgn(_sgn) id(id)
                foreach cota in lo hi {
                    di as result _n "   ... recorte `cota'"
                    capture noisily reg `yv'                               ///
                        ib${pre_year}.anio##c.`xv'                         ///
                        if lee_`cota', vce(cluster id)
                    if !_rc {
                        local yi = 0
                        foreach y of global out_years {
                            local yi = `yi' + 1
                            if `y' == $pre_year capture lincom c.`xv'
                            else capture lincom c.`xv' + `y'.anio#c.`xv'
                            if !_rc {
                                if "`cota'" == "lo" matrix A4L_`esc'[`yi', `c'] = r(estimate)
                                if "`cota'" == "hi" matrix A4H_`esc'[`yi', `c'] = r(estimate)
                            }
                        }
                    }
                    else di as error "   no estimable: `v'_`j' rango-rango `etq' recorte `cota'"
                }
                capture drop lee_lo
                capture drop lee_hi
                capture drop lee_ret
                capture drop _sgn
            }
        }
    }
}

capture log close movlog

* ---- 10.7 Excel ------------------------------------------------------------
* Una hoja por outcome. Las filas van en siete bloques de $n_post anios:
*   cota_lo  cota_hi  EE_lo  EE_hi  IC_inf  IC_sup  c_alpha
* Asi las cotas, sus EE y el IC de Imbens-Manski quedan uno debajo del otro
* para la misma columna (variable de ingreso x definicion de t0).

if "$im_se" == "boot" local se_lab "bootstrap de personas, $im_reps replicas"
else                  local se_lab "regresion recortada, agrupada por persona (ignora la variabilidad de q)"

local primera = 1
foreach o of global LEE_ALL {

    if `primera' == 1 {
        putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("cotas_`o'") replace
        local primera = 0
    }
    else {
        putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("cotas_`o'") modify
    }

    if "`o'" == "g"    putexcel A1 = "(4) Cotas de Lee: dif-en-dif del CRECIMIENTO, D$hi_decile vs D$lo_decile"
    if "`o'" == "lg"   putexcel A1 = "(4) Cotas de Lee: dif-en-dif del LOG-CRECIMIENTO, D$hi_decile vs D$lo_decile"
    if "`o'" == "ddec" putexcel A1 = "(4) Cotas de Lee: dif-en-dif del CAMBIO DE DECIL, D$hi_decile vs D$lo_decile"
    if "`o'" == "adec" putexcel A1 = "(4) Cotas de Lee: efecto del anio sobre |cambio de decil|"
    if "`o'" == "up"   putexcel A1 = "(4) Cotas de Lee: efecto del anio sobre P(subir de decil)"
    if "`o'" == "down" putexcel A1 = "(4) Cotas de Lee: efecto del anio sobre P(bajar de decil)"
    if "`o'" == "top"  putexcel A1 = "(4) Cotas de Lee: efecto del anio sobre P(seguir en D$top_decile)"
    if "`o'" == "bot"  putexcel A1 = "(4) Cotas de Lee: efecto del anio sobre P(seguir en D$bot_decile)"

    putexcel A2 = "Shock" B2 = "$shock" C2 = "muestra NO balanceada, origen D$keep_dec_lo-D$keep_dec_hi"
    putexcel A3 = "columnas: variable de ingreso x definicion de t0. El efecto esta entre cota_lo y cota_hi."
    putexcel A4 = "IC_inf/IC_sup = IC de Imbens-Manski para el EFECTO al `=100*(1-$im_alpha)'% (NO para el conjunto identificado). EE: `se_lab'"
    putexcel A5 = "fila" B5 = "anio"
    local cc = 2
    foreach pl of global PAIRLAB {
        local cc = `cc' + 1
        local cl : word `cc' of $XLCOL
        putexcel `cl'5 = "`pl'"
    }

    local rw = 5
    foreach fila in cota_lo cota_hi EE_lo EE_hi IC_inf IC_sup c_alpha {
        foreach y of global post_years {
            local rw = `rw' + 1
            putexcel A`rw' = "`fila'" B`rw' = `y'
        }
    }

    local r0 = 6
    putexcel C`r0' = matrix(A4L_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4H_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4SL_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4SU_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4CL_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4CU_`o')
    local r0 = `r0' + $n_post
    putexcel C`r0' = matrix(A4CF_`o')
}

if $do_lee_all == 1 {
    foreach esc in rr rrp {

        if "`esc'" == "rr" local hoja "sens_rank_decil"
        else               local hoja "sens_rank_pctl"

        putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("`hoja'") modify
        if "`esc'" == "rr" {
            putexcel A1 = "(4) Pendiente rango-rango en DECILES: RANGO DE SENSIBILIDAD a la atricion"
        }
        else {
            putexcel A1 = "(4) Pendiente rango-rango en PERCENTILES: RANGO DE SENSIBILIDAD a la atricion"
        }
        putexcel A2 = "NO es una cota de Lee ni un IC: una pendiente no es una media ni una diferencia de medias."
        putexcel A3 = "Es el rango que producen los dos recortes simetricos (cola alta / cola baja)."
        putexcel A5 = "recorte" B5 = "anio"
        local cc = 2
        foreach pl of global PAIRLAB {
            local cc = `cc' + 1
            local cl : word `cc' of $XLCOL
            putexcel `cl'5 = "`pl'"
        }
        local rw = 5
        foreach cota in lo hi {
            foreach y of global out_years {
                local rw = `rw' + 1
                putexcel A`rw' = "`cota'" B`rw' = `y'
            }
        }
        putexcel C6 = matrix(A4L_`esc')
        local rw6 = 6 + $n_out_years
        putexcel C`rw6' = matrix(A4H_`esc')
    }
}

putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("retencion") modify
putexcel A1 = "(4) Tasa de retencion por anio (presentes / en riesgo en t0)"
putexcel A2 = "muestra NO balanceada, deciles de origen $keep_dec_lo-$keep_dec_hi"
putexcel A3 = "anio"
local cc = 1
foreach pl of global PAIRLAB {
    local cc = `cc' + 1
    local cl : word `cc' of $XLCOL
    putexcel `cl'3 = "`pl'"
}
local rw = 3
foreach y of global out_years {
    local rw = `rw' + 1
    putexcel A`rw' = `y'
}
putexcel B4 = matrix(A4_rt)

putexcel set "$out/tablas/A4_lee_bounds_${shock}.xlsx", sheet("retencion_decil") modify
putexcel A1 = "(4) Tasa de retencion por decil de origen y anio"
putexcel A2 = "Es la fuente del problema: si la retencion cae mas en unos deciles que en otros,"
putexcel A3 = "la composicion cambia entre anios y el dif-en-dif crudo queda sesgado."
putexcel A5 = "decil_t0" B5 = "anio"
local cc = 2
foreach pl of global PAIRLAB {
    local cc = `cc' + 1
    local cl : word `cc' of $XLCOL
    putexcel `cl'5 = "`pl'"
}
local rw = 5
forvalues d = $keep_dec_lo/$keep_dec_hi {
    foreach y of global out_years {
        local rw = `rw' + 1
        putexcel A`rw' = `d' B`rw' = `y'
    }
}
putexcel C6 = matrix(A4_rtd)

di as result "Excel escrito: $out/tablas/A4_lee_bounds_${shock}.xlsx"

capture program drop lee_flags
capture program drop lee_all
* im_c se borra al final del bloque 11, que tambien lo usa

}



* ============================================================================
* 11. LOS QUE SE VAN: COMPARACION PRE-SHOCK, ESCENARIOS Y PEOR CASO
* ============================================================================
* Solo muestra NO balanceada y solo los resultados de crecimiento (lg y g).
*
* POBLACION. Personas con decil de origen D$keep_dec_lo-D$keep_dec_hi
* OBSERVADAS en $pre_year. Para cada anio post t:
*     se quedan = observados en $pre_year y en t
*     se van    = observados en $pre_year y NO en t
*     vuelven   = observados en t pero no en $pre_year. Quedan FUERA de la
*                 poblacion: son los que violan la monotonicidad de Lee. Se
*                 reporta cuantos son, para saber si importan.
* "Observado" = con el resultado definido ese anio (ingreso positivo en esa
* variable). El que "se va" puede seguir en el panel con ingreso cero.
*
* POR QUE. Las cotas de Lee (bloque 10) acotan el efecto de los que se
* quedan ADIVINANDO quienes son (recortando colas). En este panel se ve
* quien se queda, asi que ese efecto se estima directo (11.2, fila
* "quedan"), pero sigue sin decir nada de los que se van. Este bloque:
*
* 11.1 COMPARACION PRE-SHOCK dentro de cada decil de origen: los que se van
*      vs los que se quedan, en ln y_pre, log-crecimiento base -> pre,
*      percentil en $pre_year y percentil de origen. Y el contraste que
*      importa para el dif-en-dif: la brecha [se van - quedan] en
*      D$hi_decile menos la de D$lo_decile. Si es chica, la desercion no
*      deberia sesgar el dif-en-dif de los que se quedan.
* 11.2 ESCENARIOS para el resultado en t de los que se van. Con
*          D_i = y_it - y_i,pre            (y = lg o g)
*      el dif-en-dif D$hi_decile vs D$lo_decile es la diferencia de medias
*      de D_i entre los dos deciles (una fila por persona, EE robustos =
*      agrupados por persona):
*          quedan    solo los que se quedan (efecto de los que se quedan)
*          mantiene  los que se van mantienen su ingreso de $pre_year: D_i = 0
*          cero      su ingreso cae a cero: g_t = -1. Solo en g: en logs no
*                    esta definido.
*          decil     su crecimiento base -> t es el PROMEDIO del de los que se
*                    quedan en su mismo decil de origen y anio:
*                        D_i = media_quedan(y_t | decil) - y_i,pre
*                    Supone que, dentro del decil, los que se van habrian
*                    crecido (desde la base) como los que se quedan. Como su
*                    y_pre es mas bajo, implica un rebote desde $pre_year.
*                    (Imputar en cambio el cambio pre -> t medio del decil
*                    daria exactamente el mismo resultado que "quedan".)
*          winsorizado  solo los que se quedan, con el crecimiento base -> pre
*                    y base -> t topeado en su p$win_scen_p (umbral comun a los
*                    dos deciles, uno por anio): saca el peso de las colas
*                    extremas, sobre todo en g.
*          rango de deciles  par de cotas: a los que se van se les imputa el
*                    crecimiento base -> t medio de los que se quedan de ALGUNO
*                    de los 10 deciles de origen (calculado en 05, antes de la
*                    restriccion), el que lleva el dif-en-dif a su extremo:
*                        cota inferior: D$hi_decile <- el decil que menos crecio,
*                                       D$lo_decile <- el que mas crecio
*                        cota superior: al reves
*                    Mas angosto que el peor caso: supone que los que se van se
*                    comportaron como el promedio de algun decil, no como un
*                    individuo extremo. Con IC de Imbens-Manski.
* 11.3 PEOR CASO (Horowitz-Manski). El resultado en t de los que se van
*      (crecimiento desde la base hasta t) se lleva al piso o al techo, en la
*      direccion que minimiza / maximiza el dif-en-dif:
*          cota inferior: los de D$hi_decile al piso, los de D$lo_decile al techo
*          cota superior: al reves
*      piso y techo = percentiles del resultado de los que se QUEDAN, en el
*      mismo decil y anio. Una variante por par de $wc_p_lo / $wc_p_hi
*      (por defecto p1/p99, p10/p90, p20/p80). En g, la primera variante usa
*      piso -1 (ingreso cero) si $wc_g_floor0 == 1.
*      Es un supuesto EXPLICITO sobre el soporte: sin piso ni techo las cotas
*      serian infinitas. Las variantes angostas suponen mas (que los que se
*      van quedan dentro del p10-p90 o del p20-p80 de los que se quedan) y
*      por eso dan cotas mas angostas. IC de Imbens-Manski con el programa
*      im_c (10.0b) y los EE robustos de cada cota.
*
* Salida: $out/tablas/A5_desercion_${shock}.xlsx
*   comparacion      anio post x decil x estadistico
*   contraste        [se van - quedan] en D$hi_decile menos en D$lo_decile
*   escenarios_lg    una fila por estimacion y anio post (log-crecimiento)
*   escenarios_g     idem, crecimiento y/y_base - 1
*   notas            definiciones

if $do_leavers == 1 {

local _nwlo : word count $wc_p_lo
local _nwhi : word count $wc_p_hi
if `_nwlo' != `_nwhi' | `_nwlo' == 0 {
    di as error "wc_p_lo y wc_p_hi tienen que tener la misma cantidad de percentiles"
    exit 198
}
forvalues k = 1/`_nwlo' {
    local _plo : word `k' of $wc_p_lo
    local _phi : word `k' of $wc_p_hi
    if !(0 < `_plo' & `_plo' < `_phi' & `_phi' < 100) {
        di as error "percentiles de peor caso invalidos: p`_plo' / p`_phi'"
        exit 198
    }
}

capture program list im_c
if _rc {
    di as error "Falta el programa im_c: correr antes el bloque 10.0b."
    exit 199
}

capture log close movlog
log using "$out/regresiones/A5_desercion_${shock}.log", text replace name(movlog)

di as result _n "===================================================================="
di as result    " (5) LOS QUE SE VAN -- muestra NO balanceada"
di as result    "     $shock_lab"
di as result    "     poblacion: observados en $pre_year, origen D$keep_dec_lo-D$keep_dec_hi"
di as result    "     peor caso: piso / techo = p($wc_p_lo) / p($wc_p_hi) de los que se quedan"
if $wc_g_floor0 == 1 di as result "                (en g, la primera variante usa piso -1)"
di as result    "===================================================================="

* minimo y maximo del crecimiento medio por decil de origen (los 10) de los
* que se quedan, por columna, anio post y resultado -> locals dmn_* / dmx_*
* (valor) y ddn_* / ddx_* (decil)
capture confirm file "$work/${fstem}_dec_means.dta"
local _hasdm = !_rc
if !`_hasdm' di as error "OJO: falta $work/${fstem}_dec_means.dta (bloque 05): sin el escenario rango de deciles."
if `_hasdm' {
    use "$work/${fstem}_dec_means.dta" if muestra == 1, clear
    quietly levelsof pair, local(_dpairs)
    foreach p of local _dpairs {
        foreach y of global post_years {
            foreach o in lg gw {
                quietly summarize m_`o' if pair == "`p'" & anio == `y'
                if r(N) == 0 continue
                local dmn_`o'_`p'_`y' = r(min)
                local dmx_`o'_`p'_`y' = r(max)
                quietly levelsof decil if pair == "`p'" & anio == `y' & m_`o' == r(min), local(_dd) clean
                local ddn_`o'_`p'_`y' : word 1 of `_dd'
                quietly summarize m_`o' if pair == "`p'" & anio == `y'
                quietly levelsof decil if pair == "`p'" & anio == `y' & m_`o' == r(max), local(_dd) clean
                local ddx_`o'_`p'_`y' : word 1 of `_dd'
            }
        }
    }
}

tempname PC PE
postfile `PC' str16 pair int anio byte decil int stat double value ///
    using "$work/${fstem}_lv_comp.dta", replace
postfile `PE' str16 pair str2 outc int anio int fila double value ///
    using "$work/${fstem}_lv_esc.dta", replace

foreach v of global inc_vars {
    foreach j in a b {
        local pl "`v'_`j'"
        di as result _n "############ `pl' ############"

        use id anio muestra decil0_`j'_`v' pctl0_`j'_`v' pctl_`v' real_`v'  ///
            gw_`j'_`v' lg_`j'_`v' if muestra == 1 & !missing(decil0_`j'_`v') ///
            using "$work/${fstem}_analysis.dta", clear
        quietly count
        if r(N) == 0 {
            di as error "  sin observaciones para `pl': se saltea"
            continue
        }
        rename (decil0_`j'_`v' pctl0_`j'_`v' pctl_`v' real_`v' gw_`j'_`v' lg_`j'_`v') ///
               (d0 p0 pc y gw lg)
        gen byte _obs = !missing(lg)

        * ---- valores del anio pre, por persona ---------------------------
        foreach x in y gw lg pc {
            quietly gen double _t = `x' if anio == $pre_year & _obs
            quietly bysort id: egen double `x'_pre = max(_t)
            drop _t
        }
        gen byte   in_pre  = !missing(lg_pre)
        gen double lny_pre = ln(y_pre)

        foreach y of global post_years {

            preserve
            quietly {
                foreach x in gw lg {
                    gen double _t = `x' if anio == `y' & _obs
                    bysort id: egen double `x'_t = max(_t)
                    drop _t
                }
                bysort id (anio): keep if _n == 1       // una fila por persona
                gen byte stay   =  in_pre & !missing(lg_t)
                gen byte leave  =  in_pre &  missing(lg_t)
                gen byte vuelve = !in_pre & !missing(lg_t)
                gen byte hi     = d0 == $hi_decile
            }

            * ---- 11.1 comparacion pre-shock, por decil ------------------
            forvalues d = $keep_dec_lo/$keep_dec_hi {
                quietly count if d0 == `d' & in_pre
                local npre = r(N)
                post `PC' ("`pl'") (`y') (`d') (1) (`npre')
                if `npre' == 0 continue
                quietly count if d0 == `d' & leave
                post `PC' ("`pl'") (`y') (`d') (2) (r(N) / `npre')
                quietly count if d0 == `d' & vuelve
                post `PC' ("`pl'") (`y') (`d') (3) (r(N) / `npre')
                local k = 0
                foreach x in lny_pre lg_pre pc_pre p0 {
                    local k = `k' + 1
                    quietly summarize `x' if d0 == `d' & stay, meanonly
                    local ms = cond(r(N) > 0, r(mean), .)
                    quietly summarize `x' if d0 == `d' & leave, meanonly
                    local ml = cond(r(N) > 0, r(mean), .)
                    post `PC' ("`pl'") (`y') (`d') (10*`k' + 1) (`ms')
                    post `PC' ("`pl'") (`y') (`d') (10*`k' + 2) (`ml')
                    post `PC' ("`pl'") (`y') (`d') (10*`k' + 3) (`ml' - `ms')
                }
            }

            * [se van - quedan] en D$hi_decile menos en D$lo_decile (decil 0)
            capture quietly reg leave hi ///
                if in_pre & inlist(d0, $lo_decile, $hi_decile), vce(robust)
            if !_rc {
                post `PC' ("`pl'") (`y') (0) (7) (_b[hi])
                post `PC' ("`pl'") (`y') (0) (8) (_se[hi])
                post `PC' ("`pl'") (`y') (0) (9) (2*ttail(e(df_r), abs(_b[hi]/_se[hi])))
            }
            local k = 0
            foreach x in lny_pre lg_pre pc_pre p0 {
                local k = `k' + 1
                capture quietly reg `x' i.leave##i.hi ///
                    if in_pre & inlist(d0, $lo_decile, $hi_decile), vce(robust)
                if !_rc {
                    capture quietly lincom 1.leave#1.hi
                    if !_rc {
                        post `PC' ("`pl'") (`y') (0) (10*`k' + 4) (r(estimate))
                        post `PC' ("`pl'") (`y') (0) (10*`k' + 5) (r(se))
                        post `PC' ("`pl'") (`y') (0) (10*`k' + 6) ///
                            (2*ttail(r(df), abs(r(estimate)/r(se))))
                    }
                }
            }

            * ---- 11.2 escenarios y 11.3 peor caso ------------------------
            quietly keep if in_pre & inlist(d0, $lo_decile, $hi_decile)
            quietly count if stay
            local nst = r(N)
            quietly count if leave
            local nlv = r(N)
            quietly summarize leave if !hi, meanonly
            local shlo = cond(r(N) > 0, r(mean), .)
            quietly summarize leave if hi, meanonly
            local shhi = cond(r(N) > 0, r(mean), .)

            foreach o in lg gw {
                local oc = cond("`o'" == "lg", "lg", "g")

                * ---- 11.2 escenarios (filas 1-16 del Excel) ------------------
                quietly {
                    gen double D_q = `o'_t - `o'_pre if stay
                    gen double D_m = cond(stay, `o'_t - `o'_pre, 0)
                    if "`o'" == "gw" gen double D_c = cond(stay, gw_t - gw_pre, -1 - gw_pre)
                    * decil: media de y_t de los que se quedan en el mismo decil
                    bysort d0: egen double _myt = mean(cond(stay, `o'_t, .))
                    gen double D_d = cond(stay, `o'_t - `o'_pre, _myt - `o'_pre)
                    drop _myt
                    * winsorizado: tope en p$win_scen_p, solo los que se quedan
                    local _cp = .
                    local _ct = .
                    capture _pctile `o'_pre if stay, percentiles($win_scen_p)
                    if !_rc local _cp = r(r1)
                    capture _pctile `o'_t if stay, percentiles($win_scen_p)
                    if !_rc local _ct = r(r1)
                    gen double D_w = min(`o'_t, `_ct') - min(`o'_pre, `_cp') if stay
                }
                foreach sc in q m c d w {
                    local b_`sc' = .
                    local s_`sc' = .
                    if "`sc'" == "c" & "`o'" != "gw" continue
                    capture quietly reg D_`sc' hi, vce(robust)
                    if !_rc {
                        local b_`sc' = _b[hi]
                        local s_`sc' = _se[hi]
                    }
                }
                local f = 0
                foreach nm in b_q s_q b_m s_m b_c s_c b_d s_d b_w s_w nst nlv shlo shhi _cp _ct {
                    local f = `f' + 1
                    if "``nm''" == "" local `nm' = .
                    post `PE' ("`pl'") ("`oc'") (`y') (`f') (``nm'')
                }
                di as text "  `y' `oc':  quedan " as result %8.4f `b_q'          ///
                   as text "  mantiene " as result %8.4f `b_m'                  ///
                   as text "  cero " as result %8.4f `b_c'                      ///
                   as text "  decil " as result %8.4f `b_d'                     ///
                   as text "  winsor " as result %8.4f `b_w'
                drop D_q D_m D_d D_w
                capture drop D_c

                * ---- 11.2b rango de deciles (filas 51-61 del Excel) ----------
                local Rn  = .
                local Rx  = .
                local Rdn = .
                local Rdx = .
                if "`dmn_`o'_`pl'_`y''" != "" {
                    local Rn  = `dmn_`o'_`pl'_`y''
                    local Rx  = `dmx_`o'_`pl'_`y''
                    local Rdn = `ddn_`o'_`pl'_`y''
                    local Rdx = `ddx_`o'_`pl'_`y''
                }
                foreach nm in b_rl b_rh s_rl s_rh ci_rl ci_rh cf_r {
                    local `nm' = .
                }
                if !missing(`Rn', `Rx') {
                    quietly {
                        gen double D_rl = cond(stay, `o'_t - `o'_pre, cond(hi, `Rn', `Rx') - `o'_pre)
                        gen double D_rh = cond(stay, `o'_t - `o'_pre, cond(hi, `Rx', `Rn') - `o'_pre)
                    }
                    foreach sc in rl rh {
                        capture quietly reg D_`sc' hi, vce(robust)
                        if !_rc {
                            local b_`sc' = _b[hi]
                            local s_`sc' = _se[hi]
                        }
                    }
                    drop D_rl D_rh
                    if !missing(`b_rl', `b_rh', `s_rl', `s_rh') {
                        quietly im_c, delta(`=`b_rh' - `b_rl'') ///
                            smax(`=max(`s_rl', `s_rh')') alpha($im_alpha)
                        local cf_r = r(c)
                        if !missing(`cf_r') {
                            local ci_rl = `b_rl' - `cf_r' * `s_rl'
                            local ci_rh = `b_rh' + `cf_r' * `s_rh'
                        }
                    }
                }
                local f = 50
                foreach nm in b_rl b_rh s_rl s_rh ci_rl ci_rh cf_r Rdn Rn Rdx Rx {
                    local f = `f' + 1
                    if "``nm''" == "" local `nm' = .
                    post `PE' ("`pl'") ("`oc'") (`y') (`f') (``nm'')
                }
                di as text "        rango de deciles (D`Rdn' / D`Rdx'): [" as result %8.4f `b_rl' ///
                   as text "," as result %8.4f `b_rh' as text "]"

                * ---- 11.3 peor caso: una variante por par de percentiles -----
                * filas 100*k + 1..11 del Excel (k = numero de variante)
                local nwc : word count $wc_p_lo
                forvalues k = 1/`nwc' {
                    local plo : word `k' of $wc_p_lo
                    local phi : word `k' of $wc_p_hi

                    * piso y techo: p`plo' / p`phi' de los que se quedan, por decil
                    foreach side in lo hi {
                        local L`side' = .
                        local U`side' = .
                        capture _pctile `o'_t if stay & d0 == ${`side'_decile}, ///
                            percentiles(`plo' `phi')
                        if !_rc {
                            local L`side' = r(r1)
                            local U`side' = r(r2)
                        }
                        if "`o'" == "gw" & `k' == 1 & $wc_g_floor0 == 1 local L`side' = -1
                    }

                    quietly {
                        gen double D_lo = cond(stay, `o'_t - `o'_pre, ///
                                               cond(hi, `Lhi', `Ulo') - `o'_pre)
                        gen double D_hi = cond(stay, `o'_t - `o'_pre, ///
                                               cond(hi, `Uhi', `Llo') - `o'_pre)
                    }
                    foreach sc in lo hi {
                        local b_`sc' = .
                        local s_`sc' = .
                        capture quietly reg D_`sc' hi, vce(robust)
                        if !_rc {
                            local b_`sc' = _b[hi]
                            local s_`sc' = _se[hi]
                        }
                    }

                    * IC de Imbens-Manski para el efecto sobre toda la poblacion
                    local cf    = .
                    local ci_lo = .
                    local ci_hi = .
                    if !missing(`b_lo', `b_hi', `s_lo', `s_hi') {
                        quietly im_c, delta(`=`b_hi' - `b_lo'') ///
                            smax(`=max(`s_lo', `s_hi')') alpha($im_alpha)
                        local cf = r(c)
                        if !missing(`cf') {
                            local ci_lo = `b_lo' - `cf' * `s_lo'
                            local ci_hi = `b_hi' + `cf' * `s_hi'
                        }
                    }

                    local f = 100 * `k'
                    foreach nm in b_lo b_hi s_lo s_hi ci_lo ci_hi cf Llo Ulo Lhi Uhi {
                        local f = `f' + 1
                        if "``nm''" == "" local `nm' = .
                        post `PE' ("`pl'") ("`oc'") (`y') (`f') (``nm'')
                    }

                    di as text "        p`plo'/p`phi': [" as result %8.4f `b_lo' ///
                       as text "," as result %8.4f `b_hi' as text "]  IC ["     ///
                       as result %8.4f `ci_lo' as text "," as result %8.4f `ci_hi' ///
                       as text "]"

                    drop D_lo D_hi
                }
            }
            restore
        }
    }
}

postclose `PC'
postclose `PE'
capture log close movlog

* ---- 11.4 Excel ------------------------------------------------------------

use "$work/${fstem}_lv_comp.dta", clear
local lab1 "ln y $pre_year"
local lab2 "log-crec. base-$pre_year"
local lab3 "percentil en $pre_year"
local lab4 "percentil de origen"
label define lv_stat 1 "N observados en $pre_year"                          ///
                     2 "share que se va (no esta en t)"                     ///
                     3 "share que vuelve (en t sin estar en $pre_year)"     ///
                     7 "share que se va: D$hi_decile - D$lo_decile (coef)"  ///
                     8 "share que se va: D$hi_decile - D$lo_decile (EE)"    ///
                     9 "share que se va: D$hi_decile - D$lo_decile (p)", replace
forvalues k = 1/4 {
    label define lv_stat `=10*`k'+1' "`lab`k'': quedan"                     ///
                         `=10*`k'+2' "`lab`k'': se van"                     ///
                         `=10*`k'+3' "`lab`k'': se van - quedan"            ///
                         `=10*`k'+4' "`lab`k'': [se van - quedan] D$hi_decile - D$lo_decile (coef)" ///
                         `=10*`k'+5' "`lab`k'': [se van - quedan] D$hi_decile - D$lo_decile (EE)"   ///
                         `=10*`k'+6' "`lab`k'': [se van - quedan] D$hi_decile - D$lo_decile (p)", add
}
label values stat lv_stat
quietly reshape wide value, i(anio decil stat) j(pair) string
rename value* *
capture order anio decil stat $PAIRLAB
sort anio decil stat

preserve
    quietly keep if decil > 0
    export excel using "$out/tablas/A5_desercion_${shock}.xlsx", ///
        sheet("comparacion") firstrow(variables) replace
restore
preserve
    quietly keep if decil == 0
    drop decil
    export excel using "$out/tablas/A5_desercion_${shock}.xlsx", ///
        sheet("contraste", replace) firstrow(variables)
restore

use "$work/${fstem}_lv_esc.dta", clear
label define lv_fila  1 "quedan: coef"                                ///
                      2 "quedan: EE"                                  ///
                      3 "mantienen su ingreso de $pre_year: coef"     ///
                      4 "mantienen su ingreso de $pre_year: EE"       ///
                      5 "su ingreso cae a cero: coef (solo g)"        ///
                      6 "su ingreso cae a cero: EE (solo g)"          ///
                      7 "crecen como los que se quedan en su decil: coef" ///
                      8 "crecen como los que se quedan en su decil: EE"   ///
                      9 "quedan, crecimiento winsorizado en p$win_scen_p: coef" ///
                     10 "quedan, crecimiento winsorizado en p$win_scen_p: EE"   ///
                     11 "N se quedan (D$lo_decile + D$hi_decile)"     ///
                     12 "N se van (D$lo_decile + D$hi_decile)"        ///
                     13 "share que se va D$lo_decile"                 ///
                     14 "share que se va D$hi_decile"                 ///
                     15 "winsorizado: tope del crecimiento base-$pre_year" ///
                     16 "winsorizado: tope del crecimiento base-t"    ///
                     51 "rango de deciles: cota inferior"             ///
                     52 "rango de deciles: cota superior"             ///
                     53 "rango de deciles: EE cota inferior"          ///
                     54 "rango de deciles: EE cota superior"          ///
                     55 "rango de deciles: IC inferior (Imbens-Manski)" ///
                     56 "rango de deciles: IC superior (Imbens-Manski)" ///
                     57 "rango de deciles: factor c"                  ///
                     58 "rango de deciles: decil que menos crecio"    ///
                     59 "rango de deciles: su crecimiento medio"      ///
                     60 "rango de deciles: decil que mas crecio"      ///
                     61 "rango de deciles: su crecimiento medio", replace
local nwc : word count $wc_p_lo
forvalues k = 1/`nwc' {
    local plo : word `k' of $wc_p_lo
    local phi : word `k' of $wc_p_hi
    local pc "peor caso p`plo'/p`phi'"
    if `k' == 1 & $wc_g_floor0 == 1 local pc "`pc' (en g: piso -1)"
    local b = 100 * `k'
    label define lv_fila `=`b'+1'  "`pc': cota inferior"                  ///
                         `=`b'+2'  "`pc': cota superior"                  ///
                         `=`b'+3'  "`pc': EE cota inferior"               ///
                         `=`b'+4'  "`pc': EE cota superior"               ///
                         `=`b'+5'  "`pc': IC inferior (Imbens-Manski)"    ///
                         `=`b'+6'  "`pc': IC superior (Imbens-Manski)"    ///
                         `=`b'+7'  "`pc': factor c"                       ///
                         `=`b'+8'  "`pc': piso usado D$lo_decile"         ///
                         `=`b'+9'  "`pc': techo usado D$lo_decile"        ///
                         `=`b'+10' "`pc': piso usado D$hi_decile"         ///
                         `=`b'+11' "`pc': techo usado D$hi_decile", add
}
label values fila lv_fila
quietly reshape wide value, i(outc anio fila) j(pair) string
rename value* *
capture order outc anio fila $PAIRLAB
sort outc anio fila
foreach oc in lg g {
    preserve
        quietly keep if outc == "`oc'"
        drop outc
        export excel using "$out/tablas/A5_desercion_${shock}.xlsx", ///
            sheet("escenarios_`oc'", replace) firstrow(variables)
    restore
}

putexcel set "$out/tablas/A5_desercion_${shock}.xlsx", sheet("notas") modify
putexcel A1  = "(5) Los que se van -- $shock_lab"
putexcel A3  = "Poblacion: personas con decil de origen D$keep_dec_lo-D$keep_dec_hi observadas en $pre_year (muestra no balanceada)."
putexcel A4  = "Para cada anio post t: se quedan = observados en $pre_year y en t; se van = observados en $pre_year y no en t."
putexcel A5  = "Vuelven = observados en t sin estar en $pre_year: quedan fuera (violan la monotonicidad de Lee). Su share esta en 'comparacion'."
putexcel A6  = "comparacion: medias pre-shock de los que se quedan y los que se van, por decil de origen y anio post t."
putexcel A7  = "contraste: [se van - quedan] en D$hi_decile menos en D$lo_decile, con EE robustos. Si es chico, la desercion no deberia sesgar el dif-en-dif de los que se quedan."
putexcel A8  = "escenarios: dif-en-dif D$hi_decile - D$lo_decile de D_i = y_it - y_i,pre (una fila por persona, EE robustos)."
putexcel A9  = "   quedan = solo los que se quedan; mantienen = los que se van conservan su ingreso de $pre_year (D_i = 0); cero = su ingreso cae a cero (g = -1; solo en g); decil = su crecimiento base->t es la media del de los que se quedan en su decil de origen."
putexcel A15 = "   winsorizado: solo los que se quedan; el crecimiento base->$pre_year y base->t se topea en su p$win_scen_p (umbral comun a D$lo_decile y D$hi_decile, uno por anio)."
putexcel A14 = "   rango de deciles: a los que se van se les imputa el crecimiento base->t medio de los que se quedan de alguno de los 10 deciles de origen. Cota inferior: D$hi_decile <- el que menos crecio, D$lo_decile <- el que mas; superior al reves."
putexcel A10 = "   peor caso: el crecimiento base->t de los que se van se lleva al piso o al techo = percentiles de los que se quedan, en su decil y anio."
putexcel A11 = "   una variante por par de percentiles: p($wc_p_lo) / p($wc_p_hi). En g, la primera variante usa piso -1 (ingreso cero) si wc_g_floor0 = 1 (ahora: $wc_g_floor0)."
putexcel A12 = "   cota inferior: D$hi_decile al piso y D$lo_decile al techo; cota superior al reves. Es un supuesto explicito sobre el soporte: las variantes angostas suponen mas."
putexcel A13 = "   IC de Imbens-Manski al `=100*(1-$im_alpha)'% para el EFECTO sobre toda la poblacion (no para el conjunto identificado)."

di as result "Excel escrito: $out/tablas/A5_desercion_${shock}.xlsx"

}

capture program drop im_c



* ============================================================================
* 12. HETEROGENEIDAD: EL DIF-EN-DIF (1) POR GRUPOS
* ============================================================================
* Para cada dimension prendida y con dato (edad, sexo, civil, educ, etnia),
* cada muestra, variable de ingreso x def. t0 y cada decil de comparacion c
* de $lo_list, UNA regresion totalmente interactuada:
*     y = anio x decil de origen x grupo      (solo D$hi_decile y Dc)
* y el resultado principal ($main_growth), EE agrupados por persona. De ahi
* salen, para cada anio post:
*   - el dif-en-dif D$hi_decile vs Dc DENTRO de cada grupo: coef, EE, p
*     (identico a correr 7.1 solo con ese grupo)
*   - la diferencia de ese dif-en-dif entre cada grupo y el grupo BASE (el
*     de codigo mas bajo), con EE y p: es el test de heterogeneidad
*   - N de observaciones del grupo en la regresion
* Ademas, la hoja "composicion" da, en $pre_year, el peso de cada grupo
* dentro de cada decil de origen: un grupo puede cambiar el dif-en-dif
* promedio solo porque pesa distinto en D$hi_decile y en Dc.
*
* Usa $work/${fstem}_carac.dta del bloque 05.2.
* Salida: $out/tablas/A6_heterogeneidad_${shock}.xlsx
*   una hoja por dimension, composicion, notas

if $do_het == 1 {

capture confirm file "$work/${fstem}_carac.dta"
if _rc {
    di as error "Falta $work/${fstem}_carac.dta: correr antes el bloque 05.2."
    exit 601
}

* dimensiones: prendidas y con dato
use "$work/${fstem}_carac.dta", clear
local dims ""
foreach d in edad sexo civil educ etnia {
    if ${het_`d'} == 1 {
        capture confirm variable het_`d'
        if !_rc {
            quietly count if !missing(het_`d')
            if r(N) > 0 local dims "`dims' `d'"
            else di as error "OJO: het_`d' sin datos: se saltea"
        }
        else di as error "OJO: no se pudo armar het_`d' (ver 05.2): se saltea"
    }
}

if "`dims'" == "" di as error "Heterogeneidad: ninguna dimension disponible."
else {

if "$main_growth" == "lg" local ymain "lg"
else                      local ymain "gw"

use muestra id anio decil0_* `ymain'_* using "$work/${fstem}_analysis.dta", clear
merge m:1 id using "$work/${fstem}_carac.dta", keep(1 3) nogenerate

capture log close movlog
log using "$out/regresiones/A6_heterogeneidad_${shock}.log", text replace name(movlog)
di as result _n "===================================================================="
di as result    " (6) HETEROGENEIDAD -- $shock_lab"
di as result    "     dimensiones: `dims'   comparaciones: D$hi_decile vs D($lo_list)"
di as result    "     resultado: $main_lab"
di as result    "===================================================================="

tempname PH PK
postfile `PH' str16 pair str6 dim byte muestra int contraste int anio int nivel ///
    str24 nivel_lab byte stat double value using "$work/${fstem}_het.dta", replace
postfile `PK' str16 pair str6 dim byte muestra int decil int nivel ///
    str24 nivel_lab byte stat double value using "$work/${fstem}_het_comp.dta", replace

foreach d of local dims {
    di as result _n "############ dimension: `d' ############"
    local si = 0
    foreach s of global samples {
        local si = `si' + 1
        foreach v of global inc_vars {
            foreach j in a b {
                local pl "`v'_`j'"
                local yv "`ymain'_`j'_`v'"
                local dv "decil0_`j'_`v'"

                quietly levelsof het_`d' if muestra == `si' & !missing(`dv', `yv'), local(levs)
                if "`levs'" == "" continue
                local base : word 1 of `levs'

                * ---- composicion en el anio pre --------------------------
                forvalues dd = $keep_dec_lo/$keep_dec_hi {
                    quietly count if muestra == `si' & anio == $pre_year & `dv' == `dd' ///
                        & !missing(`yv', het_`d')
                    local ntot = r(N)
                    if `ntot' == 0 continue
                    foreach k of local levs {
                        local lab : label (het_`d') `k'
                        quietly count if muestra == `si' & anio == $pre_year & `dv' == `dd' ///
                            & !missing(`yv') & het_`d' == `k'
                        post `PK' ("`pl'") ("`d'") (`si') (`dd') (`k') ("`lab'") (1) (r(N) / `ntot')
                        post `PK' ("`pl'") ("`d'") (`si') (`dd') (`k') ("`lab'") (2) (r(N))
                    }
                }

                * ---- dif-en-dif por grupo, contra cada decil --------------
                foreach c of global lo_list {
                    capture quietly reg `yv'                                          ///
                        ib${pre_year}.anio##ib`c'.`dv'##ib`base'.het_`d'              ///
                        if muestra == `si' & inlist(`dv', `c', $hi_decile) & !missing(het_`d'), ///
                        vce(cluster id)
                    if _rc {
                        di as error "  no estimable: `s' | `pl' | `d' | D`c'"
                        continue
                    }
                    tempvar es
                    quietly gen byte `es' = e(sample)
                    foreach y of global post_years {
                        local line ""
                        foreach k of local levs {
                            local lab : label (het_`d') `k'
                            if `k' == `base' capture quietly lincom `y'.anio#${hi_decile}.`dv'
                            else capture quietly lincom `y'.anio#${hi_decile}.`dv' + ///
                                                         `y'.anio#${hi_decile}.`dv'#`k'.het_`d'
                            if !_rc {
                                post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (1) (r(estimate))
                                post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (2) (r(se))
                                post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (3) ///
                                    (2*ttail(r(df), abs(r(estimate)/r(se))))
                                local _b : display %7.4f r(estimate)
                                local line "`line'  `lab' `_b'"
                            }
                            if `k' != `base' {
                                capture quietly lincom `y'.anio#${hi_decile}.`dv'#`k'.het_`d'
                                if !_rc {
                                    post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (4) (r(estimate))
                                    post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (5) (r(se))
                                    post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (6) ///
                                        (2*ttail(r(df), abs(r(estimate)/r(se))))
                                }
                            }
                            quietly count if `es' & het_`d' == `k'
                            post `PH' ("`pl'") ("`d'") (`si') (`c') (`y') (`k') ("`lab'") (7) (r(N))
                        }
                        di as text "  `s' | `pl' | D$hi_decile vs D`c' | `y':`line'"
                    }
                    drop `es'
                }
            }
        }
    }
}
postclose `PH'
postclose `PK'
capture log close movlog

* ---- 12.1 Excel -------------------------------------------------------------

use "$work/${fstem}_het.dta", clear
label define het_stat 1 "coef (dif-en-dif del grupo)" 2 "EE" 3 "p"          ///
                      4 "dif vs grupo base: coef" 5 "dif vs grupo base: EE"  ///
                      6 "dif vs grupo base: p" 7 "N obs del grupo", replace
label values stat het_stat
label define muestra_lb 1 "unbal" 2 "bal", replace
label values muestra muestra_lb
quietly reshape wide value, i(dim muestra contraste anio nivel stat) j(pair) string
rename value* *
gen str12 comparacion = "D$hi_decile vs D" + string(contraste)
rename nivel_lab grupo
capture order dim muestra comparacion contraste anio nivel grupo stat $PAIRLAB
sort dim muestra contraste anio nivel stat
drop contraste
local primera = 1
foreach d of local dims {
    preserve
        quietly keep if dim == "`d'"
        drop dim
        if `primera' {
            export excel using "$out/tablas/A6_heterogeneidad_${shock}.xlsx", ///
                sheet("`d'") firstrow(variables) replace
            local primera = 0
        }
        else export excel using "$out/tablas/A6_heterogeneidad_${shock}.xlsx", ///
                sheet("`d'", replace) firstrow(variables)
    restore
}

use "$work/${fstem}_het_comp.dta", clear
label define hetc_stat 1 "share del grupo en el decil" 2 "N obs", replace
label values stat hetc_stat
label define muestra_lb 1 "unbal" 2 "bal", replace
label values muestra muestra_lb
quietly reshape wide value, i(dim muestra decil nivel stat) j(pair) string
rename value* *
rename nivel_lab grupo
capture order dim muestra decil nivel grupo stat $PAIRLAB
sort dim muestra decil nivel stat
export excel using "$out/tablas/A6_heterogeneidad_${shock}.xlsx", ///
    sheet("composicion", replace) firstrow(variables)

putexcel set "$out/tablas/A6_heterogeneidad_${shock}.xlsx", sheet("notas") modify
putexcel A1  = "(6) Heterogeneidad del dif-en-dif (1) -- $shock_lab"
putexcel A3  = "Resultado: $main_lab. Dif-en-dif D$hi_decile vs cada decil de comparacion, anio base $pre_year, EE agrupados por persona."
putexcel A4  = "Una regresion por dimension x muestra x columna x comparacion: y = anio x decil x grupo (totalmente interactuada)."
putexcel A5  = "coef = dif-en-dif dentro del grupo. dif vs grupo base = diferencia con el grupo de codigo mas bajo (test de heterogeneidad)."
putexcel A6  = "composicion: peso de cada grupo dentro de cada decil de origen en $pre_year."
putexcel A7  = "Caracteristicas fijas por persona. Edad en $base_year (cortes: $het_age_cuts). Casado = estado_civil en ($het_married_codes)."
putexcel A8  = "Estado civil: el del registro civil a la fecha de extraccion, no necesariamente el de $base_year."
putexcel A9  = "Educacion: titulo mas alto en SENESCYT de tercer o cuarto nivel = universidad; tecnico/tecnologico o ninguno = no."
if "$sen_date" == "" putexcel A10 = "   Sin filtro de fecha: cuentan tambien los titulos obtenidos despues del shock."
else                 putexcel A10 = "   Solo titulos hasta $base_year (primera fecha valida de: $sen_date)."
putexcel A11 = "Etnia: el registro civil real no tiene etnia; en los datos falsos es inventada."

di as result "Excel escrito: $out/tablas/A6_heterogeneidad_${shock}.xlsx"

}
}



* ============================================================================
* 13. RESUMEN DE SALIDAS
* ============================================================================

di as result _n "===================================================================="
di as result    " LISTO -- $shock_lab"
di as result    "===================================================================="
di as text "Muestra: deciles de ORIGEN $keep_dec_lo-$keep_dec_hi (rangos calculados sobre la poblacion completa)"
if $two_period == 1 di as text "Modo dos anios: $pre_year vs $post_years -> subcarpeta /dos_anios"
if $wins_p > 0      di as text "Winsorizacion: p$wins_p -> subcarpeta /winsorized"
if $do_lee == 1     di as text "IC de Imbens-Manski al `=100*(1-$im_alpha)'%, EE de las cotas: $im_se"
di as text "Datos intermedios (permanentes):"
di as text "  $work/${fstem}_long.dta       panel persona-anio, ingreso real"
di as text "  $work/${fstem}_t0.dta         niveles de ingreso en t0, por persona"
di as text "  $work/${fstem}_analysis.dta   dataset de analisis (apilado por muestra)"
di as text "  $work/${fstem}_slim_*.dta     archivos adelgazados para descriptivos"
di as text "Excel (filas = muestra x anio ; columnas = variable x definicion de t0):"
di as text "  $out/tablas/D_resumen_por_anio_${shock}.xlsx"
di as text "  $out/tablas/D_g_por_decil_${shock}.xlsx"
di as text "  $out/tablas/A1_crecimiento_${shock}.xlsx"
di as text "  $out/tablas/A2_movilidad_${shock}.xlsx"
di as text "  $out/tablas/A3_permanencia_${shock}.xlsx"
di as text "  $out/tablas/A4_lee_bounds_${shock}.xlsx    (solo muestra no balanceada)"
di as text "     una hoja por outcome, en 7 bloques de filas:"
di as text "     cota_lo cota_hi EE_lo EE_hi IC_inf IC_sup c_alpha"
if $do_leavers == 1 di as text "  $out/tablas/A5_desercion_${shock}.xlsx     (los que se van: comparacion, escenarios, peor caso)"
if $do_het == 1     di as text "  $out/tablas/A6_heterogeneidad_${shock}.xlsx (dif-en-dif por grupos: edad, sexo, civil, educ, etnia)"
di as text "  A1: hoja did_vs_deciles = D$hi_decile contra cada decil de $lo_list"
di as text "Logs de regresiones: $out/regresiones/"

capture log close movlog

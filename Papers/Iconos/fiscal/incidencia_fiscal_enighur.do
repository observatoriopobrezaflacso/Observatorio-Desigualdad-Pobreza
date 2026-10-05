*==============================================================================*
* INCIDENCIA FISCAL CON LA ENIGHUR 2024-2025
*
* Mide cuánto cambian el nivel y la distribución del ingreso por efecto de los
* impuestos, las transferencias y los subsidios, con la metodología Commitment
* to Equity (CEQ; Lustig, 2018): el ingreso se sigue desde antes hasta después
* de la acción fiscal y en cada paso se calcula el Gini y la contribución de
* cada instrumento.
*
* Conceptos de ingreso (mensuales, del hogar, luego per cápita):
*   Mercado     = ingreso corriente total del INEC + impuestos y aportes que el
*                 INEC ya descuenta - transferencias monetarias públicas.
*                 Incluye las pensiones contributivas (tratadas como ingreso
*                 diferido, el escenario base de CEQ) y los componentes no
*                 monetarios del INEC (alquiler imputado, autoconsumo, salario
*                 en especie, regalos).
*   Disponible  = Mercado - impuestos directos - aportes a la seguridad social
*                 + transferencias monetarias públicas.
*   Consumible  = Disponible - IVA - ICE + subsidios (GLP, electricidad, diésel).
*   Final parcial = Consumible + transferencias en especie que los propios
*                 hogares valoran en la encuesta (alimentación escolar, textos,
*                 uniformes, desarrollo infantil, micronutrientes, visitas de
*                 salud, vitaminas prenatales, incentivos de vivienda). NO
*                 incluye el costo de la educación ni de la salud públicas.
*
* Datos: bases de trabajo de la ENIGHUR 2024-2025 (INEC), levantada del 5 de
* noviembre de 2024 al 1 de noviembre de 2025. En las bases todos los montos
* son mensuales (el BDH aparece en USD 55, el bono Joaquín Gallegos Lara en
* USD 240); los valores en especie de la sección de personas son anuales.
*
* Salida: $fis_out/incidencia_fiscal_enighur.xlsx
*==============================================================================*

clear all
set more off
set varabbrev off

*------------------------------------------------------------------------------
* 0. RUTAS Y PARÁMETROS
*------------------------------------------------------------------------------

if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}
* Bases de la ENIGHUR: se usan desde Bases/ENIGHUR del Drive si están ahí; si
* no, desde la carpeta de descarga.
if "$enighur" == "" {
    global enighur "$gd/Bases/ENIGHUR/2024-2025/Bases de trabajo/SPSS"
    capture confirm file "$enighur/ENIGHUR2025_INGRESOS_H.sav"
    if _rc global enighur "/Users/santiago/Downloads/Bases_de_datos_SPSS_enighur_v1/Bases de trabajo/SPSS"
}
if "$fis_out" == "" global fis_out "$gd/Papers/Íconos/outputs/incidencia_fiscal"
cap mkdir "$fis_out"
local tmp "`c(tmpdir)'"

* IVA: 15% desde el 1 de abril de 2024 (todo el levantamiento).
global iva = 0.15

* ICE como proporción del precio al consumidor (que ya incluye ICE e IVA).
* Tarifas 2025, Resolución SRI NAC-DGERCGC24-00000043:
*   cigarrillos USD 0,16 por unidad -> una cajetilla de 20 (USD 3,20 de ICE)
*     de unos USD 5,50 = 0,55 del precio;
*   cerveza industrial USD 13,48 por litro de alcohol puro -> a 4,2% de
*     alcohol, USD 0,57 por litro de unos USD 2,10 = 0,27;
*   otras bebidas alcohólicas USD 10,30 por litro de alcohol puro (más 75% ad
*     valorem sobre el precio ex fábrica que supere el umbral) -> destilados
*     0,20; vino y otras 0,15;
*   bebidas azucaradas USD 0,18 por 100 g de azúcar -> gaseosas (unos 100 g
*     por litro, USD 0,18 de unos USD 1,20) 0,15; jugos artificiales y néctares
*     0,10; bebidas hidratantes 0,06; energizantes (10% ad valorem) 0,08;
*   vehículos nuevos (5% a 35% según el precio) 0,07; perfumes (20% ad
*     valorem) 0,145.
global ice_cig  = 0.55
global ice_cerv = 0.27
global ice_dest = 0.20
global ice_vino = 0.15
global ice_gas  = 0.15
global ice_jugo = 0.10
global ice_hidr = 0.06
global ice_ener = 0.08
global ice_auto = 0.07
global ice_perf = 0.145

* Lugares de compra donde no se cobra IVA ni ICE (compra informal): mercados,
* ferias libres, puestos y ambulantes de comida, vendedores ambulantes y
* personas particulares (códigos de GD210).
global informal "8, 9, 41, 65, 70"

* GLP de uso doméstico: precio oficial USD 1,65 por cilindro de 15 kg y costo
* referencial de USD 12,39 (EP Petroecuador) -> subsidio de USD 10,74 por
* cilindro. En la encuesta el hogar reporta cuánto pagó en el mes: la mediana
* es USD 3,25 porque la mayoría compra a domicilio. Un pago de hasta USD 4 se
* toma como un cilindro; los pagos mayores, como pago / 3,25 cilindros.
global glp_subs   = 10.74
global glp_precio = 3.25
global glp_uno    = 4

* Electricidad, subsidios pagados por el Estado (ARCONEL, Informe
* INF-DRETSE-2024-044, proyección 2025):
*   Tarifa de la Dignidad: consumos de hasta 110 kWh-mes en la Sierra y 130 en
*     la Costa, Amazonía y Galápagos; subsidio unitario medio de 3,42 ¢/kWh;
*     USD 41,25 millones al año. La simulación con los kWh de la encuesta da
*     unos USD 62 millones (buena parte de los kWh son imputados y no se ve el
*     historial de 12 meses que exige la tarifa), así que se ajusta al monto
*     administrativo manteniendo quién la recibe.
*   Ley de Personas Adultas Mayores: 50% del consumo hasta 138 kWh; USD 24,76
*     millones al año. La encuesta no dice a nombre de quién está la cuenta,
*     así que se simula para los hogares con un mayor de 65 años y se ajusta al
*     monto administrativo.
*   Quedan fuera la rebaja por discapacidad (USD 17,16 millones) y el
*   incentivo de la cocción por inducción (USD 28,96 millones).
global ele_td_unit   = 0.0342
global ele_td_mes    = 41.25e6 / 12
global ele_td_sierra = 110
global ele_td_resto  = 130
global ele_precio    = 0.092
global ele_lopam_kwh = 138
global ele_lopam_mes = 24.76e6 / 12

* Diésel: precio de USD 1,797 por galón hasta el 12 de septiembre de 2025,
* cuando pasó a USD 2,80 (Decreto 126). Se toma un subsidio de USD 1,00 por
* galón hasta la semana 44 del levantamiento (semana 1 = 5 de noviembre de
* 2024). Las gasolinas Extra y Ecopaís no tienen subsidio neto en el período:
* con el sistema de bandas la cuenta de importación de gasolinas tuvo un saldo
* positivo de USD 267 millones en 2025.
global diesel_subs   = 1.00
global diesel_precio = 1.797
global diesel_semana = 44

*------------------------------------------------------------------------------
* 1. INGRESOS, IMPUESTOS DIRECTOS Y TRANSFERENCIAS MONETARIAS (HOGAR)
*------------------------------------------------------------------------------

import spss using "$enighur/ENIGHUR2025_INGRESOS_H.sav", clear
keep Identif_hog Fexp NUMPERS AREA REGION PROVINCIA SEMANA ///
     i2001001 i2001002 i2009001 i2009002 i2009003 i2009004 i2009005 ///
     i1744001 i1744002 i1744003 i1744004 i1744005 i1744006 i1744007 ///
     i1744008 i1744009 i1744010 i1744011 i1744015 ///
     i1746004 i1746005 i1746006 i1746007 i1746008 i1746009 i1746010
foreach v of varlist i* {
    replace `v' = 0 if `v' >= . | `v' < 0
}

* Impuestos directos. El INEC ya descuenta del ingreso el impuesto a la renta
* (retenido y pagado directamente) y los aportes de los asalariados; el
* predial, la alcabala y los impuestos a vehículos y herencias no los
* descuenta (van como gasto de no consumo).
gen double t_ir     = i2001002 + i2009002
gen double t_ss_asa = i2001001
gen double t_otros  = i2009001 + i2009003 + i2009004 + i2009005

* Transferencias monetarias públicas. Las de la serie 1744 están dentro de
* las transferencias corrientes del INEC; las de calamidad y desastres (1746)
* no forman parte del ingreso corriente y se agregan aquí.
gen double tr_bdh   = i1744002 + i1744003                       // BDH y BDH con componente variable
gen double tr_pens  = i1744004 + i1744005 + i1744006 + i1744007 // MMA, PAM, PTUV, discapacidad
gen double tr_inf   = i1744008 + i1744010                       // 1000 días / infancia futuro, orfandad
gen double tr_jgl   = i1744009                                  // Joaquín Gallegos Lara
gen double tr_becas = i1744011 + i1746004 + i1746005             // becas y bonos de contingencia
gen double tr_otras = i1744015                                  // otras transferencias del Estado (sin detalle)
gen double tr_inec  = i1744002 + i1744003 + i1744004 + i1744005 + i1744006 + ///
                      i1744007 + i1744008 + i1744009 + i1744010 + i1744011 + i1744015
gen double pens_contr = i1744001                                // pensiones contributivas
gen double esp_viv  = i1746006 + i1746007 + i1746008 + i1746009 + i1746010

keep Identif_hog Fexp NUMPERS AREA REGION PROVINCIA SEMANA t_* tr_* pens_contr esp_viv
tempfile ing
save `ing'

import spss using "$enighur/ENIGHUR2025_HOGARES_AGREGADOS.SAV", clear
keep Identif_hog ing_cor_tot alq_imp
replace alq_imp = 0 if alq_imp >= .
merge 1:1 Identif_hog using `ing', assert(3) nogen
save `ing', replace

*------------------------------------------------------------------------------
* 2. PERSONAS: APORTES DE INDEPENDIENTES, EDAD Y TRANSFERENCIAS EN ESPECIE
*------------------------------------------------------------------------------

import spss using "$enighur/ENIGHUR2025_PERSONAS_INGRESOS.sav", clear
keep Identif_hog P04 i2002002 i2002010 P23_3 P24_3 P25_2 P26_2 P27_3 P29_3 P30_3 P36_3
foreach v of varlist i2002002 P23_3-P36_3 {
    replace `v' = 0 if `v' >= . | `v' < 0
}
* Los aportes a la seguridad social del negocio entran como gasto del negocio
* y el ingreso neto del patrono o cuenta propia se multiplica por la parte del
* negocio que le pertenece (2002010, en porcentaje).
gen double parte = cond(i2002010 > 1 & i2002010 <= 100, i2002010 / 100, ///
                   cond(i2002010 > 0 & i2002010 <= 1, i2002010, 1))
gen double t_ss_ind = i2002002 * parte
gen byte mayor65 = P04 >= 65 & P04 < .
* Valores en especie: anuales en la encuesta, se pasan a mensuales.
gen double esp_educ  = (P25_2 + P26_2 + P27_3) / 12            // textos, uniformes, alimentación escolar
gen double esp_infan = (P23_3 + P24_3 + P29_3) / 12            // micronutrientes, desarrollo infantil, educación alimentaria
gen double esp_salud = (P30_3 + P36_3) / 12                    // visitas de salud, vitaminas prenatales
collapse (sum) t_ss_ind esp_educ esp_infan esp_salud (max) mayor65, by(Identif_hog)
merge 1:1 Identif_hog using `ing', assert(2 3) nogen
foreach v in t_ss_ind esp_educ esp_infan esp_salud mayor65 {
    replace `v' = 0 if `v' >= .
}
save `ing', replace

*------------------------------------------------------------------------------
* 3. GASTO: IVA, ICE Y SUBSIDIOS
*------------------------------------------------------------------------------

import spss using "$enighur/ENIGHUR2025_GASTOS_V.SAV", clear
keep Identif_hog REGION SEMANA codccif descripción cantidad adquirio forma valor_monetario
keep if valor_monetario > 0 & valor_monetario < .
gen str5 c5 = substr(codccif, 1, 5)
gen str4 c4 = substr(codccif, 1, 4)
gen str3 c3 = substr(codccif, 1, 3)
gen str2 c2 = substr(codccif, 1, 2)
gen d = ustrlower(descripción)
gen byte informal = inlist(adquirio, $informal)

*--- 3a. Tarifa de IVA por producto (1 = 15%, 0 = tarifa 0%) -----------------
* Arts. 55 y 56 de la Ley de Régimen Tributario Interno. Por defecto 15%.
gen byte grav = 1

* Alimentos en estado natural o de la canasta básica (tarifa 0%)
replace grav = 0 if inlist(c5, "01111", "01112", "01115", "01121", "01122", "01123", "01124", "01125")
replace grav = 0 if inlist(c5, "01131", "01132", "01134", "01135", "01137", "01141", "01142", "01145", "01148")
replace grav = 0 if inlist(c5, "01153", "01159", "01161", "01162", "01163", "01164", "01165", "01166")
replace grav = 0 if inlist(c5, "01171", "01172", "01173", "01174", "01175", "01176", "01177", "01178")
replace grav = 0 if inlist(c5, "01181", "01194")
replace grav = 0 if c5 == "01113" & ustrregexm(d, "^pan ")                           // pan (no galletas ni pasteles)
replace grav = 0 if c5 == "01114" & ustrregexm(d, "avena")
replace grav = 0 if c5 == "01119" & ustrregexm(d, "^mote")
replace grav = 0 if c5 == "01133" & ustrregexm(d, "atún|sardina|macarela|trucha") & !ustrregexm(d, "apanad|marinad")
replace grav = 0 if c5 == "01143" & ustrregexm(d, "leche en polvo")
replace grav = 0 if c5 == "01146" & ustrregexm(d, "yogur")
replace grav = 0 if c5 == "01151" & !ustrregexm(d, "oliva")                         // aceites, excepto oliva
replace grav = 0 if c5 == "01168" & !ustrregexm(d, "salad|tostad|confitad")
replace grav = 0 if c5 == "01179" & ustrregexm(d, "harina")
replace grav = 0 if c5 == "01183" & ustrregexm(d, "miel de abeja")
replace grav = 0 if c5 == "01192" & ustrregexm(d, "fórmula|maternizada")            // leche maternizada
replace grav = 0 if c5 == "01193" & ustrregexm(d, "^sal( |$)")
replace grav = 0 if c4 == "0122" & ustrregexm(d, "café en grano")
replace grav = 0 if c4 == "0123" & ustrregexm(d, "sin procesar")
replace grav = 0 if c4 == "0240"                                                   // drogas: sin impuestos

* Vivienda y servicios básicos
replace grav = 0 if c3 == "041" | c3 == "042"                                      // arriendos
replace grav = 0 if inlist(c4, "0441", "0442", "0443", "0444")                     // agua, basura, alcantarillado, alícuotas
replace grav = 0 if c4 == "0451" | c4 == "0454"                                    // electricidad, leña y carbón
replace grav = 0 if substr(codccif, 1, 5) == "05621"                               // sueldos del servicio doméstico
* Salud
replace grav = 0 if c4 == "0611" | inlist(c3, "062", "063", "064")                  // medicinas y servicios de salud
replace grav = 0 if c4 == "1312" & ustrregexm(d, "toallas higiénicas|tampones|copas menstruales|pañales desechables para bebé")
* Transporte
replace grav = 0 if c4 == "0714"
replace grav = 0 if inlist(c4, "0731", "0732", "0734", "0735", "0749")              // pasajeros terrestre y acuático, carga
replace grav = 0 if c4 == "0724" & ustrregexm(d, "peaje")
* Recreación, educación, seguros y otros
replace grav = 0 if inlist(c4, "0931", "0947", "0971", "0972")                     // plantas, loterías, libros, prensa
replace grav = 0 if c2 == "10"                                                     // educación
replace grav = 0 if inlist(c4, "1211", "1212") | c3 == "122"                        // seguros de vida y salud, servicios financieros
replace grav = 0 if c4 == "1330"                                                   // guarderías y hogares de ancianos
replace grav = 0 if c4 == "1390" & ustrregexm(d, "mesada|perdidos o robados|fúnebre|funeral|religios|limosna")

*--- 3b. ICE (proporción del precio) -----------------------------------------
gen double ice_t = 0
replace ice_t = $ice_cig  if substr(codccif, 1, 3) == "023"
replace ice_t = $ice_cerv if c5 == "02130" & !ustrregexm(d, "sin alcohol")
replace ice_t = $ice_dest if c4 == "0211" & !ustrregexm(d, "granel")
replace ice_t = $ice_vino if (c4 == "0212" | c4 == "0219") & !ustrregexm(d, "sin alcohol")
replace ice_t = $ice_gas  if c5 == "01260" & ustrregexm(d, "cola")
replace ice_t = $ice_jugo if (c5 == "01260" & ustrregexm(d, "malta")) | ///
                             (c5 == "01210" & ustrregexm(d, "artificial|néctar|en polvo"))
replace ice_t = $ice_hidr if c5 == "01290" & ustrregexm(d, "hidratante")
replace ice_t = $ice_ener if c5 == "01290" & ustrregexm(d, "energizante")
replace ice_t = $ice_auto if c4 == "0711" & ustrregexm(d, "nuev")
replace ice_t = $ice_perf if c4 == "1312" & ustrregexm(d, "perfume|colonia")

* Lo comprado en mercados, ferias o a particulares no paga IVA ni ICE.
gen double iva    = valor_monetario * grav * $iva / (1 + $iva) * (1 - informal)
gen double iva_sf = valor_monetario * grav * $iva / (1 + $iva)                     // sin ajuste por informalidad
gen double ice    = valor_monetario * ice_t * (1 - informal)

*--- 3c. Subsidios ----------------------------------------------------------
gen byte es_glp = descripción == "Gas doméstico en cilindros"
gen double cil  = cond(valor_monetario <= $glp_uno, 1, valor_monetario / $glp_precio) if es_glp
gen double s_glp = cil * $glp_subs if es_glp
gen double s_diesel = valor_monetario * $diesel_subs / $diesel_precio ///
    if descripción == "Diésel para vehículos" & SEMANA <= $diesel_semana
gen byte es_ele = descripción == "Consumo eléctrico, vivienda principal"
gen double kwh_rep = cantidad if es_ele & cantidad > 0 & cantidad < .
gen double gasto_ele = valor_monetario if es_ele

collapse (sum) iva iva_sf ice s_glp s_diesel cil gasto_ele (max) kwh_rep, by(Identif_hog)
merge 1:1 Identif_hog using `ing', keep(2 3) nogen
foreach v in iva iva_sf ice s_glp s_diesel cil gasto_ele {
    replace `v' = 0 if `v' >= .
}

*--- 3d. Electricidad: kWh y subsidios ----------------------------------------
* Sólo uno de cada cuatro hogares reporta los kWh. Para el resto se imputan
* con la relación entre el pago y el consumo de los que sí los reportan (con
* un precio implícito entre 3 y 30 centavos por kWh).
gen double pk = gasto_ele / kwh_rep if kwh_rep > 0 & gasto_ele > 0
gen double lk = ln(kwh_rep) if inrange(pk, 0.03, 0.30)
gen double lg = ln(gasto_ele) if gasto_ele > 0
gen byte sierra = REGION == "Sierra"
regress lk lg i.AREA sierra [aw=Fexp]
predict double lk_hat if gasto_ele > 0, xb
gen double kwh = cond(inrange(pk, 0.03, 0.30), kwh_rep, exp(lk_hat)) if gasto_ele > 0
replace kwh = 0 if kwh >= .
gen double lim_td = cond(sierra, $ele_td_sierra, $ele_td_resto)
gen double s_ele_td = cond(kwh > 0 & kwh <= lim_td, kwh * $ele_td_unit, 0)
quietly summarize s_ele_td [iw=Fexp]
di as txt "Tarifa de la Dignidad simulada, al año (USD millones): " %6.1f r(sum) * 12 / 1e6 "  (ARCONEL: 41,25)"
replace s_ele_td = s_ele_td * $ele_td_mes / r(sum)                                   // ajuste al monto de ARCONEL
gen double s_ele_am = cond(mayor65 & kwh > 0, 0.5 * min(kwh, $ele_lopam_kwh) * $ele_precio, 0)
quietly summarize s_ele_am [iw=Fexp]
replace s_ele_am = s_ele_am * $ele_lopam_mes / r(sum)                                // ajuste al monto de ARCONEL
gen double s_ele = s_ele_td + s_ele_am
drop pk lk lg lk_hat

*------------------------------------------------------------------------------
* 4. CONCEPTOS DE INGRESO
*------------------------------------------------------------------------------

gen double t_ss    = t_ss_asa + t_ss_ind
gen double t_dir   = t_ir + t_ss + t_otros
gen double tr_mon  = tr_bdh + tr_pens + tr_inf + tr_jgl + tr_becas + tr_otras
gen double t_ind   = iva + ice
gen double s_ind   = s_glp + s_ele + s_diesel
gen double esp     = esp_educ + esp_infan + esp_salud + esp_viv

gen double y_merc  = ing_cor_tot + t_ir + t_ss - tr_inec
gen double y_disp  = y_merc - t_dir + tr_mon
gen double y_cons  = y_disp - t_ind + s_ind
gen double y_final = y_cons + esp
* Sensibilidades: pensiones contributivas como transferencia del Estado, IVA
* sin ajuste por informalidad, e ingreso sin alquiler imputado (más cercano al
* concepto de la ENEMDU).
gen double y_merc_pt = y_merc - pens_contr
gen double y_cons_sf = y_cons + iva - iva_sf

gen double w = Fexp * NUMPERS
foreach v of varlist y_* t_* tr_* s_* esp* iva iva_sf ice pens_contr alq_imp {
    gen double `v'_pc = `v' / NUMPERS
}
gen double y_merc_sa_pc = y_merc_pc - alq_imp_pc
gen double y_disp_sa_pc = y_disp_pc - alq_imp_pc
gen double y_cons_sa_pc = y_cons_pc - alq_imp_pc
xtile dec = y_merc_pc [aw=w], nquantiles(10)

compress
save "`tmp'/incidencia_fiscal_hogares.dta", replace

*------------------------------------------------------------------------------
* 5. INDICADORES
*------------------------------------------------------------------------------

*--- 5a. Gini de cada concepto y efecto redistributivo -----------------------
tempname G
postfile `G' str60 concepto double gini str60 nota using "`tmp'/fis_gini.dta", replace
local conc "y_merc y_disp y_cons y_final"
local nom_y_merc  "Ingreso de mercado"
local nom_y_disp  "Ingreso disponible"
local nom_y_cons  "Ingreso consumible"
local nom_y_final "Ingreso final (parcial)"
foreach c of local conc {
    quietly sgini `c'_pc [aw=w]
    post `G' ("`nom_`c''") (r(coeff)) ("")
    local g_`c' = r(coeff)
}
quietly sgini y_merc_pt_pc [aw=w]
post `G' ("Mercado, pensiones como transferencia") (r(coeff)) ("sensibilidad")
quietly sgini y_cons_sf_pc [aw=w]
post `G' ("Consumible, IVA sin ajuste por informalidad") (r(coeff)) ("sensibilidad")
foreach c in y_merc_sa y_disp_sa y_cons_sa {
    quietly sgini `c'_pc [aw=w]
    post `G' ("`c' (sin alquiler imputado)") (r(coeff)) ("sensibilidad")
}
postclose `G'

*--- 5b. Contribución marginal y progresividad de cada instrumento ------------
* Contribución marginal = Gini del concepto sin el instrumento - Gini del
* concepto con él (positivo = reduce la desigualdad). Se mide en el concepto
* donde entra el instrumento. Kakwani = coeficiente de concentración del
* instrumento (ordenando por ingreso de mercado) - Gini de mercado; en los
* impuestos, positivo = progresivo; en las transferencias, negativo = la
* transferencia se concentra en los más pobres más que el ingreso.
tempname M
postfile `M' str60 instrumento str12 tipo str30 concepto double(monto_anual_mm pct_ymerc cm cc kakwani) ///
    using "`tmp'/fis_instr.dta", replace
local impuestos "t_ir t_ss t_otros iva ice"
local beneficios "tr_bdh tr_pens tr_inf tr_jgl tr_becas tr_otras s_glp s_ele s_diesel esp_educ esp_infan esp_salud esp_viv"
local nom_t_ir     "Impuesto a la renta"
local nom_t_ss     "Aportes a la seguridad social"
local nom_t_otros  "Predial, alcabala, vehículos, herencias"
local nom_iva      "IVA"
local nom_ice      "ICE"
local nom_tr_bdh   "Bono de Desarrollo Humano"
local nom_tr_pens  "Pensiones no contributivas"
local nom_tr_inf   "Bonos de infancia (1000 días, orfandad)"
local nom_tr_jgl   "Bono Joaquín Gallegos Lara"
local nom_tr_becas "Becas y bonos de contingencia"
local nom_tr_otras "Otras transferencias del Estado (sin detalle)"
local nom_s_glp    "Subsidio al GLP"
local nom_s_ele    "Subsidios eléctricos"
local nom_s_diesel "Subsidio al diésel"
local nom_esp_educ "En especie: alimentación, textos, uniformes"
local nom_esp_infan "En especie: desarrollo infantil, nutrición"
local nom_esp_salud "En especie: visitas de salud, vitaminas"
local nom_esp_viv  "En especie: incentivos de vivienda"
local nom_esp      "Transferencias en especie (total)"
quietly summarize y_merc [iw=Fexp]
local tot_merc = r(sum)
foreach k of local impuestos {
    local c = cond(inlist("`k'", "iva", "ice"), "y_cons", "y_disp")
    tempvar sin
    quietly gen double `sin' = `c'_pc + `k'_pc
    quietly sgini `sin' [aw=w]
    local cm = r(coeff) - `g_`c''
    quietly sgini `k'_pc [aw=w], sortvar(y_merc_pc)
    local cc = r(coeff)
    quietly summarize `k' [iw=Fexp]
    post `M' ("`nom_`k''") ("impuesto") ("`nom_`c''") (r(sum) * 12 / 1e6) (100 * r(sum) / `tot_merc') ///
        (`cm') (`cc') (`cc' - `g_y_merc')
    drop `sin'
}
foreach k of local beneficios {
    local c = cond(substr("`k'", 1, 2) == "tr", "y_disp", cond(substr("`k'", 1, 2) == "s_", "y_cons", "y_final"))
    tempvar sin
    quietly gen double `sin' = `c'_pc - `k'_pc
    quietly sgini `sin' [aw=w]
    local cm = r(coeff) - `g_`c''
    quietly sgini `k'_pc [aw=w], sortvar(y_merc_pc)
    local cc = r(coeff)
    quietly summarize `k' [iw=Fexp]
    post `M' ("`nom_`k''") ("beneficio") ("`nom_`c''") (r(sum) * 12 / 1e6) (100 * r(sum) / `tot_merc') ///
        (`cm') (`cc') (`cc' - `g_y_merc')
    drop `sin'
}
postclose `M'

*--- 5c. Incidencia por decil de ingreso de mercado per cápita -----------------
preserve
    collapse (mean) y_merc_pc y_disp_pc y_cons_pc y_final_pc t_ir_pc t_ss_pc t_otros_pc iva_pc ice_pc ///
        tr_bdh_pc tr_pens_pc tr_inf_pc tr_jgl_pc tr_becas_pc tr_otras_pc s_glp_pc s_ele_pc s_diesel_pc esp_pc ///
        (rawsum) personas = w [aw=w], by(dec)
    foreach v of varlist t_ir_pc-esp_pc {
        gen double pct_`v' = 100 * `v' / y_merc_pc
    }
    gen double pct_cambio_disp = 100 * (y_disp_pc / y_merc_pc - 1)
    gen double pct_cambio_cons = 100 * (y_cons_pc / y_merc_pc - 1)
    gen double pct_cambio_final = 100 * (y_final_pc / y_merc_pc - 1)
    label var dec        "Decil de ingreso de mercado per cápita"
    label var personas   "Personas"
    label var y_merc_pc  "Ingreso de mercado per cápita (USD/mes)"
    label var y_disp_pc  "Ingreso disponible per cápita"
    label var y_cons_pc  "Ingreso consumible per cápita"
    label var y_final_pc "Ingreso final (parcial) per cápita"
    foreach k in t_ir t_ss t_otros iva ice tr_bdh tr_pens tr_inf tr_jgl tr_becas tr_otras s_glp s_ele s_diesel esp {
        label var `k'_pc     "`nom_`k'' (USD/mes per cápita)"
        label var pct_`k'_pc "`nom_`k'' (% del ingreso de mercado)"
    }
    label var pct_cambio_disp  "Disponible vs mercado (%)"
    label var pct_cambio_cons  "Consumible vs mercado (%)"
    label var pct_cambio_final "Final vs mercado (%)"
    save "`tmp'/fis_decil.dta", replace
restore

*--- 5d. Chequeos -----------------------------------------------------------
quietly summarize cil [iw=Fexp]
di as txt "Cilindros de GLP al año (millones): " %6.1f r(sum) * 12 / 1e6
quietly count if s_ele_td > 0
quietly summarize Fexp if s_ele_td > 0
di as txt "Hogares con Tarifa de la Dignidad (millones): " %5.2f r(sum) / 1e6 "  (ARCONEL: 1,7 millones de beneficiarios)"

*------------------------------------------------------------------------------
* 6. LIBRO DE RESULTADOS
*------------------------------------------------------------------------------

local libro "`tmp'/incidencia_fiscal_enighur.xlsx"
cap erase "`libro'"

use "`tmp'/fis_gini.dta", clear
gen double efecto_redistributivo = gini[1] - gini if _n <= 4
label var efecto_redistributivo "Gini de mercado - Gini del concepto"
label var concepto "Concepto de ingreso"
label var gini "Gini"
label var nota "Nota"
format gini efecto_redistributivo %9.4f
export excel using "`libro'", sheet("gini") firstrow(varlabels) replace

use "`tmp'/fis_instr.dta", clear
label var monto_anual_mm "Monto anual (USD millones)"
label var pct_ymerc      "% del ingreso de mercado (3,2 = 3,2%)"
label var cm             "Contribución marginal al Gini"
label var cc             "Coeficiente de concentración"
label var kakwani        "Kakwani (CC - Gini de mercado)"
format monto_anual_mm %12.1fc
format pct_ymerc %9.2f
format cm %9.4f
format cc kakwani %9.3f
export excel using "`libro'", sheet("instrumentos") firstrow(varlabels) sheetreplace

use "`tmp'/fis_decil.dta", clear
format personas %12.0fc
format y_merc_pc-pct_cambio_final %9.2f
export excel using "`libro'", sheet("deciles") firstrow(varlabels) sheetreplace

clear
input str60 parametro str40 valor str140 fuente
"IVA"                              "15%"          "Vigente desde el 1 de abril de 2024"
"ICE cigarrillos"                  "0,55 del precio" "USD 0,16 por unidad (SRI NAC-DGERCGC24-00000043)"
"ICE cerveza"                      "0,27 del precio" "USD 13,48 por litro de alcohol puro"
"ICE destilados / vino"            "0,20 / 0,15"  "USD 10,30 por litro de alcohol puro + ad valorem"
"ICE gaseosas / jugos"             "0,15 / 0,10"  "USD 0,18 por 100 g de azúcar"
"ICE vehículos nuevos / perfumes"  "0,07 / 0,145" "5%-35% según precio / 20% ad valorem"
"Compra informal (sin IVA ni ICE)" "GD210 = 8, 9, 41, 65, 70" "Mercados, ferias, puestos, ambulantes, particulares"
"Subsidio GLP"                     "USD 10,74 por cilindro" "Costo USD 12,39 - precio USD 1,65 (EP Petroecuador)"
"Tarifa de la Dignidad"            "3,42 ¢/kWh"   "ARCONEL INF-DRETSE-2024-044; <=110 kWh Sierra, <=130 resto"
"Adultos mayores (electricidad)"   "USD 24,76 MM/año" "ARCONEL; 50% hasta 138 kWh, ajustado al monto"
"Subsidio diésel"                  "USD 1,00 por galón" "Hasta el 12-sep-2025 (precio 1,797 -> 2,80)"
"Gasolinas Extra y Ecopaís"        "0"            "Saldo positivo de la cuenta de importación en 2025"
end
export excel using "`libro'", sheet("supuestos") firstrow(variables) sheetreplace

* Formatos numéricos (export excel no respeta los de más de dos decimales).
use "`tmp'/fis_instr.dta", clear
local ni = _N + 1
use "`tmp'/fis_gini.dta", clear
local ng = _N + 1
putexcel set "`libro'", sheet("gini") modify
putexcel (B2:B`ng'), nformat("0.0000")
putexcel (D2:D`ng'), nformat("0.0000")
putexcel set "`libro'", sheet("instrumentos") modify
putexcel (D2:D`ni'), nformat("#,##0.0")
putexcel (E2:E`ni'), nformat("0.00")
putexcel (F2:F`ni'), nformat("0.0000")
putexcel (G2:H`ni'), nformat("0.000")
putexcel save

copy "`libro'" "$fis_out/incidencia_fiscal_enighur.xlsx", replace
di as res "***** Incidencia fiscal: $fis_out/incidencia_fiscal_enighur.xlsx *****"

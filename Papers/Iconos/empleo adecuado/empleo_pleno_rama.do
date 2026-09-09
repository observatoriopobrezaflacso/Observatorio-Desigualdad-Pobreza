*==============================================================================
* Educación superior y empleo adecuado por rama de actividad
* ENEMDU (INEC) 1992, 1999, 2001, 2010, 2011 y 2024 — ramas CIIU 4.0 homogeneizadas
*
*   1. Parámetros y utilidades      4. Base rama x año
*   2. Umbral salarial (SBU)        5. Crecimiento del empleo (pares de años)
*   3. Empleo adecuado armonizado   6. Educación y empleo adecuado (por año)
*                                   7. Salidas
*
*------------------------------------------------------------------------------
* CAMBIOS RESPECTO DE LA VERSIÓN ANTERIOR
*
* (a) Se extiende el análisis a la década de 1990 (1992 y 1999, y el par
*     1992-1999). Antes el archivo cubría sólo 2001, 2010, 2011 y 2024.
*
* (b) El empleo adecuado deja de leerse de la clasificación oficial de la base
*     (condact == 1) y pasa a construirse con el mismo código armonizado de
*     "empleo_adecuado_serie.do" (secciones 3.1 a 3.8 de ese archivo), que es
*     el único criterio comparable a lo largo de todo el período: ingreso
*     laboral >= SBU vigente de diciembre, y jornada >= 40 horas o, si es
*     menor, sin deseo/disponibilidad de trabajar más horas. Esto se aplica a
*     TODOS los años, no sólo a los nuevos, así que los niveles de 2001-2024
*     cambian respecto de la corrida anterior.
*
* (c) El denominador pasa a ser los ocupados de 15 años y más con rama válida
*     (antes: todo el que no fuera inactivo/menor/indeterminado). El empleo
*     adecuado armonizado sólo está definido sobre la PEA de 15+.
*
* (d) Las columnas exportadas *_pleno_* pasan a llamarse *_adec_*.
*
*------------------------------------------------------------------------------
* ADVERTENCIAS DE COMPARABILIDAD (ver los globals cav90 / cav01 / cavdol)
*
* - 1992-1999 la ENEMDU de diciembre es SÓLO URBANA (no existe la variable
*   `area`). Con filtro = 0 esos años son urbanos y 2001-2024 nacionales; para
*   una serie homogénea conviene correr el archivo con filtro = 1.
* - 1992-1999 `nivinst` tiene una única categoría "superior" (código 5): no
*   separa universitario de no universitario ni identifica posgrado. En 2001
*   `nivinst` ya distingue posgrado (6 y 7) pero sigue sin separar el superior
*   universitario del no universitario; desde 2010 `p10a` sí lo separa (9 y 10).
*   Por eso "% con superior" no es estrictamente el mismo concepto en los tres
*   bloques, y no se arman pares de crecimiento que crucen esos bloques.
* - El umbral de ingresos es nominal y en la moneda del año (sucres hasta 1999,
*   USD desde 2000). Los niveles de empleo adecuado no son comparables a través
*   de la dolarización, y dentro de los 90 la serie es volátil porque el SMV
*   nominal se movía con la inflación.
*==============================================================================

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off

*------------------------------------------------ 1. Parámetros y utilidades --
global limpias  "$gd/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global salarios "$gd/Bases/Salarios"
global root     "$gd/Papers/Íconos"

* Años comparados y pares de crecimiento. Los pares no cruzan bloques de
* definición educativa (90s / 2001 / 2010+), que no son comparables entre sí.
local anios  1992 1999 2001 2010 2011 2024
local pares  1992-1999 2001-2010 2011-2024 2001-2024

* Ramas mostradas en los gráficos de barras de crecimiento, por código CIIU 4.0:
* 1 agricultura y pesca, 3 manufactura, 6 construcción, 7 comercio,
* 9 alojamiento/comida. Son las cinco ramas de empleo masivo con presencia en
* todo el período, así que las barras son comparables entre pares de años.
global ramas_bar 1 3 6 7 9
local filtro 0                        // 0 = nacional, 1 = urbano, 2 = rural
global minobs 50                      // mínimo de casos por rama-año en las regresiones

* Opciones del empleo adecuado armonizado; mismos nombres y valores por defecto
* que en "empleo_adecuado_serie.do".
global horas_legacy   0   // 1 = horas desconocidas valen 0 (comportamiento heredado)
global ajuste_condact 1   // 1 = ajuste residual por "otro empleo no pleno/inadecuado"
scalar edadmin = 15

local ambito : word `=`filtro'+1' of nacional urbano rural
global out "$root/outputs/rama_educ/`ambito'"
cap mkdir "$root/outputs"
cap mkdir "$root/outputs/rama_educ"
cap mkdir "$out"

* Estilo común y notas al pie reutilizadas por todos los gráficos.
* Las notas deben ir en líneas cortas: Stata no las parte y una línea larga
* desplaza y recorta el resto del gráfico.
global gopts  graphregion(color(white)) plotregion(color(white)) scheme(s2color)
global fuente "Fuente: ENEMDU de diciembre (INEC), ponderada por el factor de expansión. Ámbito: `ambito'."
global defs   "Empleo adecuado armonizado: ingreso laboral >= SBU vigente y jornada >= 40h, o menor sin desear más horas."
global cav01  "En 1992-1999 y 2001 el nivel 'superior' no distingue universitario de no universitario."
global cav90  "1992-1999: muestra sólo urbana y 'superior' sin posgrado identificable."
global cavdol "El umbral es nominal y en la moneda del año: los niveles no son comparables a través de la dolarización."

* Nota de ámbito mixto: sólo aplica si se mezclan los 90 (urbanos por diseño)
* con años posteriores tomados a nivel nacional.
global cavamb ""
if `filtro' == 0 {
    foreach y of local anios {
        if `y' <= 1999 global cavamb "Ojo: 1992-1999 son urbanos por diseño y 2001-2024 nacionales. Correr con filtro = 1 para homogeneizar."
    }
}
if "${cavamb}" != "" di as error _n "ADVERTENCIA: ${cavamb}"

if `filtro' == 2 {
    foreach y of local anios {
        if `y' <= 1999 di as error "ADVERTENCIA: `y' no tiene muestra rural; el año se omitirá."
    }
}

* Exporta la figura activa en pdf/gph/png (en batch el png se obtiene del pdf)
cap program drop savefig
program define savefig
    args f
    graph export "${out}/`f'.pdf", replace
    graph save   "${out}/`f'.gph", replace
    cap graph export "${out}/`f'.png", replace width(2200)
    if _rc shell sips -s format png --resampleWidth 2200 "${out}/`f'.pdf" ///
        --out "${out}/`f'.png" > /dev/null 2>&1
end

* Dispersión ponderada por empleo + recta MCO, con la pendiente en la leyenda.
* Con la opción -compacto- omite leyenda y notas (versión para graph combine)
* y no exporta el archivo.
cap program drop fig_scatter
program define fig_scatter
    syntax varlist(min=2 max=2) [if], peso(varname) archivo(string) ///
        title(string) [ subtitle(string) xtitle(string) ytitle(string) ///
        xlab(string) ylab(string) nombre(varname) nrot(integer 5) ///
        nesq(integer 2) nota(string) cero compacto ]

    gettoken y x : varlist
    marksample touse
    markout `touse' `y' `x' `peso'

    qui reg `y' `x' [aweight=`peso'] if `touse'
    local b  = strtrim("`: di %6.2f _b[`x']'")
    local se = strtrim("`: di %6.2f _se[`x']'")
    local r2 = strtrim("`: di %5.2f e(r2)'")
    local nr = e(N)

    * Rótulos: las `nrot' observaciones de mayor peso —las que mandan en el
    * ajuste— más las `nesq' más extremas hacia la esquina superior derecha,
    * que suelen ser pequeñas pero son las que dan sentido a la pendiente.
    * La posición se adapta: centrada dentro de los círculos grandes, y a la
    * izquierda del punto en la mitad derecha del gráfico para no salirse.
    local rotulos ""
    local nrecta 2                            // nº de plot de la recta de ajuste
    if "`nombre'" != "" {
        tempvar rw xr yr resq pos etiq
        qui egen `rw' = rank(-`peso') if `touse', unique
        qui egen `xr' = rank(`x')     if `touse'      // ranking: evita que la
        qui egen `yr' = rank(`y')     if `touse'      // escala de un eje mande
        qui egen `resq' = rank(-(`xr' + `yr')) if `touse', unique
        qui clonevar `etiq' = `nombre'
        qui replace `etiq' = "" if !`touse' | (`rw' > `nrot' & `resq' > `nesq')

        qui sum `x' if `touse'
        local xmed = (r(min) + r(max))/2
        local xlo  = r(min) + 0.15*(r(max) - r(min))   // franjas donde un rótulo
        local xhi  = r(max) - 0.15*(r(max) - r(min))   // centrado se saldría
        qui sum `peso' if `touse'
        local grande = 0.35*r(max)
        qui gen byte `pos' = cond(`peso' >= `grande' & inrange(`x', `xlo', `xhi'), 0, ///
                                  cond(`x' > `xmed', 9, 3))

        local rotulos = "(scatter `y' `x' if `touse', msymbol(none) mlabel(`etiq')" + ///
            " mlabsize(vsmall) mlabcolor(gs5) mlabvposition(`pos') mlabgap(*1.5))"
        local nrecta 3
    }
    local cero = cond("`cero'"=="", "", "yline(0, lcolor(gs9) lpattern(dash))")
    local xlab = cond("`xlab'"=="", "", "xlabel(`xlab')")

    * msize(*#) reescala los símbolos sin perder la proporcionalidad del peso
    local msz = cond("`compacto'"=="", "*0.7", "*0.45")

    if "`compacto'" != "" {
        local subtitle "pendiente = `b' (EE `se')"
        local leg  legend(off)
        local note note("")
    }
    else {
        local leg legend(order(1 "Rama de actividad (tamaño proporcional al empleo)" ///
                               `nrecta' "Ajuste MCO ponderado: pendiente = `b' (EE `se')") ///
                         cols(1) size(vsmall) region(lstyle(none)))
        local note note("Pendiente por MCO ponderado por el empleo de la rama." ///
                        "R2 = `r2'. `nr' ramas incluidas (mínimo ${minobs} casos por rama-año)." ///
                        "${fuente}" "${defs}" "`nota'", size(vsmall))
    }

    twoway ///
      (scatter `y' `x' [aweight=`peso'] if `touse', ///
            msymbol(Oh) mcolor(navy) msize(`msz')) ///
      `rotulos' ///
      (lfit `y' `x' [aweight=`peso'] if `touse', lcolor(cranberry)) ///
      , title("`title'", size(medium)) subtitle("`subtitle'", size(small)) ///
        xtitle("`xtitle'", size(small)) ytitle("`ytitle'", size(small)) ///
        `xlab' ylabel(`ylab', angle(0) grid glcolor(gs14)) `cero' ///
        `leg' `note' xsize(7.5) ysize(5) $gopts name(`archivo', replace)

    if "`compacto'" == "" savefig "`archivo'"
end


*==============================================================================
* 2. UMBRAL SALARIAL VIGENTE (SBU DE DICIEMBRE)
*==============================================================================
* Réplica de la sección 2 de "empleo_adecuado_serie.do". Sólo se necesita el
* umbral NOMINAL de cada año —en la moneda del año—, que es el que entra en el
* indicador; el deflactor de IPC de aquel archivo sirve únicamente para
* reexpresar el umbral en dólares constantes y aquí no se usa.

*--- 2000-2025: SBU = "Remuneraciones unificadas", diciembre, USD -------------*
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html
import delimited "$salarios/Salario unificado y componentes salariales.csv", clear

* la columna del año viene como "anio" o como "año" según la descarga
capture confirm variable anio
if _rc {
    capture rename año anio
    if _rc {
        di as error "No se encontró la columna del año en el archivo de salarios."
        exit 459
    }
}

keep if strtrim(componentesalarial) == "Remuneraciones unificadas" ///
       & strtrim(mes) == "Diciembre"
rename valorsalariocomponenteendolares salario_min
replace salario_min = subinstr(salario_min, ",", ".", .)
destring salario_min anio, replace force
keep anio salario_min
drop if missing(anio) | missing(salario_min)
bysort anio: keep if _n == 1
tempfile sbu_usd
save `sbu_usd'

*--- 1990-1999: SMV + bonificaciones, TOTAL a diciembre, sucres ---------------*
* https://contenido.bce.fin.ec/documentos/PublicacionesNotas/Catalogo/IEMensual/
* El archivo trae primero el promedio anual y después un bloque "A DICIEMBRE".
* Se localiza ese bloque por contenido en vez de por posición.
import delimited "$salarios/SMV + bonificaciones.csv", ///
        varnames(nonames) stringcols(_all) clear

gen long _row = _n
gen byte _dic = (strtrim(v1) == "A DICIEMBRE")
qui sum _row if _dic, meanonly
if r(N) == 0 {
    di as error "No se encontró el bloque 'A DICIEMBRE' en 'SMV + bonificaciones.csv'."
    exit 459
}
local fila_dic = r(min)

keep if _row > `fila_dic'
keep if regexm(strtrim(v1), "^[0-9][0-9][0-9][0-9]$")
gen int anio = real(strtrim(v1))
keep if inrange(anio, 1990, 1999)
replace v10 = subinstr(strtrim(v10), ",", "", .)
destring v10, gen(salario_min) force
keep anio salario_min
drop if missing(salario_min)
bysort anio: keep if _n == 1
tempfile sbu_sucres
save `sbu_sucres'

*--- tabla única de umbrales, restringida a los años del análisis -------------*
use `sbu_usd', clear
append using `sbu_sucres'
sort anio

gen byte _usar = 0
foreach y of local anios {
    replace _usar = 1 if anio == `y'
}
keep if _usar == 1
drop _usar

gen str8 moneda = cond(anio < 2000, "sucres", "USD")
label variable salario_min "SBU vigente de diciembre (sucres <=1999, USD >=2000)"
label variable moneda      "Moneda del umbral y del ingreso laboral"

di as txt _n "{hline 60}"
di as txt "UMBRALES POR AÑO"
di as txt "{hline 60}"
format salario_min %14.2fc
list anio moneda salario_min, sep(0) noobs

* control: ningún año del análisis puede quedarse sin umbral vigente
local nan : word count `anios'
qui count
if r(N) != `nan' {
    di as error "Faltan umbrales: se esperaban `nan' años y hay " r(N) "."
    exit 459
}

* a globals, para no depender de un merge dentro del loop
foreach y of local anios {
    qui sum salario_min if anio == `y', meanonly
    global smin_`y' = r(mean)
}

tempfile umbrales
save `umbrales', replace


*==============================================================================
* 3. EMPLEO ADECUADO ARMONIZADO
*==============================================================================
* Traducción a programa de las secciones 3.1 a 3.8 de "empleo_adecuado_serie.do".
* Opera sobre la base en memoria y deja creadas petn, pean, empleo, w, t, d_d,
* adec y adec_of. El umbral del año se toma de ${smin_<año>}.
*
* Códigos que cambian con el cuestionario (documentados en aquel archivo):
*   p21 "no realizó ninguna actividad" = 11 en 2000-2006, 12 en el resto
*   p25 "no desea más horas"           = 2 en 1991-1992, 3 en 1993-1999, 9 en 2007+
*   p27 "desea más horas"              = 1/2 hasta 2006, 1-3 sí / 4 no en 2007+
*   p32 "buscó trabajo"                = 1/2 hasta 2006, 1-10 sí / 11 no en 2007+
*   p34 desempleo oculto               = 7-8 en los 90, <=7 (sin 4) en 2000-2006,
*                                        <=7 en 2007+
*   p28 disponibilidad                 = sólo existe desde 2007

cap program drop adec_armonizado
program define adec_armonizado
    args y

    *--- 3.1 nombres estándar p## (las bases 1991-2006 traen los nombres viejos)
    if `y' <= 2006 {
        capture rename trabajo  p20
        capture rename actayuda p21
        capture rename aunotra  p22
        capture rename hortrasa p24
        capture rename ratmeh   p25
        capture rename bustrama p32
        capture rename motnobus p34
        capture rename deseatra p35
        capture rename hortrahp p51a
        capture rename hortrahs p51b
        capture rename hortraho p51c
        if `y' >= 2000 capture rename hormas p27
    }

    * variables ausentes en algunos años: crearlas vacías para poder usarlas
    foreach v in p24 p25 p27 p28 p32 p34 p35 p51a p51b p51c {
        capture confirm variable `v'
        if _rc qui gen `v' = .
    }

    foreach v in edad p20 p21 p22 ingrl fexp {
        capture confirm variable `v'
        if _rc {
            di as error "  `y': falta la variable `v'"
            exit 111
        }
    }

    *--- 3.2 p27 en 1991-1999: no se pregunta, se construye ---
    * 1991-1992 traen ratmeh1; 1993-1999 traen hormas. Se replica el criterio
    * del archivo de la serie: cualquier valor no missing cuenta como "desea
    * trabajar más horas", porque la pregunta sólo se formulaba a quien lo
    * deseaba. (En 1992 `hormas` sí es dicotómica 1/2 y esa regla también
    * cuenta como "sí" al que responde 2; se conserva para no desalinear esta
    * base respecto de la serie publicada.)
    if `y' <= 1999 {
        capture drop p27
        qui gen byte p27 = 2 if p20 == 1 | p22 == 1
        capture confirm variable ratmeh1
        if !_rc qui replace p27 = 1 if ratmeh1 < .
        capture confirm variable hormas
        if !_rc qui replace p27 = 1 if hormas  < .
    }

    *--- 999 = no responde en las variables de horas ---
    foreach v in p24 p51a p51b p51c {
        qui replace `v' = . if `v' == 999
    }

    local p00 = (`y' >= 2000 & `y' <= 2006)
    local p07 = (`y' >= 2007)

    * categoría "no realizó ninguna actividad" de p21
    local p21_no = cond(`p00', 11, 12)
    local p21_si = `p21_no' - 1

    *--- 3.3 poblaciones de referencia ---
    capture drop petn
    qui gen byte petn = (edad >= edadmin) if edad < .

    capture drop pean
    qui gen byte pean = 0 if petn == 1
    qui replace  pean = 1 if petn == 1 & p20 == 1
    qui replace  pean = 1 if petn == 1 & p20 == 2 & p21 <= `p21_si'
    qui replace  pean = 1 if petn == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1

    if `p07' {
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 <= 10
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 11 ///
                              & p34 <= 7 & p35 == 1
    }
    else if `p00' {
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 1
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 2 ///
                              & p34 <= 7 & p34 != 4 & p35 == 1
    }
    else {
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 1
        * el tope "< ." evita que la condición sea verdadera con p34 missing
        qui replace pean = 1 if petn==1 & p20==2 & p21==`p21_no' & p22==2 & p32 == 2 ///
                              & p34 >= 7 & p34 < . & p35 == 1
    }
    label variable pean "Población Económicamente Activa"

    capture drop empleo
    qui gen byte empleo = 0 if pean == 1
    qui replace  empleo = 1 if pean == 1 & p20 == 1
    qui replace  empleo = 1 if pean == 1 & p20 == 2 & p21 <= `p21_si'
    qui replace  empleo = 1 if pean == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1
    label variable empleo "Población con Empleo"

    *--- 3.4 dimensión 1: ingreso laboral vs. SBU vigente ---
    capture drop ila
    qui gen double ila = ingrl

    * Códigos de no respuesta / valor atípico, año por año. Cada lista reproduce
    * la rama de ese año en "Boletín 1/Procesamiento/Codigos/Ingresos/
    * ingresos_anios_all_fn.do" para los componentes del ingreso LABORAL.
    local invalidos ""
    if `y' == 1991                  local invalidos "9999998"
    if inrange(`y', 1992, 1999)     local invalidos "9999998 9999999 99999999"
    if `y' == 2000                  local invalidos "9999 10000 99999 999999 9999999 39999999 89999999 99999999"
    if inrange(`y', 2001, 2005)     local invalidos "-1 999999"
    if `y' == 2006                  local invalidos "999 9999 22150 99999 999999"
    if inrange(`y', 2007, 2009)     local invalidos "-1 999999"
    if `y' >= 2010                  local invalidos "999999"

    foreach c of local invalidos {
        qui replace ila = . if ila == `c'
    }

    local smin = ${smin_`y'}

    capture drop w
    qui gen byte w = .
    qui replace  w = 0 if empleo == 1 & ila <  `smin'
    qui replace  w = 1 if empleo == 1 & ila >= `smin' & ila < .
    qui replace  w = . if ila >= .
    label variable w "Ingreso laboral >= SBU vigente"

    *--- 3.5 dimensión 2: horas trabajadas ---
    capture drop horas
    qui gen double horas = .
    if $horas_legacy qui replace horas = 0 if empleo == 1

    * horas efectivas (trabajó la semana pasada)
    qui replace horas = p24 if pean == 1 & p20 == 1
    qui replace horas = p24 if pean == 1 & p20 == 2 & p21 <= `p21_si'

    * horas habituales (tiene empleo pero no trabajó)
    capture drop hh
    qui egen double hh = rowtotal(p51a p51b p51c), missing
    qui replace hh = . if hh < 0
    qui replace horas = hh if pean == 1 & p20 == 2 & p21 == `p21_no' & p22 == 1
    label variable horas "Horas de trabajo semanal"

    capture drop t
    qui gen byte t = .
    qui replace  t = 0 if empleo == 1 & horas <  40
    qui replace  t = 1 if empleo == 1 & horas >= 40 & horas < .
    * jornada reducida de 12-17 años
    qui replace  t = 0 if empleo == 1 & horas <  30             & inrange(edad, 12, 17)
    qui replace  t = 1 if empleo == 1 & horas >= 30 & horas < . & inrange(edad, 12, 17)
    label variable t "Cumple la jornada laboral"

    *--- 3.6 dimensión 3: deseo y disponibilidad de trabajar más horas ---
    capture drop d_d
    qui gen byte d_d = 0 if empleo == 1

    if `p07' {
        qui replace d_d = 0 if empleo == 1 & (p25 == 9 | p27 == 4)
        qui replace d_d = 1 if empleo == 1 & p27 <= 3 & p28 == 1
    }
    else if `p00' {
        qui replace d_d = 0 if empleo == 1 & p27 == 2
        qui replace d_d = 1 if empleo == 1 & p27 == 1
    }
    else if `y' >= 1993 {
        qui replace d_d = 0 if empleo == 1 & (p25 == 3 | p27 == 2)
        qui replace d_d = 1 if empleo == 1 & p27 == 1
    }
    else {
        qui replace d_d = 0 if empleo == 1 & (p25 == 2 | p27 == 2)
        qui replace d_d = 1 if empleo == 1 & p27 == 1
    }
    label variable d_d "Desea y está disponible para trabajar más horas"

    *--- 3.7 empleo adecuado ---
    capture drop adec
    qui gen byte adec = 0 if pean == 1 & edad >= edadmin
    qui replace  adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w == 1 & t == 1
    qui replace  adec = 1 if pean == 1 & edad >= edadmin & empleo == 1 & w == 1 & t == 0 & d_d == 0

    *--- 3.8 clasificación oficial de la base y ajuste residual ---
    local cvar ""
    foreach c in condactn condact {
        if "`cvar'" == "" {
            capture confirm variable `c'
            if !_rc local cvar "`c'"
        }
    }

    capture drop adec_of
    qui gen byte adec_of = .

    if "`cvar'" != "" {
        capture drop _cs
        capture decode `cvar', gen(_cs)
        if !_rc {
            qui replace _cs = strtrim(_cs)

            * la etiqueta del empleo adecuado cambia de nombre entre años
            qui gen byte _ofi = regexm(lower(_cs), ///
                "^(ocupados plenos|empleo adecuado|empleo adecuado/pleno)$")
            qui replace adec_of = 0 if pean == 1
            qui replace adec_of = 1 if pean == 1 & _ofi == 1
            drop _ofi

            * "Otro empleo no pleno" (2016+) == "Otro empleo Inadecuado" (2007-2015).
            * En 1992-2011 ninguna etiqueta coincide, así que el ajuste no opera.
            qui gen byte _aj = regexm(lower(_cs), "^otro empleo (no pleno|inadecuado)$")
            if $ajuste_condact qui replace adec = 0 if _aj == 1 & adec < .
            drop _aj _cs
        }
    }
    label variable adec    "Empleo adecuado armonizado (umbral: SBU vigente)"
    label variable adec_of "Empleo adecuado según la condición de actividad de la base"
end


*----------------------------------------------------- 4. Base rama x año -----
* Cada año trae su propia variable educativa:
*   1992-1999  nivinst  5     = superior (una sola categoría, sin posgrado)
*   2001       nivinst  6-7   = superior/posgrado
*   2010-2024  p10a     9-10  = superior universitario/posgrado
* La población de referencia son los OCUPADOS de 15 años y más con rama válida.

tempfile pool
clear
save `pool', emptyok

tempname D
tempfile diag
postfile `D' int anio double smin double adec_pea double adec_of_pea       ///
        double adec_ocup long n_pea long n_ocup long n_rama                ///
        double p_sin_ingreso using `diag', replace

local anios_ok ""

foreach y of local anios {

    di as txt _n "{hline 60}"
    di as txt "  `y'"
    di as txt "{hline 60}"

    if `y' <= 1999 {
        local educ "nivinst"
        local univ "5"
    }
    else if `y' == 2001 {
        local educ "nivinst"
        local univ "6, 7"
    }
    else {
        local educ "p10a"
        local univ "9, 10"
    }

    qui use "$limpias/empleo`y'_isic4.dta", clear

    * 1992-1999 no traen `area`: la ENEMDU de diciembre es urbana por diseño
    local tiene_area = 0
    capture confirm variable area
    if !_rc {
        local tiene_area = 1
        capture destring area, replace
    }

    if `filtro' & `tiene_area' qui keep if area == `filtro'
    if `filtro' == 2 & !`tiene_area' {
        di as error "  `y' no tiene muestra rural: año omitido."
        continue
    }

    capture confirm variable `educ'
    if _rc {
        di as error "  `y': falta la variable educativa `educ'; año omitido."
        continue
    }

    adec_armonizado `y'

    *--- diagnóstico: tasas sobre la PEA, comparables con empleo_adecuado_serie.do
    qui sum adec [aw = fexp]
    local adec_pea = r(mean) * 100
    local n_pea    = r(N)
    qui sum adec_of [aw = fexp]
    local of_pea = cond(r(N) > 0, r(mean) * 100, .)
    qui sum adec [aw = fexp] if empleo == 1
    local adec_oc = r(mean) * 100
    local n_ocup  = r(N)
    qui sum fexp if empleo == 1 & ila >= ., meanonly
    local aux = cond(r(N) > 0, r(sum), 0)
    qui sum fexp if empleo == 1, meanonly
    local sin_i = cond(r(sum) > 0, `aux'/r(sum)*100, .)

    * las bases traen su propio `anio`; se reescribe para no depender de él
    cap drop anio
    cap drop univ
    gen int  anio = `y'
    gen byte univ = inlist(`educ', `univ') if !missing(`educ')

    * ocupados de 15+ con rama y factor de expansión válidos
    keep if empleo == 1 & edad >= edadmin & !missing(rama1, fexp, adec)
    local n_rama = _N

    di as txt "  adec/PEA = " as res %5.2f `adec_pea' as txt "%" ///
              "   oficial/PEA = " as res %5.2f `of_pea' as txt "%" ///
              "   adec/ocupados = " as res %5.2f `adec_oc' as txt "%"
    di as txt "  ocupados 15+ = `n_ocup'   con rama = `n_rama'"

    post `D' (`y') (${smin_`y'}) (`adec_pea') (`of_pea') (`adec_oc') ///
             (`n_pea') (`n_ocup') (`n_rama') (`sin_i')

    keep anio rama1 fexp univ adec
    append using `pool'
    qui save `pool', replace

    local anios_ok "`anios_ok' `y'"
}

postclose `D'

local anios `anios_ok'
local nan : word count `anios'
if `nan' == 0 {
    di as error "No quedó ningún año con datos utilizables."
    exit 459
}

use `pool', clear
gen double emp      = fexp
gen double emp_uni  = fexp * univ
gen double emp_adec = fexp * adec

collapse (sum) emp emp_uni emp_adec (count) obs = fexp, by(rama1 anio)

gen double emp_nouni = emp - emp_uni
gen double p_uni     = 100 * emp_uni  / emp   // % de ocupados con superior
gen double p_adec    = 100 * emp_adec / emp   // % de ocupados con empleo adecuado

reshape wide emp emp_uni emp_nouni emp_adec p_uni p_adec obs, i(rama1) j(anio)

* Una rama puede no aparecer en un año (la 12, inmobiliarias, no existe en los
* 90): la reshape deja missing y la marca -ok- de más abajo la excluye.
foreach y of local anios {
    capture confirm variable obs`y'
    if _rc {
        di as error "El año `y' no dejó ninguna rama; revisar la base."
        exit 459
    }
}

*--------------------------------------------------- 4b. Etiquetas de ramas ---
label define rama_corta ///
     1 "Agricultura y pesca"    2 "Minas y canteras"      3 "Manufactura"        ///
     4 "Electricidad y gas"     5 "Agua y saneamiento"    6 "Construcción"       ///
     7 "Comercio"               8 "Transporte"            9 "Alojamiento/comida" ///
    10 "Información y com."    11 "Finanzas y seguros"   12 "Inmobiliarias"      ///
    13 "Prof. y científicas"   14 "Serv. administrativos" 15 "Adm. pública"      ///
    16 "Enseñanza"             17 "Salud"                18 "Arte y recreación"  ///
    19 "Otros servicios"       20 "Hogares empleadores"  21 "Org. extraterrit.", replace
label values rama1 rama_corta
label var rama1 "Rama de actividad (CIIU 4.0)"
decode rama1, gen(rama_txt)     // versión string para rotular los puntos

*------------------------------ 5. Crecimiento del empleo (pares de años) -----
* Sólo se conservan los pares cuyos dos años sobrevivieron a la sección 4.
local pares_ok ""
foreach par of local pares {
    local y0 = substr("`par'", 1, 4)
    local y1 = substr("`par'", 6, 4)
    local hay0 : list posof "`y0'" in anios
    local hay1 : list posof "`y1'" in anios
    if `hay0' & `hay1' local pares_ok "`pares_ok' `par'"
    else di as error "Par `par' omitido: falta al menos uno de los dos años."
}
local pares `pares_ok'

local paneles_c ""

foreach par of local pares {
    local y0  = substr("`par'", 1, 4)
    local y1  = substr("`par'", 6, 4)
    local cav = cond(`y0' <= 2001, "${cav01}", "")
    local c90 = cond(`y0' <= 1999, "${cav90}", "")

    * Variación del empleo por nivel educativo
    gen double g_uni_`y0'_`y1'   = 100 * (emp_uni`y1'   / emp_uni`y0'   - 1)
    gen double g_nouni_`y0'_`y1' = 100 * (emp_nouni`y1' / emp_nouni`y0' - 1)
    gen double g_tot_`y0'_`y1'   = 100 * (emp`y1'       / emp`y0'       - 1)

    * -ok- marca las ramas con muestra suficiente en ambos años (la usan las
    * dispersiones); -top- son las ramas fijas del gráfico de barras, sujetas
    * a esa misma condición de muestra.
    cap drop ok
    cap drop top
    gen byte ok = obs`y0' >= $minobs & obs`y1' >= $minobs & !missing(obs`y0', obs`y1')
    gen byte top = 0
    foreach r of global ramas_bar {
        replace top = 1 if rama1 == `r' & ok
        qui count if rama1 == `r' & !ok
        if r(N) di as error "  `par': la rama `r' no cumple el mínimo de casos y queda fuera de las barras."
    }

    * (a) Barras: crecimiento del empleo por rama y nivel educativo
    graph hbar (asis) g_uni_`y0'_`y1' g_nouni_`y0'_`y1' if top, ///
        over(rama1, sort(emp`y1') descending label(labsize(small))) ///
        blabel(bar, format(%4.0f) size(vsmall)) ///
        yline(0, lcolor(gs9)) ///
        ytitle("Variación del empleo `y0'-`y1' (%)", size(small)) ///
        title("Crecimiento del empleo por rama y nivel educativo", size(medium)) ///
        subtitle("Ecuador `ambito', `y0'-`y1'. Ramas seleccionadas, ordenadas por empleo en `y1'", size(small)) ///
        legend(order(1 "Con educación superior" 2 "Sin educación superior") ///
               rows(1) size(small) region(lstyle(none))) ///
        note("${fuente}" "${defs}" "`cav'" "`c90'" "${cavamb}", size(vsmall)) ///
        bar(1, color(navy)) bar(2, color(cranberry)) ///
        xsize(7.5) ysize(5.5) $gopts name(fig_crecimiento_`y0'_`y1', replace)
    savefig "fig_crecimiento_`y0'_`y1'"

    * (b) Dispersión: con superior en el año base vs crecimiento posterior
    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') ///
        archivo(fig_educ_crecimiento_`y0'_`y1') nombre(rama_txt) cero ///
        title("Ramas con más educación superior en `y0' y crecimiento del empleo") ///
        subtitle("Ecuador `ambito', `y0'-`y1'") ///
        xtitle("Ocupados con educación superior en `y0' (%)") ///
        ytitle("Variación del empleo total `y0'-`y1' (%)") ///
        nota("`cav' `c90'")

    fig_scatter g_tot_`y0'_`y1' p_uni`y0' if ok, peso(emp`y0') compacto cero ///
        archivo(panelc_`y0'_`y1') nombre(rama_txt) nrot(2) nesq(1) ///
        title("`y0'-`y1'") xlab(0(20)80) ///
        xtitle("% con superior en `y0'") ytitle("Variación del empleo (%)")

    local paneles_c "`paneles_c' panelc_`y0'_`y1'"
}

* Con tres paneles: dos arriba y el tercero centrado abajo. graph combine llena
* la grilla por filas y da a todas las celdas de una fila el mismo ancho, así
* que el tercer panel se deja en la celda inferior izquierda —con lo que
* conserva el tamaño de los de arriba— y se corre media celda a la derecha con
* el editor de gráficos. Armarlo con gráficos vacíos a los costados también lo
* centra, pero lo deja a dos tercios del ancho de los otros dos.
local npc : word count `paneles_c'
local layout "cols(2)"
if `npc' == 3 local layout "cols(2) holes(4)"

graph combine `paneles_c', `layout' imargin(small) ///
    title("Educación superior inicial y crecimiento posterior del empleo", size(medium)) ///
    subtitle("Ecuador `ambito'. Cada círculo es una rama (tamaño: empleo del año inicial)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "Ojo: cada panel cubre un horizonte distinto, por lo que la escala vertical no es comparable entre paneles." ///
         "${fuente}" "${defs}" "${cav01}" "${cav90}" "${cavamb}", size(vsmall)) ///
    xsize(9) ysize(7.5) $gopts name(fig_educ_crecimiento_panel, replace)
if `npc' == 3 gr_edit .plotregion1.graph3.xoffset = 25
savefig "fig_educ_crecimiento_panel"

*------------------------------ 6. Educación y empleo adecuado (por año) ------
local paneles_a ""

foreach y of local anios {
    local cav = cond(`y' <= 2001, "${cav01}", "")
    local c90 = cond(`y' <= 1999, "${cav90}", "")

    * versión individual (con leyenda y notas) y versión compacta para el panel
    fig_scatter p_uni`y' p_adec`y' if obs`y' >= $minobs & !missing(obs`y'), peso(emp`y') ///
        archivo(fig_educ_adec_`y') nombre(rama_txt) xlab(0(20)100) ylab(0(20)100) ///
        title("Educación superior y empleo adecuado por rama") ///
        subtitle("Ecuador `ambito', `y'") ///
        xtitle("Ocupados con empleo adecuado (%)") ///
        ytitle("Ocupados con educación superior (%)") ///
        nota("`cav' `c90'")

    fig_scatter p_uni`y' p_adec`y' if obs`y' >= $minobs & !missing(obs`y'), peso(emp`y') compacto ///
        archivo(panel_`y') nombre(rama_txt) nrot(3) nesq(1) ///
        xlab(0(20)100) ylab(0(20)100) title("`y'") ///
        xtitle("% con empleo adecuado") ytitle("% con superior")

    local paneles_a "`paneles_a' panel_`y'"
}

* Hasta cuatro años caben en dos columnas; con más, tres columnas mantienen
* legibles los rótulos sin estirar el alto de la lámina.
local cols = cond(`nan' <= 4, 2, 3)
local xs   = cond(`cols' == 2, 9, 12)

graph combine `paneles_a', cols(`cols') imargin(small) ///
    title("Educación superior y empleo adecuado por rama de actividad", size(medium)) ///
    subtitle("Ecuador `ambito'. Cada círculo es una rama (tamaño: empleo total)", size(small)) ///
    note("La recta roja es el ajuste MCO ponderado por el empleo de la rama." ///
         "${fuente}" "${defs}" "${cav01}" "${cav90}" "${cavdol}" "${cavamb}", size(vsmall)) ///
    xsize(`xs') ysize(7) $gopts name(fig_educ_adec_panel, replace)
savefig "fig_educ_adec_panel"

*--------------------------------------------------------------- 7. Salidas ---
cap drop ok
cap drop top

* Nombres autoexplicativos para la base exportada: <concepto>_<año> o
* <concepto>_<año inicial>_<año final>. Los "ocupados" son personas expandidas
* por el factor de expansión; "casos" son observaciones muestrales sin ponderar.
rename rama1    rama_cod
rename rama_txt rama
label var rama_cod "Código de rama, CIIU 4.0"
label var rama     "Rama de actividad, CIIU 4.0"

foreach y of local anios {
    rename emp`y'       ocupados_`y'
    rename emp_uni`y'   ocupados_sup_`y'
    rename emp_nouni`y' ocupados_nosup_`y'
    rename emp_adec`y'  ocupados_adec_`y'
    rename p_uni`y'     pct_sup_`y'
    rename p_adec`y'    pct_adec_`y'
    rename obs`y'       casos_`y'
    label var ocupados_`y'       "Ocupados 15+, `y'"
    label var ocupados_sup_`y'   "Ocupados con educación superior, `y'"
    label var ocupados_nosup_`y' "Ocupados sin educación superior, `y'"
    label var ocupados_adec_`y'  "Ocupados con empleo adecuado armonizado, `y'"
    label var pct_sup_`y'        "% de ocupados con educación superior, `y'"
    label var pct_adec_`y'       "% de ocupados con empleo adecuado armonizado, `y'"
    label var casos_`y'          "Casos muestrales sin ponderar, `y'"
}

foreach par of local pares {
    local y0 = substr("`par'", 1, 4)
    local y1 = substr("`par'", 6, 4)
    rename g_uni_`y0'_`y1'   var_pct_ocup_sup_`y0'_`y1'
    rename g_nouni_`y0'_`y1' var_pct_ocup_nosup_`y0'_`y1'
    rename g_tot_`y0'_`y1'   var_pct_ocup_`y0'_`y1'
    label var var_pct_ocup_sup_`y0'_`y1'   "Variación % ocupados con superior, `y0'-`y1'"
    label var var_pct_ocup_nosup_`y0'_`y1' "Variación % ocupados sin superior, `y0'-`y1'"
    label var var_pct_ocup_`y0'_`y1'       "Variación % ocupados totales, `y0'-`y1'"
}

order rama_cod rama ocupados_* pct_* var_pct_* casos_*
sort rama_cod
format ocupados_* %12.0f
format pct_*      %6.1f
format var_pct_*  %7.1f
compress
save "$out/base_rama_educ.dta", replace

* nolabel: rama_cod sale como código numérico (el nombre ya está en rama)
* datafmt: respeta los formatos de arriba en vez de volcar 15 decimales
export delimited using "$out/base_rama_educ.csv", replace nolabel datafmt

local y_ini : word 1 of `anios'
local y_fin : word `nan' of `anios'

di as txt _n "{hline 78}"
di as txt "RAMAS: educación superior y empleo adecuado, `y_ini' vs `y_fin'"
di as txt "{hline 78}"
list rama pct_sup_`y_ini' pct_sup_`y_fin' pct_adec_`y_ini' pct_adec_`y_fin' ///
     if casos_`y_fin' >= $minobs & !missing(casos_`y_fin'), noobs

*--- diagnóstico: tasas sobre la PEA, para cotejar con empleo_adecuado_serie.do
preserve
    use `diag', clear
    label var anio          "Año"
    label var smin          "SBU vigente de diciembre (moneda del año)"
    label var adec_pea      "Empleo adecuado armonizado (% de la PEA 15+)"
    label var adec_of_pea   "Empleo adecuado oficial de la base (% de la PEA 15+)"
    label var adec_ocup     "Empleo adecuado armonizado (% de los ocupados 15+)"
    label var n_pea         "Observaciones en la PEA 15+"
    label var n_ocup        "Observaciones de ocupados 15+"
    label var n_rama        "Ocupados 15+ con rama válida"
    label var p_sin_ingreso "Ocupados sin dato de ingreso laboral (%)"
    format adec_pea adec_of_pea adec_ocup p_sin_ingreso %6.2f
    format smin %14.2fc

    di as txt _n "{hline 78}"
    di as txt "DIAGNÓSTICO (adec_pea debe coincidir con la serie armonizada)"
    di as txt "{hline 78}"
    list, sep(0) noobs

    save "$out/diagnostico_rama_educ.dta", replace
    export delimited using "$out/diagnostico_rama_educ.csv", replace datafmt
restore

di as txt _n "Listo. Salidas en: $out"

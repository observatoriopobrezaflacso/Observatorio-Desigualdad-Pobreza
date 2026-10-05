*==============================================================================*
* CONSOLIDA EN UN SOLO LIBRO TODOS LOS EXCEL QUE GENERA EL MASTER
*
* Cada do-file del paper escribe su propio .xlsx en su carpeta. Este archivo
* junta esas tablas en un libro local, arma a partir de ellas las hojas con la
* forma que piden los gráficos y deja en el Drive
*
*     $out/Iconos_resultados.xlsx
*
* sólo con las hojas que usan los gráficos del paper (ver la sección "libro
* del paper", al final). El libro se crea de nuevo en cada corrida, así que no
* quedan hojas viejas.
*
* Se corre al final de master.do. También funciona suelto, siempre que los
* do-files ya hayan generado sus salidas.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}
if "$out" == "" global out "$gd/Papers/Íconos/outputs"

set more off
set varabbrev off

global libro "$out/Iconos_resultados.xlsx"

*------------------------------------------------------------------------------
* Carpetas de cada módulo. Se definen aparte porque algunas tienen espacios y
* eso rompe el troceo por palabras de un `foreach`.
*------------------------------------------------------------------------------
local d_des "$out/desigualdad"
local d_bre "$out/brechas"
local d_gin "$out/Gini decomposition"
local d_pri "$out/educ_ingrl"
local d_ade "$out/empleo adecuado"
local d_ram "$out/rama_educ"
local d_gic "$out/GIC"

*------------------------------------------------------------------------------
* Lista de trabajos: archivo de origen, hoja de origen, hoja de destino.
* Se usan locales numerados en vez de una lista suelta para que los nombres
* con espacios no se partan.
*------------------------------------------------------------------------------
local n = 0

* --- Gini y Palma (gini_palma_serie.do) ---------------------------------------
local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "gini"
local t`n' "gini_serie"

local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "palma"
local t`n' "palma_serie"

local ++n
local f`n' "`d_des'/gini_palma_tablas.xlsx"
local s`n' "detalle"
local t`n' "gini_palma_detalle"

* --- Brechas salariales (brechas_salariales.do) -------------------------------
local ++n
local f`n' "`d_bre'/brechas_salariales.xlsx"
local s`n' "brechas"
local t`n' "brechas"

* --- Descomposición del Gini (gini_decomp5.do) --------------------------------
local ++n
local f`n' "`d_gin'/gini_decomposition.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_nacional"

local ++n
local f`n' "`d_gin'/gini_decomposition_cuartiles.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_cuartiles"

local ++n
local f`n' "`d_gin'/gini_decomposition_quintiles.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_quintiles"

local ++n
local f`n' "`d_gin'/gini_decomposition_urbano.xlsx"
local s`n' "Sheet1"
local t`n' "decomp_urbano"

local ++n
local f`n' "`d_gin'/Gini.xlsx"
local s`n' "Sheet1"
local t`n' "gini_decomp5_gini"

* --- Prima salarial por hora (educ_ingrl_hora.do) -----------------------------
local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "coeficientes"
local t`n' "prima_coeficientes"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "ancho_para_grafico"
local t`n' "prima_ancho"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "horas_y_muestra"
local t`n' "prima_horas_muestra"

local ++n
local f`n' "`d_pri'/prima_hora_tablas.xlsx"
local s`n' "modelo_agrupado"
local t`n' "prima_modelo_agrupado"

* --- Empleo adecuado (empleo_adecuado_serie.do) -------------------------------
local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Serie"
local t`n' "adecuado_serie"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Diagnostico"
local t`n' "adecuado_diagnostico"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Sensibilidad"
local t`n' "adecuado_sensibilidad"

local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_1991_2025.xlsx"
local s`n' "Umbrales"
local t`n' "adecuado_umbrales"

* --- Empleo adecuado simulado (empleo_adecuado_simulacion.do) -----------------
local ++n
local f`n' "`d_ade'/serie_empleo_adecuado_simulado_1991_2025.xlsx"
local s`n' "Serie"
local t`n' "adecuado_simulado"

* --- Paneles de rama y educación (empleo_pleno_rama.do) -----------------------
local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_crecimiento"
local t`n' "panel_crecimiento"

local ++n
local f`n' "`d_ram'/datos_paneles.xlsx"
local s`n' "panel_educ_pleno"
local t`n' "panel_educ_pleno"

* --- Curvas de incidencia del crecimiento (gic_paper.do) ----------------------
local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_urbano"
local t`n' "gic_urbano"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_nacional"
local t`n' "gic_nacional"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_ref"
local t`n' "gic_referencias"

local ++n
local f`n' "`d_gic'/gic_paper.xlsx"
local s`n' "GIC_largo"
local t`n' "gic_largo"

*==============================================================================*
* CONSOLIDACIÓN
*==============================================================================*

* Stata no logra abrir ni escribir .xlsx directamente sobre la carpeta de
* Google Drive (r(603): "could not be loaded"). Por eso cada archivo de
* origen se copia primero a disco local, el libro se arma también en local y
* recién al final se copia a su lugar en el Drive.
tempfile tsrc tlib
local origen_loc "`tsrc'.xlsx"
local libro_loc  "`tlib'.xlsx"

local escritas = 0
local faltantes ""

forvalues i = 1/`n' {

    local arch "`f`i''"
    local hoja "`s`i''"
    local dest "`t`i''"

    capture confirm file "`arch'"
    if _rc {
        di as error "FALTA: `arch'"
        local faltantes "`faltantes' `dest'"
        continue
    }

    capture copy "`arch'" "`origen_loc'", replace
    if _rc {
        di as error "No se pudo copiar `arch'"
        local faltantes "`faltantes' `dest'"
        continue
    }

    capture import excel "`origen_loc'", sheet("`hoja'") firstrow clear
    if _rc {
        di as error "No se pudo leer `dest' (hoja `hoja' de `arch')"
        local faltantes "`faltantes' `dest'"
        continue
    }
    if (_N == 0) {
        di as error "`dest': hoja vacía, se omite"
        local faltantes "`faltantes' `dest'"
        continue
    }

    * La primera hoja crea el libro; las demás sólo reemplazan la suya.
    if (`escritas' == 0) {
        export excel using "`libro_loc'", sheet("`dest'") firstrow(variables) replace
    }
    else {
        export excel using "`libro_loc'", sheet("`dest'") firstrow(variables) sheetreplace
    }
    local ++escritas
    di as txt "  hoja `escritas': `dest'  (`=_N' filas)  <- `hoja'"
}

*------------------------------------------------------------------------------
* Crecimiento del empleo por rama y nivel educativo (Gráficos 14, 15 y 16)
*
* Los cuatro períodos salen del MISMO libro, el de empleo_pleno_rama.do, que
* usa el empleo adecuado armonizado y cubre 1992-1999, 2001-2010, 2011-2024 y
* 2001-2024. Antes tres de ellos venían de empleo_calificados.do, que parte por
* "universitaria" en vez de "superior" y da otros números: mezclarlos hacía que
* los gráficos no fueran comparables entre sí.
*
* El gemelo empleo_pleno_rama_condact.do escribe un libro igual pero con la
* definición oficial de empleo pleno (condact == 1), que no es comparable a lo
* largo del período. Sirve para cotejar, no para estos gráficos.
*
* La hoja de origen trae todas las ramas y una columna por concepto. Aquí se
* recorta a las cinco ramas de las barras (CIIU 1, 3, 6, 7 y 9) y se le da la
* forma de tres columnas que espera la macro de gráficos.
*
* En 1992-1999 la ENEMDU de diciembre es sólo urbana, que es el ámbito que
* pedía el pie del Gráfico 14 de la versión anterior. El análisis de
* crecimiento del empleo ya no está en el paper: las hojas crec_* se dejan
* como datos, sin gráfico.
*------------------------------------------------------------------------------

local crec_arch "$out/rama_educ/nacional/tablas_rama_educ.xlsx"
local crec_pares "1992_1999 2001_2010 2011_2024 2001_2024"
local crec_hojas ""

capture confirm file "`crec_arch'"
if _rc {
    di as error "FALTA: `crec_arch' (lo genera empleo_pleno_rama.do)"
    foreach par of local crec_pares {
        local faltantes "`faltantes' crec_`par'"
    }
}
else {
    capture copy "`crec_arch'" "`origen_loc'", replace

    foreach par of local crec_pares {

        capture import excel "`origen_loc'", sheet("crecimiento_`par'") firstrow clear
        if _rc | _N == 0 {
            di as error "No se pudo leer crecimiento_`par' de `crec_arch'"
            local faltantes "`faltantes' crec_`par'"
            continue
        }

        * Columnas por posición, porque los encabezados son las etiquetas de
        * variable: 1 código, 2 rama, 6 variación con superior, 7 sin superior.
        unab todas : _all
        local v_cod  : word 1 of `todas'
        local v_rama : word 2 of `todas'
        local v_uni  : word 6 of `todas'
        local v_nou  : word 7 of `todas'

        keep `v_cod' `v_rama' `v_uni' `v_nou'
        capture confirm numeric variable `v_cod'
        if _rc destring `v_cod', replace force
        keep if inlist(`v_cod', 1, 3, 6, 7, 9)

        rename `v_rama' rama_nombre
        rename `v_uni'  uni_crec_`par'
        rename `v_nou'  nouni_crec_`par'
        keep  rama_nombre uni_crec_`par' nouni_crec_`par'
        order rama_nombre uni_crec_`par' nouni_crec_`par'
        sort rama_nombre

        if (_N == 0) {
            di as error "crec_`par': ninguna de las cinco ramas sobrevivió"
            local faltantes "`faltantes' crec_`par'"
            continue
        }

        if (`escritas' == 0) export excel using "`libro_loc'", ///
            sheet("crec_`par'") firstrow(variables) replace
        else export excel using "`libro_loc'", ///
            sheet("crec_`par'") firstrow(variables) sheetreplace

        local ++escritas
        local crec_hojas "`crec_hojas' crec_`par'"
        di as txt "  hoja `escritas': crec_`par'  (`=_N' filas)  <- crecimiento_`par'"
    }
}

*------------------------------------------------------------------------------
* Hojas listas para graficar
*
* Cada gráfico de la macro graficos_iconos.bas lee sus datos de la hoja donde
* se dibuja, columna por columna, sin hojas auxiliares. Cuatro gráficos necesitan
* los datos con otra forma que la de su tabla de origen (filtrar el urbano,
* pasar de largo a ancho), así que esa forma se arma aquí, en Stata, y se
* escribe como una hoja propia con encabezados simples:
*
*   remesas_cuartil      <- decomp_cuartiles (sremesas, largo -> ancho)  G09
*   bono_cuartil         <- decomp_cuartiles (sbono,    largo -> ancho)  G10
*   prima_urbano         <- prima_ancho, filas urbanas                   G13
*   horas_urbano         <- prima_horas_muestra, urbano, horas           (sin gráfico)
*   ingreso_hora_urbano  <- prima_horas_muestra, urbano, ingreso/hora    (sin gráfico)
*   adecuado_urbano      <- adecuado_simulado, columnas urbanas          G14
*
* Se leen del libro local que se está armando, así que salen de los mismos
* datos que las tablas de origen.
*------------------------------------------------------------------------------
local graf_hojas ""
local graf_orig  ""

* --- G09 y G10: participación de remesas y bono por cuartil ------------------
foreach c in remesas bono {
    capture import excel "`libro_loc'", sheet("decomp_cuartiles") firstrow clear
    if _rc | _N == 0 {
        local faltantes "`faltantes' `c'_cuartil"
        continue
    }
    keep t q s`c'
    rename (t s`c') (anio cuartil_)
    reshape wide cuartil_, i(anio) j(q)
    sort anio
    export excel using "`libro_loc'", sheet("`c'_cuartil") firstrow(variables) sheetreplace
    local ++escritas
    local graf_hojas "`graf_hojas' `c'_cuartil"
    local graf_orig  "`graf_orig' decomp_cuartiles"
    di as txt "  hoja `escritas': `c'_cuartil  (`=_N' filas)  <- decomp_cuartiles"
}

* --- G13: prima salarial, urbano ---------------------------------------------
* Columnas por posición: 1 ámbito, 2 año, 3 total, 4 hombres, 5 mujeres.
capture import excel "`libro_loc'", sheet("prima_ancho") firstrow clear
if _rc | _N == 0 local faltantes "`faltantes' prima_urbano"
else {
    unab todas : _all
    local v_amb : word 1 of `todas'
    keep if strtrim(`v_amb') == "Urbano"
    drop `v_amb'
    unab todas : _all
    rename (`todas') (anio total hombres mujeres)
    sort anio
    export excel using "`libro_loc'", sheet("prima_urbano") firstrow(variables) sheetreplace
    local ++escritas
    local graf_hojas "`graf_hojas' prima_urbano"
    local graf_orig  "`graf_orig' prima_ancho"
    di as txt "  hoja `escritas': prima_urbano  (`=_N' filas)  <- prima_ancho"
}

* --- Horas semanales e ingreso por hora, urbano (sin gráfico en el paper) ----
* Columnas por posición: 1 ámbito, 2 año, 3-4 horas (hasta secundaria,
* universitaria o más), 5-6 ingreso por hora (mismo orden).
foreach g in horas ingreso_hora {
    capture import excel "`libro_loc'", sheet("prima_horas_muestra") firstrow clear
    if _rc | _N == 0 {
        local faltantes "`faltantes' `g'_urbano"
        continue
    }
    unab todas : _all
    local v_amb  : word 1 of `todas'
    local v_anio : word 2 of `todas'
    if "`g'" == "horas" {
        local v_sec : word 3 of `todas'
        local v_uni : word 4 of `todas'
    }
    else {
        local v_sec : word 5 of `todas'
        local v_uni : word 6 of `todas'
    }
    keep if strtrim(`v_amb') == "Urbano"
    keep `v_anio' `v_sec' `v_uni'
    rename (`v_anio' `v_sec' `v_uni') (anio hasta_secundaria universitaria)
    sort anio
    export excel using "`libro_loc'", sheet("`g'_urbano") firstrow(variables) sheetreplace
    local ++escritas
    local graf_hojas "`graf_hojas' `g'_urbano"
    local graf_orig  "`graf_orig' prima_horas_muestra"
    di as txt "  hoja `escritas': `g'_urbano  (`=_N' filas)  <- prima_horas_muestra"
}

* --- G14: empleo adecuado urbano, observado y simulado ----------------------
* Columnas por posición: 1 año, 2 nacional, 3 urbano, 4 simulado nacional,
* 5 simulado urbano. La columna urbana ya trae 1991-1999, cuando la muestra
* es sólo urbana, así que no hace falta empalmar con la nacional.
capture import excel "`libro_loc'", sheet("adecuado_simulado") firstrow clear
if _rc | _N == 0 local faltantes "`faltantes' adecuado_urbano"
else {
    unab todas : _all
    local v_anio : word 1 of `todas'
    local v_obs  : word 3 of `todas'
    local v_sim  : word 5 of `todas'
    keep `v_anio' `v_obs' `v_sim'
    rename (`v_anio' `v_obs' `v_sim') (anio observado simulado)
    sort anio
    export excel using "`libro_loc'", sheet("adecuado_urbano") firstrow(variables) sheetreplace
    local ++escritas
    local graf_hojas "`graf_hojas' adecuado_urbano"
    local graf_orig  "`graf_orig' adecuado_simulado"
    di as txt "  hoja `escritas': adecuado_urbano  (`=_N' filas)  <- adecuado_simulado"
}

*------------------------------------------------------------------------------
* Gini de los registros del SRI, antes y después de impuestos (Gráfico 17)
*
* No sale de la ENEMDU ni de ningún do-file del master: son los valores del
* libro del paper, tecleados aquí para que la hoja se regenere con el resto.
* Si cambian, se corrigen en esta tabla.
*------------------------------------------------------------------------------
clear
input int anio double(gini_antes gini_despues)
2010 0.57 0.56
2011 0.59 0.58
2012 0.57 0.56
2013 0.57 0.56
2014 0.58 0.57
2015 0.57 0.56
2016 0.59 0.57
2017 0.57 0.56
2018 0.56 0.55
2019 0.54 0.53
2020 0.54 0.53
2021 0.56 0.55
2022 0.57 0.55
2023 0.55 0.54
2024 0.55 0.54
end

if (`escritas' == 0) export excel using "`libro_loc'", ///
    sheet("gini_sri") firstrow(variables) replace
else export excel using "`libro_loc'", ///
    sheet("gini_sri") firstrow(variables) sheetreplace
local ++escritas
di as txt "  hoja `escritas': gini_sri  (`=_N' filas)  <- tecleada (SRI)"

*------------------------------------------------------------------------------
* Hojas de los gráficos cuya fuente no es la ENEMDU (Gráficos 4, 5, 15 y 16)
*
* Sus datos vienen de fuentes externas (SRI, BCE, Ministerio del Trabajo,
* INEC) y se teclean aquí, tomados del libro viejo del paper, para que los
* gráficos lean sólo de este libro. Lo que se puede calcular se calcula aquí:
* el crecimiento del PIB y sus promedios, los valores en dólares de 2015 y el
* Gini, que sale de la hoja gini_serie de este mismo libro.
*------------------------------------------------------------------------------

* Gini urbano y nacional de gini_palma_serie.do (hoja gini_serie)
import excel "`libro_loc'", sheet("gini_serie") firstrow clear
unab todas : _all
rename (`todas') (anio gini_urbano gini_nacional)
tempfile gini_ext
save `gini_ext'

* --- G04: participación en el ingreso, registros del SRI ---------------------
* Proporción del ingreso nacional antes de impuestos por grupo, de los
* microdatos tributarios (SRI/Procesamiento/Codigos/Renta/renta_percentiles.do,
* bloque 4.1 del master; no se corre aquí).
clear
input int anio double(top01 top1 top10 clase_media bottom50 bottom35)
2010 0.0412 0.1204 0.4091 0.446 0.1449 0.0705
2011 0.0533 0.1325 0.4157 0.4394 0.1449 0.0699
2012 0.0498 0.1306 0.4123 0.4385 0.1491 0.0723
2013 0.0469 0.1274 0.4097 0.436 0.1542 0.075
2014 0.0606 0.1421 0.42 0.4259 0.1543 0.075
2015 0.0456 0.1306 0.4129 0.4297 0.1574 0.0765
2016 0.0493 0.1337 0.4145 0.4292 0.1563 0.0747
2017 0.0474 0.1298 0.4095 0.4323 0.1582 0.0758
2018 0.0456 0.128 0.4057 0.4331 0.1613 0.0775
2019 0.0505 0.1302 0.394 0.4362 0.1701 0.0836
2020 0.0399 0.1191 0.392 0.4424 0.166 0.0787
2021 0.0527 0.1436 0.4172 0.4234 0.1594 0.0771
2022 0.0524 0.144 0.4185 0.426 0.1555 0.0733
2023 0.0484 0.1401 0.4101 0.4287 0.1623 0.076
2024 0.0639 0.149 0.4063 0.4298 0.1639 0.0762
end
label var top01       "0,1% más rico"
label var top1        "1% más rico"
label var top10       "10% más rico"
label var clase_media "Clase media (P50-P90)"
label var bottom50    "50% más pobre"
label var bottom35    "35% más pobre"
export excel using "`libro_loc'", sheet("participacion_sri") firstrow(variables) sheetreplace
local ++escritas
di as txt "  hoja `escritas': participacion_sri  (`=_N' filas)  <- tecleada (SRI)"

* --- G05: crecimiento del PIB y Gini urbano ----------------------------------
* PIB real del Banco Central del Ecuador (cuentas nacionales anuales). El
* crecimiento y sus promedios por período se calculan aquí; el Gini urbano es
* el de gini_serie.
clear
input int anio double pib
1989 41169477633
1990 42684479026
1991 44516216200
1992 45457427300
1993 46354401500
1994 48328288000
1995 49416906200
1996 50272682300
1997 52448416000
1998 54161658900
1999 51594728900
2000 52158041000
2001 54351950000
2002 57030466000
2003 58675510000
2004 62684454000
2005 66068551000
2006 68936674000
2007 70248145000
2008 74859880000
2009 75676611000
2010 78725726000
2011 85402830000
2012 90341857000
2013 96856622000
2014 100949846000
2015 101070675000
2016 100375355000
2017 106368164000
2018 107478961000
2019 107656736000
2020 97703767200
2021 106909311300
2022 113183202500
2023 115433554100
2024 113123434600
end
sort anio
gen double crecimiento = pib / pib[_n - 1] - 1
gen byte periodo = 1 if inrange(anio, 1990, 1999)
replace periodo = 2 if inrange(anio, 2000, 2010)
replace periodo = 3 if inrange(anio, 2011, 2017)
replace periodo = 4 if inrange(anio, 2018, 2024)
bysort periodo: egen double prom = mean(crecimiento)
gen double prom_1990_1999 = prom if periodo == 1
gen double prom_2000_2010 = prom if periodo == 2
gen double prom_2011_2017 = prom if periodo == 3
gen double prom_2018_2024 = prom if periodo == 4
keep if inrange(anio, 1990, 2024)
merge 1:1 anio using `gini_ext', keep(1 3) keepusing(gini_urbano) nogen
sort anio
keep anio crecimiento prom_1990_1999 prom_2000_2010 prom_2011_2017 prom_2018_2024 gini_urbano
tabstat prom_*, stat(mean) format(%9.4f)
export excel using "`libro_loc'", sheet("pib_gini") firstrow(variables) sheetreplace
local ++escritas
di as txt "  hoja `escritas': pib_gini  (`=_N' filas)  <- PIB del BCE + gini_serie"

* --- G15: salario básico real y Gini nacional --------------------------------
* Remuneración unificada (salario básico) de diciembre, del BCE: la misma
* fuente que usa empleo_adecuado_simulacion.do (Bases/Salarios/Salario
* unificado y componentes salariales.csv). Hasta 2004 no incluye los
* componentes salariales que aún no se habían incorporado (40 dólares en 2000,
* 32 en 2001, 24 en 2002, 16 en 2003 y 8 en 2004). IPC nacional de
* diciembre de cada año (INEC, SERIE HISTORICA IPC_03_2026.xls, hoja
* "1. ÍNDICE", columna Diciembre; base 2014 = 100). El salario en dólares de
* 2015 (IPC de diciembre de 2015) se calcula aquí; el Gini nacional es el de
* gini_serie.
clear
input int anio double(salario_basico ipc)
2000 56.65 46.24681750954841
2001 85.65 56.62402055165688
2002 104.88 61.92162857372467
2003 121.91 65.68019431414154
2004 135.63 66.9580527022704
2005 150 69.05666489473454
2006 160 71.03817315164527
2007 170 73.39643195066293
2008 200 79.8777342342988
2009 218 83.32185735936669
2010 240 86.09483799697492
2011 264 90.75203690379746
2012 292 94.53086968974523
2013 318 97.08352647785513
2014 340 100.6439261877374
2015 354 104.0458168319987
2016 366 105.2109129900111
2017 375 105.0039625527603
2018 386 105.2834519759002
2019 394 105.2146669479185
2020 400 104.2330254802137
2021 400 106.2558533647232
2022 425 110.227316943081
2023 450 111.7151014167546
2024 460 112.3062637795425
2025 470 114.4568504904683
end
quietly summarize ipc if anio == 2015
local ipc15 = r(mean)
gen double salario_real = salario_basico * `ipc15' / ipc
tempfile ipc_ext
preserve
    keep anio ipc
    save `ipc_ext'
restore
merge 1:1 anio using `gini_ext', keep(1 3) keepusing(gini_nacional) nogen
* 2002 y 2004 no tienen base de ingresos de la ENEMDU (no hay Gini). Para que
* la línea del Gini no se corte, el gráfico va cada dos años desde 2001
* (2001, 2003, ..., 2025). El IPC de los años pares sigue en `ipc_ext',
* porque lo usa la hoja tributacion.
keep if mod(anio, 2) == 1
sort anio
export excel using "`libro_loc'", sheet("salario_basico") firstrow(variables) sheetreplace
local ++escritas
di as txt "  hoja `escritas': salario_basico  (`=_N' filas)  <- SBU + IPC + gini_serie"

* --- G16: rango superior del impuesto a la renta -----------------------------
* Límite inferior del rango superior y tasa marginal máxima (tablas del
* impuesto a la renta de personas naturales, SRI); sólo los años con cambios
* normativos. Se pasa a dólares de 2015 con el mismo IPC y a valor mensual.
clear
input int anio double(limite_usd tasa)
2002 49600 0.2
2006 61440 0.25
2008 62800 0.25
2010 90810 0.3
2018 114890 0.3
2019 115290.01 0.3
2020 115338.01 0.3
2023 105580 0.35
2024 107199 0.37
2025 108810 0.37
end
merge 1:1 anio using `ipc_ext', keep(1 3) nogen
gen double limite_2015 = limite_usd * `ipc15' / ipc
gen double valor_mensual_2015 = limite_2015 / 12
drop ipc
sort anio
export excel using "`libro_loc'", sheet("tributacion") firstrow(variables) sheetreplace
local ++escritas
di as txt "  hoja `escritas': tributacion  (`=_N' filas)  <- tablas del SRI + IPC"

*----------------------------------------------------------- libro del paper --
* El libro que queda en el Drive trae sólo las hojas que usan los gráficos del
* paper, en el orden de los gráficos. Las demás tablas se arman sólo en el
* libro local (de algunas salen hojas del paper) y siguen en el .xlsx de cada
* módulo, pero no pasan al libro final. Las hojas se copian tal cual: mismas
* columnas y filas, que es a donde apuntan los gráficos del Word.
*   gini_serie        Gráficos 1 y 2        brechas           Gráfico 12
*   palma_serie       Gráfico 3             prima_urbano      Gráfico 13
*   participacion_sri Gráfico 4             adecuado_urbano   Gráfico 14
*   pib_gini          Gráfico 5             salario_basico    Gráfico 15
*   gic_urbano        Gráfico 6             tributacion       Gráfico 16
*   gic_nacional      Gráfico 7             gini_sri          Gráfico 17
*   decomp_nacional   Gráficos 8 y 11
*   remesas_cuartil   Gráfico 9
*   bono_cuartil      Gráfico 10
local hojas_paper gini_serie palma_serie participacion_sri pib_gini ///
    gic_urbano gic_nacional decomp_nacional remesas_cuartil bono_cuartil ///
    brechas prima_urbano adecuado_urbano salario_basico tributacion gini_sri
tempfile tfin
local libro_fin "`tfin'.xlsx"
local en_libro = 0
local faltan_paper ""
foreach h of local hojas_paper {
    capture import excel "`libro_loc'", sheet("`h'") firstrow clear
    if _rc {
        local faltan_paper "`faltan_paper' `h'"
        continue
    }
    if (`en_libro' == 0) export excel using "`libro_fin'", sheet("`h'") firstrow(variables) replace
    else                 export excel using "`libro_fin'", sheet("`h'") firstrow(variables) sheetreplace
    local ++en_libro
}
if (`en_libro' > 0) copy "`libro_fin'" "$libro", replace

di as res _n "{hline 78}"
di as res "Libro consolidado: $libro"
di as res "Hojas armadas: `escritas' de `=`n' + 15'"
di as res "Hojas en el libro del paper: `en_libro' de `: word count `hojas_paper''"
if ("`faltan_paper'" != "") di as err "Faltan en el libro del paper:`faltan_paper'"
if ("`faltantes'" != "") di as err "Sin escribir:`faltantes'"
di as res "{hline 78}"

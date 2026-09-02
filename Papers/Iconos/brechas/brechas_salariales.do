*==============================================================================*
* BRECHAS SALARIALES POR GRUPO SOCIAL
* ENEMDU de diciembre, ámbito nacional. Ingreso laboral individual.
*
* Alimenta la hoja "brechas" del libro plots_sources_graficos.xlsx
* (Gráficos 12 y 13 del paper).
*
* Razones calculadas, todas sobre medias ponderadas del ingreso laboral:
*   Calificados = universitaria o más / hasta secundaria
*   Publico     = sector público / sector privado
*   Sexo        = hombres / mujeres
*   Etnia       = no indígenas / indígenas
* y los dos niveles de ingreso que grafica el Gráfico 13:
*   Ing_no Univ, Ing_Univ, en dólares constantes de 2015.
*
* Réplica del método de los Ind_<año>.do del Boletín 1.
*
* Fuente: Bases/ENEMDU/Procesadas/ingresos_pc/Nacional
*
* VALIDACIÓN: al final compara contra los valores que ya están en el libro.
*==============================================================================*

clear all

* Raíz del Google Drive: Windows (H:) o macOS. La respeta si ya viene
* definida por el master.
if "$gd" == "" {
    if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
    else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
}

set more off
set varabbrev off

global nac "$gd/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
global out "$gd/Papers/Íconos/outputs/brechas"

capture mkdir "$gd/Papers/Íconos/outputs"
capture mkdir "$out"

*------------------------------------------------------------------------------
* IPC nacional de diciembre, base 2015 = 104,046.
* Literal, tomado de "Copia de Cuadros_Boletin_1.xlsx", hoja PIB_Gini, columna S,
* que es la serie que usa el Observatorio. Sólo se usa para pasar los NIVELES
* de ingreso a dólares de 2015; las razones no dependen del deflactor.
*------------------------------------------------------------------------------
matrix IPC = (2000, 46.246818 \ 2001, 56.624021 \ 2002, 61.921629 \ ///
              2003, 65.680194 \ 2004, 66.958053 \ 2005, 69.056665 \ ///
              2006, 71.038173 \ 2007, 73.396432 \ 2008, 79.877734 \ ///
              2009, 83.321857 \ 2010, 86.094838 \ 2011, 90.752037 \ ///
              2012, 94.530870 \ 2013, 97.083526 \ 2014, 100.643926 \ ///
              2015, 104.045817 \ 2016, 105.210913 \ 2017, 105.003963 \ ///
              2018, 105.283452 \ 2019, 105.214667 \ 2020, 104.233025 \ ///
              2021, 106.255853 \ 2022, 110.227317 \ 2023, 111.715101 \ ///
              2024, 112.306264 \ 2025, 114.810000)
scalar ipc_base = 104.045817          // diciembre de 2015

*==============================================================================*
* 1. CÁLCULO POR AÑO
*==============================================================================*

tempname pf
tempfile res
postfile `pf' int anio double(ing_no_univ ing_univ calificados publico ///
    sexo etnia N) using "`res'", replace

forvalues y = 2001/2025 {

    local f "$nac/ing_perca_`y'_nac_precios2000.dta"
    capture confirm file "`f'"
    if _rc continue

    qui describe using "`f'", varlist
    local vl = r(varlist)

    *--------------------------------------------------------------------------
    * Nombres de variables según el formulario del año.
    *   hasta 2006: nivinst / sexo / pe14 / catetrab, ingreso en ing_lab
    *   desde 2007: p10a / p02 / p15 / p42,          ingreso en ingrl
    * Autoidentificación indígena: pe14==3 en el formulario viejo, p15==1 en el
    * nuevo. Verificado contra los valores del libro (2001 y 2011).
    *--------------------------------------------------------------------------
    local hasp10a  : list posof "p10a"  in vl
    local hasingrl : list posof "ingrl" in vl

    if (`hasp10a') {
        local educvar p10a
        local univc   "inlist(p10a,9,10)"
    }
    else {
        local educvar nivinst
        if (`y' == 2001)      local univc "inlist(nivinst,6,7)"
        else if (`y' == 2002) local univc "inlist(nivinst,7,8)"
        else                  local univc "inlist(nivinst,9,10)"
    }
    if (`hasingrl') local iv ingrl
    else            local iv ing_lab

    * Las demás se resuelven por presencia: el nombre cambia de año a año y no
    * siempre acompaña al cambio de formulario.
    local sexvar
    foreach v in p02 sexo {
        local hit : list posof "`v'" in vl
        if `hit' & "`sexvar'" == "" local sexvar `v'
    }
    local catvar
    foreach v in p42 catetrab {
        local hit : list posof "`v'" in vl
        if `hit' & "`catvar'" == "" local catvar `v'
    }
    * Autoidentificación indígena. El nombre y el código cambian con el
    * formulario; se resuelve por presencia, en este orden de preferencia:
    *   p15 == 1   desde 2007      (verificado: 2011 -> 1.67, igual que el libro)
    *   pe14 == 3  2001-2002       (verificado: 2001 -> 1.63, igual que el libro)
    *   pe13 == 1  2003-2006       (verificado: 2005 -> 1.78, igual que el libro)
    local etnvar
    local indigc
    foreach v in p15 pe14 pe13 {
        local hit : list posof "`v'" in vl
        if `hit' & "`etnvar'" == "" {
            local etnvar `v'
            if ("`v'" == "pe14") local indigc 3
            else                 local indigc 1
        }
    }

    if ("`sexvar'" == "" | "`catvar'" == "") {
        di as error "`y': faltan variables de sexo o categoría; se omite"
        continue
    }

    qui use `iv' `educvar' `sexvar' `catvar' `etnvar' fexp using "`f'", clear

    * códigos de no respuesta del ingreso laboral
    qui recode `iv' (-1 = .) (999999 = .) (0 = .)
    qui keep if !missing(`iv') & `iv' > 0 & !missing(fexp) & fexp > 0

    gen byte univ  = `univc'
    if ("`etnvar'" != "") gen byte indig = (`etnvar' == `indigc') if !missing(`etnvar')
    else                  gen byte indig = .
    gen byte publico = .
    qui replace publico = 1 if `catvar' == 1      // empleado del Estado
    qui replace publico = 0 if `catvar' == 2      // empleado privado

    * deflactor del año a dólares de 2015
    local fac = .
    forvalues r = 1/`=rowsof(IPC)' {
        if (IPC[`r',1] == `y') local fac = ipc_base / IPC[`r',2]
    }
    if (`fac' == .) {
        di as error "Sin IPC para `y': se omite el año"
        continue
    }

    qui su `iv' [w=round(fexp)] if univ == 0
    local a = r(mean)
    local n = r(N)
    qui su `iv' [w=round(fexp)] if univ == 1
    local b = r(mean)
    qui su `iv' [w=round(fexp)] if publico == 1
    local pu = r(mean)
    qui su `iv' [w=round(fexp)] if publico == 0
    local pr = r(mean)
    qui su `iv' [w=round(fexp)] if `sexvar' == 1
    local h = r(mean)
    qui su `iv' [w=round(fexp)] if `sexvar' == 2
    local m = r(mean)
    qui su `iv' [w=round(fexp)] if indig == 0
    local ni = r(mean)
    qui su `iv' [w=round(fexp)] if indig == 1
    local si = r(mean)

    post `pf' (`y') (`a'*`fac') (`b'*`fac') (`b'/`a') (`pu'/`pr') ///
        (`h'/`m') (`ni'/`si') (`n')

    di as txt "`y' (`iv'): no_univ=" %8.2f `a'*`fac' "  univ=" %8.2f `b'*`fac' ///
        "  calif=" %5.2f `b'/`a' "  pub=" %5.2f `pu'/`pr' ///
        "  sexo=" %5.2f `h'/`m' "  etnia=" %5.2f `ni'/`si'
}
postclose `pf'

*==============================================================================*
* 2. TABLA
*==============================================================================*

use "`res'", clear

label var anio        "Año"
label var ing_no_univ "Ingreso laboral medio, sin universidad (USD 2015)"
label var ing_univ    "Ingreso laboral medio, con universidad (USD 2015)"
label var calificados "Brecha calificados / no calificados"
label var publico     "Brecha sector público / privado"
label var sexo        "Brecha hombres / mujeres"
label var etnia       "Brecha no indígenas / indígenas"
label var N           "Observaciones"

format ing_* %8.2f
format calificados publico sexo etnia %5.3f

sort anio
list, noobs

save "$out/brechas_salariales.dta", replace
export excel using "$out/brechas_salariales.xlsx", ///
    sheet("brechas") firstrow(varlabels) replace

*==============================================================================*
* 3. VALIDACIÓN CONTRA EL LIBRO DE GRÁFICOS
*==============================================================================*

di as res _n "{hline 78}"
di as res "VALIDACIÓN — hoja 'brechas' del libro"
di as res "{hline 78}"

* año, no_univ, univ, calificados, publico, sexo, etnia (valores del libro)
matrix REF = (2001, 280.7743, 757.9556, 2.70, 1.28, 1.49, 1.63 \ ///
              2003, 246.7743, 702.1032, 2.85, 1.59, 1.39, 1.61 \ ///
              2005, 308.3318, 845.2156, 2.74, 1.64, 1.32, 1.78 \ ///
              2007, 370.3691, 1057.4845, 2.86, 1.97, 1.37, 1.91 \ ///
              2009, 392.2498, 949.4302, 2.42, 2.05, 1.28, 1.69 \ ///
              2011, 465.2606, 997.1162, 2.14, 2.02, 1.25, 1.67 \ ///
              2013, 518.6021, 1306.9920, 2.52, 1.79, 1.26, 1.66 \ ///
              2023, 443.4144, 990.9869, 2.23, 1.98, 1.18, 1.60)

di as txt "  año   calif c/l    publico c/l    sexo c/l     etnia c/l"
forvalues i = 1/`=rowsof(REF)' {
    local y = REF[`i',1]
    qui su calificados if anio==`y'
    local c1 = cond(r(N)>0, r(mean), .)
    qui su publico if anio==`y'
    local c2 = cond(r(N)>0, r(mean), .)
    qui su sexo if anio==`y'
    local c3 = cond(r(N)>0, r(mean), .)
    qui su etnia if anio==`y'
    local c4 = cond(r(N)>0, r(mean), .)
    di as txt "  " %4.0f `y' "  " %5.2f `c1' "/" %4.2f REF[`i',4] ///
        "   " %5.2f `c2' "/" %4.2f REF[`i',5] ///
        "   " %5.2f `c3' "/" %4.2f REF[`i',6] ///
        "   " %5.2f `c4' "/" %4.2f REF[`i',7]
}

di as err _n "NOTA sobre los NIVELES de ingreso (columnas Ing_no Univ e Ing_Univ):"
di as err "no coinciden con el libro, y la diferencia es un error del libro."
di as err "Allí cada fila se deflactó con el factor de la fila correspondiente de"
di as err "la tabla anual de factores, que empieza en 2000, mientras que la serie"
di as err "de brechas es bienal y empieza en 2001. Resultado: 2001 quedó con el"
di as err "factor de 2000, 2003 con el de 2001, 2005 con el de 2002, y así."
di as err "Este do-file aplica a cada año su propio factor. Las cuatro razones no"
di as err "se ven afectadas porque el factor se cancela."

di as res _n "Salidas en: $out"

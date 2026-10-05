*==============================================================================*
* BRECHAS SALARIALES POR GRUPO SOCIAL
* ENEMDU de diciembre, ámbito nacional. Ingreso laboral individual.
*
* Alimenta la hoja "brechas" de Iconos_resultados.xlsx (la arma
* consolidar_excel.do), que dibuja el Gráfico 12 del paper.
*
* Razones calculadas, todas sobre medias ponderadas del ingreso laboral:
*   Calificados = universitaria o más / hasta secundaria
*   Publico     = sector público / sector privado
*   Sexo        = hombres / mujeres
*   Etnia       = no indígenas / indígenas
* y los dos niveles de ingreso, sin y con universidad, en dólares de 2015.
*
* Mismo método que los Ind_<año>.do del Boletín 1, pero siempre sobre la ENEMDU
* de diciembre: los Ind_2019/2021/2023.do usan la ENEMDU anual (todos los meses
* juntos), así que sus valores de esos años no son comparables con éstos.
*
* Fuente: Bases/ENEMDU/Procesadas/ingresos_pc/Nacional
*
* COMPARACIÓN: al final compara con la hoja "brechas" de la última corrida
* (Iconos_resultados.xlsx), para ver qué cambió.
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
global brechas_out "$gd/Papers/Íconos/outputs/brechas"

capture mkdir "$gd/Papers/Íconos/outputs"
capture mkdir "$brechas_out"

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
              2024, 112.306264 \ 2025, 114.456850)
scalar ipc_base = 104.045817          // diciembre de 2015

*==============================================================================*
* 1. CÁLCULO POR AÑO
*==============================================================================*

tempname pf
tempfile res
postfile `pf' int anio double(ing_no_univ ing_univ calificados publico ///
    sexo etnia N) using "`res'", replace

* 2025 se mantiene, pero está distorsionado. En 2025 el Gobierno adelantó el
* décimo tercer sueldo del sector público al 11-14 de noviembre (Acuerdo
* MDT-2025-164), y la ENEMDU de diciembre pregunta por el ingreso del mes
* anterior: una parte de los empleados públicos declaró noviembre más el
* décimo. Su salario mediano sube 49 % sin que suban los descuentos al IESS
* (el décimo no aporta), y el 20 % declara el doble de la base implícita en
* sus descuentos (0,1-0,4 % en 2022-2024). La brecha público/privado salta a
* 2,47 (1,8-1,9 en los años previos) y la de calificados también se infla.
* El paper lo advierte en una nota bajo el Gráfico 12.
forvalues y = 2001/2025 {

    local f "$nac/ing_perca_`y'_nac_precios2000.dta"
    capture confirm file "`f'"
    if _rc continue

    qui describe using "`f'", varlist
    local vl = r(varlist)

    *--------------------------------------------------------------------------
    * Nombres de variables según el formulario del año.
    *   hasta 2006: nivinst / sexo / pe14 / catetrab
    *   desde 2007: p10a / p02 / p15 / p42
    * Autoidentificación indígena: pe14==3 en el formulario viejo, p15==1 en el
    * nuevo. Verificado contra los valores del libro (2001 y 2011).
    *--------------------------------------------------------------------------
    local hasp10a  : list posof "p10a"  in vl

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

    * Ingreso laboral: ing_lab en todos los años, que existe en todas las bases.
    * Antes se tomaba ingrl cuando la base lo traía, pero 2006 es la única base
    * previa a 2010 que lo trae, y con los códigos de no respuesta de ese año sin
    * limpiar (999, 9999, 22150, 99999): la serie cambiaba de variable en 2006 y
    * volvía a ing_lab en 2007, con un salto falso (calificados 2,54 en vez de
    * 2,77). De 2010 en adelante las dos variables coinciden salvo en 1-19
    * personas por año: las que sólo tienen ingreso en especie (p68b, p70b) o
    * retiro de bienes del negocio (p64b), que ingrl deja en missing e ing_lab
    * cuenta. Sólo se nota en 2020-2021, con muestras chicas (hasta 0,02).
    local iv ing_lab

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
    * Sector privado: empleado privado (código 2). En el formulario de 2001 los
    * asalariados agrícolas tienen código propio (7, "trab. agrop. a sueldo");
    * desde 2003 esa categoría desaparece y quedan dentro del 2. Se suman en
    * 2001 para que el grupo sea el mismo en toda la serie. OJO: desde 2003 el
    * código 7 es "cuenta propia", por eso la regla va sólo para 2001.
    if (`y' == 2001) local privc "inlist(`catvar', 2, 7)"
    else             local privc "`catvar' == 2"

    gen byte publico = .
    qui replace publico = 1 if `catvar' == 1      // empleado del Estado
    qui replace publico = 0 if `privc'            // empleado privado

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

save "$brechas_out/brechas_salariales.dta", replace
export excel using "$brechas_out/brechas_salariales.xlsx", ///
    sheet("brechas") firstrow(varlabels) replace

*==============================================================================*
* 3. COMPARACIÓN CON LA ÚLTIMA CORRIDA
*
* Compara las cuatro razones con la hoja "brechas" de Iconos_resultados.xlsx,
* el libro que armó consolidar_excel.do en la corrida anterior del master. No
* es una validación contra una fuente externa: sirve para ver qué años
* cambiaron desde la última vez. Si el libro no existe, se omite.
*==============================================================================*

di as res _n "{hline 78}"
di as res "COMPARACIÓN — hoja 'brechas' de Iconos_resultados.xlsx (corrida anterior)"
di as res "{hline 78}"

local libro "$gd/Papers/Íconos/outputs/Iconos_resultados.xlsx"
capture confirm file "`libro'"
if _rc di as txt "No existe `libro': se omite la comparación."
else {
    * Stata no abre .xlsx directamente sobre Google Drive (r(603)): se copia a
    * disco local primero, igual que en consolidar_excel.do.
    tempfile tlib
    local libro_loc "`tlib'.xlsx"
    qui copy "`libro'" "`libro_loc'", replace
    capture import excel "`libro_loc'", sheet("brechas") firstrow clear
    if _rc di as txt "El libro no tiene la hoja 'brechas': se omite la comparación."
    else {
        * Columnas por posición, porque los encabezados son las etiquetas de
        * variable: 1 año, 4 calificados, 5 público, 6 sexo, 7 etnia.
        unab todas : _all
        local va : word 1 of `todas'
        local vc : word 4 of `todas'
        local vp : word 5 of `todas'
        local vs : word 6 of `todas'
        local ve : word 7 of `todas'
        keep `va' `vc' `vp' `vs' `ve'
        rename (`va' `vc' `vp' `vs' `ve') ///
               (anio calificados_ant publico_ant sexo_ant etnia_ant)
        tempfile ant
        qui save `ant'

        use "$brechas_out/brechas_salariales.dta", clear
        qui merge 1:1 anio using `ant'

        gen double dmax = 0
        foreach v in calificados publico sexo etnia {
            qui replace dmax = max(dmax, abs(`v' - `v'_ant)) if _merge == 3
        }
        format *_ant %5.3f

        qui count if _merge == 3 & dmax > 0.005
        local n_cambio = r(N)
        qui count if _merge != 3
        local n_solo = r(N)
        if (`n_cambio' + `n_solo' == 0) {
            di as txt "Sin cambios: las cuatro razones coinciden en todos los años."
        }
        else {
            di as txt "Años que cambiaron (diferencia > 0,005) o que están en una sola corrida:"
            list anio calificados calificados_ant publico publico_ant ///
                 sexo sexo_ant etnia etnia_ant _merge ///
                 if dmax > 0.005 | _merge != 3, noobs abbrev(14) sep(0)
            di as txt "_merge: 1 = sólo en esta corrida, 2 = sólo en la anterior."
        }
    }
}

di as res _n "Salidas en: $brechas_out"

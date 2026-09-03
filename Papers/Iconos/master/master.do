*==============================================================================*
* MASTER — PAPER "ÍCONOS"
* Evolución de la desigualdad en Ecuador en el siglo XXI
*
* Corre, en orden, los do-files que generan los datos de cada hoja del libro
*     H:/Mi unidad/Papers/Íconos/plots_sources_graficos.xlsx
* que es el que contiene los gráficos del paper.
*
* Cada bloque se puede prender o apagar con las banderas de la sección 1.
* Los do-files hijos respetan el global $gd que fija este master; si se corren
* sueltos, cada uno lo define por su cuenta según el sistema operativo.
*
* IMPORTANTE: la sección 5 lista las hojas del libro que HOY NO tienen código.
*==============================================================================*

clear all
set more off
set varabbrev off

*==============================================================================*
* 1. CONFIGURACIÓN
*==============================================================================*

* Raíz del Google Drive: Windows (H:) o macOS.
if "`c(os)'" == "Windows" global gd "H:/Mi unidad"
else global gd "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"

* Raíz del repositorio (donde vive este archivo).
if "`c(os)'" == "Windows" global repo "C:/Users/santy/Documents/GitHub/Observatorio-Desigualdad-Pobreza"
else global repo "~/Documents/GitHub/Observatorio-Desigualdad-Pobreza"

global cod "$repo/Papers/Iconos"
global out "$gd/Papers/Íconos/outputs"

capture mkdir "$gd/Papers/Íconos"
capture mkdir "$out"
capture mkdir "$out/logs"

* Banderas: 1 = correr, 0 = saltar.
global run_decomp    1     // gini_decomp     (Gráficos 8, 9, 10, 11)
global run_prima     1     // prima_salarial  (Gráficos 16, 17)
global run_adecuado  1     // empleo_adec     (Gráfico 15)
global run_rama      1     // panel_educ_pleno(Gráficos 21, 22)
global run_calif     1     // panel_crecimiento (Gráficos 17-20)
global run_ginipalma 1     // gini y palma   (Gráficos 1, 2, 3)
global run_brechas   1     // brechas        (Gráficos 12, 13)
global run_gic       0     // GIC (Gráficos 5, 6, 7) — ver nota en la sección 4
global run_sri       0     // ineq_SRI (Gráfico 3) — ver nota en la sección 4
global run_consolid  1     // junta todos los Excel en un solo libro (sección 4b)

* Si un bloque falla, el master sigue con el siguiente y lo reporta al final.
global fallos ""

*==============================================================================*
* 2. UTILIDAD DE EJECUCIÓN
*
* No se usa `program define` a propósito: el equipo trabaja con do-files
* inline. Cada bloque repite estas cuatro líneas.
*==============================================================================*

local hoy = subinstr("`c(current_date)'", " ", "_", .)

*==============================================================================*
* 3. BLOQUES QUE SÍ TIENEN CÓDIGO
*==============================================================================*

*------------------------------------------------------------------------------
* 3.0 Serie del Gini y del Palma -> hojas gini y palma (Gráficos 1, 2 y 3)
*     Salida: $out/desigualdad/gini_palma_serie.dta
*             $out/desigualdad/gini_palma_tablas.xlsx
*     El do-file imprime la comparación al final.
*------------------------------------------------------------------------------
if $run_ginipalma {
    di as res _n "=== [0/7] Serie del Gini y del Palma ==="
    capture noisily do "$cod/desigualdad/gini_palma_serie.do"
    if _rc global fallos "$fallos gini_palma_serie(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.0b Brechas salariales -> hoja brechas (Gráficos 12 y 13)
*      Salida: $out/brechas/brechas_salariales.dta / .xlsx
*      Las cuatro razones reproducen el libro. Los NIVELES de ingreso no,
*      porque el libro se deflactó con un factor desalineado por fila; este
*      do-file aplica a cada año el suyo. Ver la nota al final del do-file.
*------------------------------------------------------------------------------
if $run_brechas {
    di as res _n "=== [0b/7] Brechas salariales ==="
    capture noisily do "$cod/brechas/brechas_salariales.do"
    if _rc global fallos "$fallos brechas_salariales(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.1 Descomposición del Gini  -> hoja gini_decomp (Gráficos 8, 9, 10, 11)
*     Salida: $out/Gini decomposition/gini_decomposition_cuartiles.xlsx
*             (la sección 7 del do-file es la que produce los cuartiles)
*------------------------------------------------------------------------------
if $run_decomp {
    di as res _n "=== [1/5] Descomposición del Gini ==="
    capture noisily do "$cod/desigualdad/gini_decomp5.do"
    if _rc global fallos "$fallos gini_decomp5(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.2 Prima salarial por hora -> hoja prima_salarial (Gráficos 16 y 17)
*     Salida: $out/educ_ingrl/hora_coef_educ_ingrl.dta
*             $out/educ_ingrl/prima_hora_tablas.xlsx
*------------------------------------------------------------------------------
if $run_prima {
    di as res _n "=== [2/5] Prima salarial por hora ==="
    capture noisily do "$cod/mincer/educ_ingrl_hora.do"
    if _rc global fallos "$fallos educ_ingrl_hora(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.3 Empleo adecuado -> hoja empleo_adec (Gráfico 15)
*     Salida: $out/empleo adecuado/serie_empleo_adecuado_1991_2025.*
*------------------------------------------------------------------------------
if $run_adecuado {
    di as res _n "=== [3/5] Empleo adecuado ==="
    capture noisily do "$cod/empleo adecuado/empleo_adecuado_serie.do"
    if _rc global fallos "$fallos empleo_adecuado_serie(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.4 Empleo pleno y educación por rama -> hoja panel_educ_pleno (G. 21 y 22)
*     Salida: $out/empleo adecuado/base_rama_educ.dta / .csv
*------------------------------------------------------------------------------
if $run_rama {
    di as res _n "=== [4/5] Empleo pleno por rama ==="
    capture noisily do "$cod/empleo adecuado/empleo_pleno_rama.do"
    if _rc global fallos "$fallos empleo_pleno_rama(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 3.5 Crecimiento del empleo por rama -> hoja panel_crecimiento (G. 17 a 20)
*     Salida: $out/rama_educ/base_crecimiento.dta
*             $out/rama_educ/crecimiento_empleo.xlsx
*------------------------------------------------------------------------------
if $run_calif {
    di as res _n "=== [5/5] Crecimiento del empleo por calificación ==="
    capture noisily do "$cod/calificados_vs_no_calificados/empleo_calificados.do"
    if _rc global fallos "$fallos empleo_calificados(_rc=`=_rc')"
}

*==============================================================================*
* 4. BLOQUES CUYO CÓDIGO VIVE FUERA DE Papers/Iconos
*
* Existen y funcionan, pero pertenecen a otras carpetas del repositorio. Se
* dejan apagados por defecto porque son lentos y sus salidas ya están
* generadas. Prender la bandera correspondiente en la sección 1 para correrlos.
*==============================================================================*

*------------------------------------------------------------------------------
* 4.1 Curvas de incidencia del crecimiento -> hoja GIC (Gráficos 5, 6 y 7)
*     Código: Dashboards/codigo/gic_curves.do
*     Salida: Boletín 1/Outcomes/Curvas de crecimiento/GIC_exports/tables/xlsx/
*             gic_{nac,urb}_<año base>_<año final>.xlsx
*     Requiere antes: Boletín 1/Procesamiento/Codigos/Ingresos/
*                     ingresos_anios_all_fn.do (arma ingresos_pc y necesita IPC)
*------------------------------------------------------------------------------
if $run_gic {
    di as res _n "=== [extra] Curvas de incidencia del crecimiento ==="
    capture noisily do "$repo/Dashboards/codigo/gic_curves.do"
    if _rc global fallos "$fallos gic_curves(_rc=`=_rc')"
}

*------------------------------------------------------------------------------
* 4.2 Participación en el ingreso, registros del SRI -> hoja ineq_SRI (G. 3)
*     Código: SRI/Procesamiento/Codigos/Renta/renta_percentiles.do
*     Nota: corre sobre microdatos tributarios, no sobre ENEMDU.
*------------------------------------------------------------------------------
if $run_sri {
    di as res _n "=== [extra] Percentiles de ingreso, SRI ==="
    capture noisily do "$repo/SRI/Procesamiento/Codigos/Renta/renta_percentiles.do"
    if _rc global fallos "$fallos renta_percentiles(_rc=`=_rc')"
}

*==============================================================================*
* 4b. LIBRO ÚNICO CON TODAS LAS TABLAS
*
* Cada do-file escribe su propio .xlsx en su carpeta. Este bloque junta todas
* esas hojas en un solo libro, con una hoja de índice que dice de dónde viene
* cada tabla:
*     $out/Iconos_resultados.xlsx
*==============================================================================*

if $run_consolid {
    di as res _n "=== [final] Libro consolidado ==="
    capture noisily do "$cod/master/consolidar_excel.do"
    if _rc global fallos "$fallos consolidar_excel(_rc=`=_rc')"
}

*==============================================================================*
* 5. CÓDIGOS FALTANTES
*
* Hojas del libro de gráficos que HOY no tienen do-file que las genere.
* Sus valores están tecleados a mano o copiados de otros archivos.
*==============================================================================*

di as err _n "{hline 78}"
di as err "HOJAS SIN CÓDIGO GENERADOR"
di as err "{hline 78}"

di as txt "Ya no falta código para gini, palma ni brechas: los generan"
di as txt "gini_palma_serie.do y brechas_salariales.do (bloques 3.0 y 3.0b)."
di as txt ""
di as txt "Quedan tres hojas que no se generan desde las bases porque su fuente"
di as txt "no es la ENEMDU:"
di as txt ""
di as txt "1) PIB (Gráfico 4) — Banco Central del Ecuador."
di as txt "2) sal_min (Gráfico 14) — Ministerio del Trabajo + IPC."
di as txt "3) tributacion (Gráfico 23) — tablas del impuesto a la renta del SRI."
di as txt "   Se copian de Cuadros_Boletin_1_sv.xlsx, hoja 'Impuesto a la renta'."
di as txt ""
di as txt "Y dos series del libro que NO reproducen a los do-files:"
di as txt ""
di as txt "a) palma: el pie del Gráfico 3 cita CEPALSTAT. El Palma calculado"
di as txt "   sobre la ENEMDU da valores distintos (2001: 4.91 nacional contra"
di as txt "   5.61 en el libro). Hay que decidir cuál se publica."
di as txt "b) brechas, columnas de NIVEL de ingreso: el libro las deflactó con"
di as txt "   un factor desalineado por fila (2001 recibió el factor de 2000,"
di as txt "   2003 el de 2001, y así). Las razones no se ven afectadas."

*==============================================================================*
* 6. CIERRE
*==============================================================================*

di as res _n "{hline 78}"
if ("$fallos" == "") di as res "Todos los bloques corrieron sin error."
else di as err "Bloques con error:$fallos"
di as res "Salidas en: $out"
di as res "{hline 78}"

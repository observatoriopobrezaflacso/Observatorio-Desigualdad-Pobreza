*------------------------------------------------------------------------------*
* 00_config.do — Rutas y parametros comunes (Pobreza laboral, Boletin 3)
*------------------------------------------------------------------------------*
* Detecta la raiz de Google Drive segun el usuario de la maquina, en lugar de
* fijar "/Users/vero/...". Si se agrega un colaborador, basta con anadir su caso.
*------------------------------------------------------------------------------*

clear all
set more off
version 15.1
set varabbrev off

local u = c(username)

if "`u'" == "vero" {
    global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
    global gh_root   "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"
}
else if "`u'" == "santiago" {
    global user_root "/Users/santiago/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
    global gh_root   "/Users/santiago/Documents/GitHub/Observatorio-Desigualdad-Pobreza"
}
else {
    display as error "Usuario `u' no configurado en 00_config.do. Defina user_root y gh_root."
    error 198
}

capture confirm file "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional/ing_perca_2001_nac_precios2000.dta"
if _rc {
    display as error "No se encuentra la carpeta de bases en: $user_root"
    error 601
}

global nacional    "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"
global lineas_xlsx "$user_root/Bases/lineas_pobreza/lineas_de_pobreza_historica.xlsx"

* Salidas en carpeta propia: NO se sobrescriben los resultados publicados.
global outdir   "$user_root/Boletín 3/4. Resultados/pobreza laboral/corregido"
global paneldir "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza"

capture mkdir "$user_root/Boletín 3/4. Resultados/pobreza laboral"
capture mkdir "$outdir"
capture mkdir "$paneldir"

* Anios procesados: rondas de diciembre disponibles a nivel nacional.
global anios "2001(2)2007 2008(1)2025"

display as text "Configuracion lista para usuario `u'."

/*******************************************************************************
* Descarga automática de Base de Datos SPSS - ENEMDU
*
* Descarga desde el portal BIINEC de Ecuador en Cifras:
*   aplicaciones3.ecuadorencifras.gob.ec/BIINEC-war/
*
* Guarda los .sav en Automatizacion/Bases/ENEMDU/ENEMDU/{year}/{mm}/
*
* Configurar año y mes abajo antes de ejecutar.
*******************************************************************************/


clear all
set more off

* ============================================================================
* 1. CONFIGURACIÓN — Modificar año y mes aquí
* ============================================================================

local year  2024
local month 06

* ============================================================================
* 2. RUTAS
* ============================================================================

global basedir "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Automatizacion"

local mm : display %02.0f `month'
local destdir "$basedir/Bases/ENEMDU/ENEMDU/`year'/`mm'"

capture mkdir "$basedir/Bases/ENEMDU/ENEMDU/`year'"
capture mkdir "`destdir'"

* ============================================================================
* 3. CONSTRUIR URL DEL PORTAL BIINEC
* ============================================================================

* Nombre del mes en mayúsculas para la URL del portal
local mname_01 "ENERO"
local mname_02 "FEBRERO"
local mname_03 "MARZO"
local mname_04 "ABRIL"
local mname_05 "MAYO"
local mname_06 "JUNIO"
local mname_07 "JULIO"
local mname_08 "AGOSTO"
local mname_09 "SEPTIEMBRE"
local mname_10 "OCTUBRE"
local mname_11 "NOVIEMBRE"
local mname_12 "DICIEMBRE"

local mesname "`mname_`mm''"

* URL del portal BIINEC con parámetros
local biinec_url "https://aplicaciones3.ecuadorencifras.gob.ec/BIINEC-war/index.xhtml?oe=ENEMDU&a=`year'&m=`mm'.%20`mesname'&t=Bases%20de%20datos%20Homologadas"

local zipfile "`destdir'/1_BDD_ENEMDU_`year'_`mm'_SPSS.zip"
local cookiefile "/tmp/biinec_cookies_`year'_`mm'.txt"

display as text _n "Portal BIINEC: `biinec_url'" _n

* ============================================================================
* 4. DESCARGAR (requiere 2 pasos: GET para sesión, POST para archivo)
* ============================================================================

display as text "Paso 1: Obteniendo sesión del portal BIINEC ..."

* GET para obtener cookie de sesión y ViewState
shell curl -k -s -c "`cookiefile'" "`biinec_url'" -o /tmp/biinec_page.html

* Extraer ViewState del HTML
tempname fh
file open `fh' using "/tmp/biinec_page.html", read text
local viewstate ""
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "javax.faces.ViewState") > 0 {
        local vs_start = strpos(`"`macval(line)'"', `"value=""') + 7
        local vs_rest  = substr(`"`macval(line)'"', `vs_start', .)
        local vs_end   = strpos(`"`macval(vs_rest)'"', `"""') - 1
        local viewstate = substr(`"`macval(vs_rest)'"', 1, `vs_end')
    }
    file read `fh' line
}
file close `fh'

if "`viewstate'" == "" {
    display as error "ERROR: No se pudo obtener el ViewState del portal."
    exit 1
}

display as text "ViewState obtenido: `viewstate'"
display as text "Paso 2: Descargando Base de Datos SPSS ..."

* POST para descargar el archivo (botón índice 1 = SPSS)
shell curl -k -s -b "`cookiefile'" -o "`zipfile'" -X POST "https://aplicaciones3.ecuadorencifras.gob.ec/BIINEC-war/index.xhtml" --data-urlencode "frmBi=frmBi" --data-urlencode "frmBi:lstArchDescarga:1:btnDescarga=frmBi:lstArchDescarga:1:btnDescarga" --data-urlencode "javax.faces.ViewState=`viewstate'"

* Verificar que se descargó
confirm file "`zipfile'"
display as result "Descarga completada."

* ============================================================================
* 5. DESCOMPRIMIR
* ============================================================================

display as text "Descomprimiendo ..."
shell unzip -o "`zipfile'" -d "`destdir'"
display as result "Descompresión completada."

* ============================================================================
* 6. LIMPIAR
* ============================================================================

erase "`zipfile'"
capture erase "`cookiefile'"
capture erase "/tmp/biinec_page.html"

display as result _n "Archivos guardados en: `destdir'"
dir "`destdir'", wide

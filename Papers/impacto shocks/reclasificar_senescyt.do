/*******************************************************************************
* reclasificar_senescyt.do
*
* APLICA reclasificar_formacion.do AL REGISTRO DE TITULOS DE SENESCYT
* (cruce_FLACSO_051218.dta) Y GUARDA LA BASE CON LA CLASIFICACION CORREGIDA
*
* reclasificar_formacion.do (Issue 59) reconstruye el nivel de cada titulo a
* partir de su NOMBRE, porque la clasificacion de la fuente no es confiable
* (doctorados profesionales pre-LOES contados como PhD, grados contados como
* posgrados, etc.). Es un MODULO: clasifica lo que esta en memoria y espera
* ciertos nombres de variables. Este do-file arma esos insumos con las
* variables de cruce_FLACSO_051218, corre el modulo y guarda.
*
*   el modulo espera        se arma con (cruce_FLACSO_051218)
*   ---------------------   ----------------------------------------------------
*   nombre_titulo           nombretitulo
*   nombre_universidad      nombreinstitucion
*   ecuador (1 = Ecuador)   tipo_titulo == "NACIONAL" (coincide 100% con
*                           nombre_pais == "ECUADOR"). Sin esto el modulo asume
*                           que todo es ecuatoriano y clasifica mal los PhD
*                           extranjeros.
*   year_registro           anio de fecha_registro (texto "AAAA-MM-DD ...")
*   fecha_acta_grado_2      fecha_acta_grado (texto) -> fecha de Stata. Falta
*                           en ~34%; el modulo usa entonces el anio de registro.
*   tipo_formacion          niveldeformacion, llevado a los codigos del modulo:
*   nivel_formacion            Nivel Tecnico Superior, TECNICO,
*                                Educacion Tecnica Superior...  -> nivel_tecnico
*                              TECNOLOGICO,
*                                Educacion Tecnologica Superior... -> nivel_tecnologico
*                              Tercer Nivel o Pregrado, TERCER_NIVEL -> tercer_nivel
*                              Cuarto Nivel o Posgrado, CUARTO_NIVEL ->
*                                tipo otro_cuarto_nivel, nivel cuarto_nivel
*                           El modulo los usa para no tocar los titulos que la
*                           fuente ya da como tecnicos, para los "Doctor en..."
*                           del exterior que la fuente da como tercer nivel, y
*                           para el diagnostico.
*
* SALIDA: la base original completa + las variables del modulo
*     tipo_formacion_c   tipo corregido (tercer_nivel, maestria, phd,
*                        especializacion, diplomado, nivel_tecnico...)
*     nivel_formacion_c  nivel corregido (tercer_nivel, cuarto_nivel,
*                        tercer_nivel_tecnico, tercer_nivel_tecnologico,
*                        nivel_tecnico, nivel_tecnologico)
*     regla_formacion    regla que asigno la clasificacion
*     reclasificado      1 = tipo_formacion_c distinto del tipo de la fuente.
*                        OJO: casi todo el cuarto nivel sale 1, porque la
*                        fuente no distingue maestria / PhD / especializacion
*                        (todo es otro_cuarto_nivel). Para ver cambios de
*                        NIVEL usar cambio_nivel.
*   + las agregadas aca:
*     tipo_formacion_fuente, nivel_formacion_fuente  el niveldeformacion de la
*                        fuente en los codigos del modulo
*     cambio_nivel       1 = el nivel corregido es distinto del de la fuente
*                        (tecnico / tercer / cuarto)
*     univ_c             1 = tercer o cuarto nivel corregido (universitario)
*
* Para usarla en movilidad_shock.do (bloque 01): sen_file = la base de salida
* y sen_level "nivel_formacion_c". La clasificacion de 05.2 la lee bien:
* TECNIC/TECNOLOG -> tecnico, TERCER -> tercer nivel, CUARTO -> cuarto nivel.
*
* OJO: la base tiene nombres y cedulas reales. La salida queda en la misma
* carpeta que la entrada (no en un repositorio).
*******************************************************************************/

clear all
set more off

* --- Rutas -------------------------------------------------------------------
global sen_dir  "/Users/santiago/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Procesamiento/Bases/SENESCYT"
global sen_in   "$sen_dir/cruce_FLACSO_051218.dta"
global sen_out  "$sen_dir/cruce_FLACSO_051218_reclasificado.dta"
global modulo   "/Users/santiago/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Predoc/Issues/59/fix_formation/reclasificar_formacion.do"

* --- Opciones ----------------------------------------------------------------
global guardar  1       // 1 = guardar $sen_out ; 0 = solo diagnostico
global prueba   0       // 1 = cargar solo las variables que hacen falta (rapido,
                        //     para revisar el diagnostico); obliga guardar 0

* Las opciones del propio modulo ($amb, $corte) se fijan adentro del modulo.

* ============================================================================
* 1. Datos
* ============================================================================
capture confirm file "$sen_in"
if _rc {
    di as error "No encuentro $sen_in"
    exit 601
}
capture confirm file "$modulo"
if _rc {
    di as error "No encuentro el modulo $modulo"
    exit 601
}

if $prueba == 1 {
    global guardar 0
    use nombretitulo nombreinstitucion tipo_titulo nombre_pais niveldeformacion ///
        fecha_registro fecha_acta_grado using "$sen_in", clear
}
else use "$sen_in", clear

* que ninguna variable de la base pise a las que arma este do-file
foreach v in nombre_titulo nombre_universidad ecuador year_registro ///
             fecha_acta_grado_2 tipo_formacion nivel_formacion pais_estudios ///
             tipo_formacion_c nivel_formacion_c regla_formacion reclasificado ///
             tipo_formacion_fuente nivel_formacion_fuente cambio_nivel univ_c {
    capture confirm variable `v', exact
    if !_rc {
        di as error "La base ya tiene la variable `v': renombrarla antes."
        exit 110
    }
}
quietly count
local N0 = r(N)
di as result _n "== SENESCYT: `N0' titulos =="

* ============================================================================
* 2. Insumos del modulo
* ============================================================================
gen strL nombre_titulo      = nombretitulo
gen strL nombre_universidad = nombreinstitucion

* Ecuador: tipo_titulo; si faltara, nombre_pais
gen byte ecuador = .
replace ecuador = 1 if strtrim(upper(tipo_titulo)) == "NACIONAL"
replace ecuador = 0 if strtrim(upper(tipo_titulo)) == "EXTRANJERO"
replace ecuador = (ustrupper(strtrim(nombre_pais)) == "ECUADOR") ///
    if missing(ecuador) & strtrim(nombre_pais) != ""
tab ecuador, missing

* Fechas: texto "AAAA-MM-DD hh:mm:ss". Anios fuera de 1940-2030 (hay 1900 y
* 9000 en la fuente) se toman como faltantes.
gen int year_registro = real(substr(strtrim(fecha_registro), 1, 4))
replace year_registro = . if !inrange(year_registro, 1940, 2030)
gen fecha_acta_grado_2 = date(substr(strtrim(fecha_acta_grado), 1, 10), "YMD")
format fecha_acta_grado_2 %td
replace fecha_acta_grado_2 = . if !inrange(year(fecha_acta_grado_2), 1940, 2030)
quietly count if missing(fecha_acta_grado_2)
di as text "sin fecha de acta de grado valida: " as result r(N) as text " de `N0'"
quietly count if missing(year_registro)
di as text "sin anio de registro valido:       " as result r(N) as text " de `N0'"

* Nivel de la fuente en los codigos del modulo
gen strL _nf = ustrupper(strtrim(niveldeformacion))
replace _nf = ustrregexra(ustrnormalize(_nf, "nfd"), "\p{M}", "")
gen str20 tipo_formacion  = ""
gen str20 nivel_formacion = ""
replace tipo_formacion = "nivel_tecnologico" if strpos(_nf, "TECNOLOG")
replace tipo_formacion = "nivel_tecnico"     if strpos(_nf, "TECNIC") & tipo_formacion == ""
replace tipo_formacion = "tercer_nivel"      if strpos(_nf, "TERCER") & tipo_formacion == ""
replace tipo_formacion = "otro_cuarto_nivel" if strpos(_nf, "CUARTO") & tipo_formacion == ""
replace nivel_formacion = cond(tipo_formacion == "otro_cuarto_nivel", "cuarto_nivel", tipo_formacion)
quietly count if tipo_formacion == ""
if r(N) > 0 {
    di as error "OJO: " r(N) " titulos con niveldeformacion no reconocido (quedan sin tipo de la fuente):"
    tab niveldeformacion if tipo_formacion == ""
}
di as text _n "niveldeformacion de la fuente -> codigos del modulo:"
tab niveldeformacion tipo_formacion, missing
drop _nf

* ============================================================================
* 3. Modulo
* ============================================================================
do "$modulo"

* ============================================================================
* 4. Variables propias y diagnostico
* ============================================================================
gen byte _nfuente = cond(inlist(nivel_formacion, "nivel_tecnico", "nivel_tecnologico"), 1, ///
                    cond(nivel_formacion == "tercer_nivel", 2,                          ///
                    cond(nivel_formacion == "cuarto_nivel", 3, .)))
gen byte _ncorr   = cond(strpos(nivel_formacion_c, "tecnic") | strpos(nivel_formacion_c, "tecnolog"), 1, ///
                    cond(nivel_formacion_c == "tercer_nivel", 2,                                       ///
                    cond(nivel_formacion_c == "cuarto_nivel", 3, .)))
label define _niv3 1 "tecnico/tecnologico" 2 "tercer nivel" 3 "cuarto nivel", replace
label values _nfuente _ncorr _niv3

gen byte cambio_nivel = _nfuente != _ncorr if !missing(_nfuente, _ncorr)
label var cambio_nivel "1 = el nivel corregido (tecnico/tercer/cuarto) difiere del de la fuente"
gen byte univ_c = inlist(_ncorr, 2, 3) if !missing(_ncorr)
label var univ_c "1 = titulo universitario (tercer o cuarto nivel corregido)"

di as text _n "{hline 78}"
di as text "Nivel de la fuente (filas) -> nivel corregido (columnas)"
di as text "{hline 78}"
tab _nfuente _ncorr, missing
tab _nfuente _ncorr, row nofreq
tab cambio_nivel, missing

di as text _n "{hline 78}"
di as text "Cuarto nivel corregido, por tipo y origen"
di as text "{hline 78}"
tab tipo_formacion_c ecuador if _ncorr == 3

quietly count if missing(_ncorr)
if r(N) > 0 {
    di as error "OJO: " r(N) " titulos con nivel_formacion_c no reconocido:"
    tab nivel_formacion_c if missing(_ncorr), missing
}

rename tipo_formacion  tipo_formacion_fuente
rename nivel_formacion nivel_formacion_fuente
label var tipo_formacion_fuente  "niveldeformacion de la fuente, en codigos del modulo"
label var nivel_formacion_fuente "nivel de la fuente, en codigos del modulo"
label var fecha_acta_grado_2     "fecha_acta_grado como fecha (anios fuera de 1940-2030 = .)"
label var year_registro          "anio de fecha_registro (fuera de 1940-2030 = .)"
label var ecuador                "1 = titulo nacional (tipo_titulo)"
drop _nfuente _ncorr nombre_titulo nombre_universidad
capture program drop _astring

* ============================================================================
* 5. Guardar
* ============================================================================
quietly count
if r(N) != `N0' {
    di as error "OJO: cambio el numero de titulos (`N0' -> " r(N) "). No se guarda."
    exit 459
}
if $guardar == 1 {
    compress
    save "$sen_out", replace
    di as result _n "Guardado: $sen_out"
}
else di as text _n "(guardar = 0: no se guardo nada)"

# -*- coding: utf-8 -*-
"""Configuración del generador automático del Boletín 3.

Todo lo que cambia de una edición a otra (rutas, archivos de gráficos,
títulos, fuentes, etiquetas) vive en este archivo. El código de la carpeta
``boletin/`` no debería necesitar modificaciones.
"""

from pathlib import Path

# ---------------------------------------------------------------------------
# 1. Rutas
# ---------------------------------------------------------------------------

# Carpeta raíz del Drive del Observatorio.
RAIZ_USUARIO = Path(
    "/Users/santiago/Library/CloudStorage/"
    "GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
)

# Donde analisis_descriptivo.do deja sus salidas ($out_results).
# La carpeta ha cambiado de nombre ("informalidad2" -> "informalidad"), así que
# se toma la primera que exista. Si se renombra otra vez, agregue el nombre
# aquí — y recuerde que el global $out_results del .do debe apuntar al mismo.
CARPETAS_RESULTADOS = ["informalidad", "informalidad2"]

_BASE_RESULTADOS = RAIZ_USUARIO / "Boletín 3" / "4. Resultados"
DIR_RESULTADOS = next(
    (_BASE_RESULTADOS / nombre for nombre in CARPETAS_RESULTADOS
     if (_BASE_RESULTADOS / nombre).is_dir()),
    _BASE_RESULTADOS / CARPETAS_RESULTADOS[0],
)

# Carpeta de redacción y salida del documento.
DIR_REDACCION = RAIZ_USUARIO / "Boletín 3" / "5. Redacción"

# Salidas del análisis de pobreza laboral (2. Pobreza laboral/corregido).
DIR_POBREZA = _BASE_RESULTADOS / "pobreza laboral" / "corregido"

# Salidas del análisis de homicidios de NNA.
DIR_HOMICIDIOS = _BASE_RESULTADOS / "homicidios infantiles"

# Imágenes que no produce ningún análisis del repositorio (hoy, solo la de
# homicidios). Se llenan con herramientas/extraer_figuras_docx.py.
DIR_RECURSOS = DIR_REDACCION / "recursos_boletin"

# Bases contra las que se resuelven las rutas de GRAFICOS.
BASES_FIGURAS = {
    "resultados": DIR_RESULTADOS,
    "recursos": DIR_RECURSOS,
    "pobreza": DIR_POBREZA,
    "homicidios": DIR_HOMICIDIOS,
}

# Nota al pie del título: advertencia sobre las correcciones de septiembre.
NOTA_TITULO = (
    "En septiembre de 2026 se corrigieron errores de código que (1) cambiaron "
    "sustancialmente la serie de empleo adecuado de los 90s, solo presente en el "
    "Gráfico 1, (2) modificaron levemente las tasas de no tenencia de RUC desde "
    "2007 en adelante y de no afiliación a la seguridad social en el periodo "
    "2003-2006, (3) eliminaron el 2001 del análisis por razones explicadas en la "
    "nota del gráfico 1 y (4) extendieron el análisis de la desagregación por "
    "etnia a 2025."
)

ARCHIVO_SALIDA = DIR_REDACCION / "Boletin_3_automatizado.docx"

# Código y contenido (dentro del repositorio).
DIR_CODIGO = Path(__file__).resolve().parent
ARCHIVO_CONTENIDO = DIR_CODIGO / "contenido" / "boletin3.md"

# ---------------------------------------------------------------------------
# 2. Stata (opcional: --correr-stata)
# ---------------------------------------------------------------------------

STATA_EJECUTABLE = "/Applications/StataNow/StataSE.app/Contents/MacOS/stata-se"

_DIR_BOLETIN = DIR_CODIGO.parent                  # …/Boletín 3
_DIR_INFORMALIDAD = _DIR_BOLETIN / "1. Infomalidad"
_DIR_ANALISIS = _DIR_INFORMALIDAD / "3. Analisis"
_DIR_ARMONIZACION = _DIR_INFORMALIDAD / "2. Armonización de variables" / "main"
_DIR_POBREZA_COD = _DIR_BOLETIN / "2. Pobreza laboral" / "corregido"
_DIR_HOMICIDIOS_COD = _DIR_BOLETIN / "3. homicidios_nna"

# Orden de ejecución de cada etapa.
ETAPAS_STATA = {
    "diseno": [_DIR_ARMONIZACION / "componentes" / "diseno_muestral.do"],
    "merge": [_DIR_ANALISIS / "merge_informal.do"],
    "analisis": [_DIR_ANALISIS / "analisis_descriptivo.do"],
    "ic": [_DIR_ANALISIS / "analisis_descriptivo_ic.do"],
    # run_all.do encadena por su cuenta las cinco etapas de pobreza laboral.
    "pobreza": [_DIR_POBREZA_COD / "run_all.do"],
    "homicidios": [_DIR_HOMICIDIOS_COD / "graficos_homicidios_nna.do"],
}

# Todos los gráficos del boletín, en orden. No incluye "ic": ese do-file no
# produce ninguna de las 12 figuras y además exige haber corrido antes la
# armonización (necesita estrato_svy y upm_svy).
ETAPAS_STATA["graficos"] = (
    ETAPAS_STATA["analisis"]
    + ETAPAS_STATA["pobreza"]
    + ETAPAS_STATA["homicidios"]
)

# Cadena completa, desde la armonización.
ETAPAS_STATA["todo"] = (
    ETAPAS_STATA["diseno"] + ETAPAS_STATA["merge"]
    + ETAPAS_STATA["graficos"] + ETAPAS_STATA["ic"]
)

# Bitácoras de Stata, junto a las del master.
DIR_LOGS = _DIR_BOLETIN / "logs"

# ---------------------------------------------------------------------------
# 3. Series de datos leídas de los Excel que exporta Stata
# ---------------------------------------------------------------------------
# Cada entrada describe un archivo exportado con `export excel ..., firstrow(var)`.
#
#   archivo    : ruta relativa a DIR_RESULTADOS
#   col_anio   : nombre de la columna de año
#   col_grupo  : columna de desagregación (None si es serie nacional)
#   col_casos  : columna con el número de observaciones (opcional)
#   escala     : factor para pasar a porcentaje (1 si ya viene en %, 100 si viene en tanto por uno)
#   series     : {columna_del_excel: nombre_en_el_texto}
#   etiquetas  : renombra valores de la columna de grupo
#
# Los nombres de la derecha en `series` son los que se usan en el contenido
# markdown dentro de {{ }}.

FUENTES = [
    dict(
        archivo="Tablas/Informalidad_y_componentes.xlsx",
        col_anio="anio",
        escala=1,
        series={
            "informal2": "inf",
            "informal1": "inf_sin_ruc",
            "comp_no_adec": "no_adec",
            "comp_no_remun": "no_remun",
            "comp_no_iess": "no_iess",
            "comp_no_ruc": "no_ruc",
        },
    ),
    dict(
        archivo="Tablas/n_condiciones_informalidad.xlsx",
        col_anio="anio",
        escala=1,
        series={
            "cond_1": "cond1",
            "cond_2": "cond2",
            "cond_3": "cond3",
            "cond_4": "cond4",
        },
    ),
    dict(
        archivo="Graficos/Informalidad_area.xlsx",
        col_anio="anio",
        col_grupo="area",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_area"},
        etiquetas={"Urbana": "Urbana", "Rural": "Rural"},
    ),
    dict(
        archivo="Tablas/Informalidad_y_componentes_area.xlsx",
        col_anio="anio",
        col_grupo="area",
        escala=1,
        series={
            "comp_no_adec": "no_adec_area",
            "comp_no_remun": "no_remun_area",
            "comp_no_iess": "no_iess_area",
            "comp_no_ruc": "no_ruc_area",
        },
    ),
    dict(
        archivo="Tablas/Informalidad_genero.xlsx",
        col_anio="anio",
        col_grupo="sexo",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_sexo"},
    ),
    dict(
        archivo="Tablas/Informalidad_y_componentes_sexo.xlsx",
        col_anio="anio",
        col_grupo="sexo",
        escala=1,
        series={
            "comp_no_adec": "no_adec_sexo",
            "comp_no_remun": "no_remun_sexo",
            "comp_no_iess": "no_iess_sexo",
            "comp_no_ruc": "no_ruc_sexo",
        },
    ),
    dict(
        archivo="Tablas/informalidad_edad.xlsx",
        col_anio="anio",
        col_grupo="age_cat",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_edad"},
    ),
    dict(
        archivo="Tablas/informalidad_etnia.xlsx",
        col_anio="anio",
        col_grupo="etnia_arm",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_etnia"},
    ),
    dict(
        archivo="Tablas/informalidad_educacion.xlsx",
        col_anio="anio",
        col_grupo="educ_univ",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_educ"},
    ),
    dict(
        archivo="informalidad_deciles_ingreso.xlsx",
        col_anio="anio",
        col_grupo="decil",
        escala=100,
        series={"inf2": "inf_decil"},
    ),
    dict(
        archivo="informalidad_provicia.xlsx",  # (sic) así lo exporta el .do
        col_anio="anio",
        col_grupo="provincia",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_prov"},
        etiquetas={"Santo Domingo de los Tsáchilas": "Santo Domingo"},
    ),
    dict(
        archivo="informalidad_rama.xlsx",
        col_anio="anio",
        col_grupo="rama1",
        col_casos="N",
        escala=100,
        series={"informal2": "inf_rama"},
        # Etiquetas cortas, las mismas de la tabla LaTeX del .do
        etiquetas={
            "A. Agricultura, ganaderia, silvicultura y pesca": "Agricultura y pesca",
            "B. Explotacion de minas y canteras": "Minas y canteras",
            "C. Industrias manufactureras": "Manufactura",
            "D. Suministros de electricidad, gas, vapor y aire acondicionado": "Electricidad y gas",
            "E. Distribucion de agua; alcantarillado, gestion de desechos y saneamiento": "Agua y saneamiento",
            "F. Construccion": "Construcción",
            "G. Comercio al por mayor y al por menor; reparacion de vehiculos automotores y motocicletas": "Comercio y rep. vehículos",
            "H. Transporte y almacenamiento": "Transporte y almacenamiento",
            "I. Actividades de alojamiento y de servicio de comidas": "Alojamiento y comidas",
            "J. Informacion y comunicaciones": "Información y comunicaciones",
            "K. Actividades financieras y de seguros": "Actividades financieras",
            "L. Actividades inmobiliarias": "Actividades inmobiliarias",
            "M. Actividades profesionales, cientificas y tecnicas": "Activ. profesionales y téc.",
            "N. Actividades de servicios administrativos y de apoyo": "Servicios administrativos",
            "O. Administracion publica y defensa; seguridad social de afiliacion obligatoria": "Administración pública",
            "P. Ensenanza": "Enseñanza",
            "Q. Actividades de atencion de la salud humana y de asistencia social": "Salud y asistencia social",
            "R. Actividades artisticas, de entretenimiento y recreativas": "Artes y entretenimiento",
            "S. Otras actividades de servicios": "Otros servicios",
            "T. Actividades de los hogares como empleadores": "Hogares como empleadores",
            "U. Actividades de organizaciones y organos extraterritoriales": "Org. extraterritoriales",
        },
    ),
]

# --- Pobreza laboral -------------------------------------------------------
# Las produce "2. Pobreza laboral/corregido/02_indicadores.do" y
# "04_descriptivos.do", que escriben en DIR_POBREZA (no en DIR_RESULTADOS).
# Los nombres de los grupos son las etiquetas de valor que fija 02_indicadores.do:
# si allí cambian, hay que cambiarlos aquí.
_POBREZA = dict(carpeta=DIR_POBREZA, col_anio="anio", escala=1,
                origen="2. Pobreza laboral/corregido/run_all.do")

FUENTES += [
    dict(_POBREZA,
         archivo="pobreza_ocupados_nacional.xlsx",
         series={"tasa_pobreza_pct": "pob"}),
    dict(_POBREZA,
         archivo="pobreza_ocupados_area.xlsx",
         col_grupo="area",
         series={"tasa_pobreza_pct": "pob_area"}),
    dict(_POBREZA,
         archivo="pobreza_ocupados_educ.xlsx",
         col_grupo="educsup_ok",
         series={"tasa_pobreza_pct": "pob_educ"}),
    dict(_POBREZA,
         archivo="pobreza_ocupados_sexo.xlsx",
         col_grupo="sexo",
         series={"tasa_pobreza_pct": "pob_sexo"}),
    dict(_POBREZA,
         archivo="pobreza_ocupados_edad.xlsx",
         col_grupo="age_cat",
         series={"tasa_pobreza_pct": "pob_edad"}),
    # Reparto de los ocupados pobres (suman 100 en cada año).
    dict(_POBREZA,
         archivo="composicion_horas_ocupados_pobres.xlsx",
         col_grupo="grupo_horas",
         series={"porcentaje": "pob_horas"}),
    dict(_POBREZA,
         archivo="composicion_educ_ocupados_pobres.xlsx",
         col_grupo="educsup_ok",
         series={"porcentaje": "pob_comp_educ"}),
]

# Serie que define el "último año" general del boletín ({{ultimo}}).
SERIE_DE_REFERENCIA = "inf"

# ---------------------------------------------------------------------------
# 4. Gráficos
# ---------------------------------------------------------------------------
# `archivos` es una lista de candidatos; se usa el primero que exista.
#   ("resultados", "ruta/relativa.png")  -> dentro de DIR_RESULTADOS
#   ("recursos",   "fig_09.png")         -> dentro de DIR_RECURSOS

FUENTE_ENEMDU = "Fuente: ENEMDU, rondas de diciembre."
ELABORACION = (
    "Elaboración: Observatorio de Pobreza, Desigualdad y Empleo – FLACSO Ecuador."
)
# Los gráficos de informalidad ya no dibujan intervalos de confianza, así que
# esta nota quedó sin uso. Se conserva por si se vuelven a activar las capas
# `rarea` de analisis_descriptivo.do.
NOTA_IC = (
    "Nota: Las líneas sombreadas representan el intervalo de confianza de las "
    "estimaciones al 95% de confianza."
)
NOTA_POBREZA = (
    "Nota: El universo lo componen las personas ocupadas. Se considera pobre a "
    "quien vive en un hogar cuyo ingreso per cápita está por debajo de la línea "
    "de pobreza de diciembre de cada año. La serie salta de bienios a años "
    "completos a partir de 2008, cuando la ENEMDU pasó a levantarse todos los "
    "diciembres."
)

GRAFICOS = {
    "componentes": dict(
        titulo="Evolución de la informalidad laboral y sus componentes",
        archivos=[("resultados", "Graficos/Informalidad_y_componentes.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
        nota=(
            "Notas: El universo de análisis lo componen los ocupados en edad de "
            "trabajar. Es decir, se deja fuera a los inactivos, desempleados y "
            "menores de 15 años. Los datos de antes del 2000 corresponden "
            "únicamente al sector urbano. Además, en este periodo el indicador de "
            "informalidad no incluye al trabajo en organizaciones sin RUC como "
            "criterio, y el componente de seguridad social no contempla la "
            "afiliación al ISSFA o al ISSPOL. Los años 2001 y 2002 quedan fuera "
            "de la serie: 2002 porque sólo incluye al sector urbano, y 2001 porque la pregunta sobre el RUC sólo se le hizo a patronos y trabajadores por "
            "cuenta propia, de modo que ese criterio no puede evaluarse en el "
            "resto de los ocupados. La serie que incorpora el RUC arranca, por "
            "lo tanto, en 2003. Solo desde 2007 en adelante el "
            "trabajo no remunerado incluye a trabajadores no remunerados que no "
            "son parte de la familia. El porcentaje de trabajo con afiliación "
            "podría estar sutilmente sobreestimado, ya que incluye a personas que "
            "están afiliadas de manera voluntaria y a los que están asegurados "
            "debido a la afiliación de otra persona al IESS (cuando es un hijo "
            "trabajador menor de 18 años o cónyuge). Por diseño de la ENEMDU, el "
            "trabajo en organizaciones sin RUC trata a los empleados domésticos y "
            "a quienes trabajan en empresas de más de 100 trabajadores como si sí "
            "tuvieran RUC."
        ),
    ),
    "condiciones": dict(
        titulo=(
            "Porcentaje de personas que cumplen una o varias condiciones de "
            "informalidad al mismo tiempo"
        ),
        archivos=[("resultados", "Graficos/n_condiciones_informalidad.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "area": dict(
        titulo="Informalidad por área",
        archivos=[
            ("resultados", "Graficos/informal2_area.png"),
            ("resultados", "informal2_area.png"),
        ],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "sexo": dict(
        titulo="Informalidad por género",
        archivos=[("resultados", "Graficos/informal2_sexo.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "edad": dict(
        titulo="Informalidad por edad",
        archivos=[
            ("resultados", "Graficos/informal2_edad.png"),
            ("resultados", "informal2_edad.png"),
        ],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "etnia": dict(
        titulo="Informalidad por etnia",
        archivos=[("resultados", "Graficos/informal2_etnia.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "educacion": dict(
        titulo="Informalidad por nivel educativo",
        archivos=[("resultados", "Graficos/informal2_educ.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "deciles": dict(
        titulo="Informalidad por deciles de ingreso pre y pospandemia",
        archivos=[("resultados", "Graficos/informal2_decil.png")],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    # --- Pobreza laboral (2. Pobreza laboral/corregido/02_indicadores.do) ---
    # Se deja como respaldo la figura extraída del boletín v5 por si todavía no
    # se corrió el análisis; el generador usa el primer archivo que exista.
    "pobreza_nacional": dict(
        titulo="Evolución de la pobreza laboral a nivel nacional",
        archivos=[
            ("pobreza", "g09_pobreza_laboral_nacional.png"),
            ("recursos", "fig_09.png"),
        ],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
        nota=NOTA_POBREZA,
    ),
    "pobreza_area": dict(
        titulo="Pobreza laboral por área",
        archivos=[
            ("pobreza", "g10_pobreza_laboral_area.png"),
            ("recursos", "fig_10.png"),
        ],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
        nota=NOTA_POBREZA,
    ),
    "pobreza_educacion": dict(
        titulo="Pobreza laboral por nivel educativo",
        archivos=[
            ("pobreza", "g11_pobreza_laboral_educacion.png"),
            ("recursos", "fig_11.png"),
        ],
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
        nota=NOTA_POBREZA,
    ),
    "homicidios": dict(
        titulo="Tasa de homicidios de niñas, niños y adolescentes por cada 100.000",
        archivos=[
            ("homicidios", "tasa_homicidios_nna_etnia.png"),
            ("recursos", "fig_12.png"),
        ],
        fuente=(
            "Fuente: Estadísticas de homicidios intencionales, Ministerio del Interior."
        ),
        elaboracion=ELABORACION,
    ),
}

# ---------------------------------------------------------------------------
# 5. Tablas
# ---------------------------------------------------------------------------
# Se arman a partir de las mismas series de la sección 3 (tipo "pivote":
# filas = grupo, columnas = años).
#
#   umbral_casos: deja fuera los grupos con menos de ese % de casos en el
#                 último año (None = sin filtro).

TABLAS = {
    "provincia": dict(
        titulo="Informalidad por provincia (%)",
        serie="inf_prov",
        encabezado_grupo="Provincia",
        orden="desc",           # por el valor del último año
        decimales=1,
        faltante="–",
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
    ),
    "rama": dict(
        titulo="Informalidad por rama de actividad (%)",
        serie="inf_rama",
        encabezado_grupo="Rama de actividad",
        orden="desc",
        decimales=1,
        faltante="–",
        umbral_casos=1.0,
        fuente=FUENTE_ENEMDU,
        elaboracion=ELABORACION,
        nota=(
            "Nota: Se muestran solo las ramas de actividad que tienen más del 1% "
            "de casos en {{ultimo}}."
        ),
    ),
}

# ---------------------------------------------------------------------------
# 6. Equipo (marcador [[equipo]])
# ---------------------------------------------------------------------------

EQUIPO = [
    ("Coordinador", ["Juan Ponce"]),
    ("Responsable del Boletín", ["Andrés Mideros"]),
    ("Investigadores", ["María Ángeles Cevallos", "Santiago Valdivieso"]),
    ("Becarios", ["Emilio Espinosa", "Wilson Morquecho"]),
]

# ---------------------------------------------------------------------------
# 7. Formato del documento
# ---------------------------------------------------------------------------

DOCUMENTO = dict(
    fuente="Times New Roman",
    fuente_respaldo="Times",
    tamano_pt=12,
    tamano_nota_pt=10,
    tamano_tabla_pt=10,
    interlineado=1.15,
    espacio_despues_pt=6,
    # Carta (21.59 x 27.94 cm) con márgenes de 3 cm y 2.5 cm.
    ancho_pagina_cm=21.59,
    alto_pagina_cm=27.94,
    margen_lateral_cm=3.0,
    margen_vertical_cm=2.5,
    # Ancho de las imágenes = ancho útil de la página.
    ancho_imagen_cm=21.59 - 2 * 3.0,
    # Resolución mínima aceptable de un gráfico al insertarlo a ese ancho.
    # Por debajo de esto el gráfico se ve borroso impreso y el generador avisa.
    # Para subirla: width() en el `graph export` del .do, no aquí.
    dpi_minimo=200,
    etiqueta_grafico="Gráfico",
    etiqueta_tabla="Tabla",
)

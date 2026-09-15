# -*- coding: utf-8 -*-
"""Lector del archivo de contenido (markdown simplificado).

Sintaxis
--------
    # Título del boletín
    ## Sección
    ### Subtítulo
    Texto normal (las líneas seguidas se unen en un mismo párrafo).
    - Viñeta
    > **Cuadro 1. Título**       <- recuadro (una tabla de una celda)
    > Párrafo del recuadro.
    [[grafico: area]]            <- gráfico definido en configuracion.GRAFICOS
    [[tabla: provincia]]         <- tabla definida en configuracion.TABLAS
    [[equipo]]                   <- tabla del equipo
    [[salto]]                    <- salto de página
    % línea de comentario (no se imprime)

Dentro de cualquier texto se pueden usar expresiones {{ }} (ver indicadores.py)
y **negrita** / *cursiva*.
"""

from __future__ import annotations

import re

MARCADOR = re.compile(r"^\[\[\s*(\w+)\s*(?::\s*(.+?)\s*)?\]\]$")


class ErrorDeContenido(Exception):
    pass


def leer(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        return analizar(archivo.read())


def analizar(texto):
    bloques = []
    parrafo = []
    cita = []

    def cerrar_parrafo():
        if parrafo:
            bloques.append({"tipo": "parrafo", "texto": " ".join(parrafo)})
            parrafo.clear()

    def cerrar_cita():
        if not cita:
            return
        titulo = None
        lineas = list(cita)
        if lineas and lineas[0].startswith("**") and lineas[0].endswith("**"):
            titulo = lineas.pop(0).strip("*").strip()
        parrafos = []
        actual = []
        for linea in lineas:
            if linea.strip():
                actual.append(linea.strip())
            elif actual:
                parrafos.append(" ".join(actual))
                actual = []
        if actual:
            parrafos.append(" ".join(actual))
        bloques.append({"tipo": "cuadro", "titulo": titulo, "parrafos": parrafos})
        cita.clear()

    for numero, linea in enumerate(texto.splitlines(), start=1):
        cruda = linea.rstrip()
        desnuda = cruda.strip()

        if desnuda.startswith("%"):
            continue

        if cruda.startswith(">"):
            cerrar_parrafo()
            cita.append(cruda[1:].strip())
            continue
        cerrar_cita()

        if not desnuda:
            cerrar_parrafo()
            continue

        marcador = MARCADOR.match(desnuda)
        if marcador:
            cerrar_parrafo()
            nombre, argumento = marcador.group(1), marcador.group(2)
            if nombre in ("grafico", "tabla"):
                if not argumento:
                    raise ErrorDeContenido(
                        f"Línea {numero}: [[{nombre}]] necesita un identificador."
                    )
                bloques.append({"tipo": nombre, "id": argumento})
            elif nombre in ("equipo", "salto"):
                bloques.append({"tipo": nombre})
            else:
                raise ErrorDeContenido(
                    f"Línea {numero}: marcador desconocido '[[{nombre}]]'."
                )
            continue

        if desnuda.startswith("### "):
            cerrar_parrafo()
            bloques.append({"tipo": "subseccion", "texto": desnuda[4:].strip()})
        elif desnuda.startswith("## "):
            cerrar_parrafo()
            bloques.append({"tipo": "seccion", "texto": desnuda[3:].strip()})
        elif desnuda.startswith("# "):
            cerrar_parrafo()
            bloques.append({"tipo": "titulo", "texto": desnuda[2:].strip()})
        elif desnuda.startswith("- "):
            cerrar_parrafo()
            bloques.append({"tipo": "vineta", "texto": desnuda[2:].strip()})
        else:
            parrafo.append(desnuda)

    cerrar_parrafo()
    cerrar_cita()
    return bloques


def numerar(bloques, etiqueta_grafico="Gráfico", etiqueta_tabla="Tabla"):
    """Asigna el número correlativo a cada gráfico y tabla.

    Devuelve (referencias_graficos, referencias_tablas) para que el texto pueda
    escribir {{G.area}} -> 'Gráfico 3'.
    """
    graficos, tablas = {}, {}
    n_grafico = n_tabla = 0
    for bloque in bloques:
        if bloque["tipo"] == "grafico":
            n_grafico += 1
            bloque["numero"] = n_grafico
            graficos[bloque["id"]] = f"{etiqueta_grafico} {n_grafico}"
        elif bloque["tipo"] == "tabla":
            n_tabla += 1
            bloque["numero"] = n_tabla
            tablas[bloque["id"]] = f"{etiqueta_tabla} {n_tabla}"
    return graficos, tablas

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera el Boletín 3 en Word a partir de las salidas de Stata.

Uso típico:

    python3 generar_boletin.py                    # usa las salidas ya existentes
    python3 generar_boletin.py --correr-stata analisis
    python3 generar_boletin.py --solo-indicadores # revisa las cifras del texto

Ver README.md.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

DIR_CODIGO = Path(__file__).resolve().parent
sys.path.insert(0, str(DIR_CODIGO))


def _interprete_del_entorno():
    """Ruta del python de .venv, si existe."""
    for relativa in (("bin", "python"), ("Scripts", "python.exe")):
        candidato = DIR_CODIGO.joinpath(".venv", *relativa)
        if candidato.exists():
            return candidato
    return None


def _asegurar_dependencias():
    """Relanza el script con el intérprete de .venv si faltan las librerías.

    Sirve para correr el generador desde Spyder, desde un IDE o desde cualquier
    python que no sea el del entorno del proyecto. Se relanza como proceso hijo
    en vez de os.execv: execv reemplazaría el proceso y en Spyder eso mataría el
    kernel.
    """
    try:
        import docx  # noqa: F401
        import openpyxl  # noqa: F401
        return
    except ImportError:
        pass

    entorno = _interprete_del_entorno()
    instrucciones = (
        f'    cd "{DIR_CODIGO}"\n'
        "    python3 -m venv .venv\n"
        "    .venv/bin/pip install -r requirements.txt"
    )

    # El hijo ya corre con el entorno: si aun asi faltan, el entorno esta a medias.
    if os.environ.get("BOLETIN_REINTENTO"):
        raise SystemExit(
            "El entorno .venv existe pero no tiene openpyxl y python-docx.\n"
            "Reinstale las dependencias:\n" + instrucciones
        )

    if entorno is None:
        raise SystemExit(
            "Faltan openpyxl y/o python-docx, y no hay un entorno .venv.\n"
            "Creelo una sola vez:\n" + instrucciones + "\n\n"
            "En Spyder tambien puede apuntar el interprete a ese entorno:\n"
            "    Preferencias > Interprete de Python > Usar el siguiente\n"
            f"    {DIR_CODIGO / '.venv' / 'bin' / 'python'}"
        )

    print(f"Las librerias no estan en {sys.executable}.", flush=True)
    print(f"Se reintenta con el entorno del proyecto: {entorno}\n", flush=True)
    proceso = subprocess.run(
        [str(entorno), str(Path(__file__).resolve()), *sys.argv[1:]],
        env=dict(os.environ, BOLETIN_REINTENTO="1"),
    )
    raise SystemExit(proceso.returncode)


_asegurar_dependencias()

import configuracion as cfgmod  # noqa: E402
from boletin import contenido as contenido_mod  # noqa: E402
from boletin import indicadores as ind  # noqa: E402
from boletin import tablas as tablas_mod  # noqa: E402
from boletin import imagenes as imagenes_mod  # noqa: E402
from boletin.datos import FaltaDato, cargar_series  # noqa: E402
from boletin.documento import Documento  # noqa: E402


class Aviso(list):
    def __call__(self, mensaje):
        self.append(mensaje)


def resolver_ruta_figura(candidatos):
    """Primera ruta que exista, entre las bases de configuracion.BASES_FIGURAS."""
    bases = getattr(
        cfgmod,
        "BASES_FIGURAS",
        {"resultados": cfgmod.DIR_RESULTADOS, "recursos": cfgmod.DIR_RECURSOS},
    )
    for base, relativa in candidatos:
        raiz = bases.get(base)
        if raiz is None:
            raise SystemExit(
                f"Base de figuras desconocida: '{base}'. "
                f"Opciones: {sorted(bases)} (configuracion.BASES_FIGURAS)."
            )
        ruta = raiz / relativa
        if ruta.exists():
            return ruta
    return None


def generar(args):
    avisos = Aviso()

    # -- 1. Stata (opcional) ------------------------------------------------
    if args.correr_stata != "no":
        from boletin import stata

        print(f"Ejecutando Stata (etapa: {args.correr_stata})…")
        stata.correr_etapa(
            args.correr_stata,
            cfgmod.ETAPAS_STATA,
            cfgmod.STATA_EJECUTABLE,
            cfgmod.DIR_LOGS,
        )

    # -- 2. Datos -----------------------------------------------------------
    print(f"Leyendo resultados de: {cfgmod.DIR_RESULTADOS}")
    for nombre in cfgmod.CARPETAS_RESULTADOS:
        otra = cfgmod.DIR_RESULTADOS.parent / nombre
        if otra != cfgmod.DIR_RESULTADOS and otra.is_dir():
            if otra.stat().st_mtime > cfgmod.DIR_RESULTADOS.stat().st_mtime:
                avisos(
                    f"La carpeta '{nombre}' es más reciente que la que se está "
                    f"leyendo ('{cfgmod.DIR_RESULTADOS.name}'). Revise a cuál "
                    f"apunta el global $out_results de analisis_descriptivo.do "
                    f"y el orden de CARPETAS_RESULTADOS en configuracion.py."
                )
    series, avisos_datos = cargar_series(cfgmod.FUENTES, cfgmod.DIR_RESULTADOS)
    for mensaje in avisos_datos:
        avisos(mensaje)
    if not series:
        raise SystemExit(
            "No se pudo leer ninguna serie. ¿Corrió analisis_descriptivo.do?"
        )
    print(f"  {len(series)} series cargadas.")

    # -- 3. Contenido -------------------------------------------------------
    ruta_contenido = Path(args.contenido or cfgmod.ARCHIVO_CONTENIDO)
    bloques = contenido_mod.leer(ruta_contenido)
    ref_graficos, ref_tablas = contenido_mod.numerar(
        bloques,
        cfgmod.DOCUMENTO["etiqueta_grafico"],
        cfgmod.DOCUMENTO["etiqueta_tabla"],
    )
    espacio = ind.construir_espacio(
        series, ref_graficos, ref_tablas, cfgmod.SERIE_DE_REFERENCIA
    )
    registro = {}

    def texto(valor):
        return ind.resolver(valor, espacio, registro) if valor else valor

    # -- 4. Solo indicadores ------------------------------------------------
    if args.solo_indicadores:
        for bloque in bloques:
            for campo in ("texto", "titulo"):
                if bloque.get(campo):
                    texto(bloque[campo])
            for parrafo in bloque.get("parrafos", []):
                texto(parrafo)
        ancho = max((len(k) for k in registro), default=0)
        for expresion, valor in registro.items():
            print(f"{expresion.ljust(ancho)}  =  {valor}")
        print(f"\n{len(registro)} expresiones evaluadas.")
        return 0

    # -- 5. Documento -------------------------------------------------------
    doc = Documento(cfgmod.DOCUMENTO)

    for bloque in bloques:
        tipo = bloque["tipo"]

        if tipo == "titulo":
            doc.titulo(texto(bloque["texto"]))
        elif tipo == "seccion":
            doc.seccion(texto(bloque["texto"]))
        elif tipo == "subseccion":
            doc.subseccion(texto(bloque["texto"]))
        elif tipo == "parrafo":
            doc.parrafo(texto(bloque["texto"]))
        elif tipo == "vineta":
            doc.vineta(texto(bloque["texto"]))
        elif tipo == "salto":
            doc.salto_de_pagina()
        elif tipo == "equipo":
            doc.equipo(cfgmod.EQUIPO)
        elif tipo == "cuadro":
            doc.cuadro(
                texto(bloque.get("titulo")),
                [texto(p) for p in bloque["parrafos"]],
            )

        elif tipo == "grafico":
            cfg = cfgmod.GRAFICOS.get(bloque["id"])
            if cfg is None:
                raise SystemExit(
                    f"El gráfico '{bloque['id']}' no está en configuracion.GRAFICOS."
                )
            etiqueta = f"{cfgmod.DOCUMENTO['etiqueta_grafico']} {bloque['numero']}"
            doc.encabezado_figura(f"{etiqueta}. {texto(cfg['titulo'])}")
            ruta = resolver_ruta_figura(cfg["archivos"])
            if ruta is None:
                esperado = ", ".join(r for _, r in cfg["archivos"])
                avisos(
                    f"{etiqueta} ({bloque['id']}): no se encontró la imagen. "
                    f"Se esperaba una de: {esperado}"
                )
                doc.marcador_faltante(f"{etiqueta}. {cfg['titulo']}")
            else:
                problema = imagenes_mod.revisar(
                    ruta,
                    cfgmod.DOCUMENTO["ancho_imagen_cm"],
                    cfgmod.DOCUMENTO["dpi_minimo"],
                )
                if problema:
                    avisos(f"{etiqueta} ({bloque['id']}): {problema}")
                doc.imagen(ruta)
            for clave in ("fuente", "elaboracion", "nota"):
                if cfg.get(clave):
                    doc.pie(texto(cfg[clave]))
            doc.parrafo("")

        elif tipo == "tabla":
            cfg = cfgmod.TABLAS.get(bloque["id"])
            if cfg is None:
                raise SystemExit(
                    f"La tabla '{bloque['id']}' no está en configuracion.TABLAS."
                )
            etiqueta = f"{cfgmod.DOCUMENTO['etiqueta_tabla']} {bloque['numero']}"
            doc.encabezado_figura(f"{etiqueta}. {texto(cfg['titulo'])}")
            serie = series.get(cfg["serie"])
            if serie is None:
                avisos(
                    f"{etiqueta} ({bloque['id']}): falta la serie '{cfg['serie']}'."
                )
                doc.marcador_faltante(f"{etiqueta}. {cfg['titulo']}")
            else:
                encabezados, filas = tablas_mod.construir(serie, cfg)
                doc.tabla(encabezados, filas)
            for clave in ("fuente", "elaboracion", "nota"):
                if cfg.get(clave):
                    doc.pie(texto(cfg[clave]))
            doc.parrafo("")

        else:  # pragma: no cover
            raise SystemExit(f"Tipo de bloque desconocido: {tipo}")

    # -- 6. Guardado --------------------------------------------------------
    salida = Path(args.salida or cfgmod.ARCHIVO_SALIDA)
    doc.guardar(salida)
    print(f"\nDocumento generado: {salida}")

    auditoria = salida.with_name(salida.stem + "_indicadores.json")
    auditoria.write_text(
        json.dumps(
            {
                "generado": datetime.now().isoformat(timespec="seconds"),
                "resultados": str(cfgmod.DIR_RESULTADOS),
                "contenido": str(ruta_contenido),
                "expresiones": registro,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Cifras usadas en el texto: {auditoria}")

    if avisos:
        print(f"\n{len(avisos)} aviso(s):")
        for mensaje in avisos:
            print(f"  ! {mensaje}")
        if args.estricto:
            return 1
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Genera el Boletín 3 en Word con los datos y gráficos "
                    "de analisis_descriptivo.do."
    )
    parser.add_argument(
        "--correr-stata",
        default="no",
        choices=["no", "analisis", "ic", "merge", "diseno",
                 "pobreza", "homicidios", "graficos", "todo"],
        help="Ejecuta los do-files antes de armar el documento (por defecto: no).",
    )
    parser.add_argument("--salida", help="Ruta del .docx de salida.")
    parser.add_argument("--contenido", help="Archivo de contenido (markdown).")
    parser.add_argument(
        "--solo-indicadores",
        action="store_true",
        help="Solo imprime las cifras que se insertarían en el texto.",
    )
    parser.add_argument(
        "--estricto",
        action="store_true",
        help="Termina con código de error si hay avisos (útil en CI).",
    )
    args = parser.parse_args()

    try:
        return generar(args)
    except FaltaDato as error:
        print(f"\nERROR de datos: {error}", file=sys.stderr)
        print(
            "Revise que analisis_descriptivo.do se haya corrido con la base "
            "actualizada.",
            file=sys.stderr,
        )
        return 2
    except ind.ErrorDeExpresion as error:
        print(f"\nERROR en una expresión del contenido: {error}", file=sys.stderr)
        return 2
    except contenido_mod.ErrorDeContenido as error:
        print(f"\nERROR en el archivo de contenido: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

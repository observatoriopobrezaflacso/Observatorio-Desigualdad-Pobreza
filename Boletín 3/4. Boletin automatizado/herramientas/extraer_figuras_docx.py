#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extrae las imágenes de un .docx existente a la carpeta de recursos.

Sirve para las figuras que NO produce analisis_descriptivo.do (pobreza laboral
y homicidios): se toman del boletín ya redactado y quedan disponibles para el
generador como fig_01.png, fig_02.png, …, en el mismo orden en que aparecen.

    python3 herramientas/extraer_figuras_docx.py "…/Boletin_3_v5.docx"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from docx import Document  # noqa: E402
from docx.oxml.ns import qn  # noqa: E402

import configuracion as cfgmod  # noqa: E402


def extraer(ruta_docx: Path, destino: Path):
    doc = Document(str(ruta_docx))
    destino.mkdir(parents=True, exist_ok=True)

    numero = 0
    guardadas = []
    for parrafo in doc.paragraphs:
        for dibujo in parrafo._p.findall(".//" + qn("w:drawing")):
            for blip in dibujo.findall(".//" + qn("a:blip")):
                rid = blip.get(qn("r:embed"))
                if not rid:
                    continue
                parte = doc.part.related_parts[rid]
                extension = parte.content_type.split("/")[-1]
                extension = {"jpeg": "jpg", "x-emf": "emf"}.get(extension, extension)
                numero += 1
                archivo = destino / f"fig_{numero:02d}.{extension}"
                archivo.write_bytes(parte.blob)
                guardadas.append(archivo)
    return guardadas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("docx", help="Boletín ya redactado del que copiar las figuras.")
    parser.add_argument(
        "--destino",
        default=str(cfgmod.DIR_RECURSOS),
        help=f"Carpeta de salida (por defecto {cfgmod.DIR_RECURSOS}).",
    )
    args = parser.parse_args()

    archivos = extraer(Path(args.docx), Path(args.destino))
    for archivo in archivos:
        print(f"  {archivo.name}  ({archivo.stat().st_size // 1024} KB)")
    print(f"\n{len(archivos)} imágenes en {args.destino}")


if __name__ == "__main__":
    main()

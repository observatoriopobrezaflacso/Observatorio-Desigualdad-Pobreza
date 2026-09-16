# -*- coding: utf-8 -*-
"""Medición de imágenes, para detectar gráficos de baja resolución.

Stata exporta los PNG a la resolución de la pantalla cuando el `graph export`
no lleva `width()` o `height()`: en modo batch (`-b`, sin pantalla) eso da
720x432 px, que estirados al ancho de la página se ven borrosos. Este módulo
permite avisarlo antes de entregar el documento.
"""

from __future__ import annotations

import struct
from pathlib import Path

CM_POR_PULGADA = 2.54


def dimensiones(ruta: Path):
    """(ancho, alto) en píxeles, o None si no se reconoce el formato."""
    datos = Path(ruta).read_bytes()

    # PNG
    if datos[:8] == b"\x89PNG\r\n\x1a\n" and datos[12:16] == b"IHDR":
        return struct.unpack(">II", datos[16:24])

    # JPEG: se recorren los marcadores hasta el SOF
    if datos[:2] == b"\xff\xd8":
        i = 2
        while i < len(datos) - 9:
            if datos[i] != 0xFF:
                i += 1
                continue
            marcador = datos[i + 1]
            if marcador in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                            0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                alto, ancho = struct.unpack(">HH", datos[i + 5:i + 9])
                return ancho, alto
            if marcador in (0xD8, 0xD9) or 0xD0 <= marcador <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack(">H", datos[i + 2:i + 4])[0]
        return None

    return None


def dpi_efectivo(ruta: Path, ancho_cm: float):
    """Resolución con la que la imagen quedará impresa a ese ancho."""
    medidas = dimensiones(ruta)
    if not medidas:
        return None
    ancho_px, _ = medidas
    return ancho_px / (ancho_cm / CM_POR_PULGADA)


def revisar(ruta: Path, ancho_cm: float, dpi_minimo: int):
    """None si la imagen está bien; si no, un mensaje explicando el problema."""
    dpi = dpi_efectivo(ruta, ancho_cm)
    if dpi is None or dpi >= dpi_minimo:
        return None
    ancho_px, alto_px = dimensiones(ruta)
    ancho_necesario = round(dpi_minimo * ancho_cm / CM_POR_PULGADA)
    return (
        f"{Path(ruta).name} tiene {ancho_px}x{alto_px} px: a {ancho_cm:.1f} cm "
        f"de ancho son {dpi:.0f} dpi (mínimo {dpi_minimo}) y se verá borroso. "
        f"Agregue width({ancho_necesario}) al `graph export` de ese gráfico en "
        f"analisis_descriptivo.do y vuelva a correrlo."
    )

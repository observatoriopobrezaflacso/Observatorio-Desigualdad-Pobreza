# -*- coding: utf-8 -*-
"""Armado de las tablas del boletín a partir de las series de Stata."""

from __future__ import annotations

from .indicadores import formatear


def construir(serie, cfg):
    """Devuelve (encabezados, filas) de una tabla grupo x año.

    cfg: una entrada de configuracion.TABLAS.
    """
    anios = serie.anios
    if not anios:
        raise ValueError(f"La serie '{serie.nombre}' no tiene datos.")
    ultimo = anios[-1]

    umbral = cfg.get("umbral_casos")
    grupos = {g for _, g in serie.valores if g is not None}

    seleccion = []
    for grupo in grupos:
        if umbral is not None:
            parte = serie.participacion(ultimo, grupo)
            if parte is None or parte < umbral:
                continue
        seleccion.append(grupo)

    if not seleccion:
        raise ValueError(
            f"Ningún grupo de '{serie.nombre}' pasa el filtro de casos "
            f"(umbral = {umbral}%)."
        )

    sin_dato = float("-inf") if cfg.get("orden", "desc") == "desc" else float("inf")

    def clave(grupo):
        valor = serie.obtener(ultimo, grupo)
        return valor if valor is not None else sin_dato

    if cfg.get("orden", "desc") == "desc":
        seleccion.sort(key=clave, reverse=True)
    elif cfg["orden"] == "asc":
        seleccion.sort(key=clave)
    else:  # alfabético
        seleccion.sort()

    decimales = cfg.get("decimales", 1)
    faltante = cfg.get("faltante", "–")

    encabezados = [cfg.get("encabezado_grupo", "")] + [str(a) for a in anios]
    filas = []
    for grupo in seleccion:
        fila = [grupo]
        for anio in anios:
            valor = serie.obtener(anio, grupo)
            fila.append(faltante if valor is None else f"{valor:.{decimales}f}")
        filas.append(fila)
    return encabezados, filas

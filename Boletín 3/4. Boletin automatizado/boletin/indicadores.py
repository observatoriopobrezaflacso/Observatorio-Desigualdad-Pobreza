# -*- coding: utf-8 -*-
"""Evaluación de las expresiones {{ }} del contenido del boletín.

El texto del boletín no lleva cifras escritas a mano: lleva expresiones que se
resuelven contra las series exportadas por Stata. Ejemplos::

    En {{ultimo}}, el {{inf[-1]}}% de los trabajadores son informales.
    La brecha es de {{inf_area[-1,'Rural'] - inf_area[-1,'Urbana']}} puntos.
    {{lista(ranking(inf_prov, -1)[:4])}} registran los niveles más altos.
    El componente sin RUC subió {{no_ruc[-1] - no_ruc[2014]}} pp frente a 2014.

Sintaxis admitida dentro de las llaves: cualquier expresión de Python sobre las
series y las funciones de ayuda de este módulo. Un `|` final fija el número de
decimales: {{inf[-1]|2}}, {{inf[-1]|0}}, {{expr|crudo}}.
"""

from __future__ import annotations

import re

from .datos import FaltaDato, Serie

PATRON = re.compile(r"\{\{(.+?)\}\}", re.S)

ORDINALES = [
    "", "primer", "segundo", "tercer", "cuarto", "quinto",
    "sexto", "séptimo", "octavo", "noveno", "décimo",
]


class ErrorDeExpresion(Exception):
    pass


# ---------------------------------------------------------------------------
# Formato
# ---------------------------------------------------------------------------

def formatear(valor, decimales=1):
    """1 decimal por defecto; se elimina el '.0' sobrante (92.0 -> 92)."""
    if valor is None:
        return "—"
    if isinstance(valor, str):
        return valor
    if isinstance(valor, bool):
        return "sí" if valor else "no"
    if isinstance(valor, int):
        return str(valor)
    if isinstance(valor, float):
        texto = f"{valor:.{decimales}f}"
        if "." in texto:
            texto = texto.rstrip("0").rstrip(".")
        return texto or "0"
    if isinstance(valor, (list, tuple)):
        return ", ".join(formatear(v, decimales) for v in valor)
    return str(valor)


# ---------------------------------------------------------------------------
# Funciones de ayuda disponibles en el contenido
# ---------------------------------------------------------------------------

def _anios_filtrados(serie: Serie, grupo, desde, hasta, excluir):
    excluir = set(excluir or ())
    anios = []
    for anio in serie.anios:
        if desde is not None and anio < desde:
            continue
        if hasta is not None and anio > hasta:
            continue
        if anio in excluir:
            continue
        if serie.obtener(anio, grupo) is not None:
            anios.append(anio)
    if not anios:
        raise FaltaDato(
            f"La serie '{serie.nombre}' no tiene datos en el rango pedido."
        )
    return anios


def maximo(serie, grupo=None, desde=None, hasta=None, excluir=()):
    """Valor máximo de la serie a lo largo de los años."""
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    return max(serie.obtener(a, grupo) for a in anios)


def minimo(serie, grupo=None, desde=None, hasta=None, excluir=()):
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    return min(serie.obtener(a, grupo) for a in anios)


def anio_maximo(serie, grupo=None, desde=None, hasta=None, excluir=()):
    """Año en que la serie alcanza su máximo."""
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    return max(anios, key=lambda a: serie.obtener(a, grupo))


def anio_minimo(serie, grupo=None, desde=None, hasta=None, excluir=()):
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    return min(anios, key=lambda a: serie.obtener(a, grupo))


def promedio(serie, desde=None, hasta=None, grupo=None, excluir=()):
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    valores = [serie.obtener(a, grupo) for a in anios]
    return sum(valores) / len(valores)


def rango(serie, anio, grupo=None, desde=None, hasta=None, excluir=()):
    """Posición (1 = el más alto) del año dentro de la serie."""
    anio = serie._resolver_anio(anio)
    anios = _anios_filtrados(serie, grupo, desde, hasta, excluir)
    ordenados = sorted(anios, key=lambda a: -serie.obtener(a, grupo))
    return ordenados.index(anio) + 1


def ordinal(n):
    """3 -> 'tercer'."""
    n = int(n)
    return ORDINALES[n] if 1 <= n < len(ORDINALES) else f"{n}º"


def ranking(serie, anio, asc=False, minimo_casos=None):
    """Lista [(grupo, valor)] del año, ordenada por valor.

    `minimo_casos` deja fuera los grupos con menos de ese % de casos.
    """
    anio = serie._resolver_anio(anio)
    filas = []
    for grupo in {g for a, g in serie.valores if a == anio and g is not None}:
        valor = serie.obtener(anio, grupo)
        if valor is None:
            continue
        if minimo_casos is not None:
            parte = serie.participacion(anio, grupo)
            if parte is None or parte < minimo_casos:
                continue
        filas.append((grupo, valor))
    filas.sort(key=lambda par: par[1], reverse=not asc)
    if not filas:
        raise FaltaDato(f"La serie '{serie.nombre}' no tiene grupos en {anio}.")
    return filas


def mayor(serie, anio, minimo_casos=None):
    return ranking(serie, anio, minimo_casos=minimo_casos)[0]


def menor(serie, anio, minimo_casos=None):
    return ranking(serie, anio, asc=True, minimo_casos=minimo_casos)[0]


def lista(items, decimales=1, sufijo="%"):
    """[('Pastaza', 96.6), ...] -> 'Pastaza (96.6%), Napo (93.5%) y ...'"""
    partes = []
    for item in items:
        if isinstance(item, (list, tuple)) and len(item) == 2:
            partes.append(f"{item[0]} ({formatear(item[1], decimales)}{sufijo})")
        else:
            partes.append(formatear(item, decimales))
    if len(partes) <= 1:
        return "".join(partes)
    return ", ".join(partes[:-1]) + " y " + partes[-1]


def nombres(items):
    """Solo los nombres de un ranking."""
    return [i[0] if isinstance(i, (list, tuple)) else i for i in items]


def ult(serie):
    """Último año con datos de esa serie (útil cuando no llega al año general)."""
    return serie.ultimo


def veces(a, b):
    return a / b if b else float("nan")


# ---------------------------------------------------------------------------
# Espacio de nombres y evaluación
# ---------------------------------------------------------------------------

BUILTINS_SEGUROS = {
    "abs": abs, "min": min, "max": max, "round": round, "len": len,
    "sorted": sorted, "sum": sum, "int": int, "float": float, "str": str,
    "range": range, "list": list, "enumerate": enumerate, "zip": zip,
}

AYUDAS = {
    "maximo": maximo, "minimo": minimo,
    "anio_maximo": anio_maximo, "anio_minimo": anio_minimo,
    "promedio": promedio, "rango": rango, "ordinal": ordinal,
    "ranking": ranking, "mayor": mayor, "menor": menor,
    "lista": lista, "nombres": nombres, "ult": ult, "veces": veces,
    "formatear": formatear,
}


class Referencias(dict):
    """Permite escribir {{G.area}} o {{T.provincia}} en el texto."""

    def __getattr__(self, nombre):
        if nombre in self:
            return self[nombre]
        raise ErrorDeExpresion(
            f"No existe el marcador '{nombre}'. "
            f"Disponibles: {sorted(self)}"
        )


def construir_espacio(series, referencias_graficos, referencias_tablas,
                      serie_referencia="inf"):
    espacio = dict(AYUDAS)
    espacio.update(series)
    espacio["G"] = Referencias(referencias_graficos)
    espacio["T"] = Referencias(referencias_tablas)
    if serie_referencia in series:
        espacio["ultimo"] = series[serie_referencia].ultimo
        espacio["primero"] = series[serie_referencia].primero
    return espacio


def evaluar(expresion, espacio):
    try:
        return eval(expresion, {"__builtins__": BUILTINS_SEGUROS}, espacio)  # noqa: S307
    except FaltaDato:
        raise
    except Exception as error:  # noqa: BLE001
        raise ErrorDeExpresion(f"{expresion!r}: {error}") from error


def resolver(texto, espacio, registro=None):
    """Sustituye todas las expresiones {{ }} de un texto."""

    def _reemplazo(coincidencia):
        cuerpo = coincidencia.group(1).strip()
        decimales = 1
        crudo = False
        if "|" in cuerpo:
            cuerpo, formato = cuerpo.rsplit("|", 1)
            cuerpo, formato = cuerpo.strip(), formato.strip()
            if formato == "crudo":
                crudo = True
            else:
                try:
                    decimales = int(formato)
                except ValueError:
                    raise ErrorDeExpresion(
                        f"Formato desconocido '{formato}' en {{{{{cuerpo}}}}}"
                    )
        valor = evaluar(cuerpo, espacio)
        texto_valor = str(valor) if crudo else formatear(valor, decimales)
        if registro is not None:
            registro[cuerpo] = texto_valor
        return texto_valor

    return PATRON.sub(_reemplazo, texto)

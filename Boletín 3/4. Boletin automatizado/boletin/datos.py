# -*- coding: utf-8 -*-
"""Lectura de los Excel que exporta analisis_descriptivo.do.

Cada columna de cada archivo se convierte en una `Serie`, que es lo que el
contenido del boletín consulta dentro de {{ }}.
"""

from __future__ import annotations

from pathlib import Path

try:
    import openpyxl
except ImportError:  # pragma: no cover
    raise SystemExit(
        "Falta openpyxl.\n"
        "Corra el generador con el python del entorno del proyecto:\n"
        "    .venv/bin/python generar_boletin.py\n"
        "o cree el entorno si no existe:\n"
        "    python3 -m venv .venv\n"
        "    .venv/bin/pip install -r requirements.txt"
    )


class FaltaDato(KeyError):
    """Se pidió un dato que no existe en los Excel exportados por Stata."""


def _texto(valor):
    if valor is None:
        return None
    if isinstance(valor, float) and valor.is_integer():
        valor = int(valor)
    texto = str(valor).strip()
    return texto or None


class Serie:
    """Serie anual, opcionalmente desagregada por grupo.

    Uso desde el contenido del boletín::

        inf[2025]                 valor nacional de 2025
        inf[-1]                   último año disponible
        inf_area[-1, 'Rural']     último año, grupo Rural
        inf_prov.ultimo           año más reciente de la serie
    """

    def __init__(self, nombre, valores=None, casos=None):
        self.nombre = nombre
        self.valores = dict(valores or {})
        self.casos = dict(casos or {})

    # -- construcción ------------------------------------------------------
    def agregar(self, anio, grupo, valor, casos=None):
        self.valores[(anio, grupo)] = valor
        if casos is not None:
            self.casos[(anio, grupo)] = casos

    # -- metadatos ---------------------------------------------------------
    @property
    def anios(self):
        return sorted({a for a, _ in self.valores})

    @property
    def grupos(self):
        """Grupos ordenados por valor descendente en el último año."""
        grupos = {g for _, g in self.valores if g is not None}
        if not grupos:
            return []
        ultimo = self.ultimo
        return sorted(
            grupos,
            key=lambda g: (-(self.obtener(ultimo, g) or -1e9), g),
        )

    @property
    def ultimo(self):
        anios = self.anios
        if not anios:
            raise FaltaDato(f"La serie '{self.nombre}' está vacía.")
        return anios[-1]

    @property
    def primero(self):
        return self.anios[0]

    # -- acceso ------------------------------------------------------------
    def _resolver_anio(self, anio):
        anios = self.anios
        if isinstance(anio, int) and anio < 0:
            try:
                return anios[anio]
            except IndexError:
                raise FaltaDato(
                    f"La serie '{self.nombre}' no tiene {abs(anio)} años de datos."
                )
        return int(anio)

    def obtener(self, anio, grupo=None):
        """Valor o None si no existe."""
        anio = self._resolver_anio(anio)
        return self.valores.get((anio, _texto(grupo) if grupo is not None else None))

    def __getitem__(self, clave):
        if isinstance(clave, tuple):
            anio, grupo = clave
        else:
            anio, grupo = clave, None
        valor = self.obtener(anio, grupo)
        if valor is None:
            detalle = f"{self._resolver_anio(anio)}"
            if grupo is not None:
                detalle += f", grupo '{grupo}'"
            disponibles = ""
            if grupo is not None and self.grupos:
                disponibles = f" Grupos disponibles: {sorted(self.grupos)}."
            raise FaltaDato(
                f"No hay dato de '{self.nombre}' para {detalle}.{disponibles}"
            )
        return valor

    def casos_de(self, anio, grupo=None):
        anio = self._resolver_anio(anio)
        return self.casos.get((anio, _texto(grupo) if grupo is not None else None))

    def participacion(self, anio, grupo):
        """% de casos del grupo sobre el total del año (None si no hay N)."""
        anio = self._resolver_anio(anio)
        total = sum(
            n
            for (a, g), n in self.casos.items()
            if a == anio and g is not None and self.valores.get((a, g)) is not None
        )
        propio = self.casos_de(anio, grupo)
        if not total or propio is None:
            return None
        return propio / total * 100.0

    def __repr__(self):  # pragma: no cover
        return f"<Serie {self.nombre}: {len(self.valores)} datos>"


def leer_excel(ruta: Path):
    """Devuelve (encabezados, filas) de la primera hoja."""
    libro = openpyxl.load_workbook(ruta, read_only=True, data_only=True)
    try:
        hoja = libro.worksheets[0]
        iterador = hoja.iter_rows(values_only=True)
        encabezados = [_texto(c) for c in next(iterador)]
        filas = [f for f in iterador if any(c is not None for c in f)]
    finally:
        libro.close()
    return encabezados, filas


def cargar_series(fuentes, dir_resultados: Path):
    """Construye el diccionario {nombre: Serie} a partir de FUENTES.

    Cada fuente se lee de ``dir_resultados`` salvo que traiga la clave
    ``carpeta`` con una ruta propia (por ejemplo, las series de pobreza
    laboral, que las produce otro análisis y viven en otra carpeta).
    """
    series = {}
    avisos = []

    for fuente in fuentes:
        base = Path(fuente.get("carpeta") or dir_resultados)
        ruta = base / fuente["archivo"]
        if not ruta.exists():
            avisos.append(
                f"No se encontró {ruta}: no se cargaron las series "
                f"{sorted(fuente['series'].values())}. "
                f"Vuelva a correr el análisis que lo produce "
                f"({fuente.get('origen', 'analisis_descriptivo.do')})."
            )
            continue

        encabezados, filas = leer_excel(ruta)
        indice = {nombre: i for i, nombre in enumerate(encabezados) if nombre}

        col_anio = indice.get(fuente["col_anio"])
        col_grupo = indice.get(fuente.get("col_grupo")) if fuente.get("col_grupo") else None
        col_casos = indice.get(fuente.get("col_casos")) if fuente.get("col_casos") else None
        escala = fuente.get("escala", 1)
        etiquetas = fuente.get("etiquetas") or {}

        if col_anio is None:
            avisos.append(
                f"{ruta.name}: no tiene la columna '{fuente['col_anio']}'."
            )
            continue

        for columna, nombre in fuente["series"].items():
            if columna not in indice:
                avisos.append(f"{ruta.name}: falta la columna '{columna}'.")
                continue
            serie = series.setdefault(nombre, Serie(nombre))
            col_valor = indice[columna]

            for fila in filas:
                anio = fila[col_anio]
                valor = fila[col_valor]
                if anio is None or valor is None:
                    continue
                grupo = None
                if col_grupo is not None:
                    grupo = _texto(fila[col_grupo])
                    if grupo is None:
                        continue  # filas sin desagregación (totales)
                    grupo = etiquetas.get(grupo, grupo)
                casos = fila[col_casos] if col_casos is not None else None
                serie.agregar(
                    int(anio),
                    grupo,
                    float(valor) * escala,
                    int(casos) if casos is not None else None,
                )

    return series, avisos

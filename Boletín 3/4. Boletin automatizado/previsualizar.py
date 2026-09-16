#!/usr/bin/env python3
"""Vista previa del boletín en el navegador, con recarga automática.

Sirve el contenido de contenido/boletin3.md ya resuelto (las {{ }} calculadas
con las mismas series que usa generar_boletin.py) como una página web. La
página se recarga sola cuando cambia el markdown o cuando se regeneran los
gráficos, así que el ciclo es: guardar el .md y mirar el navegador.

No genera ni toca el .docx: es sólo para revisar mientras se escribe.

    .venv/bin/python previsualizar.py
    .venv/bin/python previsualizar.py --puerto 8080 --no-abrir
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

DIR_CODIGO = Path(__file__).resolve().parent
sys.path.insert(0, str(DIR_CODIGO))

import configuracion as cfgmod  # noqa: E402
from boletin import contenido as contenido_mod  # noqa: E402
from boletin import imagenes as imagenes_mod  # noqa: E402  (no usado, importado por simetría)
from boletin import indicadores as ind  # noqa: E402
from boletin import tablas as tablas_mod  # noqa: E402
from boletin.datos import cargar_series  # noqa: E402

# Rutas de imagen servidas en esta corrida: id -> Path. Se llena al renderizar.
_IMAGENES: dict[str, Path] = {}


# ---------------------------------------------------------------------------
# Resolución de figuras (misma lógica que generar_boletin.py)
# ---------------------------------------------------------------------------
def resolver_ruta_figura(archivos):
    for carpeta, relativa in archivos:
        base = cfgmod.BASES_FIGURAS.get(carpeta)
        if base is None:
            continue
        ruta = Path(base) / relativa
        if ruta.is_file():
            return ruta
    return None


def marca_de_tiempo() -> str:
    """Huella de los insumos: cambia si se edita el .md o se rehacen figuras."""
    partes = []
    try:
        partes.append(str(Path(cfgmod.ARCHIVO_CONTENIDO).stat().st_mtime))
    except OSError:
        partes.append("0")
    for base in cfgmod.BASES_FIGURAS.values():
        base = Path(base)
        if not base.is_dir():
            continue
        try:
            for ruta in sorted(base.rglob("*"))[:400]:
                if ruta.suffix.lower() in (".png", ".xlsx"):
                    partes.append(f"{ruta.name}:{ruta.stat().st_mtime}")
        except OSError:
            pass
    return str(hash("|".join(partes)))


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------
def enfatizar(texto: str) -> str:
    """**negrita** y *cursiva* a HTML, sobre texto ya escapado."""
    texto = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", texto)
    texto = re.sub(r"(?<!\*)\*([^*]+?)\*(?!\*)", r"<em>\1</em>", texto)
    return texto


def esc(texto) -> str:
    return enfatizar(html.escape(str(texto or "")))


def construir_html() -> tuple[str, list[str]]:
    avisos: list[str] = []
    _IMAGENES.clear()

    series, avisos_datos = cargar_series(cfgmod.FUENTES, cfgmod.DIR_RESULTADOS)
    avisos.extend(avisos_datos)

    bloques = contenido_mod.leer(Path(cfgmod.ARCHIVO_CONTENIDO))
    ref_graficos, ref_tablas = contenido_mod.numerar(
        bloques,
        cfgmod.DOCUMENTO["etiqueta_grafico"],
        cfgmod.DOCUMENTO["etiqueta_tabla"],
    )
    espacio = ind.construir_espacio(
        series, ref_graficos, ref_tablas, cfgmod.SERIE_DE_REFERENCIA
    )

    def txt(valor):
        if not valor:
            return valor
        try:
            return ind.resolver(valor, espacio, None)
        except ind.ErrorDeExpresion as error:
            avisos.append(str(error))
            return valor

    partes: list[str] = []
    en_lista = False

    def cerrar_lista():
        nonlocal en_lista
        if en_lista:
            partes.append("</ul>")
            en_lista = False

    for bloque in bloques:
        tipo = bloque["tipo"]

        if tipo != "vineta":
            cerrar_lista()

        if tipo == "titulo":
            partes.append(f"<h1>{esc(txt(bloque['texto']))}</h1>")
        elif tipo == "seccion":
            partes.append(f"<h2>{esc(txt(bloque['texto']))}</h2>")
        elif tipo == "subseccion":
            partes.append(f"<h3>{esc(txt(bloque['texto']))}</h3>")
        elif tipo == "parrafo":
            contenido_p = esc(txt(bloque["texto"]))
            if contenido_p.strip():
                partes.append(f"<p>{contenido_p}</p>")
        elif tipo == "vineta":
            if not en_lista:
                partes.append("<ul>")
                en_lista = True
            partes.append(f"<li>{esc(txt(bloque['texto']))}</li>")
        elif tipo == "salto":
            partes.append('<hr class="salto">')
        elif tipo == "equipo":
            filas = "".join(
                f"<div class='eq-fila'><span class='eq-rol'>{esc(rol)}</span>"
                f"<span class='eq-nombres'>{esc(', '.join(nombres))}</span></div>"
                for rol, nombres in cfgmod.EQUIPO
            )
            partes.append(f"<div class='equipo'>{filas}</div>")
        elif tipo == "cuadro":
            cuerpo = "".join(f"<p>{esc(txt(p))}</p>" for p in bloque["parrafos"])
            titulo = bloque.get("titulo")
            enc = f"<h4>{esc(txt(titulo))}</h4>" if titulo else ""
            partes.append(f"<aside class='cuadro'>{enc}{cuerpo}</aside>")

        elif tipo == "grafico":
            cfg = cfgmod.GRAFICOS.get(bloque["id"])
            if cfg is None:
                avisos.append(f"El gráfico '{bloque['id']}' no está en GRAFICOS.")
                continue
            etiqueta = f"{cfgmod.DOCUMENTO['etiqueta_grafico']} {bloque['numero']}"
            partes.append("<figure>")
            partes.append(
                f"<figcaption class='cap'>{etiqueta}. {esc(txt(cfg['titulo']))}</figcaption>"
            )
            ruta = resolver_ruta_figura(cfg["archivos"])
            if ruta is None:
                esperado = ", ".join(r for _, r in cfg["archivos"])
                avisos.append(f"{etiqueta}: no se encontró la imagen ({esperado}).")
                partes.append(
                    f"<div class='falta'>Falta la imagen de {etiqueta}</div>"
                )
            else:
                _IMAGENES[bloque["id"]] = ruta
                partes.append(
                    f"<img src='/img?id={html.escape(bloque['id'])}&amp;v={ruta.stat().st_mtime}' "
                    f"alt='{etiqueta}'>"
                )
            for clave in ("fuente", "elaboracion", "nota"):
                if cfg.get(clave):
                    partes.append(f"<p class='pie'>{esc(txt(cfg[clave]))}</p>")
            partes.append("</figure>")

        elif tipo == "tabla":
            cfg = cfgmod.TABLAS.get(bloque["id"])
            if cfg is None:
                avisos.append(f"La tabla '{bloque['id']}' no está en TABLAS.")
                continue
            etiqueta = f"{cfgmod.DOCUMENTO['etiqueta_tabla']} {bloque['numero']}"
            partes.append("<figure>")
            partes.append(
                f"<figcaption class='cap'>{etiqueta}. {esc(txt(cfg['titulo']))}</figcaption>"
            )
            serie = series.get(cfg["serie"])
            if serie is None:
                avisos.append(f"{etiqueta}: falta la serie '{cfg['serie']}'.")
                partes.append(f"<div class='falta'>Falta la serie de {etiqueta}</div>")
            else:
                encabezados, filas = tablas_mod.construir(serie, cfg)
                th = "".join(f"<th>{esc(h)}</th>" for h in encabezados)
                trs = "".join(
                    "<tr>" + "".join(f"<td>{esc(c)}</td>" for c in fila) + "</tr>"
                    for fila in filas
                )
                partes.append(
                    f"<div class='scroll'><table><thead><tr>{th}</tr></thead>"
                    f"<tbody>{trs}</tbody></table></div>"
                )
            for clave in ("fuente", "elaboracion", "nota"):
                if cfg.get(clave):
                    partes.append(f"<p class='pie'>{esc(txt(cfg[clave]))}</p>")
            partes.append("</figure>")

    cerrar_lista()
    return "\n".join(partes), avisos


PLANTILLA = """<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vista previa · Boletín 3</title>
<style>
  :root{ color-scheme: light; }
  body{ margin:0; background:#eceef1; color:#16202b;
        font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif; }
  .barra{ position:sticky; top:0; z-index:5; background:#16202b; color:#fff;
          padding:10px 20px; font-size:13px; display:flex; gap:16px; align-items:center; }
  .barra b{ font-weight:600; }
  .punto{ width:8px; height:8px; border-radius:50%; background:#4ade80; display:inline-block; }
  .hoja{ max-width:820px; margin:24px auto 80px; background:#fff; padding:56px 64px;
         box-shadow:0 1px 3px rgba(0,0,0,.12); }
  h1{ font-size:28px; line-height:1.25; margin:0 0 24px; }
  h2{ font-size:22px; margin:40px 0 12px; border-bottom:2px solid #16202b; padding-bottom:6px; }
  h3{ font-size:17px; margin:28px 0 8px; }
  h4{ font-size:15px; margin:0 0 8px; }
  p{ margin:0 0 12px; text-align:justify; }
  ul{ margin:0 0 16px; padding-left:22px; }
  li{ margin-bottom:8px; }
  figure{ margin:28px 0; }
  .cap{ font-weight:600; font-size:14px; margin-bottom:8px; }
  img{ max-width:100%; display:block; border:1px solid #e3e6ea; }
  .pie{ font-size:12px; color:#5a6876; margin:4px 0 0; text-align:left; }
  .falta{ padding:28px; border:2px dashed #c9ced6; color:#8a939d; text-align:center; font-size:14px; }
  .cuadro{ background:#f5f7f9; border-left:3px solid #16202b; padding:16px 20px; margin:24px 0; }
  .cuadro p{ font-size:14px; }
  .equipo{ background:#f5f7f9; padding:16px 20px; margin:20px 0; font-size:13px; }
  .eq-fila{ display:flex; gap:12px; margin-bottom:4px; }
  .eq-rol{ font-weight:600; min-width:180px; }
  .scroll{ overflow-x:auto; }
  table{ border-collapse:collapse; font-size:12px; width:100%; }
  th,td{ border:1px solid #dde2e8; padding:4px 7px; text-align:right; white-space:nowrap; }
  th{ background:#f2f4f7; font-weight:600; }
  td:first-child, th:first-child{ text-align:left; }
  .salto{ border:0; border-top:1px dashed #c9ced6; margin:36px 0; }
  .avisos{ max-width:820px; margin:0 auto; background:#fdf3e7; border-left:3px solid #c9803a;
           padding:12px 20px; font-size:13px; }
  .avisos ul{ margin:6px 0 0; }
  @media (max-width:700px){ .hoja{ padding:28px 20px; margin:12px; } }
</style></head><body>
<div class="barra">
  <span class="punto"></span>
  <b>Vista previa del Boletín 3</b>
  <span>se actualiza sola al guardar contenido/boletin3.md</span>
</div>
__AVISOS__
<div class="hoja">__CUERPO__</div>
<script>
  let version = "__VERSION__";
  setInterval(async () => {
    try {
      const r = await fetch("/version", {cache:"no-store"});
      const v = (await r.json()).version;
      if (v !== version) location.reload();
    } catch (e) {}
  }, 1000);
</script>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # silencio
        pass

    def _enviar(self, cuerpo: bytes, tipo: str, cache: bool = False):
        self.send_response(200)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(cuerpo)))
        if not cache:
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(cuerpo)

    def do_GET(self):
        partes = urlparse(self.path)

        if partes.path == "/version":
            self._enviar(
                json.dumps({"version": marca_de_tiempo()}).encode(),
                "application/json",
            )
            return

        if partes.path == "/img":
            ident = parse_qs(partes.query).get("id", [""])[0]
            ruta = _IMAGENES.get(ident)
            if ruta is None or not ruta.is_file():
                self.send_error(404)
                return
            self._enviar(ruta.read_bytes(), "image/png", cache=True)
            return

        try:
            cuerpo, avisos = construir_html()
        except Exception as error:  # noqa: BLE001
            detalle = html.escape(f"{type(error).__name__}: {error}")
            cuerpo = f"<h1>Error al armar la vista previa</h1><pre>{detalle}</pre>"
            avisos = []

        bloque_avisos = ""
        if avisos:
            items = "".join(f"<li>{html.escape(a)}</li>" for a in avisos)
            bloque_avisos = (
                f"<div class='avisos'><b>{len(avisos)} aviso(s)</b><ul>{items}</ul></div>"
            )

        pagina = (
            PLANTILLA.replace("__CUERPO__", cuerpo)
            .replace("__AVISOS__", bloque_avisos)
            .replace("__VERSION__", marca_de_tiempo())
        )
        self._enviar(pagina.encode("utf-8"), "text/html; charset=utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--puerto", type=int, default=8765)
    parser.add_argument("--no-abrir", action="store_true",
                        help="No abrir el navegador automáticamente.")
    args = parser.parse_args()

    url = f"http://localhost:{args.puerto}/"
    servidor = ThreadingHTTPServer(("127.0.0.1", args.puerto), Handler)

    print(f"Vista previa en {url}")
    print(f"Editá {cfgmod.ARCHIVO_CONTENIDO}")
    print("La página se recarga sola al guardar. Ctrl-C para salir.")

    if not args.no_abrir:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()

    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nVista previa cerrada.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

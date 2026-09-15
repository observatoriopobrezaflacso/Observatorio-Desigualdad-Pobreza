# -*- coding: utf-8 -*-
"""Ejecución de los do-files de Stata en modo batch.

Stata en modo `-b do` no respeta las comillas de la línea de comandos, así que
las rutas con espacios (todas las de este repositorio) fallan con r(601). Por
eso se corre un do-file envoltorio, escrito en un directorio temporal sin
espacios, que a su vez hace `do "<ruta real>"`.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
from pathlib import Path

ERROR_STATA = re.compile(r"^r\((\d+)\);", re.M)


class ErrorDeStata(RuntimeError):
    pass


def correr(do_file, ejecutable, dir_logs: Path, verboso=True):
    """Corre un .do y devuelve la ruta del log. Lanza ErrorDeStata si falla."""
    do_file = Path(do_file)
    if not do_file.exists():
        raise ErrorDeStata(f"No existe el do-file: {do_file}")
    if not Path(ejecutable).exists():
        raise ErrorDeStata(
            f"No se encontró Stata en {ejecutable}. "
            "Ajuste STATA_EJECUTABLE en configuracion.py."
        )

    dir_logs = Path(dir_logs)
    dir_logs.mkdir(parents=True, exist_ok=True)
    log = dir_logs / f"{do_file.stem}.log"
    if verboso:
        print(f"  → Stata: {do_file.name}")

    with tempfile.TemporaryDirectory() as temporal:
        envoltorio = Path(temporal) / "correr.do"
        envoltorio.write_text(f'do "{do_file}"\n', encoding="utf-8")

        proceso = subprocess.run(
            [str(ejecutable), "-b", "do", str(envoltorio)],
            cwd=temporal,
            capture_output=True,
            text=True,
        )

        generado = Path(temporal) / "correr.log"
        contenido = (
            generado.read_text(errors="replace")
            if generado.exists()
            else (proceso.stdout or "")
        )
        log.write_text(contenido, encoding="utf-8")

    errores = ERROR_STATA.findall(contenido)
    if proceso.returncode != 0 or errores:
        codigo = errores[-1] if errores else proceso.returncode
        raise ErrorDeStata(
            f"{do_file.name} terminó con error r({codigo}). Revise el log:\n  {log}"
        )
    return log


def correr_etapa(etapa, etapas, ejecutable, dir_logs, verboso=True):
    if etapa not in etapas:
        raise ErrorDeStata(
            f"Etapa desconocida '{etapa}'. Opciones: {sorted(etapas)}"
        )
    return [correr(do, ejecutable, dir_logs, verboso) for do in etapas[etapa]]

#!/usr/bin/env python3
"""Compute weighted average labor income (ing_lab) from historico.dta.

Reads: GoogleDrive/.../pobreza/historico.dta
Writes: Dashboards/data/Data final/empleo/salarios/salarios_series.xlsx

Keeps existing "Salario básico" rows from the original file and replaces
"Salario promedio" with weighted averages computed from microdata.
"""
import os
import numpy as np
import pandas as pd

SRC = os.path.expanduser(
    "~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/"
    "Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza/historico.dta"
)
OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "data", "Data final", "empleo", "salarios"
)
OUT_FILE = os.path.join(OUT_DIR, "salarios_series.xlsx")

SALARIO_BASICO = {
    2001: 85.65, 2003: 121.91, 2005: 150, 2007: 170, 2008: 200,
    2009: 218, 2010: 240, 2011: 264, 2012: 292, 2013: 318,
    2014: 340, 2015: 354, 2016: 366, 2017: 375, 2018: 386,
    2019: 394, 2020: 400, 2021: 400, 2022: 425, 2023: 450,
    2024: 460, 2025: 470,
}

print("Reading", SRC)
df = pd.read_stata(SRC, columns=["anio", "ing_lab", "fexp"])
df = df.dropna(subset=["ing_lab", "fexp", "anio"])
df["anio"] = df["anio"].astype(int)

rows = []
for anio in sorted(df["anio"].unique()):
    g = df[df["anio"] == anio]
    avg = np.average(g["ing_lab"], weights=g["fexp"])
    if anio in SALARIO_BASICO:
        rows.append({"anio": anio, "tipo": "Salario básico", "valor": round(SALARIO_BASICO[anio], 4)})
    rows.append({"anio": anio, "tipo": "Salario promedio", "valor": round(avg, 4)})

out = pd.DataFrame(rows)
out.to_excel(OUT_FILE, index=False)
print(f"Wrote {OUT_FILE}: {len(out)} rows")
for _, r in out.iterrows():
    print(f"  {r['anio']} {r['tipo']}: {r['valor']:.2f}")

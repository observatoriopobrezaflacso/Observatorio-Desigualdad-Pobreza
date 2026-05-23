#!/usr/bin/env python3
"""Compute poverty rates from ENEMDU microdata and export to Excel for the dashboard.

Reads:
  - GoogleDrive/.../pobreza/historico.dta          (national/area/sex/educ/age)
  - GoogleDrive/.../con_pobreza/ing_perca_*_nac_precios2000.dta  (province, ethnicity)

Writes all poverty datasets to: Dashboards/data/Data final/pobreza/
  - series_historicas_indicadores.xlsx  (national time series)
  - Pobreza_tableau.xlsx                (by nivel: Nacional/Urbano/Rural)
  - pobreza_sexo_etnia.xlsx             (by sex and ethnicity)
  - pobreza_educacion.xlsx              (by education level)
  - pobreza_edad.xlsx                   (by age group)
  - pobreza_provincial.xlsx             (by province)
  - variacion_pobreza_significancia.xlsx (year-over-year with significance)
"""
import os
import glob
import numpy as np
import pandas as pd
from scipy import stats

SRC = os.path.expanduser(
    "~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/"
    "Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza/historico.dta"
)
SRC_INDIV = os.path.expanduser(
    "~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/"
    "Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/con_pobreza/"
)
OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "data", "Data final", "pobreza"
)

PROVINCIA_NAMES = {
    1: "Azuay", 2: "Bolívar", 3: "Cañar", 4: "Carchi", 5: "Cotopaxi",
    6: "Chimborazo", 7: "El Oro", 8: "Esmeraldas", 9: "Guayas",
    10: "Imbabura", 11: "Loja", 12: "Los Ríos", 13: "Manabí",
    14: "Morona Santiago", 15: "Napo", 16: "Pastaza", 17: "Pichincha",
    18: "Tungurahua", 19: "Zamora Chinchipe", 20: "Galápagos",
    21: "Sucumbíos", 22: "Orellana", 23: "Santo Domingo de los Tsáchilas",
    24: "Santa Elena",
}

ETNIA_MAP_STR = {
    " Indígena": "Indígena",
    " Afroecuatoriano": "Afroecuatoriano",
    " Negro": "Afroecuatoriano",
    " Mulato": "Afroecuatoriano",
    " Montuvio": "Montuvio",
    " Mestizo": "Mestizo",
    " Blanco": "Blanco",
}
ETNIA_MAP_NUM = {
    1: "Indígena", 2: "Afroecuatoriano", 3: "Afroecuatoriano",
    4: "Afroecuatoriano", 5: "Montuvio", 6: "Mestizo", 7: "Blanco",
}

# ── Load historico.dta ──────────────────────────────────────────────
print("Reading", SRC)
df = pd.read_stata(SRC)
df = df.dropna(subset=["pobreza", "fexp", "anio"])
df["anio"] = df["anio"].astype(int)
df["linea_pobreza"] = df["linea_pobreza"].astype(float)
df["ingreso_pobreza"] = df["ingreso_pobreza"].astype(float)
df["pobre"] = (df["pobreza"] == "Pobre").astype(int)
df["pobre_extremo"] = (df["ingreso_pobreza"] < df["linea_pobreza"] * 0.5625).astype(int)

AGE_GROUPS = [
    ("Niños (0-17)", 0, 17),
    ("Jóvenes (18-29)", 18, 29),
    ("Adultos (30-64)", 30, 64),
    ("Adultos mayores (65+)", 65, 200),
]
df["grupoEtario"] = pd.cut(
    df["edad"],
    bins=[0, 18, 30, 65, 200],
    labels=["Niños (0-17)", "Jóvenes (18-29)", "Adultos (30-64)", "Adultos mayores (65+)"],
    right=False,
)

EDUC_MAP = {
    "Con educacion superior": "Superior",
    "Sin educacion superior": "Menos que superior",
}
df["nivelEducativo"] = df["educacion_superior"].map(EDUC_MAP)

# ── Load individual year files (for province and ethnicity) ─────────
print("Reading individual year files from", SRC_INDIV)
indiv_files = sorted(glob.glob(os.path.join(SRC_INDIV, "ing_perca_*_nac_precios2000.dta")))
dfs_indiv = []
for fpath in indiv_files:
    print(f"  {os.path.basename(fpath)}")
    peek = pd.read_stata(fpath, iterator=True).read(1)
    has_p15 = "p15" in peek.columns
    use_cols = ["ciudad", "fexp", "pobreza", "linea_pobreza", "ingreso_pobreza", "anio"]
    if has_p15:
        use_cols.append("p15")
    tmp = pd.read_stata(fpath, columns=use_cols, convert_categoricals=False)
    tmp = tmp.dropna(subset=["pobreza", "fexp", "anio"])
    tmp["anio"] = tmp["anio"].astype(int)
    tmp["linea_pobreza"] = tmp["linea_pobreza"].astype(float)
    tmp["ingreso_pobreza"] = tmp["ingreso_pobreza"].astype(float)
    tmp["pobre"] = tmp["pobreza"].astype(int)
    tmp["pobre_extremo"] = (tmp["ingreso_pobreza"] < tmp["linea_pobreza"] * 0.5625).astype(int)
    tmp["provincia"] = (tmp["ciudad"].astype(int) // 10000).map(PROVINCIA_NAMES)
    if has_p15:
        tmp["etnia"] = tmp["p15"].map(ETNIA_MAP_NUM)
    else:
        tmp["etnia"] = np.nan
    dfs_indiv.append(tmp)
df_indiv = pd.concat(dfs_indiv, ignore_index=True)


def weighted_rate(group, col):
    return np.average(group[col], weights=group["fexp"]) * 100


def weighted_se(group, col):
    w = group["fexp"].values
    x = group[col].values
    n = len(x)
    if n < 2:
        return np.nan
    p = np.average(x, weights=w)
    n_eff = np.sum(w) ** 2 / np.sum(w**2)
    return np.sqrt(p * (1 - p) / n_eff) * 100


def compute_rates(grouped, indicators=[("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]):
    rows = []
    for keys, g in grouped:
        if not isinstance(keys, tuple):
            keys = (keys,)
        for col, label in indicators:
            row = {"indicador": label, "valor": round(weighted_rate(g, col), 4)}
            rows.append({**dict(zip(grouped.keys, keys)), **row})
    return rows


def write(name, rows):
    out = pd.DataFrame(rows)
    out.to_excel(os.path.join(OUT_DIR, name), index=False)
    print(f"  {name}: {len(out)} rows")


# ── 1. Series históricas (nacional) ─────────────────────────────────
rows = []
for anio, g in df.groupby("anio"):
    rows.append({"anio": anio, "indicador": "Pobreza", "valor": round(weighted_rate(g, "pobre"), 4)})
    rows.append({"anio": anio, "indicador": "Pobreza extrema", "valor": round(weighted_rate(g, "pobre_extremo"), 4)})
write("series_historicas_indicadores.xlsx", rows)

# ── 2. Por nivel (Nacional/Urbano/Rural) — Pobreza_tableau format ────
rows = []
for (anio, area), g in df.groupby(["anio", "area"]):
    nivel = "Urbano" if area == "urbana" else "Rural"
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza Extrema")]:
        rows.append({"ano": anio, "nivel": nivel, "indicador": label, "valor": round(weighted_rate(g, col), 4)})
for anio, g in df.groupby("anio"):
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza Extrema")]:
        rows.append({"ano": anio, "nivel": "Nacional", "indicador": label, "valor": round(weighted_rate(g, col), 4)})
write("Pobreza_tableau.xlsx", rows)

# ── 3. Por sexo y etnia — pobrezaSexoEtnia format ───────────────────
rows = []
for (anio, sexo), g in df.groupby(["anio", "sexo"]):
    grupo = sexo.capitalize()
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        rows.append({
            "anio": anio, "grupo": grupo, "tipoGrupo": "sexo",
            "indicador": label, "valor": round(weighted_rate(g, col), 4),
        })
# Ethnicity from individual year files
sub_etnia = df_indiv.dropna(subset=["etnia"])
for (anio, etnia), g in sub_etnia.groupby(["anio", "etnia"]):
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        rows.append({
            "anio": anio, "grupo": etnia, "tipoGrupo": "etnia",
            "indicador": label, "valor": round(weighted_rate(g, col), 4),
        })
write("pobreza_sexo_etnia.xlsx", rows)

# ── 4. Por educación ─────────────────────────────────────────────────
sub = df.dropna(subset=["nivelEducativo"])
rows = []
for (anio, niv), g in sub.groupby(["anio", "nivelEducativo"]):
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        rows.append({
            "anio": anio, "nivelEducativo": niv,
            "indicador": label, "valor": round(weighted_rate(g, col), 4),
        })
write("pobreza_educacion.xlsx", rows)

# ── 5. Por grupo etario ──────────────────────────────────────────────
sub = df.dropna(subset=["grupoEtario"])
rows = []
for (anio, ge), g in sub.groupby(["anio", "grupoEtario"]):
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        rows.append({
            "grupoEtario": ge, "anio": anio,
            "indicador": label, "valor": round(weighted_rate(g, col), 4),
        })
write("pobreza_edad.xlsx", rows)

# ── 6. Por provincia (from individual year files) ───────────────────
sub_prov = df_indiv.dropna(subset=["provincia"])
rows = []
for (anio, prov), g in sub_prov.groupby(["anio", "provincia"]):
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        rows.append({
            "anio": anio, "provincia": prov,
            "indicador": label, "valor": round(weighted_rate(g, col), 4),
        })
write("pobreza_provincial.xlsx", rows)

# ── 7. Variación con significancia ───────────────────────────────────
var_rows = []
years = sorted(df["anio"].unique())
for i in range(1, len(years)):
    y0, y1 = years[i - 1], years[i]
    g0 = df[df["anio"] == y0]
    g1 = df[df["anio"] == y1]
    for col, label in [("pobre", "Pobreza"), ("pobre_extremo", "Pobreza extrema")]:
        val = weighted_rate(g1, col)
        val_ant = weighted_rate(g0, col)
        se1 = weighted_se(g1, col)
        se0 = weighted_se(g0, col)
        diff = val - val_ant
        se_diff = np.sqrt(se1**2 + se0**2)
        t_stat = diff / se_diff if se_diff > 0 else 0
        p_value = 2 * (1 - stats.norm.cdf(abs(t_stat)))
        if p_value < 0.01:
            sig = "Sí (p<0.01)"
        elif p_value < 0.05:
            sig = "Sí (p<0.05)"
        elif p_value < 0.10:
            sig = "Sí (p<0.10)"
        else:
            sig = "No"
        var_rows.append({
            "anio": y1, "anioAnterior": y0,
            "dimension": "Nacional", "nivel": "Nacional",
            "indicador": label,
            "valor": round(val, 4), "se": round(se1, 4),
            "valorAnterior": round(val_ant, 4), "seAnterior": round(se0, 4),
            "variacionPp": round(diff, 4),
            "variacionPct": round(diff / val_ant * 100, 4) if val_ant else 0,
            "tStat": round(t_stat, 4), "pValue": round(p_value, 4),
            "significativo": sig,
        })
write("variacion_pobreza_significancia.xlsx", var_rows)

print("\nDone. Province and ethnicity computed from individual year files.")

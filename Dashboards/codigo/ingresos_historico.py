#!/usr/bin/env python3
"""Compute weighted average per capita income from ENEMDU microdata.

Reads:
  - GoogleDrive/.../pobreza/historico.dta          (national/area/sex/educ/age)
  - GoogleDrive/.../con_pobreza/ing_perca_*_nac_precios2000.dta  (province, ethnicity)

Writes to: Dashboards/data/Data final/ingresos/
  - ingresos_series.xlsx         (national time series: nominal + deflated)
  - ingresos_area.xlsx           (by area: urbano/rural)
  - ingresos_sexo_etnia.xlsx     (by sex and ethnicity)
  - ingresos_educacion.xlsx      (by education level)
  - ingresos_edad.xlsx           (by age group)
  - ingresos_provincial.xlsx     (by province)
"""
import os
import glob
import numpy as np
import pandas as pd

SRC = os.path.expanduser(
    "~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/"
    "Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/pobreza/historico.dta"
)
SRC_INDIV = os.path.expanduser(
    "~/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/"
    "Mi unidad/Bases/ENEMDU/Procesadas/ingresos_pc/con_pobreza/"
)
OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "data", "Data final", "ingresos"
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

ETNIA_MAP_NUM = {
    1: "Indígena", 2: "Afroecuatoriano", 3: "Afroecuatoriano",
    4: "Afroecuatoriano", 5: "Montuvio", 6: "Mestizo", 7: "Blanco",
}

AGE_LABELS = ["Niños (0-17)", "Jóvenes (18-29)", "Adultos (30-64)", "Adultos mayores (65+)"]
AGE_BINS = [0, 18, 30, 65, 200]

EDUC_MAP = {
    "Con educacion superior": "Superior",
    "Sin educacion superior": "Menos que superior",
}

REGION_MAP = {
    7: "Costa", 8: "Costa", 9: "Costa", 12: "Costa", 13: "Costa",
    20: "Costa", 23: "Costa", 24: "Costa",
    1: "Sierra", 2: "Sierra", 3: "Sierra", 4: "Sierra", 5: "Sierra",
    6: "Sierra", 10: "Sierra", 11: "Sierra", 17: "Sierra", 18: "Sierra",
    14: "Oriente", 15: "Oriente", 16: "Oriente",
    19: "Oriente", 21: "Oriente", 22: "Oriente",
}


def wavg(group, col):
    valid = group.dropna(subset=[col, "fexp"])
    if valid.empty:
        return np.nan
    return np.average(valid[col], weights=valid["fexp"])


def write(name, rows):
    out = pd.DataFrame(rows)
    path = os.path.join(OUT_DIR, name)
    out.to_excel(path, index=False)
    print(f"  {name}: {len(out)} rows")


# ── Load historico.dta ──────────────────────────────────────────────
print("Reading", SRC)
df = pd.read_stata(SRC)
df = df.dropna(subset=["fexp", "anio"])
df["anio"] = df["anio"].astype(int)
df["ingtot_per"] = pd.to_numeric(df["ingtot_per"], errors="coerce")
df["ingtot_per_deflated"] = pd.to_numeric(df["ingtot_per_deflated"], errors="coerce")
df["inglab_per"] = pd.to_numeric(df["ing_lab"], errors="coerce")
df["inglab_per_deflated"] = pd.to_numeric(df["inglab_per_deflated"], errors="coerce")
df["grupoEtario"] = pd.cut(
    df["edad"], bins=AGE_BINS, labels=AGE_LABELS, right=False,
)
df["nivelEducativo"] = df["educacion_superior"].map(EDUC_MAP)

# ── Load individual year files (for province and ethnicity) ─────────
print("Reading individual year files from", SRC_INDIV)
indiv_files = sorted(glob.glob(os.path.join(SRC_INDIV, "ing_perca_*_nac_precios2000.dta")))
dfs_indiv = []
for fpath in indiv_files:
    print(f"  {os.path.basename(fpath)}")
    peek = pd.read_stata(fpath, iterator=True).read(1)
    has_p15 = "p15" in peek.columns
    use_cols = ["ciudad", "fexp", "ingtot_per", "inglab_per", "ing_lab", "anio"]
    if has_p15:
        use_cols.append("p15")
    available = [c for c in use_cols if c in peek.columns]
    tmp = pd.read_stata(fpath, columns=available, convert_categoricals=False)
    tmp = tmp.dropna(subset=["fexp", "anio"])
    tmp["anio"] = tmp["anio"].astype(int)
    tmp["ingtot_per"] = pd.to_numeric(tmp["ingtot_per"], errors="coerce")
    if "inglab_per" in tmp.columns:
        tmp["inglab_per"] = pd.to_numeric(tmp["inglab_per"], errors="coerce")
    elif "ing_lab" in tmp.columns:
        tmp["inglab_per"] = pd.to_numeric(tmp["ing_lab"], errors="coerce")
    else:
        tmp["inglab_per"] = np.nan
    prov_code = tmp["ciudad"].astype(int) // 10000
    tmp["provincia"] = prov_code.map(PROVINCIA_NAMES)
    tmp["region"] = prov_code.map(REGION_MAP)
    if has_p15:
        tmp["etnia"] = tmp["p15"].map(ETNIA_MAP_NUM)
    else:
        tmp["etnia"] = np.nan
    dfs_indiv.append(tmp)
df_indiv = pd.concat(dfs_indiv, ignore_index=True)

# ── 1. Series nacionales (nominal + deflactado) ────────────────────
rows = []
for anio, g in df.groupby("anio"):
    nom = wavg(g, "ingtot_per")
    defl = wavg(g, "ingtot_per_deflated")
    if not np.isnan(nom):
        rows.append({"anio": anio, "tipo": "Nominal", "valor": round(nom, 2)})
    if not np.isnan(defl):
        rows.append({"anio": anio, "tipo": "Real (precios 2000)", "valor": round(defl, 2)})
write("ingresos_series.xlsx", rows)

# ── 2. Por área ─────────────────────────────────────────────────────
rows = []
for (anio, area), g in df.groupby(["anio", "area"]):
    nivel = str(area).capitalize()
    if nivel not in ("Urbana", "Rural"):
        nivel = str(area)
    nivel = nivel.replace("Urbana", "Urbano")
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivel": nivel, "valor": round(val, 2)})
# Nacional
for anio, g in df.groupby("anio"):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivel": "Nacional", "valor": round(val, 2)})
write("ingresos_area.xlsx", rows)

# ── 3. Por sexo y etnia ────────────────────────────────────────────
rows = []
for (anio, sexo), g in df.groupby(["anio", "sexo"]):
    grupo = str(sexo).capitalize()
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "grupo": grupo, "tipoGrupo": "sexo", "valor": round(val, 2)})
sub_etnia = df_indiv.dropna(subset=["etnia"])
for (anio, etnia), g in sub_etnia.groupby(["anio", "etnia"]):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "grupo": etnia, "tipoGrupo": "etnia", "valor": round(val, 2)})
write("ingresos_sexo_etnia.xlsx", rows)

# ── 4. Por educación ───────────────────────────────────────────────
sub = df.dropna(subset=["nivelEducativo"])
rows = []
for (anio, niv), g in sub.groupby(["anio", "nivelEducativo"]):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivelEducativo": niv, "valor": round(val, 2)})
write("ingresos_educacion.xlsx", rows)

# ── 5. Por grupo etario ────────────────────────────────────────────
sub = df.dropna(subset=["grupoEtario"])
rows = []
for (anio, ge), g in sub.groupby(["anio", "grupoEtario"]):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"grupoEtario": str(ge), "anio": anio, "valor": round(val, 2)})
write("ingresos_edad.xlsx", rows)

# ── 6. Por provincia ──────────────────────────────────────────────
sub_prov = df_indiv.dropna(subset=["provincia"])
rows = []
for (anio, prov), g in sub_prov.groupby(["anio", "provincia"]):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "provincia": prov, "valor": round(val, 2)})
write("ingresos_provincial.xlsx", rows)

# ── 7. Por región ──────────────────────────────────────────────────
sub_reg = df_indiv.dropna(subset=["region"])
rows = []
for (anio, reg), g in sub_reg.groupby(["anio", "region"]):
    val = wavg(g, "ingtot_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "region": reg, "valor": round(val, 2)})
write("ingresos_region.xlsx", rows)

# ════════════════════════════════════════════════════════════════════
#  INGRESO LABORAL (inglab_per / inglab_per_deflated)
# ════════════════════════════════════════════════════════════════════

SALARIO_BASICO = {
    2001: 85.65, 2003: 121.91, 2005: 150, 2007: 170, 2008: 200,
    2009: 218, 2010: 240, 2011: 264, 2012: 292, 2013: 318,
    2014: 340, 2015: 354, 2016: 366, 2017: 375, 2018: 386,
    2019: 394, 2020: 400, 2021: 400, 2022: 425, 2023: 450,
    2024: 460, 2025: 470,
}

# ── L1. Series nacionales (nominal + deflactado + salario básico) ──
rows = []
for anio, g in df.groupby("anio"):
    nom = wavg(g, "inglab_per")
    defl = wavg(g, "inglab_per_deflated")
    if not np.isnan(nom):
        rows.append({"anio": anio, "tipo": "Nominal", "valor": round(nom, 2)})
    if not np.isnan(defl):
        rows.append({"anio": anio, "tipo": "Real (precios 2000)", "valor": round(defl, 2)})
    if anio in SALARIO_BASICO:
        rows.append({"anio": anio, "tipo": "Salario básico", "valor": SALARIO_BASICO[anio]})
write("inglab_series.xlsx", rows)

# ── L2. Por área ───────────────────────────────────────────────────
rows = []
for (anio, area), g in df.groupby(["anio", "area"]):
    nivel = str(area).capitalize().replace("Urbana", "Urbano")
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivel": nivel, "valor": round(val, 2)})
for anio, g in df.groupby("anio"):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivel": "Nacional", "valor": round(val, 2)})
write("inglab_area.xlsx", rows)

# ── L3. Por sexo y etnia ──────────────────────────────────────────
rows = []
for (anio, sexo), g in df.groupby(["anio", "sexo"]):
    grupo = str(sexo).capitalize()
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "grupo": grupo, "tipoGrupo": "sexo", "valor": round(val, 2)})
sub_etnia = df_indiv.dropna(subset=["etnia"])
for (anio, etnia), g in sub_etnia.groupby(["anio", "etnia"]):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "grupo": etnia, "tipoGrupo": "etnia", "valor": round(val, 2)})
write("inglab_sexo_etnia.xlsx", rows)

# ── L4. Por educación ─────────────────────────────────────────────
sub = df.dropna(subset=["nivelEducativo"])
rows = []
for (anio, niv), g in sub.groupby(["anio", "nivelEducativo"]):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "nivelEducativo": niv, "valor": round(val, 2)})
write("inglab_educacion.xlsx", rows)

# ── L5. Por grupo etario ──────────────────────────────────────────
sub = df.dropna(subset=["grupoEtario"])
rows = []
for (anio, ge), g in sub.groupby(["anio", "grupoEtario"]):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"grupoEtario": str(ge), "anio": anio, "valor": round(val, 2)})
write("inglab_edad.xlsx", rows)

# ── L6. Por provincia ─────────────────────────────────────────────
sub_prov = df_indiv.dropna(subset=["provincia"])
rows = []
for (anio, prov), g in sub_prov.groupby(["anio", "provincia"]):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "provincia": prov, "valor": round(val, 2)})
write("inglab_provincial.xlsx", rows)

# ── L7. Por región ────────────────────────────────────────────────
sub_reg = df_indiv.dropna(subset=["region"])
rows = []
for (anio, reg), g in sub_reg.groupby(["anio", "region"]):
    val = wavg(g, "inglab_per")
    if not np.isnan(val):
        rows.append({"anio": anio, "region": reg, "valor": round(val, 2)})
write("inglab_region.xlsx", rows)

print("\nDone.")

#!/usr/bin/env python3
"""Copy the original Excel/CSV source files each chart uses into the served
site (docs/dashboard/downloads/) and generate chart-sources.js.

chart-sources.js exposes `window.CHART_SOURCES`, a map from each chart canvas
id to the relative path of the source file it plots. app.js reads this to add a
per-chart download button. Charts whose source depends on a UI selector
(GIC by year range, employment-by-sector by period, LATAM by income/wealth)
are handled by resolvers in app.js and intentionally left out of the map.

Run from anywhere:  python3 docs/dashboard/build_downloads.py
"""
import json
import os
import re
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.join(SCRIPT_DIR, "..", "..")
DATA_DIR = os.path.join(REPO_ROOT, "Dashboards", "data", "Data final")
OUT_DIR = os.path.join(SCRIPT_DIR, "downloads")
OUT_JS = os.path.join(SCRIPT_DIR, "chart-sources.js")

# ── DATA key -> source file (relative to Data final unless it starts with "@") ──
# "@" prefix means relative to the repository root instead of Data final.
KEY_TO_SRC = {
    # Pobreza
    "pobrezaTableau": "pobreza/Pobreza_tableau.xlsx",
    "seriesHistoricas": "pobreza/series_historicas_indicadores.xlsx",
    "pobrezaSexoEtnia": "pobreza/pobreza_sexo_etnia.xlsx",
    "pobrezaEducacion": "pobreza/pobreza_educacion.xlsx",
    "pobrezaEdad": "pobreza/pobreza_edad.xlsx",
    "pobrezaRegion": "pobreza/pobreza_region.xlsx",
    # Ingresos
    "ingresosSeries": "ingresos/ingresos_series.xlsx",
    "ingresosArea": "ingresos/ingresos_area.xlsx",
    "ingresosSexoEtnia": "ingresos/ingresos_sexo_etnia.xlsx",
    "ingresosEducacion": "ingresos/ingresos_educacion.xlsx",
    "ingresosEdad": "ingresos/ingresos_edad.xlsx",
    "ingresosRegion": "ingresos/ingresos_region.xlsx",
    # Ingreso laboral
    "inglabSeries": "ingresos/inglab_series.xlsx",
    "inglabArea": "ingresos/inglab_area.xlsx",
    "inglabSexoEtnia": "ingresos/inglab_sexo_etnia.xlsx",
    "inglabEducacion": "ingresos/inglab_educacion.xlsx",
    "inglabEdad": "ingresos/inglab_edad.xlsx",
    "inglabRegion": "ingresos/inglab_region.xlsx",
    # Empleo
    "empleoSeries": "empleo/empleo adecuado/empleo_series.xlsx",
    "empleoDemografico": "empleo/empleo adecuado/empleo_demografico.xlsx",
    # Informalidad
    "informalidadComponentes": "empleo/informalidad/Informalidad_y_componentes.xlsx",
    "informalidadCondiciones": "empleo/informalidad/n_condiciones_informalidad.xlsx",
    "informalidadGenero": "empleo/informalidad/Informalidad_genero.xlsx",
    "informalidadEdad": "empleo/informalidad/informalidad_edad.xlsx",
    "informalidadEtnia": "empleo/informalidad/informalidad_etnia.xlsx",
    "informalidadEducacion": "empleo/informalidad/informalidad_educacion.xlsx",
    # Pobreza laboral
    "pobrezaLaboral": "empleo/pobreza/pobreza_laboral.xlsx",
    "pobrezaLaboralSexo": "empleo/pobreza/pobreza_lab_sexo.xlsx",
    "pobrezaLaboralArea": "empleo/pobreza/pobreza_lab_area.xlsx",
    "pobrezaLaboralEduc": "empleo/pobreza/pobreza_lab_educ.xlsx",
    "pobrezaLaboralEdad": "empleo/pobreza/pobreza_lab_edad.xlsx",
    # Desigualdad
    "giniPanel": "desigualdad/Gini/gini_panel_tableau.xlsx",
    "giniLacComparison": "desigualdad/Gini/gini_lac_comparison.xlsx",
    "giniDecomposition": "desigualdad/Gini/gini_decomposition.xlsx",
    "giniDecompositionCuartiles": "desigualdad/Gini/gini_decomposition_cuartiles.xlsx",
    "widIngresoPercentiles": "desigualdad/Concentracion/WID/WID_ingreso_percentiles_tableau.xlsx",
    "widRiquezaPercentiles": "desigualdad/Concentracion/WID/WID_riqueza_percentiles_tableau.xlsx",
    "widIngresoPercentilesALC": "desigualdad/Concentracion/WID/WID_ingreso_percentiles_ALC_tableau.xlsx",
    "widRiquezaPercentilesALC": "desigualdad/Concentracion/WID/WID_riqueza_percentiles_ALC_tableau.xlsx",
    "palmaAlc": "desigualdad/Palma/Palma_ALC_tableau.xlsx",
    "sriConcentracion": "desigualdad/Concentracion/SRI/Movilidad y concentracion/Datos graficos todos.xlsx",
    "sriCapital": "desigualdad/Concentracion/SRI/Movilidad y concentracion/serie_graficos_dina_2010_2024.xlsx",
    # Mortalidad / violencia
    "mortalidadJovenes": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_mortalidad_jovenes.xlsx",
    "mortalidadAdultos": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_mortalidad_adultos.xlsx",
    "homicidiosJovenes": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_homicidios_jovenes.xlsx",
    "homicidiosAdultos": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_homicidios_adultos.xlsx",
    "suicidiosJovenes": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_suicidios_jovenes.xlsx",
    "suicidiosAdultos": "desigualdad/Salud/Mortalidad/jovenes y adultos/por educacion/serie_suicidios_adultos.xlsx",
    "homicidiosNna": "@Boletín 3/3. homicidios_nna/datos_homicidios_nna.csv",
}

# ── chart canvas id -> DATA key(s) it plots (primary first) ──
CHART_KEYS = {
    "chart-pov-nivel": ["pobrezaTableau"],
    "chart-pov-etnia": ["pobrezaSexoEtnia"],
    "chart-pov-sexo": ["pobrezaSexoEtnia"],
    "chart-pov-educacion": ["pobrezaEducacion"],
    "chart-pov-edad": ["pobrezaEdad"],
    "chart-pov-region": ["pobrezaRegion"],
    "chart-pov-bar-nivel": ["pobrezaTableau"],
    "chart-pov-bar-sexo": ["pobrezaSexoEtnia"],
    "chart-pov-bar-educacion": ["pobrezaEducacion"],
    "chart-pov-bar-edad": ["pobrezaEdad"],
    "chart-pov-bar-region": ["pobrezaRegion"],
    "chart-pov-hist-combined": ["seriesHistoricas"],
    "chart-pov-hist-sexo": ["pobrezaSexoEtnia"],
    "chart-ing-series": ["ingresosSeries"],
    "chart-ing-area": ["ingresosArea"],
    "chart-ing-sexo": ["ingresosSexoEtnia"],
    "chart-ing-etnia": ["ingresosSexoEtnia"],
    "chart-ing-educacion": ["ingresosEducacion"],
    "chart-ing-edad": ["ingresosEdad"],
    "chart-ing-region": ["ingresosRegion"],
    "chart-ing-bar-area": ["ingresosArea"],
    "chart-ing-bar-etnia": ["ingresosSexoEtnia"],
    "chart-ing-bar-sexo": ["ingresosSexoEtnia"],
    "chart-ing-bar-educacion": ["ingresosEducacion"],
    "chart-ing-bar-edad": ["ingresosEdad"],
    "chart-ing-bar-region": ["ingresosRegion"],
    "chart-decomp-nacional": ["giniDecomposition"],
    "chart-decomp-q1": ["giniDecompositionCuartiles"],
    "chart-decomp-q2": ["giniDecompositionCuartiles"],
    "chart-decomp-q3": ["giniDecompositionCuartiles"],
    "chart-decomp-q4": ["giniDecompositionCuartiles"],
    "chart-inglab-series": ["inglabSeries"],
    "chart-inglab-area": ["inglabArea"],
    "chart-inglab-sexo": ["inglabSexoEtnia"],
    "chart-inglab-etnia": ["inglabSexoEtnia"],
    "chart-inglab-educacion": ["inglabEducacion"],
    "chart-inglab-edad": ["inglabEdad"],
    "chart-inglab-region": ["inglabRegion"],
    "chart-inglab-bar-area": ["inglabArea"],
    "chart-inglab-bar-etnia": ["inglabSexoEtnia"],
    "chart-inglab-bar-sexo": ["inglabSexoEtnia"],
    "chart-inglab-bar-educacion": ["inglabEducacion"],
    "chart-inglab-bar-edad": ["inglabEdad"],
    "chart-inglab-bar-region": ["inglabRegion"],
    "chart-empleo-bar-area": ["empleoDemografico"],
    "chart-empleo-bar-etnia": ["empleoDemografico"],
    "chart-empleo-bar-sexo": ["empleoDemografico"],
    "chart-empleo-bar-educacion": ["empleoDemografico"],
    "chart-empleo-bar-edad": ["empleoDemografico"],
    "chart-empleo-series": ["empleoSeries"],
    "chart-informalidad-componentes": ["informalidadComponentes"],
    "chart-informalidad-condiciones": ["informalidadCondiciones"],
    "chart-informalidad-area": ["informalidadComponentes"],
    "chart-informalidad-sexo": ["informalidadGenero"],
    "chart-informalidad-edad": ["informalidadEdad"],
    "chart-informalidad-etnia": ["informalidadEtnia"],
    "chart-informalidad-educacion": ["informalidadEducacion"],
    "chart-pobreza-laboral": ["pobrezaLaboral"],
    "chart-pobreza-laboral-sexo": ["pobrezaLaboralSexo"],
    "chart-pobreza-laboral-area": ["pobrezaLaboralArea"],
    "chart-pobreza-laboral-educ": ["pobrezaLaboralEduc"],
    "chart-pobreza-laboral-edad": ["pobrezaLaboralEdad"],
    "chart-gini-full": ["giniPanel"],
    "chart-gini-lac": ["giniLacComparison"],
    "chart-wid-income-ec": ["widIngresoPercentiles"],
    "chart-wid-wealth-ec": ["widRiquezaPercentiles"],
    "chart-palma-alc": ["palmaAlc"],
    "chart-sri-concentracion": ["sriConcentracion"],
    "chart-sri-capital": ["sriCapital"],
    "chart-mortalidad-jovenes": ["mortalidadJovenes"],
    "chart-mortalidad-adultos": ["mortalidadAdultos"],
    "chart-homicidios-jovenes": ["homicidiosJovenes"],
    "chart-homicidios-adultos": ["homicidiosAdultos"],
    "chart-suicidios-jovenes": ["suicidiosJovenes"],
    "chart-suicidios-adultos": ["suicidiosAdultos"],
    "chart-homicidios-nna": ["homicidiosNna"],
    # Dynamic (source depends on a UI selector) -> handled by resolvers in app.js:
    #   chart-gic (year range), chart-crec-empleo (period), chart-latam (income/wealth)
}


def safe_name(path):
    """Sanitize a basename for use in a URL (no spaces / accents issues)."""
    base = os.path.basename(path)
    stem, ext = os.path.splitext(base)
    stem = re.sub(r"\s+", "_", stem.strip())
    stem = re.sub(r"[^A-Za-z0-9_.\-]", "", stem)
    return stem + ext.lower()


def resolve_src(rel):
    if rel.startswith("@"):
        return os.path.join(REPO_ROOT, rel[1:])
    return os.path.join(DATA_DIR, rel)


def copy_one(rel, subdir=""):
    src = resolve_src(rel)
    if not os.path.exists(src):
        print(f"  WARNING: missing source {rel}")
        return None
    dest_dir = os.path.join(OUT_DIR, subdir) if subdir else OUT_DIR
    os.makedirs(dest_dir, exist_ok=True)
    fname = safe_name(rel)
    shutil.copy2(src, os.path.join(dest_dir, fname))
    rel_out = f"downloads/{subdir}/{fname}" if subdir else f"downloads/{fname}"
    return rel_out


def main():
    # Fresh downloads dir
    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR, exist_ok=True)

    # Copy each unique source file once, remember key -> web path
    key_to_web = {}
    for key, rel in KEY_TO_SRC.items():
        web = copy_one(rel)
        if web:
            key_to_web[key] = web

    # Build static chart -> web path map
    chart_sources = {}
    for chart_id, keys in CHART_KEYS.items():
        primary = keys[0]
        web = key_to_web.get(primary)
        if web:
            chart_sources[chart_id] = web
        else:
            print(f"  WARNING: no source file for {chart_id} ({primary})")

    # Copy dynamic folders (GIC curves + employment-by-sector periods)
    gic_src = os.path.join(DATA_DIR, "distribucion_crecimiento", "xlsx")
    n_gic = 0
    if os.path.isdir(gic_src):
        os.makedirs(os.path.join(OUT_DIR, "gic"), exist_ok=True)
        for f in os.listdir(gic_src):
            if f.startswith("gic_") and f.endswith(".xlsx"):
                shutil.copy2(os.path.join(gic_src, f), os.path.join(OUT_DIR, "gic", f))
                n_gic += 1

    crec_src = os.path.join(DATA_DIR, "crecimiento_empleo")
    n_crec = 0
    if os.path.isdir(crec_src):
        os.makedirs(os.path.join(OUT_DIR, "crec_empleo"), exist_ok=True)
        for f in os.listdir(crec_src):
            if f.startswith("datos_graficos_") and f.endswith(".xlsx"):
                shutil.copy2(os.path.join(crec_src, f), os.path.join(OUT_DIR, "crec_empleo", f))
                n_crec += 1

    # Emit chart-sources.js
    with open(OUT_JS, "w", encoding="utf-8") as f:
        f.write("// Auto-generated by build_downloads.py — do not edit.\n")
        f.write("// Maps each chart canvas id to the source file it plots.\n")
        f.write("window.CHART_SOURCES = ")
        json.dump(chart_sources, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write(";\n")

    print(f"\n✓ Copied {len(key_to_web)} static source files")
    print(f"✓ Copied {n_gic} GIC files + {n_crec} employment-period files")
    print(f"✓ Wrote {OUT_JS} with {len(chart_sources)} chart mappings")


if __name__ == "__main__":
    main()

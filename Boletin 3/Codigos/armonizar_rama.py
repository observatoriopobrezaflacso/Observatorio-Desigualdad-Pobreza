import pandas as pd
import pyreadstat
import os

# ============================================================
# RUTAS
# ============================================================
path_base   = "H:/Mi unidad/Bases/ENEMDU/Originales/Diciembres"
path_cw2_31 = "H:/Mi unidad/Bases/ENEMDU/Procesadas/ramas homogeneizadas/ISIC2_ISIC31.txt"
path_cw31_4 = "H:/Mi unidad/Bases/ENEMDU/Procesadas/ramas homogeneizadas/ISIC31_ISIC4.txt"
path_out    = "H:/Mi unidad/Bases/ENEMDU/Procesadas/ramas homogeneizadas"

carpetas = {
    range(1990, 2000): "1990-1999",
    range(2000, 2007): "2000-2006",
    range(2007, 2018): "2007-2017",
    range(2018, 2026): os.path.join("2018-presente", "Mensuales"),
}

# ============================================================
# DIAGNOSTICO INICIAL
# ============================================================
print("Iniciando script...")
print(f"path_base existe: {os.path.exists(path_base)}")
print(f"crosswalk ISIC2->31 existe: {os.path.exists(path_cw2_31)}")
print(f"crosswalk ISIC31->4 existe: {os.path.exists(path_cw31_4)}")
print(f"path_out existe: {os.path.exists(path_out)}")

primer_archivo = os.path.join(path_base, "1990-1999", "empleo1990.dta")
print(f"Primer archivo: {primer_archivo}")
print(f"Existe: {os.path.exists(primer_archivo)}")

# ============================================================
# MAPEO ISIC4 SECCIONES A-U
# ============================================================
ISIC4_SECTIONS = {
    "A": ("01", "03"), "B": ("05", "09"), "C": ("10", "33"),
    "D": ("35", "35"), "E": ("36", "39"), "F": ("41", "43"),
    "G": ("45", "47"), "H": ("49", "53"), "I": ("55", "56"),
    "J": ("58", "63"), "K": ("64", "66"), "L": ("68", "68"),
    "M": ("69", "75"), "N": ("77", "82"), "O": ("84", "84"),
    "P": ("85", "85"), "Q": ("86", "88"), "R": ("90", "93"),
    "S": ("94", "96"), "T": ("97", "98"), "U": ("99", "99"),
}

ISIC4_LABELS = {
    "A": "Agricultura, silvicultura y pesca",
    "B": "Explotacion de minas y canteras",
    "C": "Industria manufacturera",
    "D": "Suministro de electricidad, gas y aire acondicionado",
    "E": "Suministro de agua; alcantarillado y gestion de desechos",
    "F": "Construccion",
    "G": "Comercio; reparacion de vehiculos automotores",
    "H": "Transporte y almacenamiento",
    "I": "Actividades de alojamiento y servicio de comidas",
    "J": "Informacion y comunicaciones",
    "K": "Actividades financieras y de seguros",
    "L": "Actividades inmobiliarias",
    "M": "Actividades profesionales, cientificas y tecnicas",
    "N": "Actividades de servicios administrativos y de apoyo",
    "O": "Administracion publica y defensa; seguridad social",
    "P": "Educacion",
    "Q": "Actividades de atencion de la salud humana y asistencia social",
    "R": "Actividades artisticas, de entretenimiento y recreativas",
    "S": "Otras actividades de servicios",
    "T": "Actividades de los hogares como empleadores",
    "U": "Actividades de organizaciones extraterritoriales",
}

SECTION_TO_NUM = {s: i+1 for i, s in enumerate(sorted(ISIC4_SECTIONS.keys()))}

def code_to_section_isic4(code_str):
    if pd.isna(code_str) or code_str == "" or str(code_str) == "9999":
        return None
    div = str(code_str).zfill(4)[:2]
    for sec, (lo, hi) in ISIC4_SECTIONS.items():
        if lo <= div <= hi:
            return sec
    return None

# ============================================================
# PREPARAR CROSSWALKS
# ============================================================
print("\nCargando crosswalks...")

cw2_31 = pd.read_csv(path_cw2_31)
cw2_31 = cw2_31.dropna(subset=["Rev2"])
cw2_31["Rev2"]  = cw2_31["Rev2"].astype(float).astype(int).astype(str).str.zfill(4)
cw2_31["Rev31"] = cw2_31["Rev31"].astype(str).str.zfill(4)
cw2_31 = cw2_31.drop_duplicates(subset="Rev2", keep="first")[["Rev2", "Rev31"]]
cw2_31.columns = ["isic2_code", "isic31_code"]

cw31_4 = pd.read_csv(path_cw31_4)
cw31_4["ISIC31code"] = cw31_4["ISIC31code"].astype(str).str.zfill(4)
cw31_4["ISIC4code"]  = cw31_4["ISIC4code"].astype(str).str.zfill(4)
cw31_4 = cw31_4.drop_duplicates(subset="ISIC31code", keep="first")[["ISIC31code", "ISIC4code"]]
cw31_4.columns = ["isic31_code", "isic4_code"]

cw2_4 = cw2_31.merge(cw31_4, on="isic31_code", how="left")

print(f"  ISIC2->ISIC31: {len(cw2_31)} mapeos unicos")
print(f"  ISIC31->ISIC4: {len(cw31_4)} mapeos unicos")
print(f"  ISIC2->ISIC4 encadenado: {len(cw2_4)} mapeos unicos")

# ============================================================
# FUNCION AUXILIAR
# ============================================================
def get_carpeta(anio):
    for rango, carpeta in carpetas.items():
        if anio in rango:
            return carpeta
    return None

# ============================================================
# LOOP PRINCIPAL
# ============================================================
resultados = []
anios = list(range(1990, 2026))

print(f"\nProcesando {len(anios)} anos...\n")

for anio in anios:
    sub_c = get_carpeta(anio)
    ruta  = os.path.join(path_base, sub_c, f"empleo{anio}.dta")

    print(f"{'='*60}")
    print(f"ANO: {anio} | Buscando: {ruta}")

    if not os.path.exists(ruta):
        print(f"  NO ENCONTRADO - omitiendo")
        continue

    try:
        df, meta = pyreadstat.read_dta(ruta)
        vars_base = [v.lower() for v in df.columns]
        print(f"  OK: {len(df):,} obs, {len(df.columns)} vars")

        rama_orig = None
        periodo   = None

        if anio <= 1999:
            if "rama" in vars_base:
                rama_orig = df["rama"].copy()
                periodo   = "ISIC2"
        elif anio <= 2006:
            if "rama" in vars_base:
                rama_orig = df["rama"].copy()
                periodo   = "ISIC31"
        elif anio <= 2017:
            if "p40" in vars_base:
                rama_orig = df["p40"].copy()
                periodo   = "ISIC31"
        else:
            if "rama1" in vars_base:
                rama_orig = df["rama1"].copy()
                periodo   = "ISIC4_num"

        if rama_orig is None:
            print(f"  ADVERTENCIA: no se encontro variable de rama")
            continue

        print(f"  Periodo: {periodo} | Valores unicos: {rama_orig.nunique()}")

        if periodo == "ISIC2":
            rama_str = rama_orig.apply(
                lambda x: str(int(x)).zfill(4) if pd.notna(x) and x != 999 else None
            )
            merged = rama_str.to_frame("isic2_code").merge(
                cw2_4[["isic2_code", "isic4_code"]], on="isic2_code", how="left"
            )
            seccion = merged["isic4_code"].apply(code_to_section_isic4)

        elif periodo == "ISIC31":
            rama_str = rama_orig.apply(
                lambda x: str(int(x)).zfill(4) if pd.notna(x) and x not in [9999, 999] else None
            )
            merged = rama_str.to_frame("isic31_code").merge(
                cw31_4, on="isic31_code", how="left"
            )
            seccion = merged["isic4_code"].apply(code_to_section_isic4)

        elif periodo == "ISIC4_num":
            num_to_sec = {i+1: s for i, s in enumerate(sorted(ISIC4_SECTIONS.keys()))}
            seccion = rama_orig.apply(
                lambda x: num_to_sec.get(int(x)) if pd.notna(x) and x not in [22, 99] else None
            )

        df["rama_arm_letra"] = seccion.values
        df["rama_arm"]       = df["rama_arm_letra"].map(SECTION_TO_NUM)

        n_validos = df["rama_arm"].notna().sum()
        n_missing = df["rama_arm"].isna().sum()
        dist      = df["rama_arm_letra"].value_counts().sort_index()

        print(f"  rama_arm: {n_validos:,} validos | {n_missing:,} missing")
        print(f"  Distribucion:")
        for sec, cnt in dist.items():
            pct = cnt / len(df) * 100
            print(f"    {sec} - {ISIC4_LABELS[sec][:35]}: {cnt:,} ({pct:.1f}%)")

        out_path = os.path.join(path_out, f"empleo{anio}_rama_arm.dta")
        pyreadstat.write_dta(df, out_path)
        print(f"  GUARDADO: {out_path}")

        for sec, cnt in dist.items():
            resultados.append({
                "anio":    anio,
                "seccion": sec,
                "label":   ISIC4_LABELS[sec],
                "n":       cnt,
                "pct":     round(cnt / len(df) * 100, 2),
                "periodo": periodo,
            })

    except Exception as e:
        print(f"  ERROR: {e}")

# ============================================================
# EXPORTAR RESUMEN A EXCEL
# ============================================================
print("\n" + "="*60)
if resultados:
    df_res    = pd.DataFrame(resultados)
    out_excel = os.path.join(path_out, "resumen_rama_armonizada.xlsx")

    with pd.ExcelWriter(out_excel, engine="openpyxl") as writer:
        df_res.to_excel(writer, sheet_name="Largo", index=False)
        pivot = df_res.pivot_table(
            index=["seccion", "label"], columns="anio",
            values="pct", aggfunc="sum"
        ).round(2)
        pivot.to_excel(writer, sheet_name="Pivot_pct")

    print(f"RESUMEN GUARDADO: {out_excel}")
    print(f"Anos procesados: {df_res['anio'].nunique()}")
else:
    print("NO SE PROCESO NINGUN ANO")

print("\nFIN DEL SCRIPT")

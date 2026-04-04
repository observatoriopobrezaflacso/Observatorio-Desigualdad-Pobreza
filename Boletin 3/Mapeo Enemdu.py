import pandas as pd
import pyreadstat
import os
import unicodedata
import re

# ============================================================
# RUTAS
# ============================================================
path_base = "H:/Mi unidad/Bases/ENEMDU/Originales/Diciembres"

carpetas = {
    range(1990, 2000): "1990-1999",
    range(2000, 2007): "2000-2006",
    range(2007, 2018): "2007-2017",
    range(2018, 2026): os.path.join("2018-presente", "Mensuales"),
}

# ============================================================
# VARIABLES - nombres exactos por período
# ============================================================
var_buscadas = {
    "1_Ciudades_autorrepresentadas": [
        "ciudad", "dominio"
    ],
    "2_Tamano_establecimiento": [
        # 1990-2006
        "pertrabn", "nuptrab", "npertra",
        # 2007-2025
        "p47a", "p56a",
    ],
    "3_Horas_trabajadas": [
        # 1990-2006
        "hortrasa", "hortrahp", "hortrahs", "hortraho",
        # 2007-2025
        "p24", "p51a", "p51b", "p51c",
    ],
    "4_Sitio_trabajo": [
        # 1990-2006
        "sitios", "pe46",
        # 2007-2025
        "p46", "p55",
    ],
    "5_Sector_empleados": [
        # 1990-2006
        "secins", "peamsiu",
        # 2007-2025
        "secemp",
    ],
    "6_Grupo_ocupacion": [
        # 1990-2006
        "grupo", "grupos",
        # 2007-2025
        "p41", "grupo1", "p53",
    ],
    "7_Categoria_ocupacion": [
        # 1990-2006
        "catetrab", "cates",
        # 2007-2025
        "p42", "p54",
    ],
    "8_Rama_actividad": [
        # 1990-2006
        "rama", "ramas",
        # 2007-2025
        "rama1", "p40", "p52",
    ],
}
# ============================================================
# FUNCIONES
# ============================================================
def limpiar(t):
    if not t:
        return ""
    return ''.join(
        c for c in unicodedata.normalize('NFD', str(t))
        if unicodedata.category(c) != 'Mn'
    ).lower().strip()

def get_carpeta(anio):
    for rango, carpeta in carpetas.items():
        if anio in rango:
            return carpeta
    return None

def extraer_codigos(texto):
    return sorted(set(re.findall(r'\b(\d+)=', texto)))

# ============================================================
# LOOP PRINCIPAL
# ============================================================
anios = list(range(1990, 2026))
matriz = pd.DataFrame(index=var_buscadas.keys(), columns=anios)

for anio in anios:
    sub_c = get_carpeta(anio)
    if sub_c is None:
        print(f"❌ {anio}: sin carpeta definida")
        continue

    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    print(f"🔎 {anio} ({sub_c})...", end=" ")

    if not os.path.exists(ruta):
        print(f"❌ No encontrado")
        for concepto in var_buscadas:
            matriz.at[concepto, anio] = "NO EXISTE"
        continue

    try:
        _, meta = pyreadstat.read_dta(ruta, metadataonly=True)

        nombres_a_labels = meta.column_names_to_labels
        value_labels     = meta.variable_value_labels
        vars_base        = {v.lower(): v for v in meta.column_names}

        for concepto, terminos in var_buscadas.items():
            encontradas = []
            vars_ya_agregadas = set()

            for termino in terminos:
                if termino.lower() in vars_base:
                    var_real = vars_base[termino.lower()]

                    # Evitar duplicados
                    if var_real in vars_ya_agregadas:
                        continue
                    vars_ya_agregadas.add(var_real)

                    label   = nombres_a_labels.get(var_real, "")
                    dic_val = value_labels.get(var_real, {})

                    if dic_val:
                        cats = " / ".join(
                            [f"{int(k)}={v}" for k, v in sorted(dic_val.items())]
                        )
                        res = f"{var_real} — {cats}"
                    else:
                        res = f"{var_real} — continua"

                    encontradas.append(res)

            matriz.at[concepto, anio] = (
                " | ".join(encontradas) if encontradas else "NO ENCONTRADA"
            )

        print("✅")

    except Exception as e:
        print(f"⚠️ Error: {e}")
        for concepto in var_buscadas:
            matriz.at[concepto, anio] = f"ERROR: {e}"

# ============================================================
# COMPARABILIDAD AUTOMÁTICA
# ============================================================
print("\n📊 Calculando comparabilidad...")

filas_comp = []
for concepto in var_buscadas.keys():
    for anio in anios:
        val_actual = str(matriz.at[concepto, anio])
        anio_sig   = anio + 1

        if anio_sig not in anios:
            comp = "ULTIMO ANIO"
        elif val_actual in ["NO EXISTE", "NO ENCONTRADA"] or val_actual.startswith("ERROR"):
            comp = "NO EXISTE"
        else:
            val_sig = str(matriz.at[concepto, anio_sig])
            if val_sig in ["NO EXISTE", "NO ENCONTRADA"] or val_sig.startswith("ERROR"):
                comp = "NO EXISTE SIG"
            else:
                cod_act = extraer_codigos(val_actual)
                cod_sig = extraer_codigos(val_sig)

                if cod_act == cod_sig:
                    comp = "SI"
                elif set(cod_act) & set(cod_sig):
                    comp = "PARCIAL"
                else:
                    comp = "NO"

        filas_comp.append({
            "concepto":       concepto,
            "anio":           anio,
            "contenido":      val_actual,
            "comparabilidad": comp
        })

df_largo = pd.DataFrame(filas_comp)

# ============================================================
# EXPORTAR
# ============================================================
output = os.path.normpath(
    os.path.join(path_base, "..", "..", "matriz_variables_enemdu_FINAL.xlsx")
)

with pd.ExcelWriter(output, engine="openpyxl") as writer:
    matriz.to_excel(writer, sheet_name="Matriz_ancha")
    df_largo.to_excel(writer, sheet_name="Detalle_comparabilidad", index=False)

print(f"\n✅ LISTO: {output}")
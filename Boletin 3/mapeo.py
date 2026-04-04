import pandas as pd
import pyreadstat
import os
import unicodedata

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
# VARIABLES A BUSCAR
# Formato: "Concepto": [lista de nombres posibles de variable]
# ============================================================
var_buscadas = {
    "1_Ciudades_autorrepresentadas": [
        "ciudad", "dominio", "ciud"
    ],
    "2_Tamano_establecimiento": [
        "pertrabn", "tamano", "establecimiento", "trabajadores",
        "personal", "nuptrab", "npertra", "p36", "p37", "p38"
    ],
    "3_Horas_trabajadas": [
        "hortrasa", "hortrahp", "hortrahs", "hortraho",
        "horas", "hrstrab", "jornada", "p27", "p28", "p29", "p30"
    ],
    "4_Sitio_trabajo": [
        "pe46", "p46", "sitio", "domicilio",
        "ambulante", "mercado", "p33", "p34", "p35"
    ],
    "5_Sector_empleados": [
        "secins", "secemp", "peamsiu",
        "privado", "gobierno", "p39", "p40", "p41"
    ],
    "6_Grupo_ocupacion": [
        "grupo", "grupos", "ocupac", "oficio",
        "isco", "ciuo", "cno", "p20", "p21"
    ],
    "7_Categoria_ocupacion": [
        "catetrab", "cates", "categoria", "categ",
        "patron", "cuenta", "asalariado", "remunerado",
        "p18", "p42", "p43"
    ],
    "8_Rama_actividad": [
        "rama", "ramas", "ciiu", "actividad",
        "industria", "p17", "p19", "p23"
    ],
}

# ============================================================
# FUNCIÓN: limpiar texto para comparar sin tildes
# ============================================================
def limpiar(t):
    if not t:
        return ""
    return ''.join(
        c for c in unicodedata.normalize('NFD', str(t))
        if unicodedata.category(c) != 'Mn'
    ).lower().strip()

# ============================================================
# FUNCIÓN: obtener carpeta según año
# ============================================================
def get_carpeta(anio):
    for rango, carpeta in carpetas.items():
        if anio in rango:
            return carpeta
    return None

# ============================================================
# LOOP PRINCIPAL
# ============================================================
anios = range(1990, 2026)
matriz = pd.DataFrame(index=var_buscadas.keys(), columns=anios)

for anio in anios:
    sub_c = get_carpeta(anio)
    if sub_c is None:
        print(f"❌ {anio}: sin carpeta definida")
        continue

    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    print(f"🔎 {anio} ({sub_c})...", end=" ")

    if not os.path.exists(ruta):
        print(f"❌ No encontrado: {ruta}")
        for concepto in var_buscadas:
            matriz.at[concepto, anio] = "NO EXISTE"
        continue

    try:
        _, meta = pyreadstat.read_dta(ruta, metadataonly=True)

        # Mapeo nombre_var -> label
        nombres_a_labels = meta.column_names_to_labels
        # Value labels
        value_labels = meta.variable_value_labels
        # Lista de variables en la base en minúsculas
        vars_base = {v.lower(): v for v in meta.column_names}

        for concepto, terminos in var_buscadas.items():
            encontradas = []

            for termino in terminos:
                # Buscar por nombre exacto (case insensitive)
                if termino.lower() in vars_base:
                    var_real = vars_base[termino.lower()]
                    label = nombres_a_labels.get(var_real, "sin etiqueta")
                    dic_val = value_labels.get(var_real, {})

                    if dic_val:
                        cats = " / ".join(
                            [f"{int(k)}={v}" for k, v in sorted(dic_val.items())]
                        )
                        res = f"{var_real} ({limpiar(label)}): {cats}"
                    else:
                        res = f"{var_real} ({limpiar(label)}): continua"

                    if res not in encontradas:
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
# Compara códigos entre año t y año t+1 para cada concepto
# ============================================================
print("\n📊 Calculando comparabilidad...")

filas_comp = []
for concepto in var_buscadas.keys():
    for anio in anios:
        val_actual = str(matriz.at[concepto, anio])
        anio_sig   = anio + 1

        if anio_sig not in anios:
            comp = "ULTIMO AÑO"
        elif val_actual in ["NO EXISTE", "NO ENCONTRADA"] or val_actual.startswith("ERROR"):
            comp = "NO EXISTE"
        else:
            val_sig = str(matriz.at[concepto, anio_sig])
            if val_sig in ["NO EXISTE", "NO ENCONTRADA"] or val_sig.startswith("ERROR"):
                comp = "NO EXISTE SIG"
            else:
                # Extraer solo los códigos numéricos para comparar
                import re
                def extraer_codigos(texto):
                    return sorted(set(re.findall(r'\b\d+(?==)', texto)))

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
output = os.path.join(path_base, "..", "..", "matriz_variables_enemdu_FINAL.xlsx")
output = os.path.normpath(output)

with pd.ExcelWriter(output, engine="openpyxl") as writer:
    # Hoja 1: Matriz ancha (concepto x año)
    matriz.to_excel(writer, sheet_name="Matriz_ancha")

    # Hoja 2: Formato largo con comparabilidad
    df_largo.to_excel(writer, sheet_name="Detalle_comparabilidad", index=False)

print(f"\n✅ LISTO: {output}")
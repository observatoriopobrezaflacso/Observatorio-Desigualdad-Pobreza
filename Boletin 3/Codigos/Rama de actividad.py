import os
import pandas as pd
import numpy as np

# ============================================================
# 1. CONFIGURACIÓN DE RUTAS LOCALES
# ============================================================
drive_root = "H:/Mi unidad"
path_base = os.path.join(drive_root, "Bases", "ENEMDU", "Originales", "Diciembres")
path_out = os.path.join(drive_root, "Bases", "ENEMDU", "Procesadas", "Modulos_Emilio")
path_cw = os.path.join(drive_root, "Bases", "ENEMDU", "Procesadas", "ramas homogeneizadas")

if not os.path.exists(path_out):
    os.makedirs(path_out)

# ============================================================
# 2. DEFINICIÓN DE MACRO-SECTORES 
# ============================================================
ISIC4_SECTIONS = {
    "A": range(1, 4), "B": range(5, 10), "C": range(10, 34),
    "D": [35], "E": range(36, 40), "F": range(41, 44),
    "G": range(45, 48), "H": range(49, 54), "I": range(55, 57),
    "J": range(58, 64), "K": range(64, 67), "L": [68],
    "M": range(69, 76), "N": range(77, 83), "O": [84],
    "P": [85], "Q": range(86, 89), "R": range(90, 94),
    "S": range(94, 97), "T": range(97, 99), "U": [99]
}

MACRO_SECTORES = {
    "A": "1. Primario/Extractivo", "B": "1. Primario/Extractivo",
    "C": "2. Manufactura", "F": "3. Construccion",
    "D": "4. Servicios Basicos", "E": "4. Servicios Basicos", 
    "G": "5. Comercio y Servicios", "H": "5. Comercio y Servicios", "I": "5. Comercio y Servicios", 
    "J": "5. Comercio y Servicios", "K": "5. Comercio y Servicios", "L": "5. Comercio y Servicios", 
    "M": "5. Comercio y Servicios", "N": "5. Comercio y Servicios", 
}

MAPEO_RAMA1_NUM = {
    1: "1. Primario/Extractivo", 2: "1. Primario/Extractivo", 
    3: "2. Manufactura", 
    4: "4. Servicios Basicos", 5: "4. Servicios Basicos", 
    6: "3. Construccion", 
    7: "5. Comercio y Servicios", 8: "5. Comercio y Servicios", 9: "5. Comercio y Servicios", 
    10: "5. Comercio y Servicios", 11: "5. Comercio y Servicios", 12: "5. Comercio y Servicios", 
    13: "5. Comercio y Servicios", 14: "5. Comercio y Servicios"
}

def obtener_macro_sector_4d(codigo_isic4):
    try:
        if pd.isna(codigo_isic4) or str(codigo_isic4).strip() == "": return "7. N/D"
        div = int(str(codigo_isic4).zfill(4)[:2])
        seccion = next((sec for sec, rango in ISIC4_SECTIONS.items() if div in rango), None)
        return MACRO_SECTORES.get(seccion, "6. Sociales/Públicos/Otros") if seccion else "7. N/D"
    except:
        return "7. N/D"

# ============================================================
# 3. CARGA DE CROSSWALKS
# ============================================================
print("📖 Cargando diccionarios de Rama de Actividad...")
cw2_31 = pd.read_csv(os.path.join(path_cw, "ISIC2_ISIC31.txt"), dtype=str).dropna(subset=["Rev2"])
dict_2_to_31 = dict(zip(cw2_31["Rev2"].str.replace('.0','', regex=False).str.zfill(4), 
                        cw2_31["Rev31"].str.replace('.0','', regex=False).str.zfill(4)))

cw31_4 = pd.read_csv(os.path.join(path_cw, "ISIC31_ISIC4.txt"), dtype=str).dropna(subset=["ISIC31code"])
dict_31_to_4 = dict(zip(cw31_4["ISIC31code"].str.replace('.0','', regex=False).str.zfill(4), 
                        cw31_4["ISIC4code"].str.replace('.0','', regex=False).str.zfill(4)))

# ============================================================
# 4. MOTOR DE EXTRACCIÓN (1990 - 2024)
# ============================================================
datos_modulo3 = []
print("🚀 Iniciando Módulo 3 (Motor Pandas Nativo): Ramas de Actividad...")

for anio in range(1990, 2025):
    sub_c = "1990-1999" if anio < 2000 else "2000-2006" if anio <= 2006 else "2007-2017" if anio <= 2017 else os.path.join("2018-presente", "Trimestrales")
    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    
    if not os.path.exists(ruta): continue
        
    try:
        # LECTURA BLINDADA (Ignora los errores del diccionario de Stata)
        try:
            df = pd.read_stata(ruta, convert_categoricals=False)
        except Exception:
            df = pd.read_stata(ruta, convert_categoricals=False, encoding="latin1")
            
        df.columns = [c.lower() for c in df.columns]
        
        tipo_var = "codigo_4d"
        if anio <= 2006:
            var_rama = "rama" if "rama" in df.columns else "p40"
        elif anio <= 2017:
            var_rama = "p41" if "p41" in df.columns else "p40" if "p40" in df.columns else "rama"
        else:
            var_rama = "rama1" if "rama1" in df.columns else "p40"
            if var_rama == "rama1": tipo_var = "seccion_1_21"
            
        if var_rama not in df.columns:
            continue

        if tipo_var == "seccion_1_21":
            df['macro_sector_actividad'] = pd.to_numeric(df[var_rama], errors='coerce').map(
                lambda x: MAPEO_RAMA1_NUM.get(x, "6. Sociales/Públicos/Otros") if pd.notna(x) and x > 0 else "7. N/D"
            )
        else:
            df['codigo_original'] = pd.to_numeric(df[var_rama], errors='coerce').fillna(-1).astype(int).astype(str).str.zfill(4)
            df.loc[df['codigo_original'].isin(['00-1', '-001']), 'codigo_original'] = "ND"
            
            codigos_isic4 = []
            for cod in df['codigo_original']:
                if cod == "00-1" or cod == "ND":
                    codigos_isic4.append("ND")
                else:
                    if anio <= 1999:
                        codigos_isic4.append(dict_31_to_4.get(dict_2_to_31.get(cod, cod), dict_2_to_31.get(cod, cod)))
                    elif 2000 <= anio <= 2013:
                        codigos_isic4.append(dict_31_to_4.get(cod, cod))
                    else:
                        codigos_isic4.append(cod)
                        
            df['macro_sector_actividad'] = [obtener_macro_sector_4d(c) for c in codigos_isic4]

        df['anio'] = anio
        df_export = df[['anio', 'macro_sector_actividad']].copy()
        df_export['id_persona'] = df.index
        datos_modulo3.append(df_export)
        print(f"✅ {anio} procesado por [{tipo_var}].")
        
    except Exception as e:
        print(f"❌ Error en {anio}: {e}")

# ============================================================
# 5. EXPORTACIÓN
# ============================================================
if datos_modulo3:
    df_final_mod3 = pd.concat(datos_modulo3, ignore_index=True)
    ruta_salida = os.path.join(path_out, "03_Ramas_Emilio.parquet")
    df_final_mod3.to_parquet(ruta_salida)
    
    print("\n📊 Resumen CORREGIDO de Macro-Sectores Históricos:")
    print(df_final_mod3['macro_sector_actividad'].value_counts())
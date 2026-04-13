import os
import pandas as pd
import pyreadstat

# ============================================================
# 1. CONFIGURACIÓN DE RUTAS (ENTORNO LOCAL EMILIO)
# ============================================================
drive_root = "H:/Mi unidad"
path_base = os.path.join(drive_root, "Bases", "ENEMDU", "Originales", "Diciembres")

# Carpeta donde vas a guardar TUS resultados
path_out = os.path.join(drive_root, "Bases", "ENEMDU", "Procesadas", "Modulos_Emilio")
if not os.path.exists(path_out):
    os.makedirs(path_out)

# ============================================================
# 2. DICCIONARIOS DE ARMONIZACIÓN (TU LÓGICA)
# ============================================================
def armonizar_genero(val):
    try:
        v = int(float(val))
        if v == 1: return "Hombre"
        if v == 2: return "Mujer"
        return "N/D"
    except:
        return "N/D"

def armonizar_etnia(v, anio):
    try:
        v = int(float(v))
    except:
        return "6. Otro/ND"

    # Etnia no se medía en los 90s en la ENEMDU estándar
    if anio < 2001:
        return "6. Otro/ND"

    # --- 2007 a 2024 (Estructura p15) ---
    if anio >= 2007:
        if v == 1: return "1. Indígena"
        if v in [2, 3, 4]: return "2. Afroecuatoriano" # Afro + Negro + Mulato
        if v == 5: return "3. Montubio"
        if v == 6: return "4. Mestizo"
        if v == 7: return "5. Blanco"
        return "6. Otro/ND"

    # --- 2003 a 2006 (Estructura pe13) ---
    elif 2003 <= anio <= 2006:
        if v == 1: return "1. Indígena"
        if v in [4, 5]: return "2. Afroecuatoriano" 
        if v == 3: return "4. Mestizo"
        if v == 2: return "5. Blanco"
        return "6. Otro/ND"

    # --- 2002 (pe14) ---
    elif anio == 2002:
        if v == 1: return "1. Indígena"
        if v in [4, 5]: return "2. Afroecuatoriano"
        if v == 3: return "4. Mestizo"
        if v == 2: return "5. Blanco"
        return "6. Otro/ND"

    # --- 2001 (pe14: Códigos invertidos) ---
    elif anio == 2001:
        if v == 3: return "1. Indígena"
        if v in [2, 5]: return "2. Afroecuatoriano" 
        if v == 4: return "4. Mestizo"
        if v == 1: return "5. Blanco"
        return "6. Otro/ND"

# ============================================================
# 3. MOTOR DE EXTRACCIÓN (1990 - 2024)
# ============================================================
datos_modulo1 = []

print("🚀 Iniciando Módulo 1: Género y Etnia...")

for anio in range(1990, 2025):
    # Lógica de carpetas original del INEC
    if anio < 2000:
        sub_c = "1990-1999"
    elif anio <= 2006:
        sub_c = "2000-2006"
    elif anio <= 2017:
        sub_c = "2007-2017"
    else:
        sub_c = os.path.join("2018-presente", "Trimestrales")
        
    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    
    if os.path.exists(ruta):
        try:
            # Lectura a prueba de fallos (para los años 2012-2014)
            try:
                df, _ = pyreadstat.read_dta(ruta)
            except:
                df, _ = pyreadstat.read_dta(ruta, encoding="latin1")
                
            # Estandarizar nombres de columnas de origen a minúsculas
            df.columns = [c.lower() for c in df.columns]
            
            # --- Buscar Género ---
            var_gen = "sexo" if "sexo" in df.columns else "p02" if "p02" in df.columns else None
            if var_gen:
                genero_limpio = df[var_gen].apply(armonizar_genero)
            else:
                genero_limpio = "N/D"
                
            # --- Buscar Etnia ---
            if anio <= 2002: var_et = 'pe14'
            elif 2003 <= anio <= 2006: var_et = 'pe13'
            else: var_et = 'p15'
            
            if var_et in df.columns:
                etnia_limpia = df[var_et].apply(lambda x: armonizar_etnia(x, anio))
            else:
                etnia_limpia = "6. Otro/ND" # Para los años 90s donde no hay dato
                
            # --- Empaquetar datos del año ---
            df_temp = pd.DataFrame({
                'anio': anio,
                'id_persona': df.index, # Clave para luego unir con los demás módulos
                'genero_armonizado': genero_limpio,
                'etnia_armonizada': etnia_limpia
            })
            
            datos_modulo1.append(df_temp)
            print(f"✅ {anio} procesado.")
            
        except Exception as e:
            print(f"❌ Error leyendo {anio}: {e}")
    else:
        print(f"⚠️ {anio} no encontrado en la ruta.")

# ============================================================
# 4. EXPORTACIÓN DEL MÓDULO
# ============================================================
if datos_modulo1:
    df_final_mod1 = pd.concat(datos_modulo1, ignore_index=True)
    ruta_salida = os.path.join(path_out, "01_Demografia_Emilio.parquet")
    df_final_mod1.to_parquet(ruta_salida)
    print(f"\n🎉 ¡Módulo 1 terminado! Base guardada en: {ruta_salida}")
    
    # Un pequeño reporte para tu revisión
    print("\n📊 Resumen de Género:")
    print(df_final_mod1['genero_armonizado'].value_counts())
    print("\n📊 Resumen de Etnia (Recuerda que en los 90s será todo ND):")
    print(df_final_mod1['etnia_armonizada'].value_counts())
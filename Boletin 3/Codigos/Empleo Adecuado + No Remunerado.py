import os
import pandas as pd
import numpy as np
import pyreadstat

# ============================================================
# 1. CONFIGURACIÓN DE RUTAS LOCALES
# ============================================================
drive_root = "H:/Mi unidad"
path_base = os.path.join(drive_root, "Bases", "ENEMDU", "Originales", "Diciembres")
path_out = os.path.join(drive_root, "Bases", "ENEMDU", "Procesadas", "Modulos_Emilio")

if not os.path.exists(path_out):
    os.makedirs(path_out)

SBU_HISTORICO = {
    1990: 40000, 1991: 40000, 1992: 60000, 1993: 66000, 1994: 85000, 
    1995: 100000, 1996: 100000, 1997: 100000, 1998: 100000, 1999: 100000,
    2000: 49.33, 2001: 117.60, 2002: 136.80, 2003: 142.92, 2004: 143.63, 
    2005: 150.00, 2006: 160.00, 2007: 170.00, 2008: 200.00, 2009: 218.00, 
    2010: 240.00, 2011: 264.00, 2012: 292.00, 2013: 318.00, 2014: 340.00, 
    2015: 354.00, 2016: 366.00, 2017: 375.00, 2018: 386.00, 2019: 394.00, 
    2020: 400.00, 2021: 400.00, 2022: 425.00, 2023: 450.00, 2024: 460.00
}

# ============================================================
# 2. FUNCIÓN PARA EMPLEO NO REMUNERADO
# ============================================================
def es_no_remunerado(v, anio):
    try:
        v = int(float(v))
    except:
        return 0 
        
    if anio >= 2007:
        if v in [7, 8, 9]: return 1
    elif 2003 <= anio <= 2006:
        if v == 8: return 1
    else:
        if v in [6, 11]: return 1
    return 0

# ============================================================
# 3. MOTOR LABORAL (Empleo Adecuado + No Remunerado)
# ============================================================
datos_modulo2 = []
edadmin = 15

print("🚀 Iniciando Módulo 2: Empleo Adecuado y No Remunerado...")

for anio in range(1990, 2025):
    if anio < 2000: sub_c = "1990-1999"
    elif anio <= 2006: sub_c = "2000-2006"
    elif anio <= 2017: sub_c = "2007-2017"
    else: sub_c = os.path.join("2018-presente", "Trimestrales")
        
    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    
    if not os.path.exists(ruta): continue
        
    try:
        try: df, _ = pyreadstat.read_dta(ruta)
        except: df, _ = pyreadstat.read_dta(ruta, encoding="latin1")
            
        df.columns = [c.lower() for c in df.columns]
        
        # --- A. CÁLCULO DEL EMPLEO NO REMUNERADO ---
        var_oc = 'p42' if anio >= 2007 else 'catetrab'
        if var_oc in df.columns:
            df['empleo_no_remunerado'] = df[var_oc].apply(lambda x: es_no_remunerado(x, anio))
        else:
            df['empleo_no_remunerado'] = 0
            
        # --- B. CÁLCULO DEL EMPLEO ADECUADO ---
        mapa_vars = {
            "p03": ["edad", "p03"], "p20": ["trabajo", "p20"], "p21": ["actayuda", "p21"],
            "p22": ["aunotra", "p22"], "p24": ["hortrasa", "p24"], "p25": ["ratmeh", "p25"],
            "p27": ["hormas", "p27"], "p28": ["p28"], "p32": ["bustrama", "p32"],
            "p34": ["motnobus", "p34"], "p35": ["deseatra", "p35"], 
            "p51a": ["hortrahp", "p51a"], "p51b": ["hortrahs", "p51b"], 
            "p51c": ["hortraho", "p51c"], "ingrl": ["ing_lab", "ingrl"]
        }
        for var_std, opciones in mapa_vars.items():
            col_encontrada = next((c for c in opciones if c in df.columns), None)
            if col_encontrada and col_encontrada != var_std: df = df.rename(columns={col_encontrada: var_std})
            if var_std not in df.columns: df[var_std] = np.nan

        cols_numericas = ["p03", "p20", "p21", "p22", "p24", "p25", "p27", "p28", "p32", "p34", "p35", "p51a", "p51b", "p51c", "ingrl"]
        for c in cols_numericas:
            df[c] = pd.to_numeric(df[c], errors='coerce')

        if anio < 2000:
            df['p27'] = 2.0  
            if 'ratmeh1' in df.columns: 
                df.loc[df['ratmeh1'].notna(), 'p27'] = 1.0

        df['petn'] = np.where(df['p03'] >= edadmin, 1, 0)
        
        cond_pea = (df['petn'] == 1) & (df['p20'] == 1)
        if anio >= 2007:
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] <= 11))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 1))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 2) & (df['p32'] <= 10))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 2) & (df['p32'] == 11) & (df['p34'] <= 7) & (df['p35'] == 1))
        elif 2000 <= anio <= 2006:
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] <= 10))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 11) & (df['p22'] == 1))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 11) & (df['p22'] == 2) & (df['p32'] == 1))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 11) & (df['p22'] == 2) & (df['p32'] == 2) & (df['p34'] <= 7) & (df['p34'] != 4) & (df['p35'] == 1))
        else:
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] <= 11))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 1))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 2) & (df['p32'] == 1))
            cond_pea = cond_pea | ((df['petn'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 2) & (df['p32'] == 2) & (df['p34'] >= 7) & (df['p35'] == 1))
        df['pean'] = np.where(cond_pea, 1, 0)

        cond_emp = (df['pean'] == 1) & (df['p20'] == 1)
        if 2000 <= anio <= 2006:
            cond_emp = cond_emp | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] <= 10))
            cond_emp = cond_emp | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] == 11) & (df['p22'] == 1))
        else:
            cond_emp = cond_emp | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] <= 11))
            cond_emp = cond_emp | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 1))
        df['empleo'] = np.where(cond_emp, 1, 0)

        sbu_actual = SBU_HISTORICO.get(anio, 460)
        df['ila'] = df['ingrl'].replace([-1, 999999], np.nan)
        df['w'] = np.nan
        df.loc[(df['empleo'] == 1) & (df['ila'] < sbu_actual), 'w'] = 0
        df.loc[(df['empleo'] == 1) & (df['ila'] >= sbu_actual), 'w'] = 1

        df['horas'] = 0.0 
        cond_horas_1 = (df['pean'] == 1) & (df['p20'] == 1)
        if 2000 <= anio <= 2006: cond_horas_1 = cond_horas_1 | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] <= 10))
        else: cond_horas_1 = cond_horas_1 | ((df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] <= 11))
        df.loc[cond_horas_1, 'horas'] = df['p24']

        df['p51a'] = df['p51a'].replace(999, np.nan)
        df['p51b'] = df['p51b'].replace(999, np.nan)
        df['p51c'] = df['p51c'].replace(999, np.nan)
        df['hh'] = df[['p51a', 'p51b', 'p51c']].sum(axis=1, min_count=1)
        df.loc[df['hh'] < 0, 'hh'] = np.nan

        if 2000 <= anio <= 2006: cond_horas_2 = (df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] == 11) & (df['p22'] == 1)
        else: cond_horas_2 = (df['pean'] == 1) & (df['p20'] == 2) & (df['p21'] == 12) & (df['p22'] == 1)
        df.loc[cond_horas_2, 'horas'] = df['hh']

        df['t'] = np.nan
        df.loc[(df['empleo'] == 1) & (df['horas'] < 40), 't'] = 0
        df.loc[(df['empleo'] == 1) & (df['horas'] >= 40), 't'] = 1
        df.loc[(df['empleo'] == 1) & (df['horas'] < 30) & (df['p03'] >= 12) & (df['p03'] <= 17), 't'] = 0
        df.loc[(df['empleo'] == 1) & (df['horas'] >= 30) & (df['p03'] >= 12) & (df['p03'] <= 17), 't'] = 1

        df['d_d'] = np.nan
        if anio >= 2007:
            df.loc[(df['empleo'] == 1) & ((df['p25'] == 9) | (df['p27'] == 4)), 'd_d'] = 0
            df.loc[(df['empleo'] == 1) & (df['p27'] <= 3) & (df['p28'] == 1), 'd_d'] = 1
        elif 2000 <= anio <= 2006:
            df.loc[(df['empleo'] == 1) & (df['p27'] == 2), 'd_d'] = 0
            df.loc[(df['empleo'] == 1) & (df['p27'] == 1), 'd_d'] = 1
        elif 1993 <= anio <= 1999:
            df.loc[(df['empleo'] == 1) & ((df['p25'] == 3) | (df['p27'] == 2)), 'd_d'] = 0
            df.loc[(df['empleo'] == 1) & (df['p27'] == 1), 'd_d'] = 1
        else:
            df.loc[(df['empleo'] == 1) & ((df['p25'] == 2) | (df['p27'] == 2)), 'd_d'] = 0
            df.loc[(df['empleo'] == 1) & (df['p27'] == 1), 'd_d'] = 1

        df['empleo_adecuado'] = np.nan
        df.loc[(df['pean'] == 1) & (df['p03'] >= edadmin), 'empleo_adecuado'] = 0 
        
        cond_adecuado_1 = (df['pean'] == 1) & (df['p03'] >= edadmin) & (df['empleo'] == 1) & (df['w'] == 1) & (df['t'] == 1)
        cond_adecuado_2 = (df['pean'] == 1) & (df['p03'] >= edadmin) & (df['empleo'] == 1) & (df['w'] == 1) & (df['t'] == 0) & (df['d_d'] == 0)
        df.loc[cond_adecuado_1 | cond_adecuado_2, 'empleo_adecuado'] = 1
        
        # Mapeos a texto final
        df['condicion_empleo_adecuado'] = df['empleo_adecuado'].map({1: "Adecuado", 0: "No Adecuado/Inactivo"})
        df['condicion_empleo_no_remun'] = df['empleo_no_remunerado'].map({1: "No Remunerado", 0: "Remunerado/Inactivo"})

        # --- AQUÍ ESTÁ EL ARREGLO MÁGICO ---
        df['anio'] = anio 
        
        # --- Empaquetar y guardar ---
        df_export = df[['anio', 'condicion_empleo_adecuado', 'condicion_empleo_no_remun']].copy()
        df_export['id_persona'] = df.index
        
        datos_modulo2.append(df_export)
        print(f"✅ {anio} procesado.")
        
    except Exception as e:
        print(f"❌ Error leyendo {anio}: {e}")

# ============================================================
# 4. EXPORTACIÓN
# ============================================================
if datos_modulo2:
    df_final_mod2 = pd.concat(datos_modulo2, ignore_index=True)
    ruta_salida = os.path.join(path_out, "02_Laboral_Emilio.parquet")
    df_final_mod2.to_parquet(ruta_salida)
    print(f"\n🎉 ¡Módulo 2 terminado! Base guardada en: {ruta_salida}")
    
    # Reporte
    print("\n📊 Resumen de Empleo Adecuado:")
    print(df_final_mod2['condicion_empleo_adecuado'].value_counts())
    print("\n📊 Resumen de Empleo No Remunerado:")
    print(df_final_mod2['condicion_empleo_no_remun'].value_counts())
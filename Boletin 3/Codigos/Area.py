import os
import pandas as pd
import pyreadstat

drive_root = "H:/Mi unidad"
path_base = os.path.join(drive_root, "Bases", "ENEMDU", "Originales", "Diciembres")
path_out = os.path.join(drive_root, "Boletín 3", "2. Armonización de variables", "Bases_limpias", "Emilio", "Modulos_Emilio")

datos_area = []
print("🚀 Iniciando Módulo 4: Área (Urbano/Rural)...")

for anio in range(1990, 2025):
    sub_c = "1990-1999" if anio < 2000 else "2000-2006" if anio <= 2006 else "2007-2017" if anio <= 2017 else os.path.join("2018-presente", "Trimestrales")
    ruta = os.path.join(path_base, sub_c, f"empleo{anio}.dta")
    
    if not os.path.exists(ruta): continue
        
    try:
        try: df = pd.read_stata(ruta, convert_categoricals=False)
        except: df = pd.read_stata(ruta, convert_categoricals=False, encoding="latin1")
            
        df.columns = [c.lower() for c in df.columns]
        
        # LÓGICA DE ÁREA
        if anio < 2000:
            # En los 90s todo era urbano
            df['area_armonizada'] = "Urbano"
        else:
            # Del 2000 en adelante buscamos la variable (area, área, urbrur)
            var_area = "area" if "area" in df.columns else "área" if "área" in df.columns else "urbrur" if "urbrur" in df.columns else "area1" if "area1" in df.columns else None
            
            if var_area:
                df['area_armonizada'] = pd.to_numeric(df[var_area], errors='coerce').map({1: "Urbano", 2: "Rural"})
            else:
                df['area_armonizada'] = "N/D"

        df['anio'] = anio
        df_export = df[['anio', 'area_armonizada']].copy()
        df_export['id_persona'] = df.index
        datos_area.append(df_export)
        print(f"✅ {anio} procesado.")
        
    except Exception as e:
        print(f"❌ Error en {anio}: {e}")

if datos_area:
    df_final = pd.concat(datos_area, ignore_index=True)
    df_final.to_parquet(os.path.join(path_out, "04_Area_Emilio.parquet"))
    print(f"\n🎉 ¡Módulo 4 terminado!")
import os
import pandas as pd
import pyreadstat

# ============================================================
# 1. CONFIGURACIÓN DE RUTAS (LA NUEVA QUE DEFINISTE)
# ============================================================
drive_root = "H:/Mi unidad"
path_modulos = os.path.join(drive_root, "Boletín 3", "2. Armonización de variables", "Bases_limpias", "Emilio", "Modulos_Emilio")

# ============================================================
# 2. CARGAR LOS 4 MÓDULOS (INCLUYENDO ÁREA)
# ============================================================
print("📥 Cargando Módulos de Emilio...")
df_demografia = pd.read_parquet(os.path.join(path_modulos, "01_Demografia_Emilio.parquet"))
df_laboral    = pd.read_parquet(os.path.join(path_modulos, "02_Laboral_Emilio.parquet"))
df_ramas      = pd.read_parquet(os.path.join(path_modulos, "03_Ramas_Emilio.parquet"))
df_area       = pd.read_parquet(os.path.join(path_modulos, "04_Area_Emilio.parquet")) # <--- NUEVO

# ============================================================
# 3. ENSAMBLAJE (MERGE MAESTRO)
# ============================================================
print("🧩 Uniendo bases de datos...")

# Unimos Demografía + Laboral
base_final = pd.merge(df_demografia, df_laboral, on=['anio', 'id_persona'], how='outer')

# Unimos el resultado + Ramas
base_final = pd.merge(base_final, df_ramas, on=['anio', 'id_persona'], how='outer')

# Unimos el resultado + Área (Urbano/Rural)
base_final = pd.merge(base_final, df_area, on=['anio', 'id_persona'], how='left') # <--- NUEVO

# Ordenamos cronológicamente
base_final = base_final.sort_values(by=['anio', 'id_persona'])

# ============================================================
# 4. EXPORTACIÓN A STATA (.dta)
# ============================================================
print("💾 Exportando archivo final para Stata...")

ruta_dta = os.path.join(path_modulos, "ENEMDU_Boletin3_Emilio_FINAL_V2.dta")

# Guardar en DTA
pyreadstat.write_dta(base_final, ruta_dta)

print(f"\n🎉 ¡MISIÓN CUMPLIDA!")
print(f"📍 Ubicación: {ruta_dta}")
print(f"📊 Total observaciones: {len(base_final):,}")
print(f"✅ Columnas: {list(base_final.columns)}")
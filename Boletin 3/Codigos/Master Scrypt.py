import os
import pandas as pd
import pyreadstat

# ============================================================
# RUTAS
# ============================================================
drive_root = "H:/Mi unidad"
path_modulos = os.path.join(drive_root, "Bases", "ENEMDU", "Procesadas", "Modulos_Emilio")

# ============================================================
# 1. CARGAR LOS 3 MÓDULOS
# ============================================================
print("📥 Cargando Módulos de Emilio...")
df_demografia = pd.read_parquet(os.path.join(path_modulos, "01_Demografia_Emilio.parquet"))
df_laboral = pd.read_parquet(os.path.join(path_modulos, "02_Laboral_Emilio.parquet"))
df_ramas = pd.read_parquet(os.path.join(path_modulos, "03_Ramas_Emilio.parquet"))

# ============================================================
# 2. ENSAMBLAJE (MERGE)
# ============================================================
print("🧩 Uniendo bases de datos...")

# Unimos Demografía + Laboral usando outer para no perder a nadie
base_final = pd.merge(df_demografia, df_laboral, on=['anio', 'id_persona'], how='outer')

# Unimos el resultado + Ramas
base_final = pd.merge(base_final, df_ramas, on=['anio', 'id_persona'], how='outer')

# Ordenamos cronológicamente
base_final = base_final.sort_values(by=['anio', 'id_persona'])

# ============================================================
# 3. EXPORTACIÓN A STATA (.dta)
# ============================================================
print("💾 Exportando archivo final para Stata (Esto puede tomar 1 o 2 minutos)...")

ruta_dta = os.path.join(path_modulos, "ENEMDU_Boletin3_Emilio_FINAL.dta")

# Guardar en DTA (Perfecto para Stata)
pyreadstat.write_dta(base_final, ruta_dta)

print(f"\n🎉 ¡MISIÓN CUMPLIDA! Base final lista para enviar a revisión y graficar.")
print(f"📍 Ubicación: {ruta_dta}")
print("\n📊 Resumen de tu Base Final Maestra:")
print(f"Total de observaciones (filas): {len(base_final):,}")
print("Columnas integradas:", list(base_final.columns))
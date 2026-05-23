
"""## **Informal-Sector informal**"""

import pandas as pd

# 1. Ruta del mapa maestro
ruta_mapa = '/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 3/2. Armonización de variables/Bases_limpias/Respaldo/Mapa_Maestro_1990_2024.xlsx'

# 2. Cargar el mapa
df_mapa = pd.read_excel(ruta_mapa)

# 3. Usamos el nombre exacto que detectamos en tu lista
concepto_buscado = 'Informal-Sector informal'
mapa_sector = df_mapa[df_mapa['Concepto_Analisis'] == concepto_buscado].sort_values('Año')




# 4. Desplegar con auditoría de etiquetas/diccionario
with pd.option_context('display.max_rows', None, 'display.max_colwidth', 500):
    print(f"📋 AUDITORÍA DE VARIABLE: {concepto_buscado} (1990-2024)")
    print("-" * 120)

    if not mapa_sector.empty:
        # Mostramos Año, la Variable original y las Etiquetas
        columnas_ver = ['Año', 'Variable_Original_DTA', 'Etiquetas_Diccionario']
        columnas_finales = [c for c in columnas_ver if c in mapa_sector.columns]

        print(mapa_sector[columnas_finales].to_string(index=False))
    else:
        print(f"⚠️ No se encontró el concepto '{concepto_buscado}'.")

import pandas as pd
import pyreadstat
import os

# --- 1. CONFIGURACIÓN ---
path_base = "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Originales/Diciembres"
path_limpias = '/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 3/2. Armonización de variables/Bases_limpias/Wilson'
df_mapa = pd.read_excel(ruta_mapa)

def regla_sector_binario(row, columnas):
    """
    Regla universal basada en auditoría:
    1: Sector Informal (Código 2)
    0: Cualquier otro sector (Formal, Doméstico, Agrícola, No clasificado)
    """
    for col in columnas:
        val = row[col]
        if pd.isna(val): continue
        try:
            if int(float(val)) == 2:
                return 1
        except:
            continue
    return 0

# --- 2. PROCESAMIENTO ---
lista_sector = []

for anio in range(1990, 2025):
    info_anio = df_mapa[(df_mapa['Año'] == anio) &
                        (df_mapa['Concepto_Analisis'] == 'Informal-Sector informal')]

    if info_anio.empty: continue

    # Capturamos las variables detectadas (peamsiu, SECEMP, secemp)
    columnas_dta = [c for c in info_anio['Variable_Original_DTA'].unique()]

    # Lógica de carpetas
    if 1990 <= anio <= 1999: sub = "1990-1999"
    elif 2000 <= anio <= 2006: sub = "2000-2006"
    elif 2007 <= anio <= 2017: sub = "2007-2017"
    else: sub = os.path.join("2018-presente", "Trimestrales")

    ruta_input = os.path.join(path_base, sub, f"empleo{anio}.dta")

    if os.path.exists(ruta_input):
        print(f"🔄 Procesando Sector {anio}...", end=" ")
        df_t, _ = pyreadstat.read_dta(ruta_input, usecols=columnas_dta)

        df_t['sector_informal'] = df_t.apply(lambda x: regla_sector_binario(x, columnas_dta), axis=1)
        df_t['anio'] = anio
        df_t['id_persona'] = df_t.index

        lista_sector.append(df_t[['anio', 'id_persona', 'sector_informal']])
        print("✅")

# Consolidación
df_master_sector = pd.concat(lista_sector, ignore_index=True)
ruta_master_sec = os.path.join(path_limpias, "Master_Sector_Informal_90_24.dta")
pyreadstat.write_dta(df_master_sector, ruta_master_sec)
print(f"\n🚀 Master de Sector guardado en: {ruta_master_sec}")

import matplotlib.pyplot as plt

# 1. Tabla de control
tabla_sec = pd.crosstab(df_master_sector['anio'], df_master_sector['sector_informal'], normalize='index') * 100
tabla_sec.columns = ['% Resto (Formal/Domest/Agro)', '% Sector Informal (1)']

print("\n📊 RESULTADOS HISTÓRICOS: SECTOR INFORMAL")
display(tabla_sec.round(2))

# 2. Gráfico
plt.figure(figsize=(12, 5))
plt.plot(tabla_sec.index, tabla_sec['% Sector Informal (1)'],
         marker='s', color='#E67E22', linewidth=2, label='Tasa Sector Informal')

plt.title('Evolución del Sector Informal en Ecuador (1990-2024)', fontsize=14)
plt.ylabel('Porcentaje (%)')
plt.ylim(0, 100)
plt.grid(True, alpha=0.3)
plt.legend()
plt.show()

import matplotlib.pyplot as plt

# 1. Tabla de control
tabla_sec = pd.crosstab(df_master_sector['anio'], df_master_sector['sector_informal'], normalize='index') * 100
tabla_sec.columns = ['% Resto (Formal/Domest/Agro)', '% Sector Informal (1)']

print("\n📊 RESULTADOS HISTÓRICOS: SECTOR INFORMAL")
display(tabla_sec.round(2))

# 2. Gráfico
plt.figure(figsize=(12, 5))
plt.plot(tabla_sec.index, tabla_sec['% Sector Informal (1)'],
         marker='s', color='#E67E22', linewidth=2, label='Tasa Sector Informal')

plt.title('Evolución del Sector Informal en Ecuador (1990-2024)', fontsize=14)
plt.ylabel('Porcentaje (%)')
plt.ylim(0, 100)
plt.grid(True, alpha=0.3)
plt.legend()
plt.show()

"""### **Opcion 2 Informalidad**"""

import pandas as pd
import pyreadstat
import os
import numpy as np

# --- 1. CONFIGURACIÓN ---
path_base = "/content/drive/MyDrive/Observatorio/Bases/ENEMDU/Originales/Diciembres"
path_limpias = "/content/drive/MyDrive/Observatorio/Bases_limpias"
df_mapa = pd.read_excel(ruta_mapa)

def regla_sector_detallado(row, columnas, anio):
    """
    Lógica de Clasificación Independiente (Armonizada 1990-2024)
    """
    for col in columnas:
        val = row[col]
        if pd.isna(val): continue
        v = int(float(val))

        # Categoría 1: Sector Formal (Empresas con RUC, Estado, Moderno)
        if v == 1:
            return "Sector Formal"

        # Categoría 2: Sector Informal (Independientes, Negocios de Hogar)
        elif v == 2:
            return "Sector Informal"

        # Categoría 3: Empleo Doméstico (Remunerado)
        elif v in [3, 4] and "doméstico" in str(row).lower():
            # Nota: En los 90s era 4, hoy es 3. La auditoría nos guía.
            return "Empleo Doméstico"

        # Categoría 4: Sector Agropecuario / No Remunerado (Específico 90s)
        elif anio < 2007 and v == 3:
            return "Sector Agropecuario"

        # Categoría 5: No Clasificados o Otros
        elif v in [4, 5]:
            return "Otros / No Clasificados"

    return "No clasificado"

# --- 2. PROCESAMIENTO ---
lista_master = []

for anio in range(1990, 2025):
    # Usamos el concepto exacto de tu auditoría
    info_anio = df_mapa[(df_mapa['Año'] == anio) &
                        (df_mapa['Concepto_Analisis'] == 'Informal-Sector informal')]

    if info_anio.empty: continue
    columnas_dta = [c for c in info_anio['Variable_Original_DTA'].unique()]

    # Selección de carpeta según época
    if 1990 <= anio <= 1999: sub = "1990-1999"
    elif 2000 <= anio <= 2006: sub = "2000-2006"
    elif 2007 <= anio <= 2017: sub = "2007-2017"
    else: sub = os.path.join("2018-presente", "Trimestrales")

    ruta_input = os.path.join(path_base, sub, f"empleo{anio}.dta")

    if os.path.exists(ruta_input):
        print(f"📊 Procesando Estructura {anio}...", end=" ")
        # Leemos la variable (peamsiu, secemp, etc)
        df_t, _ = pyreadstat.read_dta(ruta_input, usecols=columnas_dta)

        # Aplicamos la lógica multicategoría
        df_t['categoria_sector'] = df_t.apply(lambda x: regla_sector_detallado(x, columnas_dta, anio), axis=1)
        df_t['anio'] = anio
        df_t['id_persona'] = df_t.index

        lista_master.append(df_t[['anio', 'id_persona', 'categoria_sector']])
        print("✅")

# Guardado del Master Multicategoría
df_master_final = pd.concat(lista_master, ignore_index=True)
ruta_save = os.path.join(path_limpias, "Master_Estructura_Sector_90_24.dta")
pyreadstat.write_dta(df_master_final, ruta_save)

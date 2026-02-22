#!/usr/bin/env python3
"""
Convert Excel datasets to JavaScript data.js format
Reads all .xlsx files from Data Final/ and generates docs/data.js
"""

import pandas as pd
import json
from pathlib import Path
import re

# Paths
data_dir = Path("/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final")
output_file = Path("/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/docs/data.js")

# Dataset name mappings (Excel filename -> JavaScript key)
DATASET_MAPPING = {
    # Existing datasets
    "scorecards_indicadores.xlsx": "scorecards",
    "series_historicas_indicadores.xlsx": "seriesHistoricas",
    "Pobreza_tableau.xlsx": "pobrezaTableau",
    "gini_panel_tableau.xlsx": "giniPanel",
    "pobreza_provincial.xlsx": "pobrezaProvincial",
    "pobreza_sexo_etnia.xlsx": "pobrezaSexoEtnia",
    "indicadores_sexo_etnia.xlsx": "indicadoresSexoEtnia",
    "WID_ingreso_percentiles_tableau.xlsx": "widIngresoPercentiles",
    "WID_riqueza_percentiles_tableau.xlsx": "widRiquezaPercentiles",
    "WID_ingreso_percentiles_ALC_tableau.xlsx": "widIngresoPercentilesALC",
    "WID_riqueza_percentiles_ALC_tableau.xlsx": "widRiquezaPercentilesALC",

    # New datasets from Step 2
    "pobreza_educacion.xlsx": "pobrezaEducacion",
    "pobreza_edad.xlsx": "pobrezaEdad",
    "pobreza_region.xlsx": "pobrezaRegion",
    "variacion_pobreza_significancia.xlsx": "variacionPobrezaSignificancia",
    "empleo_series.xlsx": "empleoSeries",
    "empleo_demografico.xlsx": "empleoDemografico",
    "empleo_scorecard.xlsx": "empleoScorecard",
    "variacion_empleo_significancia.xlsx": "variacionEmpleoSignificancia",
    "salarios_series.xlsx": "salariosSeries",
    "brechas_salariales.xlsx": "brechasSalariales",
    "crecimiento_percentiles.xlsx": "crecimientoPercentiles",
    "crecimiento_demografico.xlsx": "crecimientoDemografico",
    "crecimiento_empleo_sector.xlsx": "crecimientoEmpleoSector",
    "gini_lac_comparison.xlsx": "giniLacComparison",
    "pobreza_multidimensional_scorecard.xlsx": "pobrezaMultidimensionalScorecard",
    "pobreza_multidimensional_series.xlsx": "pobrezaMultidimensionalSeries",
    "iess_afiliados.xlsx": "iessAfiliados",
    "sri_percentiles_ingreso.xlsx": "sriPercentilesIngreso",
    "tributacion_graficos.xlsx": "tributacionGraficos",
    "gini_tax_impact.xlsx": "giniTaxImpact",
    "poblacion_percentiles.xlsx": "poblacionPercentiles",
}

def clean_column_name(name):
    """Convert column names to camelCase for JavaScript"""
    # Remove accents and special characters
    name = str(name).strip()
    # Replace common Spanish characters
    replacements = {
        'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
        'ñ': 'n', 'Ñ': 'N'
    }
    for old, new in replacements.items():
        name = name.replace(old, new)

    # Convert to camelCase
    # Split by spaces, underscores, or hyphens
    words = re.split(r'[\s_-]+', name)
    if not words:
        return name

    # First word lowercase, rest capitalized
    result = words[0].lower()
    for word in words[1:]:
        if word:
            result += word.capitalize()

    return result

def read_excel_file(file_path):
    """Read Excel file and convert to list of dictionaries"""
    try:
        # Read all sheets
        excel_file = pd.ExcelFile(file_path)

        # If multiple sheets, create nested structure
        if len(excel_file.sheet_names) > 1:
            data = {}
            for sheet_name in excel_file.sheet_names:
                df = pd.read_excel(file_path, sheet_name=sheet_name)
                # Clean column names
                df.columns = [clean_column_name(col) for col in df.columns]
                # Convert to records, handling NaN values
                records = df.where(pd.notna(df), None).to_dict('records')
                data[clean_column_name(sheet_name)] = records
            return data
        else:
            # Single sheet - return as array
            df = pd.read_excel(file_path, sheet_name=0)
            # Clean column names
            df.columns = [clean_column_name(col) for col in df.columns]
            # Convert to records, handling NaN values
            records = df.where(pd.notna(df), None).to_dict('records')
            return records
    except Exception as e:
        print(f"Error reading {file_path.name}: {e}")
        return None

def main():
    print("Converting Excel datasets to JavaScript...")
    print(f"Data directory: {data_dir}")
    print(f"Output file: {output_file}")
    print("-" * 80)

    # Collect all data
    all_data = {}
    processed_count = 0
    skipped_count = 0

    # Process each Excel file
    excel_files = sorted(data_dir.glob("*.xlsx"))

    for excel_file in excel_files:
        # Skip temporary files
        if excel_file.name.startswith("~$"):
            continue

        # Get JavaScript key name
        js_key = DATASET_MAPPING.get(excel_file.name)

        if not js_key:
            print(f"⚠️  Skipping {excel_file.name} (no mapping defined)")
            skipped_count += 1
            continue

        # Read and convert
        print(f"✓ Processing {excel_file.name} → {js_key}")
        data = read_excel_file(excel_file)

        if data is not None:
            all_data[js_key] = data
            processed_count += 1
        else:
            skipped_count += 1

    # Generate JavaScript file
    print("-" * 80)
    print(f"Generating {output_file}...")

    # Convert to JSON string with proper formatting
    json_str = json.dumps(all_data, ensure_ascii=False, indent=None, separators=(',', ': '))

    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("// Auto-generated — do not edit\n")
        f.write(f"const DATA = {json_str};\n")

    print("-" * 80)
    print(f"✅ Complete!")
    print(f"   Processed: {processed_count} datasets")
    print(f"   Skipped: {skipped_count} files")
    print(f"   Output: {output_file}")

    # Show dataset keys
    print("\n📊 Available datasets:")
    for key in sorted(all_data.keys()):
        data_type = "Object" if isinstance(all_data[key], dict) else f"Array[{len(all_data[key])}]"
        print(f"   - DATA.{key}: {data_type}")

if __name__ == "__main__":
    main()

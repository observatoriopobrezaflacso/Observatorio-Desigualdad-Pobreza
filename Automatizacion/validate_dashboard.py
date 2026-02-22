#!/usr/bin/env python3
"""
Validate dashboard data and check for common issues
"""

import json
from pathlib import Path

# Paths
docs_dir = Path("/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/docs")
data_js = docs_dir / "data.js"

print("=" * 80)
print("DASHBOARD VALIDATION")
print("=" * 80)

# Read and parse data.js
print("\n1. Checking data.js file...")
with open(data_js, 'r', encoding='utf-8') as f:
    content = f.read()

# Extract JSON
json_str = content.replace('// Auto-generated — do not edit\n', '').replace('const DATA = ', '').rstrip(';\n')

try:
    data = json.loads(json_str)
    print("   ✅ data.js is valid JSON")
    print(f"   ✅ Contains {len(data)} datasets")
except json.JSONDecodeError as e:
    print(f"   ❌ JSON parsing error: {e}")
    exit(1)

# Check required datasets for each page
print("\n2. Checking required datasets...")

required_datasets = {
    'Pobreza': ['pobrezaTableau', 'pobrezaSexoEtnia', 'pobrezaEducacion', 'pobrezaEdad',
                'pobrezaRegion', 'variacionPobrezaSignificancia', 'pobrezaProvincial'],
    'Empleo': ['empleoSeries', 'empleoDemografico', 'crecimientoEmpleoSector', 'variacionEmpleoSignificancia'],
    'Salarios': ['salariosSeries', 'brechasSalariales'],
    'Crecimiento': ['crecimientoPercentiles', 'crecimientoDemografico', 'crecimientoEmpleoSector'],
    'Desigualdad': ['giniPanel']
}

all_good = True
for page, datasets in required_datasets.items():
    print(f"\n   {page} page:")
    for ds in datasets:
        if ds in data:
            if isinstance(data[ds], dict):
                sheets = list(data[ds].keys())
                print(f"      ✅ {ds} (Object with {len(sheets)} sheets)")
            elif isinstance(data[ds], list):
                print(f"      ✅ {ds} ({len(data[ds])} rows)")
            else:
                print(f"      ⚠️  {ds} (unexpected type: {type(data[ds])})")
        else:
            print(f"      ❌ {ds} MISSING")
            all_good = False

# Check specific field names
print("\n3. Checking field names in key datasets...")

field_checks = {
    'pobrezaTableau': ['ano', 'indicador', 'nivel', 'valor'],
    'pobrezaEducacion': ['anio', 'nivelEducativo', 'indicador', 'valor'],
    'pobrezaEdad': ['anio', 'grupoEtario', 'indicador', 'valor'],
    'pobrezaSexoEtnia': ['anio', 'grupo', 'tipoGrupo', 'indicador', 'valor'],
    'empleoDemografico': ['anio', 'tipoCategoria', 'categoria', 'empleoAdecuado'],
    'empleoSeries': ['anio', 'indicador', 'valor'],
    'salariosSeries': ['anio', 'tipo', 'valor'],
    'giniPanel': ['ano', 'categoria', 'valor'],
}

for dataset, expected_fields in field_checks.items():
    if dataset in data and isinstance(data[dataset], list) and len(data[dataset]) > 0:
        actual_fields = list(data[dataset][0].keys())
        missing = set(expected_fields) - set(actual_fields)
        extra = set(actual_fields) - set(expected_fields)

        if not missing and not extra:
            print(f"   ✅ {dataset}: {actual_fields}")
        else:
            print(f"   ⚠️  {dataset}:")
            print(f"      Actual: {actual_fields}")
            if missing:
                print(f"      Missing: {list(missing)}")
            if extra:
                print(f"      Extra: {list(extra)}")
    elif dataset in data and isinstance(data[dataset], dict):
        # Check first sheet
        first_sheet = list(data[dataset].keys())[0]
        if len(data[dataset][first_sheet]) > 0:
            actual_fields = list(data[dataset][first_sheet][0].keys())
            print(f"   ✅ {dataset}.{first_sheet}: {actual_fields}")

# Check for multi-sheet datasets
print("\n4. Checking multi-sheet datasets...")

multi_sheet = {
    'brechasSalariales': ['educacion', 'genero', 'etnia'],
    'crecimientoPercentiles': ['percentiles', 'deciles'],
}

for dataset, expected_sheets in multi_sheet.items():
    if dataset in data and isinstance(data[dataset], dict):
        actual_sheets = list(data[dataset].keys())
        missing = set(expected_sheets) - set(actual_sheets)

        if not missing:
            print(f"   ✅ {dataset}: {actual_sheets}")
            # Check structure of first sheet
            first_sheet = actual_sheets[0]
            if len(data[dataset][first_sheet]) > 0:
                fields = list(data[dataset][first_sheet][0].keys())
                print(f"      Fields in '{first_sheet}': {fields}")
        else:
            print(f"   ⚠️  {dataset}: Missing sheets {list(missing)}")

# Check data completeness
print("\n5. Checking data completeness...")

completeness_checks = [
    ('pobrezaEducacion', 'nivelEducativo', 'Pobreza'),
    ('pobrezaEdad', 'grupoEtario', 'Pobreza'),
    ('pobrezaRegion', 'region', 'Pobreza'),
    ('empleoSeries', 'indicador', None),
    ('salariosSeries', 'tipo', None),
]

for dataset, group_field, indicator in completeness_checks:
    if dataset in data and isinstance(data[dataset], list):
        df = data[dataset]

        if indicator:
            df = [r for r in df if r.get('indicador') == indicator]

        if group_field:
            groups = set(r.get(group_field) for r in df if r.get(group_field))
            years = set(r.get('anio') or r.get('ano') for r in df if r.get('anio') or r.get('ano'))
            print(f"   {dataset}:")
            print(f"      {len(groups)} {group_field} categories: {sorted(groups)}")
            print(f"      {len(years)} years: {min(years) if years else 'N/A'} - {max(years) if years else 'N/A'}")

# Summary
print("\n" + "=" * 80)
if all_good:
    print("✅ All validations passed!")
else:
    print("⚠️  Some issues found - check details above")
print("=" * 80)

# Test specific data access patterns used in JS
print("\n6. Testing JavaScript access patterns...")

test_cases = [
    ("Poverty by nivel",
     lambda: [r for r in data['pobrezaTableau'] if r['indicador'] == 'Pobreza' and r['valor'] is not None]),

    ("Poverty by education",
     lambda: [r for r in data['pobrezaEducacion'] if r['indicador'] == 'Pobreza' and r['valor'] is not None]),

    ("Poverty by age",
     lambda: [r for r in data['pobrezaEdad'] if r['indicador'] == 'Pobreza' and r['valor'] is not None]),

    ("Employment series",
     lambda: [r for r in data['empleoSeries'] if r['valor'] is not None]),

    ("Employment demographics",
     lambda: [r for r in data['empleoDemografico'] if r['tipoCategoria'] == 'sexo' and r['empleoAdecuado'] is not None]),

    ("Wage series",
     lambda: [r for r in data['salariosSeries'] if r['valor'] is not None]),

    ("Wage gaps - education",
     lambda: [r for r in data['brechasSalariales']['educacion'] if r['salarioPromedio'] is not None]),

    ("GIC curves",
     lambda: [r for r in data['crecimientoPercentiles']['percentiles'] if r['periodo'].startswith('2017-2021')]),

    ("Gini panel",
     lambda: [r for r in data['giniPanel'] if r['valor'] is not None]),
]

for test_name, test_func in test_cases:
    try:
        result = test_func()
        print(f"   ✅ {test_name}: {len(result)} rows")
    except Exception as e:
        print(f"   ❌ {test_name}: {str(e)}")
        all_good = False

print("\n" + "=" * 80)
print("VALIDATION COMPLETE")
print("=" * 80)

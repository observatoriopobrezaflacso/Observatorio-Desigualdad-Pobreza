# Dashboard Bug Fixes - Column Name Mismatches

## Issue
Most charts were empty because the JavaScript rendering functions were using the original Spanish column names, but the Python conversion script converted all columns to camelCase.

## Root Cause
The `convert_excel_to_js.py` script converts column names like:
- `Año` → `ano`
- `tipo_grupo` → `tipoGrupo`
- `nivel_educativo` → `nivelEducativo`
- `grupo_etario` → `grupoEtario`

But the rendering functions were still looking for the original column names.

---

## Fixes Applied

### 1. Poverty Page (`renderPobrezaNivel`)
**Changed:**
- `DATA.pobrezaPanel` → `DATA.pobrezaTableau` (dataset didn't exist)
- `r.Indicador` → `r.indicador`
- `r.Valor` → `r.valor`
- `r['Año']` → `r.ano`

### 2. Poverty by Etnia/Sexo
**Changed:**
- `r.tipo_grupo` → `r.tipoGrupo`

### 3. Poverty by Education (`renderPobrezaEducacion`)
**Changed:**
- `groupBy(data, 'nivel')` → `groupBy(data, 'nivelEducativo')`

### 4. Poverty by Age (`renderPobrezaEdad`)
**Changed:**
- `groupBy(data, 'grupo')` → `groupBy(data, 'grupoEtario')`

### 5. Employment Demographics (`renderEmpleoDemo`)
**Changed:**
- `r.dimension` → `r.tipoCategoria`
- `r.nivel` → `r.categoria`
- `r.indicador === 'Empleo adecuado'` → `r.empleoAdecuado != null`
- `r.valor` → `r.empleoAdecuado`

### 6. Wage Evolution (`renderSalariosSeries`)
**Changed:**
- `groupBy(data, 'indicador')` → `groupBy(data, 'tipo')`

### 7. Wage Gaps (`renderBrechas` and `renderBrechasTrend`)
**Complete Restructure:**
- Original code expected `grupo1`, `grupo2`, `brecha` fields
- Actual data has `nivelEducativo`/`sexo`/`etnia` + `salarioPromedio`
- Changed to show average salaries by category instead of calculated gaps
- Updated chart labels: "Brecha salarial (%)" → "Salario promedio ($)"
- Updated tooltip formatting from `%` to `$`

**HTML changes:**
- "Brecha Salarial por Dimensión" → "Salarios por Dimensión"
- "Tipo de Brecha" → "Dimensión"
- "Tendencia de Brechas Salariales" → "Evolución de Salarios por Categoría"

### 8. Gini Coefficient (`renderDesigualdad`)
**Changed:**
- `r['Año']` → `r.ano`

---

## Dataset Structure Reference

### Correct camelCase Field Names:

**pobrezaTableau:**
- `ano`, `indicador`, `nivel`, `valor`

**pobrezaEducacion:**
- `anio`, `nivelEducativo`, `indicador`, `valor`

**pobrezaEdad:**
- `anio`, `grupoEtario`, `indicador`, `valor`

**pobrezaRegion:**
- `anio`, `region`, `indicador`, `valor`

**pobrezaSexoEtnia:**
- `anio`, `grupo`, `tipoGrupo`, `indicador`, `valor`

**empleoDemografico:**
- `anio`, `tipoCategoria`, `categoria`, `empleoAdecuado`

**empleoSeries:**
- `anio`, `indicador`, `valor`

**salariosSeries:**
- `anio`, `tipo`, `valor`

**brechasSalariales.educacion:**
- `anio`, `nivelEducativo`, `salarioPromedio`

**brechasSalariales.genero:**
- `anio`, `sexo`, `salarioPromedio`

**brechasSalariales.etnia:**
- `anio`, `etnia`, `salarioPromedio`

**giniPanel:**
- `ano`, `categoria`, `valor`

---

## Status
✅ All fixes applied
🧪 Ready for testing

## Next Step
Open [docs/index.html](../docs/index.html) in browser and test all pages:
1. ✅ Inicio
2. 🔄 Pobreza (4 new charts + significance table)
3. 🔄 Empleo (4 charts)
4. 🔄 Salarios (3 charts - now showing salaries not gaps)
5. 🔄 Distribución del Crecimiento (3 charts)
6. ✅ Desigualdad
7. ✅ Concentración
8. ✅ América Latina

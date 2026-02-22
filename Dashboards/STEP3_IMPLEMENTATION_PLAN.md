# Step 3: Dashboard Extension Implementation Plan

## Current Dashboard Status

**Existing Pages:**
1. **Inicio** - Home with scorecards and overview charts
2. **Pobreza** - Poverty indicators (basic)
3. **Desigualdad** - Gini coefficient comparison
4. **Concentración** - WID income/wealth shares
5. **América Latina** - Regional WID comparisons

**Technology Stack:**
- Vanilla JavaScript
- Chart.js 4.4.7
- Static HTML/CSS
- Data loaded from `data.js`

---

## New Datasets Available (from Step 2)

### ✅ Poverty Datasets (Real ENEMDU Data)
1. `pobreza_educacion.xlsx` - Poverty by education (2007-2024, 72 rows)
2. `pobreza_edad.xlsx` - Poverty by age groups (2007-2024, 36 rows)
3. `pobreza_region.xlsx` - Poverty by region (2007-2017, 66 rows)
4. `variacion_pobreza_significancia.xlsx` - Year-over-year changes with t-tests (102 rows)

### ✅ Employment Datasets (Real ENEMDU Data)
5. `empleo_series.xlsx` - Employment time series (54 rows)
6. `empleo_demografico.xlsx` - Employment by demographics (151 rows)
7. `variacion_empleo_significancia.xlsx` - Employment changes

### ✅ Wage Datasets (Real ENEMDU Data)
8. `salarios_series.xlsx` - Wage evolution (36 rows)
9. `brechas_salariales.xlsx` - 5 sheets with wage gaps by education, gender, ethnicity, age, marital status

### ✅ Growth Distribution (Real ENEMDU Data)
10. `crecimiento_percentiles.xlsx` - Growth Incidence Curves (4 periods)
11. `crecimiento_demografico.xlsx` - Income growth by demographics (5 rows)
12. `crecimiento_empleo_sector.xlsx` - Employment growth by sector (97 rows)

### ⚠️ Other Datasets
13. `gini_lac_comparison.xlsx` - Real World Bank data
14. Multidimensional poverty, IESS, SRI, taxation - TOY DATA

---

## Implementation Tasks

### Task 1: Enhanced Poverty Page
**Add to existing Pobreza page:**
- ✅ Poverty by education level (Superior vs No Superior)
- ✅ Poverty by age groups chart (Niños, Jóvenes, Adultos, Adultos mayores)
- ✅ Poverty by region chart (Costa, Sierra, Oriente)
- ✅ Statistical significance indicators for year-over-year changes
- ✅ Downloadable significance table

**Datasets:** `pobreza_educacion.xlsx`, `pobreza_edad.xlsx`, `pobreza_region.xlsx`, `variacion_pobreza_significancia.xlsx`

### Task 2: New Employment Page
**Create new "Empleo" page with:**
- Employment status evolution (Empleo adecuado, no adecuado, desempleo)
- Employment by demographics (sex, ethnicity, education, age)
- Employment by economic sector over time
- Statistical significance tests for employment changes

**Datasets:** `empleo_series.xlsx`, `empleo_demografico.xlsx`, `crecimiento_empleo_sector.xlsx`, `variacion_empleo_significancia.xlsx`

### Task 3: New Wages & Gaps Page
**Create new "Salarios y Brechas" page with:**
- Wage evolution over time
- Wage gaps by education level
- Wage gaps by gender (and gender+marital status)
- Wage gaps by ethnicity
- Wage gaps by age groups
- Gap trends visualization

**Datasets:** `salarios_series.xlsx`, `brechas_salariales.xlsx` (5 sheets)

### Task 4: New Growth Distribution Page
**Create new "Distribución del Crecimiento" page with:**
- Growth Incidence Curves (GIC) for political periods:
  - 2007-2017 (Correísmo)
  - 2017-2021 (Moreno)
  - 2021-2024 (Lasso/Noboa)
  - 2007-2024 (Complete)
- Income growth by demographics (ethnicity, area, education)
- Employment growth by economic sector

**Datasets:** `crecimiento_percentiles.xlsx`, `crecimiento_demografico.xlsx`, `crecimiento_empleo_sector.xlsx`

### Task 5: Data Conversion
**Convert Excel files to JavaScript data objects:**
- Create Python script to convert all `.xlsx` files to JSON
- Generate updated `data.js` with all datasets
- Maintain existing data structure compatibility

### Task 6: Update Navigation
**Add new menu items:**
- 📊 Empleo (Employment)
- 💵 Salarios y Brechas (Wages & Gaps)
- 📈 Distribución del Crecimiento (Growth Distribution)

---

## Technical Implementation Steps

1. **Data Conversion Script** (Python)
   - Read all Excel files from `Data Final/`
   - Convert to JSON format
   - Generate `data.js` with all datasets

2. **Update `index.html`**
   - Add new page sections for Employment, Wages, Growth Distribution
   - Add navigation menu items
   - Add chart containers and filters

3. **Update `app.js`**
   - Add rendering functions for new visualizations
   - Add filter/interaction logic
   - Add data loading for new datasets

4. **Update `styles.css`**
   - Add any new styling needed for charts
   - Ensure responsive design

5. **Testing**
   - Test all visualizations load correctly
   - Test filters and interactions
   - Test on different screen sizes

---

## Priority Order

1. **HIGH**: Task 5 (Data Conversion) - Required for everything else
2. **HIGH**: Task 1 (Enhanced Poverty) - Extends existing page with new data
3. **MEDIUM**: Task 2 (Employment Page) - New comprehensive section
4. **MEDIUM**: Task 3 (Wages Page) - New gap analysis
5. **MEDIUM**: Task 4 (Growth Distribution) - Advanced GIC visualizations

---

## Next Steps

1. Create data conversion script
2. Generate updated `data.js`
3. Implement enhanced poverty visualizations
4. Add new pages one by one
5. Test and refine


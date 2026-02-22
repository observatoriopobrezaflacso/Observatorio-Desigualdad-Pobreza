# Quick Reference - Data Sources

## Processed Datasets Locations

### Per Capita Income (for poverty calculation)
```
/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ingresos_pc
```

**Files**: `ing_perca_{year}_{area}_precios2000.dta`
**Key variables**:
- `ingtot_per_deflated` - Total per capita income (deflated to 2000 prices)
- `fw` - Survey weight
- `p01` - Sex (1=Male, 2=Female)
- `p02` - Age
- `p03` - Education level
- `p15` - Ethnicity (1=Indigenous, 2-6=Non-indigenous)
- `area` - Area (1=Urban, 2=Rural)

### Employment by Sector
```
/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Bases/Procesadas/ramas homogeneizadas
```

**Files**: `empleo{year}.dta`

### Processing Code Reference
```
/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Boletín 1/Procesamiento/Codigos
```

## Poverty Lines (Ecuador, in 2000 prices)

**TODO**: Look up official INEC poverty lines for Ecuador (deflated to 2000 prices) or use:
- Extreme poverty line: ~$25-30 USD/month per capita (2000 prices)
- Poverty line: ~$50-55 USD/month per capita (2000 prices)

These need to be verified against official INEC publications.

## Current Execution Status

- ❌ Scripts 01-05 (Poverty): Need poverty lines + use processed income files
- ✅ Scripts 06-08 (Employment, Wages, Growth): Can use ENEMDU merged files directly
- ⚠️ Script 09 (Inequality): Partial (WDI works, SRI needs toy data)
- 🎲 Script 10 (Taxation): Uses toy data

## Next Steps

1. Find official poverty lines or calculate from existing processed data
2. Update poverty scripts to use `/ingresos_pc/` files
3. Implement poverty calculation using poverty lines
4. Update employment sector script to use `/ramas homogeneizadas/` files

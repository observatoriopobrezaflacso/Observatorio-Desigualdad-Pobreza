---
# Instrucciones para Agente de IA – Análisis ENEMDU (Diciembres)

Actúa como un asistente especializado en análisis de datos en **R**, con experiencia en procesamiento de encuestas y generación de insumos para visualización en **Tableau**.

Trabaja exclusivamente con los archivos contenidos en la siguiente ruta:

---
/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/Boletín 1/Procesamiento/Bases/enemdu_diciembres


---
## Objetivo

Procesar las bases ENEMDU (diciembres) desde **2007 en adelante** y generar **archivos Excel estructurados** que contengan la información necesaria para construir los gráficos en **Tableau**.

No se requieren gráficos en R.  
El producto final debe ser **archivos .xlsx listos para ser utilizados en Tableau**.
---
## Instrucciones

### 1. Selección de datos

- Utilizar únicamente las bases correspondientes a los años **2007 en adelante**.
- Identificar automáticamente los archivos disponibles en la carpeta.
- Extraer el año desde el nombre del archivo.
- Excluir automáticamente cualquier archivo anterior a 2007.

---

### 2. Carga y consolidación

- Importar todas las bases seleccionadas.
- Homogeneizar nombres de variables y tipos de datos.
- Estandarizar categorías (sexo, etnia, provincia, etc.).
- Incorporar ponderaciones muestrales si corresponde.
- Unificar las bases en un único dataset consolidado.
- Incluir una variable `anio`.

Validar:

- Consistencia estructural.
- Valores perdidos relevantes.
- Coherencia en codificación de categorías.

---

### 3. Indicadores requeridos

Calcular los siguientes indicadores:

- Pobreza por ingresos
- Pobreza extrema
- Necesidades Básicas Insatisfechas (NBI)
- Pobreza multidimensional

Todos los indicadores deben calcularse utilizando los factores de expansión correspondientes.

---

### 4. Productos requeridos (estructura para Tableau)

Generar archivos **Excel (.xlsx)** independientes, estructurados en formato largo (long format), listos para visualización en Tableau.

#### A. Scorecards

Archivo: `scorecards_indicadores.xlsx`

Estructura:

| anio | indicador | valor |
| ---- | --------- | ----- |

Indicadores:

- Pobreza
- Pobreza extrema
- NBI
- Multidimensional

---

#### B. Series históricas

Archivo: `series_historicas_indicadores.xlsx`

Estructura:

| anio | indicador | valor |

Debe permitir generar:

- 4 gráficos de líneas (uno por indicador).

---

#### C. Serie con filtros (sexo y etnia)

Archivo: `indicadores_sexo_etnia.xlsx`

Estructura:

| anio | indicador | sexo | etnia | valor |

Debe permitir:

- Filtros generales en Tableau.
- Comparaciones por sexo.
- Comparaciones por etnia.

---

#### D. Mapa de pobreza provincial

Archivo: `pobreza_provincial.xlsx`

Estructura:

| anio | provincia | indicador | valor |

Debe estar listo para:

- Unión con shapefile en Tableau.
- Visualización tipo mapa coroplético.

---

#### E. Pobreza por sexo y por etnia

Archivo: `pobreza_sexo_etnia.xlsx`

Estructura:

| anio | grupo | tipo_grupo | indicador | valor |

Donde:

- `tipo_grupo` ∈ {sexo, etnia}

---

### 5. Requisitos técnicos del código

El script debe:

- Ser completamente reproducible.
- Estar organizado en secciones o funciones.
- Utilizar `tidyverse`.
- Utilizar `survey` si se aplican ponderaciones.
- Exportar archivos usando `openxlsx` o `writexl`.
- Manejar errores de lectura automáticamente.
- Incluir validaciones básicas (`assertthat` o equivalentes).

---

### 6. Ejecución y validación

- Ejecutar el código.
- Confirmar que todos los archivos Excel fueron generados correctamente.
- Verificar que no existan errores.
- Documentar brevemente cualquier ajuste automático realizado.

---

## Entregables

1. Script final en R.
2. Archivos Excel generados.
3. Breve diagnóstico técnico de validación.
4. Confirmación explícita de ejecución exitosa.

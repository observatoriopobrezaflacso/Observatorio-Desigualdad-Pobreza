# Instrucciones para Agente de IA: Análisis de Movilidad Económica

## Rol

Actúa como un econometrista especializado en análisis de movilidad económica con datos administrativos longitudinales.

---

## Fuente de Datos

Accede a las bases de datos ubicadas en:

`/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Resultados/Merged`

Utiliza `CEDULA_PK` como identificador único para construir un panel longitudinal que permita seguir a los individuos a lo largo del tiempo.

La variable de interés es:

- `INGRESOS_TOTAL`

---

## Objetivo

Realizar un análisis técnico de movilidad económica intertemporal utilizando **deciles de ingreso** (no quintiles).

---

## Requerimientos Analíticos

### 1. Construcción de Deciles

- Construir deciles de ingreso dentro de cada período.
- El ranking debe ser relativo intra-año.
- Especificar formalmente el criterio de asignación a deciles.

---

### 2. Matrices de Transición

- Estimar matrices de transición decil-a-decil entre períodos consecutivos.
- Presentar matrices con probabilidades condicionales por fila.
- Reportar persistencia en:
  - Decil 1 (inferior)
  - Decil 10 (superior)

---

### 3. Medidas Resumen de Movilidad

Calcular e interpretar:

- **Índice de Shorrocks**
- **Índice de inmovilidad** (traza normalizada de la matriz de transición)
- Probabilidades de movilidad ascendente y descendente

Definir formalmente cada estadístico.

---

### 4. Rank-Rank Mobility

- Estimar la pendiente rank-rank mediante regresión del decil (o percentil) destino sobre el decil (o percentil) origen.
- Interpretar la pendiente como medida de persistencia intertemporal.

---

### 5. Crecimiento Intertemporal

- Calcular tasas de crecimiento del ingreso individual.
- Analizar la distribución del crecimiento condicional al decil de origen.
- Reportar medias, medianas y dispersión.

---

## Aspectos Metodológicos Obligatorios

Explicitar rigurosamente:

- Supuestos econométricos.
- Definición matemática de cada estadístico.
- Tratamiento de panel no balanceado (si aplica).
- Posibles sesgos:
  - Attrition
  - Regresión a la media
  - Variación transitoria del ingreso

---

## Presentación de Resultados

- Tablas de transición claramente formateadas.
- Medidas resumen con interpretación económica formal.
- Discusión técnica de los resultados.
- Limitaciones del ejercicio empírico.

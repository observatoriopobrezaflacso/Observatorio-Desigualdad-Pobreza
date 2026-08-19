# ¿Cuánto costaría eliminar la pobreza con un bono uniforme por hogar?

Tablero interactivo sobre el costo fiscal de un bono monetario en Ecuador, con la
**ENEMDU de diciembre de 2025** (INEC).

## El diseño analizado

- **Todos los hogares beneficiarios reciben el mismo monto**, sin ajustar por tamaño ni por brecha.
- El **monto de referencia** es el mínimo que garantiza sacar de la pobreza a un hogar de cuatro personas
  (dos adultos y dos niñas/os), aunque no tenga ningún ingreso:
  `4 × USD 92,40 = USD 369,60 al mes por hogar` (para pobreza extrema: `4 × USD 52,07 = USD 208,28`).
  La medición oficial es per cápita y no usa escalas de equivalencia, así que la composición del hogar de
  referencia no altera el umbral, solo su tamaño.
- La **unidad de análisis es el hogar** en los tres grupos objetivo.
- **Focalización**: reciben el bono todos los hogares pobres del grupo objetivo; el usuario fija cuántas
  personas no pobres lo reciben por cada persona pobre (valor por defecto: 1). La filtración **no es aleatoria**:
  la probabilidad de que un hogar no pobre sea incluido por error decae exponencialmente con su ingreso per
  cápita —se reduce a la mitad cada vez que el ingreso supera la línea en otro 25%, parámetro ajustable entre
  10% y 150%— y el nivel de la curva se calibra hasta alcanzar exactamente las personas fijadas por el usuario.
  Los hogares no pobres incluidos **suman el bono a su ingreso**, lo que los protege de caer bajo la línea
  encarecida por la inflación. Cuando el grupo objetivo es demográfico, la filtración proviene del mismo grupo.
- **Efecto inflacionario**: el usuario fija el alza de precios que provoca el programa (10% por defecto, hasta
  40%). Encarece la línea de pobreza en la misma proporción, con ingresos nominales fijos: sube el monto de
  referencia, algunos hogares beneficiarios ya no cruzan la línea y hogares que estaban apenas por encima caen
  bajo ella. Para poder recalcular todo esto en el navegador, el análisis en R exporta los microdatos de los
  8.686 hogares de la muestra (ingreso per cápita, miembros, factor de expansión y presencia de menores de 5 y
  de personas de 65 años o más; sin identificadores ni ubicación).

## Archivos

| Archivo | Qué hace |
|---|---|
| `01_analisis_transferencias.R` | Todo el análisis estadístico: construye la base de hogares desde el `.dta` de la ENEMDU, declara el diseño muestral complejo (`survey`), estima hogares y personas pobres, brechas por hogar, intervalos de confianza y las curvas de "cuántos hogares/personas salen de la pobreza con un bono de monto T". Exporta `resultados.json`. |
| `resultados.json` | Salida del análisis (único insumo del tablero). |
| `plantilla_tablero.html` | Plantilla del tablero (HTML + CSS + JS, sin dependencias externas). El marcador `/*__DATOS__*/null` es donde se inyectan los resultados. |
| `02_construir_tablero.R` | Inserta `resultados.json` en la plantilla y genera `tablero_transferencias.html`. |
| `tablero_transferencias.html` | **Tablero final**, autocontenido: se abre con doble clic, sin servidor ni internet. |

## Cómo regenerar

```bash
Rscript 01_analisis_transferencias.R   # análisis -> resultados.json
Rscript 02_construir_tablero.R         # plantilla + datos -> tablero_transferencias.html
```

Paquetes de R: `haven`, `dplyr`, `survey`, `jsonlite`.

## Contenido del tablero

- **Punto de partida**: pobreza en personas y en hogares, brecha media del hogar pobre, tamaño de los hogares, Gini.
- **El monto del bono**: la aritmética del hogar de referencia y su comprobación con los datos observados.
- **Simulador**: grupo objetivo (todos los hogares / con menores de 5 años / con personas de 65 años o más),
  meta (pobreza o pobreza extrema), monto del bono, filtración y costo administrativo.
- **Pobreza antes y después**: incidencia en porcentaje antes y después de la transferencia, en personas y en
  hogares a nivel nacional, y dentro del grupo objetivo cuando la focalización es demográfica.
- **Qué logra cada monto**: personas que salen de la pobreza y costo, según el monto del bono.
- **El efecto inflacionario**: personas que salen y pobreza resultante, según el alza de precios.
- **Focalización**: perfil de la probabilidad de inclusión por nivel de ingreso, costo total y costo por persona
  rescatada según la filtración.
- **Lo que cuesta la mala focalización**: costo total y costo por persona rescatada, según la filtración.
- **Tabla** con los seis escenarios y sus intervalos de confianza al 95%.

## Modelo de costo

```
Costo mensual = Monto × (hogares pobres del grupo + hogares no pobres alcanzados) × (1 + costo administrativo)
hogares no pobres alcanzados = filtración × personas pobres cubiertas ÷ tamaño medio del hogar no pobre
línea ajustada = línea × (1 + inflación);  monto de referencia = 4 × línea ajustada
Un hogar sale de la pobreza si  Monto ≥ (línea ajustada − ingreso per cápita) × número de miembros
Caen en pobreza los hogares con ingreso per cápita entre la línea y la línea ajustada que, con el bono que
  reciben (si lo reciben), siguen por debajo de la línea ajustada: y + Monto/miembros < línea ajustada
```

Los supuestos, límites y fuentes están detallados en la sección "Metodología" del propio tablero.

## Fuentes

- ENEMDU diciembre 2025 (INEC); líneas oficiales: pobreza USD 92,40 y pobreza extrema USD 52,07 per cápita al mes.
- Presupuesto General del Estado 2025, consolidado por sectorial (Ministerio de Economía y Finanzas).
- Gasto tributario: SRI (proyección 2025 de USD 7.230 millones, 5,6% del PIB; desglose de IVA y renta de 2023).
- Subsidios de la Proforma 2025 (MEF, cifras reportadas en prensa) y PIB nominal 2025 (BCE, preliminar).

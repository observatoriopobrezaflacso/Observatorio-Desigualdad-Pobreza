# ¿Cuánto costaría eliminar la pobreza con un bono uniforme por hogar?

Tablero interactivo sobre el costo fiscal de un bono monetario en Ecuador, con la
**ENEMDU anual 2025** (INEC): los doce meses de 2025 juntos (103.771 hogares), con los ingresos de cada
mes llevados a precios de diciembre de 2025.

## La base

- Se usa la base anual (`BDDenemdu_personas_2025_anual.sav`) y no la de diciembre: tiene doce veces más
  muestra (error estándar de la pobreza de 0,79 p.p., frente a 2,11 p.p. en la mensual), representa un mes
  promedio del año —lo que corresponde a un costo anual— y diluye las rarezas de un solo mes, como el décimo
  tercero de 2025, pagado en noviembre.
- Sus factores de expansión están hechos para el año completo: dentro de la base anual, la población rural
  ponderada va de 20% a 39% según el mes. Por eso **ninguna cifra se calcula para un mes por separado**.
- **Precios**: ingreso × 92,40 ÷ línea del mes. El INEC actualiza la línea cada mes con el IPC; la línea de
  cada mes se recupera de la clasificación oficial (está entre el mayor ingreso de los pobres y el menor de los
  no pobres de ese mes; se toma el extremo superior del rango compatible con las dos líneas). Así el análisis
  reproduce exactamente las variables `pobreza` y `epobreza` del INEC (21,78% y 6,83%), y lo comprueba con
  `stopifnot`. Conviene contrastar estas líneas con las que publique el INEC.

## El diseño analizado

- **Todos los hogares beneficiarios reciben el mismo monto**, sin ajustar por tamaño ni por brecha.
- El **monto de referencia** es el mínimo que garantiza sacar de la pobreza a un hogar de cuatro personas
  (dos adultos y dos niñas/os), aunque no tenga ningún ingreso:
  `4 × USD 92,40 = USD 369,60 al mes por hogar` (para pobreza extrema: `4 × USD 52,07 = USD 208,28`).
  La medición oficial es per cápita y no usa escalas de equivalencia, así que la composición del hogar de
  referencia no altera el umbral, solo su tamaño.
- La **unidad de análisis es el hogar** en los tres grupos objetivo.
- **Focalización**: reciben el bono todos los hogares pobres del grupo objetivo; el usuario fija cuántas
  personas no pobres lo reciben por cada persona pobre (valor por defecto: 1,1). La filtración **no es aleatoria**:
  la probabilidad de que un hogar no pobre sea incluido por error decae exponencialmente con su ingreso per
  cápita —se reduce a la mitad cada vez que el ingreso supera la línea en otro 85%, parámetro ajustable entre
  10% y 150%— y el nivel de la curva se calibra hasta alcanzar exactamente las personas fijadas por el usuario.
  Ambos valores por defecto vienen del **Bono de Desarrollo Humano** observado en la misma ENEMDU (p75/p76,
  hogares clasificados por su ingreso sin el bono): 1,06 personas no pobres por persona pobre receptora
  (IC 95%: 0,94–1,18) y una vida media de 87% de la línea. El tablero muestra ese perfil junto a la curva del modelo.
  Los hogares no pobres incluidos **suman el bono a su ingreso**, lo que los protege de caer bajo la línea
  encarecida por la inflación. Cuando el grupo objetivo es demográfico, la filtración proviene del mismo grupo.
- **Efecto inflacionario**: el usuario fija el alza de precios que provoca el programa (5% por defecto, hasta
  40%). Encarece la línea de pobreza en la misma proporción, con ingresos nominales fijos: sube el monto de
  referencia, algunos hogares beneficiarios ya no cruzan la línea y hogares que estaban apenas por encima caen
  bajo ella. Para poder recalcular todo esto en el navegador, el análisis en R exporta los microdatos de los
  103.771 hogares de la muestra (ingreso per cápita, miembros, factor de expansión y presencia de menores de 5 y
  de personas de 65 años o más; sin identificadores ni ubicación).

## Archivos

| Archivo | Qué hace |
|---|---|
| `01_analisis_transferencias.R` | Todo el análisis estadístico: construye la base de hogares desde el `.dta` de la ENEMDU, declara el diseño muestral complejo (`survey`), estima hogares y personas pobres, brechas por hogar e intervalos de confianza, mide la filtración observada del BDH y exporta los microdatos de hogares. Exporta `resultados.json`. |
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

## Intervalos de confianza

Los conteos (personas y hogares pobres, brechas agregadas) se calculan como proporción × total conocido de
personas u hogares: los factores de expansión están calibrados a la población proyectada, así que el error
estándar del conteo es el de la proporción multiplicado por ese total. Las incidencias usan directamente el
error estándar del diseño (estratos `estrato`, conglomerados `upm`).

## Modelo de costo

```
Costo mensual = Monto × (hogares pobres del grupo + hogares no pobres alcanzados) × (1 + costo administrativo)
P(hogar no pobre incluido) = min(1, c × 2^(−(y − línea) / (vida media × línea)))
c se calibra para que  Σ w·n·P = filtración × personas pobres del grupo   (hogares no pobres del mismo grupo)
hogares no pobres alcanzados = Σ w·P
línea ajustada = línea × (1 + inflación);  monto de referencia = 4 × línea ajustada
Un hogar sale de la pobreza si  Monto ≥ (línea ajustada − ingreso per cápita) × número de miembros
Caen en pobreza los hogares con ingreso per cápita entre la línea y la línea ajustada que, con el bono que
  reciben (si lo reciben), siguen por debajo de la línea ajustada: y + Monto/miembros < línea ajustada
```

Los supuestos, límites y fuentes están detallados en la sección "Metodología" del propio tablero.

## Fuentes

- ENEMDU anual 2025 (INEC); líneas oficiales de diciembre de 2025: pobreza USD 92,40 y pobreza extrema USD 52,07 per cápita al mes.
- Presupuesto General del Estado 2025, consolidado por sectorial (Ministerio de Economía y Finanzas).
- Gasto tributario: SRI (proyección 2025 de USD 7.230 millones, 5,6% del PIB; desglose de IVA y renta de 2023).
- Subsidios de la Proforma 2025 (MEF, cifras reportadas en prensa) y PIB nominal 2025 (BCE, preliminar).

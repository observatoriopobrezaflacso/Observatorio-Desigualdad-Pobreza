# Generación automática del Boletín 3

Arma el boletín en Word (`.docx`) a partir de las salidas de
`../1. Infomalidad/3. Analisis/analisis_descriptivo.do`: los gráficos se insertan desde los
`.png` que exporta Stata, las tablas se reconstruyen desde los `.xlsx`
exportados y **las cifras del texto se calculan**, no se escriben a mano.

Si se vuelve a correr el análisis con un año más de ENEMDU, basta volver a
correr el generador: el documento sale con los gráficos, las tablas y los
números del texto actualizados.

## Instalación (una sola vez)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Uso

Lo más simple es el master del boletín, que corre los tres análisis y arma el
documento en una sola orden (unos 35 segundos):

```stata
do "Boletín 3/master_boletin3.do"
```

Los interruptores del principio de ese do-file eligen qué etapas correr.

Para usar solo este generador:

```bash
# 1. Documento con las salidas de Stata que ya están en el Drive
python3 generar_boletin.py

# 2. Correr primero el análisis en Stata y después armar el documento
python3 generar_boletin.py --correr-stata analisis

# 3. Revisar solo las cifras que entrarían en el texto (no escribe el .docx)
python3 generar_boletin.py --solo-indicadores
```

### Desde Spyder

Spyder trae su propio intérprete (`spyder-runtime`), que no tiene `openpyxl` ni
`python-docx` —ni `pip`—, así que `%runfile` fallaba con «Falta python-docx».

El generador ahora se da cuenta y **se relanza solo** con el python de `.venv`,
así que `%runfile` funciona sin configurar nada. Al hacerlo avisa:

```
Las librerias no estan en …/spyder-runtime/bin/python.
Se reintenta con el entorno del proyecto: …/.venv/bin/python
```

Como el script termina con `SystemExit`, Spyder puede mostrar «An exception has
occurred» *después* de haber generado el documento: si arriba aparece
«Documento generado: …», salió bien.

Para evitar ese rodeo, conviene apuntar Spyder al entorno del proyecto en
**Preferencias → Intérprete de Python → Usar el siguiente intérprete**, con la
ruta `.venv/bin/python` de esta carpeta. Es un ajuste de una sola vez.

No conviene instalar las librerías dentro de `spyder-runtime`: es el entorno
interno de la aplicación, se comparte con todos los proyectos y Spyder puede
rehacerlo en una actualización.

Opciones útiles:

| Opción | Para qué sirve |
| --- | --- |
| `--correr-stata {no,diseno,merge,analisis,ic,pobreza,homicidios,graficos,todo}` | Ejecuta los do-files antes de armar el documento. `graficos` corre los tres análisis que producen figuras. |
| `--salida RUTA` | Cambia el `.docx` de salida. |
| `--contenido RUTA` | Usa otro archivo de texto (por ejemplo, una versión en edición). |
| `--solo-indicadores` | Lista todas las expresiones del texto con su valor. |
| `--estricto` | Devuelve código de error si falta alguna imagen o serie. |

Cada corrida deja, junto al `.docx`, un `…_indicadores.json` con todas las
cifras que se insertaron en el texto y de dónde salieron. Sirve para revisar el
boletín sin abrir Stata.

## Archivos

```
configuracion.py                   rutas, gráficos, tablas, equipo y formato
                                   (tipografía: Times New Roman 12, interlineado 1.15)
contenido/boletin3.md              el texto del boletín (esto es lo que se edita)
generar_boletin.py                 script principal
boletin/datos.py                   lectura de los .xlsx que exporta Stata
boletin/indicadores.py             evaluación de las expresiones {{ }}
boletin/tablas.py                  armado de las tablas provincia / rama
boletin/documento.py               construcción del .docx
boletin/stata.py                   ejecución de los do-files en modo batch
herramientas/extraer_figuras_docx.py   copia figuras de un boletín ya redactado
```

## Cómo se escribe el contenido

`contenido/boletin3.md` es texto plano con unas pocas marcas:

```
# Título del boletín
## Sección
### Subtítulo
Texto normal. Las líneas seguidas forman un mismo párrafo.
- Viñeta
> **Cuadro 1. Título**        recuadro (las líneas que siguen van adentro)
> Texto del recuadro.
[[grafico: area]]             gráfico definido en configuracion.GRAFICOS
[[tabla: provincia]]          tabla definida en configuracion.TABLAS
[[equipo]]                    tabla con el equipo del boletín
[[salto]]                     salto de página
% comentario (no se imprime)
```

Se admite `**negrita**` y `*cursiva*`.

Los gráficos y las tablas **se numeran solos** según el orden en que aparecen.
Para citarlos en el texto se usa `{{G.area}}` → «Gráfico 3» y
`{{T.provincia}}` → «Tabla 1»; si se mueve un gráfico de lugar, todas las
referencias se renumeran.

### Las cifras: expresiones `{{ }}`

Dentro de `{{ }}` se escribe una expresión sobre las series que salen de los
Excel de Stata (los nombres se definen en `configuracion.FUENTES`):

```
{{ultimo}}                                   último año del boletín (2025)
{{inf[-1]}}                                  informalidad del último año
{{inf[2014]}}                                informalidad de 2014
{{inf_area[-1,'Rural']}}                     último año, área rural
{{inf_area[-1,'Rural'] - inf_area[-1,'Urbana']}}   brecha en puntos
{{inf[-1]|0}}                                sin decimales ( |2 para dos )
```

Series de informalidad: `inf`, `inf_sin_ruc`, `no_adec`, `no_remun`, `no_iess`,
`no_ruc`, `cond1`…`cond4`, `inf_area`, `inf_sexo`, `inf_edad`, `inf_etnia`,
`inf_educ`, `inf_decil`, `inf_prov`, `inf_rama` y los componentes por área y
por sexo (`no_adec_sexo`, `no_remun_area`, …).

Series de pobreza laboral (las produce `2. Pobreza laboral/corregido`):

| Serie | Qué es | Grupos |
| --- | --- | --- |
| `pob` | pobreza laboral nacional | – |
| `pob_area` | por área | `Urbana`, `Rural` |
| `pob_educ` | por nivel educativo | `Sin educación superior`, `Con educación superior` |
| `pob_sexo` | por sexo | `Hombre`, `Mujer` |
| `pob_edad` | por grupo de edad | `18-29`, `30-64`, `65+` |
| `pob_horas` | reparto de los ocupados pobres por horas (suma 100) | `40 horas o más`, `Menos de 40 horas, desea y puede trabajar más`, `Menos de 40 horas, no desea o no puede trabajar más` |
| `pob_comp_educ` | reparto de los ocupados pobres por educación (suma 100) | igual que `pob_educ` |

Los nombres de los grupos son las etiquetas de valor que fija
`02_indicadores.do`. Si cambian allí, hay que cambiarlos en
`configuracion.FUENTES` y en el contenido.

`pob_horas` empieza en 2007: las preguntas p25/p27/p28 no existen antes.

Funciones de ayuda:

| Función | Devuelve |
| --- | --- |
| `maximo(serie, desde=, hasta=, excluir=, grupo=)` | valor máximo de la serie |
| `minimo(...)` | valor mínimo |
| `anio_maximo(...)` / `anio_minimo(...)` | el año en que ocurre |
| `promedio(serie, desde, hasta, grupo)` | promedio del periodo |
| `rango(serie, anio, desde=)` + `ordinal(n)` | «el **tercer** valor más alto» |
| `ranking(serie, anio, asc=, minimo_casos=)` | `[(grupo, valor), …]` ordenado |
| `mayor(serie, anio)` / `menor(serie, anio)` | el grupo más alto / más bajo |
| `lista(items)` | «Pastaza (96.6%), Napo (95.1%) y Orellana (94.8%)» |
| `ult(serie)` | último año **de esa serie** (p. ej. etnia llega a 2024) |
| `veces(a, b)` | cociente entre dos valores |

Si una expresión pide un dato que no existe, el generador se detiene con un
mensaje que dice qué serie, qué año y qué grupo faltan.

## De dónde sale cada gráfico

| # | Gráfico | Origen |
| --- | --- | --- |
| 1 | Informalidad y componentes | `Graficos/Informalidad_y_componentes.png` |
| 2 | Número de condiciones | `Graficos/n_condiciones_informalidad.png` |
| 3 | Por área | `informal2_area.png` |
| 4 | Por género | `Graficos/informal2_sexo.png` |
| 5 | Por edad | `informal2_edad.png` |
| 6 | Por etnia | `Graficos/informal2_etnia.png` |
| 7 | Por educación | `Graficos/informal2_educ.png` |
| 8 | Por deciles | `Graficos/informal2_decil.png` |
| 9 | Pobreza laboral nacional | `pobreza laboral/corregido/g09_…png` |
| 10 | Pobreza laboral por área | `pobreza laboral/corregido/g10_…png` |
| 11 | Pobreza laboral por educación | `pobreza laboral/corregido/g11_…png` |
| 12 | Homicidios de NNA | `recursos_boletin/fig_12.png` |

Los gráficos 1 a 8 salen de `analisis_descriptivo.do` y los 9 a 11 de
`2. Pobreza laboral/corregido/02_indicadores.do`.

El **Gráfico 12 todavía se copia del boletín ya redactado**, porque
`3. homicidios_nna/graficos_homicidios_nna.do` lee dos `.csv`
(`datos_homicidios_nna.csv` y `datos_homicidios_jovenes.csv`) que no están en el
repositorio. El do-file ya exporta el `.png` a la resolución correcta y
`configuracion.GRAFICOS` ya lo busca primero: en cuanto aparezcan esos `.csv`,
el gráfico 12 se genera solo. Mientras tanto, la figura de respaldo se obtiene
con:

```bash
python3 herramientas/extraer_figuras_docx.py "…/5. Redacción/Boletin_3_v5.docx"
```

Si falta un `.png`, el documento se genera igual y deja un recuadro
«[FALTA LA IMAGEN] …» en su lugar, además de avisarlo en la consola.

## Resolución de los gráficos

Los gráficos entran a 15.6 cm de ancho, así que necesitan al menos ~2000 px de
ancho para no verse borrosos. **Stata exporta a la resolución de la pantalla
cuando el `graph export` no lleva `width()`**: en modo batch (`-b`, que es como
los corre `--correr-stata`) eso da 720x432 px, o sea 117 dpi. Por eso todos los
`graph export … .png` de `analisis_descriptivo.do` llevan `width(3000)`
—equivalen a unos 490 dpi— salvo los tres paneles, que ya usaban
`height(1900)`.

El generador mide cada imagen antes de insertarla y avisa si queda por debajo
de `dpi_minimo` (200 por omisión, en `configuracion.DOCUMENTO`), indicando qué
`width()` hace falta. **La resolución se arregla en el `.do`, no en el
generador**: agrandar la imagen desde Python solo interpola píxeles.

## Advertencias sobre los datos

- **La carpeta de resultados** es `informalidad`. El global `$out_results` de
  `analisis_descriptivo.do` y de `analisis_descriptivo_ic.do` apuntaba a
  `informalidad2`, de modo que el análisis escribía en una carpeta y el
  generador leía otra; ya está corregido en ambos. `CARPETAS_RESULTADOS` sigue
  probando los dos nombres por si quedan copias viejas.

- **Los gráficos ya no llevan intervalos de confianza.** Se quitaron las capas
  `rarea` de los cinco gráficos desagregados de `analisis_descriptivo.do`
  (área, género, edad, etnia y educación) y se renumeraron sus leyendas, que
  apuntaban a la posición de las capas. Los archivos perdieron el sufijo `_IC`;
  las versiones viejas con ese nombre siguen en el Drive y se pueden borrar.
  El cálculo de `ub_`/`lb_` sigue en el .do por si se quieren volver a dibujar,
  igual que la constante `NOTA_IC` de `configuracion.py`.

- **La serie por etnia termina en 2024.** `analisis_descriptivo.do` filtra
  `keep if anio >= 2003 & anio <= 2024` en ese bloque, mientras el resto del
  boletín llega a 2025. Por eso el texto usa `{{ult(inf_etnia)}}` y no
  `{{ultimo}}`. Si se decide extenderla, hay que corregir el filtro en el .do.
- **La Tabla 2 filtra las ramas con más del 1% de casos** en el último año
  (`umbral_casos` en `configuracion.TABLAS`). La versión v5 del boletín
  incluía algunas ramas por debajo de ese umbral y omitía comercio; la tabla
  generada aplica el criterio de manera uniforme.
- Las cifras de **pobreza laboral** ya se calculan (series `pob*`). Siguen
  escritas a mano las de **homicidios** y el dato de mujeres que no desean
  trabajar más horas por tareas de cuidado.

- **`analisis_descriptivo_ic.do` exige la armonización**: necesita
  `estrato_svy` y `upm_svy`, que crean `diseno_muestral.do` y
  `merge_informal.do`. No produce ninguna de las 12 figuras del boletín, así que
  no entra en la etapa `graficos` ni en la corrida por omisión del master.

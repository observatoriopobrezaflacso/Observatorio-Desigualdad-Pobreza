# Boletín 3 — Informalidad, pobreza laboral y homicidios de NNA

## Correr todo

```stata
do "master_boletin3.do"
```

Corre los tres análisis que producen los gráficos y, al final, llama al
generador para armar el Word. Unos 35 segundos. Se puede ejecutar desde
cualquier directorio: el master se ubica solo según el usuario de la máquina.

Desde la terminal:

```bash
/Applications/StataNow/StataSE.app/Contents/MacOS/stata-se -b do master_boletin3.do
```

Deja una bitácora `logs/master_boletin3_<fecha>_<hora>.log`, con la salida de
Stata y la del generador de Python.

La primera vez hay que crear el entorno de Python del generador:

```bash
cd "4. Boletin automatizado"
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Si falta, el master lo dice con las tres órdenes exactas y no intenta armar el
documento.

## Qué corre y qué no

Los interruptores están al principio del do-file:

```stata
local hacer_armonizacion 0
local hacer_informalidad 1
local hacer_ic           0
local hacer_pobreza      1
local hacer_homicidios   1
local hacer_word         1
```

Poner `hacer_word 0` corre solo los gráficos; poner todas las etapas de Stata en
0 arma el documento con las salidas que ya estén.

## Etapas

| Etapa | Do-files | Produce | Por omisión |
| --- | --- | --- | --- |
| `armonizacion` | `diseno_muestral.do`, `merge_informal.do` | las bases armonizadas | no |
| `informalidad` | `analisis_descriptivo.do` | Gráficos 1–8, Tablas 1–2 | sí |
| `ic` | `analisis_descriptivo_ic.do` | gráficos con intervalos de confianza (no van al boletín) | no |
| `pobreza` | `2. Pobreza laboral/corregido/run_all.do` | Gráficos 9–11 y las series del texto | sí |
| `homicidios` | `3. homicidios_nna/graficos_homicidios_nna.do` | Gráfico 12 | sí (opcional) |
| `word` | `generar_boletin.py` (lo llama el master) | `5. Redacción/Boletin_3_automatizado.docx` | sí |

`armonizacion` no entra por omisión porque es la parte lenta y sus salidas
cambian poco. `ic` tampoco: necesita `estrato_svy` y `upm_svy`, que crea la
armonización, y no produce ninguna de las 12 figuras del boletín.

`homicidios` e `ic` están declaradas opcionales (`local opcionales`): si fallan,
el master lo avisa y continúa. Si falla una obligatoria, se omiten los do-files
que quedan de **esa misma etapa** —dependen del que falló— y las demás etapas
siguen su curso. El resumen final lista lo completado y lo fallido.

## Estado de la automatización

| Sección | Gráficos | Cifras del texto |
| --- | --- | --- |
| Informalidad | se generan | se calculan |
| Pobreza laboral | se generan | se calculan |
| Homicidios de NNA | **figura copiada del boletín v5** | **escritas a mano** |

La sección de homicidios no está automatizada porque
`graficos_homicidios_nna.do` lee `datos_homicidios_nna.csv` y
`datos_homicidios_jovenes.csv`, que no están en el repositorio. El do-file ya
está listo (rutas portables y exportación `.png` a 3000 px) y el generador ya
busca ese `.png` antes que el respaldo: en cuanto aparezcan los `.csv`, el
Gráfico 12 se genera solo. Las cifras del párrafo de homicidios seguirían
escritas a mano hasta definir de qué archivo leerlas.

## Dónde queda cada cosa

```
4. Resultados/informalidad/              Gráficos 1-8, Tablas 1-2
4. Resultados/pobreza laboral/corregido/ Gráficos 9-11 y series de pobreza
4. Resultados/homicidios infantiles/     Gráfico 12 (cuando haya datos)
5. Redacción/Boletin_3_automatizado.docx           el documento
5. Redacción/Boletin_3_automatizado_indicadores.json  todas las cifras del texto
logs/                                    logs de Stata y del master
```

## Documentación por sección

- Generador del Word y lenguaje de las expresiones `{{ }}`:
  `4. Boletin automatizado/README.md`
- Pobreza laboral, correcciones y su master:
  `2. Pobreza laboral/corregido/README.md`

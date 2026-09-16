# Pobreza laboral — versión corregida

Reescritura de `evolucion_pobreza_laboral.do` y `evolucion_pobreza_laboral_ocupados.do`
con los errores corregidos y con una medición del efecto de cada uno sobre los
resultados publicados en `Boletin_3_automatizado.docx`.

Nada de lo publicado se sobrescribe: las salidas van a
`Boletín 3/4. Resultados/pobreza laboral/corregido/`.

## Scripts

| Archivo | Qué hace |
|---|---|
| `run_all.do` | **Master: corre toda la cadena en orden** |
| `00_config.do` | Rutas según el usuario de la máquina (ya no fija `/Users/vero`) |
| `01_panel.do` | Arma el panel 2001-2025. Guarda insumos corregidos (`_ok`) y réplica del original (`_orig`) |
| `02_indicadores.do` | Series corregidas + Gráficos 9, 10 y 11 |
| `03_impacto.do` | Reintroduce un error a la vez y mide su efecto |
| `04_descriptivos.do` | Versión corregida del fragmento suelto `descriptivos?texto` |
| `05_validacion.do` | Comprueba que la réplica reproduce exactamente lo publicado |

### Cómo correrlo

```stata
do "run_all.do"
```

El master se ubica solo, así que puede ejecutarse desde cualquier directorio.
Corre las etapas en el orden `01` → `05` → `02` → `03` → `04`, mide cuánto tarda
cada una y deja una bitácora `run_all_<fecha>_<hora>.log` en esta carpeta.
La corrida completa toma unos 15 segundos.

Si una etapa falla, la cadena se detiene ahí y el resumen final indica cuál fue:
las etapas posteriores dependen de las anteriores, así que no tiene sentido
seguir. Para repetir solo una parte, ponga en 0 los interruptores `hacer_XX` del
encabezado del master (por ejemplo `hacer_01 0` para no reconstruir el panel).

Dependencias: `05`, `02` y `03` necesitan el panel que produce `01`; `03` y `04`
necesitan además el panel final que produce `02`.

## Validación de la línea base

`05_validacion.do` reproduce los archivos publicados del 16-jun con exactitud de
5 decimales en los 22 años, en las tres series (nacional, ocupados, área). Por eso
las diferencias reportadas abajo son atribuibles a las correcciones y no a
diferencias de reconstrucción.

## Efecto de cada error

Medido sobre la serie de pobreza laboral (ocupados), en puntos porcentuales.

| # | Error | Efecto |
|---|---|---|
| 1 | `scope` nunca se definía (8 usos) | **0.00 pp.** Solo metadatos: `cobertura_pobreza` salió vacía en los 6 xlsx publicados y los `.dta` quedaron con doble guion bajo (`ing_perca_2001__precios2000.dta`) |
| 2 | 2018 se quedaba sin `condactn` (el parche empezaba en 2019) | **+5.00 pp en 2018** (23.24 publicado vs 18.24 correcto). Área: +5.07 urbana, +6.23 rural. Educación: +3.20 sin superior, +1.40 con superior |
| 3 | `!inlist()` / `!inrange()` clasificaban los valores perdidos como ocupados | **+0.26 pp en 2001** (código 9, "indeterminados"). Cero en los demás años |
| 4 | `historico.dta` se guardaba antes del parche de `condactn` y del filtro de horas | No altera los xlsx, pero el `.dta` distribuido no contenía las correcciones |
| 5 | `drop if p24 == 999` aplicado a toda la base | **≤0.004 pp.** Solo 6 observaciones en toda la serie (2001: 1, 2003: 3, 2007: 2) |
| 6 | Los dos scripts escribían en los mismos archivos | **−2.5 a −6.2 pp.** Lo publicado como `pobreza_laboral.xlsx` es la variante *ocupados*; la variante *ing_lab* da 12.85% en 2025 frente a 16.94% |
| 7 | `educacion_superior` excluía "superior no universitaria" desde 2003, pero la incluía en 2001 | **−0.19 a −0.85 pp** (sin superior) y **−0.03 a −0.77 pp** (con superior). Afecta 0.5% de los casos en 2003 y 3.0% en 2025 |
| 8 | `xlabel(2001(2)2023)` en el primer gráfico | Cosmético: faltaban las etiquetas 2024-2025 |
| 9 | `p24 >= 40` contaba los valores perdidos como "40 horas o más" | **0.00 pp sobre la cifra publicada**, porque ningún ocupado pobre de 2025 tiene horas perdidas. Latente: sobre el total de pobres el grupo pasaría de 437 a 2,891 casos |

### El error 2: qué ocurría en 2018

De 2018 en adelante las bases traen `condact` (con la clasificación nueva) y ya no
`condactn`. El código leía `condactn`, que para 2018 quedaba íntegramente perdida,
y `!inlist(., 0, 7, 8, 9)` devuelve 1. Resultado: el 100% de la base contaba como
ocupada.

|  | Original | Corregido |
|---|---|---|
| Observaciones | 59,350 | 28,197 |
| Población | 17,223,542 | 7,731,032 |

Entre los "ocupados" de 2018 del código original había 14,687 menores de 15 años y
15,406 inactivos. Por eso la pobreza laboral de 2018 publicada (23.2416) coincide
dígito a dígito con la pobreza total de ese año.

El parche `replace condactn = condact if inrange(anio, 2019, 2025)` resolvía
2019-2025 pero dejaba 2018 fuera.

## Efecto sobre las cifras del boletín

| Afirmación publicada | Publicado | Corregido |
|---|---|---|
| Pobreza laboral 2001 (§ Gráfico 9) | 52.8% | 52.5% |
| Pobreza laboral 2017 | 16.8% | 16.8% |
| Pobreza laboral 2020 | 26% | 26.2% |
| Pobreza laboral 2025 | 16.9% | 16.9% |
| Ocupados pobres con 40h o más, 2025 | 33.8% | 33.9% |
| Ocupados pobres <40h que desean y pueden más | 22.5% | 22.5% |
| Rural / urbano 2001 | 71.2% / 40.7% | 71.2% / 40.2% |
| Rural / urbano 2017 | 33.7% / 8.6% | 33.7% / 8.6% |
| Rural / urbano 2025 | 30.7% / 9.5% | 30.7% / 9.5% |
| Educación 2025 (sin / con superior) | 19.8% / 2.2% | 20.5% / 2.5% |
| Brecha educativa 2025 | 17.6 pp | 18.0 pp |
| Sin educación superior entre ocupados pobres 2025 | 97.8% | 97.1% |

Las cifras citadas en el texto se sostienen: ninguna cambia lo suficiente como para
alterar una conclusión. El problema está en los **Gráficos 9, 10 y 11**, donde 2018
aparece con un pico que no existe: en el Gráfico 9 la serie sube de 16.8% (2017) a
23.2% (2018) y vuelve a 19.9% (2019), cuando el valor real de 2018 es 18.2%.

## Decisiones tomadas

- **`educacion_superior`**: se adopta la definición amplia (incluye superior no
  universitaria), que es la única comparable con el código 6 de `nivinst` en 2001.
  Si se prefiere "universitaria" en sentido estricto, hay que cambiar también 2001,
  no solo 2003 en adelante.
- **`p24 == 999`**: pasa a tratarse como valor perdido en la variable `horas`, en
  lugar de eliminar la observación del cálculo de pobreza.
- **Población de referencia**: se generan las tres (`total`, `ocupados`, `inglab`)
  con nombres de archivo distintos. El boletín usa `ocupados`.

## Codificación verificada de la condición de actividad

| Años | Variable | Clasificación | Ocupado |
|---|---|---|---|
| 2001-2005 | `condact` | antigua | 0-4 |
| 2007-2013 | `CONDACT` + `CONDACTN` (mayúsculas) | ambas | `CONDACTN` 1-6 |
| 2014-2015 | `condact` + `condactn` | ambas | `condactn` 1-6 |
| 2016-2017 | `condactn` | nueva | 1-6 |
| 2018-2025 | `condact` | **nueva** | 1-6 |

En 2001 el código 9 es "indeterminados" y no debe contarse como ocupado;
`!inrange(condact, 5, 8)` lo contaba.

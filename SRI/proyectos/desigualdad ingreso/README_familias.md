# Familias en cedulados: base falsa e identificadores de familia

**Código:** `SRI/proyectos/desigualdad ingreso/` (este repo).
**Datos:** `G:/Mi unidad/Trabajos/Predoc/data/fake_data/` (fuera del repo — el
`.gitignore` excluye `*.dta`).

Corre todo con `do master_familias.do`. Los dos globales que importan están al
inicio de ese archivo: `$codigo` (aquí) y `$fake` (la unidad compartida).

| paso | archivo | qué hace | ~tiempo |
|---|---|---|---|
| 1 | `make_cedulados_fake.do` | base falsa de `cedulados_full.dta`, 23 variables, desde el yaml | 20 s |
| 2 | `build_familias.do` | identificadores de familia nuclear y extendida | ~10 min |
| 3 | `validate_familias.do` | verifica los identificadores contra la genealogía simulada | 1 min |
| 4 | `analisis_concentracion_familia.do` | concentración de riqueza por familia | 1 min |

Los logs (`*.log`) quedan junto al código y contienen todos los diagnósticos:
el achieved-vs-yaml del paso 1, los tamaños de familia y la tabla de cobertura
de parentesco del paso 2, y los checks del paso 3.
## 1. La base falsa

`Bases/Bases INEC/Cedulados/dta/cedulados_full.dta` — 23 variables, en el orden,
con las etiquetas y los formatos del yaml
`data/descriptives/cedulados_full.yaml`. ~283.000 personas (el original tiene
21.757.803; sube `nfound` en el paso 1 para escalar).

**Por qué no es un sorteo marginal.** `cedulados` es un archivo *relacional*:
`cod_inec_ci_padre`, `cod_inec_ci_madre` y `cod_inec_ci_conyugue` apuntan a otras
filas del mismo archivo. Sortear esas tres columnas independientemente de sus
marginales — que es todo lo que el yaml por sí solo permite — da un archivo donde
no se puede reconstruir ni una familia: cada "padre" es un número aleatorio que o
no existe o es más joven que el hijo.

Entonces el esqueleto es una **genealogía simulada hacia adelante** (matrimonio
asortativo por edad, fecundidad por edad de la madre, uniones seriales, seis
generaciones), y encima se imponen las marginales del yaml **censurando** los
punteros (0 = "sin pariente en el archivo") hasta que la proporción de ceros y de
missing coincide. Dos bloques:

- **bloque 1** — ancestría profunda: 6.000 fundadores nacidos 1888-1920, cinco
  rondas de reproducción → seis generaciones. Es lo que hace que existan abuelos,
  bisabuelos, primos y dinastías.
- **bloque 2** — ancestría corta: 78.000 fundadores nacidos 1958-1995, dos rondas
  → tres generaciones, sin ancestros más viejos en ninguna parte. Es la masa del
  registro real (gente cuyos padres nunca tuvieron cédula) y además empuja la
  distribución de `yob` hacia la forma joven que muestra el yaml.

**Ajuste al yaml** (ver el final de `make_cedulados_fake.log`): los doce
`missing_prop` quedan dentro de 0,003 del objetivo; `yob` con media 1984,1 vs
1984,6 y sd 25,87 vs 25,87; los cuantiles de `yob` dentro de un año en p5-p99;
`cod_inec_ci_actual` único, en el rango real, con la cola en 8,8e9;
`cod_estado_civil` y `cod_instruccion` a sus probabilidades exactas;
`cod_condicion_cedulado` a las 76 categorías del yaml verbatim.
La única desviación material es `p1(yob) = 1902` contra 1913 del yaml: una
simulación hacia adelante de este tamaño necesita más fundadores viejos que los
que la cola real tiene.

**Patologías plantadas a propósito** (P01-P17, listadas en la cabecera del do).
Cada una existe en el archivo real y cada una ejercita una rama del paso 2:
punteros colgantes, auto-paternidad, padres más jóvenes que el hijo, "padre"
marcado mujer, cónyuges no recíprocos, auto-cónyuge, parejas del mismo sexo, una
persona declarada cónyuge por varias, ciclos padre-hijo, cédulas anómalas en
8,8e9, padres con hijos de varias parejas, `yob` hasta 1800, fechas fuera de
orden, generaciones intermedias censuradas.

`_cedulados_truth.dta` guarda la genealogía verdadera antes de censurar. **No es
parte de la base sintética**: sólo lo usa el paso 3.

---

## 2. Los identificadores de familia

`Bases/Bases INEC/Cedulados/dta/cedulados_familias.dta` — una fila por persona,
`merge 1:1` contra `cedulados_full.dta` y `merge m:1` contra los archivos del SRI
por cédula.

### `id_fam_nuclear` — familia nuclear (partición estricta)

Una pareja de progenitores (o un progenitor solo) más sus hijos. La regla pedida
se aplica literalmente: **una persona deja de ser hijo en el momento en que tiene
un hijo propio**. Un padre nunca queda contado dentro de la familia de sus
propios padres.

Orden de asignación:

1. si la persona es progenitor → encabeza su **unión reproductiva primaria**;
2. si no, pertenece a la unión en la que nació;
3. si no, a su unión conyugal;
4. si no, es una familia de una persona.

`rol_nuclear`: 1 progenitor, 2 hijo/a, 3 cónyuge sin hijos, 4 persona sola.

Una persona puede encabezar varias uniones (uniones seriales). Como la familia
nuclear tiene que ser una partición, se elige una **unión primaria**: la unión
cuyo co-progenitor es el cónyuge declarado; si no, la de más hijos; si no, la del
hijo más reciente; si no, la de menor `id_union`.

### `id_fam_nuclear2` — la regla alternativa

Igual, pero **el matrimonio también emancipa** (pasos 2 y 3 invertidos). Bajo la
regla literal una pareja casada sin hijos queda partida en dos familias, cada
cónyuge con sus propios padres, y eso sesga cualquier estadística de riqueza por
familia. Se entregan las dos para que la elección sea explícita y comparable.

### `id_fam_extendida` y `id_fam_extendida2` — familia extendida (particiones estrictas)

Generaciones consecutivas de familias **nucleares** a lo largo del linaje
registrado. Ancladas en las familias nucleares cuyos jefes no tienen padres en el
archivo (la cima del linaje registrado) y cortadas cada `B` generaciones más
abajo. La línea que se sigue es **la de los dos ancestros del jefe que llega más
profundo en el archivo**, no siempre la paterna, para aprovechar la más rica de
las dos; la otra queda en `nf_up2`.

Una familia nuclear ya contiene una pareja **y** sus hijos, así que el número de
generaciones de *personas* es una más que el de familias nucleares:

| variable | bloque | generaciones de personas | lectura |
|---|---|---|---|
| `id_fam_extendida` | `$PROF_EXT = 3` familias nucleares | 4 | más amplia; conserva muchos más pares abuelo-nieto observados |
| `id_fam_extendida2` | 2 familias nucleares | 3 | abuelos + hijos y yernos/nueras + nietos: la lectura **estricta** de "segundo grado" en el eje vertical |

Las dos son particiones estrictas y las dos son agrupaciones más gruesas de
`id_fam_nuclear`. Cuál usar es una decisión empírica, y el paso 2 imprime la
tabla para tomarla (ver "Tabla de cobertura" abajo).

> **Por qué hace falta un corte.** "Todos los que están a dos grados de mí" es un
> conjunto **ego-céntrico**, y los conjuntos ego-céntricos se solapan: el círculo
> de segundo grado de mi hermano no es el mío. No existe ninguna partición cuyos
> grupos sean exactamente "todos los pares dentro de dos grados" — mi tío está a
> tres grados de mí pero a uno de mi padre. Cualquier variable de agrupación
> tiene que elegir. Por eso se entregan varios objetos:
>
> - `id_fam_extendida` / `id_fam_extendida2` son las **particiones**, para
>   totales por familia, Gini y top shares (sin doble conteo);
> - `red_parentesco_g2.dta` es el objeto **exacto** de segundo grado, relación por
>   relación, para estadísticas ego-céntricas ("¿cuánta riqueza del 1% más rico
>   está dentro de su propia parentela de segundo grado?"), donde el solapamiento
>   no es problema;
> - `id_dinastia` es la alternativa **sin cota**.

En el bloque 2 de la base falsa (55% de la población) los linajes sólo tienen 2-3
niveles, así que el corte casi nunca se activa y la familia extendida es todo el
linaje registrado. En el bloque 1 (seis generaciones) se activa.

### Tabla de cobertura: cuánto parentesco real conserva cada agrupación

Al final de la sección 8, `build_familias.do` imprime, para **cada tipo de
vínculo de segundo grado efectivamente observado en el archivo**, qué proporción
de esos pares cae dentro de la misma familia nuclear, la misma familia extendida
(los dos tamaños de bloque) y la misma dinastía.

Es la tabla que hay que leer antes de elegir la unidad de análisis, y **no
necesita ninguna verdad simulada**, así que funciona igual sobre el registro
real. Ojo: la familia nuclear *debe* separar los vínculos abuelo-nieto — eso es
lo que la hace nuclear — así que un número bajo en la primera columna es el
comportamiento correcto, no un defecto.
### `id_dinastia` — componente conexa del grafo de parentesco

Componentes conexas del grafo con aristas padre-hijo **y** aristas de pareja, sin
cota. Es la "dinastía" del trabajo sobre riqueza dinástica. **No sustituye a la
familia extendida**: un solo matrimonio fusiona dos linajes para siempre, así que
las componentes crecen sin límite a medida que mejora la cobertura del registro.
El log del paso 2 imprime las diez componentes más grandes y qué porcentaje de la
población cubre la mayor — mírálo antes de usar esta variable como unidad de
análisis.

### `red_parentesco_g2.dta` — segundo grado de consanguinidad y afinidad

Lista de aristas ego-pariente con `grado` (0/1/2) y `via` (1 consanguinidad,
2 afinidad), contada como la cuenta el Código Civil:

| vía | grado | relaciones (`rel`) |
|---|---|---|
| consanguinidad | 1 | padre, madre, hijo/a |
| consanguinidad | 2 | abuelo/a, nieto/a, hermano/a pleno, hermano/a medio |
| afinidad | 0 | cónyuge |
| afinidad | 1 | suegro/a, padrastro/madrastra, hijastro/a, yerno/nuera |
| afinidad | 2 | cuñado/a por el cónyuge, cuñado/a por el hermano, abuelo/a afín, nieto/a afín, cónyuge del nieto/a |

`primaria = 1` marca el vínculo más cercano de cada par ego-pariente, para que un
par que califica por dos vías no se cuente dos veces.

Los conteos por ego se pegan al archivo de personas: `k_padres`, `k_hijos`,
`k_abuelos`, `k_nietos`, `k_herm`, `k_hermc`, `k_conyuge`, `k_suegros`,
`k_hijast`, `k_yernos`, `k_cunados`, `k_otros_af`, y los agregados `n_g2_cons`,
`n_g2_afin`, `n_g2_g1`, `n_g2_g2`, `n_g2_total`.

### Datos sucios: se manejan, no se suponen inexistentes

Cada puntero se valida antes de usarse y cada rechazo queda como bandera `f_*`,
para poder ver cuánto de la estructura familiar descansa en registros dudosos:

| situación | qué se hace |
|---|---|
| puntero 0 o missing | sin pariente en el archivo |
| puntero = cédula propia | rechazado (`f_*_self`) |
| puntero a una cédula que no existe | rechazado (`f_*_inexist`) |
| progenitor menos de `$BRECHA_MIN = 12` años mayor | rechazado (`f_*_edad`) — esto además mata los ciclos padre-hijo: dos personas no pueden ser cada una doce años mayor que la otra |
| "padre" marcado mujer, "madre" marcada hombre | **se conserva**, con bandera. Un error de sexo no es evidencia de que la persona no sea progenitor, y botar el vínculo perdería una familia real |
| madre muerta antes del nacimiento del hijo | se conserva, con bandera |
| la misma cédula en el campo padre y en el de madre | se conserva como padre |
| varias personas declaran el mismo cónyuge | se resuelve a un *matching* para que la unión conyugal siga siendo una partición; los perdedores quedan con bandera |

### Otras variables del archivo de personas

`n_hijos`, `es_progenitor`, `gen_lin` (generación en el linaje registrado, 0 = sin
padres en el archivo), `f_ciclo`, `id_union_origen`, `id_union_rep`,
`id_union_cony`, `nf_tam`, `nf_n_padres`, `nf_n_hijos`, `nf_n_vivos`,
`nf_biparental` (y sus versiones `nf2_*`), `nf_padre`, `fe_tam`, `fe_n_fam`, `fe_n_gen`,
`fe_n_vivos`, `nf_prof`, `din_tam`, `din_n_fam`, `vivo_ref`, y los punteros
validados `ci_padre_val`, `ci_madre_val`, `ci_conyuge_val`.

Archivos a nivel de familia: `familias_nucleares.dta` y
`familias_extendidas.dta`.

---

## 3. Validación

`validate_familias.do` hace tres cosas distintas y conviene no confundirlas:

- **A. Consistencia interna** — propiedades que los identificadores tienen que
  cumplir sí o sí: partición, anidamiento (nuclear ⊂ extendida ⊂ dinastía), la
  regla de emancipación, simetría de la red (padre/hijo y abuelo/nieto son
  reversos exactos; hermanos y cónyuges son simétricos; nadie tiene más de dos
  padres ni más de cuatro abuelos). **Un `[FAIL]` acá es un bug.**
- **B. Recuperación contra la verdad** — cuánto de la estructura verdadera
  sobrevive al 35% de vínculos paternos censurados: vínculos recuperados,
  progenitores no detectados, `gen_lin` vs `gen_true`, y *recall* y *precisión*
  sobre pares de hermanos verdaderos. **Un número bajo acá no es un bug, es la
  censura** — y es exactamente el número a mirar para decidir si el análisis real
  es viable.
- **C. Patologías** — cada error plantado tiene que haber sido atrapado.

---

## 4. Concentración de riqueza por familia

`analisis_concentracion_familia.do` es la contraparte por familia del análisis
individual del final de
`h:/Mi unidad/SRI/Envíos/27.08.2026/construccion_ingreso_DINA.do`, donde la
distribución se toma sobre `CEDULA_PK`.

**Dos convenciones, las dos reportadas, porque contestan preguntas distintas:**

- **`por familia`** — una fila por familia, peso 1. La distribución es sobre
  familias: "el 1% más rico de las familias tiene x% de la riqueza". Es la
  afirmación natural a nivel de familia y **no** es comparable con el número
  individual, porque una familia rica suele ser una familia grande.
- **`equal-split`** — una fila por familia, peso = número de adultos vivos, y la
  riqueza dividida en partes iguales entre ellos. La distribución es sobre
  **personas** y **sí** es directamente comparable con el número individual,
  porque la población detrás es la misma. Es la convención DINA.

Comparar `individuo / por persona` contra `familia * / equal-split` aísla cuánta
de la desigualdad individual medida es desigualdad **entre** familias y no dentro
de ellas.

Como el yaml de cedulados no trae ingreso, por defecto (`FUENTE = "sim"`) se
simula una variable de riqueza con cola de Pareto **y correlación intrafamiliar**
(`RHO_FAM`, el efecto familia se pega a la familia extendida). Esto último es el
punto: si la riqueza fuera independiente entre parientes, la concentración por
familia sería mecánicamente *menor* que la individual y el ejercicio no diría
nada.

**Para enchufar el SRI:** `FUENTE = "sri"`, `$dir_merged` apuntando a los
`ingreso_dina_YYYY.dta` que escribe `construccion_ingreso_DINA.do`, y `$xwalk`
con un archivo que tenga `CEDULA_PK` y `cod_inec_ci_actual`. Nada más cambia.

Salidas en `Investigadores/Santiago/Outputs/familias/`:
`concentracion_por_unidad.dta`, `top_familias.dta`, `kin_share_top.dta`.

---

## 5. Limitaciones conocidas

1. **Ninguna partición es exactamente "segundo grado".** El corte cada `B`
   generaciones es una decisión, no un teorema (ver arriba). Para la definición
   exacta usa `red_parentesco_g2.dta`; para robustez sin cota, `id_dinastia`; y
   para elegir entre las dos particiones, la tabla de cobertura del paso 2.
2. **Un progenitor con hijos de varias parejas encabeza una sola familia.** Sus
   hijos de las otras uniones quedan en la familia definida por su propia pareja
   de padres, encabezada por el otro progenitor. Es el precio de exigir una
   partición.
3. **La familia extendida sigue una sola línea a la vez** — la de los dos
   ancestros del jefe que llega más profundo en el archivo. Seguir las dos a la
   vez colapsa en la dinastía (una boda fusiona dos linajes para siempre), así
   que no hay manera de tener las dos y una partición. `nf_up2` guarda el otro
   linaje para armar la variante alternativa sin rehacer nada.
4. **`gen_lin` es una cota inferior de la generación verdadera.** Censurar un
   vínculo paterno hace que una persona parezca fundadora. El paso 3 cuantifica
   cuánto (en la base falsa: 98,0% exacto, correlación 0,979).
5. **`p1(yob) = 1902` vs 1913 del yaml** en la base falsa: una simulación hacia
   adelante de este tamaño necesita más fundadores viejos que los que tiene la
   cola real.
6. **Se sobreescribió `cedulados_full.dta`** en
   `G:/…/fake_data/Bases/Bases INEC/Cedulados/dta/`. La versión anterior de seis
   variables que escribía `make_fake_data.do` quedó respaldada como
   `cedulados_full_PREV_uni_fe.dta`. Las cédulas y `cod_lugar_nacimiento` siguen
   otra convención en la base nueva, así que
   `university_fe_graduation_horizon_TEST.do` necesita la base respaldada, o
   volver a correr `make_fake_data.do` (que la sobreescribiría otra vez).
7. **`id_dinastia` no sirve como unidad de análisis en esta base**: la componente
   más grande cubre ~57% de la población. Está ahí como chequeo de robustez y
   para medir cuánto parentesco queda fuera de las particiones acotadas.

---

## 6. Resultados de la corrida de referencia

Todo lo de abajo sale de los `.log` de esta carpeta.

**Paso 1, ajuste al yaml.** 282.824 personas. Los doce `missing_prop` dentro de
0,003 del objetivo. `yob`: media 1984,1 (yaml 1984,6), sd 25,87 (yaml 25,87),
cuantiles p5-p99 dentro de un año. Ceros en los punteros: padre 0,3495
(objetivo 0,350), madre 0,3199 (0,320), cónyuge 0,7619 (0,7614). Cédulas únicas
en el rango real, con la cola en 8,8e9.

**Paso 2, estructura recuperada.** 68,97% de las personas tienen al menos un
vínculo paterno utilizable; 123.172 progenitores; 115.259 uniones (86% con
hijos, 14% sólo conyugales); 115.390 familias nucleares (tamaño medio 2,45,
78% biparentales); 88.136 familias extendidas (tamaño medio 3,21, máx. 76);
3,74 millones de aristas de parentesco hasta segundo grado.

**Tabla de cobertura** — proporción de pares de parentesco *observados* que caen
en el mismo grupo:

| vínculo | fam. nuclear | fam. extendida | fam. ext. (2 gen) | dinastía |
|---|---|---|---|---|
| padre / madre / hijo | 0,58-0,60 | 0,67-0,72 | 0,68-0,73 | 1,00 |
| hermano/a pleno | 0,484 | 0,628 | 0,632 | 1,00 |
| hermano/a medio | 0,017 | 0,089 | 0,098 | 1,00 |
| abuelo/a — nieto/a | 0,000 | 0,186 | 0,209 | 1,00 |
| cónyuge | 0,723 | 0,740 | 0,740 | 1,00 |
| suegro/a — yerno/nuera | 0,000 | 0,194 | 0,192 | 1,00 |
| cuñado/a | 0,000 | 0,102 | 0,090 | 1,00 |
| **total** | **0,183** | **0,299** | **0,297** | **1,00** |
| sólo consanguinidad | 0,286 | 0,420 | 0,431 | 1,00 |

Lectura: la familia extendida **duplica** el parentesco retenido respecto de la
nuclear (0,183 → 0,299; en consanguinidad 0,286 → 0,420), pero el vínculo
vertical abuelo-nieto es el que ninguna partición conserva bien (0,19-0,21). Los
dos tamaños de bloque quedan casi empatados en el total: el de 3 generaciones
gana en afinidad, el de 2 en consanguinidad. **Si el vínculo abuelo-nieto es
central para la pregunta, la respuesta no es una partición: es
`red_parentesco_g2.dta` y la sección 4 del paso 4.**

**Paso 3, validación.** Los 33 chequeos de consistencia interna pasan, incluido
que el bloque nunca abarca más de `$PROF_EXT` generaciones de familias nucleares
(el span de `nf_prof` dentro de una familia extendida es 1, 2 o 3, nunca más).
Aparte: en 778 familias extendidas (0,88%) el span de `gen_lin` pasa de 4. Eso
**no** es un bloque que creció de más — `gen_lin` mide la profundidad de cada
persona en *su propio* linaje más profundo, que puede correr por la línea que el
bloque no sigue; son cónyuges que entraron por matrimonio desde un linaje más
profundo.

Contra la
verdad simulada: 85,0% de los vínculos paternos verdaderos y 88,6% de los
maternos se recuperan; sólo 2,7% de los progenitores verdaderos se pierden por
completo; la correlación del conteo de hijos es 0,972 y la de `gen_lin` con la
generación verdadera 0,979 (98,0% exacto). Pares de hermanos verdaderos que
quedan en la misma familia nuclear: 65,0% (*recall*); pares co-asignados que
realmente son hermanos: 99,7% (*precisión*). Contaminación por los errores
plantados indetectables (P05): 0,12% de los vínculos paternos sobrevivientes.

**Paso 4, concentración (riqueza simulada, `RHO_FAM = 0,45`).**

| unidad | ponderación | n | Gini | top 10% | top 1% | top 0,1% |
|---|---|---|---|---|---|---|
| individuo | por persona | 105.564 | 0,6166 | 0,4813 | 0,1400 | 0,0343 |
| familia nuclear | equal-split | 71.506 | 0,5976 | 0,4597 | 0,1330 | 0,0322 |
| familia nuclear | por familia | 71.506 | 0,6111 | 0,4661 | 0,1270 | 0,0294 |
| familia extendida | equal-split | 57.553 | 0,5648 | 0,4273 | 0,1171 | 0,0270 |
| familia extendida | por familia | 57.553 | 0,6421 | 0,5034 | 0,1470 | 0,0331 |
| fam. ext. (2 gen) | equal-split | 58.560 | 0,5620 | 0,4284 | 0,1223 | 0,0285 |
| dinastía | equal-split | 25.178 | 0,2758 | 0,2670 | 0,0843 | 0,0215 |
| dinastía | por familia | 25.178 | 0,8529 | 0,7953 | 0,6358 | 0,5825 |

Comparando `individuo / por persona` con `familia extendida / equal-split`, el
Gini baja de 0,617 a 0,565: **~8% de la desigualdad individual medida es
desigualdad dentro de familias extendidas, no entre ellas.** La fila de la
dinastía muestra por qué esa variable no sirve como unidad: con una componente
que cubre 57% de la población, el equal-split colapsa el Gini a 0,276 y el
per-familia lo infla a 0,853.

Y el estadístico que sólo la lista de aristas permite: **el 1% más rico junto con
su propia parentela de segundo grado son 11.927 personas (6,2% de los adultos) y
concentran 20,2% de la riqueza total**, contra 14,0% del 1% más rico solo.

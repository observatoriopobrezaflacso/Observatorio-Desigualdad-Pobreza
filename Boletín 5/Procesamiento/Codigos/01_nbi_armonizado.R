# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Pobreza por NBI armonizada entre censos (1982, 1990, 2001, 2010, 2022)
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Definición del INEC para los censos (2010, 2022): un hogar y todos sus
# miembros son pobres si tienen al menos 1 de 5 necesidades insatisfechas y
# pobres extremos si tienen 2 o más. Solo viviendas particulares ocupadas.
#
#   1. Dependencia económica: jefe con 3 o menos años de escolaridad Y más de
#      3 personas por ocupado.
#   2. Asistencia escolar: niñas/os de 6 a 12 años que no asisten.
#   3. Vivienda: piso de tierra u otros, o paredes de caña no revestida u otros.
#   4. Servicios: agua que no es de red pública por tubería dentro de la
#      vivienda, o servicio higiénico que no va a alcantarillado o pozo séptico.
#   5. Hacinamiento: más de 3 personas por dormitorio (0 dormitorios = 1).
#
# Armonización:
#   - Saneamiento: el pozo ciego cuenta como carencia en todos los censos
#     (regla del INEC). 1982 y 1990 solo tienen la opción "pozo ciego" (sin
#     pozo séptico), así que ahí cualquier pozo es carencia; esto puede
#     sobrestimar la carencia si hogares con pozo séptico marcaron esa opción.
#   - Escolaridad del jefe en la escala del INEC (GRAESC 2010), que cuenta un
#     año de preescolar: primaria g = g + 1, EGB g = g, secundaria g = 7 + g,
#     bachillerato g = 10 + g, superior g = 13 + g.
#   - Ocupados: personas de 12 años o más (1982 solo pregunta actividad desde
#     los 12; en 2010 no cambia el resultado).
#   - 2001: los archivos no tienen manzana, por lo que un hogar puede tener la 
#           la misma clave (unión de provincia, cantón, ...,  vivienda y ho-
#           gar), pero pertnecer a distintas manzanas (ej. "vivienda 1, ho - 
#           gar 1 repetidas). Para solventarlo, en la base de personas se creó
#           un nuevo identificador de hogar que comienza cuando:
#                (1) las personas se reinician. Ejemplo: si el hogar 1 tiene 
#                    cuatro filas y en las primeras hay persona 1 y 2 y en la 
#.                   tercera y cuarta hay otra vez personas 1 y 2, entonces 
#                    el nuevo identificador asignará hogar 1 a las primeras dos
#                    filas y hogar 2 a la tercera y cuarta.
#               (2)  OR cuando la clave anterior es diferente a la actual. Ej:
#                    para la misma provincia, cantón y sector, existe una vivienda
#                    1, hogar 1 en las filas 1 y 2,  una vivienda 1 hogar 2 en 
#                    las filas 3 y 4 y luego en las filas 5 y 6 se repite vi -
#                    vienda 1, hogar 1, entonces el nuevo identificador 
#                    asignará hogar 1 a las primeras dos filas, hogar 2 a las
#                    siguientes dos y hogar 3 a la quinta y sexta, otorgando 
#                    un identificador diferente a las primeras dos filas que la 
#                    quinta y sexta. 
#        El método supone que las tres bases están en el mismo orden. La
#        verificación lo confirma: en el 100% de los hogares coinciden el número
#        de personas con el total declarado (TOTPOBL) y la clave entre las bases.
#
#        En la base de hogares, el identificador de hogar se genera con un nú
#        mero secuencial para cada fila (primera fila 1, segunda 2, ...). 
#        Luego, se unen las bases de personas y hogares solo con los nuevos i-
#        dentificadores de hogar. 
#
#        Finalmente, en la base de hogares se hace algo similar: se crea un
#        identificador de vivienda cada vez que se reinicia el hogar. En la base
#        de viviendas se asigna un número secuencial a cada fila y luego se unen
#        con ese nuevo identificador de vivienda. 
#
#   - 1982: El NBI indica que se debe considerar a un hogar como privado si su
#           vivienda tiene paredes de "caña no revestida u otros materiales". 
#           En el resto de años, la pregunta sobre el material de las paredes
#           tiene las opciones "caña revestida" y "caña no revestida", Hormigón, 
#           "...", y "otros materiales". En 1982, no hay la opcón de "caña no 
#           revestida", por lo que solo se considera a un hogar privado si está
#           si su pared está hecha de "otros materiales" o tiene la categoría 
#           6, que tiene pocas observaciones y no está etiquetada.
#
#   - 2022: agua de empresa pública o junta de agua (V10 1-2) por tubería dentro
#     de la vivienda; el inodoro a biodigestor cuenta como pozo séptico.
#
# Población a la que se hace cada pregunta (revisado con los datos):
#   - Universo: hogares en viviendas particulares ocupadas con personas
#     presentes en todos los censos (97.7% de la población en 1990, 98.4% en
#     1982 y más del 99% en los demás; el resto vive en viviendas colectivas o
#     no tiene vivienda).
#   - Actividad: desde los 12 años en 1982, desde los 8 en 1990 y desde los 5
#     en 2001-2022. Por eso los ocupados se cuentan desde los 12 en todos.
#   - Asistencia escolar: desde los 6 años en 1982 y 1990, desde los 5 en 2001
#     y 2010, y a todas las edades en 2022. Todas cubren el rango 6-12.
#   - Nivel de instrucción: desde los 6 años (1982, 1990) o 5 (2001-2022);
#     cubre a todos los jefes de hogar.
#   - Dormitorios y servicio higiénico: por hogar en 1990-2022 (1990 y 2001
#     preguntan el servicio higiénico al hogar y la eliminación de aguas a la
#     vivienda); 1982 tiene un registro por hogar con datos de su vivienda.
#   Diferencias que quedan (efecto sobre el NBI total, en puntos):
#   - No respuesta: 2010 y 2022 vienen imputados; antes hay "se ignora" (jefe
#     sin escolaridad: 5.5% de hogares en 1982, 3.7% en 1990, 9.5% en 2001 y
#     2.3% en 2010; niños 6-12 sin dato de asistencia: 8.3%, 2.7% y 3.1% en
#     1982-2001). Se cuentan como necesidad satisfecha. Contarlos como
#     carencia sube el NBI en 0.5-0.7 (1982), 0.3 (1990), 0.4-0.9 (2001) y
#     0.2 (2010).
#   - 1982 no tiene la pregunta de recuperación de trabajo (ALOMEJOR en
#     1990-2001, categorías 3-5 de TIPOACT en 2010). Quitarla en 1990-2010
#     cambia el NBI en 0.1 puntos (dependencia +1.2 a +1.7).
#
# Validación: 2010 da 59.8% (oficial 60.1%) y 2022 39.8% (oficial 39.8%). nbi_oficial
# es el NBI que traen las bases: el del INEC en 2022 (variable NBI del hogar)
# y el de la base original en 1982 (pobreza_nbi); NULL en los demás años.
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

source("censo_duckdb.R")

# censo_dir = Mi unidad/Bases/Censo
resultados_dir <- file.path(dirname(dirname(censo_dir)), "Boletín 5", "Resultados", "NBI")

# Hogares por censo ----
# Cada consulta devuelve una fila por hogar en vivienda particular ocupada con:
# anio, dpa_parroquia, n, ocu, esc_jefe, nino, piso, pared, agua,
# san, dorm, n_declarado (tamaño del hogar
# según el archivo de vivienda/hogar, para verificar la unión), nbi_oficial

nbi_sql_hogares <- list(
  `1982` = "
    WITH p AS (
      SELECT idparr11, idparr82, zona, sector, manzana, idhogar, COUNT(*) n,
        COUNT(*) FILTER (edad >= 12 AND P13 IN (0, 1)) ocu,
        MAX(CASE WHEN P02 = 0 THEN CASE P11a WHEN 0 THEN 0 WHEN 1 THEN 0 WHEN 2 THEN P11b + 1
             WHEN 3 THEN 7 + P11b WHEN 4 THEN 13 + P11b END END) esc_jefe,
        MAX((edad BETWEEN 6 AND 12 AND P10 = 2)::INT) nino,
        MAX((pobreza_nbi >= 2)::INT) nbi_oficial
      FROM censo1982 GROUP BY ALL)
    SELECT 1982 anio, lpad(p.idparr11::INT::VARCHAR, 6, '0') dpa_parroquia, p.n, p.ocu, p.esc_jefe, p.nino,
      (V03c IN (5, 6))::INT piso, (V03b IN (5, 6))::INT pared, (V05 <> 1)::INT agua,
      (V06 IN (3, 4) OR V07 <> 1)::INT san, V10 dorm, totper n_declarado, p.nbi_oficial
    FROM p JOIN censo1982_vivienda v USING (idparr82, zona, sector, manzana, idhogar)
    WHERE v.V01 BETWEEN 1 AND 8 AND v.V02 = 1",

  `1990` = "
    WITH p AS (
      SELECT PROVIN, CANTON, PARROQ, ZONA, SECTOR, MANZAN, AREEMP, NUMVIV, NUMHOG, COUNT(*) n,
        COUNT(*) FILTER (EDADOK >= 12 AND (HIZSEM IN (0, 1) OR ALOMEJOR = 1)) ocu,
        MAX(CASE WHEN PARENT = 0 THEN CASE WHEN NIVINS IN (0, 1) THEN 0
             WHEN NIVINS = 2 AND GRACUR <= 6 THEN GRACUR + 1 WHEN NIVINS = 3 AND GRACUR <= 6 THEN 7 + GRACUR
             WHEN NIVINS = 4 THEN 13 WHEN NIVINS = 5 THEN 18 END END) esc_jefe,
        MAX((EDADOK BETWEEN 6 AND 12 AND ASISTE = 2)::INT) nino
      FROM censo1990 GROUP BY ALL)
    SELECT 1990 anio, printf('%02d%02d%02d', p.PROVIN::INT, p.CANTON::INT, p.PARROQ::INT) dpa_parroquia,
      p.n, p.ocu, p.esc_jefe, p.nino, (PISO IN (5, 6))::INT piso, (PARED IN (5, 6))::INT pared,
      (NOT (MEDABA = 1 AND SISABA = 1))::INT agua,
      (SERHIG IN (3, 4) OR AGUSER <> 1)::INT san, CUADOR dorm, TOTALPOB n_declarado, NULL::INT nbi_oficial
    FROM p JOIN censo1990_vivienda_hogar v USING (PROVIN, CANTON, PARROQ, ZONA, SECTOR, MANZAN, AREEMP, NUMVIV, NUMHOG)
    WHERE v.TIPVIV BETWEEN 1 AND 8 AND v.CONOCU = 1",

  # personas -> hogar: nuevo hogar cuando cambia la clave o se reinicia ORDPOB
  # hogar -> vivienda: nueva vivienda cuando NUMHOG <= 1; las viviendas con
  # hogares son las de TOTHOG > 0 o CONOCU = 0, en el mismo orden
  `2001` = "
    WITH p01 AS (
      SELECT *, SUM(nuevo) OVER (ORDER BY fila) hseq FROM (
        SELECT *, (lag(PROVIN||'-'||CANTON||'-'||PARROQ||'-'||ZONA||'-'||SECTOR||'-'||NUMVIV||'-'||NUMHOG)
                    OVER (ORDER BY fila) IS DISTINCT FROM
                   PROVIN||'-'||CANTON||'-'||PARROQ||'-'||ZONA||'-'||SECTOR||'-'||NUMVIV||'-'||NUMHOG
                   OR ORDPOB <= lag(ORDPOB) OVER (ORDER BY fila))::INT nuevo
        FROM censo2001)),
    hg01 AS (
      SELECT *, ROW_NUMBER() OVER (ORDER BY fila) hseq, SUM((NUMHOG <= 1)::INT) OVER (ORDER BY fila) vseq
      FROM censo2001_hogar),
    v01 AS (
      SELECT *, ROW_NUMBER() OVER (ORDER BY fila) vseq
      FROM censo2001_vivienda WHERE TOTHOG > 0 OR CONOCU = 0),
    p AS (
      SELECT hseq, COUNT(*) n,
        COUNT(*) FILTER (EDAD >= 12 AND (HIZSEM IN (1, 2) OR ALOMEJOR = 1)) ocu,
        MAX(CASE WHEN PARENT = 0 AND GRACUR <> 99 THEN CASE WHEN NIVINS IN (0, 1) THEN 0
             WHEN NIVINS = 2 THEN GRACUR + 1 WHEN NIVINS = 3 THEN 7 + GRACUR WHEN NIVINS = 4 THEN GRACUR
             WHEN NIVINS = 5 THEN 10 + GRACUR WHEN NIVINS IN (6, 7) THEN 13 + GRACUR WHEN NIVINS = 8 THEN 18 END END) esc_jefe,
        MAX((EDAD BETWEEN 6 AND 12 AND ASISTE = 2)::INT) nino
      FROM p01 GROUP BY hseq)
    SELECT 2001 anio, printf('%02d%02d%02d', h.PROVIN::INT, h.CANTON::INT, h.PARROQ::INT) dpa_parroquia,
      p.n, p.ocu, p.esc_jefe, p.nino, (v.PISO IN (5, 6))::INT piso, (v.PARED IN (5, 6))::INT pared,
      (NOT (v.PROVAGUA = 1 AND v.OBTAGUA = 1))::INT agua,
      (h.SERHIG IN (3, 4) OR v.AGUSER NOT IN (1, 3))::INT san, h.DORMHOG dorm, h.TOTPOBL n_declarado, NULL::INT nbi_oficial
    FROM p JOIN hg01 h USING (hseq) JOIN v01 v USING (vseq)
    WHERE v.TIPVIV BETWEEN 1 AND 8 AND v.CONOCU = 1",

  `2010` = "
    WITH p AS (
      SELECT id_hog, COUNT(*) n,
        COUNT(*) FILTER (P03 >= 12 AND TIPOACT BETWEEN 1 AND 5) ocu,
        MAX(CASE WHEN P02 = 1 AND GRAESC <> 99 THEN GRAESC END) esc_jefe,
        MAX((P03 BETWEEN 6 AND 12 AND P21 = 2)::INT) nino
      FROM censo2010 GROUP BY id_hog)
    SELECT 2010 anio, printf('%02d%02d%02d', v.I01::INT, v.I02::INT, v.I03::INT) dpa_parroquia,
      p.n, p.ocu, p.esc_jefe, p.nino, (V05 IN (6, 7))::INT piso, (V03 IN (6, 7))::INT pared,
      (NOT (V07 = 1 AND V08 = 1))::INT agua, (V09 NOT IN (1, 2))::INT san, H01 dorm, TP1 n_declarado, NULL::INT nbi_oficial
    FROM p JOIN censo2010_hogar h USING (id_hog) JOIN censo2010_vivienda v ON v.id_viv = h.id_viv
    WHERE v.VTV BETWEEN 1 AND 8",

  `2022` = "
    WITH p AS (
      SELECT ID_HOG, COUNT(*) n,
        COUNT(*) FILTER (P03 >= 12 AND CONDACT1 = 2) ocu,
        MAX(CASE WHEN P01 = 1 THEN ESCOLA END) esc_jefe,
        MAX((P03 BETWEEN 6 AND 12 AND P15 = 2)::INT) nino
      FROM censo2022 GROUP BY ID_HOG)
    SELECT 2022 anio, printf('%02d%02d%02d', v.I01::INT, v.I02::INT, v.I03::INT) dpa_parroquia,
      p.n, p.ocu, p.esc_jefe, p.nino, (V07 IN (7, 8))::INT piso, (V05 IN (7, 8))::INT pared,
      (NOT (V09 = 1 AND V10 IN (1, 2)))::INT agua, (V11 NOT IN (1, 2, 3))::INT san, H01 dorm, H1303 n_declarado, (h.NBI = 1)::INT nbi_oficial
    FROM p JOIN censo2022_hogar h USING (ID_HOG) JOIN censo2022_vivienda v ON v.ID_VIV = h.ID_VIV
    WHERE v.V01 BETWEEN 1 AND 8"
)

# Componentes y pobreza por hogar ----

nbi_crear <- function(anios = names(nbi_sql_hogares)) {
  con <- censo_con()
  for (a in anios) {
    dbExecute(con, sprintf("CREATE OR REPLACE TEMP TABLE nbi_hogar_%s AS
      SELECT *, (nbi_dep + nbi_esc + nbi_viv + nbi_ser + nbi_hac) n_nbi
      FROM (SELECT *,
        coalesce((esc_jefe <= 3 AND n > 3 * ocu)::INT, 0) nbi_dep,
        nino nbi_esc,
        GREATEST(piso, pared) nbi_viv,
        GREATEST(agua, san) nbi_ser,
        (n > 3 * GREATEST(coalesce(dorm, 1), 1))::INT nbi_hac
      FROM (%s))", a, nbi_sql_hogares[[a]]))
  }
  dbExecute(con, paste("CREATE OR REPLACE TEMP VIEW nbi_hogar AS",
                       paste(sprintf("SELECT * FROM nbi_hogar_%s", anios), collapse = " UNION ALL ")))
  invisible(anios)
}

# Porcentaje de personas pobres por NBI y con cada carencia.
# por: columnas adicionales para desagregar (p. ej. "dpa_parroquia")
nbi_resumen <- function(por = NULL) {
  grupos <- paste(c("anio", por), collapse = ", ")
  censo_sql(sprintf("
    SELECT %s, SUM(n) personas,
      SUM(n * (n_nbi >= 1)::INT) pobres,
      ROUND(100 * SUM(n * (n_nbi >= 1)::INT) / SUM(n), 1) pct_nbi,
      ROUND(100 * SUM(n * (n_nbi >= 2)::INT) / SUM(n), 1) pct_nbi_extrema,
      ROUND(100 * SUM(n * nbi_oficial) / SUM(n), 1) pct_nbi_oficial,
      ROUND(100 * SUM(n * nbi_dep) / SUM(n), 1) pct_dependencia,
      ROUND(100 * SUM(n * nbi_esc) / SUM(n), 1) pct_escolar,
      ROUND(100 * SUM(n * nbi_viv) / SUM(n), 1) pct_vivienda,
      ROUND(100 * SUM(n * nbi_ser) / SUM(n), 1) pct_servicios,
      ROUND(100 * SUM(n * agua) / SUM(n), 1) pct_agua,
      ROUND(100 * SUM(n * san) / SUM(n), 1) pct_saneamiento,
      ROUND(100 * SUM(n * nbi_hac) / SUM(n), 1) pct_hacinamiento
    FROM nbi_hogar GROUP BY %s ORDER BY %s", grupos, grupos, grupos))
}

# Ejecución ----
# options(censo.solo_funciones = TRUE) antes de source() para cargar solo las funciones

if (!isTRUE(getOption("censo.solo_funciones"))) {
  censo_conectar()
  nbi_crear()

  nbi_nacional <- nbi_resumen()
  nbi_parroquial <- nbi_resumen("dpa_parroquia")
  print(nbi_nacional)

  dir.create(resultados_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(nbi_nacional, file.path(resultados_dir, "nbi_armonizado_nacional.csv"), row.names = FALSE)
  write.csv(nbi_parroquial, file.path(resultados_dir, "nbi_armonizado_parroquial.csv"), row.names = FALSE)
  cat("Resultados en", normalizePath(resultados_dir), "\n")

  censo_desconectar()
}

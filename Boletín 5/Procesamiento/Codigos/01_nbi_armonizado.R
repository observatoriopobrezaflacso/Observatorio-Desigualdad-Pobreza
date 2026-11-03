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
#   - Saneamiento: 1982 y 1990 no separan pozo séptico de pozo ciego, así que
#     la versión armonizada (nbi) da por satisfecho cualquier pozo. La regla
#     del INEC (nbi_inec) solo se calcula en 2001 en adelante.
#   - Escolaridad del jefe en la escala del INEC (GRAESC 2010), que cuenta un
#     año de preescolar: primaria g = g + 1, EGB g = g, secundaria g = 7 + g,
#     bachillerato g = 10 + g, superior g = 13 + g.
#   - Ocupados: personas de 12 años o más (1982 solo pregunta actividad desde
#     los 12; en 2010 no cambia el resultado).
#   - 2001: los archivos no tienen manzana, así que personas, hogares y
#     viviendas se unen por el orden del archivo (columna fila).
#   - 1982: las paredes no distinguen caña no revestida; se toma "otros"
#     (código 5) y el código 6, sin etiqueta.
#
# Validación: con la regla del INEC, 2010 da 59.8% (oficial 60.1%).
# 2022 (oficial 39.8%) requiere cargar las bases de vivienda y hogar del
# censo 2022 como censo2022_vivienda y censo2022_hogar.
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

source("censo_duckdb.R")

# censo_dir = Mi unidad/Bases/Censo
resultados_dir <- file.path(dirname(dirname(censo_dir)), "Boletín 5", "Resultados", "NBI")

# Hogares por censo ----
# Cada consulta devuelve una fila por hogar en vivienda particular ocupada con:
# anio, dpa_parroquia, n, ocu, esc_jefe, nino, piso, pared, agua,
# san_inec (NULL si no se puede), san_arm, dorm, n_declarado (tamaño del hogar
# según el archivo de vivienda/hogar, para verificar la unión)

nbi_sql_hogares <- list(
  `1982` = "
    WITH p AS (
      SELECT idparr11, idparr82, zona, sector, manzana, idhogar, COUNT(*) n,
        COUNT(*) FILTER (edad >= 12 AND P13 IN (0, 1)) ocu,
        MAX(CASE WHEN P02 = 0 THEN CASE P11a WHEN 0 THEN 0 WHEN 1 THEN 0 WHEN 2 THEN P11b + 1
             WHEN 3 THEN 7 + P11b WHEN 4 THEN 13 + P11b END END) esc_jefe,
        MAX((edad BETWEEN 6 AND 12 AND P10 = 2)::INT) nino
      FROM censo1982 GROUP BY ALL)
    SELECT 1982 anio, lpad(p.idparr11::INT::VARCHAR, 6, '0') dpa_parroquia, p.n, p.ocu, p.esc_jefe, p.nino,
      (V03c IN (5, 6))::INT piso, (V03b IN (5, 6))::INT pared, (V05 <> 1)::INT agua,
      NULL::INT san_inec, (V06 IN (3, 4) OR V07 = 3)::INT san_arm, V10 dorm, totper n_declarado
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
      (NOT (MEDABA = 1 AND SISABA = 1))::INT agua, NULL::INT san_inec,
      (SERHIG IN (3, 4) OR AGUSER IN (3, 4))::INT san_arm, CUADOR dorm, TOTALPOB n_declarado
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
      (h.SERHIG IN (3, 4) OR v.AGUSER NOT IN (1, 3))::INT san_inec,
      (h.SERHIG IN (3, 4) OR v.AGUSER = 4)::INT san_arm, h.DORMHOG dorm, h.TOTPOBL n_declarado
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
      (NOT (V07 = 1 AND V08 = 1))::INT agua, (V09 NOT IN (1, 2))::INT san_inec,
      (V09 NOT IN (1, 2, 3))::INT san_arm, H01 dorm, TP1 n_declarado
    FROM p JOIN censo2010_hogar h USING (id_hog) JOIN censo2010_vivienda v ON v.id_viv = h.id_viv
    WHERE v.VTV BETWEEN 1 AND 8"
)

# Componentes y pobreza por hogar ----

nbi_crear <- function(anios = names(nbi_sql_hogares)) {
  con <- censo_con()
  for (a in anios) {
    dbExecute(con, sprintf("CREATE OR REPLACE TEMP TABLE nbi_hogar_%s AS
      SELECT *, (nbi_dep + nbi_esc + nbi_viv + nbi_ser + nbi_hac) n_nbi,
             (nbi_dep + nbi_esc + nbi_viv + nbi_ser_inec + nbi_hac) n_nbi_inec
      FROM (SELECT *,
        coalesce((esc_jefe <= 3 AND n > 3 * ocu)::INT, 0) nbi_dep,
        nino nbi_esc,
        GREATEST(piso, pared) nbi_viv,
        GREATEST(agua, san_arm) nbi_ser,
        CASE WHEN san_inec IS NOT NULL THEN GREATEST(agua, san_inec) END nbi_ser_inec,
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
      ROUND(100 * SUM(n * (n_nbi_inec >= 1)::INT) / SUM(n), 1) pct_nbi_inec,
      ROUND(100 * SUM(n * nbi_dep) / SUM(n), 1) pct_dependencia,
      ROUND(100 * SUM(n * nbi_esc) / SUM(n), 1) pct_escolar,
      ROUND(100 * SUM(n * nbi_viv) / SUM(n), 1) pct_vivienda,
      ROUND(100 * SUM(n * nbi_ser) / SUM(n), 1) pct_servicios,
      ROUND(100 * SUM(n * agua) / SUM(n), 1) pct_agua,
      ROUND(100 * SUM(n * san_arm) / SUM(n), 1) pct_saneamiento,
      ROUND(100 * SUM(n * nbi_hac) / SUM(n), 1) pct_hacinamiento
    FROM nbi_hogar GROUP BY %s ORDER BY %s", grupos, grupos, grupos))
}

# Ejecución ----
# options(censo.solo_funciones = TRUE) antes de source() para cargar solo las funciones

if (!isTRUE(getOption("censo.solo_funciones"))) {
  censo_conectar(c(1982, 1990, 2001, 2010))
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

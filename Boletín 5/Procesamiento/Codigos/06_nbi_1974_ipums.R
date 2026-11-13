# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Pobreza por NBI en 1974 con la muestra de IPUMS International
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# El INEC no tiene los microdatos completos del censo de 1974. IPUMS tiene una
# muestra de hogares (05_ipums_extracto.R) que sale de la muestra estratificada
# del 13.6% que hizo la oficina de estadística, con pesos: los hogares de la
# Amazonía, Galápagos y parte de las demás provincias pesan 1.4; el resto,
# cerca de 14. Todos los resultados usan el peso del hogar (HHWT) y la
# población expandida es 6.51 millones (censo: 6.52).
#
# Alcance: la muestra reproduce la población nacional y la de las provincias,
# pero no la de los cantones. Dentro de una provincia hay cantones con mucha
# menos o mucha más población expandida de la que tenían (Santa Rosa 5,500
# personas frente a 40,600 en 1982; Zaruma 68,000 frente a 36,000), y Antonio
# Ante y Santa Isabel no tienen hogares. El NBI nacional y provincial es
# confiable; el cantonal es una aproximación. La columna razon_pob_1982
# (población de 1974 / población de 1982 del mismo grupo; nacional 0.81)
# permite ver qué cantones están mal representados.
#
# Mismas reglas que los demás censos (01_nbi_armonizado.R), con las variables
# originales de 1974:
#   - Universo: viviendas particulares (tipo 1-8) ocupadas con personas presentes.
#   - Ocupados: 12 años o más que trabajaron o tenían trabajo (la pregunta se
#     hace desde los 12 años, como en 1982).
#   - Escolaridad del jefe: primaria g = g + 1, secundaria g = 7 + g, superior
#     g = 13 + g; ninguno y centro de alfabetización = 0; secundaria sin grado = 12.
#   - Asistencia: niñas/os de 6 a 12 años que no asisten (se pregunta desde los 6).
#   - Vivienda: piso de tierra u otros, o paredes de caña no revestida u otros.
#   - Agua: no llega por tubería dentro de la vivienda. La pregunta de 1974 no
#     separa la red pública de otras fuentes cuando hay tubería.
#   - Saneamiento: letrina o sin servicio higiénico, o aguas servidas que no
#     van a alcantarillado. La opción "pozo séptico o ciego" cuenta como
#     carencia, igual que el pozo ciego de 1982 y 1990.
#   - Sin dato en piso, pared, agua o saneamiento: no cuenta como carencia.
#     Dormitorios sin dato: 1, como en los demás censos.
#
# Geografía: IPUMS da el cantón de empadronamiento (GEO2_EC1974) y agrupa los
# cantones pequeños. Donde un grupo junta cantones que son unidades distintas,
# se separan con el cantón de residencia habitual del jefe (EC1974A_RESCAN),
# que coincide con el de empadronamiento en el 99% de los hogares. El cantón de
# residencia no se usa solo porque tiene vacíos (Antonio Ante, Santa Isabel y
# Santa Rosa casi no aparecen).
#
# Los cantones de 1974 se enlazan con las unidades armonizadas 1982-2022
# (02_cantones_armonizados.R) por los cantones de 1982 que ocupan su
# territorio, incluidos los que se crearon entre 1974 y 1982 (Mira, Pimampiro,
# Catamayo, Sozoranga, Zapotillo, El Guabo, Huaquillas, Portovelo, San Lorenzo,
# Archidona, Lago Agrio, Yantzaza). Las unidades que comparten un cantón de
# 1974 forman un grupo. No hay parroquias en la muestra, así que los cambios
# de límites entre cantones que ya existían no se pueden corregir.
#   - Sozoranga (1975): las fuentes no aclaran si salió de Calvas o de Macará;
#     se juntan los tres.
#   - Pelileo y Patate: IPUMS los agrupa y el código de Patate no está
#     documentado; quedan juntos.
#   - Zonas en discusión (residencia 4901 y 4902, empadronadas con Santo
#     Domingo): sin unidad, como las zonas no delimitadas de 1982.
#
# Resultados en Resultados/NBI: nbi_1974_nacional.csv, nbi_1974_provincial.csv
# (provincia de empadronamiento; las zonas en discusión quedan en Pichincha),
# nbi_1974_cantonal.csv (por grupo de 1974, con el número de hogares de la muestra),
# cantones_1974_grupos.csv (unidad armonizada -> grupo de 1974) y
# nbi_cantonal_1974_2022.csv (serie 1974-2022 por grupo de 1974).
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

library(ipumsr)
options(censo.solo_funciones = TRUE)
source("01_nbi_armonizado.R")
source("02_cantones_armonizados.R")

ipums_ddi <- file.path(censo_dir, "IPUMS", "ipumsi_00001.xml")

# Cantones de 1974 ----
# geo: GEO2_EC1974; rescan: residencia habitual que separa un grupo de IPUMS
# (vacío = todo el grupo); c82: cantones del censo de 1982 en su territorio;
# c90: cantón de 1990 cuando 1982 no sirve (Alausí, base incompleta; El Carmen,
# zona no delimitada en 1982)
cantones_1974 <- read.table(header = TRUE, sep = "|", strip.white = TRUE, colClasses = "character", text = "
geo   | rescan         | nombre             | c82                 | c90
10001 |                | Montúfar           | 0404                |
10002 |                | Tulcán             | 0401                |
10003 |                | Espejo             | 0402 0403           |
11001 |                | Ibarra             | 1001 1005           |
11002 |                | Cotacachi          | 1003                |
11003 |                | Otavalo            | 1004                |
11004 |                | Antonio Ante       | 1002                |
12001 |                | Quito              | 1701                |
12002 |                | Santo Domingo      | 1706                |
12003 |                | Rumiñahui          | 1705                |
12004 |                | Cayambe            | 1702                |
12005 |                | Pedro Moncayo      | 1704                |
12006 |                | Mejía              | 1703                |
13001 |                | Pujilí             | 0503                |
13002 |                | Latacunga          | 0501                |
13003 |                | Saquisilí          | 0505                |
13004 |                | Salcedo            | 0504                |
13005 |                | Pangua             | 0502                |
14001 |                | Baños              | 1802                |
14002 | 1401           | Ambato             | 1801                |
14002 | 1405           | Quero              | 1806                |
14003 |                | Píllaro            | 1805                |
14004 |                | Pelileo y Patate   | 1804 1803           |
15001 |                | Guaranda           | 0201                |
15002 | 1502           | Chillanes          | 0202                |
15002 | 1504           | San Miguel         | 0204                |
15003 |                | Chimbo             | 0203                |
16001 |                | Riobamba           | 0601                |
16002 | 1602           | Alausí             |                     | 0602
16002 | 1604           | Chunchi            | 0604                |
16003 |                | Colta              | 0603                |
16004 |                | Guano              | 0606                |
16005 |                | Guamote            | 0605                |
17001 |                | Cañar              | 0303                |
17002 |                | Biblián            | 0302                |
17003 |                | Azogues            | 0301                |
18001 |                | Cuenca             | 0101                |
18002 |                | Sígsig             | 0106                |
18003 |                | Girón              | 0102                |
18004 |                | Paute              | 0104                |
18005 |                | Santa Isabel       | 0105                |
18006 |                | Gualaceo           | 0103                |
19001 | 1905           | Gonzanamá          | 1106                |
19001 | 1907           | Paltas             | 1108                |
19002 |                | Saraguro           | 1110                |
19003 | 1903           | Celica             | 1104 1112           |
19003 | 1908           | Puyango            | 1109                |
19004 |                | Calvas             | 1102 1111           |
19005 |                | Macará             | 1107 1111           |
19006 |                | Espíndola          | 1105                |
19007 |                | Loja               | 1101 1103           |
20001 |                | Esmeraldas         | 0801                |
20002 |                | Quinindé           | 0804                |
20003 |                | Eloy Alfaro        | 0802 0805           |
20004 |                | Muisne             | 0803                |
21001 |                | 24 de Mayo         | 1313                |
21002 |                | Jipijapa           | 1305                |
21003 | 2106           | Junín              | 1306                |
21003 | 2110           | Rocafuerte         | 1310                |
21004 |                | Santa Ana          | 1311                |
21005 |                | Paján              | 1309                |
21006 |                | Portoviejo         | 1301                |
21007 |                | Manta              | 1307                |
21008 | 2103           | Chone              | 1303                |
21008 | 2104           | El Carmen          |                     | 1304
21009 |                | Sucre              | 1312                |
21010 |                | Bolívar            | 1302                |
21011 |                | Montecristi        | 1308                |
22001 |                | Babahoyo           | 1201                |
22002 |                | Puebloviejo        | 1203                |
22003 |                | Urdaneta           | 1205                |
22004 |                | Baba               | 1202                |
22005 |                | Ventanas           | 1206                |
22006 |                | Quevedo            | 1204                |
22007 |                | Vinces             | 1207                |
23001 |                | El Empalme         | 0904                |
23002 |                | Balzar             | 0902                |
23003 |                | Guayaquil          | 0901                |
23004 |                | Milagro            | 0905                |
23005 |                | Yaguachi           | 0912                |
23006 |                | Naranjito          | 0907                |
23007 |                | Salinas            | 0908                |
23008 |                | Santa Elena        | 0910                |
23009 |                | Naranjal           | 0906                |
23010 |                | Samborondón        | 0909                |
23011 |                | Daule              | 0903                |
23012 |                | Urbina Jado        | 0911                |
23013 |                | Galápagos          | 2001 2002 2003      |
24001 |                | Piñas              | 0706                |
24002 |                | Zaruma             | 0709 0707           |
24003 |                | Pasaje             | 0705                |
24004 |                | Arenillas          | 0702 0704           |
24005 |                | Machala            | 0701 0703           |
24006 |                | Santa Rosa         | 0708                |
30001 |                | Napo (sin Tena)    | 1502 1504 1505 1506 1507 1508 |
30002 |                | Tena               | 1501 1503           |
31001 | 3101           | Pastaza            | 1601                |
31001 | 3102           | Mera               | 1602                |
32001 | 3202           | Gualaquiza         | 1402                |
32001 | 3203           | Limón Indanza      | 1403                |
32002 | 3201 3204 3205 | Morona, Palora y Santiago | 1401 1404 1405 |
32002 | 3206           | Sucúa              | 1406                |
33001 | 3301           | Zamora             | 1901 1904           |
33001 | 3302           | Chinchipe          | 1902                |
33001 | 3303           | Yacuambi           | 1903                |
")
cantones_1974$id <- seq_len(nrow(cantones_1974))
zonas_discusion_1974 <- c(4901, 4902)

partes <- function(x) strsplit(trimws(x), " +")

# Grupos de 1974: unidades armonizadas que comparten un cantón de 1974 ----
# cw: cantones_armonizados.csv. Devuelve una fila por cantón de 1974 y unidad.
grupos_1974 <- function(cw) {
  u82 <- unique(cw[cw$anio == 1982 & cw$unidad != "excluida", c("canton", "unidad")])
  u90 <- unique(cw[cw$anio == 1990 & cw$unidad != "excluida", c("canton", "unidad")])
  enlaces <- do.call(rbind, lapply(cantones_1974$id, function(i) {
    u <- c(u82$unidad[u82$canton %in% partes(cantones_1974$c82[i])[[1]]],
           u90$unidad[u90$canton %in% partes(cantones_1974$c90[i])[[1]]])
    if (!length(u)) stop("Cantón de 1974 sin unidad: ", cantones_1974$nombre[i])
    data.frame(id = i, unidad = unique(u))
  }))
  g <- igraph::graph_from_data_frame(data.frame(paste0("c", enlaces$id), enlaces$unidad), directed = FALSE)
  comp <- igraph::components(g)$membership
  enlaces$comp <- comp[enlaces$unidad]
  # el grupo toma el código de su primera unidad y el nombre de sus cantones de 1974
  enlaces$grupo <- ave(enlaces$unidad, enlaces$comp, FUN = function(u) sub("^U", "G", min(u)))
  nombres <- tapply(cantones_1974$nombre[enlaces$id], enlaces$grupo, function(x) paste(unique(x), collapse = " + "))
  enlaces$nombre_grupo <- unname(nombres[enlaces$grupo])
  enlaces$comp <- NULL
  enlaces
}

# Hogares de 1974 ----

ipums_leer <- function(anio, ddi = ipums_ddi) {
  d <- read_ipums_micro(ddi, verbose = FALSE)
  d <- d[d$YEAR == anio, ]
  as.data.frame(lapply(d, function(v) if (inherits(v, "haven_labelled")) as.numeric(v) else v))
}

# Misma estructura que nbi_sql_hogares, más el peso y la geografía de IPUMS.
# canton74 es el id de cantones_1974: el grupo de IPUMS y, donde hay que
# separarlo, la residencia del jefe o, si no sirve, la más frecuente del hogar.
nbi_sql_1974 <- "
  WITH r AS (
    SELECT SERIAL, rescan FROM (
      SELECT p.SERIAL, c.id rescan, ROW_NUMBER() OVER (PARTITION BY p.SERIAL
        ORDER BY MAX((p.EC1974A_RELATE = 0)::INT) DESC, COUNT(*) DESC, c.id) rk
      FROM ipums1974 p JOIN c74_rescan c ON c.geo = p.GEO2_EC1974 AND c.rescan = p.EC1974A_RESCAN
      GROUP BY p.SERIAL, c.id) WHERE rk = 1),
  p AS (
    SELECT SERIAL, COUNT(*) n,
      COUNT(*) FILTER (EC1974A_AGE >= 12 AND EC1974A_EMPSTAT IN (1, 2)) ocu,
      MAX(CASE WHEN EC1974A_RELATE = 0 THEN CASE
           WHEN EC1974A_EDLEV = 0 OR EC1974A_EDLEV BETWEEN 40 AND 46 THEN 0
           WHEN EC1974A_EDLEV BETWEEN 10 AND 16 THEN EC1974A_EDLEV - 9
           WHEN EC1974A_EDLEV BETWEEN 21 AND 26 THEN EC1974A_EDLEV - 13
           WHEN EC1974A_EDLEV = 29 THEN 12
           WHEN EC1974A_EDLEV BETWEEN 31 AND 39 THEN EC1974A_EDLEV - 17 END END) esc_jefe,
      MAX((EC1974A_AGE BETWEEN 6 AND 12 AND EC1974A_SCHOOL = 2)::INT) nino,
      ANY_VALUE(HHWT) peso, ANY_VALUE(GEO2_EC1974) geo, ANY_VALUE(PERSONS) n_declarado,
      ANY_VALUE(EC1974A_FLOOR) v_piso, ANY_VALUE(EC1974A_WALL) v_pared, ANY_VALUE(EC1974A_WATSUP) v_agua,
      ANY_VALUE(EC1974A_TOILET) v_ssh, ANY_VALUE(EC1974A_SEWER) v_aguas, ANY_VALUE(EC1974A_BEDROOMS) v_dorm,
      MAX((EC1974A_RELATE = 0 AND EC1974A_RESCAN IN (4901, 4902))::INT) en_discusion
    FROM ipums1974
    WHERE EC1974A_DWTYPE BETWEEN 1 AND 8 AND EC1974A_OCCUPAN = 1
    GROUP BY SERIAL)
  SELECT 1974 anio, p.SERIAL, p.peso, p.geo,
    CASE WHEN p.en_discusion = 1 THEN NULL ELSE coalesce(g.id, r.rescan) END canton74,
    p.n, p.ocu, p.esc_jefe, p.nino,
    (v_piso IN (5, 6))::INT piso, (v_pared IN (5, 6))::INT pared, (v_agua BETWEEN 2 AND 8)::INT agua,
    (v_ssh IN (3, 4) OR v_aguas IN (2, 3))::INT san, CASE WHEN v_dorm < 98 THEN v_dorm END dorm,
    p.n_declarado, NULL::INT nbi_oficial
  FROM p LEFT JOIN c74_geo g ON g.geo = p.geo LEFT JOIN r USING (SERIAL)
  WHERE p.peso > 0"

nbi_crear_1974 <- function(d = ipums_leer(1974)) {
  con <- censo_con()
  duckdb::duckdb_register(con, "ipums1974", d)
  # grupos de IPUMS completos (un solo cantón) y grupos que se separan por residencia
  entero <- cantones_1974[cantones_1974$rescan == "", ]
  sep <- cantones_1974[cantones_1974$rescan != "", ]
  sep <- do.call(rbind, lapply(seq_len(nrow(sep)), function(i)
    data.frame(geo = as.numeric(sep$geo[i]), rescan = as.numeric(partes(sep$rescan[i])[[1]]), id = sep$id[i])))
  duckdb::duckdb_register(con, "c74_geo", data.frame(geo = as.numeric(entero$geo), id = entero$id))
  duckdb::duckdb_register(con, "c74_rescan", sep)
  dbExecute(con, paste("CREATE OR REPLACE TEMP TABLE nbi_hogar_1974 AS", nbi_componentes_sql(nbi_sql_1974)))
  invisible(censo_sql("SELECT COUNT(*) hogares_muestra, COUNT(*) FILTER (canton74 IS NULL) sin_canton FROM nbi_hogar_1974"))
}

# NBI de 1974 por grupo, con el tamaño de la muestra
nbi_cantonal_1974 <- function(grupos) {
  con <- censo_con()
  duckdb::duckdb_register(con, "g74", unique(grupos[, c("id", "grupo", "nombre_grupo")]))
  dbExecute(con, "CREATE OR REPLACE TEMP VIEW nbi_hogar_1974_grupo AS
    SELECT h.*, g.grupo, g.nombre_grupo FROM nbi_hogar_1974 h JOIN g74 g ON g.id = h.canton74")
  r <- nbi_resumen(c("grupo", "nombre_grupo"), desde = "nbi_hogar_1974_grupo", peso = "peso")
  m <- censo_sql("SELECT grupo, COUNT(*) hogares_muestra FROM nbi_hogar_1974_grupo GROUP BY 1")
  merge(r, m, by = "grupo")
}

# NBI de 1974 por provincia de empadronamiento (los dos primeros dígitos de
# GEO2_EC1974; Galápagos es el grupo 23013)
provincias_1974 <- data.frame(
  cod = c(10:24, 30:33),
  provincia = c("Carchi", "Imbabura", "Pichincha", "Cotopaxi", "Tungurahua", "Bolívar", "Chimborazo", "Cañar",
                "Azuay", "Loja", "Esmeraldas", "Manabí", "Los Ríos", "Guayas", "El Oro", "Napo", "Pastaza",
                "Morona Santiago", "Zamora Chinchipe"))

nbi_provincial_1974 <- function() {
  con <- censo_con()
  duckdb::duckdb_register(con, "prov74", provincias_1974)
  dbExecute(con, "CREATE OR REPLACE TEMP VIEW nbi_hogar_1974_prov AS
    SELECT h.*, CASE WHEN h.geo = 23013 THEN 'Galápagos' ELSE p.provincia END provincia
    FROM nbi_hogar_1974 h JOIN prov74 p ON p.cod = FLOOR(h.geo / 1000)")
  r <- nbi_resumen("provincia", desde = "nbi_hogar_1974_prov", peso = "peso")
  m <- censo_sql("SELECT provincia, COUNT(*) hogares_muestra FROM nbi_hogar_1974_prov GROUP BY 1")
  merge(r, m, by = "provincia")
}

# Serie 1982-2022 con las unidades agregadas a los grupos de 1974
# (requiere nbi_crear() y la vista nbi_hogar_cantonal de 03_mapa_nbi_cantonal.R)
nbi_cantonal_grupos <- function(cw, grupos) {
  con <- censo_con()
  duckdb::duckdb_register(con, "cantones", cw[, c("anio", "parroquia", "unidad")])
  duckdb::duckdb_register(con, "ug74", unique(grupos[, c("unidad", "grupo", "nombre_grupo")]))
  dbExecute(con, "CREATE OR REPLACE TEMP VIEW nbi_hogar_grupo AS
    SELECT h.*, g.grupo, g.nombre_grupo FROM nbi_hogar h
    JOIN cantones c ON c.anio = h.anio AND c.parroquia = h.dpa_censo
    JOIN ug74 g ON g.unidad = c.unidad")
  nbi_resumen(c("grupo", "nombre_grupo"), desde = "nbi_hogar_grupo")
}

# Ejecución ----

if (!isTRUE(getOption("nbi1974.solo_funciones"))) {
  cw <- read.csv(cantones_archivo, colClasses = c(parroquia = "character", canton = "character"), encoding = "UTF-8")
  grupos <- grupos_1974(cw)
  censo_conectar()
  print(nbi_crear_1974())

  nacional <- nbi_resumen(desde = "nbi_hogar_1974", peso = "peso")
  provincial <- nbi_provincial_1974()
  cantonal <- nbi_cantonal_1974(grupos)
  print(t(nacional))

  nbi_crear()
  serie <- nbi_cantonal_grupos(cw, grupos)
  censo_desconectar()
  serie$hogares_muestra <- NA
  p82 <- serie[serie$anio == 1982, c("grupo", "personas")]
  cantonal$razon_pob_1982 <- round(cantonal$personas / p82$personas[match(cantonal$grupo, p82$grupo)], 2)
  serie <- rbind(cantonal[, names(serie)], serie)
  serie <- serie[order(serie$grupo, serie$anio), ]

  ug <- unique(merge(grupos[, c("unidad", "grupo", "nombre_grupo")],
                     unique(cw[, c("unidad", "nombre_unidad")]), by = "unidad"))
  escribir <- function(x, archivo) write.csv(x, file.path(resultados_dir, archivo), row.names = FALSE, fileEncoding = "UTF-8")
  escribir(nacional, "nbi_1974_nacional.csv")
  escribir(provincial, "nbi_1974_provincial.csv")
  escribir(cantonal[order(cantonal$grupo), ], "nbi_1974_cantonal.csv")
  escribir(ug[order(ug$grupo, ug$unidad), ], "cantones_1974_grupos.csv")
  escribir(serie, "nbi_cantonal_1974_2022.csv")
  cat("Resultados en", resultados_dir, "\n")
}

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Cantones armonizados entre censos (1982, 1990, 2001, 2010, 2022)
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Los cantones cambian entre censos: se crean cantones nuevos con parroquias de
# otros, cambian de provincia (Sucumbíos 1989, Orellana 1998, Santo Domingo y
# Santa Elena 2007) y se asignan zonas no delimitadas. Una unidad armonizada es
# un grupo de cantones que cubre el mismo territorio en todos los censos: si un
# cantón se dividió, la madre y las hijas forman una sola unidad.
#
# Método: cada cantón de cada censo es un nodo; dos nodos se unen si comparten
# alguna parroquia. Las unidades son los grupos conectados (igraph).
#   - 1982 -> 2010: la base de 1982 trae idparr11, la parroquia de 2011.
#   - 1990 -> 2001 -> 2010 y 2022 -> 2010: por código de parroquia; si el
#     código no existe en el otro censo, por nombre dentro de la misma familia
#     de provincias. Los nombres de 1990 y 2001 vienen de las etiquetas de la
#     variable parr de 1990, que son de la división de 2001.
#   - Vínculos manuales (vinculos_manuales), revisados con población y nombres.
#
# Casos especiales:
#   - Zonas no delimitadas del norte en 1982 (código 2201, 37.806 personas): no
#     se pueden repartir entre La Concordia, Manga del Cura y Las Golondrinas;
#     quedan fuera. El Piedrero en 1982 es el código 2202.
#   - La base de 1982 tiene ~78 mil personas menos que el total del INEC; faltan,
#     entre otros, El Carmen y la cabecera de Alausí. Esas unidades quedan sin
#     dato en 1982 (unidades_sin_1982).
#   - Manga del Cura pasa en 2022 a El Carmen (parroquias 130453 y 130454); se
#     mantiene como unidad aparte. Las Golondrinas pasa a García Moreno
#     (Cotacachi) y El Piedrero a El Triunfo; esas zonas se unen a esos cantones.
#
# Resultado: cantones_armonizados.csv en Resultados/NBI, una fila por parroquia
# y censo (anio, parroquia, canton, unidad, nombre_unidad).
#
# Directorio de trabajo: Boletín 5/Procesamiento/Codigos

library(igraph)
source("censo_duckdb.R")
invisible(suppressWarnings(Sys.setlocale("LC_CTYPE", "en_US.UTF-8")))

resultados_dir <- file.path(dirname(dirname(censo_dir)), "Boletín 5", "Resultados", "NBI")
cantones_archivo <- file.path(resultados_dir, "cantones_armonizados.csv")

# Parroquias de 2022 que eran Manga del Cura (zona no delimitada 9003)
parroquias_manga_del_cura <- c("130453", "130454")

# Vínculos entre cantones que no salen de los códigos ni de los nombres
vinculos_manuales <- data.frame(
  de = c("2001:1405", "2001:9002", "2022:2302", "2022:9003", "2010:9001", "2010:9004", "1982:2202",
         "1990:0206", "2001:0610", "2001:1411", "2001:1709", "1990:1505", "1990:1506", "1990:1502", "1990:1502"),
  a  = c("2010:1412", "2010:0808", "2010:0808", "2010:9003", "2022:1003", "2022:0909", "2010:9004",
         "1990:0203", "2001:0602", "2001:1409", "2001:1701", "2001:2201", "2001:2203", "2001:2202", "1990:1505"),
  motivo = c("Santiago (2001) es la cabecera de Tiwintza (2010)",
             "La Concordia: zona no delimitada hasta 2001, Esmeraldas en 2010",
             "La Concordia: Santo Domingo de los Tsáchilas en 2022",
             "Manga del Cura (parroquias 130453 y 130454 de El Carmen en 2022)",
             "Las Golondrinas pasa a García Moreno (Cotacachi) en 2022",
             "El Piedrero pasa a El Triunfo en 2022",
             "El Piedrero en 1982 (código 2202, población coincide con 1990)",
             "Caluma se separó de Chimbo",
             "Cumandá se separó de Alausí",
             "Pablo Sexto se separó de Huamboya",
             "Puerto Quito se separó de Quito",
             "Francisco de Orellana (Napo en 1990, Orellana en 2001)",
             "La Joya de los Sachas (Napo en 1990, Orellana en 2001)",
             "Aguarico (Napo en 1990, Orellana en 2001)",
             "Cuyabeno y Aguarico: sin nombres en 1990, se unen al norte amazónico"))

# Unidades con 1982 incompleto en la base (sin dato en 1982), por cantón de 2022
unidades_sin_1982 <- c("0602")  # Alausí: falta la cabecera cantonal en 1982

# Parroquias por censo ----

# Recupera caracteres escritos como <U+00F1>
texto_utf8 <- function(z) {
  m <- gregexpr("<U\\+([0-9A-F]{4})>", z)
  regmatches(z, m) <- lapply(regmatches(z, m), function(u) intToUtf8(strtoi(substr(u, 4, 7), 16L), multiple = TRUE))
  z
}

# Nombre normalizado para emparejar: sin tildes, paréntesis ni artículos
nombre_limpio <- function(z) {
  z <- toupper(iconv(z, "UTF-8", "ASCII//TRANSLIT"))
  z <- gsub("\\(.*\\)", "", z)
  z <- gsub("[^A-Z ]", "", z)
  z <- gsub("\\b(CABECERA|CANTONAL|CAB|EN|DE|DEL|LA|EL|LOS|LAS|SAN|SANTA)\\b", " ", z)
  gsub(" +", " ", trimws(z))
}

cantones_parroquias <- function() {
  et <- function(t, v) censo_sql("SELECT valor, etiqueta FROM etiquetas WHERE tabla = ? AND variable = ?", list(t, v))
  e01 <- et("censo1990_poblacion_trabajo", "parr")  # nombres de la división de 2001
  e01$c6 <- sprintf("%02d%02d%02d", as.integer(substr(e01$valor, 1, 2)),
                    as.integer(substr(e01$valor, 3, 4)), as.integer(substr(e01$valor, 5, 6)))
  p <- list(
    `1982` = censo_sql("SELECT lpad(idparr82::INT::VARCHAR, 6, '0') c6, lpad(idparr11::INT::VARCHAR, 6, '0') c11,
                          COUNT(*) pob FROM censo1982 GROUP BY ALL"),
    `1990` = censo_sql("SELECT printf('%02d%02d%02d', provin::INT, canton::INT, parroq::INT) c6, parr, COUNT(*) pob
                        FROM censo1990_poblacion_trabajo GROUP BY ALL"),
    `2001` = censo_sql("SELECT printf('%02d%02d%02d', PROVIN::INT, CANTON::INT, PARROQ::INT) c6, COUNT(*) pob
                        FROM censo2001 GROUP BY ALL"),
    `2010` = censo_sql("SELECT id_parr c6, COUNT(*) pob FROM censo2010 GROUP BY ALL"),
    `2022` = censo_sql("SELECT PARROQ c6, COUNT(*) pob FROM censo2022 GROUP BY ALL"))
  e82 <- et("censo1982", "idparr82")
  p$`1982`$nombre <- e82$etiqueta[match(as.integer(p$`1982`$c6), as.integer(e82$valor))]
  # en 1990 la etiqueta existe solo si el código sigue en la división de 2001
  p$`1990`$nombre <- e01$etiqueta[match(sprintf("%6s", p$`1990`$parr), sprintf("%6s", e01$valor))]
  p$`1990`$parr <- NULL
  p$`2001`$nombre <- e01$etiqueta[match(p$`2001`$c6, e01$c6)]
  e10 <- et("censo2010", "id_parr"); p$`2010`$nombre <- e10$etiqueta[match(p$`2010`$c6, e10$valor)]
  e22 <- et("censo2022", "PARROQ"); p$`2022`$nombre <- e22$etiqueta[match(p$`2022`$c6, e22$valor)]
  for (a in names(p)) {
    p[[a]]$anio <- as.integer(a)
    p[[a]]$nombre <- texto_utf8(p[[a]]$nombre)
    p[[a]]$n <- nombre_limpio(p[[a]]$nombre)
    p[[a]]$prov <- substr(p[[a]]$c6, 1, 2)
    p[[a]]$canton <- substr(p[[a]]$c6, 1, 4)
  }
  p$`2022`$canton[p$`2022`$c6 %in% parroquias_manga_del_cura] <- "9003"
  p
}

# Vínculos entre parroquias ----

# Provincias que se separaron de otra: se busca el nombre en toda la familia
familia <- function(p) {
  ifelse(p %in% c("15", "21", "22"), "15", ifelse(p %in% c("17", "23"), "17", ifelse(p %in% c("09", "24"), "09", p)))
}

# Destino de cada parroquia de o en d: mismo código, o mismo nombre (exacto o
# a 2 letras de distancia) entre las parroquias de d que no existen en o
vincular_parroquias <- function(o, d) {
  dest <- ifelse(o$c6 %in% d$c6, o$c6, NA)
  libres <- d[!d$c6 %in% o$c6, ]
  for (i in which(is.na(dest) & !is.na(o$n) & o$n != "")) {
    cand <- libres[familia(libres$prov) == familia(o$prov[i]), ]
    h <- cand$c6[cand$n == o$n[i]]
    if (length(h) != 1 && nchar(o$n[i]) > 5) {
      dd <- adist(o$n[i], cand$n)
      h <- cand$c6[dd <= 2 & dd == min(dd)]
    }
    if (length(h) == 1) dest[i] <- h
  }
  dest
}

cantones_crear <- function() {
  p <- cantones_parroquias()
  nodo <- function(a, x, c6) paste(a, x$canton[match(c6, x$c6)], sep = ":")
  enlaces <- list()
  # 1982 -> 2010 por idparr11
  x <- p$`1982`; ok <- x$c11 %in% p$`2010`$c6
  enlaces$e82 <- data.frame(de = nodo(1982, x, x$c6[ok]), a = nodo(2010, p$`2010`, x$c11[ok]))
  for (par in list(c("1990", "2001"), c("2001", "2010"), c("2022", "2010"))) {
    o <- p[[par[1]]]; d <- p[[par[2]]]
    dest <- vincular_parroquias(o, d); ok <- !is.na(dest)
    enlaces[[paste(par, collapse = "_")]] <- data.frame(de = nodo(par[1], o, o$c6[ok]), a = nodo(par[2], d, dest[ok]))
  }
  enlaces$manual <- vinculos_manuales[, c("de", "a")]
  A <- unique(do.call(rbind, enlaces))

  todas <- do.call(rbind, lapply(p, function(x) x[, c("anio", "c6", "canton", "nombre", "pob")]))
  todas$nodo <- paste(todas$anio, todas$canton, sep = ":")
  g <- graph_from_data_frame(A, directed = FALSE, vertices = data.frame(nodo = unique(todas$nodo)))
  todas$grupo <- components(g)$membership[todas$nodo]

  # código y nombre de la unidad: sus cantones de 2022
  c22 <- censo_sql("SELECT valor, etiqueta FROM etiquetas WHERE tabla = 'censo2022' AND variable = 'CANTON'")
  c22 <- rbind(c22, data.frame(valor = "9003", etiqueta = "Manga del Cura"))
  c22$etiqueta <- texto_utf8(c22$etiqueta)
  g22 <- unique(todas[todas$anio == 2022, c("grupo", "canton")])
  g22 <- g22[order(g22$canton), ]
  cod <- tapply(g22$canton, g22$grupo, function(z) paste0("U", z[1]))
  nom <- tapply(g22$canton, g22$grupo, function(z) paste(c22$etiqueta[match(z, c22$valor)], collapse = " + "))
  can <- tapply(g22$canton, g22$grupo, paste, collapse = " ")
  todas$unidad <- unname(cod[as.character(todas$grupo)])
  todas$nombre_unidad <- unname(nom[as.character(todas$grupo)])
  todas$cantones_2022 <- unname(can[as.character(todas$grupo)])
  # sin unidad: zonas no delimitadas del norte en 1982
  todas$unidad[is.na(todas$unidad)] <- "excluida"
  # 1982 incompleto en la base
  todas$unidad[todas$anio == 1982 & todas$unidad %in% paste0("U", unidades_sin_1982)] <- "excluida"
  todas[order(todas$anio, todas$c6), c("anio", "c6", "canton", "nombre", "pob", "unidad", "nombre_unidad", "cantones_2022")]
}

# Ejecución ----
# options(censo.solo_funciones = TRUE) antes de source() para cargar solo las funciones

if (!isTRUE(getOption("censo.solo_funciones"))) {
  censo_conectar()
  cw <- cantones_crear()
  names(cw)[2] <- "parroquia"
  tab <- with(cw[cw$unidad != "excluida", ], tapply(pob, list(unidad, anio), sum))
  cat("Unidades:", nrow(tab), "\n")
  print(colSums(tab, na.rm = TRUE))
  dir.create(resultados_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(cw, cantones_archivo, row.names = FALSE, fileEncoding = "UTF-8")
  cat("Escrito", cantones_archivo, "\n")
  censo_desconectar()
}

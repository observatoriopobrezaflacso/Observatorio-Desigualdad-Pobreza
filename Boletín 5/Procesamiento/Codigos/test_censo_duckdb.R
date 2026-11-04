# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Pruebas de 00_crear_bases_censo.R y censo_duckdb.R
# boletín 5 - observatorio de políticas públicas
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
# Parte 1: censos ficticios pequeños (.sav creados aquí) -> siempre se ejecuta.
# Parte 2: bases reales en Drive -> solo para los censos cuya base ya existe.
#
# Ejecutar desde Boletín 5/Procesamiento/Codigos:
#   Rscript test_censo_duckdb.R

options(censo.solo_funciones = TRUE)
source("censo_duckdb.R")
source("00_crear_bases_censo.R")

n_fallas <- 0
prueba <- function(descripcion, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    message("  error: ", conditionMessage(e)); FALSE
  })
  cat(if (ok) "OK   " else "FALLA", descripcion, "\n")
  if (!ok) n_fallas <<- n_fallas + 1
}

# Parte 1: censos ficticios ----
cat("\n== Censos ficticios ==\n")

dir_falso <- tempfile("censo_falso_")
dir.create(file.path(dir_falso, "2010"), recursive = TRUE)
dir.create(file.path(dir_falso, "2022"), recursive = TRUE)

set.seed(1)
n_pob <- 2500
pob <- data.frame(
  I01 = labelled(sample(1:24, n_pob, TRUE), c(Azuay = 1, Pichincha = 17), label = "Provincia"),
  P01 = labelled(sample(1:2, n_pob, TRUE), c(Hombre = 1, Mujer = 2), label = "Sexo"),
  P03 = labelled_spss(c(sample(0:98, n_pob - 10, TRUE), rep(99, 10)),
                      c(`No responde` = 99), na_values = 99, label = "Edad"),
  NOMBRE = sample(c("a", "b"), n_pob, TRUE)
)
viv <- data.frame(V01 = labelled(sample(1:8, 300, TRUE), c(Casa = 1), label = "Tipo de vivienda"))

write_sav(pob, file.path(dir_falso, "2010", "poblacion.sav"))
sav_viv <- file.path(dir_falso, "2010", "vivienda.sav")
write_sav(viv, sav_viv)
zip(file.path(dir_falso, "2010", "vivienda.zip"), sav_viv, flags = "-jq")
unlink(sav_viv)

# 2022 sin metadatos, como una base creada desde csv
con22 <- dbConnect(duckdb::duckdb(), censo_archivo(2022, dir_falso))
dbWriteTable(con22, "censo2022", data.frame(P01 = c(1, 2, 2), GEDAD = c(6, 8, 15)))
dbDisconnect(con22, shutdown = TRUE)

# bloque pequeño para probar la lectura por partes (2500 = 6 bloques de 450 + resto)
suppressMessages(censo_crear_base(
  2010, fuentes = c(censo2010 = "poblacion.sav", censo2010_vivienda = "vivienda.zip"),
  dir = dir_falso, bloque = 450))

prueba("se crea Censo/2010/censo2010.duckdb",
       file.exists(censo_archivo(2010, dir_falso)))
prueba("no sobrescribe sin sobrescribir = TRUE", {
  antes <- file.mtime(censo_archivo(2010, dir_falso))
  suppressMessages(censo_crear_base(2010, fuentes = c(x = "no_existe.sav"), dir = dir_falso))
  file.mtime(censo_archivo(2010, dir_falso)) == antes
})

censo_conectar(c(2010, 2022), dir = dir_falso)

prueba("censo_tablas lista las tres tablas",
       setequal(censo_tablas()$tabla, c("censo2010", "censo2010_vivienda", "censo2022")))
prueba("lectura por bloques conserva todas las filas",
       censo_sql("SELECT COUNT(*) AS n FROM censo2010")$n == n_pob)
prueba("fila conserva el orden del .sav entre bloques", {
  db <- censo_sql("SELECT fila, P03 FROM censo2010 ORDER BY fila")
  identical(db$fila, as.double(seq_len(n_pob))) && all(db$P03 == as.numeric(pob$P03))
})
prueba("desde un .zip se lee la vivienda",
       censo_sql("SELECT COUNT(*) AS n FROM censo2010_vivienda")$n == 300)
prueba("los valores coinciden con el .sav", {
  db <- censo_sql("SELECT P01, COUNT(*) AS n FROM censo2010 GROUP BY P01 ORDER BY P01")
  all(db$n == as.vector(table(as.numeric(pob$P01))))
})
prueba("missing de usuario SPSS se guardan como código (99)",
       censo_sql("SELECT COUNT(*) AS n FROM censo2010 WHERE P03 = 99")$n == 10)
prueba("variables de texto se conservan",
       censo_sql("SELECT COUNT(DISTINCT NOMBRE) AS n FROM censo2010")$n == 2)
prueba("censo_variables trae etiqueta de variable",
       censo_variables("censo2010")$etiqueta[censo_variables("censo2010")$variable == "P01"] == "Sexo")
prueba("censo_variables busca por etiqueta",
       identical(censo_variables(buscar = "vivienda")$variable, "V01"))
prueba("censo_variables incluye 2022 sin etiquetas", {
  v <- censo_variables("censo2022")
  setequal(v$variable, c("P01", "GEDAD")) && all(is.na(v$etiqueta))
})
prueba("censo_etiquetas devuelve códigos ordenados", {
  e <- censo_etiquetas("censo2010", "P01")
  identical(e$valor, c("1", "2")) && identical(e$etiqueta, c("Hombre", "Mujer"))
})
prueba("SQL entre censos (UNION ALL 2010 y 2022)", {
  r <- censo_sql("
    SELECT 2010 AS anio, COUNT(*) AS mujeres FROM censo2010 WHERE P01 = 2
    UNION ALL
    SELECT 2022, COUNT(*) FROM censo2022 WHERE P01 = 2")
  nrow(r) == 2 && r$mujeres[r$anio == 2022] == 2
})
prueba("censo_sql acepta parámetros",
       censo_sql("SELECT COUNT(*) AS n FROM censo2010 WHERE I01 = ?", params = list(17))$n ==
         sum(pob$I01 == 17))
prueba("las bases quedan en solo lectura",
       inherits(try(censo_sql("DELETE FROM c2010.main.censo2010"), silent = TRUE), "try-error"))
prueba("censo_conectar avisa si falta un censo",
       inherits(try(censo_conectar(1982, dir = dir_falso), silent = TRUE), "try-error"))

censo_desconectar()
prueba("censo_sql falla después de desconectar",
       inherits(try(censo_sql("SELECT 1"), silent = TRUE), "try-error"))
unlink(dir_falso, recursive = TRUE)

# Parte 2: bases reales ----
cat("\n== Bases reales en", censo_dir, "==\n")

# población total publicada por el INEC (la base puede diferir levemente)
poblacion_inec <- c(`1982` = 8138974, `1990` = 9648189, `2001` = 12156608,
                    `2010` = 14483499, `2022` = 16938986)
anios_reales <- censo_anios[file.exists(censo_archivo(censo_anios))]

if (length(anios_reales) == 0) {
  cat("(no hay bases reales todavía; ejecutar 00_crear_bases_censo.R)\n")
} else {
  censo_conectar(anios_reales)
  for (a in anios_reales) {
    tabla <- paste0("censo", a)
    prueba(paste("existe la tabla", tabla), tabla %in% censo_tablas()$tabla)
    n <- censo_sql(sprintf("SELECT COUNT(*) AS n FROM %s", tabla))$n
    prueba(sprintf("%s: %s personas (INEC %s, tolerancia 1%%)", tabla,
                   format(n, big.mark = ","), format(poblacion_inec[[as.character(a)]], big.mark = ",")),
           abs(n / poblacion_inec[[as.character(a)]] - 1) < 0.01)
    prueba(paste(tabla, "tiene diccionario"),
           any(!is.na(censo_variables(tabla)$etiqueta)))
  }
  censo_desconectar()
}

# Parte 3: NBI armonizado (01_nbi_armonizado.R) ----
anios_nbi <- c(1982, 1990, 2001, 2010, 2022)
if (all(anios_nbi %in% anios_reales)) {
  cat("\n== NBI armonizado ==\n")
  source("01_nbi_armonizado.R")
  censo_conectar(anios_nbi)
  nbi_crear()
  r <- nbi_resumen()

  union <- censo_sql("SELECT anio, AVG((n = n_declarado)::INT) igual FROM nbi_hogar GROUP BY anio ORDER BY anio")
  for (i in seq_len(nrow(union))) {
    prueba(sprintf("%d: personas por hogar = tamaño declarado en %.2f%% de hogares", union$anio[i], 100 * union$igual[i]),
           union$igual[i] > if (union$anio[i] == 2001) 0.9999 else 0.99)
  }
  prueba(sprintf("2010: %.1f%% (oficial INEC 60.1%%, tolerancia 0.5)", r$pct_nbi[r$anio == 2010]),
         abs(r$pct_nbi[r$anio == 2010] - 60.1) <= 0.5)
  prueba(sprintf("2022: %.1f%% (oficial INEC 39.8%%, tolerancia 0.5)", r$pct_nbi[r$anio == 2022]),
         abs(r$pct_nbi[r$anio == 2022] - 39.8) <= 0.5)
  acuerdo22 <- censo_sql("SELECT AVG(((n_nbi >= 1)::INT = nbi_oficial)::INT) a FROM nbi_hogar WHERE anio = 2022")$a
  prueba(sprintf("2022: coincide con la variable NBI del INEC en %.2f%% de hogares", 100 * acuerdo22),
         acuerdo22 > 0.99)
  # la diferencia con 1982 viene sobre todo del pozo ciego (dándolo por satisfecho era 1 punto)
  prueba(sprintf("1982: %.1f%% vs NBI de la base original %.1f%% (tolerancia 2.5)",
                 r$pct_nbi[r$anio == 1982], r$pct_nbi_oficial[r$anio == 1982]),
         abs(r$pct_nbi[r$anio == 1982] - r$pct_nbi_oficial[r$anio == 1982]) <= 2.5)
  prueba("pobreza por NBI baja en cada censo", all(diff(r$pct_nbi) < 0))
  prueba("extrema <= NBI <= 100", all(r$pct_nbi_extrema <= r$pct_nbi & r$pct_nbi <= 100))
  censo_desconectar()
}

cat("\n", if (n_fallas == 0) "Todas las pruebas pasaron" else paste(n_fallas, "pruebas fallaron"), "\n")
if (n_fallas > 0) quit(status = 1)

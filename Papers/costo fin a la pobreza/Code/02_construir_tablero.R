# Inserta los resultados (resultados.json) en la plantilla HTML y genera el tablero final.
# Se trabaja a nivel de bytes para no alterar la codificación UTF-8 del documento.
leer <- function(p) rawToChar(readBin(p, "raw", file.size(p)))
plantilla <- leer("plantilla_tablero.html")
datos     <- leer("resultados.json")

marca <- "/*__DATOS__*/null"
stopifnot(grepl(marca, plantilla, fixed = TRUE))
html <- sub(marca, datos, plantilla, fixed = TRUE)

writeBin(charToRaw(html), "tablero_transferencias.html")
cat("Tablero generado:", normalizePath("tablero_transferencias.html"),
    sprintf("(%.0f KB)\n", file.size("tablero_transferencias.html")/1024))

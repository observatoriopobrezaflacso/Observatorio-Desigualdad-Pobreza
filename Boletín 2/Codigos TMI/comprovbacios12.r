# DIAGNÓSTICO - corre esto y pégame el output
pobreza_nbi <- read_excel("Pobreza_NBI_2022_Final.xlsx")
cat("Columnas del NBI:\n")
print(names(pobreza_nbi))
cat("\nPrimeras 5 filas:\n")
print(head(pobreza_nbi, 5))

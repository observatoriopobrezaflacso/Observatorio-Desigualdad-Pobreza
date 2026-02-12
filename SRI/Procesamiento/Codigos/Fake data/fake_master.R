setwd("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento")

source("Codigos/Fake data/Synthetic.R")
source("Codigos/Fake data/descriptives_yaml.R")
source("Codigos/Fake data/fake_from_yaml.R")

library(haven)

for (form_n in c(2, 7)) {
    for (year in c(2010:2020, 2024)) {
        print(paste0(form_n, "_", year))
        data_spec <- load_spec_yaml(paste0("Bases/Descriptivos/F10", form_n, "/F10", form_n, "_", year, ".txt"))
        fake_data <- fake_data_creation(data_spec, n = 1000, seed = 41, verbose = TRUE)
        write_dta(fake_data[names(fake_data) != "e_catastrofica"], paste0("Bases/Fake/F10", form_n, "/F10", form_n, "_", year, ".dta"))
    }
}



library(RStata)
# Set Stata path
options("RStata.StataPath" = "/Applications/Stata/StataSE.app/Contents/MacOS/stata-se")
options("RStata.StataVersion" = 18)
# Run a .do file
stata("Codigos/Fake data/fix_id_overlap.do", data.in = NULL, data.out = FALSE)


stata("Codigos/Renta/01_limpieza_merge.do", data.in = NULL, data.out = FALSE)

stata("Codigos/Renta/02_variables_ingreso.do", data.in = NULL, data.out = FALSE)

a <- read_dta("Bases/Fake/F102/F102_2010.dta")
a1 <- read_dta("Bases/Fake/F107/F107_2010.dta")
b <- read_dta("Bases/Fake/F102/F102_2011.dta")
b1 <- read_dta("Bases/Fake/F107/F107_2011.dta")
c <- read_dta("Bases/Fake/F102/F102_2012.dta")
c1 <- read_dta("Bases/Fake/F107/F107_2012.dta")
d <- read_dta("Bases/Fake/F102/F102_2013.dta")
d1 <- read_dta("Bases/Fake/F107/F107_2013.dta")

table(a$CEDULA_PK %in% b$CEDULA_PK)
table(b$CEDULA_PK %in% c$CEDULA_PK)
table(c$CEDULA_PK %in% d$CEDULA_PK)


a_j <- left_join(a, a1 %>% mutate(a = 1), by = c("CEDULA_PK" = "CEDULA_PK_empleado"))

table(is.na(a_j$a))


table(a$CEDULA_PK == "")

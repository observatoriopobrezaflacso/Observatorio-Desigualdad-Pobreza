library(haven)
library(srvyr)
library(dplyr)
library(survey)

setwd('/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad')

c <- readRDS('Bases/ENDI/R2/BDD_ENDI_R2_f2_mef.rds')

for (i in 1:15) {
c <- c %>% mutate(!!sym(paste0("hijo_muerto_", i)) := 
                  if_else(.data[[paste0("f2_s2_235_c_", i)]] == 2, 1, 0))

c <- c %>% mutate(!!sym(paste0("hijo_nino_muerto_", i)) := 
                  if_else(.data[[paste0("f2_s2_235_f_anios_", i)]] <= 1, 1, 0))

}


c <- c %>% mutate( 
                  !!sym(paste0("hijo_nino_muerto_total")) := 
                  rowSums(select(., starts_with("hijo_nino_muerto_")), 
                          na.rm = TRUE)
                          )

c <- c %>% mutate( 
                  !!sym(paste0("hijo_muerto_total")) := 
                  rowSums(select(., starts_with("hijo_muerto_")), 
                          na.rm = TRUE)
                          )                          

c 

print(c %>% select(starts_with("hijo_muerto_")) %>% head())

c %>% select(starts_with("hijo_"),starts_with("f2_s2_235_f_anios_")) %>% View()



d <- readRDS('Bases/ENDI/R2/BDD_ENDI_R2_f1_personas.rds')


e <- c %>%left_join(d %>% select(f1_s1_15_1, id_mef, pobreza), by = "id_mef") 


survey_design <- e %>% 
as_survey_design(ids = "id_upm",
strata = "estrato",
weights = "fexp")

survey_design %>% 
mutate(n = 1) %>%
summarize(total = survey_total(hijo_nino_muerto_total, na.rm = TRUE), 
          n = survey_total(n, na.rm = TRUE)) %>%
          mutate(tmf = (total / n)*1000)




survey_design %>% 
  mutate(
    denom = 1,
    superior = case_when(
      f1_s1_15_1 %in% c(1:9) ~ 0,
      f1_s1_15_1 %in% c(10:13) ~ 1
    )
  ) %>%
  group_by(superior) %>%
  summarize(
    total = survey_total(hijo_nino_muerto_total, na.rm = TRUE),
    n = survey_total(denom, na.rm = TRUE),
    tmf = survey_ratio(hijo_nino_muerto_total, denom, vartype = c("se", "cv"), na.rm = TRUE)
  ) %>%
  mutate(tmf = tmf * 1000)


graph_data <- survey_design %>% 
  mutate(
    denom = 1,
  ) %>%
  group_by(pobreza) %>%
  summarize(
    total = survey_total(hijo_nino_muerto_total, na.rm = TRUE),
    n = survey_total(denom, na.rm = TRUE),
    tmf = survey_ratio(hijo_nino_muerto_total, denom, vartype = c("se", "cv"), na.rm = TRUE)
  ) %>%
  mutate(tmf = tmf * 1000) %>% 
  filter(!is.na(pobreza))


plot <- graph_data %>% 
ggplot(aes(x = pobreza, y = tmf)) +
geom_col(fill = "steelblue") +
geom_text(aes(label = paste0(round(tmf, 2))), vjust = -0.3, size = 4.5) +
labs(title = "Tasa de mortalidad infantil (<1 año) por nivel de pobreza de la parroquia",
subtitle = "Ecuador 2024 - Tasa por 1,000 nacidos vivos",
x = "Pobreza por ingresos",
y = "Tasa por 1,000 nacidos vivos") +
theme_minimal()

print(plot)
ggsave(file.path(output_dir, "mortalidad_infantil_pobreza.png"), plot, width = 9, height = 6, dpi = 300, bg = "white")

# Identificar los outliers verdes
analisis_grafico_v2 %>%
    filter(nivel_pobreza == "Baja Pobreza", tmi_num > 20) %>%
    select(Provincia, Canton, Parroquia, cod_parroquia, tmi_num, nac_num, nbi_num) %>%
    arrange(desc(tmi_num))

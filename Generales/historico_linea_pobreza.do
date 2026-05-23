clear all
set more off

global ipc "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/IPC/"

global lpob "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/lineas_pobreza"


local ipcfile "$ipc/SERIE HISTORICA IPC_03_2026.xls"
local factor  = 56.64 / 70.2628

import excel "`ipcfile'", sheet("1. ÍNDICE") cellrange(A6:M63) clear

rename A ano
rename B enero
rename C febrero
rename D marzo
rename E abril
rename F mayo
rename G junio
rename H julio
rename I agosto
rename J septiembre
rename K octubre
rename L noviembre
rename M diciembre

destring ano, replace force
drop if missing(ano)

gen double ipc_noviembre     = noviembre
gen double linea_pobreza_dic = ipc_noviembre * `factor'

gen mes   = 12
gen fecha = ym(ano, mes)
format fecha %tm

keep ano mes fecha ipc_noviembre linea_pobreza_dic
drop if missing(linea_pobreza_dic)

sort ano
list ano ipc_noviembre linea_pobreza_dic, sep(0)

save "$lpob/lineas_de_pobreza_historica.dta", replace

export excel using "$lpob/lineas_de_pobreza_historica.xlsx", replace firstrow(var)

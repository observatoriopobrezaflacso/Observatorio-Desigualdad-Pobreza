global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"

global enemdu_diciembres "$user_root/Bases/ENEMDU/Originales/Diciembres/"

global bases_90s "$enemdu_diciembres/1990-1999"
global bases_2000_2006 "$enemdu_diciembres/2000-2006"
global bases_2007_2017 "$enemdu_diciembres/2007-2017"
global bases_2018_presente "$enemdu_diciembres/2018-presente/Trimestrales"


local texto_buscar "tiene RUC"

forval y = 2007/2024 {

    di "************** `y' ********************"

	if (inrange(`y', 1990, 1999)) local dir_bases $bases_90s
	if (inrange(`y', 2000, 2006)) local dir_bases $bases_2000_2006
	if (inrange(`y', 2007, 2017)) local dir_bases $bases_2007_2017
	if (inrange(`y', 2018, 2025)) local dir_bases $bases_2018_presente

	use "`dir_bases'/empleo`y'.dta", clear 

    local vars_buscadas ""        // reset explicitly each iteration

    lookfor "`texto_buscar'"

    if ("`r(varlist)'" != "") {
        local vars_buscadas = r(varlist)
		foreach var of local vars_buscadas {
			tab `var'
			tab `var', nol
		}
		
		
    }
    else di "No hay variable en `y'"

}


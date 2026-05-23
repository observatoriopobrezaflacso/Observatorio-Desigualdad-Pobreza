global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"

global enemdu_diciembres "$user_root/Bases/ENEMDU/Originales/Diciembres/"

global bases_90s "$enemdu_diciembres/1990-1999"
global bases_2000_2006 "$enemdu_diciembres/2000-2006"
global bases_2007_2017 "$enemdu_diciembres/2007-2017"
global bases_2018_presente "$enemdu_diciembres/2018-presente/Trimestrales"


local texto_buscar "region"
local texto_buscar2 ""

forval y = 2001/2025 {
*foreach y in 2024 {

    di "************** `y' ********************"

	if (inrange(`y', 1990, 1999)) local dir_bases $bases_90s
	if (inrange(`y', 2000, 2006)) local dir_bases $bases_2000_2006
	if (inrange(`y', 2007, 2017)) local dir_bases $bases_2007_2017
	if (inrange(`y', 2018, 2025)) local dir_bases $bases_2018_presente

	use "`dir_bases'/empleo`y'.dta", clear 
	
    local vars_buscadas ""        // reset explicitly each iteration

    lookfor "`texto_buscar'"
	local varlist1 = "`r(varlist)'"
	
	*lookfor "`texto_buscar2'"
	local varlist2 = "`r(varlist)'"
	
	 
	 di "`varlist1' `varlist2'"
	 
	
    if ("`varlist1'" != "") {
        local vars_buscadas =  "`varlist1'"
		foreach var of local vars_buscadas {
			 *tab `var' `varlist2' if condact != 9 & condact != 0 [iw = fexp], nofreq row col
			tab `var'
			tab `var', nol
			*replace `var' = . if `var' <= 0 | `var' >= 99999
			*sum `var'
		}
		
		
    }
    else di "No hay texto buscado en `y'"

}


s


local texto_buscar "RUC"

forval y = 1990/2001 {
*foreach y in 2018 {

    di "************** `y' ********************"

	if (inrange(`y', 1990, 1999)) local dir_bases $bases_90s
	if (inrange(`y', 2000, 2006)) local dir_bases $bases_2000_2006
	if (inrange(`y', 2007, 2017)) local dir_bases $bases_2007_2017
	if (inrange(`y', 2018, 2025)) local dir_bases $bases_2018_presente

	use "`dir_bases'/empleo`y'.dta", clear 

	
	
    local vars_buscadas ""        // reset explicitly each iteration

    lookfor "`texto_buscar'"
*     describe `texto_buscar', varlist
*	 local r(varlist) = r(varlist)
	 
	 di "`r(varlist)'"
	 
    if ("`r(varlist)'" != "") {
        local vars_buscadas = r(varlist)
		foreach var of local vars_buscadas {
			sum `var'
			tab `var', nol
		}
		
		
    }
    else di "No hay texto buscado en `y'"

}






local num_looked = 2410


forval y = 1990/2025 {
*foreach y in 2024 {

    di "************** `y' ********************"

	if (inrange(`y', 1990, 1999)) local dir_bases $bases_90s
	if (inrange(`y', 2000, 2006)) local dir_bases $bases_2000_2006
	if (inrange(`y', 2007, 2017)) local dir_bases $bases_2007_2017
	if (inrange(`y', 2018, 2025)) local dir_bases $bases_2018_presente

	use "`dir_bases'/empleo`y'.dta", clear 

	if (inrange(`y', 1990, 2006)) tab rama if rama == `num_looked'
	if (`y' >= 2007) tab p40 if rama ==  `num_looked'
  
}












* Convertir archivos sav a dta

global wd "G:\Mi unidad\Bases\ENEMDU - copia\2025\12"
cd "$wd"
macro drop _all

local myfiles: dir "$wd" files "*.sav"
di `myfiles'

foreach files of local myfiles {    
	import spss using "`files'", clear	 
	local x = subinstr("`files'", ".sav",".dta", .)
    save "`x'" , replace
	erase "`files'"
} 




* Buscar variables comunes a todas las bases

macro drop _all
global wd "G:/Mi unidad/Procesamiento/Bases"
cd "$wd"            

forval i = 2025/2025{

forval j = 1/12 {
if (strlen("`j'") == 1) local j2 = "0`j'"
else local j2 = "`j'"

mata : st_numscalar("OK", direxists("ENEMDU/`i'/`j2'"))
di "`i'/`j2'"
di scalar(OK)

if (scalar(OK) == 1) {
    
local myfiles: dir "$wd/ENEMDU/`i'/`j2'" files "*.sav"
di `myfiles'

foreach files of local myfiles {   
di "ENEMDU/`i'/`j2'/`files'" 
    import spss using "ENEMDU/`i'/`j2'/`files'", clear   
    local x = subinstr("`files'", ".sav",".dta", .)
	capture mkdir "ENEMDU - copia/`i'"
	capture mkdir "ENEMDU - copia/`i'/`j2'"
    save "ENEMDU - copia/`i'/`j2'/`x'" , replace
	di "asd2"
} 
    
   }
  }
 }

di "`base'"

stop







* Buscar variables comunes a todas las bases

macro drop _all
global wd "G:\Mi unidad\Bases\ENEMDU - copia"
cd "$wd"            

local base ""

forval i = 2020/2023 {

forval j = 1/12 {
if (strlen("`j'") == 1) local j2 = "0`j'"
else local j2 = "`j'"

mata : st_numscalar("OK", direxists("`i'/`j2'"))
di "`i'/`j2'"
di scalar(OK)

if (scalar(OK) == 1) {
    
local myfiles: dir "$wd/`i'/`j2'" files "*.dta", respectcase

foreach files of local myfiles {   
    di "`files'" 
    use "`i'/`j2'/`files'" in 1, clear
    lookfor id_hogar
    if ("`r(varlist)'" != "") local base "`base'" "  " "`files'"
    }
    
   }
  }
 }

di "`base'"

stop



* Renombrar todas las variables con minúsculas

macro drop _all
global wd "G:\Mi unidad\Bases\ENEMDU - copia"
cd "$wd"            

local base ""

forval i = 2014/2023 {

forval j = 1/12 {
if (strlen("`j'") == 1) local j2 = "0`j'"
else local j2 = "`j'"

mata : st_numscalar("OK", direxists("`i'/`j2'"))
di "`i'/`j2'"
di scalar(OK)

if (scalar(OK) == 1) {
    
local myfiles: dir "$wd/`i'/`j2'" files "*.dta", respectcase

foreach files of local myfiles {   
    use "`i'/`j2'/`files'", clear
    rename *, lower
    save "`i'/`j2'/`files'", replace
    }
    
   }
  }
 }


stop











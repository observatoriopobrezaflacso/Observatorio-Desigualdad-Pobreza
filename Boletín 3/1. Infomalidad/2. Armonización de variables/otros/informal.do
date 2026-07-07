

* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global bases "$user_root/Bases"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"

global important_variable informal_new


* SBUs (2000-2025)
* https://contenido.bce.fin.ec/documentos/Administracion/bi_menuSalarios.html#

import delimited "$salarios/Salario unificado y componentes salariales.csv", clear
encode componentesalarial, gen(componente)
drop componentesalarial 
keep if componente == 6 & mes == "Diciembre"
rename (año valor) (anio salario_min)
replace salario_min = subinstr(salario_min, ",", ".", .)
destring salario_min, replace
keep anio salario_min
tempfile tmp
save `tmp'


* Ingreso mínimo legal (SMV + bonificaciones:)
* https://contenido.bce.fin.ec/documentos/PublicacionesNotas/Catalogo/IEMensual/m1810/m1810_55.htm#:~:text=Table_content:%20header:%20%7C%20PERIODO%20%7C%20Salario%20M%C3%ADnimo,1991%20%7C%20Salario%20M%C3%ADnimo%20Vital:%2040000%20%7C

import delimited "$salarios/SMV + bonificaciones.csv", clear
keep in 12/21
rename (periodo total) (anio salario_min)
keep anio salario_min
tempfile tmp2
destring anio, replace
append using `tmp'

tempfile tm2
save `tmp2'

list 



use "$bases_2007_2017/empleo2007.dta" in 1, clear 
destring area, replace
drop in 1

tempfile informal_acumulado
save `informal_acumulado', replace

foreach y of numlist 2007(1)2025 {

di "*****************   `y'   ************************"

	use "$raw/empleo`y'.dta", clear 
	
	rename *, lower
	
	*gen anio = `y'
		
	
	if (`y' == 2014) {
		rename peamsiu  secemp 
		replace secemp = . if inlist(secemp, 0, 4)	
	}
	
	gen informal_new = .
	replace informal_new = 1 if inlist(secemp, 2, 4) 
	replace informal_new = 0 if !inlist(secemp, 2, 4)  
	
	*do "$gh/Generales/id_persona_loop.do"
	
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 
	
    keep id_persona $important_variable anio `area_var'
	
	append using `informal_acumulado'
	
    keep id_persona $important_variable anio `area_var'

	save `informal_acumulado', replace
	
	count if anio == .
	
	local anio_mis_n = r(N)
	
	assert `anio_mis_n' == 0
	
*    save "$procesado/ingresos_pc/ing_perca_`y'_nac_precios2000.dta", replace

}


save "$out/historico_informal.dta", replace

s

s


tab p27 
tab p27 if p24 < 40

tab d_d
tab d_d if p24 < 40



/*

tostring idhogar, replace
bysort idhogar: gen i = _n
gen len = strlen(idhogar)
gen zero = "0"

egen idhogar1 = concat(zero zero zero idhogar) if len == 1
egen idhogar2 = concat(zero zero idhogar) if len == 2
egen idhogar3 = concat(zero idhogar) if len == 3

replace idhogar = idhogar1 if len == 1
replace idhogar = idhogar2 if len == 2
replace idhogar = idhogar3 if len == 3

gen len2 = strlen(idhogar)
bysort idhogar: gen i = _n
egen id = concat(idhogar i)
* Create subset of those who answered ratmeh1
preserve
keep if ratmeh1 != .
tempfile sub
save `sub'
restore

preserve 
keep if ratmeh !=. 

* Merge to verify subset relation
merge 1:1 id using `sub'

* Tabulate merge results
tab _merge

restore
*/







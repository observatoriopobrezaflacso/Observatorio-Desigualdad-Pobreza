

clear

* ── Recover 'area' from each yearly empleo file ──────────────────────────────

global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global enemdu_diciembres "$user_root/Bases/ENEMDU/Originales/Diciembres/"
global bases_90s         "$enemdu_diciembres/1990-1999"
global bases_2000_2006   "$enemdu_diciembres/2000-2006"
global bases_2007_2017   "$enemdu_diciembres/2007-2017"
global bases_2018_presente "$enemdu_diciembres/2018-presente/Mensuales"
global out "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Mensuales"
global ingpc "$user_root/Bases/ENEMDU/Procesadas/ingresos_pc/Nacional"

cap mkdir "$out"

gen id_persona = .
tostring id_persona, replace
gen anio = .

tempfile id_persona_cumulative
save `id_persona_cumulative'

* ── Loop: extract id_persona + anio + area from each yearly file ──────────────
*foreach y in 2017 {
forval y =2017/2025 {

    di "************** `y' ********************"


    use "$ingpc/ing_perca_`y'_nac_precios2000.dta", clear
	
	cap gen id = _n
	cap gen anio = `y'
	
	rename *, lower

	gen cero1= "0"
	gen cero2= "00"
	gen cero3= "000"
	gen cero4= "0000"
	gen cero5= "00000"

	
	if inrange(`y', 1990, 2000) local vars ciudad zona sector vivienda ///
									  hogar formul persona
									  
	if inrange(`y', 2001, 2002) local vars ciudad zona sector vivienda ///
									  hogar persona
									  
	if inrange(`y', 2003, 2006) local vars ciudad zona sector panelm vivienda ///
									  hogar persona
								  
	if inrange(`y', 2007, 2017) local vars ciudad zona sector panelm vivienda ///
									  hogar p01

	if inrange(`y', 2018, 2025) local vars ciudad conglomerado panelm vivienda ///
									  hogar p01
									  
	capture confirm variable id_persona	
	if !_rc local id_var id_persona

	capture confirm variable area	
	if !_rc local area_var area
	else    local area_var 
	

	capture confirm variable p02	
	if !_rc rename p02 sexo
	
	capture confirm variable p03	
	if !_rc rename p03 edad

	
	*keep `vars'	cero* anio 	`id_var' `area_var'	sexo				  
									  
	foreach x of local vars  {

	    tostring `x', replace force 
		
		if "`x'" == "ciudad"  {
		
		egen ciudad_a = concat(cero1 ciudad) if strlen(ciudad) == 5
		replace ciudad = ciudad_a if strlen(ciudad) == 5 
		drop ciudad_a
		
		}
	
		if "`x'" == "zona"  {
		
		egen zona_a = concat(cero2 zona) if strlen(zona) == 1
		replace zona = zona_a if strlen(zona) == 1 
		drop zona_a

		egen zona_a = concat(cero1 zona) if strlen(zona) == 2
		replace zona = zona_a if strlen(zona) == 2
		drop zona_a
		}

		if "`x'" == "sector"  {

		egen sector_a = concat(cero2 sector) if strlen(sector) == 1
		replace sector = sector_a if strlen(sector) == 1
		drop sector_a
		}

		if "`x'" == "panelm"  {

		egen panelm_a = concat(cero2 panelm) if strlen(panelm) == 1
		replace panelm = panelm_a if strlen(panelm) == 1
		drop panelm_a

		egen panelm_a = concat(cero1 panelm) if strlen(panelm) == 2
		replace panelm = panelm_a if strlen(panelm) == 2
		drop panelm_a

		}

		if "`x'" == "vivienda"  {

		egen vivienda_a = concat(cero1 vivienda) if strlen(vivienda) == 1
		replace vivienda = vivienda_a if strlen(vivienda) == 1
		drop vivienda_a

		}

		if "`x'" == "p01"  {

		egen p01_a = concat(cero1 p01) if strlen(p01) == 1
		replace p01 = p01_a if strlen(p01) == 1
		drop p01_a

		}
		
		if "`x'" == "persona"  {
		rename persona p01	
		egen p01_a = concat(cero1 p01) if strlen(p01) == 1
		replace p01 = p01_a if strlen(p01) == 1
		drop p01_a
		rename p01 persona 

		}
		
	*	save "`files'", replace
	}
	
	drop cero*


	if (inrange(`y', 1990, 2000)) {
		egen id_persona = concat(ciudad zona sector vivienda hogar formul persona)
	}
	
	if (inrange(`y', 2001, 2002)) {
    	egen id_persona = concat(ciudad zona sector vivienda hogar persona)
	}


	if (inrange(`y', 2003, 2006)) {
        egen id_persona = concat(ciudad zona sector panelm vivienda hogar persona)
	}
	
	if (inrange(`y', 2007, 2013)) {
        egen id_persona = concat(ciudad zona sector panelm vivienda hogar p01)
	}
	
	if (inrange(`y', 2014, 2017)) {
        egen id_persona2 = concat(ciudad zona sector panelm vivienda hogar p01)
	}


	if (inrange(`y', 2018, 2025)) {
        egen id_persona2 = concat(ciudad conglomerado panelm vivienda hogar p01)
	}

	
	* Cuando una persona tiene el mismo id_persona, no se lo borra; se crea
	* una variable persona2 para reconocer que pertenecen al mismo hogar pero 
	* son personas distintas. 
	
	* En 1998 hay ~50 personas que tienen el mismo id_persona. Los datos de las variables
	* sugieren que se trata del mismo hogar, pero no es la misma persona.
	
	* En 2001 se se aplica solo 1 observación.  
	
	* En 2002, se hace esto en 9 observaciones que tienen datos muy similares en todas las variables.
	
	* En 2003 se se aplica solo 1 observación. Los datos no son muy similares. 

	
    *if (inlist(`y', 2002, 2003)) duplicates drop id_persona, force
	
	capture isid id_persona
	
	if _rc {
		duplicates tag id_persona, gen(dup)
		tab dup
		order id_persona, first
		sort id_persona
		*br if dup > 0
		
		bysort id_persona: gen persona2 = _n
		tostring persona2, replace
		egen id_persona2 = concat(id_persona persona2)
		rename id_persona id_persona_old
		rename id_persona2 id_persona
		
		order id_persona_old id_persona
		
		*br if dup > 0
		duplicates report id_persona

	}
	
	gen provincia = substr(id_persona, 1, 2)
	
	save "$out/empleo`y'", replace
	
	capture confirm variable id_persona2
	if !_rc local id_var2 id_persona2 
	
	
	capture confirm variable area	
	if !_rc destring area, replace

	
	isid id_persona
	*keep id_persona anio `id_var2'  `area_var'	sexo
	tostring id_persona, replace
	
		
}


save "$out/serie_1990_2025.dta", replace




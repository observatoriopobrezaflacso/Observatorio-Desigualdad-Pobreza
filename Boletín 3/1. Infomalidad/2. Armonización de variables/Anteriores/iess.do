*==============================================================================*
* HARMONIZACIÓN: AFILIACIÓN AL IESS (1990-2024)                                *
* affiliated_iess = 1 si la persona está afiliada al IESS, 0 en otro caso      *
*==============================================================================*


* Definición de rutas globales para facilitar la portabilidad del código
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global out "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global gh "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/"
global out_plot "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"

global important_variable affiliated_iess

use "$raw/empleo1990.dta" in 1, clear 
destring area, replace
drop in 1

tempfile iess_acumulado
save `iess_acumulado', replace

foreach y of numlist 1990(1)2025 {

    di "*****************   `y'   ************************"

    use "$raw/empleo`y'.dta", clear 
    
    rename *, lower
    
    *gen anio = `y'
    
    gen affiliated_iess = 0
    
    *--------------------------------------------------------------------------*
    * PERÍODO 1990-2000: variable 'iess' binaria (1=sí, 2=no)
    *--------------------------------------------------------------------------*
    if (inrange(`y', 1990, 2000)) {
        capture confirm variable iess
        if !_rc {
            replace affiliated_iess = 1 if iess == 1
            replace affiliated_iess = . if missing(iess)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2001-2006: 'iess' multicategórica
    * IESS general = 2, IESS campesino = 3
    *--------------------------------------------------------------------------*
    if (inrange(`y', 2001, 2006)) {
        capture confirm variable iess
        if !_rc {
            replace affiliated_iess = 1 if inlist(iess, 2, 3)
            replace affiliated_iess = . if missing(iess)
        }
    }
    
    *--------------------------------------------------------------------------*
    * PERÍODO 2007-2024: variables p05a y p05b
    * IESS general = 1, IESS voluntario = 2, IESS campesino = 3, ISSFA/ISSPOL = 4
    *--------------------------------------------------------------------------*
    if (`y' >= 2007) {
        capture confirm variable p05a
        local has_p05a = !_rc
        capture confirm variable p05b
        local has_p05b = !_rc
        
        if `has_p05a' {
            replace affiliated_iess = 1 if inlist(p05a, 1, 2, 3)
        }
        if `has_p05b' {
            replace affiliated_iess = 1 if inlist(p05b, 1, 2, 3)
        }
        if `has_p05a' & `has_p05b' {
            replace affiliated_iess = . if missing(p05a) & missing(p05b)
        }
        else if `has_p05a' {
            replace affiliated_iess = . if missing(p05a)
        }
		s
    }
    
    label define lbl_iess 0 "No afiliado al IESS" 1 "Afiliado al IESS", replace
    label values affiliated_iess lbl_iess
    label variable affiliated_iess "Afiliación al IESS (armonizado)"
    
    * do "$gh/Generales/id_persona_loop.do"
    
	capture confirm variable area 
	if  !_rc {
		      local area_var area
			  destring area, replace 
			  
	}
	else      local area_var 
	
    keep id_persona $important_variable anio `area_var' fexp
	
	append using `iess_acumulado'
	
    keep id_persona $important_variable anio `area_var' fexp
        
    save `iess_acumulado', replace
    
    di "*************** `y' *****************"
    
    count if id_persona == ""
    local n = r(N)
    
    if (`n' != 0) asd

}

save "$out/historico_iess.dta", replace

use "$out/historico_iess.dta", clear

* Verificación
tab anio affiliated_iess [iw = fexp], nofreq row missing



preserve
    collapse (mean) $important_variable, by(anio area)
    list
    format $important_variable %9.2f
    keep if area == 1
    rename $important_variable ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    collapse (mean) $important_variable, by(anio)
    format $important_variable %9.2f
    rename $important_variable ${important_variable}_nac
    merge 1:1 anio using `urb', nogen
    list
twoway (line ${important_variable}_nac anio)  ///
           (line ${important_variable}_urb anio if anio >= 2000), ///
           legend(order(1 "Nacional" 2 "Urbano"))  ///
           yscale(range(0 1)) ylabel(#5, format(%9.2f))
restore

graph export "$out_plot/historico_{$important_variable}.pdf", replace



*==============================================================================*
*0. IDENTIFICACIÓN DE VARIABLES IMPORTANTES
*==============================================================================*
clear all
set more off
set dp comma
use enemdu_persona_201912.dta, clear //Base homologada de personas
* IDENTIFICO Hijos casados/unión libre
gen hijocasado=1 if p04==3 & ( p06==1 | p06==5)
egen h_hijcas=sum(hijocasado), by(id_hogar)
* IDENTIFICO yerno/nuera casados/unión libre
gen yernonuera=1 if p04==4 & ( p06==1 | p06==5)
egen h_yernue=sum(yernonuera), by(id_hogar)
*IDENTIFICO nietos
gen nieto=1 if p04==5
egen h_nieto=sum(nieto), by(id_hogar)
*==============================================================================*
*1. NÚCLEOS DE HOGAR
*==============================================================================*
* NÚCLEO 1. jefe, cónyuge, hijos menores den18 años e hijos de cualquier edad incapacitados
gen nucleo=1 if p04==1 | p04==2 | (p04==3 & p03<18)
replace nucleo=1 if (p04==3 & p36==5)
* NÚCLEO 2. 1 solo hijo/a casado/a, 1 solo yerno, 1 sola nuera y nietos menores de 18 años y nietos de cualquier edad con discapacidad
replace nucleo=2 if hijocasado==1 & h_hijcas==1 & h_yernue==1
replace nucleo=2 if yernonuera==1 & h_hijcas==1 & h_yernue==1
replace nucleo=2 if (nieto==1 & p03<18 ) & h_hijcas==1 & h_yernue==1
replace nucleo=2 if (nieto==1 & p36==5) & h_hijcas==1 & h_yernue==1
***************************************
* IDENTIFICACIÓN DE LOS NÚCLEOS
****************************************
capture egen idnucleo=concat(id_hogar nucleo)
*==============================================================================*
* 2. CREACIÓN DE LA VARIABLE DE SEGURO (AFILIACIÓN)
*==============================================================================*
* Aporte a seguridad social
gen seguros=.
replace seguros=1 if p61b1==1
replace seguros=2 if seguros==. & p61b1==2
replace seguros=3 if seguros==. & p61b1==3
replace seguros=4 if seguros==. & p61b1==4
*============================================================
* 2.1 IESS Seguro General
*============================================================
*Para núcleo 1
gen seg1=1 if seguros==1 & (p04==1)
replace seg1=1 if seg1==. & seguros==1 & (p04==2)
egen seguro1=max(seg1) if nucleo==1, by(idnucleo)
*Para núcleo 2
gen seg2=1 if seguros==1 & (h_hijcas==1 | h_yernue==1)
egen seguro2=max(seg2) if nucleo==2, by(idnucleo)
gen IESS_general=1 if seguro1==1
replace IESS_general=1 if seguro2==1


*============================================================
* 2.2 IESS Seguro Voluntario
*============================================================
*Para núcleo 1
gen seg3=1 if seguros==2 & p04==1
replace seg3=1 if seg3==. & seguros==2 & p04==2
egen seguro3=max(seg3) if nucleo==1, by(idnucleo)
*Para núcleo 2
gen seg4=1 if seguros==2 & (h_hijcas==1 | h_yernue==1)
egen seguro4=max(seg4) if nucleo==2, by(idnucleo)
gen IESS_voluntario=1 if seguro3==1
replace IESS_voluntario=1 if seguro4==1

*============================================================
* 2.3 Seguro Campesino
*============================================================
gen seg5=1 if seguros==3 & p04 ==1
replace seg5=1 if seg5==. & seguros==3 & p04==2
egen Seguro_Campesino =max(seg5) if inrange(p04,1,7) & (IESS_general!=1 & IESS_voluntario!=1), by (id_hogar)
*============================================================
* 2.4 ISSFA e ISSPOL
*============================================================
*Para núcleo 1
gen seg6=1 if seguros==4 & p04==1
replace seg6=1 if seg6==. & seguros==4 & p04==2
egen seguro6=max(seg6) if nucleo==1, by(idnucleo)
*___________________________________________________________________
* Se crea un núcleo solo ISSFA para los hijos hasta 25 años y que estén estudiando
gen seg6_fa = (grupo1 == 10) & (p04 == 1 | p04==2) & p61b1 == 4
egen fa = total(seg6_fa), by(id_hogar)
gen nucFA = 1 if fa == 1 & p04 == 3 & inrange(p03,18,25) & p07 == 1
*Hay tres casos PERO dos de ellos declaran tener ISSFA en la p05a, así que solo se recupera 1 caso
replace seguro6 = 1 if nucFA == 1
*____________________________________________________________________
*Para núcleo 2
gen seg7=1 if seguros==4 & (h_hijcas==1 | h_yernue==1)
egen seguro7=max(seg7) if nucleo==2, by(idnucleo)
gen ISSFA_ISSPOL=1 if seguro6==1
replace ISSFA_ISSPOL=1 if seguro7==1
*============================================================
* 2.5 JUBILADOS
*============================================================
*NÚCLEO 1
*Para jubilados menores de 65 años no divorciados
gen seg8=1 if (p61b1==5 | p61b1==6) & p72a==1 & (p03<65 & p06!=3) & nucleo==1 & (p04==1 | p04==2) & (IESS_general!=1 & Seguro_Campesino!=1 & IESS_voluntario!=1 & ISSFA_ISSPOL!=1)
*Para jubilados de 65 años o más (todos)
replace seg8=1 if (p61b1==5 | p61b1==6) & p72a==1 & p03>=65 & nucleo==1 & (p04==1 | p04==2) & (IESS_general!=1 & Seguro_Campesino!=1 & IESS_voluntario!=1 & ISSFA_ISSPOL!=1)
egen seguro8=max(seg8) if nucleo==1, by(idnucleo)
*NÚCLEO 2
*Para jubilados menores de 65 años no divorciados
gen seg9=1 if (p61b1==5 | p61b1==6) & p72a==1 & (p03<65 & p06!=3) & nucleo==2 & (h_hijcas==1 | h_yernue==1) & (IESS_general!=1 & Seguro_Campesino!=1 & IESS_voluntario!=1 & ISSFA_ISSPOL!=1)
*Para jubilados de 65 años o más (todos)
replace seg9=1 if (p61b1==5 | p61b1==6) & p72a==1 & p03>=65 & nucleo==2 & (h_hijcas==1 | h_yernue==1) & (IESS_general!=1 & Seguro_Campesino!=1 & IESS_voluntario!=1 & ISSFA_ISSPOL!=1)
egen seguro9=max(seg9) if nucleo==2, by(idnucleo)
gen Jubilado=1 if seguro8==1
replace Jubilado=1 if seguro9==1
*Recupero jubilados que no estén en el nucleo1 o nucleo2
replace Jubilado=1 if p72a==1 & p03>=65 & (seguro8==. & seguro9==.) & (IESS_general!=1 & IESS_voluntario==1 & Seguro_Campesino!=1 & ISSFA_ISSPOL!=1)
replace Jubilado=1 if p72a==1 & (p03<65 & p06!=3) & (seguro8==. & seguro9==.) & (IESS_general!=1 & IESS_voluntario==1 & Seguro_Campesino!=1 & ISSFA_ISSPOL!=1)
*==============================================================================*
* 3 VARIABLE AGREGADA (recupero casos con p05)
*==============================================================================*
replace seguros=1 if seguros==. & IESS_general==1
replace seguros=1 if (p05a==1 | p05b==1)
replace seguros=2 if seguros==. & IESS_voluntario==1
replace seguros=2 if p05a==2
replace seguros=3 if seguros==. & Seguro_Campesino==1
replace seguros=3 if p05a==3
replace seguros=4 if seguros==. & (ISSFA_ISSPOL==1 | nucFA==1)
replace seguros=4 if p05a==4
replace seguros=5 if seguros==. & Jubilado==1
replace seguros=0 if seguros==.


*============================================================
*Recupero hijos menores de edad casados o en unión libre (que estan en el núcleo 2), cuyos padres aportan a la seguridad social
*-Identifico a hogares cuyos jefes o cónyuges aportan a cualquier régimen de la seguridad social.



gen jefes=p61b1 if p04==1 & inrange(p61b1,1,4)
egen jefes_afil=max(jefes), by(id_hogar)
gen conyuges=p61b1 if p04==2 & inrange(p61b1,1,4)
egen conyuges_afil=max(conyuges) if jefes_afil==., by(id_hogar)
gen hogar_afil=jefes_afil
replace hogar_afil=conyuges_afil if hogar_afil==.
*-Recupero casos
replace seguros= hogar_afil if p03<18 & seguros==0 & p04==3 & inrange(hogar_afil,1,4)
*============================================================
label var seguros "Cobertura a la Seguridad Social pública contributiva"
label def seguros 0 "Sin Cobertura" 1 "IESS General" 2 "IESS Voluntario" ///
3 "Seguro Campesino" 4 "ISSFA ISSPOL" 5 "Jubilados"
label values seguros seguros
*Indicador agregado
gen seguridad_universal=0 if seguros==0
replace seguridad_universal=1 if inrange(seguros,1,7)
label var seguridad_universal "Cobertura a la Seguridad Social pública contributiva"
label def seguridad_universal 0 "No cumple" 1 "Cumple"
label values seguridad_universal seguridad_universal
proportion seguridad_universal [iw=fexp]

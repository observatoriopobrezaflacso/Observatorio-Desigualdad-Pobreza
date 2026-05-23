*------------------------------------------------------------------*
* Merge ENEMDU informality datasets by id_persona and anio
*------------------------------------------------------------------*

clear all
set more off

* Definición de rutas globales para acceder a las bases de datos
global user_root "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad"
global bases "$user_root/Bases"
global raw "$bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global salarios "$bases/Salarios"
global variables_base "$user_root/Bases/ENEMDU/Procesadas/Armonizacion/Variables base/Trimestrales"
global bases_armonizadas "$user_root/Bases/ENEMDU/Procesadas/analisis informalidad/Santiago"
global out_results/Graficos "$user_root/Boletín 3/2. Armonización de variables/Gráficos de control"
global out_results "$user_root/Boletín 3/4. Resultados"

* Definición de variables importantes para análisis
global important_variable informal1
global important_variable2 informal2
global important_variable3 informal2_sim
global important_variable4 informal1_sim

* Cargar base de datos de trabajo
use "$bases/ENEMDU/Procesadas/analisis informalidad/Santiago/base_trabajo.dta", clear

* Generar obs de area antes del 2000
replace area = 1 if area == .


* Definir lista de variables relevantes para análisis de informalidad
local vars affiliated adec cuenta_propia tiene_ruc tamano_armonizado no_remunerado

* Generar tabulaciones de cada variable por año para control
foreach var of local vars {
    di "`var'"	
    tab anio `var'
}


* Poner a todas las variables sobre el mismo denominador (ocupados en edad de trabajar)

keep if edad >= 15

foreach var of varlist affiliated adec* no_remunerado tiene_ruc {
	replace `var' = . if inrange(condact, 5, 8) & anio < 2001
	replace `var' = . if inlist(condactn, 0, 7, 8, 9) & anio >= 2001
}


* ============================================================
**# INFORMALIDAD 1
* ============================================================
gen informal1 =  affiliated    == 0 | ///
				 adec               == 0 | ///
				 no_remunerado      == 1 
replace informal1 = . if inlist(., affiliated, adec, no_remunerado)				 

* ============================================================
**# INFORMALIDAD 1 SIM
* ============================================================
gen informal1_sim = ///
				  affiliated    == 0 | ///
				  adec_sim           == 0 | ///
				  no_remunerado      == 1 
replace informal1_sim = . if inlist(., affiliated, adec_sim, no_remunerado)				 

* ============================================================
**#  INFORMALIDAD 2
* ============================================================
gen informal2 =  affiliated    == 0 | ///
				 adec               == 0 | ///
				 no_remunerado      == 1 | ///
				 (tiene_ruc == 0) 
replace informal2 = . if inlist(., affiliated, adec,  tiene_ruc, tamano_armonizado)

* ============================================================
**#  INFORMALIDAD 2 SIM
* ============================================================
gen informal2_sim =  ///
				 affiliated        == 0 | ///
				 adec_sim               == 0 | ///
				 no_remunerado          == 1 | ///
				 (tiene_ruc == 0) 
replace informal2_sim = . if inlist(., affiliated, adec_sim,  tiene_ruc, tamano_armonizado)


* ===============================================================
**# INFORMALIDAD CON Y SIN RUC 
* ===============================================================

preserve
    collapse (mean) informal1 informal2 if anio != 2002 [iw = fexp], by(anio)
	export excel using "$out_results/Tablas/informal_con_y_sin_ruc.xlsx", replace
    replace informal1 = informal1 * 100
    replace informal2 = informal2 * 100
    format informal1 %9.2f
    format informal2 %9.2f
    twoway (connected informal1 anio, lcolor(navy) mcolor(navy)) /// 
	       (connected informal2 anio if anio >= 2001, lcolor(maroon) mcolor(maroon)),  ///
		   legend(order(1 "Informalidad sin criterio RUC" 2 "Informalidad con criterio RUC") position(6) ring(1)) ///
           yscale(range(50 100)) ylabel(50(10)100, format(%9.0f)) ///
           xscale(range(1990 2025)) xlabel(1990(2)2025, angle(90)) ///
           ytitle("Informalidad (%)") ///
           xtitle("") ///
           xline(2000, lpattern(dash) lcolor(gray)) ///
           name(informal_con_y_sin_ruc, replace)
    graph export "$out_results/Graficos/informal_con_y_sin_ruc.png", replace
restore



*------------------------------------------------------------------*
* Gráfico de serie de tiempo: Componentes de informal2
*------------------------------------------------------------------*
* Componentes de informal2:
*   - affiliated == 0  (no afiliado al IESS)
*   - adec == 0             (sin condiciones adecuadas)
*   - no_remunerado == 1    (trabajador no remunerado)
*   - tiene_ruc == 0        (no tiene RUC)
*------------------------------------------------------------------*

* Generar variables dummy de cada componente (en %), respetando los missing
gen     comp_no_iess     = (affiliated == 0) * 100 if !missing(affiliated)
gen     comp_no_adec     = (adec == 0)             * 100 if !missing(adec)
gen     comp_no_remun    = (no_remunerado == 1)    * 100 if !missing(no_remunerado)
gen     comp_no_ruc      = (tiene_ruc == 0)        * 100 if !missing(tiene_ruc)

label var comp_no_iess  "No afiliado al IESS"
label var comp_no_adec  "No tiene condiciones adecuadas (adec=0)"
label var comp_no_remun "Trabajador no remunerado"
label var comp_no_ruc   "No tiene RUC"
s
*------------------------------------------------------------------*
* Colapsar por año usando el factor de expansión (fexp)
* Si tu factor de expansión tiene otro nombre, reemplaza fexp por el
* correspondiente (p. ej. fexp_pob, fac_expan, etc.)

* ===============================================================
**# INFORMALIDAD CON Y SIN RUC Y CON Y SIN EMPLEO ADECUADO SIMULADO
* ===============================================================

preserve
    collapse (mean) comp_no_iess comp_no_adec comp_no_remun comp_no_ruc ///
             informal1 informal2 [iw=fexp] if anio != 2002, by(anio)
    replace informal1 = informal1 * 100
    replace informal2 = informal2 * 100
    export excel using "$out_results/Tablas/Informalidad_y_componentes.xlsx", firstrow(var) replace
	
    * Create a single combined series
    gen informal_combined = informal1 if anio <= 1999
    replace informal_combined = informal2 if anio >= 2000

    twoway ///
        (connected informal_combined anio, msymbol(O) lwidth(medium) lcolor(navy) mcolor(navy) msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel A. Informalidad", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
		xscale(range(1990 2025)) ///
        legend(off) graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_informal.gph", replace
    twoway ///
        (connected comp_no_iess  anio, msymbol(O) lwidth(medium) lcolor(navy)      mcolor(navy)      msize(small)) ///
        (connected comp_no_adec  anio, msymbol(O) lwidth(medium) lcolor(cranberry)  mcolor(cranberry)  msize(small)) ///
        (connected comp_no_remun anio, msymbol(O) lwidth(medium) lcolor(teal)       mcolor(teal)       msize(small)) ///
        (connected comp_no_ruc   anio, msymbol(O) lwidth(medium) lcolor(orange)     mcolor(orange)     msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel B. Componentes", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
		xscale(range(1990 2025)) ///
        legend(order(1 "No IESS" 2 "No adecuado" 3 "No remunerado" 4 "No RUC") ///
               rows(1) size(small) position(6)) ///
        graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_componentes.gph", replace
    graph combine ///
        "$out_results/Graficos/panel_informal.gph"     ///
        "$out_results/Graficos/panel_componentes.gph", ///
        cols(1) ycommon             ///
        note("Fuente: ENEMDU. Elaboración propia.") ///
        graphregion(color(white))
    graph export "$out_results/Graficos/Informalidad_y_componentes.png", replace height(1900)
    graph export "$out_results/Graficos/Informalidad_y_componentes.pdf", replace
restore





preserve
    collapse (mean) comp_no_iess comp_no_adec comp_no_remun comp_no_ruc ///
             informal1 informal2 [iw=fexp] if anio != 2002, by(anio sexo) 
			 
    replace informal1 = informal1 * 100
    replace informal2 = informal2 * 100
    export excel using "$out_results/Tablas/Informalidad_y_componentes_sexo.xlsx", firstrow(var) replace

    gen informal_combined = informal1 if anio <= 1999
    replace informal_combined = informal2 if anio >= 2000

    * --- Panel A: Informalidad – Hombres ---
    twoway ///
        (connected informal_combined anio if sexo == 1, msymbol(O) lwidth(medium) lcolor(navy) mcolor(navy) msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel A. Informalidad – Hombres", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
        xscale(range(1990 2025)) ///
        legend(off) graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_informal_hombres.gph", replace

    * --- Panel B: Informalidad – Mujeres ---
    twoway ///
        (connected informal_combined anio if sexo == 2, msymbol(O) lwidth(medium) lcolor(cranberry) mcolor(cranberry) msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel B. Informalidad – Mujeres", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
        xscale(range(1990 2025)) ///
        legend(off) graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_informal_mujeres.gph", replace

    * --- Panel C: Componentes – Hombres ---
    twoway ///
        (connected comp_no_iess  anio if sexo == 1, msymbol(O) lwidth(medium) lcolor(navy)      mcolor(navy)      msize(small)) ///
        (connected comp_no_adec  anio if sexo == 1, msymbol(O) lwidth(medium) lcolor(cranberry)  mcolor(cranberry)  msize(small)) ///
        (connected comp_no_remun anio if sexo == 1, msymbol(O) lwidth(medium) lcolor(teal)       mcolor(teal)       msize(small)) ///
        (connected comp_no_ruc   anio if sexo == 1, msymbol(O) lwidth(medium) lcolor(orange)     mcolor(orange)     msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel C. Componentes – Hombres", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
        xscale(range(1990 2025)) ///
        legend(order(1 "No IESS" 2 "No adecuado" 3 "No remunerado" 4 "No RUC") ///
               rows(1) size(small) position(6)) ///
        graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_componentes_hombres.gph", replace

    * --- Panel D: Componentes – Mujeres ---
    twoway ///
        (connected comp_no_iess  anio if sexo == 2, msymbol(O) lwidth(medium) lcolor(navy)      mcolor(navy)      msize(small)) ///
        (connected comp_no_adec  anio if sexo == 2, msymbol(O) lwidth(medium) lcolor(cranberry)  mcolor(cranberry)  msize(small)) ///
        (connected comp_no_remun anio if sexo == 2, msymbol(O) lwidth(medium) lcolor(teal)       mcolor(teal)       msize(small)) ///
        (connected comp_no_ruc   anio if sexo == 2, msymbol(O) lwidth(medium) lcolor(orange)     mcolor(orange)     msize(small)) ///
        (scatteri 0 1999 100 1999, recast(line) lpattern(dash) lcolor(gs8) lwidth(thin)), ///
        ytitle("") xtitle("") ///
        title("Panel D. Componentes – Mujeres", size(medium)) ///
        ylabel(0(20)100, angle(0) grid labsize(small)) ///
        xlabel(1991(2)2025, angle(90) labsize(small)) ///
        xscale(range(1990 2025)) ///
        legend(order(1 "No IESS" 2 "No adecuado" 3 "No remunerado" 4 "No RUC") ///
               rows(1) size(small) position(6)) ///
        graphregion(color(white)) plotregion(color(white)) scheme(s2color)
    graph save "$out_results/Graficos/panel_componentes_mujeres.gph", replace

    * --- Combine: 2x2 grid (men left, women right) ---
    graph combine ///
        "$out_results/Graficos/panel_informal_hombres.gph"     ///
        "$out_results/Graficos/panel_informal_mujeres.gph"     ///
        "$out_results/Graficos/panel_componentes_hombres.gph"  ///
        "$out_results/Graficos/panel_componentes_mujeres.gph", ///
        cols(2) ycommon ///
        note("Fuente: ENEMDU. Elaboración propia.") ///
        graphregion(color(white))
    graph export "$out_results/Graficos/Informalidad_y_componentes_sexo.png", replace height(1900)
    graph export "$out_results/Graficos/Informalidad_y_componentes_sexo.pdf", replace
restore

 
		s 
		 
* ============================================================
**# INFORMALIDAD POR AREA
* ============================================================

*::::::::::::::::::::: SIN CRITERIO RUC :::::::::::::::::::::

/*
preserve
    collapse (mean) informal1 if anio != 2002, by(anio area)
    replace informal1 = informal1 * 100
    list
    format informal1 %9.2f
    keep if area == 1
    rename informal1 ${important_variable}_urb
    tempfile urb
    save `urb'
restore

preserve
    keep if anio >= 2001
    collapse (mean) informal1  if anio != 2002 [iw = fexp], by(anio area)
    replace informal1 = informal1 * 100
    list
    format informal1 %9.2f
    keep if area == 2
    rename informal1 ${important_variable}_rural
    tempfile rural
    save `rural', replace
restore

preserve
    collapse (mean) informal1 if anio != 2002, by(anio)
    replace informal1 = informal1 * 100
    format informal1 %9.2f
    rename informal1 ${important_variable}_nac
    merge 1:1 anio using `urb',   nogen
    merge 1:1 anio using `rural', nogen
    list
    twoway (connected ${important_variable}_nac   anio, lcolor(navy)        mcolor(navy)) ///
           (connected ${important_variable}_urb   anio if anio >= 2000, lcolor(maroon)      mcolor(maroon)) ///
           (connected ${important_variable}_rural anio if anio >= 2000, lcolor(forest_green) mcolor(forest_green)), ///
           legend(order(1 "Nacional" 2 "Urbano" 3 "Rural")) ///
           yscale(range(50 100)) ylabel(50(10)100, format(%9.0f)) ///
           ytitle("Informalidad (%)") ///
           xscale(range(2001 2024)) xlabel(2001(3)2024) ///
           name(informal1_nac_urb, replace)
    graph export "$out_results/informal1_nac_urb.png", replace
restore

*/

*::::::::::::::::::::: CON CRITERIO RUC :::::::::::::::::::::

preserve
    keep if anio >= 2001
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio area)
    export excel using "$out_results/Graficos/Informalidad_area.xlsx", replace
	
    * Compute standard errors and CI bounds
    gen se      = sqrt((informal2 * (1 - informal2)) / N)
    gen ub      = informal2 + 1.96 * se
    gen lb      = informal2 - 1.96 * se
    replace ub  = min(ub, 1)
    replace lb  = max(lb, 0)
    
    * Scale to percentages
    replace informal2 = informal2 * 100
    replace ub        = ub        * 100
    replace lb        = lb        * 100
    
    * Reshape wide by area
    reshape wide informal2 N se ub lb, i(anio) j(area)
    
    * informal21 / ub1 / lb1 = Urban (area==1)
    * informal22 / ub2 / lb2 = Rural (area==2)
    
    * Compute national series (population-weighted mean)
    gen informal2_nac = (informal21 * N1 + informal22 * N2) / (N1 + N2)
    gen N_nac         = N1 + N2
    gen se_nac        = sqrt((informal2_nac/100 * (1 - informal2_nac/100)) / N_nac) * 100
    gen ub_nac        = min(informal2_nac + 1.96 * se_nac, 100)
    gen lb_nac        = max(informal2_nac - 1.96 * se_nac,   0)

    list anio informal2_nac informal21 informal22, sepby(anio)

    twoway ///
        (rarea ub_nac lb_nac anio,   sort color(navy%35)) ///
        (connected informal2_nac anio,   sort lcolor(navy)         mcolor(navy)         lwidth(medium)) ///
        (rarea ub1 lb1 anio,         sort color(maroon%35)) ///
        (connected informal21 anio,  sort lcolor(maroon)       mcolor(maroon)       lwidth(medium)) ///
        (rarea ub2 lb2 anio,         sort color(forest_green%35)) ///
        (connected informal22 anio,  sort lcolor(forest_green) mcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "Nacional" 4 "Urbano" 6 "Rural")) ///
        yscale(range(50 100)) ylabel(50(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        xscale(range(2001 2024)) xlabel(2001(3)2024, angle(90)) ///
        graphregion(color(white)) ///
        name(informal2_nac_urb, replace)
    graph export "$out_results/informal2_nac_urb.png", replace
restore


* ============================================================
**# GRÁFICOS DESAGREGADOS POR GÉNERO
* ============================================================

preserve
    keep if anio >= 2001
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio sexo)
    export excel using "$out_results/Tablas/Informalidad_genero.xlsx", replace

	
    reshape wide informal2 N, i(anio) j(sexo)
    gen se_h = sqrt((informal21*(1-informal21))/N1)
    gen se_m = sqrt((informal22*(1-informal22))/N2)
    gen ub_h = informal21 + 1.96*se_h
    gen lb_h = informal21 - 1.96*se_h
    gen ub_m = informal22 + 1.96*se_m
    gen lb_m = informal22 - 1.96*se_m
    replace ub_h = min(ub_h,1)
    replace lb_h = max(lb_h,0)
    replace ub_m = min(ub_m,1)
    replace lb_m = max(lb_m,0)
	list anio informal21 se_h ub_h lb_h informal22 se_m ub_m lb_m, sepby(anio)
	gen diff    = informal21 - informal22
	gen se_diff = sqrt(se_h^2 + se_m^2)
	gen z       = diff / se_diff
	gen p_value = 2 * normal(-abs(z))
	gen diff_sig = p_value < 0.05
	list anio diff p_value if diff_sig, noobs
	replace informal21 = informal21 * 100
	replace informal22 = informal22 * 100
	replace ub_h = ub_h * 100
	replace lb_h = lb_h * 100
	replace ub_m = ub_m * 100
	replace lb_m = lb_m * 100
    twoway ///
        (rarea ub_h lb_h anio, sort color(navy%35)) ///
        (connected informal21 anio, sort lcolor(navy) mcolor(navy) lwidth(medium)) ///
        (rarea ub_m lb_m anio, sort color(maroon%35)) ///
        (connected informal22 anio, sort lcolor(maroon) mcolor(maroon) lwidth(medium)), ///
        legend(order(2 "Hombre" 4 "Mujer")) ///
        xlabel(2001(2)2025, angle(90)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        yscale(range(50 100)) ///
        graphregion(color(white)) ///
        name(informal2_sexo_ci_area, replace)
restore

	 s
* ============================================================
**# GRÁFICO DE BARRAS: INFORMALIDAD POR PROVINCIA EN 2024
* ============================================================

	encode provincia, gen(provincia_enc)
	drop provincia
	rename provincia_enc provincia

	capture label define provincia_lbl ///
		01 "Azuay" ///
		02 "Bolívar" ///
		03 "Cañar" ///
		04 "Carchi" ///
		05 "Cotopaxi" ///
		06 "Chimborazo" ///
		07 "El Oro" ///
		08 "Esmeraldas" ///
		09 "Guayas" ///
		10 "Imbabura" ///
		11 "Loja" ///
		12 "Los Ríos" ///
		13 "Manabí" ///
		14 "Morona Santiago" ///
		15 "Napo" ///
		16 "Pastaza" ///
		17 "Pichincha" ///
		18 "Tungurahua" ///
		19 "Zamora Chinchipe" ///
		20 "Galápagos" ///
		21 "Sucumbíos" ///
		22 "Orellana" ///
		23 "Santo Domingo de los Tsáchilas" ///
		24 "Santa Elena" ///
		90 "Zonas no delimitadas"
	label values provincia provincia_lbl

	preserve
    keep if anio == 2025
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp] if anio != 2002, by(provincia)
    gen se = sqrt((informal2*(1-informal2))/N)
    gen ub = informal2 + 1.96*se
    gen lb = informal2 - 1.96*se
    replace ub = min(ub,1)
    replace lb = max(lb,0)
    gsort -informal2
	list provincia informal2 se ub lb, sepby(provincia)
    sum se

	local ref_cod = 17
	sum informal2 if provincia == `ref_cod', meanonly
	local ref_mean = r(mean)
	sum se if provincia == `ref_cod', meanonly
	local ref_se = r(mean)
	di "Comparando con provincia código `ref_cod' (tasa = `ref_mean')"
	gen diff_vs_ref    = .
	gen se_diff_vs_ref = .
	gen p_vs_ref       = .
	gen sig_vs_ref     = .
	foreach prov in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 90 {
		if `prov' != `ref_cod' {
			sum informal2 if provincia == `prov', meanonly
			local prov_mean = r(mean)
			sum se if provincia == `prov', meanonly
			local prov_se = r(mean)
			local diff    = `prov_mean' - `ref_mean'
			local se_diff = sqrt(`prov_se'^2 + `ref_se'^2)
			local z       = `diff' / `se_diff'
			local p       = 2 * normal(-abs(`z'))
			replace diff_vs_ref    = `diff'       if provincia == `prov'
			replace se_diff_vs_ref = `se_diff'    if provincia == `prov'
			replace p_vs_ref       = `p'          if provincia == `prov'
			replace sig_vs_ref     = (`p' < 0.05) if provincia == `prov'
		}
	}
	list provincia informal2 diff_vs_ref p_vs_ref sig_vs_ref if provincia != `ref_cod', sep(0)
	replace informal2 = informal2 * 100
	replace ub = ub * 100
	replace lb = lb * 100
    twoway ///
        (bar informal2 provincia, horizontal barwidth(0.6) color(navy)) ///
        (rcap ub lb provincia, horizontal lcolor(black)), ///
        ylabel(, valuelabel angle(0) labsize(small)) ///
        xlabel(0(20)100, format(%9.0f)) ///
        xscale(range(0 100)) ///
		xtitle("Informalidad") ///
        legend(off) ///
        graphregion(color(white)) ///
        title("Informalidad por provincia - 2024", size(medium)) ///
        name(informal2_provincia_ci_2024, replace)
*    graph export "$out_results/informal2_provincia_ci_2024.png", replace
restore


* ============================================================
**# TABLA LATEX: INFORMALIDAD POR PROVINCIA - 2000-2025 (cada 5 años)
* DIVIDIDA POR REGIÓN: SIERRA, COSTA, ORIENTE, INSULAR
* ============================================================
preserve
    keep if inlist(anio, 2001, 2005, 2010, 2015, 2020, 2025)
    drop if provincia == 25
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(provincia anio)
    rename informal2 inf
    keep provincia anio inf
    reshape wide inf, i(provincia) j(anio)
    gen region = .
    replace region = 1 if inlist(provincia, 1, 2, 3, 4, 5, 6, 10, 11, 17, 18)
    replace region = 2 if inlist(provincia, 7, 8, 9, 12, 13, 23, 24)
    replace region = 3 if inlist(provincia, 14, 15, 16, 19, 21, 22)
    replace region = 4 if provincia == 20
    gsort region -inf2025
    
    capture file close tex
    file open tex using "$out_results/informalidad_provincia.tex", write replace
    file write tex "\begin{table}[htbp]" _n
    file write tex "\centering" _n
    file write tex "\small" _n
    file write tex "\caption{Tasa de informalidad por provincia, Ecuador}" _n
    file write tex "\label{tab:informal_prov}" _n
    file write tex "\begin{tabular}{lcccccc}" _n
    file write tex "\hline\hline" _n
    file write tex "Provincia & 2001 & 2005 & 2010 & 2015 & 2020 & 2025 \\" _n
    
    local nobs = _N
    
    foreach reg_num in 1 2 3 4 {
        if `reg_num' == 1 file write tex "\hline" _n "\multicolumn{7}{l}{\textit{Sierra}} \\" _n "\hline" _n
        if `reg_num' == 2 file write tex "\hline" _n "\multicolumn{7}{l}{\textit{Costa}} \\" _n "\hline" _n
        if `reg_num' == 3 file write tex "\hline" _n "\multicolumn{7}{l}{\textit{Oriente}} \\" _n "\hline" _n
        if `reg_num' == 4 file write tex "\hline" _n "\multicolumn{7}{l}{\textit{Insular}} \\" _n "\hline" _n
        
        forvalues i = 1/`nobs' {
            if region[`i'] == `reg_num' {
                local prov : label (provincia) `=provincia[`i']'
                local f01 = cond(missing(inf2001[`i']), "--", string(inf2001[`i'], "%6.3f"))
                local f05 = cond(missing(inf2005[`i']), "--", string(inf2005[`i'], "%6.3f"))
                local f10 = cond(missing(inf2010[`i']), "--", string(inf2010[`i'], "%6.3f"))
                local f15 = cond(missing(inf2015[`i']), "--", string(inf2015[`i'], "%6.3f"))
                local f20 = cond(missing(inf2020[`i']), "--", string(inf2020[`i'], "%6.3f"))
                local f25 = cond(missing(inf2025[`i']), "--", string(inf2025[`i'], "%6.3f"))
                file write tex "`prov' & `f01' & `f05' & `f10' & `f15' & `f20' & `f25' \\" _n
            }
        }
    }
    
    file write tex "\hline\hline" _n
    file write tex "\end{tabular}" _n
    file write tex "\begin{tablenotes}" _n
    file write tex "\small" _n
    file write tex "\item \textit{Nota:} Provincias ordenadas por tasa de informalidad en 2025 (descendente) dentro de cada región." _n
    file write tex "\end{tablenotes}" _n
    file write tex "\end{table}" _n
    file close tex
    display "Tabla exportada a: informalidad_provincia.tex"
restore


* With CV

preserve
keep if inlist(anio, 2001, 2005, 2010, 2015, 2020, 2025)
drop if provincia == 25
gen uno = 1
replace informal2 = informal2*100
collapse (mean) informal2 (sd) sd_inf=informal2 (rawsum) N=uno [iw = fexp], by(provincia anio)
gen se_inf = sd_inf / sqrt(N)
gen hci = 1.96 * se_inf
rename informal2 inf
rename hci hci_inf
keep provincia anio inf hci_inf
reshape wide inf hci_inf, i(provincia) j(anio)
gsort -inf2025

capture file close tex
file open tex using "$out_results/informalidad_provincia.tex", write replace
file write tex "\begin{table}[htbp]" _n
file write tex "\centering" _n
file write tex "\caption{Tasa de informalidad por provincia, Ecuador (semi-amplitud del IC 95\% entre paréntesis)}" _n
file write tex "\label{tab:informal_prov}" _n
file write tex "\begin{tabular}{lcccccc}" _n
file write tex "\hline\hline" _n
file write tex "Provincia & 2001 & 2005 & 2010 & 2015 & 2020 & 2025 \\" _n
file write tex "\hline" _n

local nobs = _N
forvalues i = 1/`nobs' {
    local prov : label (provincia) `=provincia[`i']'
    foreach yr in 2001 2005 2010 2015 2020 2025 {
        local v`yr' = inf`yr'[`i']
        local h`yr' = hci_inf`yr'[`i']
        if missing(`v`yr'') {
            local f`yr' = "--"
        }
        else {
            local f`yr' = string(`v`yr'', "%4.1f") + " (" + string(`h`yr'', "%4.1f") + ")"
        }
    }
    file write tex "`prov' & `f2001' & `f2005' & `f2010' & `f2015' & `f2020' & `f2025' \\" _n
}
file write tex "\hline\hline" _n
file write tex "\end{tabular}" _n
file write tex "\end{table}" _n
file close tex
display "Tabla exportada a: informalidad_provincia.tex"
list provincia inf2001 hci_inf2001 inf2025 hci_inf2025, sep(0)
restore


*============================================================
**# GRÁFICO INFORMALIDAD POR EDAD
* ============================================================

gen age_cat = .
replace age_cat = 1 if edad >= 18 & edad <= 29
replace age_cat = 2 if edad >= 30 & edad <= 64
replace age_cat = 3 if edad >= 65 & edad < 98
label variable age_cat "Age category"
label define age_cat_lbl 1 "18-29" 2 "30-64" 3 "65+"
label values age_cat age_cat_lbl
tab age_cat

* Nacional
preserve 
    keep if anio >= 2001
    drop if missing(age_cat)
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio age_cat)
	export excel using "$out_results/Tablas/informalidad_edad.xlsx"
    reshape wide informal2 N, i(anio) j(age_cat)
    gen se_1 = sqrt((informal21*(1-informal21))/N1)
    gen se_2 = sqrt((informal22*(1-informal22))/N2)
    gen se_3 = sqrt((informal23*(1-informal23))/N3)
    gen ub_1 = informal21 + 1.96*se_1
    gen lb_1 = informal21 - 1.96*se_1
    gen ub_2 = informal22 + 1.96*se_2
    gen lb_2 = informal22 - 1.96*se_2
    gen ub_3 = informal23 + 1.96*se_3
    gen lb_3 = informal23 - 1.96*se_3
    foreach var in ub_1 ub_2 ub_3 {
        replace `var' = min(`var', 1)
    }
    foreach var in lb_1 lb_2 lb_3 {
        replace `var' = max(`var', 0)
    }
    list anio informal21 se_1 ub_1 lb_1 informal22 se_2 ub_2 lb_2 informal23 se_3 ub_3 lb_3, sepby(anio)
    sum se_1 se_2 se_3
    gen diff_1v2    = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2       = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2     = (p_1v2 < 0.05)
    gen diff_1v3    = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3       = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3     = (p_1v3 < 0.05)
    gen diff_2v3    = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3       = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3     = (p_2v3 < 0.05)
    list anio diff_1v2 p_1v2 sig_1v2 diff_1v3 p_1v3 sig_1v3 diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
    foreach g in 1 2 3 {
        replace informal2`g' = informal2`g' * 100
        replace ub_`g'       = ub_`g'       * 100
        replace lb_`g'       = lb_`g'       * 100
    }
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (connected informal21 anio, sort lcolor(navy) mcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (connected informal22 anio, sort lcolor(maroon) mcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (connected informal23 anio, sort lcolor(forest_green) mcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2001(2)2025, angle(90)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        yscale(range(50 100)) ///
        graphregion(color(white)) ///
        name(informal2_edad_ci, replace)
    graph export "$out_results/informal2_edad_IC.png", replace
restore
/*
* Urbano
preserve 
    keep if area == 1
    keep if anio >= 2001 & anio <= 2024
    drop if missing(age_cat)
    gen uno = 1 
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio age_cat)
    reshape wide informal2 N, i(anio) j(age_cat)
    gen se_1 = sqrt((informal21*(1-informal21))/N1)
    gen se_2 = sqrt((informal22*(1-informal22))/N2)
    gen se_3 = sqrt((informal23*(1-informal23))/N3)
    foreach g in 1 2 3 {
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    list anio informal21 se_1 ub_1 lb_1 informal22 se_2 ub_2 lb_2 informal23 se_3 ub_3 lb_3, sepby(anio)
    sum se_1 se_2 se_3
    gen diff_1v2    = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2       = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2     = (p_1v2 < 0.05)
    gen diff_1v3    = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3       = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3     = (p_1v3 < 0.05)
    gen diff_2v3    = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3       = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3     = (p_2v3 < 0.05)
    list anio diff_1v2 p_1v2 sig_1v2 diff_1v3 p_1v3 sig_1v3 diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
    foreach g in 1 2 3 {
        replace informal2`g' = informal2`g' * 100
        replace ub_`g'       = ub_`g'       * 100
        replace lb_`g'       = lb_`g'       * 100
    }
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(navy%30)) ///
        (connected informal21 anio, sort lcolor(navy) mcolor(navy) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(maroon%30)) ///
        (connected informal22 anio, sort lcolor(maroon) mcolor(maroon) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(forest_green%30)) ///
        (connected informal23 anio, sort lcolor(forest_green) mcolor(forest_green) lwidth(medium)), ///
        legend(order(2 "18-29" 4 "30-64" 6 "65+")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        yscale(range(50 100)) ///
		ytitle("Informalidad (%)") ///
        graphregion(color(white)) ///
        name(informal2_edad_urb_IC, replace)
    *graph export "$out_results/informal2_edad_urb_IC.png", replace
restore
*/

* ============================================================
**# GRÁFICO INFORMALIDAD POR ETNIA
* ============================================================

* Nacional — desde 2003 (primer año con datos completos post-2002)
preserve 
    keep if anio >= 2003 & anio <= 2024
    drop if missing(etnia_arm)
    gen uno = 1 
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio etnia_arm)
	export excel using "$out_results/Tablas/informalidad_etnia.xlsx", replace firstrow(var)
    tab etnia_arm
    reshape wide informal2 N, i(anio) j(etnia_arm)
    foreach g in 1 2 3 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    list anio informal21 se_1 ub_1 lb_1 informal22 se_2 ub_2 lb_2 informal23 se_3 ub_3 lb_3, sepby(anio)
    sum se_1 se_2 se_3
    gen diff_1v2    = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2       = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2     = (p_1v2 < 0.05)
    gen diff_1v3    = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3       = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3     = (p_1v3 < 0.05)
    gen diff_2v3    = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3       = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3     = (p_2v3 < 0.05)
    list anio diff_1v2 p_1v2 sig_1v2 diff_1v3 p_1v3 sig_1v3 diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g'       = ub_`g'       * 100
		replace lb_`g'       = lb_`g'       * 100
	}
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (connected informal21 anio, sort lcolor(green) mcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (connected informal22 anio, sort lcolor(blue) mcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (connected informal23 anio, sort lcolor(orange) mcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afroecuatoriano" 6 "Blanco/Mestizo")) ///
        xlabel(2003(2)2024, angle(45)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        yscale(range(50 100)) ///
        graphregion(color(white)) bgcolor(white) ///
        title("Informalidad por etnia (Nacional)", size(med)) ///
        name(informal2_etnia_nac_IC, replace)
    *graph export "$out_results/informal2_etnia_nac_IC.png", replace 
restore 

/*

* Urbano — desde 2003
preserve 
    keep if area == 1
    keep if anio >= 2003 & anio <= 2024
    drop if missing(etnia_arm)
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp] if anio != 2002, by(anio etnia_arm)
    tab etnia_arm
    reshape wide informal2 N, i(anio) j(etnia_arm)
    foreach g in 1 2 3 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    list anio informal21 se_1 ub_1 lb_1 informal22 se_2 ub_2 lb_2 informal23 se_3 ub_3 lb_3, sepby(anio)
    sum se_1 se_2 se_3
    gen diff_1v2    = informal21 - informal22
    gen se_diff_1v2 = sqrt(se_1^2 + se_2^2)
    gen p_1v2       = 2 * normal(-abs(diff_1v2 / se_diff_1v2))
    gen sig_1v2     = (p_1v2 < 0.05)
    gen diff_1v3    = informal21 - informal23
    gen se_diff_1v3 = sqrt(se_1^2 + se_3^2)
    gen p_1v3       = 2 * normal(-abs(diff_1v3 / se_diff_1v3))
    gen sig_1v3     = (p_1v3 < 0.05)
    gen diff_2v3    = informal22 - informal23
    gen se_diff_2v3 = sqrt(se_2^2 + se_3^2)
    gen p_2v3       = 2 * normal(-abs(diff_2v3 / se_diff_2v3))
    gen sig_2v3     = (p_2v3 < 0.05)
    list anio diff_1v2 p_1v2 sig_1v2 diff_1v3 p_1v3 sig_1v3 diff_2v3 p_2v3 sig_2v3 ///
         if !sig_1v2 | !sig_1v3 | !sig_2v3, noobs sep(0)
	foreach g in 1 2 3 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g'       = ub_`g'       * 100
		replace lb_`g'       = lb_`g'       * 100
	}
    twoway ///
        (rarea ub_1 lb_1 anio, sort color(green%30)) ///
        (connected informal21 anio, sort lcolor(green) mcolor(green) lwidth(medium)) ///
        (rarea ub_2 lb_2 anio, sort color(blue%30)) ///
        (connected informal22 anio, sort lcolor(blue) mcolor(blue) lwidth(medium)) ///
        (rarea ub_3 lb_3 anio, sort color(orange%30)) ///
        (connected informal23 anio, sort lcolor(orange) mcolor(orange) lwidth(medium)), ///
        legend(order(2 "Indígena" 4 "Negro/Afroecuatoriano" 6 "Blanco/Mestizo")) ///
        xlabel(2003(2)2024, angle(45)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        yscale(range(50 100)) ///
        graphregion(color(white)) bgcolor(white) ///
        title("Informalidad por etnia (Urbano)", size(med)) ///
        name(informal2_etnia_urb_IC, replace)
   *graph export "$out_results/informal2_etnia_urb_IC.png", replace
restore

*/

* ============================================================
**# GRÁFICO INFORMALIDAD POR EDUCACION
* ============================================================

* Nacional
preserve 
    keep if anio >= 2001 & anio <= 2024
    drop if missing(educ_univ)
    gen uno = 1
    collapse (mean) informal2 (rawsum) N=uno [iw = fexp] if anio != 2002, by(anio educ_univ)
	export excel using "$out_results/Tablas/informalidad_educacion.xlsx", replace firstrow(var)
    tab educ_univ
    reshape wide informal2 N, i(anio) j(educ_univ)
    foreach g in 0 1 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    list anio informal20 se_0 ub_0 lb_0 informal21 se_1 ub_1 lb_1, sepby(anio)
    sum se_0 se_1
    gen diff    = informal20 - informal21
    gen se_diff = sqrt(se_0^2 + se_1^2)
    gen p_value = 2 * normal(-abs(diff / se_diff))
    gen sig     = (p_value < 0.05)
    list anio diff p_value sig if !sig, noobs sep(0)
	foreach g in 0 1 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g'       = ub_`g'       * 100
		replace lb_`g'       = lb_`g'       * 100
	}
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (connected informal20 anio, sort lcolor(navy) mcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (connected informal21 anio, sort lcolor(maroon) mcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(20(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        yscale(range(30 100)) ///
        graphregion(color(white)) bgcolor(white) ///
        title("Informalidad por educación (Nacional)", size(med)) ///
        name(informal2_educ_nac_IC, replace)
*    graph export "$out_results/informal2_educ_nac_IC.png", replace
restore

/*

* Urbano
preserve 
    keep if area == 1
    keep if anio >= 2001 & anio <= 2024
    drop if missing(educ_univ)
    gen uno = 1
    collapse (mean) informal2 (sum) N=uno [iw = fexp] if anio != 2002, by(anio educ_univ)
    tab educ_univ
    reshape wide informal2 N, i(anio) j(educ_univ)
    foreach g in 0 1 {
        gen se_`g' = sqrt((informal2`g'*(1-informal2`g'))/N`g')
        gen ub_`g' = informal2`g' + 1.96*se_`g'
        gen lb_`g' = informal2`g' - 1.96*se_`g'
        replace ub_`g' = min(ub_`g', 1)
        replace lb_`g' = max(lb_`g', 0)
    }
    list anio informal20 se_0 ub_0 lb_0 informal21 se_1 ub_1 lb_1, sepby(anio)
    sum se_0 se_1
    gen diff    = informal20 - informal21
    gen se_diff = sqrt(se_0^2 + se_1^2)
    gen p_value = 2 * normal(-abs(diff / se_diff))
    gen sig     = (p_value < 0.05)
    list anio diff p_value sig if !sig, noobs sep(0)
	foreach g in 0 1 {
		replace informal2`g' = informal2`g' * 100
		replace ub_`g'       = ub_`g'       * 100
		replace lb_`g'       = lb_`g'       * 100
	}
    twoway ///
        (rarea ub_0 lb_0 anio, sort color(navy%30)) ///
        (connected informal20 anio, sort lcolor(navy) mcolor(navy) lwidth(medium)) ///
        (rarea ub_1 lb_1 anio, sort color(maroon%30)) ///
        (connected informal21 anio, sort lcolor(maroon) mcolor(maroon) lwidth(medium)), ///
        legend(order(2 "No universitaria" 4 "Universitaria")) ///
        xlabel(2000(2)2024, angle(45)) ///
        ylabel(50(10)100, format(%9.0f)) ///
        ytitle("Informalidad (%)") ///
        yscale(range(50 100)) ///
        graphregion(color(white)) bgcolor(white) ///
        title("Informalidad por educación (Urbano)", size(med)) ///
        name(informal2_educ_urb_IC, replace)
  *  graph export "$out_results/informal2_educ_urb_IC.png", replace
restore
*/

* ============================================================
**# Gráfico: % informalidad por decil de ingresos laborales
* ============================================================

/*
Revisión:

preserve
keep if anio == 2024
keep if ingrl != . & ingrl > 0   
xtile decile = ingrl [pw = fexp], nq(10)
tab decile
tab decile informal2 if anio == 2024, nofreq row
bysort decile: sum ingrl
gen a = ingrl == 460 
restore
*/

preserve

* --- 1. Filtro de población ocupada con ingreso válido --------
keep if mi_pea == 1
keep if ingrl != . & ingrl > 0   
keep if anio == 2024 | anio == 2019 

* --- 2. Construir deciles ponderados DENTRO de cada año -----
gen decil = .
levelsof anio, local(years)
foreach y of local years {
    xtile decil_`y' = ingrl [pw=fexp] if anio == `y', nq(10)
    replace decil = decil_`y' if anio == `y'
    drop decil_`y'
}


keep if decil >= 6

* --- 3. Colapsar: % informalidad por decil y año ------------
collapse (mean) inf2=informal2 [pw=fexp], by(decil anio)
replace inf2 = inf2 * 100

* --- 4. Reshape para graficar ambas líneas ------------------
reshape wide inf2, i(decil) j(anio)

* --- 5. Gráfico de Alta Calidad -----------------------------
twoway ///
    (connected inf22019 decil, ///
        lcolor(navy) mcolor(navy) lwidth(medthick) msize(medlarge) lpattern(solid)) ///
    (connected inf22024 decil, ///
        lcolor(maroon) mcolor(maroon) lwidth(medthick) msize(medlarge) lpattern(solid)), ///
    xlabel(6 "6" 7 "7" 8 "8" 9 "9" 10 "10", labsize(small)) ///
    ylabel(50(10)100, angle(horizontal) format(%2.0f) labsize(small) grid glcolor(gs14) glpattern(dot)) ///
    xtitle("{bf:Decil de Ingresos Laborales}", size(small) margin(t=2)) ///
    ytitle("{bf:Tasa de Informalidad (%)}", size(small) margin(r=2)) ///
    title("Informalidad Laboral por Deciles de Ingreso", size(medium) color(black) margin(b=2)) ///
    subtitle("Población ocupada — Ponderado por factor de expansión", size(vsmall) color(gs7)) ///
    legend(order(1 "2019" 2 "2024") position(6) rows(1) size(small) region(lcolor(white))) ///
    graphregion(color(white) margin(medium)) plotregion(color(white))

restore






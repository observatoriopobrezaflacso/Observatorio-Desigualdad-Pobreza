clear

* ============================================================
* 0. PARÁMETROS
* ============================================================

* Lista de TODOS los años disponibles (agregar nuevos aquí)
global anios_disponibles "2001 2010 2011 2024"

* Ruta global
global limpias "/Users/vero/Library/CloudStorage/GoogleDrive-observatorio.pobreza@flacso.edu.ec/Mi unidad/Bases/ENEMDU/Procesadas/ramas homogeneizadas"

global user_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza"

global outdir "$user_root/Dashboards/Data final/crecimiento_empleo"

* Carpeta de salida para los Excel
capture mkdir "$outdir"


* ============================================================
* 1. CARGA SECUENCIAL DE BASES
* ============================================================

local first = 1
foreach yr of global anios_disponibles {

    * --- Determinar qué variable de educación tiene este año ---
    * 2001 usa "nivinst"; el resto usa "p10a"
    if "`yr'" == "2001" {
        local eduvars "rama1 nivinst condact fexp area"
    }
    else {
        local eduvars "rama1 p10a condact fexp area"
    }

    if `first' {
        use `eduvars' using "$limpias/empleo`yr'_isic4.dta", clear
        local first = 0
    }
    else {
        append using "$limpias/empleo`yr'_isic4.dta", ///
            keep(`eduvars' condact*) force
    }

    rename *, lower

    * --- Renombrar condact ---
    capture confirm variable condact
    if !_rc {
        rename condact condact_`yr'
    }

    * --- Renombrar variable de educación al formato p10a_YYYY ---
    capture confirm variable nivinst
    if !_rc {
        rename nivinst p10a_`yr'
    }
    capture confirm variable p10a
    if !_rc {
        rename p10a p10a_`yr'
    }

    * --- Marcar año ---
    capture confirm variable anio
    if _rc {
        gen anio = "`yr'_"
    }
    else {
        replace anio = "`yr'_" if anio == ""
    }
}


* ============================================================
* 2. FILTRO ÁREA
* ============================================================
*keep if area == 1
drop area


* ============================================================
* 3. VARIABLES CLAVE: EMPLEO PLENO Y NIVEL EDUCATIVO
* ============================================================

gen empleo_pleno = 0
foreach yr of global anios_disponibles {
    capture confirm variable condact_`yr'
    if !_rc {
        replace empleo_pleno = 1 if condact_`yr' == 1
    }
}

foreach yr of global anios_disponibles {
    capture confirm variable condact_`yr'
    if !_rc {
        if "`yr'" == "2001"  replace empleo_pleno = . if inlist(condact_`yr', 7, 8, 9)
        if "`yr'" == "2010"  replace empleo_pleno = . if inlist(condact_`yr', 7, 8)
        if "`yr'" == "2011"  replace empleo_pleno = . if inlist(condact_`yr', 7, 8)
        if "`yr'" == "2024"  replace empleo_pleno = . if inlist(condact_`yr', 0, 9)
    }
}

gen universitario = 0
foreach yr of global anios_disponibles {
    capture confirm variable p10a_`yr'
    if !_rc {
        if "`yr'" == "2001" {
            replace universitario = 1 if inlist(p10a_`yr', 6, 7)
        }
        else {
            replace universitario = 1 if inlist(p10a_`yr', 9, 10)
        }
    }
}

keep rama1 universitario empleo_pleno anio fexp


* ============================================================
* 4. GENERACIÓN DE N Y PONDERACIÓN
* ============================================================

gen n_obs = !inlist(., rama1, universitario, empleo_pleno)
replace n_obs = . if n_obs == 0

gen n = n_obs * fexp

tostring empleo_pleno, replace
replace empleo_pleno = "pleno"   if empleo_pleno == "1"
replace empleo_pleno = "nopleno" if empleo_pleno == "0"
keep if empleo_pleno != "."

tostring universitario, replace
replace universitario = "uni_"   if universitario == "1"
replace universitario = "nouni_" if universitario == "0"


* ============================================================
* 5. ETIQUETAS PARA GRÁFICOS
* ============================================================

label define rama_graph ///
    1 "Agricult./Silvicult./Pesca" ///
    3 "Manufactura" ///
    6 "Construcción" ///
    7 "Comercio" ///
    9 "Alojamiento y comida"

label value rama1 rama_graph


* ============================================================
* 6. COLAPSO Y RESHAPE
* ============================================================

collapse (sum) n, by(rama1 universitario anio empleo_pleno)

reshape wide n, i(rama1 universitario empleo_pleno) j(anio) string
reshape wide n*, i(rama1 empleo_pleno) j(universitario) string
reshape wide n*, i(rama1) j(empleo_pleno) string

* Guardar la base colapsada para restaurar en cada iteración
tempfile base_collapsed
save `base_collapsed'


* ============================================================
* 7. LOOP SOBRE TODAS LAS COMBINACIONES DE AÑO INI / AÑO FIN
* ============================================================

local anios_list $anios_disponibles

foreach yi of local anios_list {
    foreach yf of local anios_list {

        * Saltar si año final <= año inicial
        if `yf' <= `yi' continue

        display as result _n "=============================================="
        display as result "   PROCESANDO PERÍODO: `yi' → `yf'"
        display as result "=============================================="

        * Restaurar base colapsada limpia
        use `base_collapsed', clear

        * --- Verificar que existen las variables de ambos años ---
        capture confirm variable n`yi'_nouni_nopleno
        if _rc {
            display as error "No existe variable n`yi'_nouni_nopleno — saltando `yi'-`yf'"
            continue
        }
        capture confirm variable n`yf'_nouni_nopleno
        if _rc {
            display as error "No existe variable n`yf'_nouni_nopleno — saltando `yi'-`yf'"
            continue
        }

        * ===========================================================
        * 7a. PROPORCIONES DENTRO DE CADA GRUPO
        * ===========================================================

        foreach grp in nouni_nopleno nouni_pleno uni_nopleno uni_pleno {
            foreach yr in `yi' `yf' {
                capture confirm variable n`yr'_`grp'
                if !_rc {
                    egen tot_`yr'_`grp' = total(n`yr'_`grp')
                    gen  per_`yr'_`grp' = n`yr'_`grp' / tot_`yr'_`grp'
                }
            }
        }

        * ===========================================================
        * 7b. AGRUPACIÓN: UNIVERSITARIOS vs NO UNIVERSITARIOS
        * ===========================================================

        foreach yr in `yi' `yf' {
            egen n`yr'_uni   = rowtotal(n`yr'_uni_pleno   n`yr'_uni_nopleno)
            egen n`yr'_nouni = rowtotal(n`yr'_nouni_pleno  n`yr'_nouni_nopleno)

            egen rowtot_`yr' = rowtotal(n`yr'_nouni n`yr'_uni)
            gen  rowper_`yr'_uni = n`yr'_uni / rowtot_`yr'
        }

        * ===========================================================
        * 7c. CRECIMIENTO
        * ===========================================================

        gen uni_crecimiento    = ((n`yf'_uni    / n`yi'_uni)    - 1) * 100
        gen nouni_crecimiento  = ((n`yf'_nouni  / n`yi'_nouni)  - 1) * 100
        gen rowtot_crecimiento = ((rowtot_`yf'  / rowtot_`yi')  - 1) * 100

        * ===========================================================
        * 7d. AGRUPACIÓN: EMPLEO PLENO vs NO PLENO
        * ===========================================================

        foreach yr in `yi' `yf' {
            egen n`yr'_pleno   = rowtotal(n`yr'_uni_pleno   n`yr'_nouni_pleno)
            egen n`yr'_nopleno = rowtotal(n`yr'_uni_nopleno  n`yr'_nouni_nopleno)

            gen rowper_`yr'_pleno = n`yr'_pleno / rowtot_`yr'
        }

        * ===========================================================
        * 7e. GRÁFICO 1: BARRAS DE CRECIMIENTO POR RAMA
        * ===========================================================

        preserve

        keep rama1 uni_crecimiento nouni_crecimiento rowtot_`yf'
        keep if inlist(rama1, 1, 3, 6, 7, 9)

        graph bar (mean) uni_crecimiento nouni_crecimiento, ///
            over(rama1, label(angle(45) labsize(small))) ///
            legend(order(1 "Universitarios" 2 "No universitarios")) ///
            title("Crecimiento `yi'-`yf'") ///
            name(crec_`yi'_`yf', replace)

        * --- Exportar datos del gráfico de barras ---
        export excel using "$outdir/datos_graficos_`yi'_`yf'.xlsx", ///
            sheet("barras_crecimiento") firstrow(variables) replace

        restore

        * ===========================================================
        * 7f. GRÁFICO 2: SCATTER CRECIMIENTO vs EDUCACIÓN
        * ===========================================================

        reg rowtot_crecimiento rowper_`yi'_uni [aweight = rowtot_`yi'] if rama1 != 18
        local slope : display %6.3f _b[rowper_`yi'_uni]

        summ rowper_`yi'_uni
        local midx = r(mean)

        summ rowtot_crecimiento
        local midy = r(mean) + 0.05*(r(max) - r(min))

        twoway ///
            (scatter rowtot_crecimiento rowper_`yi'_uni [aweight = rowtot_`yi']) ///
            (lfit    rowtot_crecimiento rowper_`yi'_uni [aweight = rowtot_`yi']) ///
            if rama1 != 18, ///
            text(`midy' `midx' "Slope = `slope'", place(c)) ///
            title("Educación y crecimiento `yi'-`yf'") ///
            name(edu_crec_`yi'_`yf', replace)

        * --- Exportar datos del scatter educación-crecimiento ---
        preserve
        keep if rama1 != 18
        keep rama1 rowtot_crecimiento rowper_`yi'_uni rowtot_`yi'
        rename rowper_`yi'_uni    prop_universitarios_`yi'
        rename rowtot_`yi'        peso_`yi'
        export excel using "$outdir/datos_graficos_`yi'_`yf'.xlsx", ///
            sheet("scatter_edu_crec") firstrow(variables) sheetmodify
        restore

        * ===========================================================
        * 7g. GRÁFICO 3 y 4: SCATTER EDUCACIÓN vs EMPLEO PLENO
        * ===========================================================

        foreach yr in `yi' `yf' {

            reg rowper_`yr'_uni rowper_`yr'_pleno [aweight = rowtot_`yr']
            local slope : display %6.3f _b[rowper_`yr'_pleno]

            summ rowper_`yr'_pleno
            local midx = r(mean)

            summ rowper_`yr'_uni
            local midy = r(mean) + 0.05*(r(max) - r(min))

            twoway ///
                (scatter rowper_`yr'_uni rowper_`yr'_pleno [aweight = rowtot_`yr']) ///
                (lfit    rowper_`yr'_uni rowper_`yr'_pleno [aweight = rowtot_`yr']) ///
                , text(`midy' `midx' "Slope = `slope'", place(c)) ///
                title("Educación vs Empleo pleno — `yr'") ///
                name(edu_emp_`yr'_par`yi'`yf', replace)

            * --- Exportar datos del scatter educación-empleo ---
            preserve
            keep rama1 rowper_`yr'_uni rowper_`yr'_pleno rowtot_`yr'
            rename rowper_`yr'_uni   prop_universitarios
            rename rowper_`yr'_pleno prop_empleo_pleno
            rename rowtot_`yr'       peso
            export excel using "$outdir/datos_graficos_`yi'_`yf'.xlsx", ///
                sheet("scatter_edu_emp_`yr'") firstrow(variables) sheetmodify 
            restore
        }

        display as result ">>> Archivo guardado: $outdir/datos_graficos_`yi'_`yf'.xlsx"

    } // end foreach yf
} // end foreach yi

display as result _n "=============================================="
display as result "   PROCESO COMPLETO — TODAS LAS COMBINACIONES"
display as result "=============================================="

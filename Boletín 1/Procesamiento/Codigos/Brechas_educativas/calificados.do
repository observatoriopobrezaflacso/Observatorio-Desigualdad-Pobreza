clear

* ============================================================
* 0. GLOBALES DE CONTROL
* ============================================================

global user_root "H:/Mi unidad"
global limpias "$user_root/Bases/ENEMDU/Procesadas/ramas homogeneizadas"
global salidas "$user_root/Boletín 1/Outcomes/Brecha educacion"

capture mkdir "$salidas"

global excel "$salidas/tablas_ramas.xlsx"   // libro único, una hoja por tabla

global anios "2001 2010 2011 2024"           // todos los años de trabajo
global pares "2001_2010 2011_2024 2001_2024" // comparaciones inicio_fin

* Categorías de condact que NO son válidas para empleo pleno, por año
global excluir_2001 "7, 8, 9"
global excluir_2010 "7, 8"
global excluir_2011 "7, 8"
global excluir_2024 "0, 9"


* ============================================================
* 1. CARGA DE BASES
* ============================================================

* Base 2001: usa nivinst en lugar de p10a
use rama1 nivinst condact fexp area using "$limpias/empleo2001_isic4.dta", clear

rename *, lower                         // uniformidad en minúsculas
rename condact condact_2001             // diferenciación por año
rename nivinst p10a_2001
gen anio = "2001_"                      // marca de año para reshape futuro

* Resto de años: mismo bloque de variables
foreach y in 2010 2011 2024 {

    append using "$limpias/empleo`y'_isic4.dta", ///
        keep(rama1 p10a condact fexp area) force

    rename *, lower                     // uniformidad en minúsculas
    rename condact condact_`y'          // diferenciación por año
    replace anio = "`y'_" if anio == "" // completar años faltantes
}


* ============================================================
* 2. FILTROS
* ============================================================

keep if area == 1
drop area

drop if p10a == . & anio != "2001_"
drop if p10a_2001 == . & anio == "2001_"


* ============================================================
* 3. VARIABLES CLAVE: EMPLEO PLENO Y NIVEL EDUCATIVO
* ============================================================

* ---- Empleo pleno: condact == 1 en el año correspondiente ----
gen empleo_pleno = inlist(1, condact_2001, condact_2010, condact_2011, condact_2024)

foreach y of global anios {

    * Categorías no válidas de ese año
    replace empleo_pleno = . if inlist(condact_`y', ${excluir_`y'})

    * Missing en condact del año propio de la observación
    replace empleo_pleno = . if missing(condact_`y') & anio == "`y'_"
}

* ---- Universitario ----
gen universitario = inlist(p10a, 9, 10)               if anio != "2001_"
replace universitario = inlist(p10a_2001, 6, 7)       if anio == "2001_"

* Missing en p10a del año propio de la observación
replace universitario = . if missing(p10a)      & anio != "2001_"
replace universitario = . if missing(p10a_2001) & anio == "2001_"

* Conservar solo variables necesarias
keep rama1 universitario empleo_pleno anio fexp


* ============================================================
* 4. GENERACIÓN DE N Y PONDERACIÓN
* ============================================================

* Crear contador de observaciones válidas
gen n_obs = !inlist(., rama1, universitario, empleo_pleno)
replace n_obs = . if n_obs == 0

gen n = n_obs
replace n = n_obs * fexp           // expansión con factor de expansión

* Codificar empleo pleno y universitario como string para pivotear después
tostring empleo_pleno, replace
replace empleo_pleno = "pleno"   if empleo_pleno == "1"
replace empleo_pleno = "nopleno" if empleo_pleno == "0"

tostring universitario, replace
replace universitario = "uni_"    if universitario == "1"
replace universitario = "nouni_"  if universitario == "0"

* Eliminar missings de ambas variables antes del reshape
keep if inlist(empleo_pleno, "pleno", "nopleno")
keep if inlist(universitario, "uni_", "nouni_")


* ============================================================
* 5. ETIQUETAS PARA GRÁFICOS
* ============================================================

label define rama_graph 1 "Agricult./Silvicult./Pesca" 3 "Manufactura" ///
    6 "Construcción" 7 "Comercio" 9 "Alojamiento y comida"

label value rama1 rama_graph


* ============================================================
* 6. COLAPSOS PARA OBTENER TABLAS DE CONTINGENCIA
* ============================================================

collapse (sum) n, by(rama1 universitario anio empleo_pleno)

* Reordenar base a formato ancho: primero año
reshape wide n, i(rama1 universitario empleo_pleno) j(anio) string

* Luego nivel educativo
reshape wide n*, i(rama1 empleo_pleno) j(universitario) string

* Finalmente empleo pleno
reshape wide n*, i(rama1) j(empleo_pleno) string

* Nombre legible de la rama para las tablas de Excel
decode rama1, gen(rama_nombre)
replace rama_nombre = "Rama " + string(rama1) if missing(rama_nombre)


* ============================================================
* 7. PROPORCIONES DENTRO DE CADA GRUPO (columna)
* ============================================================

foreach y of global anios {
    foreach u in uni nouni {
        foreach e in pleno nopleno {

            egen tot_`y'_`u'_`e' = total(n`y'_`u'_`e')
            gen  per_`y'_`u'_`e' = n`y'_`u'_`e' / tot_`y'_`u'_`e'
        }
    }
}


* ============================================================
* 8. AGRUPACIONES POR AÑO: UNI/NOUNI Y PLENO/NOPLENO
* ============================================================

foreach y of global anios {

    * Universitarios vs no universitarios
    egen n`y'_uni   = rowtotal(n`y'_uni_pleno n`y'_uni_nopleno)
    egen n`y'_nouni = rowtotal(n`y'_nouni_pleno n`y'_nouni_nopleno)

    egen rowtot_`y' = rowtotal(n`y'_nouni n`y'_uni)
    gen rowper_`y'_uni = n`y'_uni / rowtot_`y'

    * Empleo pleno vs no pleno
    egen n`y'_pleno   = rowtotal(n`y'_uni_pleno n`y'_nouni_pleno)
    egen n`y'_nopleno = rowtotal(n`y'_uni_nopleno n`y'_nouni_nopleno)

    gen rowper_`y'_pleno = n`y'_pleno / rowtot_`y'
}


* ============================================================
* 9. CRECIMIENTO POR PAR DE AÑOS Y GRÁFICO DE BARRAS
* ============================================================

foreach par of global pares {

    global y0 = substr("`par'", 1, 4)   // año inicial
    global y1 = substr("`par'", 6, 4)   // año final

    gen uni_crec_`par'    = ((n${y1}_uni   / n${y0}_uni)   - 1) * 100
    gen nouni_crec_`par'  = ((n${y1}_nouni / n${y0}_nouni) - 1) * 100
    gen rowtot_crec_`par' = ((rowtot_${y1} / rowtot_${y0}) - 1) * 100

    preserve

        keep uni_crec_`par' nouni_crec_`par' rama1 rowtot_${y1}
        keep if inlist(rama1, 1, 3, 6, 7, 9)

        list

        graph bar (mean) uni_crec_`par' nouni_crec_`par', ///
            over(rama1, label(angle(45) labsize(small))) ///
            legend(order(1 "Universitarios" 2 "No universitarios")) ///
            name(crec_`par', replace)

    restore
}


* ============================================================
* 10. ARCHIVO PARA GUARDAR LAS PENDIENTES DE REGRESIÓN
* ============================================================

* Se abre antes de los loops de gráficos y se cierra después de ellos
* Solo pendiente y constante: es lo necesario para dibujar la recta en Excel
postfile pend str25 grafico double(pendiente constante) ///
    using "$salidas/pendientes.dta", replace


* ============================================================
* 11. GRÁFICOS: CRECIMIENTO vs EDUCACIÓN INICIAL
* ============================================================

foreach par of global pares {

    global y0 = substr("`par'", 1, 4)

    reg rowtot_crec_`par' rowper_${y0}_uni [aweight = rowtot_${y0}] if rama1 != 18
    global slope : display %6.3f _b[rowper_${y0}_uni]

    post pend ("edu_crec_`par'") (_b[rowper_${y0}_uni]) (_b[_cons])

    summ rowper_${y0}_uni
    global midx = r(mean)

    summ rowtot_crec_`par'
    global midy = r(mean) + 0.05*(r(max)-r(min))

    twoway ///
        (scatter rowtot_crec_`par' rowper_${y0}_uni [aweight = rowtot_${y0}]) ///
        (lfit    rowtot_crec_`par' rowper_${y0}_uni [aweight = rowtot_${y0}]) ///
        if rama1 != 18, text($midy $midx "Slope = $slope", place(c)) ///
        name(edu_crec_`par', replace)
}


* ============================================================
* 12. GRÁFICOS: EDUCACIÓN vs EMPLEO PLENO, POR AÑO
* ============================================================

foreach y of global anios {

    reg rowper_`y'_uni rowper_`y'_pleno [aweight = rowtot_`y']
    global slope : display %6.3f _b[rowper_`y'_pleno]

    post pend ("edu_emp_`y'") (_b[rowper_`y'_pleno]) (_b[_cons])

    summ rowper_`y'_pleno
    global midx = r(mean)

    summ rowper_`y'_uni
    global midy = r(mean) + 0.05*(r(max)-r(min))

    twoway ///
        (scatter rowper_`y'_uni rowper_`y'_pleno [aweight = rowtot_`y']) ///
        (lfit    rowper_`y'_uni rowper_`y'_pleno [aweight = rowtot_`y']) ///
        , text($midy $midx "Slope = $slope", place(c)) ///
        name(edu_emp_`y', replace)
}

postclose pend


* ============================================================
* 13. EXPORTACIÓN A EXCEL
*     Una hoja por gráfico, con las columnas exactas que se grafican
* ============================================================

* Guardar la base de resultados para poder volver a ella cuando se quiera
save "$salidas/base_tablas.dta", replace


* ---- 13.1 Gráficos de barras de crecimiento ----
* Columnas: rama (eje) + las dos series de barras

foreach par of global pares {

    preserve

        * borrar las ramas que no aparecen en el gráfico de barras
        drop if !inlist(rama1, 1, 3, 6, 7, 9)
        drop if missing(uni_crec_`par') | missing(nouni_crec_`par')

        keep rama_nombre uni_crec_`par' nouni_crec_`par'
        order rama_nombre uni_crec_`par' nouni_crec_`par'

        sort rama_nombre

        export excel using "$excel", ///
            sheet("crec_`par'") sheetreplace firstrow(variables)

    restore
}


* ---- 13.2 Scatter crecimiento vs educación inicial ----
* Columnas: x, y y el peso del aweight

foreach par of global pares {

    global y0 = substr("`par'", 1, 4)

    preserve

        * borrar las ramas que no aparecen en el scatter
        drop if rama1 == 18
        drop if missing(rowper_${y0}_uni) | missing(rowtot_crec_`par')
        drop if missing(rowtot_${y0}) | rowtot_${y0} <= 0

        keep rama_nombre rowper_${y0}_uni rowtot_crec_`par' rowtot_${y0}
        order rama_nombre rowper_${y0}_uni rowtot_crec_`par' rowtot_${y0}

        sort rama_nombre

        export excel using "$excel", ///
            sheet("edu_crec_`par'") sheetreplace firstrow(variables)

    restore
}


* ---- 13.3 Scatter educación vs empleo pleno ----
* Columnas: x, y y el peso del aweight

foreach y of global anios {

    preserve

        keep rama_nombre rowper_`y'_pleno rowper_`y'_uni rowtot_`y'
        order rama_nombre rowper_`y'_pleno rowper_`y'_uni rowtot_`y'

        sort rama_nombre

        export excel using "$excel", ///
            sheet("edu_emp_`y'") sheetreplace firstrow(variables)

    restore
}


* ---- 13.4 Pendiente y constante de cada recta ajustada ----
* Permite trazar la lfit en Excel: y = constante + pendiente * x

use "$salidas/pendientes.dta", clear

export excel using "$excel", ///
    sheet("rectas") sheetreplace firstrow(variables)

list


* ============================================================
* 14. VERIFICACIÓN DE CATEGORÍAS CONDACT POR AÑO
*     (ojo: este bloque reemplaza los datos en memoria)
* ============================================================

foreach y in 2011 2024 {

    use "$limpias/empleo`y'.dta", clear
    rename *, lower

    display "==== CONDACT `y' ===="
    tab condact
    tab condact, nol
}

* Para volver a la base de resultados:
* use "$salidas/base_tablas.dta", clear
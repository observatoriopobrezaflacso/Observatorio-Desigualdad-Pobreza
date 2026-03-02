* ═══════════════════════════════════════════════════════════════════════════════
* SERIE HISTÓRICA TMI POR ETNIA 2013-2024
* Numerador: EDG - etnia del fallecido menor de 1 año
* Denominador: ENV - etnia de la madre
* Excluye: Sin información en ambas bases
* ═══════════════════════════════════════════════════════════════════════════════

local carpeta_edg "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones"
local carpeta_env "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV"


tempfile base_muertes base_nacimientos

* Recodificación estándar:
* 1 = Indígena
* 2,3,4,5,6,7,8 = No Indígena
* 9 o sin info = excluir

clear
set obs 0
gen anio        = .
gen MI_indigena = .
gen MI_noindi   = .
save `base_muertes', emptyok replace

* ── DEFUNCIONES (EDG) 2013-2024 ──────────────────────────────────────────────
forvalues y = 2013/2024 {
    di "═══ EDG `y' ═══"

    capture import spss using "`carpeta_edg'\EDG_`y'.sav", clear
    if _rc {
        di "EDG_`y'.sav no encontrado"
        continue
    }

    * Estandarizar nombre de variable edad
    foreach v in COD_EDA COD_EDAD {
        capture confirm variable `v'
        if !_rc rename `v' cod_edad
    }
    capture confirm string variable cod_edad
    if !_rc destring cod_edad, replace force
    capture confirm string variable edad
    if !_rc destring edad, replace force

    * Filtrar menores de 1 año
    keep if inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)

    * Estandarizar nombre de variable etnia
    foreach v in etnia p_etnica ETNIA P_ETNICA {
        capture confirm variable `v'
        if !_rc rename `v' etnia
    }
    capture confirm string variable etnia
    if !_rc destring etnia, replace force

    * Excluir sin información
    drop if missing(etnia) | etnia == 9 | etnia == 99

    * Recodificar
    gen indigena    = (etnia == 1)
    gen no_indigena = (etnia >= 2 & etnia <= 8)

    collapse (sum) MI_indigena=indigena MI_noindi=no_indigena
    gen anio = `y'

    append using `base_muertes'
    save `base_muertes', replace
}

* ── NACIMIENTOS (ENV) 2013-2024 ──────────────────────────────────────────────
clear
set obs 0
gen anio        = .
gen NV_indigena = .
gen NV_noindi   = .
save `base_nacimientos', emptyok replace

forvalues y = 2013/2024 {
    di "═══ ENV `y' ═══"

    capture import spss using "`carpeta_env'\ENV_`y'.sav", clear
    if _rc capture import spss using "`carpeta_env'\ENV_ `y'.sav", clear
    if _rc {
        di "ENV_`y'.sav no encontrado"
        continue
    }

    * Estandarizar nombre etnia madre
    foreach v in etnia etnia_m ETNIA ETNIA_M p_etnia {
        capture confirm variable `v'
        if !_rc rename `v' etnia
    }
    capture confirm string variable etnia
    if !_rc destring etnia, replace force

    * Excluir sin información
    drop if missing(etnia) | etnia == 9 | etnia == 99

    * Recodificar
    gen indigena    = (etnia == 1)
    gen no_indigena = (etnia >= 2 & etnia <= 8)

    collapse (sum) NV_indigena=indigena NV_noindi=no_indigena
    gen anio = `y'

    append using `base_nacimientos'
    save `base_nacimientos', replace
}

* ── MERGE Y CÁLCULO TMI ──────────────────────────────────────────────────────

use `base_muertes', clear
merge 1:1 anio using `base_nacimientos'
keep if _merge == 3
drop _merge

gen tmi_indigena = (MI_indigena / NV_indigena) * 1000
gen tmi_noindi   = (MI_noindi   / NV_noindi)   * 1000

label var tmi_indigena "TMI Indígena"
label var tmi_noindi   "TMI No Indígena"

gsort anio

save "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\TMI_etnia_2013_2024.dta", replace

* Verificación
di "═══ RESULTADO FINAL ═══"
list anio MI_indigena NV_indigena tmi_indigena MI_noindi NV_noindi tmi_noindi

* ── GRÁFICO PROFESIONAL ──────────────────────────────────────────────────────

* Convertir a formato largo para ggplot-style en Stata
reshape long tmi_, i(anio) j(grupo) string

rename tmi_ tmi
label define grupo_lbl 1 "Indígena" 2 "No Indígena"

gen grupo_num = 1 if grupo == "indigena"
replace grupo_num = 2 if grupo == "noindi"

* Brecha en el último año disponible
quietly sum tmi if grupo == "indigena" & anio == 2024
local tmi_indi = round(r(mean), 0.1)
quietly sum tmi if grupo == "noindi"   & anio == 2024
local tmi_noin = round(r(mean), 0.1)
local brecha = round(`tmi_indi' - `tmi_noin', 0.1)

twoway ///
    (connected tmi anio if grupo == "indigena", ///
        lcolor("178 34 34") lwidth(medthick) lpattern(solid) ///
        mcolor("178 34 34") msymbol(circle) msize(medium)) ///
    (connected tmi anio if grupo == "noindi", ///
        lcolor("52 119 181") lwidth(medthick) lpattern(solid) ///
        mcolor("52 119 181") msymbol(square) msize(medium)) ///
    , ///
    title("Tasa de Mortalidad Infantil por Etnia" ///
          "Ecuador 2013–2024", ///
          size(medlarge) color(black) justification(left)) ///
    subtitle("Por cada 1.000 nacidos vivos", ///
          size(small) color(gs6) justification(left)) ///
    ytitle("TMI (por 1.000 NV)", size(small)) ///
    xtitle("") ///
    xlabel(2013(1)2024, angle(45) labsize(small)) ///
    ylabel(0(5)40, grid glcolor(gs14) glwidth(vthin) labsize(small)) ///
    legend(order(1 "Indígena" 2 "No Indígena") ///
           position(6) rows(1) size(small) region(lwidth(none))) ///
    note("Brecha 2024: `brecha' puntos (Indígena: `tmi_indi' vs No Indígena: `tmi_noin')" ///
         " " ///
         "Nota metodológica: Numerador = etnia del fallecido menor de 1 año (EDG)." ///
         "Denominador = etnia de la madre (ENV). Se excluyen registros sin información étnica" ///
         "(EDG 2022: 14.5%; ENV 2022: 3.0%). Estándar OPS/OMS para TMI por etnia." ///
         "Fuente: Estadísticas de Defunciones (EDG) y Estadísticas de Nacidos Vivos (ENV)," ///
         "INEC 2013–2024. Elaboración: Observatorio de Desigualdad y Pobreza.", ///
         size(vsmall) color(gs7) justification(left)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    bgcolor(white) ///
    scheme(s2color)

graph export "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\TMI_etnia_2013_2024.png", ///
    replace width(2400) height(1600)

di "✔ Gráfico exportado: TMI_etnia_2013_2024.png"
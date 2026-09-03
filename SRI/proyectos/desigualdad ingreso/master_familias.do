********************************************************************************
*  master_familias.do
*  ---------------------------------------------------------------------------
*  Runs the whole family-identifier pipeline end to end.
*
*    1  make_cedulados_fake.do            ~ 20 s   synthetic cedulados_full
*    2  build_familias.do                 ~ 10 m   the family identifiers
*    3  validate_familias.do              ~ 1 m    checks against the truth
*    4  analisis_concentracion_familia.do ~ 1 m    concentration by family
*
*  The CODE lives in the git repo ($codigo); the DATA lives on the shared
*  drive ($fake), which is why the two paths are separate globals.  Each of
*  the four do-files sets $fake itself, so any one of them can also be run on
*  its own.
*
*  Step 1 is only needed for the synthetic test bed.  Against the real
*  registry, skip it and point $ced (inside build_familias.do) at the real
*  Cedulados/dta folder; steps 2 and 4 run unchanged, and step 3 skips its
*  ground-truth section on its own, since there is no truth file to compare
*  against.
********************************************************************************

clear all
set more off

* where the code lives
global codigo "C:/Users/santy/Documents/GitHub/Observatorio-Desigualdad-Pobreza/SRI/proyectos/desigualdad ingreso"
* where the data lives
global fake   "G:/Mi unidad/Trabajos/Predoc/data/fake_data"

* which steps to run
global PASO1 1
global PASO2 1
global PASO3 1
global PASO4 1

if $PASO1 do "$codigo/make_cedulados_fake.do"
if $PASO2 do "$codigo/build_familias.do"
if $PASO3 do "$codigo/validate_familias.do"
if $PASO4 do "$codigo/analisis_concentracion_familia.do"

di as res _n "master_familias.do finished"

*****Defunciones*******

import spss using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\EDG_2000.sav", clear



drop if ANON < 1850
drop if ANOF != 2000
drop if MESN < 1 | MESN > 12
drop if MESF < 1 | MESF > 12

gen edad_meses = (ANOF - ANON)*12 + (MESF - MESN)

drop if edad_meses < 0
drop if edad_meses > 130*12

gen menor1 = edad_meses >= 0 & edad_meses < 12

sum edad_meses, d
tab menor1
count if menor1 == 1

tab edad_meses if menor1==1






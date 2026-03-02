* ── EN EDG 2022: distribución de etnia del fallecido menor de 1 año ──
import spss using "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\Defunciones-20260215T190152Z-1-001\Defunciones\EDG_2022.sav", clear
keep if inlist(cod_edad,1,2,3) | (cod_edad==4 & edad==0)
tab etnia

* ── EN ENV 2022: distribución de etnia de la madre ──
import spss using  "C:\Users\user\Observatorio-Desigualdad-Pobreza\EDG\ENV\ENV_2022.sav", clear
tab etnia
```

Lo que vas a ver es que la **proporción de indígenas** en ambas tablas es similar — alrededor del mismo porcentaje. Si EDG dice 8% indígena y ENV dice 7.5% indígena, la comparación es válida. Si hubiera una diferencia enorme ahí sí habría problema metodológico.

---

### La recodificación que usaremos

En ambas bases:
```
1 → Indígena
2,3,4,5,6,7,8 → No Indígena
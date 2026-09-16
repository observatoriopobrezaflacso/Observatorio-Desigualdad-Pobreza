do "00_config.do"
use "$paneldir/panel_pobreza_laboral.dta", clear

* Replica exacta del original: drop antes de todo
drop if p24 == 999

preserve
collapse (mean) t = pobreza [iw=fexp] if pobreza < . & fexp < ., by(anio)
gen total_orig = 100*t
list anio total_orig, noobs sep(0)
restore

preserve
collapse (mean) t = pobreza [iw=fexp] if pobreza < . & fexp < . & ocupado_orig == 1, by(anio)
gen ocup_orig = 100*t
list anio ocup_orig, noobs sep(0)
restore

preserve
collapse (mean) t = pobreza [iw=fexp] if pobreza < . & fexp < . & ocupado_orig == 1 & area < ., by(anio area)
gen v = 100*t
keep anio area v
reshape wide v, i(anio) j(area)
list, noobs sep(0)
restore

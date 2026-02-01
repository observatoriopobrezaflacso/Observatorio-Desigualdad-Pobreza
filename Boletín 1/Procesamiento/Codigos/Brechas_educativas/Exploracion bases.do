
use "$procesado/ingresos_pc/ing_perca_2015_urb_precios2000.dta", clear




foreach v of varlist p20 p21 p22 p25 p27 p32 p34 p35 {
	
	di "**** `v' *******"


	foreach y of numlist 1991 2005 2015 {


	use "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", clear


		if inrange(`y', 2001, 2005) rename hormas p27

		if inrange(`y', 1990, 1999) {		
			gen p27 = ratmeh1
			replace p27 = 1 if ratmeh1 != .
		}
		
		if inrange(`y', 1990, 2005) {

			gen t = 1
			rename t t_a

			rename edad p03
			rename trabajo p20
			rename actayuda p21 
			rename aunotra p22 
			rename hortrasa p24
			rename ratmeh p25
			rename bustrama  p32
			rename motnobus p34
			rename deseatra p35
			rename hortrahp p51a
			rename hortrahs p51b
			rename hortraho p51c
		}

	
	  codebook `v'

		
}

}

s

p25

*foreach v of varlist p20 p21 p22 p25 p27 p32 p34 p35 {
foreach v of varlist p21{
	
	di "**** `v' *******"


	foreach y of numlist 1991 2005 2015 {


	use "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", clear


		if inrange(`y', 2001, 2005) rename hormas p27

		if inrange(`y', 1990, 1999) {		
			gen p27 = ratmeh1
			replace p27 = 1 if ratmeh1 != .
		}
		
		if inrange(`y', 1990, 2005) {

			gen t = 1
			rename t t_a

			rename edad p03
			rename trabajo p20
			rename actayuda p21 
			rename aunotra p22 
			rename hortrasa p24
			rename ratmeh p25
			rename bustrama  p32
			rename motnobus p34
			rename deseatra p35
			rename hortrahp p51a
			rename hortrahs p51b
			rename hortraho p51c
		}

	
	  tab  `v'
	  tab  `v', nol

		
}

}




log using "$out/exploration.log", replace text


use "$procesado/ingresos_pc/ing_perca_2015_nac_precios2000.dta", clear

*foreach v of varlist p20 p21 p22 p25 p27 p32 p34 p35 {
foreach v of varlist p20 p21 p22 p25 p27 p32 p34 p35 {
	
	di "**** `v' *******"


	foreach y of numlist 1991 1995 2005 2015 {

   
	use "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", clear

	di "**** `y' *******"


		if inrange(`y', 2001, 2005) rename hormas p27

		
		if inrange(`y', 1990, 2005) {
			

			gen t = 1
			rename t t_a

			rename edad p03
			rename trabajo p20
			rename actayuda p21 
			rename aunotra p22 
			rename hortrasa p24
			rename ratmeh p25
			rename bustrama  p32
			rename motnobus p34
			rename deseatra p35
			rename hortrahp p51a
			rename hortrahs p51b
			rename hortraho p51c
		}

	
		if inrange(`y', 1991, 1999) {		
			gen p27 = 2  if p20 == 1 | p22 == 1 | !inlist(p25, 9, .)
			capture replace p27 = 1 if ratmeh1 != .
			capture replace p27 = 1 if hormas != .
		}

	
	  codebook `v'

		
}

}



use "$procesado/ingresos_pc/ing_perca_2015_nac_precios2000.dta", clear

foreach v of varlist p20 p21 p22 p25 p27 p32 p34 p35 {
*foreach v of varlist p32 {
	
	di "**** `v' *******"


	foreach y of numlist 1991 1995 2005 2015 {

	di "**** `y' *******"

	use "$procesado/ingresos_pc/ing_perca_`y'_urb_precios2000.dta", clear


		if inrange(`y', 2001, 2005) rename hormas p27

		if inrange(`y', 1990, 1999) {		
			cap gen p27 = ratmeh1
			cap gen p27 = hormas
			*replace p27 = 1 if ratmeh1 != .
		}
		
		if inrange(`y', 1990, 2005) {

			gen t = 1
			rename t t_a

			rename edad p03
			rename trabajo p20
			rename actayuda p21 
			rename aunotra p22 
			rename hortrasa p24
			rename ratmeh p25
			rename bustrama  p32
			rename motnobus p34
			rename deseatra p35
			rename hortrahp p51a
			rename hortrahs p51b
			rename hortraho p51c
		}

	
	  tab  `v'
	  tab  `v', nol

		
}

}





log close






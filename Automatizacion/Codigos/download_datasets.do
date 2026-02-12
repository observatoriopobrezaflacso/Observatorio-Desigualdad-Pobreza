****************************************************
* 1. Set URL and filenames
****************************************************
local url 

forval year = 2017/2018 {     "https://www.ecuadorencifras.gob.ec/documentos/web-inec/EMPLEO/2025/Junio_2025/1_BDD_ENEMDU_2025_06_SPSS.zip"
local zipfile  "1_BDD_ENEMDU_2025_06_SPSS.zip"
local savfile  "enemdu_persona_2025_06.sav"

****************************************************
* 2. Download ZIP
****************************************************
copy "`url'" "`zipfile'", replace

****************************************************
* 3. Unzip
****************************************************
unzipfile "`zipfile'", replace

****************************************************
* 4. Import SPSS file
****************************************************
import spss using "`savfile'", clear

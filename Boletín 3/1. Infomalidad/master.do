
global user_root "/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Boletín 3"
global componentes "$user_root/1. Infomalidad/2. Armonización de variables/main/componentes"
global desagregaciones "$user_root/1. Infomalidad/2. Armonización de variables/main/desagregaciones"
global analisis "$user_root/1. Infomalidad/3. Analisis"




* COMPONENTES


* Tiene RUC
do "$componentes/armonizacion_institucion_formal.do" 


* Trabajo no remunerado
do "$componentes/familiar_no_remunerado.do" 


* Seguridad Scocial
do "$componentes/iess_issfa_isspol.do" 


* Empleo adecuado
do "$componentes/adec.do"
 
 
* DESAGREGACIONES


* Educación 
do "$desagregaciones/armonizacion_educacion.do"

* Etnia
do "$desagregaciones/armonizacion_etnia.do"

* PEA
do "$desagregaciones/armonizacion_pea.do"

* Rama

do "$desagregaciones/rama/master_rama.do"


* UNIÓN DE BASES

do "$analisis/merge_informal.do"


* ANALISIS DESCRIPTIVOS


do "$analisis/analisis_descriptivo.do"



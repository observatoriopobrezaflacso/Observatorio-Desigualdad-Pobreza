% ---------------------------------------------------------------------------
% Contenido del Boletín 3. Las cifras NO se escriben a mano: van entre {{ }}
% y se calculan con las salidas de analisis_descriptivo.do.
% Ver README.md para la sintaxis completa.
% ---------------------------------------------------------------------------

# Boletín 3: Informalidad laboral, pobreza y homicidios en la niñez y adolescencia en Ecuador

En este tercer boletín del Observatorio de Pobreza, Desigualdad y Empleo dirigimos la mirada al mundo del trabajo y a los homicidios de niños, niñas y adolescentes. Analizamos tres problemáticas acuciantes para el país: la informalidad laboral, la pobreza laboral y los homicidios de niñas, niños y adolescentes.

[[equipo]]

Se propone una definición conceptual y operativa de informalidad para el contexto ecuatoriano. Una serie histórica desde {{inf_sin_ruc.primero}} hasta {{ultimo}} evidencia un deterioro de este indicador iniciado en {{anio_minimo(inf, desde=2003)}}, que borra el progreso realizado en más de 15 años. Un análisis de la evolución del número de condiciones de informalidad también muestra que la informalidad se ha profundizado. Las desagregaciones por área, género, edad, etnia, nivel educativo, deciles de ingreso, provincia y rama de actividad permiten identificar que los indígenas, las personas de la tercera edad y los trabajadores de la ruralidad sufren las prevalencias más altas de informalidad. El análisis cuantitativo se complementa con las voces de dos especialistas, que ayudan a leer las cifras desde la experiencia cotidiana del trabajo precario y desde las transformaciones recientes del empleo público.

En la segunda parte del boletín se aborda la pobreza laboral, que da cuenta de las realidades precarias en las que trabajar no basta para salir de la pobreza. En la última parte se documenta el alarmante aumento de los homicidios de niñas, niños y adolescentes en los últimos años, con especial atención a las profundas desigualdades étnicas que lo atraviesan.

## La informalidad laboral en Ecuador

Lo “informal” es aquello que carece de forma. En el ámbito laboral, la forma la brindan las instituciones creadas por el Estado. En este marco, se define al trabajo informal como todo aquel que ocurre por fuera del marco normativo estatal y, por ende, no asegura la garantía de derechos ni el cumplimiento de obligaciones.

En Ecuador la formalidad requiere como base el salario básico unificado, jornada semanal de 40 horas, afiliación a la seguridad social y cumplimiento tributario. Así, para propósitos de este boletín, se considera que un trabajador es informal si cumple alguna de las siguientes condiciones:

- No cumple las condiciones de empleo adecuado (gana menos del salario mínimo legal o trabaja menos de cuarenta horas a la semana cuando desearía trabajar más).
- Es un trabajador no remunerado.
- No está afiliado a la seguridad social.
- El empleador no tiene Registro Único de Contribuyente (RUC).

El {{G.componentes}} muestra la evolución de la informalidad y de cada uno de estos componentes. En {{ultimo}}, el {{inf[-1]}}% de los trabajadores estuvieron en informalidad. Este nivel es similar al de inicios de siglo e implica un retroceso frente al progreso logrado entre 2007 y 2014, lapso en el que bajó del {{inf[2007]|0}}% al {{inf[2014]|0}}%.

Al desagregar los componentes de este indicador se ve que el trabajo no adecuado llegó a su máximo histórico (exceptuando el año 2020) en {{anio_maximo(no_adec, desde=2001, excluir=[2020])}}, situándose en {{maximo(no_adec, desde=2001, excluir=[2020])}}%. Su punto más bajo fue de {{minimo(no_adec, desde=2001)}}% en {{anio_minimo(no_adec, desde=2001)}}. Por su parte, el empleo no remunerado cayó de {{no_remun[2006]}}% a {{no_remun[2014]}}% entre 2006 y 2014, y aumentó al {{no_remun[-1]}}% en {{ultimo}}. El trabajo sin afiliación a la seguridad social, la principal causa de informalidad, pasó del {{no_iess[2006]}}% al {{no_iess[2014]}}% entre 2006 y 2014, para después aumentar al {{no_iess[-1]}}% en {{ultimo}}. Finalmente, el trabajo en organizaciones sin RUC llegó al {{no_ruc[-1]}}% en {{ultimo}} y representa el {{ordinal(rango(no_ruc, -1, desde=2004))}} valor más alto desde 2004, mostrando un aumento de {{no_ruc[-1] - no_ruc[2014]}} puntos porcentuales frente a 2014.

En la década de los noventa el indicador es más volátil. Esto se debe principalmente al componente de empleo adecuado y, específicamente, a las fluctuaciones del salario mínimo en un contexto de elevada inflación. El empleo sin afiliación creció {{no_iess[1999] - no_iess[1990]}} puntos porcentuales en este periodo, mientras que el no remunerado se mantuvo estable. Nótese que, como se explica en la nota del gráfico, los datos de esta década no son comparables con la información del siguiente siglo.

[[grafico: componentes]]

El {{G.condiciones}} muestra la profundidad de la informalidad al sumar el número de condiciones de informalidad que afectan a los trabajadores simultáneamente. En 2003 lo más frecuente era tener tres condiciones simultáneamente ({{cond3[2003]}}%). Este porcentaje llega a {{cond3[-1]}}% en {{ultimo}}. El porcentaje de ocupados que sufren de cuatro condiciones al mismo tiempo también sube en este periodo de {{cond4[2003]}}% a {{cond4[-1]}}%. Esta tendencia indica que la informalidad no solo se ha extendido, sino que se ha profundizado.

[[grafico: condiciones]]

> **Cuadro 1. La informalidad más allá de las cifras**
> El abordaje cualitativo permite visualizar aspectos de la realidad laboral en el país que pueden quedar invisibilizados si se analizan solo los números. “Las cifras laborales muchas veces ocultan más de lo que muestran”, señala María Gabriela Palacio. Para la investigadora, las bajas tasas de desempleo en Ecuador que pueden ser, en algunos aspectos, similares a las reportadas por países desarrollados no significan efectivamente bienestar, sino más bien la necesidad de aceptar trabajos precarios, informales o múltiples actividades simultáneas para sostener la vida cotidiana, debido, entre otras cosas, a la falta de provisiones del Estado. “Las encuestas nos muestran una fotografía estática, pero no reflejan las trayectorias reales: personas que oscilan entre desempleo, subempleo, endeudamiento, jornadas extenuantes y trabajo de cuidado no remunerado”.
>
> Desde una mirada etnográfica, la experta explica cómo se experimenta la precariedad y la inestabilidad laboral, que atraviesan profundamente las trayectorias de vida, especialmente de mujeres, hogares pobres, población migrante y comunidades racializadas. Las jornadas de trabajo están marcadas por la pluriactividad: mujeres que preparan alimentos para venta callejera, trabajan luego por horas en empleo doméstico, continúan con tareas de cuidado y complementan ingresos mediante ventas informales. “Nada de eso aparece realmente en las estadísticas laborales”, afirma. Además, advierte que gran parte de la economía ecuatoriana se sostiene sobre trabajo de reproducción social no remunerado y sobre redes familiares y comunitarias invisibles para las mediciones oficiales. En este punto también se observa cómo las cargas de cuidado que recaen sobre todo en las mujeres incrementan la pobreza subjetiva. “(…) si el ingreso laboral debe destinarse para el cuidado de todos los miembros de la familia, esa presión sobre quién obtiene los ingresos laborales es altísima, y de nuevo, aunque no aparezca como pobre oficialmente, es una población empobrecida a nivel subjetivo”.
>
> Para Palacio, estas condiciones producen efectos profundos sobre las expectativas y posibilidades de las personas. La incertidumbre laboral, incluso entre quienes tienen empleo “adecuado”, genera una fuerte sensación de desmotivación frente a la promesa de movilidad social. “Las ganancias del mercado laboral no corresponden al esfuerzo educativo y desincentivan la formación de capital humano”.

El {{G.area}} muestra la desagregación de la informalidad por área. En el sector rural alcanza el {{inf_area[-1,'Rural']}}% en {{ultimo}}, mostrando una tendencia creciente de precarización desde 2015. En el sector urbano, este indicador llega al {{inf_area[-1,'Urbana']}}%, por lo que la brecha es de {{inf_area[-1,'Rural'] - inf_area[-1,'Urbana']}} puntos porcentuales. En {{anio_minimo(inf, desde=2003)}}, cuando la informalidad se encontraba en sus puntos más bajos, llegó al {{inf_area[anio_minimo(inf, desde=2003),'Rural']}}% en el área rural y al {{inf_area[anio_minimo(inf, desde=2003),'Urbana']}}% en la urbana.

[[grafico: area]]

En el {{G.sexo}} se presenta la brecha de género. En el promedio de la serie, la diferencia es de {{promedio(inf_sexo, grupo='mujer') - promedio(inf_sexo, grupo='hombre')}} puntos porcentuales en detrimento de las mujeres. Entre 2005 y 2013 la brecha parece cerrarse de forma que, en varios años, la diferencia no es estadísticamente significativa. Desde 2014 hasta {{ultimo}} la brecha se abre nuevamente, llegando a un promedio de {{promedio(inf_sexo, 2014, ultimo, 'mujer') - promedio(inf_sexo, 2014, ultimo, 'hombre')}} puntos porcentuales en este periodo.

La informalidad de ambos sexos se experimenta de forma diferente. El trabajo no remunerado es {{veces(no_remun_sexo[-1,'mujer'], no_remun_sexo[-1,'hombre'])}} veces más prevalente entre mujeres que entre hombres, con porcentajes de {{no_remun_sexo[-1,'mujer']|0}}% y {{no_remun_sexo[-1,'hombre']|0}}% en {{ultimo}}, respectivamente. El trabajo no adecuado también es {{no_adec_sexo[-1,'mujer'] - no_adec_sexo[-1,'hombre']|0}} puntos porcentuales más alto en mujeres ({{no_adec_sexo[-1,'mujer']}}%) que en hombres ({{no_adec_sexo[-1,'hombre']}}%). Además, un 14.3% de las mujeres que trabajan menos de 40 horas explican que no desean trabajar más horas porque tienen que cuidar un familiar. Este porcentaje es de 0.39% en el caso de los hombres.

[[grafico: sexo]]

Por grupos de edad ({{G.edad}}), los adultos mayores trabajadores presentan la mayor tasa de informalidad laboral, lo que refleja las limitaciones de cobertura de un sistema de seguridad social contributivo que supone la existencia de una relación laboral formal, cuando esta en la práctica es una excepción. En {{ultimo}}, la informalidad de este grupo fue de {{inf_edad[-1,'65+']}}% y, a diferencia de la serie nacional, es relativamente estable en todo el periodo de análisis. La caída de la informalidad que se experimentó entre 2007 y 2014 se concentró entre los jóvenes y adultos, con disminuciones de cerca de {{inf_edad[2007,'18-29'] - inf_edad[2014,'18-29']|0}} y {{inf_edad[2007,'30-64'] - inf_edad[2014,'30-64']|0}} puntos porcentuales, respectivamente, llegando a {{inf_edad[2014,'18-29']}}% y {{inf_edad[2014,'30-64']}}%. En {{ultimo}}, volvió al {{inf_edad[-1,'18-29']}}% entre los jóvenes y al {{inf_edad[-1,'30-64']}}% entre los adultos.

[[grafico: edad]]

La desagregación por etnia ({{G.etnia}}) muestra que los indígenas son el grupo con mayor informalidad laboral, alcanzando el {{inf_etnia[-1,'Indígena']}}% de la población ocupada en {{ultimo}}, nivel similar al de inicio del siglo. En el año con menor informalidad ({{anio_minimo(inf_etnia, grupo='Indígena')}}), llegó al {{minimo(inf_etnia, grupo='Indígena')}}%. Entre las personas blanco/mestizas, la informalidad llega a ({{inf_etnia[-1,'Blanco/Mestizo']}}%) en 2025, por lo que la brecha en ese año frente a los indígenas es de  {{inf_etnia[-1,'Indígena'] - inf_etnia[-1,'Blanco/Mestizo']}} puntos porcentuales. Históricamente, la población afroecuatoriana ha sufrido más informalidad que la blanco/mestiza, con una brecha promedio de {{promedio(inf_etnia, grupo='Negro/Afro') - promedio(inf_etnia, grupo='Blanco/Mestizo')}} puntos porcentuales durante el periodo de análisis. En los últimos años la diferencia se redujo y se cerró en 2025, aunque existen desviaciones importantes debido a que la estimación de la informalidad entre afroecuatorianos es ruidosa debido a que su muestra en la ENEMDU es reducida. 


[[grafico: etnia]]

Al analizar la informalidad por nivel educativo se observa una brecha de {{inf_educ[-1,'No universitaria'] - inf_educ[-1,'Universitaria']}} puntos porcentuales en favor de las personas con educación universitaria (véase el {{G.educacion}}). Entre quienes no tienen educación universitaria, la informalidad llega al {{inf_educ[-1,'No universitaria']}}%, mientras que entre quienes sí la tienen es del {{inf_educ[-1,'Universitaria']}}%. Entre los universitarios, la informalidad descendió desde el inicio de la serie, años antes de la caída a nivel nacional, reduciéndose del {{inf_educ[2003,'Universitaria']}}% en 2003 al {{inf_educ[2014,'Universitaria']}}% en 2014. Entre los no universitarios, la informalidad se redujo en menor medida, pasando del {{inf_educ[2003,'No universitaria']}}% al {{inf_educ[2014,'No universitaria']}}% en ese periodo.

[[grafico: educacion]]

El {{G.deciles}} muestra la informalidad por deciles de ingreso laboral, comparando los niveles pre (2019) y pospandemia (2024). Se presentan únicamente los deciles superiores (del 6 al 10), ya que el ingreso máximo de los 5 primeros deciles es inferior al salario básico, por lo que la informalidad es del 100% al encontrarse en condición de empleo no adecuado. La informalidad disminuye a medida que aumenta el ingreso, pero incluso entre el 10% de trabajadores con mayores ingresos laborales la prevalencia ronda el {{inf_decil[2024,10]}}%, tanto en 2019 como en 2024. La comparación entre ambos años revela un deterioro generalizado en los deciles medios. En el decil 6 la informalidad pasó del {{inf_decil[2019,6]}}% al {{inf_decil[2024,6]}}%, un aumento de {{inf_decil[2024,6] - inf_decil[2019,6]}} puntos porcentuales. En los deciles más altos la brecha entre ambos periodos se reduce, hasta volverse prácticamente nula en el decil 10. Esto indica que la crisis sanitaria afectó de manera desproporcionada a los trabajadores de ingresos medios.

[[grafico: deciles]]

La {{T.provincia}} presenta la tasa de informalidad por provincia para años seleccionados entre {{inf_prov.primero}} y {{inf_prov.ultimo}}. Las provincias amazónicas encabezan la tabla: {{lista(ranking(inf_prov, -1)[:4])}} registran los niveles más altos en {{inf_prov.ultimo}}, consistentes con la predominancia de actividades agropecuarias y de subsistencia en estas zonas. En el otro extremo, {{lista(ranking(inf_prov, -1, asc=True)[:2][::-1])}} son las provincias con menor informalidad, lo que refleja la concentración de la administración pública, los servicios financieros y el turismo formal en Quito y en el archipiélago. La diferencia entre la provincia más informal ({{mayor(inf_prov, -1)[0]}}) y la menos informal ({{menor(inf_prov, -1)[0]}}) es de {{mayor(inf_prov, -1)[1] - menor(inf_prov, -1)[1]}} puntos porcentuales. Todas las provincias muestran una caída entre 2003 y 2015, seguida de un repunte entre 2020 y {{inf_prov.ultimo}}. Incluso en los mejores años, varias provincias de la Sierra central como Bolívar y Chimborazo mantuvieron un porcentaje de informalidad por encima del 80%, lo que sugiere la presencia de factores estructurales que no han sido resueltos.

[[tabla: provincia]]

La {{T.rama}} desagrega la informalidad por rama de actividad. {{lista(ranking(inf_rama, -1, minimo_casos=1.0)[:3])}} son los sectores con mayor prevalencia en {{ultimo}}. En el extremo opuesto, las que registran la tasa más baja son {{lista(ranking(inf_rama, -1, asc=True, minimo_casos=1.0)[:3])}}. Entre 2003 y 2015, la mayoría de los sectores experimentaron mejoras, en algunos casos superiores a 20 puntos porcentuales, como en minas y canteras (que pasó de {{inf_rama[2003,'Minas y canteras']}}% a {{inf_rama[2015,'Minas y canteras']}}%) y servicios administrativos (de {{inf_rama[2003,'Servicios administrativos']}}% a {{inf_rama[2015,'Servicios administrativos']}}%). Sin embargo, entre 2015 y {{ultimo}} se observa un retroceso generalizado. El caso de minas y canteras es ilustrativo. Tras haber caído al {{inf_rama[2015,'Minas y canteras']}}% en 2015, la informalidad en este sector subió al {{inf_rama[-1,'Minas y canteras']}}% en {{ultimo}}.

[[tabla: rama]]

> **Cuadro 2. Empleo público**
> El sector público ha sido un espacio clave de estabilidad laboral y movilidad social para las clases medias en el Ecuador. Desde inicios de los 2000, además, se dio un fuerte proceso de profesionalización orientado a fortalecer las capacidades técnicas del Estado. Sin embargo, en los últimos años se han transformado las dinámicas de contratación lo que ha debilitado la estabilidad laboral y ha generado impactos sobre el mercado laboral en general. La entrevista a Daniel Falconí permite profundizar en estas transformaciones y sus efectos en las trayectorias laborales.
>
> “En el sector público no puede hablarse estrictamente de informalidad, porque toda relación laboral está regulada por una ley. Pero sí hay una precarización creciente”, explica Daniel Falconí. Según el investigador, desde 2019 el Estado ha reemplazado progresivamente los nombramientos permanentes por contratos provisionales y temporales, debilitando la estabilidad laboral y la posibilidad de construir una carrera pública. Esto ha generado una segmentación dentro del propio Estado: trabajadores con menos garantías, más expuestos a despidos, cambios políticos y rotación constante.
>
> El experto advierte que esta reducción del Estado también está impactando al mercado laboral en general. Profesionales con 20 o 25 años de experiencia, alta formación académica y especialización salen del sector público y presionan un mercado ya saturado. “Muchos terminan rotando entre contratos temporales o pasando a actividades con ingresos más bajos y menor estabilidad”, señala. El problema afecta especialmente a personas mayores de 45 años, quienes enfrentan mayores barreras para reinsertarse laboralmente y suelen cargar además con el estigma asociado al trabajo público.
>
> Este proceso forma parte de un ajuste estatal desordenado tras la expansión del aparato público entre 2007 y 2017. “El Estado creció muy rápido, pero luego no existió una planificación clara para contraerse”, sostiene el experto. El resultado ha sido un debilitamiento de capacidades institucionales y una creciente precarización incluso en espacios históricamente asociados a estabilidad y protección laboral.

% ---------------------------------------------------------------------------
% Las secciones de pobreza laboral y homicidios no provienen de
% analisis_descriptivo.do: sus cifras están escritas a mano y sus gráficos se
% toman de DIR_RECURSOS (ver herramientas/extraer_figuras_docx.py).
% ---------------------------------------------------------------------------

## Pobreza laboral

La pobreza laboral mide el porcentaje de personas ocupadas que viven en hogares cuyo ingreso per cápita se encuentra por debajo de la línea de pobreza. De esta manera se da cuenta del extremo de la precariedad laboral, cuando la ilusión de bienestar a través del empleo no se cumple. No basta con trabajar para salir de la pobreza.

El {{G.pobreza_nacional}} muestra su evolución entre {{pob.primero}} y {{ultimo}}. La tasa pasó del {{pob[2001]}}% en 2001 al {{pob[2017]}}% en 2017, una reducción de {{pob[2001] - pob[2017]|0}} puntos porcentuales. Parte de esta reducción se debe al efecto rebote de la economía tras la crisis financiera del 2000. Desde entonces, el indicador se ha mantenido relativamente estable, con un repunte durante la pandemia ({{pob[2020]}}% en 2020) y un retorno posterior al {{pob[-1]}}% en {{ultimo}}. Entre los ocupados pobres, un {{pob_horas[-1,'40 horas o más']}}% trabaja 40 horas o más a la semana y un {{pob_horas[-1,'Menos de 40 horas, desea y puede trabajar más']}}% trabaja menos de 40 horas a la semana, pero desea y está disponible a trabajar más.

[[grafico: pobreza_nacional]]

La desagregación por área ({{G.pobreza_area}}) revela una brecha persistente entre los sectores urbano y rural. En 2001, la pobreza laboral rural era de {{pob_area[2001,'Rural']}}% frente al {{pob_area[2001,'Urbana']}}% en el área urbana. Para 2017, ambas cayeron al {{pob_area[2017,'Rural']}}% y al {{pob_area[2017,'Urbana']}}%, respectivamente. En {{ultimo}}, la tasa rural se ubica en {{pob_area[-1,'Rural']}}% y la urbana en {{pob_area[-1,'Urbana']}}%, lo que representa una brecha de {{pob_area[-1,'Rural'] - pob_area[-1,'Urbana']}} puntos porcentuales.

[[grafico: pobreza_area]]

El {{G.pobreza_educacion}} presenta la pobreza laboral por nivel educativo. La diferencia entre trabajadores sin educación superior y quienes sí la tienen es de {{pob_educ[-1,'Sin educación superior'] - pob_educ[-1,'Con educación superior']}} puntos porcentuales en {{ultimo}} ({{pob_educ[-1,'Sin educación superior']}}% frente a {{pob_educ[-1,'Con educación superior']}}%). Ambos grupos experimentaron una mejora sostenida entre 2001 y 2017: la pobreza entre los trabajadores sin educación superior pasó del {{pob_educ[2001,'Sin educación superior']}}% al {{pob_educ[2017,'Sin educación superior']}}%, y entre quienes tienen educación superior del {{pob_educ[2001,'Con educación superior']}}% al {{pob_educ[2017,'Con educación superior']}}%. La tasa de pobreza de los ocupados más educados se ha mantenido relativamente estable desde 2015 alrededor del {{pob_educ[2015,'Con educación superior']|0}}% y no se vio significativamente afectada por la pandemia. Esto indica que la educación superior funciona como un factor de protección contra la pobreza laboral.

[[grafico: pobreza_educacion]]

## Homicidios de niñas, niños y adolescentes

La tasa de homicidios de las niñas, niños y adolescentes (NNA), que corresponde a la población de menos de 18 años, ha crecido en 1050% entre 2019 y 2025 ({{G.homicidios}}), pasando de 0.8 a 8.4. En términos nominales, esto significa que el último año murieron 545 NNA por esta causa. Esto es más que todos los homicidios desde el 2014 hasta el 2021 juntos. La población afroecuatoriana es la más afectada, su tasa creció de alrededor de 0.7 en 2019 a 14.6 en 2025, un incremento de 2085% y poco menos del doble de la tasa de otras etnias (8.3).

[[grafico: homicidios]]

## Conclusiones

En este boletín se analizaron 3 problemáticas acuciantes para el país: la informalidad, la pobreza laboral y los homicidios de niñas, niños y adolescentes (NNA). Se observó que la informalidad es la norma en el país, con cerca de 8 de cada 10 trabajadores laborando en circunstancias que no garantizan las condiciones mínimas de bienestar establecidas formalmente. Entre los indígenas, los trabajadores del sector rural, los mayores de 65 años y varias provincias del oriente, esta situación abarca a casi la totalidad de sus integrantes.

Sobre la pobreza laboral, se vio que el {{pob[-1]}}% de los trabajadores viven en condición de pobreza monetaria. De ellos, un tercio trabajó 40 horas o más a la semana y un cuarto trabajó menos de este número de horas aun queriendo y estando dispuesto a trabajar más. La mayoría están en el sector rural y no tienen educación universitaria. Esto sugiere la necesidad de ampliar el alcance de los programas de protección social y/o mejorar la focalización de los existentes.

Finalmente, es preocupante cómo la violencia ha permeado tanto que la tasa de homicidios de niñas, niños y adolescentes (NNA) se ha multiplicado por 10 en apenas 6 años. Más inquietantes aún son las desigualdades socioeconómicas y étnicas que concluyen en que esta tasa se haya multiplicado por 20 entre NNA afroecuatorianos.

## Biografías de los entrevistados

### María Gabriela Palacio

Es profesora de Estudios del Desarrollo en la Universidad de Leiden. Trabaja en temas de economía política y estratificación social, con un enfoque en América Latina. Su investigación examina cómo las economías políticas, los mercados laborales y los arreglos institucionales moldean formas diferenciadas de inclusión y exclusión dentro y a través de las fronteras.

### Daniel Falconí

Profesor en la Maestría de Contabilidad y Finanzas de la Universidad Nacional de Loja. Ha desempeñado las funciones de Viceministro de Economía, Asesor del Despacho Ministerial, Subsecretario de Consistencia Macroeconómica, Subsecretario de Política Fiscal, Subsecretario de Financiamiento Público y Director Nacional de Programación Fiscal.

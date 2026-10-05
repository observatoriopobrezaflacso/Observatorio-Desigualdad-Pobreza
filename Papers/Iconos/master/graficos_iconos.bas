Attribute VB_Name = "GraficosIconos"
'==============================================================================
' GRÁFICOS DEL PAPER "ÍCONOS" DENTRO DEL LIBRO CONSOLIDADO
'
' Dibuja, sobre las hojas de Iconos_resultados.xlsx, los gráficos del documento
'   "Reducción de la desigualdad en Ecuador durante los 2000s_final 22092026.docx"
' que se arman con los datos que produce el master. Sólo se dibujan los que
' están en el paper, con su número:
'
'   G01  Gráfico 1   Gini urbano                        -> gini_serie
'   G02  Gráfico 2   Gini nacional                      -> gini_serie
'   G03  Gráfico 3   Índice de Palma                    -> palma_serie
'   G04  Gráfico 4   Participación en el ingreso (SRI)  -> participacion_sri
'   G05  Gráfico 5   Crecimiento del PIB y Gini urbano  -> pib_gini
'   G06  Gráfico 6   GIC urbano                         -> gic_urbano
'   G07  Gráfico 7   GIC nacional                       -> gic_nacional
'   G08  Gráfico 8   Composición del ingreso            -> decomp_nacional
'   G09  Gráfico 9   Remesas por cuartil                -> remesas_cuartil
'   G10  Gráfico 10  Bono por cuartil                   -> bono_cuartil
'   G11  Gráfico 11  Elasticidad ingreso-Gini           -> decomp_nacional
'   G12  Gráfico 12  Brechas salariales                 -> brechas
'   G13  Gráfico 13  Prima salarial (urbano)            -> prima_urbano
'   G14  Gráfico 14  Empleo adecuado (urbano)           -> adecuado_urbano
'   G15  Gráfico 15  Salario básico real y Gini         -> salario_basico
'   G16  Gráfico 16  Rango superior del impuesto a la renta -> tributacion
'   G17  Gráfico 17  Gini SRI, antes y después de imp.  -> gini_sri
'
' Cada gráfico se dibuja en la hoja de la derecha y lee sólo de ella. Las hojas
' remesas_cuartil, bono_cuartil, prima_urbano y adecuado_urbano las escribe
' consolidar_excel.do con la forma que pide el gráfico (filtrada al urbano, de
' largo a ancho), así que la macro no arma datos por su cuenta ni usa hojas
' ocultas. Las columnas se buscan por su encabezado, no por su posición.
'
' Los Gráficos 4, 5, 15, 16 y 17 no salen de la ENEMDU (SRI, BCE, Ministerio
' del Trabajo): sus hojas las escribe consolidar_excel.do con los valores
' tecleados y calcula lo que se puede calcular (crecimiento del PIB, dólares de
' 2015); el Gini de los Gráficos 5 y 15 es el de gini_serie. Así todos los
' gráficos del paper leen sólo de este libro, que trae sólo sus 15 hojas.
'
' El formato sale del XML de los gráficos del propio documento: dispersión con
' líneas rectas y marcadores, sin título, leyenda abajo, líneas de división
' horizontales grises, Arial, paleta azul / vino / verde / naranja, y las
' etiquetas de valor sólo sobre los puntos que el paper etiqueta.
'
' USO
'   1. Abrir Iconos_resultados.xlsx.
'   2. Editor de Visual Basic (Herramientas -> Macro -> Editor, o ALT+F11).
'      Ahí: Archivo -> Importar archivo -> este .bas. Si el importador se
'      porta mal, Insertar -> Módulo y pegar el contenido.
'   3. Ejecutar CrearGraficosIconos.
'   Se puede volver a correr cada vez que se regeneran los datos: borra los
'   gráficos que hizo antes y los vuelve a dibujar.
'
' También corre sobre gic_paper.xlsx: ahí encuentra sólo las dos hojas del GIC
' y dibuja los Gráficos 6 y 7.
'
' Para conservar la macro dentro del libro hay que guardarlo como .xlsm.
'==============================================================================

Option Explicit

' Paleta del paper.
Private Const AZUL As String = "1A476F"
Private Const VINO As String = "90353B"
Private Const VERDE As String = "55752F"
Private Const NARANJA As String = "E37E00"
Private Const NEGRO As String = "000000"
Private Const VERDE_PIB As String = "339966"     ' barras del Gráfico 5
Private Const GRIS_VERDE As String = "6E8E84"    ' Gráfico 4
Private Const MORADO As String = "7B6888"        ' Gráfico 4

' Grises de ejes y texto.
Private Const GRIS_TITULO As String = "404040"
Private Const GRIS_TEXTO As String = "595959"
Private Const GRIS_EJE_X As String = "BFBFBF"
Private Const GRIS_EJE_Y As String = "D9D9D9"

Private Const FUENTE As String = "Arial"

' Centinela para "escala automática" en los ejes. No se usa 0 porque 0 es una
' escala legítima (el eje X del GIC arranca justo en 0).
Private Const AUTO As Double = -1E+30

' Hoja oculta que usaban versiones anteriores de esta macro. Ya no se usa; si
' el libro la trae, se borra (ver BorrarHojaAuxiliarVieja).
Private Const HOJA_AUX_VIEJA As String = "graficos_datos"

Private mLibro As Workbook
Private mHechos As Long
Private mFaltan As String
Private mErrores As String
Private mColorFallas As String

'==============================================================================
' PUNTO DE ENTRADA
'==============================================================================
Public Sub CrearGraficosIconos()

    Set mLibro = ActiveWorkbook
    mHechos = 0
    mFaltan = ""
    mErrores = ""
    mColorFallas = ""

    ' OJO: aquí NO se apaga ScreenUpdating. En Excel para Mac, con el
    ' redibujado apagado se pierden en silencio cambios de formato de los
    ' elementos del gráfico (color del texto de las etiquetas, quitar el
    ' título automático). Es más lento, pero es lo que hace que se apliquen.

    ' Cada gráfico va con su propia red: si uno falla, se anota y los demás
    ' siguen. Sin esto un error en el tercero dejaba los últimos sin dibujar y
    ' no quedaba rastro de por qué.
    On Error Resume Next

    BorrarHojaAuxiliarVieja
    Anotar "hoja auxiliar vieja"
    BorrarGraficosViejos
    Anotar "graficos viejos"

    Grafico01_GiniUrbano
    Anotar "G01"
    Grafico02_GiniNacional
    Anotar "G02"
    Grafico03_Palma
    Anotar "G03"
    Grafico04_ParticipacionSRI
    Anotar "G04"
    Grafico05_PibGini
    Anotar "G05"
    Grafico06_GicUrbano
    Anotar "G06"
    Grafico07_GicNacional
    Anotar "G07"
    Grafico08_Composicion
    Anotar "G08"
    Grafico09_RemesasCuartil
    Anotar "G09"
    Grafico10_BonoCuartil
    Anotar "G10"
    Grafico11_Elasticidad
    Anotar "G11"
    Grafico12_Brechas
    Anotar "G12"
    Grafico13_Prima
    Anotar "G13"
    Grafico14_EmpleoAdecuado
    Anotar "G14"
    Grafico15_SalarioBasico
    Anotar "G15"
    Grafico16_Tributacion
    Anotar "G16"
    Grafico17_GiniSRI
    Anotar "G17"

    On Error GoTo 0

    Dim msj As String
    msj = Ac("Gr{a}ficos dibujados: ") & mHechos
    If mFaltan <> "" Then msj = msj & vbLf & vbLf & _
        "Sin dibujar, porque falta la hoja:" & mFaltan
    If mErrores <> "" Then msj = msj & vbLf & vbLf & "Errores:" & mErrores
    If mColorFallas <> "" Then msj = msj & vbLf & vbLf & _
        Ac("V{i}as de color: ") & mColorFallas

    MsgBox msj, vbInformation

End Sub

' Anota el error que haya quedado del gráfico anterior y limpia, para que el
' siguiente empiece con la cuenta en cero.
Private Sub Anotar(etq As String)

    If Err.Number <> 0 Then
        mErrores = mErrores & vbLf & "  " & etq & ": " & Err.Number & " " & Err.Description
        Err.Clear
    End If

End Sub

'==============================================================================
' HOJA AUXILIAR DE VERSIONES ANTERIORES
'
' Antes seis gráficos leían de una hoja oculta, graficos_datos, que esta macro
' armaba filtrando y reordenando otras tablas. Ahora esa forma la arma
' consolidar_excel.do y cada gráfico lee de su propia hoja. Si el libro todavía
' trae la hoja vieja, se borra para que no quede una copia desactualizada.
'==============================================================================
Private Sub BorrarHojaAuxiliarVieja()

    Dim ws As Worksheet

    Set ws = Hoja(HOJA_AUX_VIEJA)
    If ws Is Nothing Then Exit Sub

    Application.DisplayAlerts = False
    ws.Visible = xlSheetVisible
    ws.Delete
    Application.DisplayAlerts = True

End Sub

'==============================================================================
' GRÁFICOS DE VERSIONES ANTERIORES
'
' Versiones anteriores de esta macro dibujaban gráficos que no están en el
' paper (horas e ingreso por hora por nivel educativo, crecimiento del empleo)
' y numeraban distinto el empleo adecuado (G17) y el Gini del SRI (G04). Si el
' libro todavía los trae, se borran para que queden sólo los del paper.
'==============================================================================
Private Sub BorrarGraficosViejos()

    Dim viejos As Variant, ws As Worksheet, i As Long, k As Long

    viejos = Array("G04_gini_sri", "G13b_horas_semanales", "G13c_ingreso_hora", _
                   "G14_crecimiento_1992_1999", "G15_crecimiento_2001_2010", _
                   "G16_crecimiento_2011_2024", "G16b_crecimiento_2001_2024", _
                   "G17_empleo_adecuado")

    For Each ws In mLibro.Worksheets
        For i = ws.ChartObjects.Count To 1 Step -1
            For k = LBound(viejos) To UBound(viejos)
                If StrComp(ws.ChartObjects(i).Name, viejos(k), vbTextCompare) = 0 Then
                    ws.ChartObjects(i).Delete
                    Exit For
                End If
            Next k
        Next i
    Next ws

End Sub

'==============================================================================
' UN SUB POR GRÁFICO
'==============================================================================

Private Sub Grafico01_GiniUrbano()

    Dim ws As Worksheet, ch As Chart, s As Series, n As Long

    Set ws = HojaOAviso("gini_serie", "G01")
    If ws Is Nothing Then Exit Sub
    n = UltimaFila(ws, 1)

    Set ch = Lienzo(ws, "G01_gini_urbano", 425, 238, 6)
    Set s = Serie(ch, "Gini urbano", ws.Range(ws.Cells(2, 1), ws.Cells(n, 1)), _
                  ws.Range(ws.Cells(2, 2), ws.Cells(n, 2)), AZUL, xlMarkerStyleCircle, 6)
    Etiquetas s, "1991,2001,2011,2025", "0.00", "b", AZUL

    Base ch, False
    EjeX ch, "", 1990, 2025, AUTO, "0", False
    EjeY ch, "Coeficiente de Gini", AUTO, AUTO, AUTO, "0.00", True
    Listo

End Sub

Private Sub Grafico02_GiniNacional()

    Dim ws As Worksheet, ch As Chart, s As Series, n As Long

    Set ws = HojaOAviso("gini_serie", "G02")
    If ws Is Nothing Then Exit Sub
    n = UltimaFila(ws, 1)

    Set ch = Lienzo(ws, "G02_gini_nacional", 425, 238, 30)
    Set s = Serie(ch, "Gini nacional", ws.Range(ws.Cells(2, 1), ws.Cells(n, 1)), _
                  ws.Range(ws.Cells(2, 3), ws.Cells(n, 3)), AZUL, xlMarkerStyleCircle, 6)
    Etiquetas s, "2001,2007,2011,2024,2025", "0.00", "b", AZUL

    Base ch, False
    EjeX ch, "", 2000, 2025, AUTO, "0", False
    EjeY ch, "Coeficiente de Gini", AUTO, AUTO, AUTO, "0.00", True
    Listo

End Sub

Private Sub Grafico03_Palma()

    Dim ws As Worksheet, ch As Chart, s As Series, n As Long

    Set ws = HojaOAviso("palma_serie", "G03")
    If ws Is Nothing Then Exit Sub
    n = UltimaFila(ws, 1)

    Set ch = Lienzo(ws, "G03_palma", 425, 238, 6)
    Set s = Serie(ch, "Ecuador", ws.Range(ws.Cells(2, 1), ws.Cells(n, 1)), _
                  ws.Range(ws.Cells(2, 3), ws.Cells(n, 3)), AZUL, xlMarkerStyleCircle, 6)
    Etiquetas s, "2003,2007,2011,2025", "0.0", "r", AZUL

    Base ch, False
    EjeX ch, "", 2000, 2025, AUTO, "0", False
    EjeY ch, Ac("Raz{o}n"), AUTO, AUTO, AUTO, "0.0", True
    Listo

End Sub

' Gráfico 17: Gini de los registros del SRI. Columnas: anio, gini_antes,
' gini_despues.
Private Sub Grafico17_GiniSRI()

    Dim ws As Worksheet, ch As Chart, s As Series, n As Long

    Dim cX As Long

    Set ws = HojaOAviso("gini_sri", "G17")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,gini_antes,gini_despues") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G17_gini_sri", 425, 238, 6)

    ' Las dos series van a 0,01 una de otra: las etiquetas de la primera van
    ' arriba y las de la segunda abajo para que no se encimen.
    Set s = SerieCol(ch, ws, cX, Columna(ws, "gini_antes"), n, "Antes de impuestos", AZUL)
    Etiquetas s, "PRIMERO,2016,2019,ULTIMO", "0.00", "t", AZUL
    Set s = SerieCol(ch, ws, cX, Columna(ws, "gini_despues"), n, Ac("Despu{e}s de impuestos"), VINO)
    Etiquetas s, "PRIMERO,2016,2019,ULTIMO", "0.00", "b", VINO

    Base ch, True
    EjeX ch, "", 2010, 2024, AUTO, "0", False
    EjeY ch, "Coeficiente de Gini", AUTO, AUTO, AUTO, "0.00", True
    Listo

End Sub

Private Sub Grafico06_GicUrbano()

    Dim ws As Worksheet, ch As Chart, n As Long
    Dim cols() As Long, nSer As Long
    Dim s As Series

    Set ws = HojaGIC("GIC_urbano", "gic_urbano")
    If ws Is Nothing Then
        mFaltan = mFaltan & " G06(gic_urbano)"
        Exit Sub
    End If
    n = UltimaFila(ws, 1)
    ColumnasGIC ws, "urb_1991_1998,urb_2001_2025", cols, nSer
    If nSer = 0 Then Exit Sub

    Set ch = Lienzo(ws, "G06_gic_urbano", 341, 230, 2)

    Set s = SerieGIC(ch, ws, n, cols(1), AZUL)
    Etiquetas s, "PRIMERO,ULTIMO", "0.0", "t", AZUL
    If nSer >= 2 Then
        Set s = SerieGIC(ch, ws, n, cols(2), VINO)
        Etiquetas s, "PRIMERO,ULTIMO", "0.0", "b", VINO
    End If

    Base ch, True
    EjeX ch, "Percentil de ingreso", 0, 100, 20, "0", False
    EjeY ch, "Crecimiento anualizado (%)", AUTO, AUTO, AUTO, "0.0", True
    Listo

End Sub

Private Sub Grafico07_GicNacional()

    Dim ws As Worksheet, ch As Chart, n As Long
    Dim cols() As Long, nSer As Long
    Dim s As Series

    Set ws = HojaGIC("GIC_nacional", "gic_nacional")
    If ws Is Nothing Then
        mFaltan = mFaltan & " G07(gic_nacional)"
        Exit Sub
    End If
    n = UltimaFila(ws, 1)
    ColumnasGIC ws, "nac_2001_2010,nac_2011_2025,nac_2001_2025", cols, nSer
    If nSer = 0 Then Exit Sub

    Set ch = Lienzo(ws, "G07_gic_nacional", 300, 206, 2)

    Set s = SerieGIC(ch, ws, n, cols(1), AZUL)
    Etiquetas s, "PRIMERO,ULTIMO", "0.0", "t", AZUL
    If nSer >= 2 Then
        Set s = SerieGIC(ch, ws, n, cols(2), VINO)
        Etiquetas s, "PRIMERO,ULTIMO", "0.0", "r", VINO
    End If
    If nSer >= 3 Then
        Set s = SerieGIC(ch, ws, n, cols(3), VERDE)
        Etiquetas s, "PRIMERO,ULTIMO", "0.0", "t", VERDE
    End If

    Base ch, True
    EjeX ch, "Percentil de ingreso", 0, 100, 20, "0", False
    EjeY ch, "Crecimiento anualizado (%)", AUTO, AUTO, AUTO, "0.0", True
    Listo

End Sub

Private Sub Grafico08_Composicion()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("decomp_nacional", "G08")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "t,slaboral,srentas,sremesas,sbono") Then Exit Sub

    cX = Columna(ws, "t")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G08_composicion", 298, 227, 20)

    Set s = SerieCol(ch, ws, cX, Columna(ws, "slaboral"), n, "Laboral", AZUL)
    Etiquetas s, "ULTIMO", "0.0", "t", AZUL
    Set s = SerieCol(ch, ws, cX, Columna(ws, "srentas"), n, "Rentas", VINO)
    Etiquetas s, "ULTIMO", "0.0", "r", VINO
    Set s = SerieCol(ch, ws, cX, Columna(ws, "sremesas"), n, "Remesas", VERDE)
    Etiquetas s, "ULTIMO", "0.0", "r", VERDE
    Set s = SerieCol(ch, ws, cX, Columna(ws, "sbono"), n, "Bono", NARANJA)
    Etiquetas s, "ULTIMO", "0.0", "r", NARANJA

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2000, 2025, AUTO, "0", False
    EjeY ch, Ac("Participaci{o}n en el ingreso (%)"), AUTO, AUTO, AUTO, "0", True
    Listo

End Sub

Private Sub Grafico09_RemesasCuartil()

    GraficoCuartiles "remesas_cuartil", "G09_remesas_cuartil", 300, 202, _
                     Ac("Participaci{o}n en el ingreso (%)"), "0.0", _
                     "PRIMERO,ULTIMO", "r", "", "", "", "", "PRIMERO,ULTIMO", "t"

End Sub

Private Sub Grafico10_BonoCuartil()

    GraficoCuartiles "bono_cuartil", "G10_bono_cuartil", 310, 227, _
                     Ac("Participaci{o}n en el ingreso (%)"), "0.0", _
                     "PRIMERO,2009,ULTIMO", "t", "PRIMERO,ULTIMO", "b", _
                     "ULTIMO", "r", "ULTIMO", "r"

End Sub

' Los dos gráficos por cuartil son el mismo dibujo con distinta hoja de
' origen y distintas etiquetas, así que comparten este armador. La hoja
' (remesas_cuartil o bono_cuartil) la escribe consolidar_excel.do con las
' columnas anio, cuartil_1 ... cuartil_4.
Private Sub GraficoCuartiles(nomHoja As String, nombre As String, _
                             ancho As Single, alto As Single, _
                             tituloY As String, fmtY As String, _
                             e1 As String, p1 As String, e2 As String, p2 As String, _
                             e3 As String, p3 As String, e4 As String, p4 As String)

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, q As Long, cX As Long
    Dim etq As String, pos As String
    Dim colores As Variant

    Set ws = HojaOAviso(nomHoja, nombre)
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,cuartil_1,cuartil_2,cuartil_3,cuartil_4") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)
    If n < 2 Then Exit Sub

    colores = Array(AZUL, VINO, VERDE, NARANJA)

    Set ch = Lienzo(ws, nombre, ancho, alto, 6)

    For q = 1 To 4
        Set s = SerieCol(ch, ws, cX, Columna(ws, "cuartil_" & q), n, _
                         "Cuartil " & q, CStr(colores(q - 1)))
        Select Case q
            Case 1: etq = e1: pos = p1
            Case 2: etq = e2: pos = p2
            Case 3: etq = e3: pos = p3
            Case 4: etq = e4: pos = p4
        End Select
        If etq <> "" Then Etiquetas s, etq, "0.0", pos, CStr(colores(q - 1))
    Next q

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2000, 2025, AUTO, "0", False
    EjeY ch, tituloY, AUTO, AUTO, AUTO, fmtY, True
    Listo

End Sub

Private Sub Grafico11_Elasticidad()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("decomp_nacional", "G11")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "t,elaboral,erentas,eremesas,ebono") Then Exit Sub

    cX = Columna(ws, "t")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G11_elasticidad", 372, 261, 36)

    ' Las elasticidades se etiquetan con cuatro decimales: son números
    ' chicos y con uno solo varias series quedaban en el mismo valor.
    Set s = SerieCol(ch, ws, cX, Columna(ws, "elaboral"), n, "Laboral", AZUL)
    Etiquetas s, "PRIMERO,2009,ULTIMO", "0.0000", "t", AZUL
    Set s = SerieCol(ch, ws, cX, Columna(ws, "erentas"), n, "Rentas", VINO)
    Etiquetas s, "ULTIMO", "0.0000", "r", VINO
    Set s = SerieCol(ch, ws, cX, Columna(ws, "eremesas"), n, "Remesas", VERDE)
    Etiquetas s, "ULTIMO", "0.0000", "r", VERDE
    Set s = SerieCol(ch, ws, cX, Columna(ws, "ebono"), n, "Bono", NARANJA)
    Etiquetas s, "PRIMERO,ULTIMO", "0.0000", "b", NARANJA

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2000, 2025, AUTO, "0", True
    EjeY ch, Ac("Elasticidad ingreso{-}Gini"), AUTO, AUTO, AUTO, "0.000", True
    Listo

End Sub

Private Sub Grafico12_Brechas()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long

    Set ws = HojaOAviso("brechas", "G12")
    If ws Is Nothing Then Exit Sub
    n = UltimaFila(ws, 1)

    Set ch = Lienzo(ws, "G12_brechas", 425, 238, 10)

    Set s = SerieCol(ch, ws, 1, 4, n, "Calificados", AZUL)
    Etiquetas s, "PRIMERO:t,2011:t,ULTIMO:t", "0.00", "t", AZUL
    Set s = SerieCol(ch, ws, 1, 5, n, "Publico", VINO)
    Etiquetas s, "PRIMERO:b,2011:r,ULTIMO:b", "0.00", "b", VINO
    Set s = SerieCol(ch, ws, 1, 6, n, "Sexo", VERDE)
    Etiquetas s, "PRIMERO:r,2011:b,ULTIMO:b", "0.00", "b", VERDE
    Set s = SerieCol(ch, ws, 1, 7, n, "Etnia", NARANJA)
    Etiquetas s, "PRIMERO:t,2011:r,ULTIMO:t", "0.00", "t", NARANJA

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2000, 2025, AUTO, "0", False
    EjeY ch, Ac("Raz{o}n de ingresos"), AUTO, AUTO, AUTO, "0.00", True
    Listo

End Sub

' Hoja prima_urbano (la escribe consolidar_excel.do con las filas urbanas de
' prima_ancho): anio, total, hombres, mujeres.
Private Sub Grafico13_Prima()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("prima_urbano", "G13")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,total,hombres,mujeres") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)
    If n < 2 Then Exit Sub

    Set ch = Lienzo(ws, "G13_prima_salarial", 425, 302, 7)

    Set s = Serie(ch, "Total", Rango(ws, cX, n), Rango(ws, Columna(ws, "total"), n), _
                  NEGRO, xlMarkerStyleCircle, 6)
    Etiquetas s, "1991:r,1999:r,2011:t,2025:t", "0.00", "r", NEGRO

    Serie ch, "Hombres", Rango(ws, cX, n), Rango(ws, Columna(ws, "hombres"), n), _
          AZUL, xlMarkerStyleTriangle, 6

    Serie ch, "Mujeres", Rango(ws, cX, n), Rango(ws, Columna(ws, "mujeres"), n), _
          VINO, xlMarkerStyleSquare, 6

    Base ch, True

    ' Éste es el único gráfico del paper que lleva título dentro del gráfico.
    ch.HasTitle = True
    ch.ChartTitle.Text = Ac("Prima salarial de la educaci{o}n superior. " _
                            & "Urbano, 1991{-}2025")
    ch.ChartTitle.Font.Name = FUENTE
    ch.ChartTitle.Font.Size = 10
    ch.ChartTitle.Font.Bold = False
    ch.ChartTitle.Font.Color = Col(GRIS_TITULO)

    EjeX ch, Ac("A{n}o"), 1990, 2025, AUTO, "0", False
    EjeY ch, "Coeficiente sobre ln(ingreso laboral)", 0, 1.4, 0.2, "0.0", True
    Listo

End Sub

' Hoja adecuado_urbano (la escribe consolidar_excel.do desde adecuado_simulado):
' anio, observado, simulado. Tasas sobre la PEA urbana; 1991-1999 es la
' muestra urbana por diseño de la ENEMDU de diciembre.
Private Sub Grafico14_EmpleoAdecuado()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("adecuado_urbano", "G14")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,observado,simulado") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)
    If n < 2 Then Exit Sub

    Set ch = Lienzo(ws, "G14_empleo_adecuado", 425, 238, 6)

    Set s = SerieCol(ch, ws, cX, Columna(ws, "observado"), n, "Observado", AZUL)
    s.MarkerSize = 5
    Etiquetas s, "1999:r,2013:t,ULTIMO:t", "0.0", "t", AZUL

    ' El paper no la trae; se agrega para ver el contrafactual al lado.
    Set s = SerieCol(ch, ws, cX, Columna(ws, "simulado"), n, _
                     "Simulado con el SBU de 2025", VINO)
    s.MarkerSize = 5
    Etiquetas s, "PRIMERO:b,ULTIMO:b", "0.0", "b", VINO

    Base ch, True
    EjeX ch, Ac("A{n}o"), 1990, 2025, AUTO, "0", False
    EjeY ch, "Porcentaje de la PEA (%)", AUTO, AUTO, AUTO, "0.0", True
    Listo

End Sub


' Gráfico 4: participación en el ingreso nacional antes de impuestos por grupo,
' registros del SRI. Hoja participacion_sri.
Private Sub Grafico04_ParticipacionSRI()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("participacion_sri", "G04")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,top01,top1,top10,clase_media,bottom50,bottom35") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G04_participacion_sri", 425, 260, 6)

    Set s = SerieCol(ch, ws, cX, Columna(ws, "top01"), n, Ac("0,1% m{a}s rico"), AZUL)
    Etiquetas s, "PRIMERO,2015,2020,ULTIMO", "0.0%", "b", AZUL
    Set s = SerieCol(ch, ws, cX, Columna(ws, "top1"), n, Ac("1% m{a}s rico"), VINO)
    Etiquetas s, "PRIMERO,2020", "0.0%", "r", VINO
    Set s = SerieCol(ch, ws, cX, Columna(ws, "top10"), n, Ac("10% m{a}s rico"), VERDE)
    Etiquetas s, "PRIMERO,2015,2020,ULTIMO", "0.0%", "b", VERDE
    Set s = SerieCol(ch, ws, cX, Columna(ws, "clase_media"), n, "Clase media (P50-P90)", NARANJA)
    Etiquetas s, "PRIMERO,2015,2020,ULTIMO", "0.0%", "t", NARANJA
    Set s = SerieCol(ch, ws, cX, Columna(ws, "bottom50"), n, Ac("50% m{a}s pobre"), GRIS_VERDE)
    Etiquetas s, "PRIMERO,2015,2020,ULTIMO", "0.0%", "t", GRIS_VERDE
    SerieCol ch, ws, cX, Columna(ws, "bottom35"), n, Ac("35% m{a}s pobre"), MORADO

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2009, 2024, AUTO, "0", False
    EjeY ch, Ac("Participaci{o}n en el ingreso nacional"), AUTO, AUTO, AUTO, "0%", True
    Listo

End Sub

' Gráfico 5: crecimiento anual del PIB (barras), su promedio en cada período
' (líneas negras) y el Gini urbano en el eje derecho. Hoja pib_gini.
Private Sub Grafico05_PibGini()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long, k As Long
    Dim proms As Variant

    Set ws = HojaOAviso("pib_gini", "G05")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,crecimiento,prom_1990_1999,prom_2000_2010,prom_2011_2017,prom_2018_2024,gini_urbano") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G05_pib_gini", 425, 260, 6)
    ch.ChartType = xlColumnClustered

    Set s = SerieBarra(ch, "Crecimiento PIB", Rango(ws, cX, n), Rango(ws, Columna(ws, "crecimiento"), n), VERDE_PIB)

    proms = Array("prom_1990_1999", "prom_2000_2010", "prom_2011_2017", "prom_2018_2024")
    For k = 0 To 3
        Set s = ch.SeriesCollection.NewSeries
        s.XValues = Rango(ws, cX, n)
        s.Values = Rango(ws, Columna(ws, CStr(proms(k))), n)
        s.Name = Ac("Promedio del per{i}odo")
        s.ChartType = xlLine
        s.MarkerStyle = xlMarkerStyleNone
        With s.Format.Line
            .Visible = msoTrue
            .ForeColor.RGB = Col(NEGRO)
            .Weight = 1.5
        End With
    Next k

    Set s = ch.SeriesCollection.NewSeries
    s.XValues = Rango(ws, cX, n)
    s.Values = Rango(ws, Columna(ws, "gini_urbano"), n)
    s.Name = "Gini urbano"
    s.ChartType = xlLine
    s.AxisGroup = xlSecondary
    s.MarkerStyle = xlMarkerStyleNone
    With s.Format.Line
        .Visible = msoTrue
        .ForeColor.RGB = Col(NARANJA)
        .Weight = 1.75
    End With

    Base ch, True
    ' Una sola entrada de leyenda para los cuatro promedios.
    On Error Resume Next
    ch.Legend.LegendEntries(5).Delete
    ch.Legend.LegendEntries(4).Delete
    ch.Legend.LegendEntries(3).Delete
    Err.Clear
    On Error GoTo 0

    EjeCat ch, ""
    EjeY ch, "", -0.1, 0.15, AUTO, "0%", True
    EjeY2 ch, "", 0.2, AUTO, AUTO, "0.00"
    Listo

End Sub

' Gráfico 15: salario básico real (barras, dólares de 2015) y Gini nacional
' en el eje derecho. Hoja salario_basico (cada dos años desde 2001: 2002 y
' 2004 no tienen Gini).
Private Sub Grafico15_SalarioBasico()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("salario_basico", "G15")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,salario_real,gini_nacional") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G15_salario_basico", 425, 260, 6)
    ch.ChartType = xlColumnClustered

    Set s = SerieBarra(ch, Ac("Salario b{a}sico real (d{o}lares de 2015)"), _
                       Rango(ws, cX, n), Rango(ws, Columna(ws, "salario_real"), n), AZUL)
    Etiquetas s, "PRIMERO,2015,ULTIMO", "$#,##0", "outend", AZUL

    Set s = ch.SeriesCollection.NewSeries
    s.XValues = Rango(ws, cX, n)
    s.Values = Rango(ws, Columna(ws, "gini_nacional"), n)
    s.Name = "Gini nacional"
    s.ChartType = xlLineMarkers
    s.AxisGroup = xlSecondary
    s.MarkerStyle = xlMarkerStyleCircle
    s.MarkerSize = 6
    s.MarkerBackgroundColor = Col(VINO)
    s.MarkerForegroundColor = Col(VINO)
    With s.Format.Line
        .Visible = msoTrue
        .ForeColor.RGB = Col(VINO)
        .Weight = 1.75
    End With

    Base ch, True
    EjeCat ch, Ac("A{n}o")
    EjeY ch, Ac("D{o}lares de 2015 por mes"), AUTO, AUTO, AUTO, "$#,##0", True
    EjeY2 ch, "Coeficiente de Gini", AUTO, AUTO, AUTO, "0.00"
    Listo

End Sub

' Gráfico 16: valor mensual del límite inferior del rango superior del impuesto
' a la renta (dólares de 2015) y tasa marginal máxima en el eje derecho. Hoja
' tributacion (sólo los años con cambios normativos).
Private Sub Grafico16_Tributacion()

    Dim ws As Worksheet, ch As Chart, s As Series
    Dim n As Long, cX As Long

    Set ws = HojaOAviso("tributacion", "G16")
    If ws Is Nothing Then Exit Sub
    If Not HayColumnas(ws, "anio,tasa,valor_mensual_2015") Then Exit Sub

    cX = Columna(ws, "anio")
    n = UltimaFila(ws, cX)

    Set ch = Lienzo(ws, "G16_tributacion", 425, 260, 6)

    SerieCol ch, ws, cX, Columna(ws, "valor_mensual_2015"), n, "Valor mensual del rango superior", AZUL
    Set s = Serie(ch, "Tasa sobre el rango superior", Rango(ws, cX, n), _
                  Rango(ws, Columna(ws, "tasa"), n), VINO, xlMarkerStyleSquare, 6)
    s.AxisGroup = xlSecondary
    s.Format.Line.DashStyle = msoLineDash

    Base ch, True
    EjeX ch, Ac("A{n}o"), 2000, 2026, AUTO, "0", False
    EjeY ch, Ac("D{o}lares de 2015 por mes"), AUTO, AUTO, AUTO, "$#,##0", True
    EjeY2 ch, Ac("Tasa marginal m{a}xima"), AUTO, AUTO, AUTO, "0%"
    Listo

End Sub

'==============================================================================
' AYUDANTES
'==============================================================================


' Serie de barras: se pinta el relleno, no la línea (Gráficos 5 y 15).
Private Function SerieBarra(ch As Chart, nombre As String, rx As Range, ry As Range, _
                            colorHex As String) As Series

    Dim s As Series

    Set s = ch.SeriesCollection.NewSeries
    s.Values = ry
    s.XValues = rx
    s.Name = nombre

    With s.Format.Fill
        .Visible = msoTrue
        .ForeColor.RGB = Col(colorHex)
        .Solid
    End With
    s.Format.Line.Visible = msoFalse

    Set SerieBarra = s

End Function

' Eje de categorías de los gráficos de barras: no tiene escala, sólo formato.
' Las etiquetas van abajo porque hay barras negativas (Gráfico 5).
Private Sub EjeCat(ch As Chart, titulo As String)

    With ch.Axes(xlCategory)

        .HasTitle = (titulo <> "")
        If titulo <> "" Then
            .AxisTitle.Text = titulo
            .AxisTitle.Font.Name = FUENTE
            .AxisTitle.Font.Size = 10
            .AxisTitle.Font.Bold = False
            .AxisTitle.Font.Color = Col(GRIS_TITULO)
        End If

        .HasMajorGridlines = False
        .HasMinorGridlines = False
        .MajorTickMark = xlTickMarkOutside
        .MinorTickMark = xlTickMarkNone
        .TickLabelPosition = xlTickLabelPositionLow
        .TickLabels.Font.Name = FUENTE
        .TickLabels.Font.Size = 9
        .TickLabels.Font.Color = Col(GRIS_TEXTO)

        .Format.Line.Visible = msoTrue
        .Format.Line.ForeColor.RGB = Col(GRIS_EJE_X)
        .Format.Line.Weight = 0.75

    End With

End Sub

' Eje vertical derecho (series con AxisGroup = xlSecondary), sin líneas de
' división para que no se crucen con las del eje izquierdo.
Private Sub EjeY2(ch As Chart, titulo As String, minimo As Double, maximo As Double, _
                  unidad As Double, fmt As String)

    With ch.Axes(xlValue, xlSecondary)

        .HasTitle = (titulo <> "")
        If titulo <> "" Then
            .AxisTitle.Text = titulo
            .AxisTitle.Font.Name = FUENTE
            .AxisTitle.Font.Size = 10
            .AxisTitle.Font.Bold = False
            .AxisTitle.Font.Color = Col(GRIS_TITULO)
        End If

        If minimo <> AUTO Then .MinimumScale = minimo Else .MinimumScaleIsAuto = True
        If maximo <> AUTO Then .MaximumScale = maximo Else .MaximumScaleIsAuto = True
        If unidad <> AUTO Then .MajorUnit = unidad Else .MajorUnitIsAuto = True

        .HasMajorGridlines = False
        .HasMinorGridlines = False
        .MajorTickMark = xlTickMarkOutside
        .MinorTickMark = xlTickMarkNone
        .TickLabels.NumberFormatLocal = FormatoLocal(fmt)
        .TickLabels.Font.Name = FUENTE
        .TickLabels.Font.Size = 9
        .TickLabels.Font.Color = Col(GRIS_TEXTO)

        .Format.Line.Visible = msoTrue
        .Format.Line.ForeColor.RGB = Col(GRIS_EJE_Y)
        .Format.Line.Weight = 0.75

    End With

End Sub

Private Sub Listo()
    mHechos = mHechos + 1
End Sub

' Verifica que existan todas las columnas de la lista.
Private Function HayColumnas(ws As Worksheet, lista As String) As Boolean

    Dim it() As String
    Dim i As Long

    it = Split(lista, ",")
    For i = 0 To UBound(it)
        If Columna(ws, Trim$(it(i))) = 0 Then
            mFaltan = mFaltan & " " & ws.Name & ":" & Trim$(it(i))
            Exit Function
        End If
    Next i

    HayColumnas = True

End Function

Private Function Hoja(nombre As String) As Worksheet

    Dim ws As Worksheet

    For Each ws In mLibro.Worksheets
        If StrComp(ws.Name, nombre, vbTextCompare) = 0 Then
            Set Hoja = ws
            Exit Function
        End If
    Next ws

End Function

Private Function HojaOAviso(nombre As String, etiqueta As String) As Worksheet

    Set HojaOAviso = Hoja(nombre)
    If HojaOAviso Is Nothing Then mFaltan = mFaltan & " " & etiqueta & "(" & nombre & ")"

End Function

Private Function HojaGIC(n1 As String, n2 As String) As Worksheet

    Set HojaGIC = Hoja(n1)
    If HojaGIC Is Nothing Then Set HojaGIC = Hoja(n2)

End Function

Private Function UltimaFila(ws As Worksheet, laCol As Long) As Long

    If laCol < 1 Then laCol = 1
    UltimaFila = ws.Cells(ws.Rows.Count, laCol).End(xlUp).Row

End Function

' Número de la columna cuyo encabezado (fila 1) es `titulo`.
Private Function Columna(ws As Worksheet, titulo As String) As Long

    Dim c As Long, ultCol As Long

    ultCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    For c = 1 To ultCol
        If StrComp(CStr(ws.Cells(1, c).Value), titulo, vbTextCompare) = 0 Then
            Columna = c
            Exit Function
        End If
    Next c

End Function

' Columnas g_* de una hoja del GIC, en el orden pedido.
Private Sub ColumnasGIC(ws As Worksheet, orden As String, ByRef cols() As Long, ByRef nSer As Long)

    Dim pedidas() As String
    Dim i As Long, c As Long, ultCol As Long

    ultCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    ReDim cols(1 To ultCol)
    nSer = 0
    pedidas = Split(orden, ",")

    For i = 0 To UBound(pedidas)
        For c = 2 To ultCol
            If StrComp(CStr(ws.Cells(1, c).Value), "g_" & Trim$(pedidas(i)), vbTextCompare) = 0 Then
                nSer = nSer + 1
                cols(nSer) = c
                Exit For
            End If
        Next c
    Next i

End Sub

Private Function SerieGIC(ch As Chart, ws As Worksheet, n As Long, laCol As Long, colorHex As String) As Series

    Set SerieGIC = Serie(ch, EtiquetaSerieGIC(CStr(ws.Cells(1, laCol).Value)), _
                         ws.Range(ws.Cells(2, 1), ws.Cells(n, 1)), _
                         ws.Range(ws.Cells(2, laCol), ws.Cells(n, laCol)), _
                         colorHex, xlMarkerStyleCircle, 7)

End Function

' g_urb_1991_1998 -> "1991–1998"
Private Function EtiquetaSerieGIC(encabezado As String) As String

    Dim p() As String
    Dim n As Long

    p = Split(encabezado, "_")
    n = UBound(p)
    If n >= 2 Then
        If IsNumeric(p(n)) And IsNumeric(p(n - 1)) Then
            EtiquetaSerieGIC = p(n - 1) & ChrW$(8211) & p(n)
            Exit Function
        End If
    End If
    EtiquetaSerieGIC = encabezado

End Function

Private Function SerieCol(ch As Chart, ws As Worksheet, colX As Long, colY As Long, _
                          n As Long, nombre As String, colorHex As String) As Series

    Set SerieCol = Serie(ch, nombre, _
                         ws.Range(ws.Cells(2, colX), ws.Cells(n, colX)), _
                         ws.Range(ws.Cells(2, colY), ws.Cells(n, colY)), _
                         colorHex, xlMarkerStyleCircle, 6)

End Function

' Columna `laCol` de la fila 2 a la `n`: el rango de una serie.
Private Function Rango(ws As Worksheet, laCol As Long, n As Long) As Range

    Set Rango = ws.Range(ws.Cells(2, laCol), ws.Cells(n, laCol))

End Function

' Crea el marco del gráfico. `filaAncla` es la fila donde se pega, para que no
' tape los datos. Si ya existía uno con el mismo nombre, lo borra.
Private Function Lienzo(ws As Worksheet, nombre As String, ancho As Single, _
                        alto As Single, filaAncla As Long) As Chart

    Dim co As ChartObject
    Dim ultCol As Long
    Dim izq As Single, arr As Single

    For Each co In ws.ChartObjects
        If StrComp(co.Name, nombre, vbTextCompare) = 0 Then co.Delete
    Next co

    ultCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    izq = ws.Cells(1, ultCol + 2).Left
    arr = ws.Cells(filaAncla, 1).Top

    Set co = ws.ChartObjects.Add(Left:=izq, Top:=arr, Width:=ancho, Height:=alto)
    co.Name = nombre

    Set Lienzo = co.Chart

    ' La fuente de todo el gráfico se pone aquí, al crearlo, y no al final:
    ' tocar ChartArea.Font reaplica la fuente a TODO el texto y de paso
    ' devuelve su color al automático. Si esto corriera después de las
    ' etiquetas, les borraría el color de la serie.
    Lienzo.ChartArea.Font.Name = FUENTE
    Lienzo.ChartArea.Font.Size = 9
    If Lienzo.HasTitle Then Lienzo.ChartTitle.Delete
    Lienzo.HasTitle = False

    Lienzo.ChartType = xlXYScatterLines
    Do While Lienzo.SeriesCollection.Count > 0
        Lienzo.SeriesCollection(1).Delete
    Loop

End Function

Private Function Serie(ch As Chart, nombre As String, rx As Range, ry As Range, _
                       colorHex As String, marcador As Long, tam As Long) As Series

    Dim s As Series

    Set s = ch.SeriesCollection.NewSeries
    s.XValues = rx
    s.Values = ry
    s.Name = nombre

    With s.Format.Line
        .Visible = msoTrue
        .ForeColor.RGB = Col(colorHex)
        .Weight = 1.75
    End With

    s.MarkerStyle = marcador
    s.MarkerSize = tam
    s.MarkerBackgroundColor = Col(colorHex)
    s.MarkerForegroundColor = Col(colorHex)
    s.Smooth = False

    Set Serie = s

End Function

' Etiquetas de valor sobre puntos elegidos, como en el paper. `lista` acepta
'   - un valor del eje X:      "2011"
'   - PRIMERO / ULTIMO:        primer o último punto con dato
'   - cualquiera de los dos con su posición: "2011:r"
' Si el punto no existe en los datos, esa etiqueta simplemente no se pone.
'
' El formato se da a nivel de SERIE y recién después se apagan los puntos que
' no llevan etiqueta. Parece un rodeo, pero es lo único que funciona: sobre un
' punto suelto (s.Points(i).DataLabel) Excel acepta tamaño, fuente, posición y
' formato de número, pero ignora el color y lo deja en automático — en el
' archivo queda <a:sysClr val="windowText"/>. Sobre la colección de la serie
' (s.DataLabels) sí lo toma, que es por lo que los gráficos de barras siempre
' salieron con el color correcto.
Private Sub Etiquetas(s As Series, lista As String, fmt As String, _
                      posDefecto As String, colorHex As String)

    Dim xs As Variant, ys As Variant
    Dim it() As String
    Dim quiere() As Boolean
    Dim posDe() As String
    Dim i As Long, k As Long, n As Long, idx As Long
    Dim pieza As String, valor As String, pos As String

    On Error Resume Next

    xs = s.XValues
    ys = s.Values
    n = UBound(xs)
    If n < 1 Then Exit Sub

    ReDim quiere(1 To n)
    ReDim posDe(1 To n)

    '--- qué puntos llevan etiqueta y en qué posición ---
    it = Split(lista, ",")

    For k = 0 To UBound(it)

        pieza = Trim$(it(k))
        pos = posDefecto
        If InStr(pieza, ":") > 0 Then
            valor = Trim$(Left$(pieza, InStr(pieza, ":") - 1))
            pos = Trim$(Mid$(pieza, InStr(pieza, ":") + 1))
        Else
            valor = pieza
        End If

        idx = 0
        If StrComp(valor, "PRIMERO", vbTextCompare) = 0 Then
            For i = 1 To n
                If ConDato(ys, i) Then
                    idx = i
                    Exit For
                End If
            Next i
        ElseIf StrComp(valor, "ULTIMO", vbTextCompare) = 0 Then
            For i = n To 1 Step -1
                If ConDato(ys, i) Then
                    idx = i
                    Exit For
                End If
            Next i
        Else
            For i = 1 To n
                If CStr(xs(i)) = valor And ConDato(ys, i) Then
                    idx = i
                    Exit For
                End If
            Next i
        End If

        If idx > 0 Then
            quiere(idx) = True
            posDe(idx) = pos
        End If

    Next k

    '--- formato para toda la serie, que es donde el color sí se pega ---
    s.HasDataLabels = True
    With s.DataLabels
        .ShowValue = True
        .ShowSeriesName = False
        .ShowCategoryName = False
        .NumberFormatLocal = FormatoLocal(fmt)
        .Position = PosEtiqueta(posDefecto)
        .Font.Name = FUENTE
        .Font.Size = 8
        .Font.Bold = False
    End With

    PintarTexto s.DataLabels, colorHex

    '--- y ahora se apagan las que no van ---
    For i = 1 To n
        Err.Clear
        If quiere(i) Then
            If posDe(i) <> posDefecto Then _
                s.Points(i).DataLabel.Position = PosEtiqueta(posDe(i))
        Else
            s.Points(i).HasDataLabel = False
        End If
    Next i

    Err.Clear
    On Error GoTo 0

End Sub

Private Function ConDato(ys As Variant, i As Long) As Boolean

    On Error Resume Next
    ConDato = False
    If Not IsEmpty(ys(i)) Then
        If IsNumeric(ys(i)) Then ConDato = True
    End If
    On Error GoTo 0

End Function

' Color del texto de una etiqueta (o de la colección de etiquetas de una
' serie). Excel lo expone por dos caminos y cuál funciona depende de la
' versión: Font.Color (el clásico) y el relleno del TextFrame2 (el de las
' versiones nuevas). Se escriben los dos y después se lee de vuelta.
'
' NO se toca Font.ColorIndex: apuntar a un índice de la paleta del libro
' devolvía el color a "automático" (en el archivo, sysClr windowText) y con
' eso borraba lo que acababa de escribir Font.Color.
Private Sub PintarTexto(etiqueta As Object, colorHex As String)

    Dim c As Long
    Dim notas As String
    Dim leido As Long

    If colorHex = "" Then Exit Sub
    c = Col(colorHex)

    On Error Resume Next

    Err.Clear
    etiqueta.Font.Color = c
    If Err.Number <> 0 Then notas = notas & " Font!" & Err.Number

    Err.Clear
    With etiqueta.Format.TextFrame2.TextRange.Font.Fill
        .Visible = msoTrue
        .Solid
        .ForeColor.RGB = c
        .Transparency = 0
    End With
    If Err.Number <> 0 Then notas = notas & " TextFrame2!" & Err.Number

    ' Lectura de vuelta: si el color guardado no es el que se pidió, la
    ' escritura no sirvió aunque no haya dado error.
    Err.Clear
    leido = etiqueta.Font.Color
    If Err.Number = 0 Then
        If leido <> c Then notas = notas & " Font=" & Hex(leido) & "<>" & Hex(c)
    Else
        notas = notas & " Font?" & Err.Number
    End If

    Err.Clear
    On Error GoTo 0

    ' Se anota una sola vez cada combinación, para no repetir la misma línea
    ' por cada etiqueta.
    If notas <> "" Then
        If InStr(mColorFallas, notas) = 0 Then _
            mColorFallas = mColorFallas & vbLf & "  " & notas
    End If

End Sub

Private Function PosEtiqueta(pos As String) As Long

    Select Case LCase$(pos)
        Case "t": PosEtiqueta = xlLabelPositionAbove
        Case "b": PosEtiqueta = xlLabelPositionBelow
        Case "l": PosEtiqueta = xlLabelPositionLeft
        Case "outend": PosEtiqueta = xlLabelPositionOutsideEnd
        Case Else: PosEtiqueta = xlLabelPositionRight
    End Select

End Function

' Fondo, tipografía y leyenda: igual en todos los gráficos del paper.
Private Sub Base(ch As Chart, conLeyenda As Boolean)

    ch.DisplayBlanksAs = xlNotPlotted

    With ch.ChartArea.Format.Fill
        .Visible = msoTrue
        .ForeColor.RGB = RGB(255, 255, 255)
    End With
    ch.ChartArea.Format.Line.Visible = msoFalse

    ch.PlotArea.Format.Fill.Visible = msoFalse
    ch.PlotArea.Format.Line.Visible = msoFalse

    ch.HasLegend = conLeyenda
    If conLeyenda Then
        With ch.Legend
            .Position = xlLegendPositionBottom
            .Font.Name = FUENTE
            .Font.Size = 9
            .Font.Color = Col(GRIS_TEXTO)
        End With
    End If

    ' Al final, porque Excel vuelve a poner el título automático (el nombre de
    ' la serie) cuando se toca la leyenda. HasTitle = False no basta: en el
    ' archivo quedaba autoTitleDeleted = 0 y el título seguía ahí. Hay que
    ' borrar el objeto.
    If ch.HasTitle Then ch.ChartTitle.Delete
    ch.HasTitle = False

End Sub

' minimo/maximo/unidad en AUTO = que Excel elija la escala.
Private Sub EjeX(ch As Chart, titulo As String, minimo As Double, maximo As Double, _
                 unidad As Double, fmt As String, etiquetasAbajo As Boolean)

    With ch.Axes(xlCategory)

        .HasTitle = (titulo <> "")
        If titulo <> "" Then
            .AxisTitle.Text = titulo
            .AxisTitle.Font.Name = FUENTE
            .AxisTitle.Font.Size = 10
            .AxisTitle.Font.Bold = False
            .AxisTitle.Font.Color = Col(GRIS_TITULO)
        End If

        If minimo <> AUTO Then .MinimumScale = minimo Else .MinimumScaleIsAuto = True
        If maximo <> AUTO Then .MaximumScale = maximo Else .MaximumScaleIsAuto = True
        If unidad <> AUTO Then .MajorUnit = unidad Else .MajorUnitIsAuto = True

        .HasMajorGridlines = False
        .HasMinorGridlines = False
        .MajorTickMark = xlTickMarkOutside
        .MinorTickMark = xlTickMarkNone
        If etiquetasAbajo Then .TickLabelPosition = xlTickLabelPositionLow _
                          Else .TickLabelPosition = xlTickLabelPositionNextToAxis

        .TickLabels.NumberFormatLocal = FormatoLocal(fmt)
        .TickLabels.Font.Name = FUENTE
        .TickLabels.Font.Size = 9
        .TickLabels.Font.Color = Col(GRIS_TEXTO)

        .Format.Line.Visible = msoTrue
        .Format.Line.ForeColor.RGB = Col(GRIS_EJE_X)
        .Format.Line.Weight = 0.75

    End With

End Sub

Private Sub EjeY(ch As Chart, titulo As String, minimo As Double, maximo As Double, _
                 unidad As Double, fmt As String, conLineas As Boolean)

    With ch.Axes(xlValue)

        .HasTitle = (titulo <> "")
        If titulo <> "" Then
            .AxisTitle.Text = titulo
            .AxisTitle.Font.Name = FUENTE
            .AxisTitle.Font.Size = 10
            .AxisTitle.Font.Bold = False
            .AxisTitle.Font.Color = Col(GRIS_TITULO)
        End If

        If minimo <> AUTO Then .MinimumScale = minimo Else .MinimumScaleIsAuto = True
        If maximo <> AUTO Then .MaximumScale = maximo Else .MaximumScaleIsAuto = True
        If unidad <> AUTO Then .MajorUnit = unidad Else .MajorUnitIsAuto = True

        .HasMajorGridlines = conLineas
        If conLineas Then
            .MajorGridlines.Format.Line.Visible = msoTrue
            .MajorGridlines.Format.Line.ForeColor.RGB = Col(GRIS_EJE_Y)
            .MajorGridlines.Format.Line.Weight = 0.75
        End If
        .HasMinorGridlines = False

        .MajorTickMark = xlTickMarkOutside
        .MinorTickMark = xlTickMarkNone
        .TickLabels.NumberFormatLocal = FormatoLocal(fmt)
        .TickLabels.Font.Name = FUENTE
        .TickLabels.Font.Size = 9
        .TickLabels.Font.Color = Col(GRIS_TEXTO)

        .Format.Line.Visible = msoTrue
        .Format.Line.ForeColor.RGB = Col(GRIS_EJE_Y)
        .Format.Line.Weight = 0.75

    End With

End Sub

' Los códigos de formato de número se escriben aquí con punto decimal, pero
' Excel los lee según el idioma de la aplicación: en un Excel en español
' "0.00" se interpreta con el punto como separador de miles y un 0,5 termina
' impreso como "000". Por eso el código se traduce al separador que declare la
' aplicación y se asigna a NumberFormatLocal, que es la propiedad que va en el
' idioma de Excel.
' Los textos visibles se escriben en ASCII con marcas entre llaves y se
' traducen aquí. Así el módulo se puede importar o pegar sin que dependa de la
' codificación con que el editor lea el archivo: en el editor de VBA de Mac los
' acentos de un archivo UTF-8 llegan convertidos en basura ("gr√°fico").
'   {a} {e} {i} {o} {u} = vocales con tilde     {n} = eñe
'   {A} = A con tilde   {N} = eñe mayúscula     {-} = guion largo
Private Function Ac(txt As String) As String

    Dim t As String

    t = txt
    t = Replace(t, "{a}", ChrW$(225))
    t = Replace(t, "{e}", ChrW$(233))
    t = Replace(t, "{i}", ChrW$(237))
    t = Replace(t, "{o}", ChrW$(243))
    t = Replace(t, "{u}", ChrW$(250))
    t = Replace(t, "{n}", ChrW$(241))
    t = Replace(t, "{A}", ChrW$(193))
    t = Replace(t, "{N}", ChrW$(209))
    t = Replace(t, "{-}", ChrW$(8211))

    Ac = t

End Function

Private Function FormatoLocal(codigo As String) As String

    FormatoLocal = Replace(codigo, ".", Application.International(xlDecimalSeparator))

End Function

' "1A476F" -> el Long que espera VBA.
Private Function Col(hex6 As String) As Long

    Col = RGB(CLng("&H" & Mid$(hex6, 1, 2)), _
              CLng("&H" & Mid$(hex6, 3, 2)), _
              CLng("&H" & Mid$(hex6, 5, 2)))

End Function

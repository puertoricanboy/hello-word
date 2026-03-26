Attribute VB_Name = "ModuloPingRefreshV2"
Option Explicit

' ================== REFRESH V2 ==================
' Cambios principales:
' - Limpieza robusta de columnas de salida en Data (G:I)
' - Sin pop-up con lista de equipos; el dato clave queda en Data!H
' - Data!H = días consecutivos Offline por equipo
' - Menos congelamiento: se elimina ping extra de latencia y se fuerza DoEvents por fila
' - Historial dinámico por clave de equipo (Nombre o IP)

Public Sub RefreshV2()
    Dim wb As Workbook
    Dim wsData As Worksheet
    Dim wsConfig As Worksheet
    Dim wsResumen As Worksheet

    Dim objShell As Object
    Dim i As Long, lastRowData As Long
    Dim host As String
    Dim estado As String, motivo As String

    Dim totalOnline As Long, totalOffline As Long, totalSaltados As Long
    Dim tStart As Single, tEnd As Single, tSecs As Single
    Dim alertaCantidad As Long

    ' Configuración
    Dim cfgStartRow As Long, cfgThreshold As Long
    Dim cfgTimeoutFast As Long, cfgTimeoutRetry As Long, cfgRetryCount As Long
    Dim cfgSkipMarker As String

    ' Estado previo de Excel para restaurar al final
    Dim prevScreenUpdating As Boolean
    Dim prevEnableEvents As Boolean
    Dim prevCalc As XlCalculation

    On Error GoTo ErrHandler

    Set wb = ThisWorkbook
    Set wsData = wb.Worksheets("Data")
    Set wsConfig = GetOrCreateConfigSheet(wb)
    Set wsResumen = GetOrCreateSummarySheet(wb)

    LoadConfig wsConfig, cfgStartRow, cfgThreshold, cfgTimeoutFast, cfgTimeoutRetry, cfgRetryCount, cfgSkipMarker
    EnsureDataHeaders wsData

    ' Fijo por requerimiento: terminar ping en fila 1399
    lastRowData = 1399
    If cfgStartRow > lastRowData Then
        MsgBox "DataStartRow no puede ser mayor que 1399.", vbExclamation + vbOKOnly, "Refresh V2"
        Exit Sub
    End If

    ' Limpiar todos los resultados en columna G
    wsData.Range("G" & cfgStartRow & ":G" & lastRowData).ClearContents

    prevScreenUpdating = Application.ScreenUpdating
    prevEnableEvents = Application.EnableEvents
    prevCalc = Application.Calculation

    ' Mantener la UI visible para reducir sensación de congelamiento
    Application.ScreenUpdating = True
    Application.EnableEvents = False
    Application.Calculation = xlCalculationManual
    Application.StatusBar = "RefreshV2 iniciando..."

    tStart = Timer
    Set objShell = CreateObject("WScript.Shell")

    For i = cfgStartRow To lastRowData
        Application.StatusBar = "RefreshV2: " & i & "/" & lastRowData
        DoEvents

        host = Trim$(CStr(wsData.Cells(i, 6).Value2))

        If Len(host) = 0 Or UCase$(host) = UCase$(cfgSkipMarker) Then
            totalSaltados = totalSaltados + 1
            GoTo ContinueNext
        End If

        ProbeHost objShell, host, cfgTimeoutFast, cfgTimeoutRetry, cfgRetryCount, estado, motivo

        ' Estado (col G)
        wsData.Cells(i, 7).Value = estado
        If UCase$(estado) = "ONLINE" Then
            wsData.Cells(i, 7).Font.Color = vbBlue
            totalOnline = totalOnline + 1
        ElseIf UCase$(estado) = "OFFLINE" Then
            wsData.Cells(i, 7).Font.Color = vbRed
            totalOffline = totalOffline + 1
        Else
            wsData.Cells(i, 7).Font.Color = vbBlack
        End If

        ' Motivo (col I)
        wsData.Cells(i, 9).Value = motivo

ContinueNext:
    Next i

    ' Sincroniza historial y llena Data!H con días offline consecutivos
    UpdateHistoryV2 wb, wsData, cfgStartRow, lastRowData, cfgThreshold, alertaCantidad

    WriteDailySummary wsResumen, totalOnline, totalOffline, totalSaltados, alertaCantidad

    tEnd = Timer
    If tEnd < tStart Then
        tSecs = (86400! - tStart) + tEnd
    Else
        tSecs = tEnd - tStart
    End If

    Dim msg As String
    msg = "Resumen del ping (V2):" & vbCrLf & _
          "• Online:   " & totalOnline & vbCrLf & _
          "• Offline:  " & totalOffline & vbCrLf & _
          "• Saltados: " & totalSaltados & vbCrLf & _
          "• Duración: " & Format(tSecs, "0.0") & " segundos" & vbCrLf & vbCrLf & _
          "Revisa Data!H (DíasOffline) para ver cuánto lleva cada equipo sin comunicar." & vbCrLf & _
          "Equipos con " & cfgThreshold & "+ días Offline: " & alertaCantidad

    MsgBox msg, vbInformation + vbOKOnly, "Resultados"

SafeExit:
    On Error Resume Next
    Application.StatusBar = False
    Application.ScreenUpdating = prevScreenUpdating
    Application.EnableEvents = prevEnableEvents
    Application.Calculation = prevCalc

    Set objShell = Nothing
    Set wsResumen = Nothing
    Set wsConfig = Nothing
    Set wsData = Nothing
    Set wb = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en RefreshV2: " & Err.Number & " - " & Err.Description, vbCritical + vbOKOnly, "Refresh V2"
    Resume SafeExit
End Sub

Private Sub ProbeHost(ByVal objShell As Object, ByVal host As String, _
                      ByVal timeoutFast As Long, ByVal timeoutRetry As Long, ByVal retryCount As Long, _
                      ByRef outStatus As String, ByRef outReason As String)
    Dim cmd As String
    Dim rc As Long

    cmd = "cmd /c ping -n 1 -w " & timeoutFast & " " & QuoteArg(host)
    rc = objShell.Run(cmd, 0, True)

    If rc = 0 Then
        outStatus = "Online"
        outReason = "OK (primer intento)"
        Exit Sub
    End If

    cmd = "cmd /c ping -n " & retryCount & " -w " & timeoutRetry & " " & QuoteArg(host)
    rc = objShell.Run(cmd, 0, True)

    If rc = 0 Then
        outStatus = "Online"
        outReason = "OK (reintento)"
    Else
        outStatus = "Offline"
        outReason = MapPingReason(rc)
    End If
End Sub

Private Function MapPingReason(ByVal rc As Long) As String
    Select Case rc
        Case 11010
            MapPingReason = "Host unreachable"
        Case 11003
            MapPingReason = "Destination net unreachable"
        Case 11001
            MapPingReason = "Buffer too small"
        Case Else
            MapPingReason = "Timeout/error (code " & rc & ")"
    End Select
End Function

Private Function QuoteArg(ByVal s As String) As String
    QuoteArg = Chr$(34) & Replace(s, Chr$(34), "") & Chr$(34)
End Function

Private Sub EnsureDataHeaders(ByVal wsData As Worksheet)
    If Len(Trim$(wsData.Cells(1, 7).Value2)) = 0 Then wsData.Cells(1, 7).Value = "Estado"
    If Len(Trim$(wsData.Cells(1, 8).Value2)) = 0 Then wsData.Cells(1, 8).Value = "DiasOffline"
    If Len(Trim$(wsData.Cells(1, 9).Value2)) = 0 Then wsData.Cells(1, 9).Value = "Motivo"
End Sub

Private Sub UpdateHistoryV2(ByVal wb As Workbook, ByVal wsData As Worksheet, _
                            ByVal startRow As Long, ByVal lastRowData As Long, ByVal offlineStreakDays As Long, _
                            ByRef alertaCantidad As Long)
    Dim sh As Worksheet
    Dim todayCol As Long
    Dim dict As Object
    Dim histLastRow As Long

    Dim r As Long, targetRow As Long
    Dim nameVal As String, ipVal As String, keyVal As String, stateVal As String
    Dim streak As Long

    alertaCantidad = 0

    Set sh = GetOrCreateHistorySheet(wb)
    todayCol = GetOrCreateDateColumn(sh, Date)

    Set dict = CreateObject("Scripting.Dictionary")
    dict.CompareMode = vbTextCompare

    histLastRow = sh.Cells(sh.Rows.Count, 1).End(xlUp).Row
    If histLastRow < 2 Then histLastRow = 1

    For r = 2 To histLastRow
        keyVal = Trim$(CStr(sh.Cells(r, 1).Value2))
        If Len(keyVal) > 0 Then
            If Not dict.Exists(keyVal) Then dict.Add keyVal, r
        End If
    Next r

    For r = startRow To lastRowData
        nameVal = Trim$(CStr(wsData.Cells(r, 1).Value2))
        ipVal = Trim$(CStr(wsData.Cells(r, 6).Value2))

        keyVal = nameVal
        If Len(keyVal) = 0 Then keyVal = ipVal

        If Len(keyVal) = 0 Then
            wsData.Cells(r, 8).ClearContents
            GoTo ContinueNextRow
        End If

        If dict.Exists(keyVal) Then
            targetRow = CLng(dict(keyVal))
        Else
            histLastRow = histLastRow + 1
            targetRow = histLastRow
            sh.Cells(targetRow, 1).Value = keyVal
            dict.Add keyVal, targetRow
        End If

        stateVal = Trim$(CStr(wsData.Cells(r, 7).Value2))
        If Len(stateVal) > 0 Then
            sh.Cells(targetRow, todayCol).Value = stateVal
            sh.Cells(targetRow, todayCol).HorizontalAlignment = xlCenter
        Else
            sh.Cells(targetRow, todayCol).ClearContents
        End If

        streak = GetOfflineStreak(sh, targetRow, todayCol)
        wsData.Cells(r, 8).Value = streak
        wsData.Cells(r, 8).HorizontalAlignment = xlCenter

        ApplyOfflineHighlight sh, targetRow, todayCol, streak, offlineStreakDays
        If streak >= offlineStreakDays Then alertaCantidad = alertaCantidad + 1

ContinueNextRow:
        DoEvents
    Next r

    With sh.Rows(1)
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
End Sub

Private Function GetOfflineStreak(ByVal sh As Worksheet, ByVal rowNum As Long, ByVal todayCol As Long) As Long
    Dim c As Long
    Dim streak As Long

    streak = 0
    For c = todayCol To 2 Step -1
        If UCase$(Trim$(CStr(sh.Cells(rowNum, c).Value2))) = "OFFLINE" Then
            streak = streak + 1
        Else
            Exit For
        End If
    Next c

    GetOfflineStreak = streak
End Function

Private Sub ApplyOfflineHighlight(ByVal sh As Worksheet, ByVal rowNum As Long, ByVal todayCol As Long, _
                                  ByVal streak As Long, ByVal thresholdDays As Long)
    With sh.Cells(rowNum, todayCol)
        If streak >= thresholdDays Then
            .Interior.Color = RGB(255, 199, 206)
            .Font.Color = RGB(156, 0, 6)
            .Font.Bold = True
        Else
            .Interior.Pattern = xlNone
            .Font.Color = vbBlack
            .Font.Bold = False
        End If
    End With
End Sub

Private Function GetOrCreateHistorySheet(ByVal wb As Workbook) As Worksheet
    On Error Resume Next
    Set GetOrCreateHistorySheet = wb.Worksheets("Historial")
    On Error GoTo 0

    If GetOrCreateHistorySheet Is Nothing Then
        Set GetOrCreateHistorySheet = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
        GetOrCreateHistorySheet.Name = "Historial"
        GetOrCreateHistorySheet.Cells(1, 1).Value = "Equipo"
        GetOrCreateHistorySheet.Columns(1).ColumnWidth = 35
    End If
End Function

Private Function GetOrCreateDateColumn(ByVal sh As Worksheet, ByVal d As Date) As Long
    Dim lastCol As Long, c As Long, dInt As Date
    dInt = DateSerial(Year(d), Month(d), Day(d))

    If Len(Trim$(sh.Cells(1, 1).Value2)) = 0 Then sh.Cells(1, 1).Value = "Equipo"

    lastCol = sh.Cells(1, sh.Columns.Count).End(xlToLeft).Column
    If lastCol < 1 Then lastCol = 1

    For c = 2 To lastCol
        If IsDate(sh.Cells(1, c).Value) Then
            If Int(CDate(sh.Cells(1, c).Value)) = dInt Then
                GetOrCreateDateColumn = c
                Exit Function
            End If
        End If
    Next c

    GetOrCreateDateColumn = lastCol + 1
    sh.Cells(1, GetOrCreateDateColumn).Value = dInt
    sh.Cells(1, GetOrCreateDateColumn).NumberFormat = "yyyy-mm-dd"
    sh.Cells(1, GetOrCreateDateColumn).HorizontalAlignment = xlCenter
End Function

Private Function GetOrCreateConfigSheet(ByVal wb As Workbook) As Worksheet
    On Error Resume Next
    Set GetOrCreateConfigSheet = wb.Worksheets("Config")
    On Error GoTo 0

    If GetOrCreateConfigSheet Is Nothing Then
        Set GetOrCreateConfigSheet = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
        GetOrCreateConfigSheet.Name = "Config"

        With GetOrCreateConfigSheet
            .Range("A1:B1").Value = Array("Parametro", "Valor")
            .Range("A2:B8").ClearContents
            .Range("A2").Value = "DataStartRow"
            .Range("B2").Value = 2
            .Range("A3").Value = "OfflineThresholdDays"
            .Range("B3").Value = 5
            .Range("A4").Value = "PingTimeoutFastMs"
            .Range("B4").Value = 1000
            .Range("A5").Value = "PingTimeoutRetryMs"
            .Range("B5").Value = 700
            .Range("A6").Value = "PingRetryCount"
            .Range("B6").Value = 3
            .Range("A7").Value = "SkipMarker"
            .Range("B7").Value = "X"
            .Range("A8").Value = "Notas"
            .Range("B8").Value = "Editar solo columna B"
            .Columns("A:B").AutoFit
        End With
    End If
End Function

Private Sub LoadConfig(ByVal sh As Worksheet, _
                       ByRef dataStartRow As Long, ByRef offlineThreshold As Long, _
                       ByRef timeoutFast As Long, ByRef timeoutRetry As Long, ByRef retryCount As Long, _
                       ByRef skipMarker As String)
    dataStartRow = CLng(ReadConfigOrDefault(sh, "DataStartRow", 2))
    offlineThreshold = CLng(ReadConfigOrDefault(sh, "OfflineThresholdDays", 5))
    timeoutFast = CLng(ReadConfigOrDefault(sh, "PingTimeoutFastMs", 1000))
    timeoutRetry = CLng(ReadConfigOrDefault(sh, "PingTimeoutRetryMs", 700))
    retryCount = CLng(ReadConfigOrDefault(sh, "PingRetryCount", 3))
    skipMarker = CStr(ReadConfigOrDefault(sh, "SkipMarker", "X"))

    If dataStartRow < 2 Then dataStartRow = 2
    If offlineThreshold < 1 Then offlineThreshold = 1
    If timeoutFast < 100 Then timeoutFast = 100
    If timeoutRetry < 100 Then timeoutRetry = 100
    If retryCount < 1 Then retryCount = 1
End Sub

Private Function ReadConfigOrDefault(ByVal sh As Worksheet, ByVal keyName As String, ByVal defaultValue As Variant) As Variant
    Dim lastRow As Long, r As Long
    lastRow = sh.Cells(sh.Rows.Count, 1).End(xlUp).Row

    For r = 2 To lastRow
        If StrComp(Trim$(CStr(sh.Cells(r, 1).Value2)), keyName, vbTextCompare) = 0 Then
            If Len(Trim$(CStr(sh.Cells(r, 2).Value2))) > 0 Then
                ReadConfigOrDefault = sh.Cells(r, 2).Value2
            Else
                ReadConfigOrDefault = defaultValue
            End If
            Exit Function
        End If
    Next r

    ReadConfigOrDefault = defaultValue
End Function

Private Function GetOrCreateSummarySheet(ByVal wb As Workbook) As Worksheet
    On Error Resume Next
    Set GetOrCreateSummarySheet = wb.Worksheets("Resumen")
    On Error GoTo 0

    If GetOrCreateSummarySheet Is Nothing Then
        Set GetOrCreateSummarySheet = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
        GetOrCreateSummarySheet.Name = "Resumen"
        With GetOrCreateSummarySheet
            .Range("A1:E1").Value = Array("Fecha", "Online", "Offline", "Saltados", "Alertas")
            .Rows(1).Font.Bold = True
            .Columns("A:E").AutoFit
        End With
    End If
End Function

Private Sub WriteDailySummary(ByVal wsResumen As Worksheet, ByVal totalOnline As Long, ByVal totalOffline As Long, _
                              ByVal totalSaltados As Long, ByVal alertaCantidad As Long)
    Dim nextRow As Long
    nextRow = wsResumen.Cells(wsResumen.Rows.Count, 1).End(xlUp).Row + 1

    wsResumen.Cells(nextRow, 1).Value = Date
    wsResumen.Cells(nextRow, 1).NumberFormat = "yyyy-mm-dd"
    wsResumen.Cells(nextRow, 2).Value = totalOnline
    wsResumen.Cells(nextRow, 3).Value = totalOffline
    wsResumen.Cells(nextRow, 4).Value = totalSaltados
    wsResumen.Cells(nextRow, 5).Value = alertaCantidad
End Sub

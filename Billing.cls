VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ThisWorkbook"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Function countRows(ws)
    countRows = 2
    Do While ws.Cells(countRows, 11) > 0
        countRows = countRows + 1
    Loop
End Function

Function InitialCount(ws, col)
    For i = countRows(ws) To 2 Step -1
        If ws.Cells(i, col) = 0 Then
            ws.Cells(i, col).EntireRow.Delete
        End If
    Next
    ws.Range("$A$1:$K$" + Trim(Str(countRows(ws)))).RemoveDuplicates Columns:=Array(1, 3, 6), Header:=xlYes
    InitialCount = countRows(ws) - 1
End Function


Sub ImportInvoices()
    Dim Filt As String
    Dim FilterIndex As Integer
    Dim Title As String
    Dim FileName As Variant
    
    Filt = "CSV Files (*.csv),*.csv"
    Title = "Select a Billing File to Import"
    FileName = Application.GetOpenFilename(FileFilter:=Filt, Title:=Title)
    
    If FileName = False Then
    MsgBox "No File Was Selected"
    Exit Sub
    End If
    
    Dim wb As Workbook
    Set wb = Workbooks.Open(FileName)
    Source = wb.Worksheets(1).Name
    wb.Worksheets(1).Range("C:C,D:D,K:K").NumberFormat = "0"
    wb.Sheets(1).Copy After:=wb.Sheets(1)
    wb.Sheets(1).Copy After:=wb.Sheets(1)
    wb.Sheets(2).Name = "Initial Cases"
    wb.Sheets(3).Name = "Initial Eaches"
    wb.Sheets.Add After:=wb.Sheets(3)
    wb.Sheets(4).Name = "Summary"


    cases = InitialCount(wb.Sheets(2), 9)
    eaches = InitialCount(wb.Sheets(3), 10)
    casechrg = ThisWorkbook.Names("CaseCharge").RefersToRange.Value2
    eachchrg = ThisWorkbook.Names("EachCharge").RefersToRange.Value2
   
    wb.Sheets(4).Cells(1, 2).Value = "Count"
    wb.Sheets(4).Cells(1, 3).Value = "Charges"
    
    wb.Sheets(4).Cells(2, 1).Value = "Cases"
    wb.Sheets(4).Cells(2, 2).Value = cases
    wb.Sheets(4).Cells(2, 3).Value = cases * casechrg
    
    wb.Sheets(4).Cells(3, 1).Value = "Eaches"
    wb.Sheets(4).Cells(3, 2).Value = eaches
    wb.Sheets(4).Cells(3, 3).Value = eaches * eachchrg
    
    
    wb.Sheets(4).Cells(4, 1).Value = "Total"
    wb.Sheets(4).Cells(4, 3).Value = cases * casechrg + eaches * eachchrg
    
    
    
    wb.Sheets(4).Range("C2:C4").Style = "Currency"
    wb.Sheets(4).Range("C4:C4").Font.Bold = True
    wb.Sheets(4).Columns("B:C").ColumnWidth = 12
    
    
End Sub


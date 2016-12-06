VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ThisWorkbook"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Function EachCount(ws)
    r = 2
    Do While ws.Cells(r, 9) > 0
        If ws.Cells(r, 5) < ws.Cells(r, 6) Then
            EachCount = EachCount + ws.Cells(r, 5)
        End If
        r = r + 1
    Loop
End Function


Sub ImportInvoices()
    Dim Filt As String
    Dim FilterIndex As Integer
    Dim Title As String
    Dim FileName As Variant
    
    Filt = "Xlsx (*.xlsx),*.xlsx"
    Title = "Select a Billing File to Import"
    FileName = Application.GetOpenFilename(FileFilter:=Filt, Title:=Title)
    
    If FileName = False Then
    MsgBox "No File Was Selected"
    Exit Sub
    End If
    
    Dim wb As Workbook
    Set wb = Workbooks.Open(FileName)
    wb.Sheets.Add After:=wb.Sheets(1)
    wb.Sheets(2).Name = "Summary"
    
    FillSummary wb.Sheets(1), wb.Sheets(2)
End Sub

Sub FillSummary(data, summary)
    eaches = EachCount(data)
    cases = 0
    
    casechrg = ThisWorkbook.Names("CaseCharge").RefersToRange.Value2
    eachchrg = ThisWorkbook.Names("EachCharge").RefersToRange.Value2
    
    summary.Cells(1, 2).Value = "Count"
    summary.Cells(1, 3).Value = "Charge per"
    summary.Cells(1, 4).Value = "Charges"
    
    summary.Cells(2, 2).Value = eaches
    summary.Cells(2, 3).Value = eachchrg
    summary.Cells(2, 4).Value = eaches * eachchrg
    
    summary.Cells(3, 2).Value = cases
    summary.Cells(3, 3).Value = casechrg
    summary.Cells(3, 4).Value = cases * casechrg
    
    
    summary.Cells(4, 3).Value = "Total"
    summary.Cells(4, 4).Value = cases * casechrg + eaches * eachchrg
    
    summary.Range("C2:d4").Style = "Currency"
    summary.Range("c4:d4").Font.Bold = True
    summary.Columns("B:d").ColumnWidth = 15
    
    
End Sub


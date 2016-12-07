VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ThisWorkbook"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Dim Report As Workbook
Dim Eaches
Dim Cases
Dim EachCharge
Dim CaseCharge


Function EachCount()
    r = 2
    Do While Report.Sheets(1).Cells(r, 9) > 0
        If Report.Sheets(1).Cells(r, 5) < Report.Sheets(1).Cells(r, 6) Then
            EachCount = EachCount + Report.Sheets(1).Cells(r, 5)
        End If
        r = r + 1
    Loop
End Function
Sub openReport(fn)

    EachCharge = ThisWorkbook.Names("EachCharge").RefersToRange.Value2
    CaseCharge = ThisWorkbook.Names("CaseCharge").RefersToRange.Value2
    Set Report = Workbooks.Open(fn)
    Report.Sheets.Add After:=Report.Sheets(1)
    Report.Sheets(1).Name = "Data"
    Report.Sheets(2).Name = "Summary"
    Report.Sheets(1).Cells(1, 11) = "Typcod"
    Report.Sheets(1).Cells(1, 11).Interior.Color = 65535
    Report.Sheets(1).Cells(1, 11).Font.Bold = True
    Report.Sheets(1).Cells(1, 12) = "Type"
    Report.Sheets(1).Cells(1, 12).Interior.Color = 65535
    Report.Sheets(1).Cells(1, 12).Font.Bold = True
    Report.Sheets(1).Cells(1, 13) = "Cases"
    Report.Sheets(1).Cells(1, 13).Interior.Color = 65535
    Report.Sheets(1).Cells(1, 13).Font.Bold = True
    Report.Sheets(1).Cells(1, 14) = "Eaches"
    Report.Sheets(1).Cells(1, 14).Interior.Color = 65535
    Report.Sheets(1).Cells(1, 14).Font.Bold = True
    
    typefn = Replace(fn, ".xlsx", "_typecodes.xlsx")
    Set typ = Workbooks.Open(typefn)
    typ.Sheets.Copy After:=Report.Sheets(1)
    
     
End Sub

Sub fillVlookups()
    r = 2
    Do While Report.Sheets(1).Cells(r, 9) > 0
        Report.Sheets(1).Cells(r, 11).FormulaR1C1 = "=VLOOKUP(C[-8],typeCodes!C1:C3,2, FALSE)"
        Report.Sheets(1).Cells(r, 12).FormulaR1C1 = "=VLOOKUP(C[-9],typeCodes!C1:C3,3, FALSE)"
        r = r + 1
    Loop
End Sub

Function unloadTypes()
    r = 2
    Do While Report.Sheets(1).Cells(r, 9) > 0
        Report.Sheets(1).Cells(r, 13).FormulaR1C1 = "=FLOOR(RC[-8]/RC[-7],1)"
        Report.Sheets(1).Cells(r, 14).FormulaR1C1 = "=RC[-9]-RC[-1]*RC[-8]"
        If Left(Report.Sheets(1).Cells(r, 11), 3) = "L02" Then
            
        End If
        r = r + 1
    Loop
    unloadTypes = r
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
    
    openReport (FileName)
    fillVlookups
    numRow = unloadTypes()
    Report.Sheets("Data").Columns("A:Z").EntireColumn.AutoFit
    summs (numRow)
    FillSummary Report.Sheets(1), Report.Sheets("Summary")
    Report.Sheets("Summary").Select
End Sub
Sub summs(rows)
    Report.Sheets(1).Cells(rows + 1, 13).FormulaR1C1 = "=Sum(" + Replace("R2C13:R" + Str(rows - 1) + "C13", " ", "") + ")"
    Report.Sheets(1).Cells(rows + 1, 14).FormulaR1C1 = "=Sum(" + Replace("R2C14:R" + Str(rows - 1) + "C14", " ", "") + ")"
    Eaches = Report.Sheets(1).Cells(rows + 1, 14)
    Cases = Report.Sheets(1).Cells(rows + 1, 13)
End Sub
Sub FillSummary(data, summary)

   
    
    summary.Cells(1, 2).Value = "Count"
    summary.Cells(1, 3).Value = "Charge per"
    summary.Cells(1, 4).Value = "Charges"
    
    summary.Cells(2, 1) = "Eaches"
    summary.Cells(2, 2) = Eaches
    summary.Cells(2, 3) = EachCharge
    summary.Cells(2, 4).FormulaR1C1 = "=C[-1]*C[-2]"
    
    summary.Cells(3, 1) = "Cases"
    summary.Cells(3, 2) = Cases
    summary.Cells(3, 3) = CaseCharge
    summary.Cells(3, 4).FormulaR1C1 = "=C[-1]*C[-2]"
    
    
    summary.Cells(4, 3).Value = "Total"
    summary.Cells(4, 4).FormulaR1C1 = "=R[-1]+r[-2]"
    
    summary.Range("C2:d4").Style = "Currency"
    summary.Range("c4:d4").Font.Bold = True
    summary.Columns("B:d").ColumnWidth = 15
    
    
End Sub


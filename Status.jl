
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using Base.Dates
using HIARP
using XlsxWriter

include("utils.jl")

i64(a::AbstractString) = a=="TBD" ? -1 : parse(Int64, a)

skulocs, locskus, rackskus = skuLocations()
locLabels = collect(keys(locskus))

currStolocs = currentStolocs()
currLabels = collect(keys(currStolocs))

function FLabels(racks, bins, levels)
	vec([@sprintf("F-%02d-%02d-%02d", r, l, b) for r in racks, b in bins, l in levels])
end

function BLabels()
	[ []
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 1:1, l in 10:10:60, b in [1:24; 31:55]])	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 3:3, l in 10:10:60, b in 31:55])	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 4:8, l in 10:10:60, b in [1:24; 31:55]])	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 9:19, l in 10:10:60, b in 1:25] 	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 3:3, l in 70:70, b in 31:55]  	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 4:4, l in 70:70, b in [17:24; 31:55]] )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 5:7, l in 70:70, b in 31:55]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 8:11, l in 70:70, b in 1:24]  )	
	; vec(["03-50-17" "03-70-22" "03-70-23"])
	]
end

function countif(col, startr, endr, cond)
	@sprintf "countif(%s:%s, \"%s\")" rc2cell(startr, col) rc2cell(endr, col) cond
end

function bakerFStatus(ws)
	labels = FLabels(1:81, 1:8, [10:10:90; 91])
	deployed = vec([FLabels(1:9, 1:8, [10:10:90; 91]); FLabels(7:9, 1:8, [40:10:60;]); FLabels(10:10, 1:8, 50:50); FLabels(12:12, 1:4, [10:10:90; 91])] )
	currentProd = DictVec(Stoloc, :stoloc, rackFPrtnums())
	cols = ["Stoloc" "Deployed" "Prtnum" "Descr" "Qty" "Assigned" "WrongProd" "Fill" "Ass&Dep" "Replenishable"]
	row = startrow = 5
	write_row!(ws, startrow-1, 0, cols)
	for label in sort(labels)
		prtass = string(get(locskus, label, ""))
		
		if haskey(currStolocs, label)
			item = currStolocs[label][1]
			prtin = string(item.prtnum)
			reass = prtass == "" ? "" : prtin==prtass ? "" : "Yes"
			fill = reass == "Yes" && prtass != "" ? "Yes" : ""
			assdep = prtass=="" ? "" : "Yes"
			write_row!(ws, row, 0, [label "*" prtin item.descr item.qty prtass reass fill assdep ""])
		else
			dep = (label in deployed ? "*":"")
			fill = prtass == "" ? "":"Yes"
			depass = dep == "*" && prtass != "" ? "Yes" : ""
			write_row!(ws, row, 0, [label dep "EMPTY" "" "" prtass "" fill depass depass])
		end
		row += 1
	end
	row -= 1
	write_row!(ws, 0, 0, ["Locations" "Deployed" "Empty" "Assigned" "Ass&Dep" "WrongProd" "NeedFill" "Replenishable"]) 
	write!(ws, 2, 0, "%") 

	coln(k) = findfirst(cols, k) -1
	
	c = write_row!(ws, 1, 0, ["=" * countif(coln("Stoloc"), startrow, row, "<>\"\"")])
	totAdd = string(Char('@' + coln("Locations") - 1)) * "2"
	write_column!(ws, 1, c, ["=" * countif(coln("Deployed"), startrow, row, "*") "=indirect(\"R[-1]\", false) / $totAdd"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Prtnum"), startrow, row, "EMPTY") "=indirect(\"R[-1]\", false) / $totAdd"])
	c += 1
	write_column!(ws, 1, c, ["=A2-" * countif(coln("Assigned"), startrow, row, "") "=indirect(\"R[-1]\", false) / $totAdd"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Ass&Dep"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / $totAdd"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("WrongProd"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / $totAdd"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Fill"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / $totAdd"])	
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Replenishable"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / " * string(Char('@' + coln("Assigned") - 1)) * "2"])	
	c + 3
end

function bakerExisting(ws, c)
	labels = BLabels()
	write_row!(ws, 3, c, ["Stoloc" "Prtnum" "Descr" "Qty"])
	row = startrow = 5
	for label in sort(labels)
		if haskey(currStolocs, label)
			item = currStolocs[label][1]
			write_row!(ws, row, c, [label string(item.prtnum) item.descr item.qty])
		else
			write_row!(ws, row, c, [label "EMPTY"])
		end
		row += 1
	end
	row -= 1
	write_row!(ws, 0, c, ["Locations" "Filled"]) 
	cntC = c
	c += write_row!(ws, 1, c, ["=" * countif(cntC, startrow, row, "<>\"\""), "=indirect(\"C[-1]\", false)-" * countif(cntC+1, startrow, row, "EMPTY")])
end

d = Dates.format(today(), "u_d")
@Xls "Status_$d" begin
	ws = add_worksheet!(xls, "F-Contents")
	c = bakerFStatus(ws)
	bakerExisting(ws, c+1)	
end



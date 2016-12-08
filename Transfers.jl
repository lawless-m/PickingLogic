
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
	[@sprintf("F-%02d-%02d-%02d", r, l, b) for r in racks, b in bins, l in levels]
end

function BLabels()
	[ []
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 1:8, l in 10:10:60, b in [1:24; 31:55]])
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 9:19, l in 10:10:60, b in 1:25] 	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 2:3, l in 70:70, b in [1:24; 31:55]]  	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 4:4, l in 70:70, b in [17:24; 31:55]] )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 5:7, l in 70:70, b in 31:55]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 8:11, l in 70:70, b in 1:24]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 13:13, l in 70:70, b in 1:8]  )
	
	]
end

function chanelLabels()
	[ []
	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 15:15, l in [120; 140], b in 1:90]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 15:15, l in [130], b in 1:120]  )

	]

end

function printLods(ws, row, labels, lods)
	for label in labels
		if haskey(lods, string(locskus[label]))
			prtnum = locskus[label]
			maxqty = skulocs[prtnum][2]
			fifos = FIFOSort(lods[string(prtnum)])
			if length(fifos) > 0
				write_row!(ws, row, 0, [label fifos[1].stoloc fifos[1].qty maxqty prtnum fifos[1].descr])
			else
				write_row!(ws, row, 0, [label "DOMESTIC" 0 maxqty prtnum lods[string(prtnum)][1].descr])
			end
			row += 1
		end
	end
	row
end

function testerInNonTestBin(k, v)
	if v[1].descr[1:2] == "T "		
		if v[1].stoloc[1] == 'F'
			return true
		end
		if v[1].stoloc[7] == '-'
			return false
		end
		r, l, b =  map(x->parse(Int64,x), split(v[1].stoloc, '-'))
		if l < 9 && b > 55
			return false
		end
		if b > 25
			return false
		end
		return true
	end
	return false			
end

function printBRItems(ws, flt=(k,v)->true)
	write_row!(ws, 0, 0, ["Stoloc" "Qty" "Prtnum" "Descr"])
	items = filter(flt, HIARP.BRItems())
	row = 1
	for s in sort(collect(keys(items)))
		item = items[s][1]
		write_row!(ws, row, 0, [item.stoloc item.qty item.prtnum item.descr])
		row += 1
	end
end
		
function procRacks(ws, levels)
	write_row!(ws, 0, 0, ["Stoloc" "NEXT FIFO" "FIFO Qty" "Fill QTY" "Prtnum" "Descr"])
	row = 1
	for rack in sort(collect(keys(rackskus)))
		if ! isnull(tryparse(Int64, rack))
			row = printLods(ws, row, intersect(locLabels, setdiff(FLabels([parse(Int64,rack)], 1:8, levels), currLabels)), FIFOStolocs(rackskus[rack], :prtnum))
		end
	end
end

function checkRacks(ws)
	write_row!(ws, 0, 0, ["Stoloc" "Has" "Should be"])
	tfd = rackFPrtnums()
	row = 1
	for r in 1:size(tfd)[1]
		loc = tfd[:stoloc][r]
		if haskey(locskus, loc) && string(locskus[loc]) != tfd[:prtnum][r]
			write_row!(ws, row, 0, [loc tfd[:prtnum][r] locskus[loc]])
			row += 1
		end
	end
end

function bakerStatus(ws, labels)
	empty = 0
	exist = 0
	testers = 0
	write_row!(ws, 3, 0, ["Stoloc" "Prtnum" "Descr" "Qty"])
	row = 4
	for label in sort(labels)
		exist += 1
		if haskey(currStolocs, label)
			item = currStolocs[label][1]
			write_row!(ws, row, 0, [label item.prtnum item.descr item.qty])
			if item.descr[1:2] == "T "
				testers += 1
			end
		else
			empty += 1
			write_row!(ws, row, 0, [label "EMPTY"])
		end
		row += 1
	end
	write_row!(ws, 0, 0, ["Locations" "Empty" "Empty%" "Testers" "Testers%"]) 
	write_row!(ws, 1, 0, [exist empty empty/exist testers testers/exist])
end

d = Dates.format(today(), "u_d")
@Xls "Status_$d" begin
	procRacks(add_worksheet!(xls, "F-picks"), [10:10:90; 91])
	procRacks(add_worksheet!(xls, "F-A-Picks"), [40 50 60])
	bakerStatus(add_worksheet!(xls, "F-Contents"), vec(FLabels(1:81, 1:8, [10:10:90; 91])))
	bakerStatus(add_worksheet!(xls, "F-A-Contents"), vec(FLabels(1:81, 1:8, [40; 50 ;60])))
	checkRacks(add_worksheet!(xls, "Checks"))
	printBRItems(add_worksheet!(xls, "Testers"), testerInNonTestBin)
	bakerStatus(add_worksheet!(xls, "Bakers"), BLabels())
	bakerStatus(add_worksheet!(xls, "Chanel"), chanelLabels())
	
end



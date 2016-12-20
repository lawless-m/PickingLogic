
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using Base.Dates
using HIARP
using XlsxWriter

include("utils.jl")



currStolocs = HAIItems()
currLabels = collect(keys(currStolocs))

skulocs, locskus, rackskus = fixedLocations()
locLabels = collect(keys(locskus))

bakers = BLabels()

bakerlocs = Dict{AbstractString, Vector{Stoloc}}()
hailocs = Dict{AbstractString, Vector{Stoloc}}()
for (loc, sto) in currStolocs
	if loc in bakers
		@push!(bakerlocs, sto[1].prtnum, sto[1])
	end
	@push!(hailocs, sto[1].prtnum, sto[1])
end
typcods = typeCodes(collect(keys(hailocs)))

function prtLocs(prts, ws, tester=false)
	set_column!(ws, "A:A", 35)
	set_column!(ws, "B:Z", 10)
	now = today()
	row = 5
	write_row!(ws, row-1, 0, ["Prtnum" "#Locations" "Locations"])
	numlocs = 0
	numprts = 0
	for p in sort(collect(keys(prts)), lt=(a, b)->length(prts[a]) < length(prts[b]), rev=true)		
		if tester 
			if typcods[p][1].typcod[1] != 'T'
				continue
			end
		else
			if typcods[p][1].typcod[1] == 'T'
				continue
			end
		end
		numprts += 1
		stos = prts[p]
		numlocs += length(stos)
		write_column!(ws, row, 0, [p stos[1].descr])
		write!(ws, row, 1, length(stos))
		write_row!(ws, row, 2, [s.stoloc for s in stos])
		write_column!(ws, row+1, 1, ["Qty" "Age"])
		
		c = 2
		for s in sort(stos, lt=(a, b)->a.fifo < b.fifo)
			write_column!(ws, row+1, c, [s.qty Int(now - Date(s.fifo))])
			c += 1
		end
		row += 3
	end
	write_row!(ws, 0, 0, ["#Prtnums" "#Locations"])
	write_row!(ws, 1, 0, [numprts numlocs])
end

function swapIns(wb, ws)
	sources = 0
	fifosources = 0
	row = 4
	bold = add_format!(wb, Dict("bold"=>true))
	write_row!(ws, row-1, 0, ["Location", "Prtnum", "Rack Source"])
	
	cs = currentPrtlocs()
	fifo = FIFOStolocs(collect(keys(cs)), :prtnum)
	
	for loc in sort(collect(keys(locskus)))
		if loc[1] != 'F'
			continue
		end
		sku = locskus[loc]

		write!(ws, row, 0, loc)
		write!(ws, row, 1, sku)
		if haskey(prts, sku)
			nxts = FIFOSort(fifo[sku])
			locs = [s.stoloc for s in prts[sku]]
	
			sources += 1
				
			if nxts[1].stoloc == locs[1]
				write!(ws, row, 2, nxts[1].stoloc, bold)
				write_row!(ws, row, 3, [s.stoloc for s in nxts[2:end]])
				fifosources += 1
			else
				write_row!(ws, row, 2, [s.stoloc for s in nxts])
			end
		end
		row += 1
	end
	write_row!(ws, 0, 0, ["In Rack Sources" "FIFO in rack"])
	write_row!(ws, 1, 0, [sources fifosources])
end

@Xls "consolidate_testers" begin
	#prtLocs(bakerlocs, add_worksheet!(xls, "Multi Bins"))
	#prtLocs(bakerlocs, add_worksheet!(xls, "Multi Tester Bins"), true)
	prtLocs(hailocs, add_worksheet!(xls, "All Testers"), true)
	
	#swapIns(xls, add_worksheet!(xls, "Swap Ins"))
end




			
	
	

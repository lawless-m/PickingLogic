
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using Base.Dates
using HIARP
using XlsxWriter

include("utils.jl")

currStolocs = HUSInventory()
currLabels = collect(keys(currStolocs))

skulocs, locskus, rackskus = fixedLocations()
locLabels = collect(keys(locskus))
items = itemMaster()
deployed = Fdeployed()

bakers = BLabels()

bakerlocs = Dict{AbstractString, Vector{Stoloc}}()
hailocs = Dict{AbstractString, Vector{Stoloc}}()
for (loc, sto) in currStolocs
	if loc in bakers
		@push!(bakerlocs, sto[1].prtnum, sto[1])
	end
	@push!(hailocs, sto[1].prtnum, sto[1])
end

macro FLTtester(istester, prtnums)
	:(filter((p)->$istester==(items[p].typcod[1] == 'T'), $prtnums))
end

function prtLocs(prts, ws, tester=false)
	set_column!(ws, "A:A", 35)
	set_column!(ws, "B:Z", 10)
	now = today()
	row = 5
	write_row!(ws, row-1, 0, ["SKU" "#Locations" "Locations"])
	numlocs = 0
	numprts = 0
	for p in sort(@FLTtester(tester, collect(keys(prts))), lt=(a, b)->length(prts[a]) < length(prts[b]), rev=true)
		numprts += 1
		stos = prts[p]
		numlocs += length(stos)
		write_column!(ws, row, 0, [p items[p].descr])
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
	write_row!(ws, 0, 0, ["#SKUs" "#Locations"])
	write_row!(ws, 1, 0, [numprts numlocs])
end

function assigned(ws, c, row, fifo, prts, sku, loc, bold)
	nxts = FIFOSort(fifo[sku])
	locs = [s.stoloc for s in prts[sku]]
		
	if length(nxts) == 0
		return (0, 0)
	end
	if length(locs) > 0 && nxts[1].stoloc == locs[1]
		write!(ws, row, c, nxts[1].stoloc, nxts[1] == loc ? italic : bold)
		write_row!(ws, row, c+1, [s.stoloc for s in nxts[2:end]])
		return (1, 1)
	else
		if nxts[1] == loc
			write!(ws, row, c, nxts[1].stoloc, italic)
		else
			write!(ws, row, c, nxts[1].stoloc)
		end
		write_row!(ws, row, c+1, [s.stoloc for s in nxts[2:end]])
		return (1, 0)
	end
end

function swapIns(prts, wb, ws)
	sources = 0
	fifosources = 0
	replen = 0
	row = 4
	bold = add_format!(wb, Dict("bold"=>true))
	italic = add_format!(wb, Dict("italic"=>true))
	write_row!(ws, row-1, 0, ["Location", "SKU", "Deployed", "Locations"])
	
	cs = currentPrtlocs()
	fifo = FIFOStolocs(collect(keys(cs)), :prtnum)
	
	row -= 1
	for loc in ["F-01-20-06", "F-01-20-07", "F-01-20-08", "F-01-30-01", "F-01-30-02", "F-01-30-03", "F-01-30-04", "F-01-30-05", "F-01-30-06"] #sort(collect(keys(locskus)))
		if loc[1] != 'F'
			continue
		end
		row += 1
		sku = locskus[loc]

		c = 0
		write!(ws, row, 0, loc)
		c += 1
		write!(ws, row, c, sku)
		c += 1	

		if loc in deployed
			write!(ws, row, c, "*")
		else
			write!(ws, row, c, "")
		end
		c += 1
			
		if haskey(prts, sku)	
			s, f  = assigned(ws, c, row, fifo, prts, sku, loc, bold)
			sources += s
			fifosources += f
			if loc in deployed
				replen += 1
			end
		end
	end
	write_row!(ws, 0, 0, ["#SKUs in Stock" "#FIFO in Rack" "#Replenishable"])
	write_row!(ws, 1, 0, [sources fifosources replen])
end

@Xls "swap_and_consolidate" begin
	prtLocs(bakerlocs, add_worksheet!(xls, "Non Testers, Bakers"))
	prtLocs(hailocs, add_worksheet!(xls, "Non Testers, All"))
	prtLocs(bakerlocs, add_worksheet!(xls, "Testers, Bakers"), true)
	prtLocs(hailocs, add_worksheet!(xls, "Testers, All"), true)
	swapIns(bakerlocs, xls, add_worksheet!(xls, "Swap Ins"))
	swapIns(hailocs, xls, add_worksheet!(xls, "Replenish"))
end


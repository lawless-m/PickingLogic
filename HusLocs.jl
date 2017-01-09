
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

using Base.Dates
using HIARP
using XlsxWriter

include("utils.jl")
include("merch_cats.jl")
include("families.jl")


skulocs, locskus, rackskus = skuLocations()

curr = currentStolocs()
typecodes = typeCodesSerial()

z3(n) = @sprintf "%03d" n
z2(n) = @sprintf "%02d" n

function merch(prtnum)
	typcod = get(typecodes, prtnum, "")
	if haskey(Merch_cat, typcod)
		typcod, Merch_cat[typcod]
	else
		typcod, ""
	end
end

function procLevel(ws, row, rack)
	for bin in [[z3(n) for n in 1:500]; [z2(n) for n in 1:500]]
		for level in [[z2(n) for n in 10:5:60]; [z3(n) for n in 10:5:60]]
			label = @sprintf "%s-%s-%s" rack level bin
			if haskey(curr, label)
				sto = curr[label][1]
				data = [label sto.prtnum sto.descr sto.qty haskey(skulocs, i64(sto.prtnum)) ? skulocs[i64(sto.prtnum)][1] : "" merch(sto.prtnum)...]
				write_row!(ws, row, 0, data)
				row = row + 1
			end
		end
	end
	row
end

function rackName(stoloc)
	d = search(stoloc, '-')
	if d > 0
		if stoloc[1] == 'F'
			rack = stoloc[1:search(stoloc[d+1:end], '-')+1]
		else
			rack = stoloc[1:d]
		end
	else
		n = search(stoloc, ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'])
		if n > 1
			rack = stoloc[1:n-1]
		elseif length(stoloc) >4 && stoloc[1:4] == "16HA"
			rack = "16HA"
		else
			rack = stoloc
		end
	end
	if rack[end] == '-' || rack[end] == '_'
		rack = rack[1:end-1]
	end
	if rack == "15*"
		rack = "15STAR"
	end
	rack = replace(rack, '/', '_')
end

function racklist(stolocs)
	racks = Dict{AbstractString, Vector{AbstractString}}()
	for s in stolocsHUS()
		rack = rackName(s)
		if haskey(racks, rack)
			push!(racks[rack], s)	
		else
			racks[rack] = AbstractString[s]
		end
	end
	racks
end


function writeLoc(curr, sheets, rack, loc, area)
	if haskey(curr, loc)
		sto = curr[loc][1]
		data = [area loc sto.prtnum sto.descr sto.qty haskey(skulocs, i64(sto.prtnum)) ? skulocs[i64(sto.prtnum)][1] : "" merch(sto.prtnum)...]
	else
		data = [area loc]					
	end
	write_row!(sheets[area][1], sheets[area][2], 0, data[2:end])
	write_row!(sheets[rack][1], sheets[rack][2], 0, data)
	write_row!(sheets["All"][1], sheets["All"][2], 0, data)	
		
	for s in (area, rack, "All")
		sheets[s] = (sheets[s][1], sheets[s][2] + 1)
	end

end

function getArea(locs)
	for loc in locs
		if haskey(curr, loc)
			return curr[loc][1].area
		end
	end
	"NO AREA"
end

function allstolocs()
	stolocs = stolocsHUS()
	racks = racklist(stolocs)
	locareas = locAreas()
	d = Dates.format(today(), "u_d")
	@Xls "HUSLocs_$d" begin
		Cols = [("Area", 10) ("Loc", 12) ("prtnum", 10) ("Descr", 35) ("Qty", 5) ("Fixed Loc", 11) ("Typecode", 12) ("Category", 25)]
		bold = add_format!(xls ,Dict("bold"=>true))
		date_format = add_format!(xls, Dict("num_format"=>"d mmmm yyyy"))
		sheets = Dict{AbstractString, Tuple{Worksheet, Int64}}() # name => (ws, rownum)
		sheets["All"] = (newSheet(xls, "ALL", Cols, bold), 1)
		tick = 0
		for rack in sort(collect(keys(racks)))
			println(rack)
			area = get(locareas, racks[rack][1], "NO AREA")
			if !haskey(sheets, area)
				sheets[area] = (newSheet(xls, area, Cols[2:end], bold), 1)
			end
			if !haskey(sheets, rack)
				sheets[rack] = (newSheet(xls, rack, Cols, bold), 1)
			end
			for loc in sort(racks[rack])
				writeLoc(curr, sheets, rack, loc, area)
			end
		end
	end
end

function rack28moves()
	rackmoves("28", 28:28)
end

function newSheet(wb, rack, Cols, fmt)
	ws = add_worksheet!(wb, rack)
	for c in 'A':'@'+length(Cols)
		set_column!(ws, "$c:$c", Cols[c-'@'][2])
		write_string!(ws, "$(c)1", Cols[c-'@'][1], fmt)
	end
	freeze_panes!(ws, 1, 0)
	ws
end
	

function rackmoves(wb, racks)
	Cols = [("Loc", 12) ("prtnum", 10) ("Descr", 35) ("Qty", 5) ("Fixed Loc", 11) ("Typecode", 12) ("Category", 25)]
	bold = add_format!(wb,Dict("bold"=>true))
	for rack in sort(collect(keys(racks)))
		ws = add_worksheet!(wb, rack)
		for c in 'A':'A'+length(Cols)
			set_column!(ws, "$c:$c", Cols[c-'@'][2])
			write_string!(ws, "$(c)1", Cols[c-'@'][1], bold)
		end
		freeze_panes!(ws, 1, 0)
		row = 1
		for p in racks[rack]
			row = procLevel(ws, row, p)
		end
	end
end

#@time @Xls "Rack_80-86_91_contents" rackmoves(xls, Dict("80"=>34:41))	#, "81"=>81, "82"=>82, "83"=>83, "84"=>84, "85"=>85, "86"=>86, "91"=>91))

HIARP.setLog(true)

@time allstolocs()




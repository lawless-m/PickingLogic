cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

using HIARP
using XlsxWriter
using Base.Dates

include("utils.jl")

skulocs, locskus, rackskus = fixedLocations()

function newSheet(wb, name, cols, fmt=nothing)
	ws = add_worksheet!(wb, name)
	for c in 'A':'@'+length(cols)
		set_column!(ws, "$c:$c", cols[c-'@'][2])
		write_string!(ws, "$(c)1", cols[c-'@'][1], fmt)
	end
	freeze_panes!(ws, 1, 0)
	ws
end

function fill_sheet(ws, row, locs, inventory)
	wrt(st, c) = write!(ws, row, c, st.stoloc * " " * st.case_id)
	for loc in locs
		write!(ws, row, 0, loc)
		prtnum = locskus[loc]
		write!(ws, row, 1, prtnum)
		if haskey(inventory, prtnum)
			write!(ws, row, 2, skulocs[parse(Int64, prtnum)][2])
			write!(ws, row, 3, inventory[prtnum][1].descr)
			
			if alreadyPicked(inventory[prtnum], loc)
				write!(ws, row, 4, "PICKED")
			else
				picks = FIFOSort(inventory[prtnum])
				
				if length(picks) > 0
					wrt(picks[1], 4)
				end
				if length(picks) > 1
					wrt(picks[2], 5)
				end
				if length(picks) > 3
					wrt(picks[end-1], 6)
				end
				if length(picks) > 2
					wrt(picks[end], 7)
				end
			end
		end
		row += 1
	end
	row
end

function alreadyPicked(inventory, stoloc)
	for i in inventory
		if stoloc == i.stoloc
			return true
		end
	end
	false
end

@time @Xls "MoveList_" * string(Dates.format(today(), "u_d")) begin
	sheets = Dict{AbstractString, Worksheet}()
	cols = [("Loc", 11) ("prtnum", 10) ("Qty", 5) ("descr", 25) ("Oldest", 25) ("Oldest+1", 25) ("Newest-1", 25) ("Newest", 25)]
	for r in sort(collect(keys(rackskus)))
		sheets[r] = newSheet(xls, r, cols)
		row = 1
		locs = sort(filter((x)->x[1:4] == "F-$r", collect(keys(locskus))))
		prtnums = [locskus[l] for l in locs]
		if length(prtnums) > 0
			inventory = FIFOStolocs(prtnums, :prtnum)
			row = fill_sheet(sheets[r], row, locs, inventory)
		end
	end
end


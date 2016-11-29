
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

using HIARP
using XlsxWriter

include("utils.jl")
include("merch_cats.jl")

skulocs, locskus, rackskus = skuLocations()

curr = currentStolocs()

z3(n) = @sprintf "%03d" n
z2(n) = @sprintf "%02d" n

function merch(prtnum)
	typcod = typeCode(prtnum)
	typcod, Merch_cat[typcod]
end

function procLevelX(fid, rack)
	for bin in [[z3(n) for n in 1:500]; [z2(n) for n in 1:500]]
		for level in [[z2(n) for n in 10:5:60]; [z3(n) for n in 10:5:60]]
			label = @sprintf "%s-%s-%s" rack level bin
			if haskey(curr, label)
				sto = curr[label][1]
				@printf fid "%s\t\"%s\"\t%s\t%s\t%d" label sto.prtnum sto.descr typeCode(sto.prtnum) sto.qty
				if haskey(skulocs, i64(sto.prtnum))
					@printf fid "\t%s\n" skulocs[i64(sto.prtnum)][1]
				else
					@printf fid "\t?\n"
				end
			end
		end
	end
end

function procLevel(ws, row, rack)
	for bin in [[z3(n) for n in 1:500]; [z2(n) for n in 1:500]]
		for level in [[z2(n) for n in 10:5:60]; [z3(n) for n in 10:5:60]]
			label = @sprintf "%s-%s-%s" rack level bin
			if haskey(curr, label)
				sto = curr[label][1]
				data = [label sto.prtnum sto.descr merch(sto.prtnum)...  sto.qty haskey(skulocs, i64(sto.prtnum)) ? skulocs[i64(sto.prtnum)][1] : "?"]
				write_row!(ws, row, 0, data)
				row = row + 1
			end
		end
	end
	row
end


function rack28moves()
	rackmoves("28", 28:28)
end


function rackmoves(wb, racks)
	bold = add_format!(wb,Dict("bold"=>true))
	for rack in sort(collect(keys(racks)))
		ws = add_worksheet!(wb, rack)
		for cw in [("A:B", 10) ("C:C", 35) ("D:D", 12) ("E:E", 10) ("F:F", 12)]
			set_column!(ws, cw[1], cw[2])
		end
		freeze_panes!(ws, 1, 0)
		write_row!(ws, 0, 0, ["Loc" "prtnum" "Item" "Type" "Qty" "Move To"], bold)
		row = 1
		for p in racks[rack]
			row = procLevel(ws, row, p)
		end
	end
end

@time @Xls "Rack_80-86_91_contents" rackmoves(xls, Dict("80"=>34:41))	#, "81"=>81, "82"=>82, "83"=>83, "84"=>84, "85"=>85, "86"=>86, "91"=>91))





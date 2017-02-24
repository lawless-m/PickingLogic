cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")
include("Families.jl")

using Base.Dates
using HIARP
using XlsxWriter

skulocs, locskus, rackskus = skuLocations()
physLocs = physicalHUSLocations()
curr = currentStolocs()
items = itemMaster()

function CoolToDry(ws)
	write_row!(ws, 0, 0, ["Stoloc" "Rack" "Level" "Pos" "Prtnum" "Qty" "Descr"])
	row = 1
	for (stoloc, ps) in curr
		for p in ps
			fam = family(p.prtnum)
			mer = merch(p.prtnum)
			if p.area == "CLDRMST" && fam[1] in ["C1F1" "C1F"] && mer[1][1] != 'T'
				i = items[p.prtnum]
				write_row!(ws, row, 0, [p.stoloc split(p.stoloc, "-")... p.prtnum p.qty i.descr])
				row += 1
			end
		end
	end
end

function DryToCool(ws)
	write_row!(ws, 0, 0, ["Stoloc" "Rack" "Level" "Pos" "Prtnum" "Qty" "Descr"])
	row = 1
	for (stoloc, ps) in curr
		for p in ps
			fam = family(p.prtnum)
			mer = merch(p.prtnum)
			if p.area in ["HWLFTZRR" "HWLFTZRL" "PALR01"] && fam[1] in ["C1T01F" "C1T02F" "C1T02F1" "C1T03F1"] && mer[1][1] != 'T'
				i = items[p.prtnum]
				write_row!(ws, row, 0, [p.stoloc split(p.stoloc, "-")... p.prtnum p.qty i.descr])
				row += 1
			end
		end
	end
			
end

function AreaMoves()
	d = Dates.format(today(), "u_d")
	@Xls "CoolDry_Moves_$d" begin
		CoolToDry(add_worksheet!(xls, "Cool2Dry"))
		DryToCool(add_worksheet!(xls, "Dry2Cool"))
	end
end

AreaMoves()

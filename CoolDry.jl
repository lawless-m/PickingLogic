cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")


include(abspath("GitHub/PickingLogic/utils.jl"))
include(abspath("GitHub/PickingLogic/merch_cats.jl"))
include(abspath("GitHub/PickingLogic/Families.jl"))

using Base.Dates
using HIARP
using XlsxWriter
using ExcelReaders

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

function nowInDry()
	xl = @sheet "Cool-Dry\\CoolDry_Moves_Feb_20.xlsx" "Cool2Dry"
	dries = Set{AbstractString}()
	for r in 2:size(xl, 1)
		prt = @sprintf "%s" xl[r,2]
		push!(dries, prt)
	end
	@Xls "Cool-Dry\\Dried" begin
		ws = add_worksheet!(xls, "Dried")
		row = 1
		write_row!(ws, 0, 0, ["stoloc" "prtnum" "famcod" "family" "qty" "descr"])
		for (stoloc, ps) in curr
			for p in ps
				if ! (p.prtnum in dries)
					continue
				end
				if p.area in ["HWLFTZRR" "HWLFTZRL" "PALR01"]
					write_row!(ws, row, 0, [stoloc p.prtnum p.qty family(p.prtnum)... items[p.prtnum].descr])
					row += 1
				end
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


function Heinemann_Colds()
	xl = @sheet "Cool-Dry\\Liquor, Wine & Sparkling - Heinemann.xlsx" "Sheet1"
	@Xls "Cool-Dry\\Liquor, Wine & Sparkling - with family" begin
		ws = add_worksheet!(xls, "Fam")
		write_row!(ws, 0, 0, ["GH CODE" "CLASS" "DESCRIPTION" "FAMILY CODE" "FAMILY"])
		for r in 2:size(xl, 1)	
			prtnum = string(@denaI(xl[r, 1]))
			write_row!(ws, r-1, 0, [prtnum @dena(xl[r,2]) @dena(xl[r,3]) family(prtnum)...])
		end
	end
end

# Heinemann_Colds()

# AreaMoves()

nowInDry()


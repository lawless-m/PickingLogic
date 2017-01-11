
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

inv_by_loc = DictVec2Map(HUSInventory()) #currentStolocs()
used_locs = collect(keys(inv_by_loc))
items = itemMaster()

function countif(col, startr, endr, cond)
	@sprintf "countif(%s:%s, \"%s\")" rc2cell(startr, col) rc2cell(endr, col) cond
end


macro write(d)
	:(col += write!(ws, row, col, $d))
end
macro Yes(b)
	:(col += write!(ws, row, col, $b?"Yes":""))
end
	
macro nonz(n)
	:(col += write!(ws, row, col, $n>0?$n:""))
end

macro nonE(t)
	:(col += write!(ws, row, col, $t==""?"EMPTY":$t))
end

macro descr(prtnum)
	:(col += write!(ws, row, col, get(items, $prtnum, Part()).descr))
end


function bakerFStatus(ws)
	fLocs = allFLabels()
	deployed = Fdeployed()
	used = physicalFlabels()
	currentProd = DictVec(Stoloc, :stoloc, rackFPrtnums())
	cols = ["Stoloc" "Deployed" "In Use" "Prtnum" "Descr" "Qty" "Assigned" "WrongProd" "Fill" "Ass&Dep" "Replenishable"]
	row = startrow = 5
	write_row!(ws, startrow-1, 0, cols)
	
	for loc in sort(fLocs)
		col = 0
		@write loc
		dep = loc in deployed ? "*" : "" # has this bin been deployed
		@write dep
		@write loc in used ? "*":""
		item = get(inv_by_loc, loc, Stoloc()) # item stored this location
		@nonE item.prtnum
		@descr item.prtnum
		@nonz item.qty
		prtass = string(get(locskus, loc, "")) # prtnum assigned to this location
		@write prtass
		@Yes !(item.prtnum != "" && item.prtnum == prtass) # does this product need moving ?
		@Yes item.prtnum != prtass # does this space need filling 
		@Yes dep=="*" && prtass != "" # is the bin deployed and assigned
		@Yes dep=="*" && item.prtnum=="" # can we replenish this bin i.e. deployed and empty
		row += 1
	end
	
	row -= 1
	write_row!(ws, 0, 0, ["Locations" "Deployed" "Empty" "Assigned" "Ass&Dep" "WrongProd" "NeedFill" "Replenishable"]) 
	write!(ws, 2, 0, "%") 

	coln(k) = findfirst(cols, k) -1
	colC(k) = string(Char('A' + coln(k))) 
	
	c = write_row!(ws, 1, 0, ["=" * countif(coln("Stoloc"), startrow, row, "<>\"\"")])
	write_column!(ws, 1, c, ["=" * countif(coln("Deployed"), startrow, row, "*") "=indirect(\"R[-1]\", false) / " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Prtnum"), startrow, row, "EMPTY") "=indirect(\"R[-1]\", false) / " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=A2-" * countif(coln("Assigned"), startrow, row, "") "=indirect(\"R[-1]\", false) / " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Ass&Dep"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("WrongProd"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Fill"), startrow, row, "Yes") "=indirect(\"R[-1]\", false)/ " * colC("Stoloc") * "2"])
	c += 1
	write_column!(ws, 1, c, ["=" * countif(coln("Replenishable"), startrow, row, "Yes") "=indirect(\"R[-1]\", false) / " * colC("Assigned") * "2"])	
	c + 3
end

function bakerExisting(ws, c)
	labels = BLabels()
	write_row!(ws, 3, c, ["Stoloc" "Prtnum" "Descr" "Qty"])
	row = startrow = 5
	for label in sort(labels)
		if haskey(inv_by_loc, label)
			item = inv_by_loc[label]
			write_row!(ws, row, c, [label item.prtnum items[item.prtnum].descr item.qty])
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



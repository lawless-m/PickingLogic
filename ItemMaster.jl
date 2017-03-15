cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")

using HIARP
using XlsxWriter
using ExcelReaders
using Base.Dates

items = itemMaster()

function createMaster()
	@Xls "ItemMaster" begin
		ws = add_worksheet!(xls, "Item Master")
		write_row!(ws, 0, 0, ["prtnum" "typcod" "abccod" "family" "descr"])
		row = 1
		for (prt, item) in items
			write_row!(ws, row, 0, [prt item.typcod item.abccod item.family item.descr])
			row = row + 1
		end
	end
end

createMaster()

cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
using Base.Dates
using HIARP
using XlsxWriter

@Xls "Multi_$(Today())" begin
	
	ws = add_worksheet!(xls, "Multi")
	write_row!(ws, 0, 0, ["Year-Month" "Cartons"])
	row = 1
	for yr in 2013:2017
		for m in 1:12
			 dte = @sprintf "%04d-%02d" yr m
			 write_row!(ws, row, 0, [dte HIARP.ships(yr, m)])
			 row += 1
		end
	end
end
			

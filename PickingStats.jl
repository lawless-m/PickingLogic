cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using DataFrames
using HIARP

include(abspath("GitHub/PickingLogic/utils.jl"))

function cacheOrders()
	ords = Dict{Int64, OrdLine}() # year => OrdLine
	for yr in 2013:2017
		ords[yr] = orderAmntByDay(yr)		
	end
	ords
end

function SkuAvg()
	xl = @sheet "Travel Sequence/A SKU Data  R2.xlsx" "Cosmetics & Frag"
	sa = Dict{AbstractString, Float64}()
	for r in 4:size(xl, 1)
		if isna(xl[r,1]) || isna(xl[r,23]) 
			continue
		end
		sa[@sprintf "%d" xl[r,1]] = xl[r,23]
	end
	sa
end

@cacheFun(cacheOrders, "g:/Heinemann/Orders2013-2016.jls")



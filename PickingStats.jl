cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using DataFrames
using HIARP
using XlsxWriter

include(abspath("GitHub/PickingLogic/utils.jl"))

Years = 2013:2017
MaxDays = Dict{Int64, Int64}()
for yr in Years
	MaxDays[yr] = yr == 2016 ? 366:365
end


function cacheOrders()
	ords = Dict{Int64, OrdLine}() # year => {sku => Dict{date=>qty}}
	for yr in Years
		ords[yr] = orderAmntByDay(yr)		
	end
	ords
end

function SkuAvg()
	xl = @sheet "Travel Sequence/A SKU Data  R2.xlsx" "Cosmetics & Frag"
	sa = Dict{AbstractString, Tuple{Float64, Float64}}() # avg/pick  avg/week
	for r in 4:size(xl, 1)
		if isna(xl[r,1]) || isna(xl[r,23]) || isna(xl[r,24]) 
			@printf STDERR "na %s\n" r
			continue
		end
		sa[@sprintf "%d" xl[r,1]] = (xl[r,23], xl[r,24])
	end
	sa
end

allOrders = @cacheFun(cacheOrders, "g:/Heinemann/Orders2013-2016.jls")
rankA = SkuAvg()

function sumDict(d)
	sum = 0
	cnt = 0
	for (k,v) in d
		sum += v
		cnt += 1
	end
	cnt, sum
end

# ords = Dict{Int64, OrdLine}() # year => {sku => Dict{date=>qty}}

function writeOrders(xls, skus)
	vert = add_format!(xls, Dict("rotation"=>-90, "valign"=>"top"))
	#set_rotation!(vert, -90)
	
	sheets = Dict()
	for yr in Years
		ws = get(sheets, yr, add_worksheet!(xls, string(yr)))
		write_row!(ws, 0, 1, ["#picks", "sum(qty)"])
		for d = 1:MaxDays[yr]
			write!(ws, 0, d+2, Dates.format(Date(yr-1,12,31) + Dates.Day(d), "dd-u"), vert)
		end
		row = 1
		for sku in skus
			write!(ws, row, 0, sku)
			cnt = 0
			sum = 0
			for (d,q) in get(allOrders[yr], sku, Dict())
				write!(ws, row, 2+Dates.dayofyear(d), q)
				cnt += 1
				sum += q
			end
			write_row!(ws, row, 1, [cnt, sum])
			row += 1
		end
	end
end

@Xls "recalc_avgs" begin
	ws = add_worksheet!(xls, "sums")
	writeOrders(xls, keys(rankA))
	row = 1
	data = ["Sku", "R2Avg/pick"]
	for yr in Years
		append!(data, ["# $yr picks", "$yr sum", "$yr avg"])
	end
	append!(data, ["#Picks", "Sum", "Avg"])
	write_row!(ws, 0, 0, data)
	
	for sku in keys(rankA)
		data = [sku, rankA[sku][1]]
		tcnt, tsum = 0, 0
		for yr in Years
			cnt, sum = sumDict(get(allOrders[yr], sku, Dict()))
			append!(data, [cnt, sum, cnt>0?sum/cnt:0])
			tcnt += cnt
			tsum += sum
		end
		append!(data, [tcnt, tsum, tcnt>0?tsum/tcnt:0])
		
		write_row!(ws, row, 0,  data)
		row += 1
	end
end



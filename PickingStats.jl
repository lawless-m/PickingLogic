cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using ExcelReaders
using DataFrames
using HIARP
using XlsxWriter

include(abspath("GitHub/PickingLogic/utils.jl"))


function SkuAvg()
	xl = @sheet "Travel Sequence/A SKU Data  R2.xlsx" "Cosmetics & Frag"
	sa = Dict{AbstractString, Tuple{Float64, Float64}}() # avg/pick  avg/week
	skuOrder = []
	for r in 4:size(xl, 1)
		if isna(xl[r,1]) || isna(xl[r,23]) || isna(xl[r,24]) 
			break
		end
		sku = @sprintf "%d" xl[r,1]
		push!(skuOrder, sku)
		sa[sku] = (xl[r,23], xl[r,24])
	end
	skuOrder, sa
end

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

function writeOrders(wb)
	for yr in Years
		ws = add_worksheet!(wb, "Ords$yr")
		cold = write_row!(ws, 0, 1, ["#Orders", "sum(qty)", "median"])
		for d = 1:MaxDays[yr]
			write!(ws, 0, cold+d, Dates.format(Date(yr-1,12,31) + Dates.Day(d), "dd-u"), FMTs["vert"])
		end
		for row in 1:size(aSkus, 1)
			range = rc2cell(row, cold+1) *":"* rc2cell(row, cold+1+MaxDays[yr])
			col = write_row!(ws, row, 0, [aSkus[row], "=count($range)", "=sum($range)", "=if(exact(indirect(\"C[-1]\", false), 0), 0, median($range))"])
			for (d,q) in get(allOrders[yr], aSkus[row], Dict())
				write!(ws, row, col+Dates.dayofyear(d), q)
			end
		end
	end
end

function buildOrdAvgs(ws)
	set_column!(ws, "A:Z", 12)
	data = ["Sku", "R2Avg/pick", "Order Avgs"]
	append!(data, ["$yr avg" for yr in Years])
	append!(data, ["#Orders", "Sum(Qty)", "Avg"])
	write_row!(ws, 0, 0, data)
	
	for row in 1:size(aSkus, 1)
		c = write_row!(ws, row, 0, [aSkus[row], rankA[aSkus[row]][1]])
		c += [add_sparkline!(ws, row, c, Dict("range"=>colNtocolA(c) * "$row:" * colNtocolA(c+length(Years)) * "$row", "type"=>"column")), 1][2] # hack to return 1
		for yr in Years
			# yearly averages
			c += write!(ws, row, c, "=IF(EXACT('Ords$yr'!B$(row+1),0),0,'Ords$yr'!C$(row+1)/'Ords$yr'!B$(row+1))", FMTs["twodp"])
		end
		# totals
		c += write_row!(ws, row, c, ["=" * join(["'Ords$yr'!B$(row+1)" for yr in Years], "+"), "=" * join(["'Ords$yr'!C$(row+1)" for yr in Years], "+")], FMTs["int"])
		# calculate overall averagea
		c += write!(ws, row, c, "=if(exact(indirect(\"C[-2]\",false),0),0,indirect(\"C[-1]\", false)/indirect(\"C[-2]\", false))", FMTs["twodp"])
	end

end

function buildOrdMedians(ws)
	set_column!(ws, "A:Z", 12)
	col = write_row!(ws, 0, 0, ["Sku", "R2Avg/pick", "Medians"])
		
	for yr in Years
		col += write!(ws, 0, col, "$yr Median")
	end
	
	for yr in Years
		col += write!(ws, 0, col, "$yr Order Qty")
	end
			
	for row in 1:size(aSkus, 1)
		c = write_row!(ws, row, 0, [aSkus[row], rankA[aSkus[row]][1]])
		c += [add_sparkline!(ws, row, c, Dict("range"=>colNtocolA(c+1) * "$row:" * colNtocolA(c+2length(Years)) * "$row", "type"=>"column")), 1][2] # hack to return 1
		c += write_row!(ws, row, c, ["='Ords$yr'!D$(row+1)" for yr in Years], FMTs["int"])
		for yr in Years
			c += [add_sparkline!(ws, row, c, Dict("range"=>"Ords$(yr)!" * rc2cell(row, c+1) *":"* rc2cell(row, c+1+MaxDays[yr]), "type"=>"column")), 1][2] # hack to return 1
		end
	
	end
end


function writePicks(wb) # picks["yr"]["prtnum"][month]
	cold = 0
	for yr in Years
		ws = add_worksheet!(wb, "Picks$yr")
		cold = write_row!(ws, 0, 1, ["#Picks", "Sum(qty)", "Avg",  "Median", "Stdev.P", "Kurtosis"])
		for d = 1:MaxDays[yr]
			write!(ws, 0, cold+d, Dates.format(Date(yr-1,12,31) + Dates.Day(d), "dd-u"), FMTs["vert"])
		end
		for row in 1:size(aSkus, 1) # skus[row] => prtnum
			range = rc2cell(row, cold+1) *":"* rc2cell(row, cold+1+MaxDays[yr])
			col = write_row!(ws, row, 0, [aSkus[row], "=count($range)", "=sum($range)"], FMTs["int"])
			col += write!(ws, row, col, "=if(exact(indirect(\"C[-1]\", false), 0), 0, average($range))", FMTs["twodp"]) # c[-1] = sum
			col += write!(ws, row, col, "=if(exact(indirect(\"C[-2]\", false), 0), 0, median($range))", FMTs["int"]) # c[-2] = sum
			col += write!(ws, row, col, "=if(exact(indirect(\"C[-3]\", false), 0), 0, _xlfn.STDEV.P($range))", FMTs["twodp"]) # c[-3] = sum
			col += write!(ws, row, col, "=if(indirect(\"C[-5]\", false)>4,Kurt($range),\"\")", FMTs["twodp"]) # c[-5] = count
			if !haskey(allPicks[yr], aSkus[row])
				continue
			end
			for m in 1:12
				if isdefined(allPicks[yr][aSkus[row]], m)
					for p in allPicks[yr][aSkus[row]][m]
						write!(ws, row, col+Dates.dayofyear(p.date), p.qty)
					end
				end
			end
		end
	end
end

function summaryPicks(ws, cold)
	set_column!(ws, "A:Z", 12)
	data = ["Sku", "R2Avg/pick"]
	col1 = write_row!(ws, 0, 0, data)
	col1 += write_row!(ws, 0, col1, ["#Picks", "Qty", "Median", "Avg", "Stdev", "Kurtosis"])
	for yr in Years
		col1 += write!(ws, 0, col1, "Picks $yr")
	end
	for row in 1:size(aSkus, 1) # skus[row] => prtnum
		ranges = ["Picks$(yr)!" * rc2cell(row, cold+1) *":"* rc2cell(row, cold+1+MaxDays[yr]) for yr in Years]
		comranges = join(ranges, ",")
		col = write_row!(ws, row, 0, [aSkus[row], rankA[aSkus[row]][1]])

		col += write_row!(ws, row, col, ["=count(" * join(ranges, ") + count(") * ")", "=sum($comranges)", "=median($comranges)"], FMTs["int"])
		col += write_row!(ws, row, col, ["=average($comranges)", "=_xlfn.STDEV.P($comranges)", "=if(indirect(\"C[-5]\", false)>4, kurt($comranges),\"\")"], FMTs["twodp"])	
		for yr in Years
			col += [add_sparkline!(ws, row, col, Dict("range"=>"Picks$(yr)!" * rc2cell(row, cold+1) *":"* rc2cell(row, cold+1+MaxDays[yr]), "type"=>"column")), 1][2] # hack to return 1
		end
	end
	
end

allOrders = @cacheFun(cacheOrders, "g:/Heinemann/Orders2013-2016.jls")
allPicks = @cacheFun(cachePicks, "g:/Heinemann/Picks2013-2016.jls")

aSkus, rankA = SkuAvg()
FMTs = Dict{AbstractString, Format}()
sheets = Dict{AbstractString, Worksheet}()

@Xls "recalc_avgs" begin
	FMTs["int"] = add_format!(xls, Dict("num_format"=> "0"))
	FMTs["twodp"] = add_format!(xls, Dict("num_format"=> "0.00"))
	FMTs["vert"] = add_format!(xls, Dict("rotation"=>-90, "valign"=>"top"))
	FMTs["hidden"] = add_format!(xls, Dict("hidden"=>1))
		
	buildOrdAvgs(add_worksheet!(xls, "OrdAvgs"))
	buildOrdMedians(add_worksheet!(xls, "OrdMedians"))
	summaryPicks(add_worksheet!(xls, "Picks"), 6)
	
	writePicks(xls)
	writeOrders(xls)
	
	
end



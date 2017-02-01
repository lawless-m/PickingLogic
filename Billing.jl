cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")

using HIARP
using XlsxWriter
using ExcelReaders

items = itemMaster()

function byPrtMonth(yr, mn)
	RPClient.qSQL("
		with prtmonth(yr, mn, dy, prtnum, untqty, untcas) as (
			SELECT year(rcvdte) as yr, right(concat('00', month(rcvdte)), 2) as mn, right(concat('00', day(rcvdte)), 2) as dy, prtnum, untqty, untcas 
			FROM invdtl
			WHERE prt_client_id='HUS'
			)
		SELECT dy, prtnum, untqty, untcas FROM prtmonth where yr='$yr' and mn='$mn' order by dy, prtnum
		")
end

function prtmonths()
	@Xls "prtmonths" begin
		for m in ["08" "09" "10" "11"]
			ws = add_worksheet!(xls, m)
			df = byPrtMonth("2016", m)
			for r in 1:size(df)[1]
				write!(ws, r, 1, df[:dy][r])
				write!(ws, r, 2, df[:prtnum][r])
				write!(ws, r, 3, df[:untqty][r])
				write!(ws, r, 4, df[:untcas][r])
			end
		end
	end
end

function parsewhIDs(ws, skus, whids)
	write_row!(ws, 0, 0, ["Article" "Descr" "Typcod" "Typ" "Put aways"])
	puts = wherePuts(skus, whids)
	row = 1
	for sku in skus
		item = items[sku]
		c = write_row!(ws, row, 0, [sku item.descr item.typcod Merch_cat[item.typcod]])
		if haskey(puts, sku)
			c += write_row!(ws, row, c, [s.stoloc for s in puts[sku]])	
		end
		row += 1
	end
end


function getRecd(year, month)
	recd = HIARP.getRecd(year, month)
	skus = Set()
	whids = Set()
	@Xls "Billing/recd_$(year)_$(month)" begin
		dte = add_format!(xls, Dict("num_format"=>"d mmm yyyy"))
		ws = add_worksheet!(xls, "Data")
		write_row!(ws, 0, 0, ["Date" "Activity"	"Article" "Status" "rcvqty"	"units per Case"	"# cases"	"Entry ID"	"Invoice"	"Received by"	"Typcod"	"Type"	"Cases"	"Eaches"	"Pallets"])
		for row in 1:length(recd)
			r = recd[row]
			item = get(items, r.prtnum, "")
			typ = item == "" ? "XX" : item.typcod				
			cat = get(Merch_cat, typ, "XX")
			write!(ws, row, 0, r.date, dte)
			write_row!(ws, row, 1, [r.activity r.prtnum r.status r.rcvqty r.untcas 0 r.entry_id r.invnum r.recd_by typ cat 0 0 0])
			push!(skus, r.prtnum)
			push!(whids, r.entry_id)
		end	
		parsewhIDs(add_worksheet!(xls, "Articles"), skus, whids)
	end
end

getRecd(2017, 1)
#parseReport("Billing/December_processed.xlsx")



 
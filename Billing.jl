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
		select dy, prtnum, untqty, untcas from prtmonth where yr='$yr' and mn='$mn' order by dy, prtnum
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

function parseReport(repFn)
	xl = @sheet repFn 1
	@Xls replace(repFn, ".xlsx", "_PutAways") begin
		prtnums = unique(xl[2:end,3])
		ws = add_worksheet!(xls, "Articles")
		write_row!(ws, 0, 0, ["Article" "Descr" "Typcod" "Typ" "Put aways"])
		puts = wherePuts(prtnums, unique(xl[2:end,8])) # prtnums, wh_entry_ids
		for sku in prtnums
			c = write_row!(ws, xr, 0, [prtnum items[sku].descr items[sku].typcod Merch_cat[items[sku].typcod])
			if haskey(puts, sku)
				c += write_row!(ws, xr, c, [s.stoloc for s in puts[sku]])	
			end
		end
	end
end

parseReport("Billing/December_processed.xlsx")



 
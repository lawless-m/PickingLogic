cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")

using HIARP
using XlsxWriter
using ExcelReaders


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

function prtnums2typcod(xlfn)
	xl = @sheet xlfn 1
	include("merch_cats.jl")
	@Xls replace(xlfn, ".xlsx", "_typecodes") begin
		ws = add_worksheet!(xls, "typeCodes")
		write!(ws, 0, 0, "Article")
		write!(ws, 0, 1, "Type Code")
		write!(ws, 0, 2, "Type")
		r = 1
		for (prt, cod) in typeCodes(unique(xl[2:end,3]))
			write!(ws, r, 0, prt)
			write!(ws, r, 1, cod)
			if haskey(Merch_cat, cod)
				write!(ws, r, 2, Merch_cat[cod])
			end
			r += 1
		end
	end
end


prtnums2typcod("Billing/Receiving_Report_November.xlsx")


 
 
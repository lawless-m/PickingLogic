
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

include("utils.jl")

using HIARP


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

@fid "prtmonth.df" begin
	df = byPrtMonth("2016", "10")
	for r in 1:size(df)[1]
		@printf fid "%s\t%s\t%d\t%d\n" df[:dy][r] df[:prtnum][r] df[:untqty][r] df[:untcas][r]
	end
end



 
 
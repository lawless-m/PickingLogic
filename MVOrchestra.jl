
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using HIARP
using Base.Dates
using DataFrames

include("utils.jl")

MVO = readtable("g:/Heinemann/MVOrchestra.tab.txt", separator='\t', eltypes=[UTF8String, UTF8String, Int64])

curr = FIFOStolocs(MVO[:Prtnum], :prtnum)

@fid "transfers/MVOrchestra_new_skus.txt" begin
	newSkus = size(setdiff(MVO[:Prtnum], collect(keys(curr))), 1)
	for prt in setdiff(MVO[:Prtnum], collect(keys(curr)))
		row = MVO[MVO[:Prtnum] .== prt, :]
		@printf fid "%s\t%s\t%d\n" prt row[:DESCRIPTION][1] row[:ORDERED][1]
	end
end
@fid "transfers/MVOrchestra_existing_skus.txt" begin
	@printf fid "Prtnum\tDescription\tNo ordered\tNext Fifo\tQty in FIFO\tNo. FIFOs\tQty in all FIFOs\tLast Ordered\n"
	for prt in intersect(collect(keys(curr)), MVO[:Prtnum])
		infifo = 0
		# reduce would be better but my attempt didn't work
		for i in 1:length(curr[prt])
			infifo += curr[prt][i].qty
		end
		loc = sort(curr[prt], lt=(x,y)->x.fifo<y.fifo)[1]
		# inv = @sprintf "%s\t%s\t%d\t%S" fst.stoloc fst.case_id fst.qty fst.fifo
		row = MVO[MVO[:Prtnum] .== prt, :]
		
		@printf fid "%s\t%s\t%d\t%s\t%d\t%d\t%d\t%S\n" loc.prtnum loc.descr row[:ORDERED][1] loc.stoloc loc.qty length(curr[prt]) infifo Date(prevOrders(prt)[1]) 
	end
end


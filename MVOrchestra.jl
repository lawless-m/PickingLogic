
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using HIARP

include("utils.jl")

MVOrchestra = @deserial("g:/Heinemann/MVOrchestra.jls")

prtnums = map(string, collect(keys(MVOrchestra)))

curr = FIFOStolocs(prtnums, :prtnum)

for prt in prtnums
	if haskey(curr, prt)
		locs = sort(curr[prt], lt=(x,y)->x.fifo<y.fifo)
		@printf "(%s) %s\n" locs[1].prtnum locs[1].descr
		for l in sort(curr[prt], lt=(x,y)->x.fifo<y.fifo)
			@printf "\t%s %s %d %S\n" l.stoloc l.case_id l.qty l.fifo
		end
	else
		println("$prt : Not In Storage")
	end
end


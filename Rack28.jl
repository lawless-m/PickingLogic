
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using HIARP

include("utils.jl")

skulocs, locskus, rackskus = skuLocations()

curr = currentStolocs()

function procLevel(fid, level, bins)
	for b in bins
		label = @sprintf "84-%s-%02d" level b
		if haskey(curr, label)
			sto = curr[label][1]
			@printf fid "%s\t(%s)\t%s\t[qty:%d]" label sto.prtnum sto.descr sto.qty
			if haskey(skulocs, i64(sto.prtnum))
				@printf fid "\t%s\n" skulocs[i64(sto.prtnum)][1]
			else
				@printf fid "\t?\n"
			end
		end
	end
end

@fid "Rack28_Moves.txt" begin
	@printf "Loc\tprtnum\tItem\tQty\tMove To\n"
	procLevel(fid, "20", 1:119)
	procLevel(fid, "20", 123:500)
	procLevel(fid, "30", 30:100)
	procLevel(fid, "30", 110:500)
	procLevel(fid, "40", 110:500)
end

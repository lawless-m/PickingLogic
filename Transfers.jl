
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using ExcelReaders
using Base.Dates
using HIARP

include("utils.jl")

i64(a::AbstractString) = a=="TBD" ? -1 : parse(Int64, a)

skulocs, locskus, rackskus = skuLocations()


function LIFOPick(lods::Vector{HIARP.Stoloc})
	domestics = ["89-", "91-", "92-"]
	pickable = filter((x)->!(x.stoloc[1:3] in domestics), lods)
	if size(pickable)[1] == 0
		return
	end
	if size(pickable)[1] == 1
		return pickable[1]
	end
	sort!(pickable, lt=(x,y)->x.fifo<y.fifo, rev=true)
	i = 2
	while i <= size(pickable)[1] && pickable[i].stoloc == pickable[1].stoloc
		pickable[1].qty += pickable[i].qty 
		i += 1
	end
	pickable[1]
end

function printLods(fn, rack, lods, curr, levels)
	@fidA fn for bin in 1:1:8, level in levels
		label = @sprintf "F-%s-%02d-%02d" rack level bin
		if haskey(curr, label)
			continue
		end
		if haskey(locskus, label) && haskey(lods, string(locskus[label]))
			prtnum = locskus[label]
			maxqty = skulocs[prtnum][2]
			lod = LIFOPick(lods[string(prtnum)])
			if lod == nothing
				lod = lods[string(prtnum)][1]
				@printf fid "%s\t%s\tqty:%d\tMax:%d\t(%s) %s\r\n" label "DOMESTIC" 0 maxqty prtnum lod.descr
			else
				@printf fid "%s\t%s\tqty:%d\tMax:%d\t(%s) %s\r\n" label lod.stoloc lod.qty maxqty prtnum lod.descr
			end
		end
	end
end
		
function procRacks(fn, levels)
	curr = DictVec(HIARP.Stoloc, :stoloc, HIARP.currentStolocs())
	for rack in sort(collect(keys(rackskus)))
		printLods(fn, rack, DictVec(HIARP.Stoloc, :prtnum, HIARP.FIFOStolocs(rackskus[rack])), curr, levels)
	end
end

function checkRacks()
	tfd = HIARP.rackFPrtnums()
	for r in 1:size(tfd)[1]
		loc = tfd[:stoloc][r]
		if haskey(locskus, loc) && string(locskus[loc]) != tfd[:prtnum][r]
			@printf "%s is %s, should be %s\n" loc tfd[:prtnum][r] locskus[loc]
		end
	end
end


j = 1
if j==1
	fn = "transfers/ALL-F.txt"
	close(open("G:/Heinemann/" * fn, "w+"))
elseif j==2
	fn = "transfers/A-F.txt"
	close(open("G:/Heinemann/" * fn, "w+"))
	procRacks(fn, [40 50 60])
elseif j==3
	checkRacks(locskus)
end




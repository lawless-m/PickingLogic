
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))


using ExcelReaders
using Base.Dates
using HIARP

include("utils.jl")


i64(a::AbstractString) = a=="TBD" ? -1 : parse(Int64, a)

skulocs, locskus, rackskus = skuLocations()
locLabels = collect(keys(locskus))

currStolocs = currentStolocs()
currLabels = collect(keys(currStolocs))

function FLabels(racks, bins, levels)
	[@sprintf("F-%s-%02d-%02d", r, l, b) for r in racks, b in bins, l in levels]
end

function printLods(fid, labels, lods)
	for label in labels
		if haskey(lods, string(locskus[label]))
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

function printBRItems(flt=(k,v)->true)
	items = filter(flt, HIARP.BRItems())
	for s in sort(collect(keys(items)))
		item = items[s][1]
		@printf "%s\t%d\t(%s)\t%s\n" item.stoloc item.qty item.prtnum item.descr
	end
end
		
function procRacks(fid, levels)
	for rack in sort(collect(keys(rackskus)))
		printLods(fid, intersect(locLabels, setdiff(FLabels([rack], 1:8, levels), currLabels)), FIFOStolocs(rackskus[rack], :prtnum))
	end
end

function checkRacks()
	tfd = rackFPrtnums()
	for r in 1:size(tfd)[1]
		loc = tfd[:stoloc][r]
		if haskey(locskus, loc) && string(locskus[loc]) != tfd[:prtnum][r]
			@printf "%s is %s, should be %s\n" loc tfd[:prtnum][r] locskus[loc]
		end
	end
end


j = 4
if j==1
	@fid "transfers/ALL-F.txt" procRacks(fid, [10:10:90; 91])
elseif j==2
	@fid "transfers/A-F.txt" procRacks(fid, [40 50 60])
elseif j==3
	checkRacks(locskus)
elseif j == 4
	function testerInNonTestBin(k, v)
		if v[1].descr[1:2] == "T "		
			if v[1].stoloc[1] == 'F'
				return true
			end
			if v[1].stoloc[7] == '-'
				return false
			end
			r, l, b =  map(x->parse(Int64,x), split(v[1].stoloc, '-'))
			if l < 9 && b > 55
				return false
			end
			if b > 25
				return false
			end
			return true
		end
		return false			
	end
	printBRItems(testerInNonTestBin)
end



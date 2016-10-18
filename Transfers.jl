
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using ExcelReaders
using Base.Dates
using HIARP

include("utils.jl")

i64(a::AbstractString) = a=="TBD" ? -1 : parse(Int64, a)

function skuLocationsXLS()
	skulocs = Dict{Int64, Tuple{AbstractString, Int64}}()
	locskus = Dict{AbstractString, Int64}()
	xl = readxlsheet("G:/Heinemann/Travel Sequence/P81 SKU Location R1.xlsx", "SKU Qty Loc")
	for r in 2:size(xl)[1]
		if typeof(xl[r, 3]) != DataArrays.NAtype
			continue
		end
		skulocs[Int64(xl[r, 1])] = (xl[r, 4], i64(xl[r, 2]))
		locskus[xl[r, 4]] = Int64(xl[r, 1])
	end
	skulocs, locskus
end

function rackSkus(skulocs)
	rks = Dict{AbstractString, Vector{Int64}}()
	for skuloc in skulocs
		loc = split(skuloc[2][1], "-")
		if loc[1] == "F"
			if !haskey(rks, loc[2])
				rks[loc[2]] = []
			end
			push!(rks[loc[2]], skuloc[1])
		end
	end
	rks
end

type Load
	fifo::DateTime
	area::AbstractString
	stoloc::AbstractString
	descr::AbstractString
	qty::Int64
	Load(f::DateTime, a::AbstractString, s::AbstractString, d::AbstractString, q::Int64) = new(f, a, s, d, q)
	Load(df, r) = new(df[:dte][r], df[:area][r], df[:stoloc][r], df[:dsc][r], df[:qty][r])
end

function printLods(rack, lods, locskus, skulocs)
	@fid "transfers/F-$rack.txt" for bin in 1:1:8, level in [91; 90:-10:10]
		label = @sprintf "F-%s-%02d-%02d" rack level bin
		if haskey(locskus, label) && haskey(lods, string(locskus[label]))
			prtnum = locskus[label]
			maxqty = skulocs[prtnum][2]
			prt = lods[string(prtnum)]
			lod = sortperm(prt, lt=(l1, l2)->l1.fifo<l2.fifo)[1]
			if prt[lod].stoloc[1] == 'F' || prt[lod].stoloc[1:3] in ("89-", "91-", "92-")
				continue
			end
			@printf fid "%s\t%s\t\t%d\tMaxQty:%d\r\n" label prt[1].descr prtnum maxqty
			@printf fid "%s\t%s\t%s\t%s\tqty:%d\r\n\r\n" level>30 && level <70 ? "DH" : "" prt[lod].area prt[lod].stoloc Date(prt[lod].fifo) prt[lod].qty
		end
	end
end

function printALods(rack, lods, locskus, skulocs)
	@fidA "transfers/A-F.txt" for bin in 1:1:8, level in 40:10:60
		label = @sprintf "F-%s-%02d-%02d" rack level bin
		if haskey(locskus, label) && haskey(lods, string(locskus[label]))
			prtnum = locskus[label]
			maxqty = skulocs[prtnum][2]
			prt = lods[string(prtnum)]
			lod = sortperm(prt, lt=(l1, l2)->l1.fifo<l2.fifo)[1]
			if prt[lod].stoloc[1] == 'F' || prt[lod].stoloc[1:3] in ("89-", "91-", "92-")
				continue
			end
			@printf fid "%s\t%s\t%s\t%d\tMaxQty:%d\r\n" label prt[1].descr prt[lod].area prtnum maxqty
			#@printf fid "\t%s\t%s\t%s\tqty:%d\r\n\r\n" prt[lod].area prt[lod].stoloc Date(prt[lod].fifo) prt[lod].qty
			@printf fid "\t\t%s\t\tqty:%d\r\n\r\n"  prt[lod].stoloc prt[lod].qty
		end
	end
end
		
function procRacks(skulocs, locskus, rackskus, printfn)
	for rack in sort(collect(keys(rackskus)))
		df = HIARP.LIFOStolocs(rackskus[rack])
		printfn(rack, DictVec(Load, :prtnum, df), locskus, skulocs)
	end
end

function checkRacks(locskus)
	tfd = HIARP.rackFPrtnums()
	for r in 1:size(tfd)[1]
		loc = tfd[:stoloc][r]
		if haskey(locskus, loc) && string(locskus[loc]) != tfd[:prtnum][r]
			@printf "%s is %s, should be %s\n" loc tfd[:prtnum][r] locskus[loc]
		end
	end
end

function deXLS(fn)
	s, l = skuLocationsXLS()
	r = rackSkus(skulocs)
	fid = open(fn, "w+")
	serialize(fid, (s, l, r))
	close(fid)
end

function skuLocations()
	skfn = "g:/Heinemann/skulocRacks.jls"
	if ! isfile(skfn)
		deXLS(skfn)
	end
	fid = open(skfn, "r")
	(s, l, r) = deserialize(fid)
	close(fid)
	s, l, r
end

skulocs, locskus, rackskus = skuLocations()

j = 2
if j==1
	procRacks(skulocs, locskus, rackskus, printLods)
elseif j==2
	procRacks(skulocs, locskus, rackskus, printALods)
elseif j==3
	checkRacks(locskus)
end




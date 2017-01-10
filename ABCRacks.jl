
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

error("different locs re-write needed, abort")

#using HIADB
using DataFrames
using HIARP

include("utils.jl")

type Velq
	qtr::AbstractString
	count::Int64
	Velq(q::AbstractString, c::Int64) = new(q, c)
	Velq(df::DataFrame, r::Int64) = new(df[:qtr][r], df[:cnt][r])
end

type SkuStore
	stoloc::AbstractString
	qty::Int64
	SkuStore(s::AbstractString, q::Int64) = new(s, q)
	SkuStore(df, r) = new(get(df[:stoloc][r]), get(df[:qty][r]))
end


skulocs, locskus, rackskus = skuLocations()
locLabels = collect(keys(locskus))

currStolocs = currentStolocs()
currLabels = collect(keys(currStolocs))

const skus = itemMaster()
const Prtnums = collect(keys(skus))
const PickCountsByQtr = DictVec(Velq, :prtnum, HIARP.orderFreqByQtr()) # prtnum => Vector{.qtr .count}
const PickCounts = HIARP.orderFreq() # prtnum => pickCount

pickCount(k) = haskey(PickCounts, k) ? PickCounts[k] : 0


const Ranks = begin
		ranks = Dict{AbstractString, Int64}() # prtnum => rank
		rank=0
		for vrank in sortperm(Prtnums, lt=(a, b)->pickCount(a)<pickCount(b), rev=true)
			rank += 1
			ranks[Prtnums[vrank]] = rank
		end
		ranks
	end

const Racks = begin
		r = Vector{AbstractString}()
		for rack in 1:19, level in 10:10:60, bin in 1:60
			push!(r, @sprintf "%02d-%02d-%02d" rack level bin)
		end
		r
	end


	
const LocRank =  Dict{AbstractString, Int64}([loc => haskey(locskus, loc) ? Ranks[locskus[loc]] : 0 for loc in Racks])

function printQtrs()
	#=
		print parts with most picked first, include each picks per quarter also
	=#
	@fid("g:/Heinemann/abc.txt", 
		for vrank in 1:size(Prtnums)[1]
			@printf fid "P%d\tPicks:%d\t%s\n" Ranks[Prtnums[vrank]] PickCounts[Prtnums[vrank]] skus[Prtnums[vrank]]
			for v in PickCountsByQtr[Prtnums[vrank]]
				@printf fid "\t%s\t%d\n" v.qtr v.count
			end
		end
	)
end

function printRankLocs(fid)
	#=
		print locations and various ranks
	=#
	for loc in sort(Racks)
		if LocRank[loc] > 0
			@printf fid "%s - Visits:%#2d - %s (%#2.2f)\n" loc pickCount(locskus[loc]) @class(LocRank[loc]) 100LocRank[loc]/size(Prtnums)[1]
		else
			@printf fid "%s - noSKU\n" loc
		end
	end
end

function pickCountFreqs()
	maxCnt = max(collect(values(PickCounts))...)
	pickFreqs = zeros(Int64, maxCnt+1) # [freq+1]=count
	for prtnum in collect(keys(skus))
		pickFreqs[pickCount(prtnum)+1] += 1
	end
	pickFreqs
end

function printPickCountFreqs(fid, pickFreqs) # for barchart
	begin
		@printf fid "Freq\tCount\n"
		for cnt in 1:size(pickFreqs)[1]
			@printf fid "%d\t%d\n" cnt-1 pickFreqs[cnt]
		end
	end
end

function rankRacks(fid)
	shelves = Dict{AbstractString, Int64}()
	for rack in 1:19, level in 10:10:60
		shelves[@sprintf "%02d-%02d" rack level] = sum([LocRank[@sprintf "%02d-%02d-%02d" rack level bin] for bin in 1:60])
	end
	sortshelf = collect(keys(shelves))
	for shelf in sortperm(sortshelf, lt=(a, b)->shelves[a]<shelves[b])
		@printf fid "%s\t%d\n" sortshelf[shelf] shelves[sortshelf[shelf]]
	end
end



#@fid "g:/Heinemann/pickCountFreqs.txt" printPickCountFreqs(fid, pickCountFreqs())
@fid "stoloc_visits.txt" printRankLocs(fid)
#@fid "g:/Heinemann/shelfRanks.txt" rankRacks(fid)



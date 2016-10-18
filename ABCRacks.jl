
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using HIADB

include("utils.jl")

type Velq 
	year::Int64
	quarter::Int64
	count::Int64
	Velq(y::Int64, q::Int64, c::Int64) = new(y, q, c)
	Velq(df, r) = new(get(df[:yr][r]), get(df[:qtr][r]), get(df[:cnt][r]))
end

type SkuStore
	stoloc::AbstractString
	qty::Int64
	SkuStore(s::AbstractString, q::Int64) = new(s, q)
	SkuStore(df, r) = new(get(df[:stoloc][r]), get(df[:qty][r]))
end

const SKUs = HIADB.SKUs()
const Prtnums = collect(keys(SKUs))
const PickCountsByQtr = i64DictVec(Velq, :prtnum, HIADB.pickCountsByQtr()) # prtnum => Vector{.year .quarter .count}
const PickCounts = HIADB.pickCounts() # prtnum => pickCount
const SkuStorage = i64DictVec(SkuStore, :prtnum, HIADB.SKUsInStorage())# prtnum => Vector{.stoloc .qty}
const LocSkus = begin
		ls = Dict{AbstractString, Int64}()
		for p in collect(keys(SkuStorage)), l in SkuStorage[p]
			ls[l.stoloc] = p
		end
		ls
	end

pickCount(k) = haskey(PickCounts, k) ? PickCounts[k] : 0

const Ranks = begin
		ranks = Dict{Int64, Int64}() # prtnum => rank
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
	
const LocRank =  Dict{AbstractString, Int64}([loc => haskey(LocSkus, loc) ? Ranks[LocSkus[loc]] : 0 for loc in Racks])

function printQtrs()
	#=
		print parts with most picked first, include each picks per quarter also
	=#
	@fid("g:/Heinemann/abc.txt", 
		for vrank in 1:size(Prtnums)[1]
			@printf fid "P%d\tPicks:%d\t%s\n" Ranks[Prtnums[vrank]] PickCounts[Prtnums[vrank]] SKUs[Prtnums[vrank]]
			for v in PickCountsByQtr[Prtnums[vrank]]
				@printf fid "\t%d/%d\t%d\n" v.year v.quarter v.count
			end
		end
	)
end

function printRankLocs()
	#=
		print locations and various ranks
	=#
	@fid "g:/Heinemann/stoloc_visits.txt" for loc in sort(Racks)
		if LocRank[loc] > 0
			@printf fid "%s - Visits:%#2d - %s (%#2.2f)\n" loc pickCount(LocSkus[loc]) @class(LocRank[loc]) 100LocRank[loc]/size(Prtnums)[1]
		else
			@printf fid "%s - noSKU\n" loc
		end
	end
end

function pickCountFreqs()
	maxCnt = max(collect(values(PickCounts))...)
	pickFreqs = zeros(Int64, maxCnt+1) # [freq+1]=count
	for prtnum in collect(keys(SKUs))
		pickFreqs[pickCount(prtnum)+1] += 1
	end
	pickFreqs
end

function printPickCountFreqs(pickFreqs) # for barchart
	@fid "g:/Heinemann/pickCountFreqs.txt"	begin
		@printf fid "Freq\tCount\n"
		for cnt in 1:size(pickFreqs)[1]
			@printf fid "%d\t%d\n" cnt-1 pickFreqs[cnt]
		end
	end
end

function rankRacks()
	shelves = Dict{AbstractString, Int64}()
	for rack in 1:19, level in 10:10:60
		shelves[@sprintf "%02d-%02d" rack level] = sum([LocRank[@sprintf "%02d-%02d-%02d" rack level bin] for bin in 1:60])
	end
	sortshelf = collect(keys(shelves))
	@fid "g:/Heinemann/shelfRanks.txt" for shelf in sortperm(sortshelf, lt=(a, b)->shelves[a]<shelves[b])
		@printf fid "%s\t%d\n" sortshelf[shelf] shelves[sortshelf[shelf]]
	end
end

printRankLocs()
rankRacks()



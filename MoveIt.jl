cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using HIADB
include("utils.jl")

const SKUs = HIADB.SKUs()
const Prtnums = collect(keys(SKUs))
const PickCounts = HIADB.pickCounts() # prtnum => pickCount

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
	
type Inv
	label::AbstractString
	fifoday::Int64
	prtnum::Int64
	lngdsc::AbstractString
	qty::Int64
	class::AbstractString
	Inv(l, f, p, d, q) = new(l, f, p, d, q)
	Inv(df, r) = new(get(df[:label][r]), i64(df[:fifoday][r]), i64(df[:prtnum][r]), get(df[:lngdsc][r]), i64(df[:qty][r]), @class(Ranks[i64(df[:prtnum][r])]))
end

df = SQLite.query(HIADB.DB, "
	WITH
	  Loc(label, location) AS (SELECT label, location FROM Locations WHERE label not like 'F%' and rack > 0 and rack < 20)
	, Sku(prtnum, fifoday, qty, lngdsc, location) AS (SELECT SKUs.prtnum, Inventory.fifoday, Inventory.qty, SKUs.lngdsc, Inventory.location FROM Inventory JOIN Skus ON Inventory.prtnum=SKUs.prtnum) 
	SELECT Loc.label as label, Sku.fifoday as fifoday , Sku.prtnum as prtnum, Sku.lngdsc as lngdsc, sum(Sku.qty) as qty FROM Loc JOIN Sku ON Loc.location=Sku.location
	GROUP BY label, prtnum, lngdsc, fifoday
")


locs = DictVec(Inv, :label, df)
prts = i64DictVec(Inv, :prtnum, df)

function sortloc(x, y)
	a = locs[x][1].class
	b = locs[y][1].class
	ca = replace(a, ['-', '+'], "")
	cb = replace(b, ['-', '+'], "")
	if ca != cb
		return ca < cb
	end
 
	if (s=search(a, ca[1])) == search(b, ca[1])
		return length(a) - s > length(b) -s
	end
	
	search(a, ca[1]) < search(b, ca[1])
end

function adj(prtnum, fifoday)
	j = prts[prtnum][1].class
	for invs in prts[prtnum]
		if invs.fifoday > fifoday
			j = j * "+"
		elseif invs.fifoday < fifoday
			j = "-" * j
		end
	end
	j
end

for l in collect(keys(locs))
	for k in 1:size(locs[l])[1]
		locs[l][k].class = adj(locs[l][k].prtnum, locs[l][k].fifoday)
	end
end

loclist = collect(keys(locs))

@fid "movelist.txt" for k in sortperm(loclist, lt=sortloc, rev=true)
	if search(locs[loclist[k]][1].class, 'B') > 0
		break
	end
	@printf fid "%s\t%d\t%s\t%d\t%s\t%d\n" loclist[k] locs[loclist[k]][1].fifoday locs[loclist[k]][1].class locs[loclist[k]][1].prtnum locs[loclist[k]][1].lngdsc sum([locs[loclist[k]][j].qty for j in 1:size(locs[loclist[k]])[1]])
end


@fid "moveCs.txt" for k in sortperm(loclist, lt=sortloc, rev=true)
	if search(locs[loclist[k]][1].class, 'B') > 0
		break
	end
	@printf fid "%s\t%d\t%s\t%d\n" loclist[k] sum([locs[loclist[k]][j].qty for j in 1:size(locs[loclist[k]])[1]]) locs[loclist[k]][1].lngdsc locs[loclist[k]][1].prtnum 
end

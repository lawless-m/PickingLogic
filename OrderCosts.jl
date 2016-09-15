
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using SQLite
using CoOccur

macro denull(T, data, col)
	:($T[get(x) for x in $data[$col]])
end

function denull(T, sql::AbstractString, col)
	@denull(T, SQLite.query(DB, sql), col)
end

function i64(sql::AbstractString, col)
	@denull(Int64, SQLite.query(DB, sql), col)
end

macro dictCols(sql, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		data = SQLite.query(DB, $sql)
		dct = Dict{eltype(data[$ks][1]), eltype(data[$vs][1])}()
		for k in 1:size(data)[1]
			dct[get(data[$ks][k])] = get(data[$vs][k])
		end
		dct
	end
end


function orders()
	for o in i64("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		locs = i64("SELECT SKUs.location FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY SKUs.location DESC", :location)
		if size(locs)[1] > 0
			produce(o, locs)
		end
	end
end

function distance(l1, l2)
	@denull(Float64, SQLite.query(DB, "SELECT distance FROM Distances WHERE lmin=? AND lmax=?", values=[min(l1, l2), max(l1, l2)]), :distance)[1]
end

function orderCost(pipe)
	for (o, locs) in pipe
		d = 0
		s = locs[1]
		for l in locs[2:end]
			d += distance(s, l)
			s = l
		end
		println("order $o distance $d")
	end
end

orderCost(Task(orders))

fillOccurrences!()
println(clusterize(14))


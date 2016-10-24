
macro push!(d, k, v)
	return quote
		if !haskey($d, $k)
			$d[$k] = valtype($d)()
		end
		push!($d[$k], $v)
	end
end

macro iif(bl)
	return quote                                    
		if !$bl                      
			return
		end                       
	end                           
end

macro sheet(fn, sht) 
	return quote
		f = [filter(d->isfile(d*$fn),["G:/Heinemann/" "G:/RedPrarie/" ""]); ""][1] * $fn
		f=="" ? println("Not Found: " * $fn) : println(f); readxlsheet(f, $sht)
	end
end

function sheet(sht) 
	@sheet(sht*".xls", sht)
end


macro fid(fn, blk)
	return quote
		if $fn[2] == ":"
			fid = open($fn, "w+")
		else
			fid = open("G:/Heinemann/" * $fn, "w+")
		end
		$blk
		close(fid)
	end
end

macro fidA(fn, blk)
	return quote
		fid = open($fn[2] == ":" ? $fn : "G:/Heinemann/" * $fn, "a+")
		$blk
		close(fid)
	end
end

macro dena(x)
	:(typeof($x) == DataArrays.NAtype ? "":$x)
end

i64(a::Nullable{Int64}) = get(a)
i64(a::Float64) = round(Int64, a)
i64(a::AbstractString) = isnull(tryparse(Int64, a)) ? 0 : parse(Int64, a) 

macro denull(T, data, col)
	:($T[Base.get(x) for x in $data[$col]])
end

function DictVec(T, k, df)
	dd = Dict{AbstractString, Vector{T}}() # AbstractString => Vector{T}
	for r in 1:size(df[1])[1]
		@push!(dd, df[k][r], T(df, r))
	end	
	dd
end

function i64DictVec(T, k, df)
	dd = Dict{Int64, Vector{T}}() # Int64 => Vector{T}
	for r in 1:size(df[1])[1]
		@push!(dd, i64(df[k][r]), T(df, r))
	end	
	dd
end

macro class(pc)
	:($pc/size(Prtnums)[1] < 0.1 ? "A" : $pc/size(Prtnums)[1] < 0.2 ? "B" : "C") 
end

function iday(txt)
	d = Date(txt, "m/d/y")
	10000Dates.year(d) + 100Dates.month(d) + Dates.day(d)
end

function ttime(txt)
	dt = DateTime(txt, "m/d/y H:M:S")
	if txt[end-1:end] == "PM"
		dt += Dates.Hour(12)
	end
	Dates.format(dt, "HH:MM:SS")
end

macro trans(blk)
	return quote
	SQLite.execute!(DB, "BEGIN")
	$blk
	SQLite.execute!(DB, "COMMIT")
	end
end

macro query!(stmt, binds)
	return quote
		for i in 1:length($binds)
			SQLite.bind!($stmt, i, $binds[i])
		end
		SQLite.execute!($stmt)
	end
end

function denull(T, sql::AbstractString, col)
	@denull(T, SQLite.query(DB, sql), col)
end

function i64(sql::AbstractString, col)
	@denull(Int64, SQLite.query(DB, sql), col)
end

macro dictColsSQL(sql, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		data = SQLite.query(DB, $sql)
		dct = Dict{eltype(data[$ks][1]), eltype(data[$vs][1])}()
		for k in 1:size(data)[1]
			dct[Base.get(data[$ks][k])] = isnull(data[$vs][k]) ? "" : Base.get(data[$vs][k])
		end
		dct
	end
end

macro dictCols(df, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		dct = Dict{eltype($df[$ks]), eltype($df[$vs])}()
		for k in 1:size($df)[1]
			dct[$df[$ks][k]] = $df[$vs][k]
		end
		dct
	end
end

macro serialize(fn, v)
	return quote
		fid = open($fn, "w+")
		serialize(fod, $v)
		close(fid)
	end
end

macro deserial(fn)
	return quote
		fid = open($fn, "r+")
		v = deserialize(fid)
		close(fid)
		v
	end
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

function deXLS(fn)
	s, l = skuLocationsXLS()
	r = rackSkus(skulocs)
	fid = open(fn, "w+")
	serialize(fid, (s, l, r))
	close(fid)
end


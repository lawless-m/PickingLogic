#=

generate the cooccurence matrix of our orders

https://en.wikipedia.org/wiki/Co-occurrence_matrix

reduce dimensionality
do this using 
https://github.com/JuliaStats/MultivariateStats.jl

http://multivariatestatsjl.readthedocs.io/en/latest/index.html

e.g.

https://en.wikipedia.org/wiki/Principal_component_analysis



use these as groupings for clustering

http://clusteringjl.readthedocs.io/en/latest/kmeans.html




=#

cd(ENV["USERPROFILE"] * "/Documents")

using SQLite
using Clustering
using MultivariateStats

db = SQLite.DB("Databases/HIA_Orders.sqlite")

macro denull(data, col)
	:([get(x) for x in $data[$col]])
end

macro denullSQL(sql, col)
	:(@denull(SQLite.query(db, $sql), $col))
end

macro dictCols(sql, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		data = SQLite.query(db, $sql)
		dct = Dict{eltype(data[$ks][1]), eltype(data[$vs][1])}()
		for k in 1:size(data)[1]
			dct[get(data[$ks][k])] = get(data[$vs][k])
		end
		dct
	end
end
			

macro vsort(d) # dictionary keys sorted by the values
	:(sort(collect(keys($d)), lt=(v1, v2)->$d[v1]<$d[v2]))
end

const parts = @denullSQL("SELECT prtnum FROM SKUs WHERE location IS NOT NULL ORDER BY prtnum", :prtnum)

function occurs()
	occur = zeros(Float32, size(parts)[1], size(parts)[1])

	function procOrder(order)
		for p in 1:size(parts)[1]
			if parts[p] in order
				for q in 1:size(parts)[1]
					if parts[q] in order
						occur[p, q] += 1 
						occur[q, p] += 1 					
					end
				end
			end
		end
	end
	
	for o in @denullSQL("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		procOrder(@denullSQL("SELECT DISTINCT prtnum FROM OrderLine WHERE ordnum=$o ORDER BY prtnum",:prtnum))
	end
	
	for k in 1:size(parts)[1] # is this appropriate ? self correlation zero or should it be maximum ?
		occur[k, k] = 0
	end
	
	return occur
end

function reduceDim(occ, dims)
	projection(fit(PCA, occ; maxoutdim=dims))
end

function clusters(occ, k=14)
	R = kmeans(occ, k; maxiter=200)
	A = assignments(R)
	d = Vector{Vector{Int64}}(k)
	for i in 1:k
		d[i] = []
	end
	
	for i in 1:size(A)[1]
		push!(d[A[i]], parts[i])
	end
	
	return d
end

function velocity()
	# dictionary keys of partnumbers sorted by number of times picked
	counts = @dictCols("SELECT prtnum, COUNT(prtnum) AS cnt FROM OrderLine GROUP BY prtnum", :prtnum, :cnt)
	order = @vsort(counts)
	(counts, order)
end

function writeCluster(fn, assignments)
	for v in assignments
		@printf fn "%d" v[1] # cluster no.
		for p in v[2:end]
			@printf fn "\t%d" p # part no.s
		end
		@printf fn "\r\n"
	end
end

function writeOccurs(fn, occ)
	o = open("$fn.txt", "w+")
	for i in 1:size(parts)[1]
		@printf o "\t%s" parts[i]
	end
	@printf o "\r\n"
	for i in 1:size(parts)[1]
		@printf o "%s" parts[i]
		for k in 1:size(parts)[1]
			@printf o "\t%s" occ[i, k]
		end
		@printf o "\r\n"
	end
	close(o)
end

#clusters(occurs()))

println(velocity())




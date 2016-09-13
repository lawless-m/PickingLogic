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

using SQLite
using Clustering
using MultivariateStats 

db = SQLite.DB("G:\\Heinemann\\HIA_Orders.sqlite")

macro denull(sql, col)
	:([get(x) for x in SQLite.query(db, $sql)[$col]])
end

const parts = @denull "select prtnum from SKUs order by prtnum" :prtnum

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
	
	for o in @denull "select distinct ordnum from OrderLine order by ordnum" :ordnum
		procOrder(@denull "select distinct prtnum FROM OrderLine WHERE ordnum=$o order by prtnum" :prtnum)
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

clusters(occurs()))

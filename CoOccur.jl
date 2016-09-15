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
module CoOccur


using SQLite
using Clustering
using MultivariateStats


function denull(data, col)
	[get(x) for x in data[col]]
end

function denull(sql::AbstractString, col)
	denull(SQLite.query(DB, sql), col)
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

macro vsort(d) # dictionary keys sorted by the values
	:(sort(collect(keys($d)), lt=(v1, v2)->$d[v1]<$d[v2]))
end

function fillOccurrences!()
	function procOrder(order)
		for i in 1:size(order)[1]
			p = searchsorted(PARTS, order[i])
			for k in i+1:size(order)[1]
				q = searchsorted(PARTS, order[k])[1]
				OCCURRENCE[p, q] += 1 
				OCCURRENCE[q, p] += 1 	
			end
		end
	end
	
	for o in denull("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		procOrder(denull("SELECT DISTINCT OrderLine.prtnum FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY OrderLine.prtnum", :prtnum))
	end
end

function reduceDim(dims)
	projection(fit(PCA, OCCURRENCE; maxoutdim=dims))
end

function kclusters(k)
	cs = Vector{Vector{Int64}}(k)
	R = kmeans(OCCURRENCE, k; maxiter=200)
	A = assignments(R)
	for i in 1:k
		cs[i] = []
	end
	
	for i in 1:NUMPARTS
		push!(cs[A[i]], PARTS[i])
	end
	cs
end

function velocityDict()
	# dictionary keys of partnumbers sorted by number of times picked
	
	#order = @vsort(ans)
end

function clusterVelocities(clus)
	v = zeros(Float64, size(clus)[1])
	for k in 1:size(clus)[1]	
		for p in clus[k]
			v[k] += VELOCITIES[p]
		end
	end
	v
end

function printSortedClusters(clusters)
	velocities = clusterVelocities(clusters)
	for k in sortperm(velocities)
		@printf "%d\t" velocities[k]
		println(clusters[k])
	end
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

function writeOccurs(fn)
	o = open("$fn.txt", "w+")
	for i in 1:NUMPARTS
		@printf o "\t%s" PARTS[i]
	end
	@printf o "\r\n"
	for i in 1:NUMPARTS
		@printf o "%s" PARTS[i]
		for k in 1:NUMPARTS
			@printf o "\t%s" OCCURRENCE[i, k]
		end
		@printf o "\r\n"
	end
	close(o)
end

function clusterize(k)
	clusters = kclusters(k)
	clusters, clusterVelocities(clusters)
end


const DB = SQLite.DB("Databases/HIA_Orders.sqlite")
const PARTS = denull("SELECT DISTINCT SKUs.prtnum FROM OrderLine, SKUs where OrderLine.prtnum = SKUs.prtnum and SKUs.location IS NOT NULL ORDER BY SKUs.prtnum", :prtnum)
const NUMPARTS = size(PARTS)[1]
const VELOCITIES = @dictCols("SELECT prtnum, COUNT(prtnum) AS cnt FROM OrderLine GROUP BY prtnum", :prtnum, :cnt)
const OCCURRENCE = zeros(Float32, NUMPARTS, NUMPARTS) 
export DB, fillOccurrences!, clusterize

end






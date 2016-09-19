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

using HIADB
using Clustering
using MultivariateStats

macro vsort(d) # dictionary keys sorted by the values
	:(sort(collect(keys($d)), lt=(v1, v2)->$d[v1]<$d[v2]))
end

function fillOccurrences!()
	for o in HIADB.orderNumbers()
		partnums = HIADB.partnumsInRackPerOrder(o)
		for i in 1:size(partnums)[1]
			p = searchsorted(PARTS, partnums[i])
			for k in i+1:size(partnums)[1]
				q = searchsorted(PARTS, partnums[k])[1]
				OCCURRENCE[p, q] += 1 
				OCCURRENCE[q, p] += 1 	
			end
		end
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

function printSortedClusters(clusters, sortby)
	for k in sortperm(sortby)
		@printf "%d\t" sortby[k]
		println(clusters[k])
	end
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


const PARTS = HIADB.partnumsInRacks()
const NUMPARTS = size(PARTS)[1]
const VELOCITIES = HIADB.partVelocities()
const OCCURRENCE = zeros(Float32, NUMPARTS, NUMPARTS) 
export fillOccurrences!, clusterize, kclusters, clusterVelocities, printSortedClusters

end


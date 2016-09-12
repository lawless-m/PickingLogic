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

using ExcelReaders
using Clustering
using MultivariateStats 


function procXLS()
	

	xl = readxlsheet("g:/Heinemann/ord_line_raw_data.xlsx", "LextEdit Export 08-24-16 02.28")

	parts = unique(sort([parse(Int64, x) for x in xl[2:end, 4]]))
	occur = zeros(Float32, length(parts), length(parts))

	function procOrder(order)
		if length(order) == 0
			return
		end
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
	
	prevord = 0
	ordparts = Set{Int64}()
	for d in 2:size(xl)[1] # first row is headers
		ordnum = parse(xl[d, 2]) # column 2
		prtnum = parse(xl[d, 4]) # column 4
		if prevord != ordnum
			procOrder(ordparts)
			ordparts = Set{Int64}()
			prevord = ordnum
		end
		push!(ordparts, prtnum)
	end

	procOrder(ordparts)
	
	for k in 1:size(parts)[1] # is this appropriate ? self correlation zero or should it be maximum ?
		occur[k, k] = 0
	end

	serialize(open("parts.jls", "w+"), parts)
	serialize(open("occur.jls", "w+"), occur)
	
	return parts, occur
end

function loadIt()
	return deserialize(open("parts.jls", "r")), deserialize(open("occur.jls", "r"))
end

function reduceDim(occ)
	
	M = fit(PCA, occ; maxoutdim=30)
	projs = projection(M)

end

function cluster(parts, occ)
	R = kmeans(occ, 14; maxiter=200)
	A = assignments(R)
	d = Dict{Int64, Int32}()
	for i in 1:size(A)[1]
		d[parts[i]]=A[i]
	end
	return d
end

function writeCluster(fn, assignment)
	for a in assignment
		@printf fn "%d\t%d\r\n" a[1] a[2]
	end
end

writeCluster(open("cluster.txt", "w+"), cluster(procXLS()...))





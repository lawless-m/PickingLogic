
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

include("utils.jl")
using CoOccur
using Bay2Bay_Costs

#=

function orderCost(pipe)
	for (o, locs) in pipe
		d = 0
		s = locs[1]
		for l in locs[2:end]
			d += HIADB.distanceByLocation(s, l)
			s = l
		end
		println("order $o distance $d")
	end
end

function ordersInRacksTask()
	for o in i64("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		locs = i64("SELECT DISTINCT SKUs.location FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY SKUs.location DESC", :location)
		if size(locs)[1] > 0
			produce(o, locs)
		end
	end
end
orderCost(Task(HIADB.ordersInRacksTask))
=#

@time fillOccurrences!()
if isfile("g:/Heinemann/CoOccur.jls")
	CoOccur.loadOccurrences!("g:/Heinemann/CoOccur.jls")
else
	@serialise("g:/Heinemann/CoOccur.jls", CoOccur.OCCURRENCE)
end

clusters = kclusters(14)
velocity = clusterVelocities(clusters)
printSortedClusters(clusters, [velocity[k] / size(clusters[k])[1] for k in 1:size(clusters)[1]])


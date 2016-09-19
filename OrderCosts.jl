
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using CoOccur
using Bay2Bay_Costs


function orderCost(pipe)
	for (o, locs) in pipe
		d = 0
		s = locs[1]
		for l in locs[2:end]
			d += distanceByLocation(s, l)
			s = l
		end
		println("order $o distance $d")
	end
end

#orderCost(Task(ordersInRacks))

@time fillOccurrences!()
clusters = kclusters(14)
velocity = clusterVelocities(clusters)
printSortedClusters(clusters, [velocity[k] / size(clusters[k])[1] for k in 1:size(clusters)[1]])



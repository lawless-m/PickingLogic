module Bay2Bay_Costs

#=
create grid for excel to view
=#
				
const toEnd = [24, 16, 8, 0, 8, 16]

macro one2six(n)
	:(1+mod($n-1, 6))
end

macro aisle(rack) # e.g 4:9
	:(floor(Int, 1+(($rack+2)/6)))
end

macro fore_aft(rack) # F 4-5-6 A 1-2-3
	:(mod($rack-1, 6)+1 > 3 ? 'F' : 'A')
end

macro bin2bin(b1, b2)
	:(abs($b1 - $b2))
end

macro n1to100(v) 
	:($v == 91 ? 100 : $v)
end

macro level2level(l1, l2)
	:(abs(@n1to100($l1) - @n1to100($l2)) / 100)
end

macro endDist(r, b)
	:(toEnd[@one2six($r)] - (@fore_aft($r) == 'A' ? $b : $b-8))
end

macro aisle2aisle(r1, r2)
	:(8abs(@aisle($r1) - @aisle($r2)))
end

macro sameAisle(r1, r2)
	:(@aisle($r1) == @aisle($r2))
end

function distance(r1, b1, l1, r2, b2, l2)
	if r1 == r2
		if b1 == b2
			return @level2level(l1, l2)
		end
		return @bin2bin(b1, b2)
	end
	
	if @sameAisle(r1, r2)
		return abs(@endDist(r1, b1) - @endDist(r2, b2))
	end
	
	return @endDist(r1, b1) + @aisle2aisle(r1, r2) + @endDist(r2, b2)
end

function writeExcel(fn)
	tab = open(fn, "w")
	for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
		@printf tab "\tF-%02d-%02d-%02d" rackH levelH binH
	end
	@printf tab "\n"
	for rackV in 81:-1:1, binV in 8:-1:1, levelV in [10:10:90; 91]
		@printf tab "F-%02d-%02d-%02d" rackV levelV binV
		for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
			@printf tab "\t%0.2f" distance(rackV, binV, levelV, rackH, binH, levelH)
		end
		@printf tab "\n"
	end
	close(tab)
end

function writePGM(R, B, L)
	img = open("PathingMap_$(R)_$(B)_$(L).pgm", "w")
	@printf img "P2 %d %d 150\n" 24 27
	for r1 in 0:6:79
		for rr in [3:-1:1; 4:6] 
			if rr == 4
				@printf img "\n"
			end
			rack = r1 + rr
			if rack > 81
				break
			end
			for k in 1:8
				@printf img "%03d " distance(R, B, L, rack, 9-k, L)
			end
		end
		@printf img "\n\n"
	end	
	close(img)
end


end

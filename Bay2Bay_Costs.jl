module Bay2Bay_Costs

export aisle

#=
create grid for excel to view
=#
				
const toEnd = [24, 16, 8, 0, 8, 16]

one2six(n) = 1+mod(n-1, 6)
aisle(rack) = floor(Int, 1+((rack+2)/6))
fore_aft(rack) = mod(rack-1, 6)+1 > 3 ? 'F' : 'A' # F 4-5-6 A 1-2-3
bin2bin(b1, b2) = abs(b1 - b2)
n1to100(v) = v == 91 ? 100 : v
level2level(l1, l2) = abs(n1to100(l1) - n1to100(l2)) / 100
endDist(r, b) = toEnd[one2six(r)] - (fore_aft(r) == 'A' ? b : b-8)
aisle2aisle(r1, r2) = 8abs(aisle(r1) - aisle(r2))
sameAisle(r1, r2) = aisle(r1) == aisle(r2)
label(r, l, b) = @sprintf "F-%02d-%02d-%02d" r l b

function distance(r1, l1, b1, r2, l2, b2)
	if r1 == r2
		if b1 == b2
			return level2level(l1, l2)
		end
		return bin2bin(b1, b2)
	end
	
	if sameAisle(r1, r2)
		return abs(endDist(r1, b1) - endDist(r2, b2))
	end
	
	return endDist(r1, b1) + aisle2aisle(r1, r2) + endDist(r2, b2)
end

function writeExcel(fn)
	tab = open(fn, "w")
	for rackH in 81:-1:1, levelH in [10:10:90; 91], binH in 8:-1:1
		@printf tab "\t%s" label(rackH, levelH, binH)
	end
	@printf tab "\n"
	for rackV in 81:-1:1, levelV in [10:10:90; 91], binV in 8:-1:1
		@printf tab "%s" label(rackV, levelV, binV)
		for rackH in 81:-1:1, levelH in [10:10:90; 91], binH in 8:-1:1
			@printf tab "\t%0.2f" distance(rackV, levelV, binV, rackH, levelH, binH)
		end
		@printf tab "\n"
	end
	close(tab)
end

function writePGM(R, L, B)
	img = open("PathingMap_$(label(R, L, B)).pgm", "w")
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
				@printf img "%03d " distance(R, L, B, rack, L, 9-k)
			end
		end
		@printf img "\n\n"
	end	
	close(img)
end


end

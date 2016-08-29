#=
create grid for excel to view
=#

tab = open("Bay2Bay.txt", "w")
@printf tab "\t"
for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
	@printf tab "F-%02d-%02d-%02d\t" rackH levelH binH
end
@printf tab "\n"

macro pcon(str)
	return quote
		write(tab, $str)
		continue
	end
end

function aisle(rack) # e.g 4:9
	floor(Int, 1+((rack+2)/6))
end

function fore_aft(rack) # F 4-5-6 A 1-2-3
	mod(rack-1, 6)+1 > 3 ? 'F' : 'A'
end

n1to100(v) = v == 91 ? 100 : v

inAisleDists = [0 1 1 2 2 1
			  1 0 1 2 2 1
 			  1 1 0 1 1 1
			  2 2 1 0 1 1
			  2 2 1 1 0 1
			  1 1 1 1 1 0]
			  
for rackV in 81:-1:1, binV in 8:-1:1, levelV in [10:10:90; 91]
	@printf tab "F-%02d-%02d-%02d" rackV levelV binV
	for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
		@printf tab "\t"
		
		# SAME RACK
		if rackV==rackH
			if binH == binV
				@pcon @sprintf "A%0.2f" abs(n1to100(levelH) - n1to100(levelV)) / 100
			end
			@pcon @sprintf "B%d" abs(binH - binV)
		end
		
		#SAME AISE
		if aisle(rackV) == aisle(rackH)	
			@pcon @sprintf "D%d" 8inAisleDists[1+mod(rackV, 6), 1+mod(rackH, 6)]+(binV-binH)
		end
		
		#SAME FORE/AFT
		if fore_aft(rackV) == fore_aft(rackH)
			ad = abs(aisle(rackV) - aisle(rackH))
			@pcon @sprintf "E%d" 8ad
		end
		
	end
	@printf tab "\n"
end

close(tab)


#=
create grid for excel to view
=#

using Formatting

tab = open("PathingCosts.txt", "w")
img = open("PathingMap.pgm", "w")
dim = 0

macro pfn(fn, arg)
	return quote
		if typeof($arg) == ASCIIString
			printfmt($fn, "{:s}", $arg)
		else
			printfmt($fn, $arg[1], $arg[2:end]...)
		end
	end
end

macro ptab(arg)
	:(@pfn tab $arg)
end
macro pimg(arg)
	:(@pfn img $arg)
end


@ptab "\n"
for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
	dim += 1
	@ptab "F-{:02d}-{:02d}-{:02d}\t", rackH, levelH, binH
end
@ptab "\n"

@pimg "P5 {:d} {:d} 127", dim, dim

macro pcon(fmt)
	return quote
		@ptab $fmt
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
	@ptab "F-{:02d}-{:02d}-{:02d}", rackV, levelV, binV
	for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
		@ptab "\t"
		
		# SAME RACK
		if rackV==rackH
			if binH == binV
				@pcon "{:0.2f}", abs(n1to100(levelH) - n1to100(levelV)) / 100
			end
			@pcon "{:d}", abs(binH - binV)
		end
		
		#SAME AISE
		if aisle(rackV) == aisle(rackH)	
			@pcon "{:d}", 8inAisleDists[1+mod(rackV, 6), 1+mod(rackH, 6)]+(binV-binH)
		end
		
		#SAME FORE/AFT
		#if fore_aft(rackV) == fore_aft(rackH)
			ad = abs(aisle(rackV) - aisle(rackH))
			@pcon "{:d}", 8ad + (binV-binH) + 8inAisleDists[4, 1+mod(rackH, 6)]
		#end
		
	end
	@ptab "\n"
end

close(tab)
close(img)



type ST
	stoloc::AbstractString
	descr::AbstractString
end


tt = Dict{Int64, Vector{ST}}(1=>[ST("10-100-10", "T test100")], 2=>[ST("18-20-22", "T YSL Paris L0074300 EDPS")], 3=>[ST("F-01-01-01", "NormalF")], 4=>[ST("10-100-10", "Exist?")])


	function testerInNonTestBin(k, v)
		if v[1].stoloc[1] == 'F'
			println("F ", v[1])
			return false
		end
		if v[1].descr[1:2] == "T "
			if v[1].stoloc[7] == '-'
				println("- ", v[1])
				return false
			end
			println("T ", v[1])
			return true
		end
		println("N ", v[1])
		return false			
	end
	
	println(filter(testerInNonTestBin, tt))
	
	
	
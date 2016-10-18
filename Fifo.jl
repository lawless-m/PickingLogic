#cd(ENV["USERPROFILE"] * "/Documents")
#unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using FifoData

include("utils.jl")
# same ldnum diff : prt, whid, caseid
# same prt   diff : case, lodnum, whid
# same whid  diff : prt, case, lodnum, 
# same case  same lodnum, diff : whid, prt


function whidlodnum()
	whlods = Dict{AbstractString, AbstractString}()
	for (lodnum, info) in FIFO
	
	end
end


@fid "g:/Heinemann/fifo.txt" for (stoloc, prts) in LOCWH
	@printf fid "%s\n" stoloc
	for (prtnum, locwhid) in prts
		if locwhid == ""
			continue
			for (lodnum, casenum, fifoday, fifotime, qty, whid) in FIFO[prtnum]
				@printf fid "\t%d\t%s\t%s\t%s\t%s\t%s\n" prtnum lodnum casenum fifoday fifotime qty
			end
		else
			for (lodnum, casenum, fifoday, fifotime, qty, whid) in FIFO[prtnum]
				if locwhid == whid
					@printf fid "\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n" prtnum lodnum casenum fifoday fifotime qty whid
				end
			end
		end
	end
end

	


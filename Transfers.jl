
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))


using ExcelReaders
using Base.Dates
using HIARP

include("utils.jl")


i64(a::AbstractString) = a=="TBD" ? -1 : parse(Int64, a)

skulocs, locskus, rackskus = skuLocations()
locLabels = collect(keys(locskus))

currStolocs = currentStolocs()
currLabels = collect(keys(currStolocs))

function FLabels(racks, bins, levels)
	[@sprintf("F-%02d-%02d-%02d", r, l, b) for r in racks, b in bins, l in levels]
end

function BLabels()
	[ []
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 1:8, l in 10:10:60, b in [1:24; 31:55]])
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 9:19, l in 10:10:60, b in 1:25] 	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 2:3, l in 70:70, b in [1:24; 31:55]]  	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 4:4, l in 70:70, b in [17:24; 31:55]] )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 5:7, l in 70:70, b in 31:55]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 8:11, l in 70:70, b in 1:24]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 13:13, l in 70:70, b in 1:8]  )
	
	]
end

function chanelLabels()
	[ []
	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 15:15, l in [120; 140], b in 1:90]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 15:15, l in [130], b in 1:120]  )

	]

end

function printLods(fid, labels, lods)
	for label in labels
		if haskey(lods, string(locskus[label]))
			prtnum = locskus[label]
			maxqty = skulocs[prtnum][2]
			lod = FIFOPick(lods[string(prtnum)])
			if lod == nothing
				lod = lods[string(prtnum)][1]
				@printf fid "%s\t%s\tqty:%d\tMax:%d\t(%s) %s\r\n" label "DOMESTIC" 0 maxqty prtnum lod.descr
			else
				@printf fid "%s\t%s\tqty:%d\tMax:%d\t(%s) %s\r\n" label lod.stoloc lod.qty maxqty prtnum lod.descr
			end
		end
	end
end

function testerInNonTestBin(k, v)
	if v[1].descr[1:2] == "T "		
		if v[1].stoloc[1] == 'F'
			return true
		end
		if v[1].stoloc[7] == '-'
			return false
		end
		r, l, b =  map(x->parse(Int64,x), split(v[1].stoloc, '-'))
		if l < 9 && b > 55
			return false
		end
		if b > 25
			return false
		end
		return true
	end
	return false			
end

function printBRItems(fid, flt=(k,v)->true)
	items = filter(flt, HIARP.BRItems())
	for s in sort(collect(keys(items)))
		item = items[s][1]
		@printf fid "%s\t%d\t(%s)\t%s\n" item.stoloc item.qty item.prtnum item.descr
	end
end
		
function procRacks(fid, levels)
	for rack in sort(collect(keys(rackskus)))
		printLods(fid, intersect(locLabels, setdiff(FLabels([rack], 1:8, levels), currLabels)), FIFOStolocs(rackskus[rack], :prtnum))
	end
end

function checkRacks()
	tfd = rackFPrtnums()
	for r in 1:size(tfd)[1]
		loc = tfd[:stoloc][r]
		if haskey(locskus, loc) && string(locskus[loc]) != tfd[:prtnum][r]
			@printf "%s is %s, should be %s\n" loc tfd[:prtnum][r] locskus[loc]
		end
	end
end

function bakerStatus(fid, labels)
	empty = 0
	exist = 0
	testers = 0
	for label in sort(labels)
		exist += 1
		if haskey(currStolocs, label)
			item = currStolocs[label][1]
			@printf fid "%s\t(%s) %s\t%d\n" label item.prtnum item.descr item.qty
			if item.descr[1:2] == "T "
				testers += 1
			end
		else
			empty += 1
			@printf fid "%s\tEMPTY\n" label
		end
	end
	@printf fid "Testers: %d / %d = %d%%\n" testers exist round(100testers/exist)
	@printf fid "Empty: %d / %d = %d%%\n" empty exist round(100empty/exist)
end

j = 8
if j==1
	@fid "transfers/ALL-F.txt" procRacks(fid, [10:10:90; 91])
elseif j==2
	@fid "transfers/A-F.txt" procRacks(fid, [40 50 60])
elseif j==3
	checkRacks(locskus)
elseif j == 4
	@fid "transfers/Testers.txt"	printBRItems(fid, testerInNonTestBin)
elseif j==5
	d = Dates.format(today(), "u_d")
	@fid "transfers/Status_$d.txt" bakerStatus(fid, BLabels())
elseif j==6
	d = Dates.format(today(), "u_d")
	@fid "transfers/Status_Chanel_$d.txt" bakerStatus(fid, chanelLabels())
elseif j==7
	d = Dates.format(today(), "u_d")
	@fid "transfers/Status_F-A_$d.txt" bakerStatus(fid, vec(FLabels(1:81, 1:8, [40; 50 ;60])))
elseif j==8
	@fid "transfers/Wrong_items.txt" checkRacks()
end


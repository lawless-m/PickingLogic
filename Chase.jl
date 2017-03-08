cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")

using Base.Dates
using HIARP
using XlsxWriter

function traceTRN(lod, trns)
	for aw in trns
		#@printf "%s\t%d\t%s\t%s\t%s\n" aw.lodnum aw.qty aw.frstoloc aw.tostoloc aw.area
		if aw.lodnum==lod && aw.area in HIARP.AREAS
			return aw
		end
	end
	return HIARP.Away()
end	


function aways(year, month)
	@Xls "Aways" begin
		dte = add_format!(xls, Dict("num_format"=>"d mmm yyyy"))
		ws = add_worksheet!(xls, "Put Aways")
		write_row!(ws, 0, 0, ["Date" "WH ENTRY ID" "lodnum" "prtnum" "qty" "stoloc" "area"])
		recs = HIARP.getRecdByWH(year, month)
		
		#whlods, lodnums = HIARP.idntfyLods(["17HA0000945"])
		whlods, lodnums = HIARP.idntfyLods(collect(keys(recs)))
		awaysbyWH = HIARP.putAways(lodnums)
		#awaysbyWH = HIARP.putAways(["L00000243577"])
		
		#@printf "LODNUMS: %s\n" lodnums
		traces = Dict{AbstractString, Vector{HIARP.Away}}()
		for (whid,trns) in awaysbyWH
			for lod in lodnums
				trc = traceTRN(lod, trns)
				#@printf "WHID%s\t%s\n" whid trns
				if trc.lodnum != ""

					if haskey(traces, trc.lodnum)
						push!(traces[trc.lodnum], trc)
					else
						traces[trc.lodnum] = [trc]
					end
				end
			end
		end
		


		row = 1
		whids = collect(keys(recs))

		for id in whids

			for rec in recs[id]
				if !haskey(whlods, rec.wh_entry_id)
					continue
				end
				for lod in whlods[rec.wh_entry_id]
					if !haskey(traces, lod)
						continue
					end
					#@printf STDERR "id%s\ttraces[lod]:%s\n" id traces[lod]
					for i in 1:size(traces[lod],1)
						a = traces[lod][i]
						if a.prtnum == rec.prtnum
							c = write!(ws, row, 0, rec.date, dte)		
							write_row!(ws, row, c, [rec.wh_entry_id a.lodnum a.prtnum a.qty a.tostoloc a.area])
							row += 1
							traces[lod][i].prtnum = ""
						end
					end
				end
			end
		end
							
	end
end


aways(2017, 2)

quit()

println(HIARP.qSQL("
select trndte, lodnum, prtnum, inv_attr_str5, trnqty, frstol, tostol, to_arecod
from dlytrn 
where   
lodnum = 'L00000243577'
"))

quit()

#=
[
with
wh_ids as (SELECT inv_attr_str5 FROM invact WHERE  actcod='INVRCV' AND wh_id='MFTZ' AND )
, ident(lodnum) as ( select lodnum from dlytrn where inv_attr_str5  IN (select * from wh_ids) AND actcod='IDNTFY' AND movref='INTERNAL' 
AND (trndte >= '2017-01-01 00:00:00' and trndte <= '2017-01-31 23:59:59')
)
select trndte, lodnum, prtnum, inv_attr_str5, trnqty, tostol, to_arecod 
from dlytrn where lodnum IN (select * from lods) AND to_arecod  IN ('HWLFTZRH', 'HWLFTZRL', 'PALR01', 'CLDRMST', 'BBINA01', 'BIN01')
]

[

with

lods as (select lodnum, prtnum, trndte from dlytrn where actcod='IDNTFY' AND movref='INTERNAL' and trndte>= '2017-01-01 00:00:00' and trndte <= '2017-01-31 23:59:59')


select  dlytrn.trndte as putAwayDTE, lods.trndte as RecDTE, dlytrn.lodnum, dlytrn.prtnum, dlytrn.inv_attr_str5, dlytrn.trnqty, dlytrn.tostol, dlytrn.to_arecod, dlytrn.ordnum, dlytrn.rowid
from dlytrn inner join lods on dlytrn.prtnum=lods.prtnum
where 1=1

--and dlytrn.prtnum='1242911'
and dlytrn.lodnum=lods.lodnum
and dlytrn.to_arecod IN ('HWLFTZRH', 'HWLFTZRL', 'PALR01', 'CLDRMST', 'BBINA01', 'BIN01')

order by dlytrn.trndte
]

=#


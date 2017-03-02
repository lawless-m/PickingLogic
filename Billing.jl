cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")

using HIARP
using XlsxWriter
using ExcelReaders
using Base.Dates

items = itemMaster()

const Fmts = Dict{AbstractString, Format}()

function byPrtMonth(yr, mn)
	RPClient.qSQL("
		with prtmonth(yr, mn, dy, prtnum, untqty, untcas) as (
			SELECT year(rcvdte) as yr, right(concat('00', month(rcvdte)), 2) as mn, right(concat('00', day(rcvdte)), 2) as dy, prtnum, untqty, untcas 
			FROM invdtl
			WHERE prt_client_id='HUS'
			)
		SELECT dy, prtnum, untqty, untcas FROM prtmonth where yr='$yr' and mn='$mn' order by dy, prtnum
		")
end

function prtmonths()
	@Xls "prtmonths" begin
		for m in ["08" "09" "10" "11"]
			ws = add_worksheet!(xls, m)
			df = byPrtMonth("2016", m)
			for r in 1:size(df)[1]
				write!(ws, r, 1, df[:dy][r])
				write!(ws, r, 2, df[:prtnum][r])
				write!(ws, r, 3, df[:untqty][r])
				write!(ws, r, 4, df[:untcas][r])
			end
		end
	end
end

function parsewhIDs(ws, skus, whids)
	write_row!(ws, 0, 0, ["Article" "Descr" "Typcod" "Typ" "Put aways"])
	puts = wherePuts(skus, whids)
	row = 1
	for sku in skus
		item = items[sku]
		c = write_row!(ws, row, 0, [sku item.descr item.typcod Merch_cat[item.typcod]])
		if haskey(puts, sku)
			c += write_row!(ws, row, c, [s.stoloc for s in puts[sku]])	
		end
		row += 1
	end
end

function traceTRN(lod, trns)
	for aw in trns
		#@printf "%s\t%d\t%s\t%s\t%s\n" aw.lodnum aw.qty aw.frstoloc aw.tostoloc aw.area
		if aw.lodnum==lod && aw.area in HIARP.AREAS
			return aw
		end
	end
	return HIARP.Away()
end	


function aways(ws, year, month)

	write_row!(ws, 0, 0, ["Date" "WH ENTRY ID" "lodnum" "prtnum" "qty" "stoloc" "area"])
	recs = HIARP.getRecdByWH(year, month)
	if length(recs) == 0
		return "","",""
	end
	
	#whlods, lodnums = HIARP.idntfyLods(["17HA0000945"])
	whlods, lodnums = HIARP.idntfyLods(collect(keys(recs)))
	if size(lodnums, 1) < 1
		return "","",""
	end
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
	col = 0 
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
						col = write!(ws, row, 0, rec.date, Fmts["dte"])		
						col += write_row!(ws, row, col, [rec.wh_entry_id a.lodnum a.prtnum a.qty a.tostoloc a.area (a.area in BINS ? 1 : 0) (a.area in CARTONS ? 1 : 0)])
						row += 1
						traces[lod][i].prtnum = ""
					end
				end
			end
		end
	end
	binA = colNtocolA(col-2)
	cartA = colNtocolA(col-1)
	write!(ws, row, 4, "=sum(E2:E$row)")
	write_row!(ws, row, col-2, ["=sum($(binA)2:$binA$row)" "=sum($(cartA)2:$cartA$row)"])
	return "$binA$(row+1)", "$cartA$(row+1)", "E$(row+1)"
end

function getRecd(ws, year, month)
	recd = HIARP.getRecd(year, month)
	skus = Set()
	whids = Set()
	write_row!(ws, 0, 0, ["Date" "Activity"	"Article" "Status" "rcvqty"	"units per Case"	"# cases"	"Entry ID"	"Invoice"	"Received by"	"Typcod"	"Type"	"Cases"	"Eaches"])
	tcol = 0
	row = 0
	for row in 1:length(recd)
		r = recd[row]
		item = get(items, r.prtnum, "")
		typ = item == "" ? "XX" : item.typcod				
		cat = get(Merch_cat, typ, "XX")
		write!(ws, row, 0, r.date, Fmts["dte"])
		tcol = write_row!(ws, row, 1, [r.activity r.prtnum r.status r.rcvqty r.untcas 0 r.wh_entry_id r.invnum r.recd_by typ cat "=ROUNDDOWN(E$(row+1)/F$(row+1),0)" "=SIGN(E$(row+1))*MOD(ABS(E$(row+1)),ABS(F$(row+1)))"])
		push!(skus, r.prtnum)
		push!(whids, r.wh_entry_id)
	end	
	casesCol = colNtocolA(tcol-1)
	eachesCol = colNtocolA(tcol)
	
	write!(ws, row+1, 4, "=sum(E2:E$(row+1))") 
	qtyCell = "E$(row+2)"
	
	row = row + 1
	write_row!(ws, row, tcol-1, ["=sum($(casesCol)2:$(casesCol)$row)" "=sum($(eachesCol)2:$(eachesCol)$row)"])
	row = row + 1
	write!(ws, row, tcol-2, "Charge")
	write_row!(ws, row, tcol-1, [1.90 1.76], Fmts["dollar"])
	row = row + 1
	write_row!(ws, row, tcol-1, ["=indirect(\"R[-2]\",false) * indirect(\"R[-1]\",false)" "=indirect(\"R[-2]\",false) * indirect(\"R[-1]\",false)" "=indirect(\"C[-2]\",false)+indirect(\"C[-1]\",false)"], Fmts["dollar"])
	
	return "$(casesCol)$(row+1)", "$(eachesCol)$(row+1)", qtyCell
end


function inv()
	df = HIARP.qSQL("select dtlnum, subnum, fifdte, expire_dte  ,untqty,rcvkey  ,ship_line_id  ,wrkref   ,adddte  ,rcvdte ,lstmov     ,lstdte     ,lstcod    ,lst_usr_id ,inv_attr_str5 from invdtl where rcvkey='161100000928754'")
	println(df)
	
	df = HIARP.qSQL("select invact_id   ,trndte       ,actcod  ,inv_attr_str5 ,rcvqty ,shpqty ,ship_id   ,ship_line_id ,ordnum     ,ordlin  ,ordsln  ,ordtyp  ,trknum    ,invnum      ,supnum  ,invlin ,invsln  ,invtyp,moddte        ,mod_usr_id   

  FROM invact                                                                             
        WHERE  actcod='INVRCV'                                                                  
        AND wh_id='MFTZ'               
and prtnum='66400'                                                         
        AND trndte >='2017-01-01 00:00:00' and trndte <='2017-01-31 23:59:59'      
") 

	println(df)
end

function billing(xls, yr, mn)
	cases, eaches, recdQty = getRecd(add_worksheet!(xls, "Recd $yr-$mn"), yr, mn)
	bins, carts, awayQty = aways(add_worksheet!(xls, "Init $yr-$mn"), yr, mn)

	return ("'Recd $yr-$mn'!$cases", "'Recd $yr-$mn'!$eaches", "'Recd $yr-$mn'!$recdQty"), ("'Init $yr-$mn'!$bins", "'Init $yr-$mn'!$carts", "'Init $yr-$mn'!$awayQty")
end

function bills()
	@Xls "Billing" begin
		Fmts["dte"] = add_format!(xls, Dict("num_format"=>"d mmm yyyy"))
		Fmts["dollar"] = add_format!(xls, Dict("num_format"=>"\$#,##0.00"))
		summ = add_worksheet!(xls, "Summary")
		write_row!(summ, 0, 0, ["Year" "Mon" "Qty" "Cases" "Eaches" "Qty" "Cartons" "Bins"])
		row = 1
		for yr in 2016:2017, mn in 1:12
		#yr, mn = 2016, 9
			r, i = billing(xls, yr, mn)
			write_row!(summ, row, 0, [yr mn "="*r[3] "="*r[1] "="*r[2] "="*i[3] "=5.48*"*i[1] "=2*"*i[2] "=sum("*r[1]*","*r[2]*",5.48*"*i[1]*", 2*"*i[2]*")"])
			row += 1
		end
	end
end

#inv()
#getRecd(2017, 2)
#parseReport("Billing/December_processed.xlsx")

bills()




 
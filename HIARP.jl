

module HIARP

import Base.show
using RPClient
using DataFrames

include("utils.jl")

export FIFOSort, Stoloc, Part, currentStolocs, FIFOStolocs, rackFPrtnums, orderNumbers, orderLinePrtnums, ordersPrtnumList, prtnumOrderFreq, SKUs, prevOrders, stolocsHUS, wherePuts, HUSInventory, BRItems, currentPrtlocs, locAreas, itemMaster, OrdLine, orderAmntByDay, Pick, picksForYear
export AREAS, BINS, CARTONS

login("G:/RedPrarie/credentials.jls")
setLog(true)

macro DF(s, def)
	:(haskey(df, $s) ? isna(df[$s][r]) ? $def : df[$s][r] : $def)
end

const AREAS = ["HWLFTZRH" "HWLFTZRL" "PALR01" "CLDRMST" "BBINA01" "BIN01"]
const BINS = ["BBINA01" "BIN01"]
const CARTONS = ["HWLFTZRH" "HWLFTZRL" "PALR01" "CLDRMST"]

type Stoloc
	prtnum::AbstractString
	area::AbstractString
	stoloc::AbstractString
	fifo::DateTime
	lodnum::AbstractString
	case_id::AbstractString
	qty::Int64
	wh_entry_id::AbstractString
	# don't forget to change show if you change this
	Stoloc() = new("", "", "", DateTime(), "", "", 0, "")
	Stoloc(p, a, s, f, l, c, q, w) = new(p, a, s, f, l, c, q, w)
	function Stoloc(df, r) 
		new(@DF(:prtnum, ""), @DF(:area, ""), @DF(:stoloc, ""), @DF(:fifo, DateTime()), @DF(:lodnum, ""), @DF(:case_id, ""), @DF(:qty, 0), @DF(:wh_entry_id, ""))
	end
end

type Part
	prtnum::AbstractString
	typcod::AbstractString
	family::AbstractString
	descr::AbstractString
	Part() = new("", "", "", "")
	Part(p, t, f, d) = new(p, t, f, d)
	Part(df, r) = new(@DF(:prtnum, ""), @DF(:typcod, ""), @DF(:prtfam, ""), @DF(:dsc, ""))
end

type Pick # SELECT prtnum, pckqty AS qty, datum FROM pckwrk GROUP BY prtnum, datum
	prtnum::AbstractString
	qty::Int64
	date::Date
	Pick() = new("", 0, Date())
	Pick(p, q, d) = new(p, q, d)
	function Pick(df, r)
		p, q, d = @DF(:prtnum, ""), @DF(:pckqty, 0), @DF(:pckdte, "0000-01-01")
		new(p, q, Date(d))
	end
end

type InvAct
	date::DateTime
	activity::AbstractString
	prtnum::AbstractString
	status::AbstractString
	rcvqty::Int64
	untcas::Int64
	wh_entry_id::AbstractString
	invnum::AbstractString
	recd_by::AbstractString
	InvAct() = new(DateTime(), "", "", "", 0, 0, "", "", "")
	InvAct(d, a, p, s, r, u, e, i, b) = new(d, a, p, s, r, u, e, i, b)
	function InvAct(df, r)
		d = @DF(:trndte, "0000-01-01 00:00:00")
		new(d, @DF(:actcod, ""), @DF(:prtnum, ""), @DF(:invsts, ""), @DF(:rcvqty, 0), 0, @DF(:wh_entry_id, ""), @DF(:invnum, ""), @DF(:mod_usr_id, ""))
	end
end

type Away
	date::DateTime
	lodnum::AbstractString
	prtnum::AbstractString
	wh_entry_id::AbstractString
	qty::Int64
	frstoloc::AbstractString
	tostoloc::AbstractString
	area::AbstractString
	Away() = new(DateTime(), "", "", "", 0, "", "", "")
	Away(d, l, p, w, q, fs, ts, a) = new(d, l, p, w, q, fs, ts, a)
	function Away(df, r)
		d = @DF(:trndte, "0000-01-01 00:00:00")
		new(d, @DF(:lodnum, ""), @DF(:prtnum, ""), @DF(:inv_attr_str5, ""), @DF(:trnqty, 0), @DF(:frstol, ""), @DF(:tostol, ""), @DF(:to_arecod, ""))
	end
end

#  tostol, , ordnum, rowid

function show(io::IO, s::Stoloc)
	@printf io "Stoloc prtnum:%s area:%s stoloc:%s fifo:%S lodnum:%s case_id:%s qty:%d wh_entry_id:%s\n" s.prtnum s.area s.stoloc s.fifo s.lodnum s.case_id s.qty s.wh_entry_id
end

macro IN(a)
	:(" IN (" * join(["'$p'" for p in $a], ", ") * ")")
end

macro INpfx(pfx, a)
	:(" IN (" * join(["'$pfx$p'" for p in $a], ", ") * ")")
end

macro logCmd(blk)
	quote
		setLog(true)
		v = $blk
		setLog(false)
		return v
	end
end

function FIFOSort(lods::Vector{Stoloc})
	domestics = ["89-", "91-", "92-"]
	pickable = filter((x)->!(x.stoloc[1:3] in domestics), lods)
	sort!(pickable, lt=(x,y)->x.fifo<y.fifo)
	for i = 2:size(pickable, 1)
		if pickable[i].stoloc == pickable[1].stoloc
			pickable[1].qty += pickable[i].qty 
		else
			break
		end
	end
	pickable
end

function inventory()
	inv = Dict{AbstractString, DataFrame}()
	for area in AREAS
		inv[area] = qMoca("list inventory for display  WHERE wh_id = 'MFTZ' and  bldg_id='B1' and  prt_client_id='HUS' and arecod ='$area'")
		
		for i in [1 2 3 4 6 7 8 9 10]
			delete!(inv[area], symbol("inv_attr_str$i"))
		end
		for i in 1:5
			delete!(inv[area], symbol("inv_attr_int$i"))
		end
		for i in 1:3
			delete!(inv[area], symbol("inv_attr_flt$i"))
		end
		for i in 1:2
			delete!(inv[area], symbol("inv_attr_dte$i"))
		end
		for s in [:rem_untqty :rem_untqty_uom :cstms_cnsgnmnt_id :rttn_id :dty_stmp_flg :cstms_bond_flg :distro_id :distro_flg :wh_id :bldg_id :traknm :ftpcod :lotnum :sup_lotnum :invsts :mandte :revlvl :orgcod :supnum :hld_flg :cnsg_flg :subucc :subtag :loducc :lodtag :ch_asset_id :ch_asset_typ :asset_len :asset_wid :asset_hgt :asset_wgt :parent_asset_typ :parent_asset_id :parent_asset_len :parent_asset_wid :parent_asset_hgt  :parent_asset_wgt :phyflg :phdflg :catch_qty :avg_unt_catch_qty :untpak :untcas :age_pflnam  :stkuom :ser_typ :lodlvl :prtstyle :prtfit :prtcolor :prtsize :cmpkey :ship_line_id :prt_client_id :catch_unttyp :pckflg :useflg :cipflg :locsts :adddte :bill_through_dte]
			delete!(inv[area], s)
		end
	end
	inv
end

function item(prtnum)
	@printf STDERR "HIARP.item used\n"
	qMoca("list parts WHERE prtnum=@prtnum AND prt_client_id ='HUS' AND wh_id='----'", [("prtnum", prtnum)])
end

function typeCode(prtnum)
	@printf STDERR "HIARP.typeCode used\n"
	qSQL("SELECT typcod from prtmst WHERE prtnum=@prtnum AND prt_client_id ='HUS' AND wh_id_tmpl='----'", [("prtnum", prtnum)])[:typcod][1]
end

function prtNames()
	qSQL("SELECT DISTINCT colval, lngdsc FROM prtdsc WHERE colval LIKE '%|HUS|----'")
end	

function fillNames(prts::Dict{AbstractString, Part}) # by prtnum
	names = prtNames()
	for r in 1:size(names[1], 1)
		if haskey(prts, names[:colval][r][1:end-9])
			prts[names[:colval][r][1:end-9]].descr = names[:lngdsc][r]
		end
	end
	prts
end

function itemMaster()
	df = qSQL("SELECT DISTINCT prtnum, typcod, prtfam FROM prtmst WHERE prt_client_id ='HUS' AND wh_id_tmpl='----'")
	fillNames(DictMap(Part, :prtnum, df))
end
function itemMaster(prtnums)
	df = qSQL("SELECT DISTINCT prtnum, typcod, prtfam FROM prtmst WHERE prtnum " * @IN(prtnums) * " AND prt_client_id ='HUS' AND wh_id_tmpl='----'")
	fillNames(DictMap(Part, :prtnum, df))
end

function prtnum_stoloc_wh_entry_id()
	qSQL("SELECT prtnum, stoloc, inv_attr_str5 from client_blng_inv WHERE prt_client_id ='HUS' AND wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'R%' and arecod " * @IN(AREAS))
end

function columns(tbl)
	RPClient.columns(tbl)
end

function wh_entry_locs(wh_entry_id)
	qSQL("SELECT * FROM invloc WHERE wh_id='MFTZ' AND inv_attr_str5=@wh_entry_id", [("wh_entry_id", wh_entry_id)])
end

function FIFOStolocsX(prtnums)
	prts = join(["'$p'" for p in prtnums], ", ")
	qMoca("[ 
	WITH 
		fifo(prtnum, wh_entry_id, fifodte, qty, case_id) AS (SELECT prtnum, inv_attr_str5, fifdte, untqty, subnum FROM invdtl)	
	,	cbi(prtnum, stoloc, wh_entry_id, arecod, untqty) as (SELECT prtnum, stoloc, inv_attr_str5, arecod, untqty from client_blng_inv WHERE prt_client_id ='HUS' AND wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'RT%')
	SELECT distinct cbi.arecod as area, cbi.prtnum as prtnum, cbi.stoloc as stoloc, fifo.qty as qty, fifo.case_id, fifo.fifodte as fifo 
	FROM cbi INNER JOIN fifo on fifo.wh_entry_id=cbi.wh_entry_id
	WHERE fifo.prtnum=cbi.prtnum AND cbi.prtnum IN ($prts) ]"
	)
end

function FIFOStolocsDF(prtnums)
	qSQL("
	SELECT distinct stoloc, lodnum AS load_id, subnum AS case_id, prtnum, fifdte AS fifo, lst_arecod AS area, untqty AS qty, inv_attr_str5 AS wh_entry_id 
	FROM inventory_view
	WHERE lst_arecod " * @IN(AREAS) * "
	AND prtnum " * @IN(prtnums))
end

function FIFOStolocs(prtnums, k::Symbol)
	DictVec(Stoloc, k, FIFOStolocsDF(prtnums))
end

function rackFPrtnums()
	qSQL("SELECT prtnum, stoloc, inv_attr_str5 from client_blng_inv WHERE prt_client_id ='HUS' AND wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'R%' and arecod=@AREA", [("AREA", "BBINA01")]) 
end

function BRItems()
	DictVec(Stoloc, :stoloc, qSQL("SELECT DISTINCT stoloc, lodnum AS load_id, subnum AS case_id, prtnum, fifdte AS fifo, lst_arecod AS area, untqty AS qty, inv_attr_str5 AS wh_entry_id 
	FROM inventory_view
	WHERE lst_arecod " * @IN(AREAS) * " and (stoloc like '[0-1][0-9]-%' or stoloc like 'F-%')"))
end

function HUSInventory()
	DictVec(Stoloc, :stoloc, qSQL("SELECT DISTINCT stoloc, lodnum AS load_id, subnum AS case_id, prtnum, fifdte AS fifo, lst_arecod AS area, untqty AS qty, inv_attr_str5 AS wh_entry_id
	FROM inventory_view
	WHERE prt_client_id='HUS' AND lst_arecod " * @IN(AREAS)))
end

function SKUs()
	df = qSQL("SELECT DISTINCT prtnum, prtdsc.lngdsc AS dsc FROM inventory_view INNER JOIN prtdsc on prtdsc.colval LIKE CONCAT(inventory_view.prtnum, '|HUS|%')")
	dct = Dict{AbstractString, AbstractString}()
	for k in 1:size(df)[1]
		dct[df[:prtnum][k]] = df[:dsc][k]
	end
	return dct
end

function prtnumOrderFreq()
	df = qSQL("SELECT prtnum, COUNT(prtnum) AS cnt 
	FROM ord LEFT JOIN ord_line ON ord.ordnum = ord_line.ordnum
	WHERE ord.client_id='HUS' AND ord.wh_id='MFTZ'
	GROUP BY prtnum")
	dct = Dict{AbstractString, Int64}()
	for k in 1:size(df, 1)
		dct[df[:prtnum][k]] = df[:cnt][k]
	end
	return dct
end

typealias OrdLine Dict{AbstractString, Dict{Date, Int64}} # sku => Dict{date=>qty}

function orderAmntByDay(yr)
	df = qSQL("
		WITH ords(prtnum, qty, datum) AS (			
			SELECT prtnum, ordqty, CONVERT(date, entdte)
			FROM ord_line 
			WHERE  client_id='HUS' AND wh_id='MFTZ' AND entdte >= '01/01/$yr' AND entdte < '01/01/$(yr + 1)'
		)
		SELECT prtnum, SUM(qty) AS qty, datum FROM ords GROUP BY prtnum, datum")
		
	ords = OrdLine()
	for r in 1:size(df, 1)
		p = df[:prtnum][r]
		q = df[:qty][r]
		d = Date(df[:datum][r])
		
		if !haskey(ords, p)
			ords[p] = Dict{Date, Int64}()
		end
		ords[p][d] = q
	end	
	ords
end

function orderFreqByMonth()
	qSQL("
		WITH ords(prtnum, datum) AS (
			SELECT prtnum , CONCAT(CONCAT(YEAR(entdte), '-'), RIGHT(CONCAT('00', MONTH(entdte)), 2)) 
			FROM ord_line 
			WHERE  client_id='HUS' AND wh_id='MFTZ')
		SELECT prtnum, COUNT(*) AS cnt, datum FROM ords GROUP BY prtnum, datum")
end

function orderFreqByQtr()
	qSQL("
		WITH ords(prtnum, qtr) AS (
			SELECT prtnum, CONCAT(CONCAT(year(entdte), '-Q'), 1+MONTH(entdte)/4)
			FROM ord_line
			WHERE  client_id='HUS' AND wh_id='MFTZ')
		SELECT prtnum, COUNT(*) AS cnt, qtr FROM ords GROUP BY prtnum, qtr")
end

function picksForYear(yr)
	picks = Dict{AbstractString, Vector{Vector{Pick}}}()
	dates = ["01/01/$yr" "02/01/$yr" "03/01/$yr" "04/01/$yr" "05/01/$yr" "06/01/$yr" "07/01/$yr" "08/01/$yr" "09/01/$yr" "10/01/$yr" "11/01/$yr" "12/01/$yr" "01/01/$(yr+1)"]
	for m = 1:12
		df = qSQL("
			WITH ords(ordnum) AS (SELECT ordnum FROM ord WHERE client_id='HUS' AND wh_id='MFTZ')
			SELECT ords.ordnum, convert(date, pckwrk.pckdte) AS pckdte, pckwrk.prtnum, pckwrk.pckqty 
			FROM ords INNER JOIN pckwrk ON pckwrk.ordnum=ords.ordnum
			WHERE pckwrk.pckdte >= '$(dates[m])' AND pckwrk.pckdte < '$(dates[m+1])'
		")
		for r in 1:size(df)[1]
			p = Pick(df, r)
			if !haskey(picks, p.prtnum)
				picks[p.prtnum] = Vector{Vector{Pick}}(12)
			end
			if isdefined(picks[p.prtnum], m)
				push!(picks[p.prtnum][m], p)
			else
				picks[p.prtnum][m] = [p]
			end
		end
	end
	picks
end

function currentStolocsDF()
	qSQL("SELECT distinct arecod as area, prtnum as prtnum, stoloc as stoloc, untqty as qty, inv_attr_str5 as wh_entry_id 
	FROM client_blng_inv
	WHERE prt_client_id='HUS' AND wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'RT%'")
end

function locAreas()
	df = qSQL("SELECT distinct arecod as area, stoloc as stoloc
	FROM client_blng_inv
	WHERE prt_client_id='HUS' AND wh_id='MFTZ'  AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'RT%'")

	dct = Dict{AbstractString, AbstractString}()
	for k in 1:size(df)[1]
		dct[df[:stoloc][k]] = df[:area][k]
	end
	dct
end

function currentPrtlocs()
	DictVec(Stoloc, :prtnum, currentStolocsDF())
end

function currentStolocs()
	DictVec(Stoloc, :stoloc, currentStolocsDF())
end

function ordersPrtnumList()
	collect(qSQL("SELECT DISTINCT ord_line.prtnum as prtnum 
	FROM ord LEFT JOIN ord_line ON ord.ordnum = ord_line.ordnum 
	WHERE ord.client_id='HUS' AND ord.wh_id='MFTZ'")[:prtnum])
end

function orderNumbers()
	collect(qSQL("SELECT ordnum 
	FROM ord 
	WHERE client_id='HUS' AND wh_id='MFTZ'")[:ordnum])
end

function orderLinePrtnums(onum)
	collect(qSQL("SELECT prtnum FROM ord_line
	WHERE ordnum=@ORDNUM", [("ORDNUM", onum)])[:prtnum])
end

function prevOrders(prtnum, cnt=5)
	collect(qSQL("SELECT entdte as datum FROM ord_line WHERE prtnum=@PRTNUM AND rownum<=@CNT ORDER BY entdte DESC", [("PRTNUM", prtnum), ("CNT", cnt)])[:datum])
end

function stolocsHUS()
	collect(qSQL("SELECT distinct stoloc FROM locmst WHERE (wh_id ='MIA' or wh_id='MFTZ')")[:stoloc])
end

function wherePut(prtnum, wh_entry_id)
	qSQL("SELECT distinct stoloc from inventory_view where prtnum=@prtnum and inv_attr_str5=@whid and lst_arecod " * @IN(AREAS)* " and (stoloc like '[0-1][0-9]-%' or stoloc like 'F-%')", [("prtnum", prtnum), ("whid", wh_entry_id)])
end

function wherePuts(prtnums, wh_entry_ids)
	df = qSQL("SELECT DISTINCT prtnum, stoloc FROM inventory_view WHERE prtnum " * @IN(prtnums) * " AND inv_attr_str5 " * @IN(wh_entry_ids) * " AND lst_arecod " * @IN(AREAS) * " and (stoloc like '[0-9]%' or stoloc like 'F-%')")
	DictVec(Stoloc, :prtnum, df)
end

function unitCases(dte, prtnums)
	if length(prtnums) == 0
		return
	end
	df = qSQL("SELECT distinct prtnum, untcas FROM invdtl WHERE prtnum " * @IN(prtnums) * " AND $dte")
	unts = Dict{AbstractString, Int64}()
	for r in 1:size(df, 1)
		unts[df[:prtnum][r]] = df[:untcas][r]
	end
	unts
end

function getRecdByWH(year, month)
	df = getRecdDF(year, month)
	DictVec(InvAct, :wh_entry_id, df)
end

function idntfyLods(wh_entry_ids)
	df = qSQL(
	"select lodnum, inv_attr_str5
	from dlytrn
	where inv_attr_str5 " * @IN(wh_entry_ids) * "
	AND actcod='IDNTFY'
	AND movref='INTERNAL'
	"
	)
	whlods = Dict{AbstractString, Vector{AbstractString}}()
	lods = AbstractString[]
	for r in 1:size(df,1)
		if haskey(whlods, df[:inv_attr_str5][r])
			push!(whlods[df[:inv_attr_str5][r]], df[:lodnum][r])
		else
			whlods[df[:inv_attr_str5][r]] = AbstractString[df[:lodnum][r]]
		end
		push!(lods, df[:lodnum][r])
	end
	whlods, lods
end

function putAways(lodnums)
	df = qSQL("
	select trndte, lodnum, prtnum, inv_attr_str5, trnqty, frstol, tostol, to_arecod, ordnum
	from dlytrn
	where lodnum " * @IN(lodnums) * "
	order by trndte
	")
	DictVec(Away, :inv_attr_str5, df)
end

function ym2range(year, month, field)
	y_m = @sprintf "%04d-%02d" year month
	d_end = @sprintf "%02d" Dates.day(Dates.lastdayofmonth(Date(year,month,1)))
	"($field >= '$(y_m)-01 00:00:00' and $field <= '$(y_m)-$(d_end) 23:59:59')"
end

function putAwaysInOne(year, month)
	dte = ym2range(year, month, "trndte")
	df = qSQL("
with 
wh_ids as (SELECT inv_attr_str5 FROM invact WHERE  actcod='INVRCV' AND wh_id='MFTZ')
, lods(lodnum, prtnum) as (select lodnum from dlytrn where inv_attr_str5 IN (select * from wh_ids) AND actcod='IDNTFY' AND movref='INTERNAL' and $dte)
select trndte, lodnum, prtnum, inv_attr_str5, trnqty, tostol, to_arecod, ordnum, rowid
from dlytrn 
where $dte
AND lodnum IN (select lodnum from lods) AND to_arecod " * @IN(AREAS))
	DictMap(Away, :rowid, df)
end

function getRecdDF(year, month)
	dte = ym2range(year, month, "trndte")
	df = qSQL("
	SELECT rcvqty, trndte, actcod,  inv_attr_str5 as wh_entry_id, prtnum, invsts, invnum, mod_usr_id 
	FROM invact 
	WHERE  actcod='INVRCV'
	AND wh_id='MFTZ'
	AND $dte
")
	return df
end
	
function getRecd(year, month)
	df = getRecdDF(year, month)	
	recs = InvAct[]
	parts = Set()
	for r in 1:size(df, 1)
		push!(parts, df[:prtnum][r])
		push!(recs, InvAct(df, r))
	end
	if length(parts) > 0
		unts = unitCases(ym2range(year, month, "rcvdte"), parts)
		for i in 1:size(recs,1)
			recs[i].untcas = get(unts, recs[i].prtnum, 0)
		end
	end
	recs
end

function ships(year, month)
	dte = ym2range(year, month, "lstdte")
	df = qSQL("
	WITH cartons as (SELECT subnum, count(*) parts from invdtl WHERE $dte AND lst_arecod='SHIP' group by subnum)
	select count(*) as multiparts from cartons where parts > 1
	")
	return df[1][1]
end

function invdtl(year, month)
	dte = ym2range(year, month, "lstdte")
	qSQL("SELECT * from invdtl WHERE $dte")
end

# STAAHHHPPPP

end


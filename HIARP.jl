
module HIARP

using RPClient
using DataFrames

login("credentials.jls")

type Stoloc
	prtnum::AbstractString
	area::AbstractString
	stoloc::AbstractString
	fifo::DateTime
	case_id::AbstractString
	qty::Int64
	descr::AbstractString
	wh_entry_id::AbstractString
	Stoloc(p, a, s, f, c, q, d, w) = new(p, a, s, f, c, q, d, w)
	function Stoloc(df, r)
		dns(x)=x
		dns(x::DataArrays.NAtype)=""
		
		p = dns(haskey(df, :prtnum) ? df[:prtnum][r] : "")
		a = dns(haskey(df, :area) ? df[:area][r] : "")
		s = dns(haskey(df, :stoloc) ? df[:stoloc][r] : "")
		f = haskey(df, :fifo) ? df[:fifo][r] : DateTime()
		c = dns(haskey(df, :case_id) ? df[:case_id][r] : "")
		q = dns(haskey(df, :qty) ? df[:qty][r] : 0)
		d = dns(haskey(df, :dsc) ? df[:dsc][r] : "")
		w = dns(haskey(df, :wh_entry_id) ? df[:wh_entry_id][r] : "")
		new(p, a, s, f, c, q, d, w)
	end
end

function inventory()
	inv = Dict{AbstractString, DataFrame}()
	for area in ["HWLFTZRH", "HWLFTZRL", "PALR01", "CLDRMST", "BBINA01", "BIN01"]
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

function prtnum_stoloc_wh_entry_id()
	qSQL("SELECT prtnum, stoloc, inv_attr_str5 from client_blng_inv WHERE wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'R%' and arecod in ('BIN01', 'HWLFTZRH', 'HWLFTZRL', 'PALR01', 'CLDRMST', 'BBINA01')")
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
	,	cbi(prtnum, stoloc, wh_entry_id, arecod, untqty) as (SELECT prtnum, stoloc, inv_attr_str5, arecod, untqty from client_blng_inv WHERE wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'RT%')
	SELECT distinct cbi.arecod as area, cbi.prtnum as prtnum, cbi.stoloc as stoloc, fifo.qty as qty, prtdsc.lngdsc as dsc, fifo.case_id, fifo.fifodte as fifo 
	FROM cbi INNER JOIN prtdsc on prtdsc.colval LIKE CONCAT(cbi.prtnum, '|HUS|%') INNER JOIN fifo on fifo.wh_entry_id=cbi.wh_entry_id
	WHERE fifo.prtnum=cbi.prtnum AND cbi.prtnum IN ($prts) ]"
	)
end

function FIFOStolocs(prtnums)
	prts = join(["'$p'" for p in prtnums], ", ")
	qSQL("
	SELECT distinct stoloc, lodnum AS load_id, subnum AS case_id, prtnum, fifdte AS fifo, lst_arecod AS area, untqty AS qty, inv_attr_str5 AS wh_entry_id , prtdsc.lngdsc AS dsc
	FROM inventory_view  INNER JOIN prtdsc on prtdsc.colval LIKE CONCAT(inventory_view.prtnum, '|HUS|%')
	WHERE lst_arecod IN ('BIN01', 'HWLFTZRH', 'HWLFTZRL', 'PALR01', 'CLDRMST', 'BBINA01')	
	AND prtnum IN ($prts)")
end


function rackFPrtnums()
	qSQL("SELECT prtnum, stoloc, inv_attr_str5 from client_blng_inv WHERE wh_id='MFTZ' AND bldg_id='B1' AND fwiflg=1 and shpflg=0 and stgflg=0 and stoloc not like 'OST%' and stoloc not like 'QUA%' and stoloc not like 'R%' and arecod=@AREA", [("AREA", "BBINA01")]) 
end

function orderFreq()
	qSQL("with ords(prtnum, datum) as (SELECT prtnum , concat(concat(year(entdte), '-'), right(concat('00', month(entdte)), 2)) from ord_line where  client_id='HUS' AND wh_id='MFTZ') select prtnum, count(*) as cnt, datum from ords group by datum, prtnum")
end

function currentStolocs()
	qSQL("SELECT distinct CBI.arecod as area, CBI.prtnum as prtnum, CBI.stoloc as stoloc, CBI.untqty as qty, prtdsc.lngdsc as dsc, inv_attr_str5 as wh_entry_id FROM client_blng_inv AS CBI INNER JOIN prtdsc on prtdsc.colval = CONCAT(CBI.prtnum, '|HUS|MFTZ') WHERE CBI.bldg_id='B1' AND CBI.fwiflg=1 and CBI.shpflg=0 and CBI.stgflg=0 and CBI.stoloc not like 'OST%' and CBI.stoloc not like 'QUA%' and CBI.stoloc not like 'RT%'")
end


end

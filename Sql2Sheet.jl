cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
using Base.Dates
using HIARP
using XlsxWriter


function sql2sheet(sql)
	@Xls "SQL_$(hash(sql))" begin
		ws = add_worksheet!(xls)
		df = HIARP.qSQL(sql)
		for r in 1:size(df,1)
			for c in 1:size(df,2)
				write!(ws, r, c, @dena(df[c][r]))
			end
		end
	end
end

sql2sheet("
SELECT ia.trndte,
        ia.inv_attr_str5 as wh_entry_id,
        ia.invsts,
        ia.invnum,
        rl.inv_attr_str7 PO,
        ia.prtnum,
        ia.rcvqty actual_rcv_qty,
        cs.untqty footprint_qty,
        Case when cs.untqty > 0 then(ia.rcvqty / cs.untqty)
             else 0
        end cases,
        ia.rcvqty % cs.untqty PCS
   FROM invact ia
  inner
   join rcvlin rl
     on rl.invnum = ia.invnum
    and rl.prtnum = ia.prtnum
    and rl.wh_id = ia.wh_id
    and rl.client_id = ia.prt_client_id
    and rl.trknum = ia.trknum
    and rl.invlin = ia.invlin
  inner
   join prtftp_dtl cs
     on cs.prtnum = ia.prtnum
    and cs.uomcod = 'CS'
    and cs.wh_id = ia.wh_id
    and cs.prt_client_id = ia.prt_client_id
    and cs.wh_id = 'MFTZ'
    and cs.prt_client_id = 'HUS'
  inner
   join prtftp_dtl ea
     on ea.prtnum = ia.prtnum
    and ea.uomcod = 'EA'
    and ea.wh_id = ia.wh_id
    and ea.prt_client_id = ia.prt_client_id
    and ea.wh_id = 'MFTZ'
    and ea.prt_client_id = 'HUS'
  WHERE actcod = 'INVRCV'
    AND ia.wh_id = 'MFTZ'
    and ia.prt_client_id = 'HUS'
    AND ia.trndte > '2/01/2017'
    AND ia.trndte < '3/01/2017'

")


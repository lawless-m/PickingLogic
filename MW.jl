cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")

include("utils.jl")
include("merch_cats.jl")

using HIARP
using XlsxWriter
using ExcelReaders

for sql in ["select * from dlytrn where usr_id='MWHEATH' or ins_user_id='MWHEATH' or last_upd_user_id='MWHEATH'"

"select * from ordact  where   usr_id   ='MWHEATH'"
"select * from shipping_pckwrk_view  where  last_pck_usr_id='MWHEATH'"
"select * from invdtl  where   lst_usr_id='MWHEATH'"
"select * from trlract  where  mod_usr_id='MWHEATH'"
"select * from invsub  where  lst_usr_id ='MWHEATH'"
"select * from invlod  where  lst_usr_id ='MWHEATH'"
"select * from inventory_pckwrk_view  where  lst_usr_id ='MWHEATH'"
"select * from pcklst  where  last_upd_user_id ='MWHEATH'"
"select * from invact  where   mod_usr_id='MWHEATH'"
"select * from inventory_view where lst_usr_id ='MWHEATH'"
"select * from pckwrk  where  last_pck_usr_id='MWHEATH'"
"select * from rcvtrk WHERE mod_usr_id ='MWHEATH'"
"select * from prtmst_wh  where   last_upd_user_id ='MWHEATH'"
"select * from les_opt_ath  where  ath_id   ='MWHEATH'"

]

	println(sql)
	df = HIARP.qSQL(sql)
	println(df)
end



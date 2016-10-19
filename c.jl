
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using HIARP

include("utils.jl")

println(HIARP.RPClient.qSQL("select * from inventory_view where stoloc='91-25-11'"))




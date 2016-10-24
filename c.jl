cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

#using HIADB
using DataFrames
using HIARP

include("utils.jl")

println("Get DF")
df = HIARP.RPClient.qSQL("SELECT DISTINCT prtnum, prtdsc.lngdsc AS dsc FROM inventory_view INNER JOIN prtdsc on prtdsc.colval LIKE CONCAT(inventory_view.prtnum, '|HUS|%')")

println("loop")
dct = Dict{AbstractString, AbstractString}()
for k in 1:size(df)[1]
	dct[df[:prtnum][k]] = df[:dsc][k]
end




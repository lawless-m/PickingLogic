
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))


using HIARP


include("utils.jl")
include("merch_cats.jl")

skulocs, locskus, rackskus = skuLocations()

curr = currentStolocs()
typecodes = typeCodesSerial()

println(typecodes)


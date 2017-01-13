
cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))


using Base.Dates
using HIARP
using XlsxWriter

 include(abspath("GitHub/PickingLogic/utils.jl"))
include("merch_cats.jl")
include("Families.jl")


phys = physicalHUS()
println(phys)
println("90-10-12B" in phys)


cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))

using HIARP
using DataFrames

println(HIARP.orderFreq())


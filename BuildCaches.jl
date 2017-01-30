cd(ENV["USERPROFILE"] * "/Documents")
const PLPATH = abspath("GitHub/PickingLogic")
unshift!(LOAD_PATH, "$PLPATH/")

using HIARP

include("$PLPATH/utils.jl")

allOrders = @cacheFun(cacheOrders, "g:/Heinemann/Orders2013-2016.jls")

allPicks = @cacheFun(cachePicks, "g:/Heinemann/Picks2013-2016.jls")



cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")
unshift!(LOAD_PATH, "GitHub/XlsxWriter.jl/")


using XlsxWriter


@Xls "mat" begin
	ws = add_worksheet!(xls)
	write!(ws, 0, 0, [[1 2 3] [10 20 30]])
end


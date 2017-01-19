cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using Base.Dates
using HIARP
using XlsxWriter
using ExcelReaders

include("utils.jl")

xl = @sheet "Schema.xls" "Table-Column"
scheme = Dict{AbstractString, Vector{AbstractString}}()
@time for r in 2:size(xl, 1)	
	if xl[r,3] in ["nvarchar" "varchar" "char"]
		if haskey(scheme, xl[r,1])
			push!(scheme[xl[r,1]], xl[r,2])
		else
			scheme[xl[r,1]] = AbstractString[xl[r,2]]
		end
	end
end

function findT(t)
	@fid "$t.txt" for table in keys(scheme)
		df = HIARP.RPClient.qSQL("SELECT * FROM $table WHERE (" * join(scheme[table], "='$t' OR ") * "='$t') AND rownum=1")
		if size(df,1) > 0
			@printf fid "%s : %s\n" table df
			@printf STDERR "%s : %s\n" table df
		end
	end
end
function findLikeT(t)
	@fid "$t%.txt" for table in keys(scheme)
		df = HIARP.RPClient.qSQL("SELECT * FROM $table WHERE (" * join(scheme[table], " like '$t%' OR ") * " like '$t%') AND rownum=1")
		if size(df,1) > 0
			@printf fid "%s : %s\n" table df
			@printf STDERR "%s : %s\n" table df
		end
	end
end

findLikeT("ATU")


cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, abspath("GitHub/PickingLogic/"))
unshift!(LOAD_PATH, abspath("GitHub/XlsxWriter.jl/"))

using Base.Dates
using HIARP
using XlsxWriter
using ExcelReaders

include("utils.jl")

function tColumns(typs) # e.g. ["nvarchar" "varchar" "char"]
	xl = @sheet "Schema.xls" "Table-Column"
	scheme = Dict{AbstractString, Vector{AbstractString}}()
	@time for r in 2:size(xl, 1)	
		if xl[r,3] in typs
			if haskey(scheme, xl[r,1])
				push!(scheme[xl[r,1]], xl[r,2])
			else
				scheme[xl[r,1]] = AbstractString[xl[r,2]]
			end
		end
	end
	scheme
end

function findPrtnum(t, prtnum, scheme)
	txtScheme = tColumns(["nvarchar"])
	@fid "$t.txt" for table in keys(scheme)

		if !(haskey(txtScheme, table) && "prtnum" in txtScheme[table])		
			continue
		end
		df = HIARP.RPClient.qSQL("SELECT * FROM $table WHERE (" * join(scheme[table], "=$t OR ") * "=$t) AND prtnum=$prtnum AND rownum=1")
		if size(df,1) > 0
			@printf fid "%s : %s\n" table df
			@printf STDERR "%s : %s\n" table df
		end
	end
end

function findwithCandPrtnum(c, prtnum, scheme)
	txtScheme = tColumns(["nvarchar"])
	@fid "$(prtnum)_$(c).txt" begin
		@printf fid "Table\tPrtnum\t%s\n" c
		for table in keys(scheme)

			# does the table have column $c
			if ! (c in scheme[table])
				continue
			end
			
			# does the table with c have a prtnum
			if ! (haskey(txtScheme, table) && ("prtnum" in txtScheme[table]))
				continue
			end

			df = HIARP.RPClient.qSQL("SELECT DISTINCT '$table' as tab, prtnum, $c as col FROM $table WHERE prtnum=$prtnum")

			for r in 1:size(df,1)
				@printf fid "%s\t%s\t%s\n" df[:tab][r] df[:prtnum][r] df[:col][r]
			end
		end
	end
end

function findT(t, scheme) # if T is textxt, it needs quoting with '
	@fid "$t.txt" for table in keys(scheme)
		df = HIARP.RPClient.qSQL("SELECT * FROM $table WHERE (" * join(scheme[table], "=$t OR ") * "=$t) AND rownum=1")
		if size(df,1) > 0
			@printf fid "%s : %s\n" table df
			@printf STDERR "%s : %s\n" table df
		end
	end
end

function findLikeT(t, scheme)
	@fid "$t%.txt" for table in keys(scheme)
		df = HIARP.RPClient.qSQL("SELECT * FROM $table WHERE (" * join(scheme[table], " like '$t%' OR ") * " like '$t%') AND rownum=1")
		if size(df,1) > 0
			@printf fid "%s : %s\n" table df
			@printf STDERR "%s : %s\n" table df
		end
	end
end


#findLikeT("'ATU'", tColumns(["nvarchar" "varchar" "char"]))
findT("'MWHEATH'", tColumns(["nvarchar" "varchar" "char"]))

# findPrtnum(15, "'816520'", tColumns(["int"]))

#findwithCandPrtnum("untcas", "'816520'", tColumns(["int"]))



module RPClient

export login, qMoca, qSQL, columns, setLog

const CREDENTIALS = Dict{AbstractString, AbstractString}("host"=>"", "un"=>"", "pw"=>"", "id"=>"", "key"=>"")

using LightXML
using Requests
using DataFrames
using Base.Dates

logMoca = false

function setLog(b::Bool)
	global logMoca = b
end

function parseDate(txt)
	y = parse(Int64, txt[1:4])
	m = parse(Int64, txt[5:6])
	d = parse(Int64, txt[7:8])
	H = parse(Int64, txt[9:10])
	M = parse(Int64, txt[11:12])
	S = parse(Int64, txt[13:14])
	DateTime(y, m, d, H, M, S)
end

type colmn
	s::Symbol
	t::DataType
end
	
function fillDF(res)
	df = DataFrame()
	if size(res)[1] != 1
		return df
	end

	meta = get_elements_by_tagname(res[1], "metadata")
	if size(meta)[1] != 1
		return df
	end

	cols = Symbol[]
	types = Dict{AbstractString, DataType}("S"=>AbstractString, "I"=>Int64, "O"=>Bool, "D"=>DateTime, "F"=>Float64)
	for c in child_elements(meta[1])
		S = symbol(attribute(c, "name"))
		T = types[attribute(c, "type")]
		df[S] = T[]
		push!(cols, S)
	end
	
	data = get_elements_by_tagname(res[1], "data")
	if size(data)[1] != 1
		return df
	end
	
	conv = Dict{DataType, Function}(AbstractString=>(x)->x, Int64=>(x)->parse(Int64,x), Bool=>(x)->x==0?false:true, DateTime=>parseDate, Float64=>(x)->parse(Float64, x))
	for r in child_nodes(data[1])
		fields = collect(child_elements(XMLElement(r)))
		for c in 1:size(cols)[1]
			if attribute(fields[c], "null") == "true"
				push!(df[cols[c]], NA)
			else
				push!(df[cols[c]], conv[eltype(df[cols[c]])](content(fields[c])))
			end
		end
	end
	df
end

function postMOCA(xml)
	if logMoca == true
		@printf STDERR "%s\n" xml
	end
	r = Requests.post(CREDENTIALS["host"]*(CREDENTIALS["id"] == "" ? "service" : "service?msession=" * CREDENTIALS["id"]); headers = Dict("Content-Type" => "application/moca-xml", "Response-Encoder" => "xml"), data=xml)
	xml = parse_string(readall(r))
	els = get_elements_by_tagname(root(xml), "session-id")
	CREDENTIALS["id"] = size(els)[1] == 1 ? content(els[1]) : ""
	els = get_elements_by_tagname(root(xml), "status")
	status = size(els)[1] == 1 ? content(els[1]) : ""
	els = get_elements_by_tagname(root(xml), "message")
	msg = size(els)[1] == 1 ? content(els[1]) : ""
	if status != "0" && status != "510"
		error(status, ": SQL says : ", msg)
	end
	fillDF(get_elements_by_tagname(root(xml), "moca-results"))
end

macro moca(fields, blk)
	return quote
		x = XMLDocument()
		xroot = create_root(x, "moca-request")
		set_attribute(xroot, "auto-commit", "True")
		if CREDENTIALS["id"] != ""
			sid = new_child(xroot, "session")
			set_attribute(sid, "id", CREDENTIALS["id"])
		end
		if size($fields)[1] > 0
			context = new_child(xroot, "context")
			for (n, v) in $fields
				@field context n v 
			end
		end
		env = new_child(xroot, "environment")
		$blk
		resp = postMOCA(string(xroot))
		free(x)
		resp
	end
end

macro var(r, n, v)
	return quote
		v = new_child($r, "var")
		set_attribute(v, "name", $n)
		set_attribute(v, "value", $v)
	end
end

attType(n::Integer) = "INTEGER"
attType(n::Real) = "FLOAT"
attType(n) = "STRING"

macro field(r, n, v)
	return quote
		f = new_child($r, "field")
		set_attribute(f, "name", $n)
		set_attribute(f, "type", attType($v))
		set_attribute(f, "oper", "EQ")
		add_text(f, string($v))
	end
end

macro query(r, sql)
	:(add_text(new_child($r, "query"), $sql))
end

function login(credfile) # serialized "host"=>"http://$host:$port", "un"=>$un, "pw"=>$pw
	fid = open(credfile, "r")
	creds = deserialize(fid)
	close(fid)

	CREDENTIALS["host"] = creds["host"]
	CREDENTIALS["un"] = creds["un"]
	CREDENTIALS["pw"] = creds["pw"]

	newSessionID()
	resp = @moca [("usr_id",CREDENTIALS["un"]) ("usr_pswd",CREDENTIALS["pw"])] begin
		@var env "LOCALE_ID" "US_ENGLISH"
		@query xroot "login user where usr_id = @usr_id and usr_pswd = @usr_pswd"
	end
	CREDENTIALS["key"] = resp[:session_key][1]
	@printf STDERR "Logged in as %s [%s]\n" CREDENTIALS["un"] CREDENTIALS["key"]
end

function newSessionID()
	@moca [] begin
		@var env "DEVCOD" "MWHTERMINAL"
		@query xroot "ping"
	end
end

function qMoca(q::AbstractString, fields=[])
	@moca fields begin
		@var env "LOCALE_ID" "US_ENGLISH"
		@var env "USR_ID" CREDENTIALS["un"]
		@var env "SESSION_KEY" CREDENTIALS["key"]
		@var env "MOCA_APPL_ID" "Julio"
		@query xroot q
	end
end

function qSQL(q::AbstractString, fields=[])
	qMoca("[" * q * "]", fields)
end

function columns(tbl)
	qMoca("[ SELECT * from $tbl WHERE 1=0]")
end

function tables()
	qSQL("SELECT TableName = c.table_name, TableType = t.table_type, ColumnName = c.column_name, DataType = data_type
	FROM information_schema.columns c INNER JOIN information_schema.tables t ON c.table_name = t.table_name AND c.table_schema = t.table_schema
	ORDER BY TableName, ordinal_position")
end

# staahhhp

end
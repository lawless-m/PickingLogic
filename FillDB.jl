#=

Ex2SQL.jl

https://github.com/JuliaDB/SQLite.jl
=#

cd(ENV["USERPROFILE"] * "/Documents")

unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using SQLite
using ExcelReaders
using Bay2Bay_Costs

macro trans(blk)
	return quote
	SQLite.execute!(db, "BEGIN")
	$blk
	SQLite.execute!(db, "COMMIT")
	end
end

#= doesn;t work
macro insert(stmt, binds)
	return quote
		for i in 1:length($binds)
			SQLite.bind!($stmt, i, $binds[i])
		end
		SQLite.execute!($stmt)
	end
end
=#

macro dictCols(sql, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		data = SQLite.query(db, $sql)
		dct = Dict{eltype(data[$ks][1]), eltype(data[$vs][1])}()
		for k in 1:size(data)[1]
			dct[get(data[$ks][k])] = get(data[$vs][k])
		end
		dct
	end
end

i64(a::Float64) = round(Int64, a)
i64(a::AbstractString) = parse(Int64, a)

	
function DB()
	db = SQLite.DB("Databases/HIA_Orders.sqlite")
	SQLite.execute!(db, "PRAGMA foreign_keys = ON")
	@trans if size(SQLite.query(db, "PRAGMA stats"))[1] == 1
		SQLite.execute!(db, "CREATE TABLE Locations (location INTEGER PRIMARY KEY, label TEXT, UNIQUE(label))")
		SQLite.execute!(db, "CREATE TABLE Distances  (location1 INTEGER, location2 INTEGER, distance REAL, FOREIGN KEY(location1) REFERENCES Locations(location), FOREIGN KEY(location2) REFERENCES Locations(location), UNIQUE (location1, location2))")	
		SQLite.execute!(db, "CREATE TABLE SKUs (prtnum INTEGER PRIMARY KEY, location INTEGER, FOREIGN KEY(location) REFERENCES Locations(location))")
		SQLite.execute!(db, "CREATE TABLE OrderLine (ordnum INTEGER, prtnum INTEGER, qty INTEGER, FOREIGN KEY(prtnum) REFERENCES SKUs(prtnum))")
		SQLite.execute!(db, "CREATE INDEX OrderLineordnum on OrderLine(ordnum)")
	end
	return db
end

function importOrders(db)
	xl = readxlsheet("g:/Heinemann/ord_line_raw_data.xlsx", "LextEdit Export 08-24-16 02.28")

	sku = SQLite.Stmt(db, "INSERT OR IGNORE INTO SKUs (prtnum, location) VALUES(?, NULL)")
	lne = SQLite.Stmt(db, "INSERT INTO OrderLine (ordnum, prtnum, qty) VALUES(?, ?, ?)")

	@trans for r in 2:size(xl)[1]
		SQLite.bind!(sku, 1, i64(xl[r, 4]))
		SQLite.execute!(sku)
		SQLite.bind!(lne, 1, i64(xl[r, 2]))
		SQLite.bind!(lne, 2, i64(xl[r, 4]))
		SQLite.bind!(lne, 3, i64(xl[r, 5]))
		SQLite.execute!(lne)	
	end
end

function labelLocations(db)
	loc = SQLite.Stmt(db, "INSERT INTO Locations (label) VALUES(?)")
	@trans for rack in 81:-1:1, bin in 8:-1:1, level in [10:10:90; 91]				
		SQLite.bind!(loc, 1, @sprintf "F-%02d-%02d-%02d" rack level bin)
		SQLite.execute!(loc)
	end
end

function distances(db)
	locs = @dictCols("SELECT location, label from Locations", :label, :location)
	loc =  SQLite.Stmt(db, "SELECT location From Locations WHERE label=?")
	dist = SQLite.Stmt(db, "INSERT INTO Distances (location1, location2, distance) VALUES(?, ?, ?)")
	@trans for rack1 in 81:-1:1, bin1 in 8:-1:1, level1 in [10:10:90; 91]
		l1 = locs[@sprintf "F-%02d-%02d-%02d" rack1 level1 bin1]
		SQLite.bind!(dist, 1, l1)
		for rack2 in 81:-1:1, bin2 in 8:-1:1, level2 in [10:10:90; 91]
			l2 = locs[@sprintf "F-%02d-%02d-%02d" rack2 level2 bin2]
			if l2 > l1
				SQLite.bind!(dist, 2, l2)
				SQLite.bind!(dist, 3, Bay2Bay_Costs.distance(rack1, bin1, level1, rack2, bin2, level2))
				SQLite.execute!(dist)
			end
		end
	end
end

function SKUlocations(db)
	xl = readxlsheet("G:/Heinemann/Travel Sequence/P81 SKU Location R1.xlsx", "SKU Qty Loc")
	sku = SQLite.Stmt(db, "UPDATE OR IGNORE SKUs SET location=(SELECT location from Locations where label=?) WHERE prtnum=?")
	@trans for r in 2:size(xl)[1]
		SQLite.bind!(sku, 1, xl[r, 4])
		SQLite.bind!(sku, 2, i64(xl[r, 1]))
		SQLite.execute!(sku)
	end
end

db = DB()
importOrders(db)
labelLocations(db)
SKUlocations(db)
distances(db)



#=

Ex2SQL.jl

https://github.com/JuliaDB/SQLite.jl
=#

module HIADB

using SQLite
using ExcelReaders
using Bay2Bay_Costs

macro trans(blk)
	return quote
	SQLite.execute!(DB, "BEGIN")
	$blk
	SQLite.execute!(DB, "COMMIT")
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

macro denull(T, data, col)
	:($T[get(x) for x in $data[$col]])
end

function denull(T, sql::AbstractString, col)
	@denull(T, SQLite.query(DB, sql), col)
end


function i64(sql::AbstractString, col)
	@denull(Int64, SQLite.query(DB, sql), col)
end


macro dictCols(sql, ks, vs) # create dictionary, one column as keys, one as values
	return quote
		data = SQLite.query(DB, $sql)
		dct = Dict{eltype(data[$ks][1]), eltype(data[$vs][1])}()
		for k in 1:size(data)[1]
			dct[get(data[$ks][k])] = get(data[$vs][k])
		end
		dct
	end
end

i64(a::Float64) = round(Int64, a)
i64(a::AbstractString) = parse(Int64, a)

function createSchema()
	@trans if size(SQLite.query(DB, "PRAGMA stats"))[1] == 1
		SQLite.execute!(DB, "CREATE TABLE Locations (location INTEGER PRIMARY KEY, label TEXT, rack INTEGER, level INTEGER, bin INTEGER, UNIQUE(label), UNIQUE(rack, level, bin))")
		SQLite.execute!(DB, "CREATE TABLE Distances  (lmin INTEGER, lmax INTEGER, distance REAL, FOREIGN KEY(lmin) REFERENCES Locations(location), FOREIGN KEY(lmax) REFERENCES Locations(location), UNIQUE (lmin, lmax))")	
		SQLite.execute!(DB, "CREATE TABLE SKUs (prtnum INTEGER PRIMARY KEY, location INTEGER, FOREIGN KEY(location) REFERENCES Locations(location))")
		SQLite.execute!(DB, "CREATE TABLE OrderLine (ordnum INTEGER, prtnum INTEGER, qty INTEGER, FOREIGN KEY(prtnum) REFERENCES SKUs(prtnum))")
		SQLite.execute!(DB, "CREATE INDEX OrderLineordnum on OrderLine(ordnum)")
	end
end

function importOrders()
	xl = readxlsheet("g:/Heinemann/ord_line_raw_data.xlsx", "LextEdit Export 08-24-16 02.28")

	sku = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum, location) VALUES(?, NULL)")
	lne = SQLite.Stmt(DB, "INSERT INTO OrderLine (ordnum, prtnum, qty) VALUES(?, ?, ?)")

	@trans for r in 2:size(xl)[1]
		SQLite.bind!(sku, 1, i64(xl[r, 4]))
		SQLite.execute!(sku)
		SQLite.bind!(lne, 1, i64(xl[r, 2]))
		SQLite.bind!(lne, 2, i64(xl[r, 4]))
		SQLite.bind!(lne, 3, i64(xl[r, 5]))
		SQLite.execute!(lne)	
	end
end

function labelLocations()
	loc = SQLite.Stmt(DB, "INSERT INTO Locations (label, rack, level, bin) VALUES(?, ?, ?, ?)")
	@trans for rack in 81:-1:1, level in [10:10:90; 91], bin in 8:-1:1				
		SQLite.bind!(loc, 1, @sprintf "F-%02d-%02d-%02d" rack level bin)
		SQLite.bind!(loc, 2, rack)
		SQLite.bind!(loc, 3, level)
		SQLite.bind!(loc, 4, bin)
		SQLite.execute!(loc)
	end
end

function distanceFill()
	locs = @dictCols("SELECT location, label from Locations", :label, :location)
	loc =  SQLite.Stmt(DB, "SELECT location From Locations WHERE label=?")
	dist = SQLite.Stmt(DB, "INSERT INTO Distances (lmin, lmax, distance) VALUES(?, ?, ?)")
	@trans for rack1 in 81:-1:1, level1 in [10:10:90; 91], bin1 in 8:-1:1
		lmin = locs[@sprintf "F-%02d-%02d-%02d" rack1 level1 bin1]
		SQLite.bind!(dist, 1, lmin)
		for rack2 in 81:-1:1, level2 in [10:10:90; 91], bin2 in 8:-1:1
			lmax = locs[@sprintf "F-%02d-%02d-%02d" rack2 level2 bin2]
			if lmax > lmin
				SQLite.bind!(dist, 2, lmax)
				SQLite.bind!(dist, 3, Bay2Bay_Costs.distance(rack1, level1, bin1, rack2, level2, bin2))
				SQLite.execute!(dist)
			end
		end
	end
end

function resetSKUlocations()
	xl = readxlsheet("G:/Heinemann/Travel Sequence/P81 SKU Location R1.xlsx", "SKU Qty Loc")
	prt = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum, location) VALUES(?, NULL)")
	sku = SQLite.Stmt(DB, "UPDATE OR IGNORE SKUs SET location=(SELECT location from Locations where label=?) WHERE prtnum=?")
	@trans for r in 2:size(xl)[1]
		SQLite.bind!(prt, 1, i64(xl[r, 1]))
		SQLite.execute!(prt)
		SQLite.bind!(sku, 1, xl[r, 4])
		SQLite.bind!(sku, 2, i64(xl[r, 1]))
		SQLite.execute!(sku)
	end
end


function ordersInRacksTask()
	for o in i64("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		locs = i64("SELECT SKUs.location FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY SKUs.location DESC", :location)
		if size(locs)[1] > 0
			produce(o, locs)
		end
	end
end

function distanceByLocation(l1, l2)
	@denull(Float64, SQLite.query(DB, "SELECT distance FROM Distances WHERE lmin=? AND lmax=?", values=[min(l1, l2), max(l1, l2)]), :distance)[1]
end



function orderNumbers()
	i64("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
end

function partnumsInRacks()
	i64("SELECT DISTINCT SKUs.prtnum FROM OrderLine, SKUs where OrderLine.prtnum = SKUs.prtnum and SKUs.location IS NOT NULL ORDER BY SKUs.prtnum", :prtnum)
end

function partnumsInRackPerOrder(o)
	i64("SELECT DISTINCT OrderLine.prtnum FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY OrderLine.prtnum", :prtnum)
end

function partVelocities()
	@dictCols("SELECT prtnum, COUNT(prtnum) AS cnt FROM OrderLine GROUP BY prtnum", :prtnum, :cnt)
end

function initialise()
	createSchema()
	importOrders()
	labelLocations()
	distanceFill()
	resetSKUlocations()
end

reset = !isfile("Databases/HIA_Orders.sqlite")
const DB = SQLite.DB("Databases/HIA_Orders.sqlite")
SQLite.execute!(DB, "PRAGMA foreign_keys = ON")
if reset	
	initialise()
end

end



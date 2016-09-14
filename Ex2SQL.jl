#=

Ex2SQL.jl

https://github.com/JuliaDB/SQLite.jl
=#

using SQLite
using ExcelReaders

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
#

i64(a::Float64) = round(Int64, a)
i64(a::AbstractString) = parse(Int64, a)

	
function DB()
	db = SQLite.DB("G:\\Heinemann\\HIA_Orders.sqlite")
	SQLite.execute!(db, "PRAGMA foreign_keys = ON")
	@trans if size(SQLite.query(db, "PRAGMA stats"))[1] == 1
		SQLite.execute!(db, "CREATE TABLE Locations (location INTEGER PRIMARY KEY, label TEXT, UNIQUE(label))")
		SQLite.execute!(db, "CREATE TABLE Distances  (location1 INTEGER, location2, distance REAL, FOREIGN KEY(location1) REFERENCES Locations(location), FOREIGN KEY(location2) REFERENCES Locations(location), UNIQUE (location1, location1))")	
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
	@trans for rack in 81:-1:1
		for bin in 8:-1:1
			for level in [10:10:90; 91]				
				SQLite.bind!(loc, 1, @sprintf "F-%02d-%02d-%02d" rack level bin)
				SQLite.execute!(loc)
			end
		end
	end
end

db = DB()
importOrders(db)
labelLocations(db)

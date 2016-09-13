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

function createDB()
	db = SQLite.DB("G:\\Heinemann\\HIA_Orders.sqlite")
	SQLite.execute!(db, "PRAGMA foreign_keys = ON")
	if size(SQLite.query(db, "PRAGMA stats"))[1] == 1
		@trans begin
			SQLite.execute!(db, "CREATE TABLE Locations (location INTEGER PRIMARY KEY, label TEXT) ")
			SQLite.execute!(db, "CREATE TABLE Distances  (location1 INTEGER, location2, distance REAL)")	
			SQLite.execute!(db, "CREATE UNIQUE INDEX Dl1l2 ON Distances (location1, location1)")
			SQLite.execute!(db, "CREATE TABLE SKUs (prtnum INTEGER PRIMARY KEY, location INTEGER) ") #FOREIGN KEY(location) REFERENCES(Locations.location)")
			SQLite.execute!(db, "CREATE TABLE OrderLine (ordnum INTEGER, prtnum INTEGER, qty INTEGER) ") #FOREIGN KEY(prtnum) REFERENCES(SKUs.prtnum)")
			SQLite.execute!(db, "CREATE INDEX OrderLineNum ON OrderLine(ordnum)")
		end
	end
	return db
end

db = createDB()
xl = readxlsheet("g:/Heinemann/ord_line_raw_data.xlsx", "LextEdit Export 08-24-16 02.28")

sku = SQLite.Stmt(db, "INSERT OR IGNORE INTO SKUs (prtnum, location) VALUES(?, NULL)")
lne = SQLite.Stmt(db, "INSERT INTO OrderLine (ordnum, prtnum, qty) VALUES(?, ?, ?)")

i64(a::Float64) = round(Int64, a)
i64(a::AbstractString) = parse(Int64, a)

@trans for r in 2:size(xl)[1]
	SQLite.bind!(sku, 1, i64(xl[r, 4]))
	SQLite.execute!(sku)
	SQLite.bind!(lne, 1, i64(xl[r, 2]))
	SQLite.bind!(lne, 2, i64(xl[r, 4]))
	SQLite.bind!(lne, 3, i64(xl[r, 5]))
	SQLite.execute!(lne)	
end

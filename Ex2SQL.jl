#=

Ex2SQL.jl

https://github.com/JuliaDB/SQLite.jl
using SQLite
function createDB()
	SQLite.execute!("CREATE TABLE Locations IF NOT EXISTS (location INTEGER PRIMARY KEY, label TEXT) UNIQUE(label)")
	SQLite.execute!("CREATE TABLE Distances IF NOT EXISTS (location1 INTEGER, location2, distance REAL) UNIQUE(location1, location2)")	
	SQLite.execute!("CREATE TABLE SKUs IF NOT EXISTS (prtnum INTEGER PRIMARY KEY, location INTEGER) FOREIGN KEY(location) REFERENCES(Locations.location)")
	SQLite.execute!("CREATE TABLE Orders IF NOT EXISTS (ordnum INTEGER PRIMARY KEY, prtnum INTEGER, qty INTEGER) FOREIGN KEY(prtnum) REFERENCES(SKUs.prtnum)")")
end
db = SQLite.DB("G:\\Heinemann\\HIA_Orders.sqlite")
SQLite.execute!("PRAGMA foreign_keys = ON")
createDB()
=#





#=

Ex2SQL.jl

https://github.com/JuliaDB/SQLite.jl
=#

module HIADB

using Base.Dates
using SQLite
using ExcelReaders
using Bay2Bay_Costs


include("utils.jl")


function createSchema()
	@iif size(SQLite.query(DB, "PRAGMA stats"))[1] == 1
	@trans begin
		SQLite.execute!(DB, "CREATE TABLE Locations (location INTEGER PRIMARY KEY, label TEXT, rack INTEGER, level INTEGER, bin INTEGER, UNIQUE(label))")
		SQLite.execute!(DB, "CREATE INDEX Locationsrack on Locations(rack)")
		SQLite.execute!(DB, "CREATE INDEX Locationslevel on Locations(level)")
		SQLite.execute!(DB, "CREATE INDEX Locationsbin on Locations(bin)")
		
		SQLite.execute!(DB, "CREATE TABLE Distances  (lmin INTEGER, lmax INTEGER, distance REAL, FOREIGN KEY(lmin) REFERENCES Locations(location), FOREIGN KEY(lmax) REFERENCES Locations(location), UNIQUE (lmin, lmax))")	
		
		SQLite.execute!(DB, "CREATE TABLE SKUs (prtnum INTEGER PRIMARY KEY, newlocation INTEGER, lngdsc TEXT, FOREIGN KEY(newlocation) REFERENCES Locations(location))")
		
		SQLite.execute!(DB, "CREATE TABLE OrderLine (day INTEGER, ordnum INTEGER, prtnum INTEGER, qty INTEGER, FOREIGN KEY(prtnum) REFERENCES SKUs(prtnum))")
		SQLite.execute!(DB, "CREATE INDEX OrderLineordnum on OrderLine(ordnum)")
		SQLite.execute!(DB, "CREATE INDEX OrderLineprtnum on OrderLine(prtnum)")
		SQLite.execute!(DB, "CREATE INDEX OrderLineday on OrderLine(day)")
		
		SQLite.execute!(DB, "CREATE TABLE Picks (day INTEGER, time TEXT, ordnum INTEGER, prtnum INTEGER, location INTEGER, qty INTEGER, FOREIGN KEY(prtnum) REFERENCES SKUs(prtnum), FOREIGN KEY(location) REFERENCES Locations(location))")
		SQLite.execute!(DB, "CREATE INDEX Picksday on Picks(day)")
		SQLite.execute!(DB, "CREATE INDEX Picksprtnum on Picks(prtnum)")
		SQLite.execute!(DB, "CREATE INDEX Pickslocation on Picks(location)")
		
		SQLite.execute!(DB, "CREATE TABLE RPSchema (table_name TEXT, column_name TEXT, data_type TEXT, nullable integer)")
		SQLite.execute!(DB, "CREATE UNIQUE INDEX RPSchemaTableColumn ON RPSchema(table_name, column_name)")
		
		SQLite.execute!(DB, "CREATE TABLE Storage (location INTEGER, prtnum INTEGER, qty INTEGER, fifodte TEXT, FOREIGN KEY(location) REFERENCES Locations(location))")
		SQLite.execute!(DB, "CREATE INDEX Storagelocation on Storage(location)")
		SQLite.execute!(DB, "CREATE INDEX Storageprtnum on Storage(prtnum)")
		
		SQLite.execute!(DB, "CREATE TABLE Inventory(location INTEGER, prtnum INTEGER, qty INTEGER, lodnum TEXT, caseid TEXT, piece TEXT, footprint INTEGER, fifoday INTEGER, fifotime TEXT, reckey INTEGER, whid TEXT, FOREIGN KEY(location) REFERENCES Locations(location), FOREIGN KEY(prtnum) REFERENCES SKUs(prtnum))")
		SQLite.execute!(DB, "CREATE INDEX Inventorylocation on Inventory(location)")
		SQLite.execute!(DB, "CREATE INDEX Inventoryprtnum on Inventory(prtnum)")
		
	end
end

function fillInv()
	sku = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum) VALUES(?)")
	dsc = SQLite.Stmt(DB, "Update SKUs set lngdsc=? WHERE prtnum=?")
	loc = SQLite.Stmt(DB, "INSERT OR IGNORE INTO Locations (label, rack, level, bin) VALUES(?, ?, ?, ?)")
	inv = SQLite.Stmt(DB, "INSERT INTO Inventory (location, prtnum, qty, lodnum, caseid, piece, footprint, fifoday, fifotime, reckey, whid) values((SELECT location FROM Locations WHERE label=?), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
	
	for xls in ["inv_BBINA01" "inv_bin01" "inv_CLDRMST" "inv_HWLFTZRH" "inv_HWLFTZRL" "inv_PALR01"]
		xl = @sheet(xls *".xls", xls)
		@trans for r in 2:size(xl)[1]
			prtnum = i64(xl[r,8])
			@query! sku (prtnum)
			@query! dsc (xl[r,10], prtnum)
			locs = split(xl[r,4], '-')
			if size(locs)[1] >= 3
				if locs[1] == "F"
					@query! loc (xl[r,4], locs[2], locs[3], locs[4])
				else
					@query! loc (xl[r,4], locs[1], locs[2], locs[3])
				end
			else
				@query! loc (xl[r,4], 0, 0, 0)
			end
			@query! inv (xl[r,4], prtnum, i64(xl[r,11]), xl[r,5], xl[r,6], xl[r,7], xl[r,12], iday(xl[r,16]), ttime(xl[r,16]), xl[r,56], xl[r,70])
		end
	end
end
		
function fillSKUs()
	xl = @sheet("partnum_descr.xls", "partnum_descr")
	sku = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum) VALUES(?)")
	dsc = SQLite.Stmt(DB, "Update SKUs set lngdsc=? WHERE prtnum=?")
	@trans for r in 2:size(xl)[1]
		prtnum = i64(split(xl[r, 1], "|")[1])
		if prtnum > 0
			@query! sku (prtnum)
			@query! dsc (xl[r,2], prtnum)
		end
	end
end

function fillRPSchema()
	xl = @sheet("Schema.xls", "Schema")
	rp = SQLite.Stmt(DB, "INSERT OR IGNORE INTO RPSchema (table_name, column_name, data_type, nullable) VALUES(?, ?, ?, ?)")
	@trans for r in 2:size(xl)[1]
		@query! rp (xl[r, 1], xl[r, 2], xl[r, 3], xl[r, 4]=="YES" ? 1:0)
	end
end

function fillOrders(yr)
	@iif isfile("Picks_20$yr.xls")
	xl = @sheet("Picks_20$yr.xls", "Picks_20$yr")
	loc = SQLite.Stmt(DB, "INSERT OR IGNORE INTO Locations (label, rack, level, bin) VALUES(?, ?, ?, ?)")
	pk = SQLite.Stmt(DB, "INSERT INTO Picks (day, time, ordnum, prtnum, location, qty) VALUES(?, ?, ?, ?, (select location from locations where label=?), ?)")
	@trans for r in 2:size(xl)[1]
		@query! loc (xl[r,5], split(xl[r,5], '-')...)
		@query! pk (iday(xl[r,2]), ttime(xl[r,2]), i64(xl[r,4]), i64(xl[r,3]), xl[r,5], i64(xl[r,1]))
	end
end

function importOrders(yr)
	xl = @sheet("ord_line_raw_20$yr.xls", "ord_line_raw_20$yr")
	sku = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum, newlocation) VALUES(?, NULL)")
	lne = SQLite.Stmt(DB, "INSERT INTO OrderLine (day, ordnum, prtnum, qty) VALUES(?, ?, ?, ?)")

	@trans for r in 2:size(xl)[1]
		@query! sku (i64(xl[r, 3]))
		@query! lne (iday(xl[r, 1]), i64(xl[r, 2]), i64(xl[r, 3]), i64(xl[r, 4]))
	end
end

function labelLocations()
	loc = SQLite.Stmt(DB, "INSERT OR IGNORE INTO Locations (label, rack, level, bin) VALUES(?, ?, ?, ?)")
	@trans for rack in 81:-1:1, level in [10:10:90; 91], bin in 8:-1:1				
		@query! loc ((@sprintf "F-%02d-%02d-%02d" rack level bin), rack, level, bin)
	end
	@trans for rack in 1:19, level in 10:10:90, bin in 1:60		
		@query! loc ((@sprintf "%02d-%02d-%02d" rack level bin), rack, level, bin)
	end
end

function distanceFill()
	locs = @dictCols("SELECT location, label from Locations", :label, :location)
	loc =  SQLite.Stmt(DB, "SELECT location From Locations WHERE label=?")
	dist = SQLite.Stmt(DB, "INSERT INTO Distances (lmin, lmax, distance) VALUES(?, ?, ?)")
	@trans for rack1 in 81:-1:1, level1 in [10:10:90; 91], bin1 in 8:-1:1
		lmin = locs[@sprintf "F-%02d-%02d-%02d" rack1 level1 bin1]
		for rack2 in 81:-1:1, level2 in [10:10:90; 91], bin2 in 8:-1:1
			lmax = locs[@sprintf "F-%02d-%02d-%02d" rack2 level2 bin2]
			if lmax > lmin
				@query! dist (lmin, lmax, Bay2Bay_Costs.distance(rack1, level1, bin1, rack2, level2, bin2))
			end
		end
	end
end

function currentStorage()
	xl = @sheet("current_rack_storage.xls", "current_rack_storage")
	sku = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum, lngdsc, newlocation) VALUES(?, NULL, NULL)")
	dsc = SQLite.Stmt(DB, "UPDATE SKUs SET lngdsc=? WHERE prtnum=?")
	cloc  = SQLite.Stmt(DB, "INSERT OR IGNORE INTO Storage(location, prtnum, qty) VALUES((SELECT location from Locations WHERE label=?),?,?)")
	@trans for r in 2:size(xl)[1]
		@query! sku (i64(xl[r, 2]))
		@query! dsc (xl[r, 5], i64(xl[r, 2]))
		@query! cloc (xl[r, 3], i64(xl[r, 2]), i64(xl[r,4]))
	end
end

function resetSKUlocations()
	xl = @sheet("Travel Sequence/P81 SKU Location R1.xlsx", "SKU Qty Loc")
	prt = SQLite.Stmt(DB, "INSERT OR IGNORE INTO SKUs (prtnum, lngdsc, newlocation) VALUES(?, NULL, NULL)")
	sku = SQLite.Stmt(DB, "UPDATE OR IGNORE SKUs SET newlocation=(SELECT location from Locations where label=?) WHERE prtnum=?")
	@trans for r in 2:size(xl)[1]
		@query! prt (i64(xl[r, 1]))
		@query! sku (xl[r, 4], i64(xl[r, 1]))
	end
end

function ordersInRacksTask()
	for o in i64("SELECT DISTINCT ordnum FROM OrderLine ORDER BY ordnum", :ordnum)
		locs = i64("SELECT DISTINCT SKUs.location FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY SKUs.location DESC", :location)
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

function partnumsInOrders()
	i64("SELECT DISTINCT SKUs.prtnum FROM OrderLine, SKUs where OrderLine.prtnum = SKUs.prtnum and SKUs.location IS NOT NULL ORDER BY SKUs.prtnum", :prtnum)
end

function partnumsInLocationPerOrder(o)
	i64("SELECT DISTINCT OrderLine.prtnum FROM OrderLine, SKUs WHERE OrderLine.ordnum=$o AND OrderLine.prtnum=SKUs.prtnum AND SKUs.location IS NOT NULL ORDER BY OrderLine.prtnum", :prtnum)
end

function ordCounts()
	@dictCols("SELECT prtnum, COUNT(prtnum) AS cnt FROM OrderLine GROUP BY prtnum", :prtnum, :cnt)
end

function ordCountsByMonth()
	SQLite.query(DB, "SELECT prtnum, day / 100 AS yrmnth, COUNT(prtnum) as cnt FROM OrderLine GROUP BY prtnum, yrmnth")
end

function ordCountsByQtr()
	SQLite.query(DB, "SELECT prtnum, day / 10000 as yr , (((day / 100) % 100) /4)+1 as qtr, COUNT(prtnum) as cnt FROM OrderLine GROUP BY prtnum, yr, qtr")
end

function SKUs()
	@dictCols("SELECT prtnum, lngdsc FROM SKUs", :prtnum, :lngdsc)
end

function SKUsInStorage()
	SQLite.query(DB, "
	WITH Sto(prtnum, stoloc, qty) as (SELECT Storage.prtnum, Locations.label, Storage.qty FROM Storage INNER JOIN Locations ON Storage.location=Locations.location)
	SELECT SKUs.prtnum as prtnum, SKUs.lngdsc as lngdsc, Sto.stoloc as stoloc, Sto.qty as qty FROM SKUs INNER JOIN Sto ON SKUs.prtnum=Sto.prtnum
	")
end

function initialise()
	createSchema()
	fillSKUs()
	fillInv()
	for y in 16:-1:13
		importOrders(y)
		fillOrders(y)
	end
	labelLocations()
	distanceFill()
	resetSKUlocations()
	currentStorage()
end

exists = isfile("Databases/HIA_Orders.sqlite")
const DB = SQLite.DB("Databases/HIA_Orders.sqlite")
SQLite.execute!(DB, "PRAGMA foreign_keys = ON")

end

module sqtest

using SQLite

DB = SQLite.DB()

SQLite.execute!(DB, "CREATE TABLE test (t1 INTEGER PRIMARY KEY, t2 INTEGER)")


macro insert(stmt, binds)
	return quote
		for i in 1:length($binds)
			SQLite.bind!($stmt, i, $binds[i])
		end
		SQLite.execute!($stmt)
	end
end


s = SQLite.Stmt(DB, "INSERT INTO test (t2) VALUES(?)")

@insert s (3)

println(SQLite.query(DB, "Select * from test"))

SQLite.execute!(DB, "DROP TABLE test")

end
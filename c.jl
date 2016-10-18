
tprtnum = SQLite.query(HIADB.DB, "SELECT table_name from RPSchema WHERE column_name = \"prtnum\"")
wtbls = []
for t in 1:size(tprtnum)[1]
	sql = "SELECT table_name from RPSchema WHERE column_name=\"wh_id\" and table_name=\"$(get(tprtnum[1][t]))\""
    tb = SQLite.query(HIADB.DB, sql)
    if size(tb)[1] > 0
        push!(wtbls, get(tb[1][1]))
    end
end

tbls=[]
for t in wtbls
	sql = "SELECT table_name from RPSchema WHERE column_name=\"bldg_id\" and table_name=\"$t\""
    tb = SQLite.query(HIADB.DB, sql)
    if size(tb)[1] > 0
        push!(tbls, get(tb[1][1]))
    end
end

for t in tbls
	sql = "SELECT table_name, column_name from RPSchema WHERE table_name=\"$t\""
    tb = SQLite.query(HIADB.DB, sql)
	for k in 1:size(tb)[1]
		@printf "%s = %s\n" get(tb[1][k]) get(tb[2][k])
    end
end




cd(ENV["USERPROFILE"] * "/Documents")
unshift!(LOAD_PATH, "GitHub/PickingLogic/")

using HIADB

if ! HIADB.exists	
	HIADB.initialise()
else
	HIADB.fillInv()
end

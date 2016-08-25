#=

create grid for excel to view
will it be too big ?

=#


tab = open("Bay2Bay.txt", "w")
@printf tab "\t"
for rackH in 81:-1:1, binH in 8:-1:1, levelH in [10:10:90; 91]
	@printf tab "F-%02d-%02d-%02d\t" rackH levelH binH
end
@printf tab "\n"

for rackV in 81:-1:1, binV in 8:-1:1, levelV in [10:10:90; 91]
	@printf tab "F-%02d-%02d-%02d\n" rackV levelV binV
end

close(tab)



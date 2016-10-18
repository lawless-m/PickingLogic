
function sortloc(x, y)
	a = x
	b = y
	ca = replace(a, ['-', '+'], "")
	cb = replace(b, ['-', '+'], "")
	if ca != cb
		return ca < cb
	end
 
	if (s=search(a, ca[1])) == search(b, ca[1])
		return length(a) - s > length(b) -s
	end
	
	search(a, ca[1]) < search(b, ca[1])
end

t = ["C+", "C++", "C+++", "-C", "C", "--C", "-C+", "-C++"]

println(sort(t, lt=sortloc,rev=true))


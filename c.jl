function BLabels()
	[ []
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 1:1, l in 10:10:60, b in [1:24; 31:55]])	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 3:8, l in 10:10:60, b in [1:24; 31:55]])	
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 9:19, l in 10:10:60, b in 1:25] 	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 2:2, l in 70:70, b in 31:55]  	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 3:3, l in 70:70, b in [1:24; 31:55]]  	)
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 4:4, l in 70:70, b in [17:24; 31:55]] )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 5:7, l in 70:70, b in 31:55]  )
	;vec(	[@sprintf("%02d-%02d-%02d", r, l, b) for r in 8:11, l in 70:70, b in 1:24]  )	
	]
end

BLabels()


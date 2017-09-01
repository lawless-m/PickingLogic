Julia code developed to execute queries against the Red Prairie WMS System devloped while on internship.
RPCLient.jl is generic and will connec tto any Red Prairie installation

What is not included in this code is a set of serialized credentials, these are a simple Julio Dict of the form
("host"=>"http://$host:$port", "un"=>$un, "pw"=>$pw)

utils.jl contains code for serialising

HIARP contains code tailored to our particular install but all the queries are contained in these two files for reference.

DBScan is a tool for searching every field in the database for a particular value,
useful when the only guy that knows the WMS leaves and the whole department suddenly relies on the intern to keep things going


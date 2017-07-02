# close leaked connections
cons <- dbListConnections(RMySQL::MySQL())
for(con in cons) dbDisconnect(con) 

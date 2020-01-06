#-------------------------------------------------------------------------------
# Name:        0_COAdb_creator.r
# Purpose:     Create an empty, new COA databases
# Author:      Christopher Tracey
# Created:     2019-03-15
# Updated:     
#
# Updates:
# * 2019-03-15 - minor cleanup and documentation
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------

if (!requireNamespace("here", quietly=TRUE)) install.packages("here")
  require(here)
if (!requireNamespace("RSQLite", quietly=TRUE)) install.packages("RSQLite")
  require(RSQLite)

## create an empty sqlite db

# Set input paths ----
databasename <- "nha_recs.sqlite" 
databasename <- here("_data","databases",databasename)

# connect to the database
db <- dbConnect(SQLite(), dbname=databasename) # creates an empty NHA database

# disconnect the db
dbDisconnect(db)

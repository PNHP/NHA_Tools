#-------------------------------------------------------------------------------
# Name:        NHA_databaseCreator.r
# Purpose:     Update the ET
# Author:      Christopher Tracey
# Created:     2019-03-09
# Updated:     
#
# Updates:
# * 2019-02-20 - 
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
require(RSQLite)

# Set input paths ----
databasename <- "NHA_Database.sqlite" 
databasename <- here("databases",databasename)

# connect to the database
db <- dbConnect(SQLite(), dbname=databasename) # creates an empty COA database

# disconnect the db
dbDisconnect(db)

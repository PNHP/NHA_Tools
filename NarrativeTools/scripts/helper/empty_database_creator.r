#This should only be run the first time, to create the database table to hold the data

if (!requireNamespace("here", quietly=TRUE)) install.packages("here")
  require(here)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
  require(RSQLite)

## create an empty sqlite db

# Set input paths ----
databasename <- "NaturalHeritageAreas.sqlite" 
databasename <- here("_data", "databases", databasename)
# connect to the database
db <- dbConnect(SQLite(), dbname=databasename) # creates an empty COA database

# create the master table
#names_nhatable <- c("SITE_NAME","SITE_TYPE","SIG_RANK","BRIEF_DESC","COUNTY","Muni","USGS_QUAD","ASSOC_NHA","PROTECTED_LANDS","NHA_JOIN_ID")
#types_nhatable <- c("TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","INTEGER")
#names(types_nhatable) <- names_nhatable
#dbCreateTable(db, "nha_main", types_nhatable)

# CREATE TABLE `nha_main` (
#   `SITE_NAME`	TEXT,
#   `SITE_TYPE`	TEXT,
#   `NHA_JOIN_ID`	INTEGER,
#   `SIG_RANK`	TEXT,
#   `SIG_SCORE`	NUMERIC,
#   `BRIEF_DESC`	TEXT,
#   `COUNTY`	TEXT,
#   `Muni`	TEXT,
#   `USGS_QUAD`	TEXT,
#   `ASSOC_NHA`	TEXT,
#   `PROTECTED_LANDS`	TEXT
# );


# disconnect the db
dbDisconnect(db)


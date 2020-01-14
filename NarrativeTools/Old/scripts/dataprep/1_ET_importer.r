#-------------------------------------------------------------------------------
# Name:        ET_importer.r
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
if (!requireNamespace("openxlsx", quietly=TRUE)) install.packages("openxlsx")
require(openxlsx)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
require(RSQLite)

# paths
ETpath <- "P:/Conservation Programs/Natural Heritage Program/Data Management/Biotics Database Areas/Element Tracking/current element lists" 

#get the threats template
ET <- list.files(path=ETpath, pattern=".xlsx$")  # --- make sure your excel file is not open.
ET
#look at the output and choose which shapefile you want to run
#enter its location in the list (first = 1, second = 2, etc)
n <- 4
ETfile <- paste(ETpath,ET[n],sep="/")

#get a list of the sheets in the file
ETsheets <- getSheetNames(ETfile)
#look at the output and choose which excel sheet you want to load
ETsheets # list the sheets, you probably want the one that's called "Query Output"
n <- 1 # enter its location in the list (first = 1, second = 2, etc)

ElementTracking <- read.xlsx(xlsxFile=ETfile, sheet=ETsheets[n], skipEmptyRows=FALSE, rowNames=FALSE)

# rename two problematic fields
names(ElementTracking)[names(ElementTracking) == 'ELEMENT.SUBNATIONAL.ID'] <- 'ELSUBID'
names(ElementTracking)[names(ElementTracking) == 'SCIENTIFIC.NAME'] <- 'SNAME'
names(ElementTracking)[names(ElementTracking) == 'COMMON.NAME'] <- 'SCOMNAME'
names(ElementTracking)[names(ElementTracking) == 'G.RANK'] <- 'GRANK'
names(ElementTracking)[names(ElementTracking) == 'S.RANK'] <- 'SRANK'
names(ElementTracking)[names(ElementTracking) == 'TRACKING.STATUS'] <- 'EO_TRACK'
names(ElementTracking)[names(ElementTracking) == 'PA.FED.STATUS'] <- 'USESA'
names(ElementTracking)[names(ElementTracking) == 'PA.STATUS'] <- 'SPROT'
names(ElementTracking)[names(ElementTracking) == 'PBS.STATUS'] <- 'PBSSTATUS'
names(ElementTracking)[names(ElementTracking) == 'SENSITIVE.SPECIES'] <- 'SENSITV_SP'

# drop unneeded columns
ElementTracking <- ElementTracking[c("ELSUBID","ELCODE","SNAME","SCOMNAME","GRANK","SRANK","EO_TRACK","USESA","SPROT","PBSSTATUS","SENSITV_SP")]

# cleanup
rm(n)

# insert in the sqlite database
databasename <- "NHA_Database.sqlite" 
databasename <- here("databases",databasename)
db <- dbConnect(SQLite(), dbname=databasename) # connect to the database
  dbWriteTable(db, "ElementTracking", ElementTracking, overwrite=TRUE) # write the output to the sqlite db
dbDisconnect(db) # disconnect the db
#m(COA_references)

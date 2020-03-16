#-------------------------------------------------------------------------------
# Name:        NHA_statuschecks
# Purpose:     check for more NHAs ready for templates, completed, etc.
# Author:      Anna Johnson
# Created:     2019-12-30
#
# Updates:
# 
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------
#Build SQL queries for NHA database to ask the questions you want answered

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

# load in the paths and settings file (which contains the rest of the libraries needed)
source(here::here("scripts", "0_PathsAndSettings.r"))

#Q: what sites are completed, not published in SW (and thus ready for NHA templates to be generated?)
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nhas <- arc.select(nha, where_clause="STATUS = 'NP'") #first pull out NP status sites
NHA_JoinID_list <- as.vector(selected_nhas$NHA_JOIN_ID)
NHA_JoinID_list <- as.list(NHA_JoinID_list)

SW_Counties <- c("Allegheny","Butler","Beaver","Armstrong","Greene","Fayette","Indiana","Lawrence","Washington","Westmoreland")
SQLquery_Counties <- paste("COUNTY IN(",paste(toString(sQuote(SW_Counties)),collapse=", "), ")") #select all NHAs which are in the SW


nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nhas <- arc.select(nha, where_clause="created_user='ajohnson' AND STATUS = 'NP'") #NP sites that Anna created

#query NHA database of sites for which templates have been created
db_nha <- dbConnect(SQLite(), dbname=nha_databasename)

nha_indb <- dbGetQuery(db_nha, "SELECT * FROM nha_runrecord") #select all rows of NHA site summary table
dbDisconnect(db_nha)

Notemplates <- subset(selected_nhas, !(selected_nhas$NHA_JOIN_ID %in% nha_indb$NHA_JOIN_ID))
Notemplates <- subset(nha_indb, nha_indb$date_run == "2020-03-04") #or alternate, select by diff paramater
Notemplates$NHA_JOIN_ID
#Notemplates==dataframe of NHAs to run template generator for

#Pull in list of NHAs w/ political boundaries and then check against the list of sites w/o templates, to only run sites with political boundaries defined AND lacking templates

PBs <- read.csv("PB_list.csv")

PBs_list <- unique(PBs$NHA_JOIN_ID)

Notemplates <- Notemplates[which(Notemplates$NHA_JOIN_ID %in% PBs_list),]


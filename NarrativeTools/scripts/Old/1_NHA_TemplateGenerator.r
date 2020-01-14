#-------------------------------------------------------------------------------
# Name:        NHA_TemplateGenerator.r
# Purpose:     Create a Word template for NHA content
# Author:      Anna Johnson
# Created:     2019-03-21
# Updated:     
#
# Updates:
# 
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------

# check and load required libraries
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
  require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
  require(RSQLite)
if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr")
  require(knitr)
if (!requireNamespace("xtable", quietly = TRUE)) install.packages("xtable")
  require(xtable)
if (!requireNamespace("flextable", quietly = TRUE)) install.packages("flextable")
  require(flextable)
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
  require(dplyr)
if (!requireNamespace("dbplyr", quietly = TRUE)) install.packages("dbplyr")
  require(dbplyr)
if (!requireNamespace("rmarkdown", quietly = TRUE)) install.packages("rmarkdown")
  require(rmarkdown)
if (!requireNamespace("tmap", quietly = TRUE)) install.packages("tmap")
  require(tmap)
if (!requireNamespace("OpenStreetMap", quietly = TRUE)) install.packages("OpenStreetMap")
  require(OpenStreetMap)
if (!requireNamespace("openxlsx", quietly = TRUE)) install.packages("openxlsx")
  require(openxlsx)
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
require(sf)

# if (!requireNamespace("odbc", quietly = TRUE)) install.packages("odbc")
#   require(odbc)

# note: we need to install 64bit java: https://www.java.com/en/download/manual.jsp

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

# open the NHA feature class and select and NHA
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
#selected_nha <- arc.select(nha, where_clause="SITE_NAME='Allegheny River Pool #6' AND STATUS = 'NP'")  # Carnahan Run at Stitts Run Road  AND STATUS ='NP'
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nha <- arc.select(nha, where_clause="SITE_NAME='Muddy Creek Marsh' AND STATUS='NR'")  # Carnahan Run at Stitts Run Road  AND STATUS ='NP'

nha_siteName <- selected_nha$SITE_NAME
nha_foldername <- foldername(nha_siteName) # this now uses a user-defined function
nha_filename <- paste(nha_foldername,"_",gsub("[^0-9]", "", Sys.Date() ),".docx",sep="")

selected_nha$nha_filename <- nha_filename

# convert geometry to simple features for the map
nha_sf <- arc.data2sf(selected_nha)
a <- st_area(nha_sf) #calculate area
a <- a*0.000247105 #convert m2 to acres
selected_nha$Acres <- as.numeric(a)

## Build the Species Table #########################
# open the related species table and get the rows that match the NHA join id from above
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep="")) #(here::here("_data", "NHA_newTemplate.gdb",""))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies)  #, where_clause=paste("NHD_JOIN_ID","=",sQuote(selected_nha$NHA_JOIN_ID),sep="") 
selected_nha_relatedSpecies <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==selected_nha$NHA_JOIN_ID),] #! consider integrating with the previous line the select statement

SD_speciesTable <- selected_nha_relatedSpecies[c("EO_ID","ELCODE","SNAME","SCOMNAME","ELEMENT_TYPE","G_RANK","S_RANK","S_PROTECTI","PBSSTATUS","LAST_OBS_D","BASIC_EO_R","SENSITIVE_")] # subset to columns that are needed.

colnames(SD_speciesTable)[which(names(SD_speciesTable)=="G_RANK")] <- "GRANK"
colnames(SD_speciesTable)[which(names(SD_speciesTable)=="S_RANK")] <- "SRANK"
colnames(SD_speciesTable)[which(names(SD_speciesTable)=="S_PROTECTI")] <- "SPROT"
colnames(SD_speciesTable)[which(names(SD_speciesTable)=="LAST_OBS_D")] <- "LASTOBS"
colnames(SD_speciesTable)[which(names(SD_speciesTable)=="BASIC_EO_R")] <- "EORANK"
colnames(SD_speciesTable)[which(names(SD_speciesTable)=="SENSITIVE_")] <- "SENSITIVE"

TRdb <- dbConnect(SQLite(), dbname=TRdatabasename) #connect to SQLite DB
Join_ElSubID <- dbGetQuery(TRdb, paste0("SELECT ELSubID, ELCODE FROM ET"," WHERE ELCODE IN (", paste(toString(sQuote(SD_speciesTable$ELCODE)), collapse = ", "), ");"))
dbDisconnect(TRdb)
SD_speciesTable <- merge(SD_speciesTable, Join_ElSubID, by="ELCODE")  # merge in the ELSubID until we get it fixed in the GIS layer

         
#add a column in NHA selected species table for the image path, and assign image. Note: this uses the EO_ImSelect function
for(i in 1:nrow(SD_speciesTable)){
  SD_speciesTable$Images <- EO_ImSelect(SD_speciesTable[i,])
}
# assign the icon images
SD_speciesTable <- within(SD_speciesTable, Images[SENSITIVE=="Y"] <- "Sensitive.png") #substitute image for sensitive species, as necessary (this does not, however, account for sensitive data by request) 
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IZSPN")] <- "Sponges.png") #subset out freshwater sponges
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IICOL")] <- "TigerBeetles.png") #subset out beetles
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IITRI")] <- "Caddisflies.png") #subset out caddisflies + stoneflies (?)
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IIEPH")] <- "OtherInverts.png") #subset out stoneflies/mayflies
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IIPLE")] <- "OtherInverts.png") #subset out stoneflies/mayflies
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IIDIP")] <- "Craneflies.png") #subset out craneflies
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "NBHEP")] <- "Liverworts.png") #subset out liverworts
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "NLT")] <- "Mosses.png") #subset out mosses
SD_speciesTable <- within(SD_speciesTable, Images[startsWith(ELCODE, "IIME")] <- "earwigscorpionfly.png") #subset out earwig scorpionflies

# write this table to the SQLite database
speciesTable4db <- SD_speciesTable
speciesTable4db <- cbind(selected_nha$NHA_JOIN_ID, speciesTable4db)
colnames(speciesTable4db)[which(names(speciesTable4db) == "selected_nha$NHA_JOIN_ID")] <- "NHA_JOIN_ID"
speciesTable4db$NHA_JOIN_ID <- as.character(speciesTable4db$NHA_JOIN_ID)

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
dbExecute(db_nha, paste("DELETE FROM nha_species WHERE NHA_JOIN_ID = ", sQuote(selected_nha$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_species", speciesTable4db)
dbDisconnect(db_nha)

#check whether there are multiple EOs in the species table for the same species, and only keep one record for each species, the most recently observed entry
duplic_Spp <- SD_speciesTable %>%
                  group_by(ELCODE) %>%
                  mutate(dupe=n()>1)
duplic_Spp <- as.data.frame(duplic_Spp)
duplic_Spp2 <- duplic_Spp[(duplic_Spp$dupe != TRUE),] #remove rows which are the same species
same <- duplic_Spp[(duplic_Spp$dupe == TRUE),]#select the rows which are the same
same <- same[order(same$LASTOBS, decreasing=TRUE),] #sort by date, so that when unique is called, the most recent rows are preserved
unique <- unique(same[,-15])#remove the duplication code column

SD_speciesTable <- duplic_Spp2[,-15] #remove the duplication code column
SD_speciesTable <- as.data.frame(rbind(SD_speciesTable, unique))

###
eoid_list <- paste(toString(SD_speciesTable$EO_ID), collapse = ",")  # make a list of EOIDs to get data from
ELCODE_list <- paste(toString(sQuote(unique(SD_speciesTable$ELCODE))), collapse = ",")  # make a list of EOIDs to get data from

ptreps <- arc.open(paste(biotics_gdb,"eo_ptreps",sep="/"))
ptreps_selected <- arc.select(ptreps, fields=c("EO_ID", "SNAME", "EO_DATA", "GEN_DESC","MGMT_COM","GENERL_COM"), where_clause=paste("EO_ID IN (", eoid_list, ")",sep="") )

#################################################################################################################################
# calculate the site significance rank based on the species present at the site #################################################
source(here::here("scripts","nha_ThreatsRecDatabase","2_loadSpeciesWeights.r"))

sigrankspecieslist <- SD_speciesTable[c("SNAME","GRANK","SRANK","EORANK")]

sigrankspecieslist <- sigrankspecieslist[which(sigrankspecieslist$GRANK!="GNR"&!is.na(sigrankspecieslist$EORANK)),]

sigrankspecieslist <- merge(sigrankspecieslist, rounded_grank, by="GRANK")
sigrankspecieslist <- merge(sigrankspecieslist, rounded_srank, by="SRANK")
sigrankspecieslist <- merge(sigrankspecieslist, nha_EORANKweights, by="EORANK")

for(i in 1:nrow(sigrankspecieslist)){
  sigrankspecieslist$rarityscore[i] <- nha_gsrankMatrix[sigrankspecieslist$GRANK_rounded[i],sigrankspecieslist$SRANK_rounded[i]]  
}
sigrankspecieslist$totalscore <- sigrankspecieslist$rarityscore * sigrankspecieslist$Weight # calculate the total score for each species
selected_nha$site_score <- sum(sigrankspecieslist$totalscore, na.rm=TRUE) # sum that score across all species

if(selected_nha$site_score==0){
  selected_nha$site_rank <- "Local"
} else if(selected_nha$site_score>0 & selected_nha$site_score<=152) {
  selected_nha$site_rank <- "State"
} else if(selected_nha$site_score>152 & selected_nha$site_score<=457) {
  selected_nha$site_rank <- "Regional"
}  else if (selected_nha$site_score>457) {
  selected_nha$site_rank <- "Global"
}

#################################################################################################################################

#generate URLs for each EO at site
URL_EOs <- sapply(seq_along(ptreps_selected$EO_ID), function(x)  paste("https://bioticspa.natureserve.org/biotics/services/page/Eo/",ptreps_selected$EO_ID[x],".html", sep=""))
URL_EOs <- sapply(seq_along(URL_EOs), function(x) paste("(",URL_EOs[x],")", sep=""))
Sname_link <- sapply(seq_along(ptreps_selected$SNAME), function(x) paste("[",ptreps_selected$SNAME[x],"]", sep=""))
Links <- paste(Sname_link, URL_EOs, sep="") 

TRdb <- dbConnect(SQLite(), dbname=TRdatabasename) #connect to SQLite DB
# trying this Chris' way because its awesomer....
ElementTR <- dbGetQuery(TRdb, paste0("SELECT * FROM ElementThreatRecs"," WHERE ELSubID IN (", paste(toString(sQuote(SD_speciesTable$ELSubID)), collapse = ", "), ");"))
ThreatRecTable  <- dbGetQuery(TRdb, paste0("SELECT * FROM ThreatRecTable"," WHERE TRID IN (", paste(toString(sQuote(ElementTR$TRID)), collapse = ", "), ");"))
ET <- dbGetQuery(TRdb, paste0("SELECT SNAME, ELSubID FROM ET"," WHERE ELSubID IN (", paste(toString(sQuote(ElementTR$ELSubID)), collapse = ", "), ");"))

# Generate paths to previous site accounts for the area included in the present NHA
OldNames <- gsub(", ", ",",selected_nha$OLD_SITE_NAME) #remove spaces after comma
OldNames <- strsplit(OldNames, split=",") #split comma-separated list of old site names into individual elements
OldNames <- unlist(OldNames)

N <- length(OldNames)
OldNames_path <- list()

#loop through each old site name to create a list of the elements needed to create the file path to that site account
for (i in 1:N) {
  temp <- paste0(c("P:\\\\Conservation Programs\\\\Natural Heritage Program\\\\ConservationPlanning\\\\NaturalHeritageAreas\\\\SiteDescriptions\\\\=",selected_nha$COUNTY," CNHI site descriptions\\\\", OldNames[i],".pdf"))
  
  OldNames_path[[paste0("OldNames",i)]] <- temp
}

x <- NULL
for (i in 1:N) {
  x[i]  <- paste0(unlist(OldNames_path[i]), sep="", collapse="")
}

#join general threats/recs table with the element table 
ELCODE_TR <- ElementTR %>%
  inner_join(ET) %>%
  inner_join(ThreatRecTable)

# set up the temp directories
NHAdest1 <- paste(NHAdest,"DraftSiteAccounts",nha_foldername,sep="/")
dir.create(NHAdest1, showWarnings=FALSE) # make a folder for each site
dir.create(paste(NHAdest1,"photos", sep="/"), showWarnings = F) # make a folder for each site


# make the maps

mtype <- 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}?'
basetiles <- tmaptools::read_osm(nha_sf, type=mtype, ext=1.5, use.colortable=FALSE)

# plot it
tmap_mode("plot")
nha_map <- tm_shape(basetiles, unit="m") +
  tm_rgb() +
  tm_shape(nha_sf) +
  tm_borders("red", lwd=1.5)+
  tm_legend(show=FALSE) + 
  tm_layout(attr.color="white") +
  tm_compass(type="arrow", position=c("left","bottom")) +
  tm_scale_bar(position=c("center","bottom"))
tmap_save(nha_map, filename=paste(NHAdest1, "/", nha_foldername,"_tempmap.png",sep=""), units="in", width=7) 



######### Write the output document for the site ###############
 
rmarkdown::render(input=here::here("scripts","template_NHAREport_part1v2.Rmd"), output_format="word_document", 
                  output_file=nha_filename,
                  output_dir=NHAdest1)

# delete the map, after its included in the markdown
fn <- paste(NHAdest1, "/", nha_filename,"_tempmap.png",sep="")
if (file.exists(fn)) #Delete file if it exists
  file.remove(fn)

###############################################################################################################
# insert the NHA data into a sqlite database

nha_data <- selected_nha[c("SITE_NAME","SITE_TYPE","NHA_JOIN_ID","site_rank","site_score","BRIEF_DESC","COUNTY","Muni","USGS_QUAD","ASSOC_NHA","PROTECTED_LANDS","nha_filename")]

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
dbAppendTable(db_nha, "nha_main", nha_data)
dbDisconnect(db_nha)


########################

#add record of creation of this site to running Excel spreadsheet of NHA site accounts

# wb <- c("SITE_NAME","COUNTY","ASSIGNED_WRITER","TEMPLATE_COMPLETED","PDF_CREATED","NOTES")
# write.xlsx(t(wb),file="P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/NHA_SitesSummary.xlsx", colNames=FALSE) #Create workbook for the first time

NHA_rec <- data.frame(SITE_NAME=selected_nha$SITE_NAME, COUNTY=selected_nha$COUNTY, ASSIGNED_WRITER="",TEMPLATE_COMPLETED="", CONTENT_DATABASED="", PDF_CREATED="", NOTES="", FOLDER_PATH=gsub("/","\\\\", NHAdest1)) #create new row for dataframe for current site 

wb <- loadWorkbook("P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/NHA_SitesSummary.xlsx") #import excel file
sheet1 <- read.xlsx(wb,sheet = 1) #select sheet of interest
df <- rbind(sheet1, NHA_rec[!NHA_rec$SITE_NAME %in% (sheet1$SITE_NAME),]) #add new row to dataframe only if the site is not already within the dataframe
writeData(wb, sheet=1, df) #write updated dataframe to file
saveWorkbook(wb,"P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/NHA_SitesSummary.xlsx", overwrite=TRUE) #save excel file

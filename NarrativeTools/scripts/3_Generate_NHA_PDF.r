#-------------------------------------------------------------------------------
# Name:        Formatted_NHA_PDF.r
# Purpose:     Generate the formatted PDF
# Author:      Anna Johnson
# Created:     2019-03-28
# Updated:     2019-03-28
#
# Updates:
# * 

# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------

# check and load required libraries  
#if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
#  require(here)
# clear the environment
#rm(list = ls())
# load in the paths and settings file
#source(here::here("scripts","0_PathsAndSettings.r"))

# Pull in the selected NHA data ################################################
nha_name <- LauncherNHA
nha_name <- gsub("'", "''", nha_name)
nha_nameSQL <- paste("'", nha_name, "'", sep='')
nha_name <- gsub("''", "'", nha_name)
nha_foldername <- foldername(nha_name) # this now uses a user-defined function

nha_nameLatex <- gsub("#","\\\\#", nha_name) # escapes our octothorpes

# access geodatabase to pull site info 
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nha <- arc.select(nha, where_clause=paste("SITE_NAME=", nha_nameSQL, "AND STATUS = 'NP'"))
#selected_nha <- selected_nha %>% slice(2)
# Access SQL database to access nha site account data
db_nha <- dbConnect(SQLite(), dbname=nha_databasename)
nha_data <- dbGetQuery(db_nha, paste("SELECT * from nha_siteaccount WHERE NHA_JOIN_ID = ", sQuote(selected_nha$NHA_JOIN_ID), sep=""))

# replace NA in 'Location' data with specific text 

## Pull in protected lands information #############
nha_ProtectedLands <- arc.open(paste(serverPath,"PNHP.DBO.NHA_ProtectedLands", sep=""))
selected_nha_ProtectedLands <- arc.select(nha_ProtectedLands) 
protected_lands <- selected_nha_ProtectedLands[which(selected_nha_ProtectedLands$NHA_JOIN_ID==selected_nha$NHA_JOIN_ID),]

if(nrow(protected_lands)==0){
  nha_data$PROTECTED_LANDS <- paste("This site is not documented as overlapping with any Federal, state, or locally protected land or conservation easements.")
} else {
  nha_data$PROTECTED_LANDS <- paste(protected_lands$PROTECTED_LANDS, collapse=', ')
}

## Pull in political boundaries information #############
nha_PoliticalBoundaries <- arc.open(paste(serverPath,"PNHP.DBO.NHA_PoliticalBoundaries", sep=""))
selected_nha_PoliticalBoundaries <- arc.select(nha_PoliticalBoundaries) 
PoliticalBoundaries <- selected_nha_PoliticalBoundaries[which(selected_nha_PoliticalBoundaries$NHA_JOIN_ID==selected_nha$NHA_JOIN_ID),]

PBs <- split(PoliticalBoundaries, PoliticalBoundaries$COUNTY)
munil <- list()
for(i in 1:length(PBs)){
  munil[[i]] <- unique(PBs[[i]]$MUNICIPALITY)  
}

printCounty <- list()
for (i in 1:length(PBs)){
  printCounty[[i]]  <- paste0(PBs[[i]]$COUNTY[1], " County",": ", paste(munil[[i]], collapse=', '))  
}

nha_data$CountyMuni <- paste(printCounty, collapse='; ')

# # delete existing site account info from this site, prior to overwriting with new info
dbExecute(db_nha, paste("DELETE FROM nha_siteaccount WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_siteaccount", nha_data)
dbDisconnect(db_nha)

# species table
# open the related species table and get the rows that match the NHA join ids from the selected NHAs
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies) 

#open linked species table, select based on list of selected NHAs, join to Point Reps data,
species_table_select <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==selected_nha$NHA_JOIN_ID),]

SQLquery_pointreps <- paste("EO_ID IN(",paste(toString(species_table_select$EO_ID),collapse=", "), ")") #don't use quotes around numbers

pointreps <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/eo_ptreps")
selected_pointreps <- arc.select(pointreps, c('EO_ID', 'EORANK', 'GRANK', 'SRANK', 'SPROT', 'PBSSTATUS', 'LASTOBS_YR', 'SENSITV_SP', 'SENSITV_EO'), where_clause=SQLquery_pointreps) 

speciestable <- merge(species_table_select,selected_pointreps, by="EO_ID")

names(speciestable)[names(speciestable)=="SENSITV_SP"] <- c("SENSITIVE")
names(speciestable)[names(speciestable)=="SENSITV_EO"] <- c("SENSITIVE_EO")

# delete unneeded fields
speciestable <- speciestable[c("EO_ID","ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE","NHA_JOIN_ID","EORANK","GRANK","SRANK","SPROT","PBSSTATUS","LASTOBS_YR","SENSITIVE","SENSITIVE_EO")]

# replace missing values with NA
speciestable$EORANK[is.na(speciestable$EORANK)] <- "E"

# replace certain species names
speciestable[which(speciestable$SNAME=="Carex shortiana"),"SCOMNAME"] <- "Short's sedge"

# merge the species table with the taxonomic icons
speciestable <- merge(speciestable, taxaicon, by="ELEMENT_TYPE")
# do a check here if it results in a zero length table and will break the script
ifelse(nrow(speciestable)==0,print("ERROR: Bad join with Taxa Icons"), print("All is well with this join"))

# take one value from multiple species
dupspecies <- sort(speciestable[which(duplicated(speciestable$SNAME)),]$SNAME)
ifelse(length(dupspecies)>0, print(paste("The following species have multiple EOs: ", paste(dupspecies, collapse=", "), sep="")), print("No duplicate species in the table."))

speciestable_dup <- speciestable[which(speciestable$SNAME %in% dupspecies),]
speciestable_nodup <- speciestable[which(!speciestable$SNAME %in% dupspecies),]
speciestable_dup <- speciestable_dup[which(speciestable_dup$EORANK!="F"&speciestable_dup$EORANK!="X"),]
speciestable <- rbind(speciestable_dup,speciestable_nodup)


speciestable <- speciestable %>% distinct(SNAME, LASTOBS_YR, .keep_all= TRUE)
speciestable <- speciestable %>% group_by(SNAME) %>% slice_min(EORANK)
speciestable <- speciestable %>%  group_by(SNAME) %>%  slice_max(LASTOBS_YR)

# manually change the sensitivity if the the EO is sensitive
speciestable[which(speciestable$SENSITIVE=="N" & speciestable$SENSITIVE_EO=="Y"),"SENSITIVE"] <- "Y"

# create paragraph about species ranks
db_nha <- dbConnect(SQLite(), dbname=TRdatabasename)

rounded_srank <- dbReadTable(db_nha, "rounded_srank")
rounded_grank <- dbReadTable(db_nha, "rounded_grank")

granklist <- merge(rounded_grank, speciestable[c("SNAME","SCOMNAME","GRANK","SENSITIVE")], by="GRANK")

# secure species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G4"|granklist$GRANK_rounded=="G5"|granklist$GRANK_rounded=="GNR"|granklist$GRANK_rounded=="GNA")&granklist$SENSITIVE!="Y"),])
if(a>0){
  spExample_GSecure <- sample_n(granklist[which(granklist$SENSITIVE!="Y"),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
}
spCount_GSecure <- ifelse(length(a)==0, 0, a)
spCount_GSecureSens <- ifelse(any(((granklist$GRANK_rounded=="G4"|granklist$GRANK_rounded=="G5"|granklist$GRANK_rounded=="GNR"|granklist$GRANK_rounded=="GNA")&granklist$SENSITIVE=="Y")), "yes", "no")
rm(a)

# G3G4 but has state significance


# vulnerable species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G3")&granklist$SENSITIVE!="Y"),])
if(a>0){
  spExample_GVulnerable <- sample_n(granklist[which(granklist$SENSITIVE!="Y" & granklist$GRANK_rounded=="G3"),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
}
spCount_GVulnerable <- ifelse(length(a)==0, 0, a)
spCount_GVulnerableSens <- ifelse(any(((granklist$GRANK_rounded=="G3")&granklist$SENSITIVE=="Y")), "yes", "no")
rm(a)

# imperiled species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G2"|granklist$GRANK_rounded=="G1")&granklist$SENSITIVE!="Y"),])
if(a>0){
  spExample_GImperiled <- sample_n(granklist[which(granklist$SENSITIVE!="Y" & (granklist$GRANK_rounded=="G2"|granklist$GRANK_rounded=="G1")),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
}
spCount_GImperiled <- ifelse(length(a)==0, 0, a)
spCount_GImperiledSens <- ifelse(any(((granklist$GRANK_rounded=="G2"|granklist$GRANK_rounded=="G1")&granklist$SENSITIVE=="Y")), "yes", "no")
rm(a)

rm(granklist, rounded_srank, rounded_grank)

# threats
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  nha_threats <- dbGetQuery(db_nha, paste("SELECT * FROM nha_TRbullets WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)
#nha_threats$ThreatRec <- gsub("&", "and", nha_threats$ThreatRec)

# pictures
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_photos <- dbGetQuery(db_nha, paste("SELECT * FROM nha_photos WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)

# #site rank
# db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# nha_siterank <- dbGetQuery(db_nha, paste("SELECT site_score FROM nha_runrecord WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
# dbDisconnect(db_nha)

nha_siterank <- NA
if(selected_nha$SIG_RANK=="G"){
  nha_siterank <- "Global"
} else if(selected_nha$SIG_RANK=="R"){
  nha_siterank <- "Regional"
} else if(selected_nha$SIG_RANK=="S"){
  nha_siterank <- "State"
} else if(selected_nha$SIG_RANK=="L"){
  nha_siterank <- "Local"
} else {
  nha_siterank <- NA
}

# sources and funding
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_Sources <- dbGetQuery(db_nha, paste("SELECT * FROM nha_SourcesFunding WHERE SOURCE_REPORT = " , sQuote(selected_nha$SOURCE_REPORT), sep="") )
dbDisconnect(db_nha)

###############################################################
## format various blocks of text to be formatted in terms of italics and bold font : Note that  Etitalics vector is now loaded in paths and settings
# italicize all SNAMEs in the descriptive text. 
for(j in 1:length(ETitalics)){
  nha_data$Description <- str_replace_all(nha_data$Description, ETitalics[j])
}
# italicize all SNAMEs in the threats and recommendations text. 
nha_data$ThreatRecP <- str_replace_all(nha_data$ThreatRecP, ETitalics) # for the paragraph
for(j in 1:nrow(nha_threats)){
  nha_threats$TRB[j] <- str_replace_all(nha_threats$TRB[j], ETitalics)
}
# italicize in photo captions
if(!is.na(nha_photos$P1C)) {
  nha_photos$P1C <- str_replace_all(nha_photos$P1C, ETitalics)
} else {
  print("No Photo 1 caption, moving on...")
}
if(!is.na(nha_photos$P2C)) {
  nha_photos$P2C <- str_replace_all(nha_photos$P2C, ETitalics)
} else {
  print("No Photo 2 caption, moving on...")
}
if(!is.na(nha_photos$P3C)) {
  nha_photos$P2C <- str_replace_all(nha_photos$P3C, ETitalics)
} else {
  print("No Photo 3 caption, moving on...")
}

# replace apostrophes in the description paragraph
nha_data$Description <- str_replace_all(nha_data$Description, c("â€™"="'"))

# bold tracked species names
namesbold <- speciestable$SCOMNAME
namesbold <- namesbold[!is.na(namesbold)]
namesbold_lower <- tolower(namesbold)
namesbold_first <- namesbold_lower
substr(namesbold_first, 1, 1) <- toupper(substr(namesbold_first, 1, 1))
namesbold <- c(namesbold, namesbold_first, namesbold_lower)

vecnames <- namesbold 
namesbold <- paste0("\\\\textbf{",namesbold,"}") 
names(namesbold) <- vecnames
rm(vecnames)
for(i in 1:length(namesbold)){
  nha_data$Description <- str_replace_all(nha_data$Description, namesbold[i])
}

##############################################################################################################
## Write the output document for the site ###############
setwd(paste(NHAdest, "DraftSiteAccounts", nha_foldername, sep="/"))
pdf_filename <- paste(nha_foldername,"_",gsub("[^0-9]", "", Sys.time() ),sep="")
makePDF(rnw_template, pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd
if(FinalSwitch=="Final"){
  file.copy(from=paste(NHAdest, "DraftSiteAccounts", nha_foldername, paste0(pdf_filename, ".pdf"), sep="/"), to=paste(NHAdest, "FinalSiteAccounts", paste0(pdf_filename, ".pdf"), sep="/"), overwrite = TRUE, recursive = FALSE, copy.mode = TRUE)
  cat("The final pdf of", dQuote(nha_name), "is complete and moved the Final NHA directory!")
  beepr::beep(sound=10, expr=NULL)
} else {
  cat("The draft of",dQuote(nha_name), "is complete!")
}


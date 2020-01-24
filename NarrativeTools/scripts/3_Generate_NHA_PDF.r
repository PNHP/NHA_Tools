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
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)

# load in the paths and settings file
source(here::here("scripts","0_PathsAndSettings.r"))

# Pull in the selected NHA data ################################################
nha_name <- "Allegheny River Pool #6"
nha_nameSQL <- paste("'", nha_name, "'", sep='')
nha_foldername <- foldername(nha_name) # this now uses a user-defined function

# access geodatabase to pull site info 
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nha <- arc.select(nha, where_clause=paste("SITE_NAME=", nha_name, "AND STATUS = 'NP'"))

# replace NA in 'Location' data with specific text 

## Pull in protected lands information #############
nha_ProtectedLands <- arc.open(paste(serverPath,"PNHP.DBO.NHA_ProtectedLands", sep=""))
selected_nha_ProtectedLands <- arc.select(nha_ProtectedLands) 
protected_lands <- selected_nha_ProtectedLands[which(selected_nha_ProtectedLands$NHA_JOIN_ID==selected_nha$SITE_NAME),]

if(nrow(protected_lands)==0){
  nha_data$PROTECTED_LANDS <- "This site is not documented as overlapping with any Federal, state, or locally protected land or conservation easements."
} else {
  nha_data$PROTECTED_LANDS <- paste(ProtectedLands$PROTECTED_LANDS, collapse=', ')
}


# species table
# open the related species table and get the rows that match the NHA join ids from the selected NHAs
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies) 

#open linked species tables and select based on list of selected NHAs
species_table_select <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==selected_nha$SITE_NAME),]

# create paragraph about species ranks
rounded_srank <- read.csv(here::here("_data","databases","sourcefiles","rounded_srank.csv"), stringsAsFactors=FALSE)
rounded_grank <- read.csv(here::here("_data","databases","sourcefiles","rounded_grank.csv"), stringsAsFactors=FALSE)

granklist <- merge(rounded_grank, NHAspecies[c("SNAME","SCOMNAME","GRANK","SENSITIVE")], by="GRANK")
# secure species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G4"|granklist$GRANK_rounded=="G5"|granklist$GRANK_rounded=="GNR")&granklist$SENSITIVE!="Y"),])
spCount_GSecure <- ifelse(length(a)==0, 0, a)
spExample_GSecure <- sample(granklist[which(granklist$SENSITIVE!="Y"),]$SNAME, 1, replace=FALSE, prob=NULL) 
# vulnerable species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G3")&granklist$SENSITIVE!="Y"),])
spCount_GVulnerable <- ifelse(length(a)==0, 0, a)
rm(a)
spExample_GVulnerable <- sample_n(granklist[which(granklist$SENSITIVE!="Y" & granklist$GRANK_rounded=="G3"),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
# imperiled species
a <- nrow(granklist[which((granklist$GRANK_rounded=="G2"|granklist$GRANK_rounded=="G1")&granklist$SENSITIVE!="Y"),])
spCount_GImperiled <- ifelse(length(a)==0, 0, a)
rm(a)
spExample_GImperiled <- sample_n(granklist[which(granklist$SENSITIVE!="Y" & (granklist$GRANK_rounded=="G2"|granklist$GRANK_rounded=="G1")),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 

rm(granklist, rounded_srank, rounded_grank)

# threats
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  nha_threats <- dbGetQuery(db_nha, paste("SELECT * FROM nha_ThreatRec WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)
nha_threats$ThreatRec <- gsub("&", "and", nha_threats$ThreatRec)

# References
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_References <- dbGetQuery(db_nha, paste("SELECT * FROM nha_References WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)
# fileConn<-file(paste(NHAdest, "DraftSiteAccounts", nha_foldername, "ref.bib", sep="/"))
# writeLines(c(nha_References$Reference), fileConn)
# close(fileConn)

# picture
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_photos <- dbGetQuery(db_nha, paste("SELECT * FROM nha_photos WHERE NHA_JOIN_ID = " , sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)

p1_path <- paste(NHAdest, "DraftSiteAccounts", nha_foldername, "photos", nha_photos$P1F, sep="/")


## Process the species names within the site description text
namesitalic <- NHAspecies[which(NHAspecies$ELEMENT_TYPE!="C"),]$SNAME
namesitalic <- namesitalic[!is.na(namesitalic)]
vecnames <- namesitalic 
namesitalic <- paste0("\\\\textit{",namesitalic,"}")                                                                                                                                              
names(namesitalic) <- vecnames
rm(vecnames)
for(i in 1:length(namesitalic)){
  nha_data$Description <- str_replace_all(nha_data$Description, namesitalic[i])
}

namesbold <- NHAspecies$SCOMNAME
namesbold <- namesbold[!is.na(namesbold)]
vecnames <- namesbold 
namesbold <- paste0("\\\\textbf{",namesbold,"}") 
names(namesbold) <- vecnames
rm(vecnames)
for(i in 1:length(namesbold)){
  nha_data$Description <- str_replace_all(nha_data$Description, namesbold[i])
}



# italicize other species names in threats and stressors and brief description
db <- dbConnect(SQLite(), dbname=databasename) # connect to the database
ETitalics <- dbGetQuery(db, paste("SELECT * FROM SNAMEitalics") )
dbDisconnect(db) # disconnect the db
ETitalics <- ETitalics$ETitalics
vecnames <- ETitalics 
ETitalics <- paste0("\\\\textit{",ETitalics,"}") 
names(ETitalics) <- vecnames
rm(vecnames)
#italicize the stuff
for(j in 1:length(ETitalics)){
  nha_data$Description <- str_replace_all(nha_data$Description, ETitalics[j])
}
for(j in 1:nrow(nha_threats)){
  nha_threats$ThreatRec[j] <- str_replace_all(nha_threats$ThreatRec[j], ETitalics)
}


##############################################################################################################
## Write the output document for the site ###############
setwd(paste(NHAdest, "DraftSiteAccounts", nha_foldername, sep="/"))
pdf_filename <- paste(nha_foldername,"_",gsub("[^0-9]", "", Sys.time() ),sep="")
makePDF(rnw_template, pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd 

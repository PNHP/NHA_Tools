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
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
  require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
  require(RSQLite)
if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr")
  require(knitr)
if (!requireNamespace("xtable", quietly = TRUE)) install.packages("xtable")
  require(xtable)
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
  require(dplyr)
if (!requireNamespace("DBI", quietly = TRUE)) install.packages("DBI")
  require(DBI)
if (!requireNamespace("dbplyr", quietly = TRUE)) install.packages("dbplyr")
  require(dbplyr)
if (!requireNamespace("tinytex", quietly = TRUE)) install.packages("tinytex")
  require(tinytex)
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
  require(stringr)
if (!requireNamespace("english", quietly = TRUE)) install.packages("english")
  require(english)

# load in the paths and settings file
source(here::here("scripts","0_PathsAndSettings.r"))

# Pull in the selected NHA data ################################################
# File path for completed Word documents
nha_name <- "Hogback Barrens"

# query the database for the site information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_data <- dbGetQuery(db_nha, paste("SELECT * FROM nha_main WHERE SITE_NAME = " , sQuote(nha_name), sep="") )
dbDisconnect(db_nha)

nha_foldername <- foldername(nha_data$SITE_NAME ) # this now uses a user-defined function

# replace NA in 'Location' data with specific text 
if(is.na(nha_data$PROTECTED_LANDS)){
  nha_data$PROTECTED_LANDS <- "This site is not documented as overlapping with any Federal, state, or locally protected land or conservation easements."
} else {
  nha_data$PROTECTED_LANDS <- nha_data$PROTECTED_LANDS
}


# species table
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  NHAspecies <- dbGetQuery(db_nha, paste("SELECT * from nha_species WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep="") )
dbDisconnect(db_nha)

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

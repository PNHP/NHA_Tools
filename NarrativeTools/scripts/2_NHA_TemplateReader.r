if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)
if (!requireNamespace("readtext", quietly = TRUE)) install.packages("readtext")
  require(readtext)
if (!requireNamespace("qdapRegex", quietly = TRUE)) install.packages("qdapRegex")
  require(qdapRegex)
if (!requireNamespace("textreadr", quietly = TRUE)) install.packages("textreadr")
  require(textreadr)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
  require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
  require(RSQLite)
if (!requireNamespace("plyr", quietly = TRUE)) install.packages("plyr")
  require(plyr)
if (!requireNamespace("dbplyr", quietly = TRUE)) install.packages("dbplyr")
  require(dbplyr)
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
  require(stringr)



# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

# Pull in the selected NHA data ################################################
# File path for completed Word documents
nha_name <- "Cherry Run at Cochrans Mills"

# query the database for the site information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_data <- dbGetQuery(db_nha, paste("SELECT * FROM nha_main WHERE SITE_NAME = " , sQuote(nha_name), sep="") )
dbDisconnect(db_nha)

nha_siteName <- nha_data$SITE_NAME  
nha_foldername <- foldername(nha_siteName) # this now uses a user-defined function

# find the NHA word file template that we want to use
NHA_file <- list.files(path=paste(NHAdest, "DraftSiteAccounts", nha_foldername, sep="/"), pattern=".docx$")  # --- make sure your excel file is not open.
NHA_file
# select the file number from the list below
n <- 1
NHA_file <- NHA_file[n]
# create the path to the whole file!
NHAdest1 <- paste(NHAdest,"DraftSiteAccounts", nha_foldername, NHA_file, sep="/")

# Translate the Word document into a text string  ################################################
text <- readtext(NHAdest1, format=TRUE)
text1 <- text[2]
text1 <- as.character(text1)
text1 <- gsub("\r?\n|\r", " ", text1)
rm(text)

###############################################################################################################
# Extract individual elements of report, process, and add to NHA database #####################################

# NHA written description information #########################################################################
Description <- rm_between(text1, '|DESC_B|', '|DESC_E|', fixed=TRUE, extract=TRUE)[[1]]
# bold and italic species names
# db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
#   NHAspecies <- dbGetQuery(db_nha, paste("SELECT * from nha_species WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep="") )
# dbDisconnect(db_nha)

# namesbold <- paste0("//textbf{",NHAspecies$SCOMNAME,"}")
# names(namesbold) <- NHAspecies$SCOMNAME
# Description1 <- str_replace_all(Description, namesbold)
# 
# namesitalic <- paste0("/textit{",NHAspecies$SNAME,"}")  
# names(namesitalic) <- NHAspecies$SNAME
# Description <- str_replace_all(Description, namesitalic)


# add the above to the database
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  dbSendStatement(db_nha, paste("UPDATE nha_siteaccount SET Description = ", sQuote(Description), " WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
dbDisconnect(db_nha)

# Threats and Recommendations #################################################################################

# Introductory paragraph for the Threats and Recommendations Section
ThreatRecP <- rm_between(text1, '|THRRECP_B|', '|THRRECP_E|', fixed=TRUE, extract=TRUE)[[1]] 
# add the above to the database
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
dbSendStatement(db_nha, paste("UPDATE nha_main SET ThreatsAndRecomendations = ", sQuote(ThreatRecP), " WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
dbDisconnect(db_nha)

# Extract all the threat/rec bullets into a list and convert to a dataframe
TRB <- rm_between(text1, '|BULL_B|', '|BULL_E|', fixed=TRUE, extract=TRUE)
TRB <- ldply(TRB)
TRB <- as.data.frame(t(TRB))
TRB <- cbind(nha_data$NHA_JOIN_ID,TRB)
names(TRB) <- c("NHA_JOIN_ID","ThreatRec")
TRB$NHA_JOIN_ID <- as.character(TRB$NHA_JOIN_ID)
TRB$ThreatRec <- as.character(TRB$ThreatRec)

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
dbExecute(db_nha, paste("DELETE FROM nha_ThreatRec WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_ThreatRec", TRB)
dbDisconnect(db_nha)

# References ###################################################################################################
References <- rm_between(text1, '|REF_B|', '|REF_E|', fixed=TRUE, extract=TRUE)[[1]]
References <- ldply(References)
References <- as.data.frame(References)

RefCodes <- rm_between(text1, '|REFCODE_B|', '|REFCODE_E|', fixed=TRUE, extract=TRUE)[[1]]
RefCodes <- ldply(RefCodes)
RefCodes <- as.data.frame(RefCodes)

References <- cbind(nha_data$NHA_JOIN_ID, RefCodes, References)
names(References) <- c("NHA_JOIN_ID","RefCode","Reference")
References$NHA_JOIN_ID <- as.character(References$NHA_JOIN_ID)
References$RefCode <- as.character(References$RefCode)
References$Reference <- as.character(References$Reference)

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
dbExecute(db_nha, paste("DELETE FROM nha_References WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_References", References)
dbDisconnect(db_nha)



DateTime <- Sys.time()
#round(DateTime, unit="day") # to pull out just date--use to select and append vs overwrite lines


# Pull in information on photos, for photo database table ######################################################
# Photo one
P1N <- rm_between(text1, '|P1N_B|', '|P1N_E|', fixed=TRUE, extract=TRUE)[[1]]
P1C <- rm_between(text1, '|P1C_B|', '|P1C_E|', fixed=TRUE, extract=TRUE)[[1]]
P1F <- rm_between(text1, '|P1F_B|', '|P1F_E|', fixed=TRUE, extract=TRUE)[[1]]
# Photo two
P2N <- rm_between(text1, '|P2N_B|', '|P2N_E|', fixed=TRUE, extract=TRUE)[[1]]
P2C <- rm_between(text1, '|P2C_B|', '|P2C_E|', fixed=TRUE, extract=TRUE)[[1]]
P2F <- rm_between(text1, '|P2F_B|', '|P2F_E|', fixed=TRUE, extract=TRUE)[[1]]
# Photo three
P3N <- rm_between(text1, '|P3N_B|', '|P3N_E|', fixed=TRUE, extract=TRUE)[[1]]
P3C <- rm_between(text1, '|P3C_B|', '|P3C_E|', fixed=TRUE, extract=TRUE)[[1]]
P3F <- rm_between(text1, '|P3F_B|', '|P3F_E|', fixed=TRUE, extract=TRUE)[[1]]
# prep the data frame
AddPhotos <- as.data.frame(cbind(nha_data$SITE_NAME, nha_data$NHA_JOIN_ID, P1N, P1C, P1F, P2N, P2C, P2F, P3N, P3C, P3F))
colnames(AddPhotos)[which(names(AddPhotos) == "V1")] <- "SITE_NAME"
colnames(AddPhotos)[which(names(AddPhotos) == "V2")] <- "NHA_JOIN_ID"
# convert any empty fields to NA
AddPhotos[AddPhotos=="enter name here."] <- NA
AddPhotos[AddPhotos=="enter short description of photo here"] <- NA
AddPhotos[AddPhotos=="enter name of photo file uploaded to folder here, including format (eg.jpg, .png)."] <- NA
# convert all to character
AddPhotos$SITE_NAME <- as.character(AddPhotos$SITE_NAME)
AddPhotos$NHA_JOIN_ID <- as.character(AddPhotos$NHA_JOIN_ID)
AddPhotos$P1N <- as.character(AddPhotos$P1N)
AddPhotos$P1C <- as.character(AddPhotos$P1C)
AddPhotos$P1F <- as.character(AddPhotos$P1F)
AddPhotos$P2N <- as.character(AddPhotos$P2N)
AddPhotos$P2C <- as.character(AddPhotos$P2C)
AddPhotos$P2F <- as.character(AddPhotos$P2F)
AddPhotos$P3N <- as.character(AddPhotos$P3N)
AddPhotos$P3C <- as.character(AddPhotos$P3C)
AddPhotos$P3F <- as.character(AddPhotos$P3F)
# add to the database
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
dbExecute(db_nha, paste("DELETE FROM nha_photos WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep="")) # delete existing threats and recs for this site if they exist
dbAppendTable(db_nha, "nha_photos", AddPhotos) # add in the new data
dbDisconnect(db_nha)




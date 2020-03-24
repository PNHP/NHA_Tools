if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

# Pull in the selected NHA data ################################################
# File path for completed Word documents
nha_name <- "Conemaugh River at Old River Hill Rd"
nha_nameSQL <- paste("'", nha_name, "'", sep='')
nha_foldername <- foldername(nha_name) # this now uses a user-defined function

# access geodatabase to pull site info 
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nha <- arc.select(nha, where_clause=paste("SITE_NAME=", nha_nameSQL, "AND STATUS = 'NP'"))

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
#text1 <- gsub("\r?\n|\r", " ", text1)  #ORIGINAL line
text1 <- gsub("\n", "\\\\\\\\ \\\\par\\\\noindent ", text1)

rm(text)

#########################################################################
#Create an NHA data table to extract site information into piece by piece
nha_data <- as.data.frame(matrix(nrow=1, ncol=0))
nha_data$NHA_JOIN_ID <- selected_nha$NHA_JOIN_ID
nha_data$SITE_NAME <- selected_nha$SITE_NAME
nha_data$Description <- rm_between(text1, '|DESC_B|', '|DESC_E|', fixed=TRUE, extract=TRUE)[[1]]
nha_data$ThreatRecP <- rm_between(text1, '|THRRECP_B|', '|THRRECP_E|', fixed=TRUE, extract=TRUE)[[1]]

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
dbExecute(db_nha, paste("DELETE FROM nha_siteaccount WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_siteaccount", nha_data)
dbDisconnect(db_nha)

rm(selected_nha)
###############################################################################################################

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
#db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
 # dbSendStatement(db_nha, paste("UPDATE nha_siteaccount SET Description = ", sQuote(Description), " WHERE NHA_JOIN_ID = ", sQuote(selected_nha$NHA_JOIN_ID), sep=""))
#dbDisconnect(db_nha)

################################################################################################
# Threats and Recommendations Bullets ##########################################################
# Extract all the threat/rec bullets into a list and convert to a dataframe
TRB <- rm_between(text1, '|BULL_B|', '|BULL_E|', fixed=TRUE, extract=TRUE)
TRB <- ldply(TRB)
TRB <- as.data.frame(t(TRB))
TRB <- cbind(nha_data$NHA_JOIN_ID,TRB)
names(TRB) <- c("NHA_JOIN_ID","TRB")
TRB$NHA_JOIN_ID <- as.character(TRB$NHA_JOIN_ID)
TRB$TRB <- as.character(TRB$TRB)

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
dbExecute(db_nha, paste("DELETE FROM nha_TRbullets WHERE NHA_JOIN_ID = ", sQuote(nha_data$NHA_JOIN_ID), sep=""))
# add in the new data
dbAppendTable(db_nha, "nha_TRbullets", TRB)
dbDisconnect(db_nha)

rm(TRB)


##################
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


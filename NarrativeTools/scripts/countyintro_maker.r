
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

library(english)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

nameCounty <- "Butler"

NHAdest <- here::here()

#################################################################################################################
# get NHA GIS data
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
## Pull in political boundaries information #############
nha_PoliticalBoundaries <- arc.open(paste(serverPath,"PNHP.DBO.NHA_PoliticalBoundaries", sep=""))
selected_nha_PoliticalBoundaries <- arc.select(nha_PoliticalBoundaries) 
PoliticalBoundaries <- selected_nha_PoliticalBoundaries[which(selected_nha_PoliticalBoundaries$COUNTY %in% nameCounty),]
ListJoinID <- unique(PoliticalBoundaries$NHA_JOIN_ID)
ListJoinID <- paste(toString(sQuote(ListJoinID)), collapse = ",")

# access geodatabase to pull site info 
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
nha_list <- arc.select(nha, where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ") AND STATUS = 'NP'"))  # AND STATUS = 'NP'

ListJoinID <- nha_list$NHA_JOIN_ID
ListJoinID <- paste(toString(sQuote(ListJoinID)), collapse = ",")

# species lists
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
nha_relatedSpecies <- arc.select(nha_relatedSpecies, where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ")")) 
nha_relatedSpecies <- nha_relatedSpecies[c("ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE")]
nha_relatedSpecies <- unique(nha_relatedSpecies)

ET <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/ET")
ET <- arc.select(ET, c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")) # , c('EO_ID', 'EORANK', 'GRANK', 'SRANK', 'SPROT', 'PBSSTATUS', 'LASTOBS_YR', 'SENSITV_SP', 'SENSITV_EO'), where_clause=SQLquery_pointreps

speciestable <- merge(nha_relatedSpecies, ET, by="ELCODE", all.x=TRUE)
names(speciestable)[names(speciestable)=="SENSITV_SP"] <- c("SENSITIVE")
#################################################################################################################

# get a count of the different ranks of the NHAs

sigcount <- as.data.frame(table(nha_list$SIG_RANK))
names(sigcount) <- c("sig","count")



##############################################################################################################
## Write the output document for the site ###############
setwd(paste(NHAdest)) #, "countyIntros", nameCounty, sep="/")
pdf_filename <- paste(nameCounty,"_Intro_",gsub("[^0-9]", "", Sys.time() ),sep="")
makePDF("template_Formatted_Intro_PDF.rnw", pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd
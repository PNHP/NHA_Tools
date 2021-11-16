
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))
# get NHA GIS data
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")

nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
nha_list <- arc.select(nha, where_clause="STATUS = 'C'")  # where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ") AND STATUS = 'NP'")



includedNHAs <- nha_list[c("SITE_NAME","NHA_JOIN_ID")] #as.data.frame(nha_list$SITE_NAME)
#names(includedNHAs) <- "SITE_NAME"
includedNHAs$filename <- gsub(" ", "", includedNHAs$SITE_NAME, fixed=TRUE)
includedNHAs$filename <- gsub("#", "", includedNHAs$filename, fixed=TRUE)
includedNHAs$filename <- gsub("''", "", includedNHAs$filename, fixed=TRUE)
includedNHAs$filename <- gsub("'", "", includedNHAs$filename, fixed=TRUE) 

filelist <- list.files("P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/FinalSiteAccounts")
filelist_stripped <- gsub("(.+?)(\\_.*)", "\\1", filelist)
filelist_new <- data.frame(filelist, filelist_stripped)
filelist_new$filelist <- as.character(filelist_new$filelist)
filelist_new$filelist_stripped <- as.character(filelist_new$filelist_stripped)
filelist_new <- filelist_new[which(filelist_new$filelist_stripped %in% includedNHAs$filename),]

setdiff(includedNHAs$filename, filelist_new$filelist_stripped) 

pdf_links <- merge(includedNHAs, filelist_new, by.x="filename", by.y="filelist_stripped", all.x=TRUE)


write.csv(pdf_links, file="pdflinks.csv", row.names=FALSE)


if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

library(english)
library(ggplot2)
require(scales)
library(textclean)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

# Variables for the Intro!
nameCounty <- "Westmoreland"
YearUpdate <- 2021

editor1 <- "Anna Johnson"
editor1title <- "Connservation Planner"
editor1email <- "ajohnson@paconserve.org"
editor1phone <- "412-586-2389"
editor2 <- "Christopher Tracey"
editor2title <- "Conservation Planning Manager"
editor2email <- "ctracey@paconserve.org"
editor2phone <- "412-586-2326"

staffPNHP <- "JoAnn Albert, Jaci Braund, Charlie Eichelberger, Kierstin Carlson, Mary Ann Furedi, Steve Grund, Amy Jewitt, Anna Johnson, Susan Klugman, John Kunsman, Betsy Leppo, Jessica McPherson, Molly Moore, Ryan Miller, Greg Podniesinski, Megan Pulver, Erika Schoen, Scott Schuette, Emily Szoszorek, Kent Taylor, Christopher Tracey, Natalie Virbitsky, Jeff Wagner, Denise Watts, Joe Wisgo, Pete Woods, David Yeany, and Ephraim Zimmerman"

projectLead <- "Ryan Gordon"
projectLeadOrg <- "Southwest Pennsylvania Commission"
projectCode <- "SPC"

projectClient <- "Southwest Pennsylvania Commission"
projectClientAdd1 <- "112 Washington Pl \\#500"
projectClientAdd2 <- "Pittsburgh, PA 15219"


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
# change abbreviations to full words
nha_list$SIG_RANK <- ifelse(nha_list$SIG_RANK=="G", "Global", ifelse(nha_list$SIG_RANK=="R", "Regional", ifelse(nha_list$SIG_RANK=="S", "State", ifelse(nha_list$SIG_RANK=="L", "Local", NA))))

# get and calculate the map id form the temp layer
NHA_MapID <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_NHACounty")
NHA_MapID <- arc.select(NHA_MapID, c("COUNTY_NAM","NHA_Join_ID","SITE_NAME","MAP_ID"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
colnames(NHA_MapID)[4] <- "MAP_ID1"
nha_list <- merge(nha_list, NHA_MapID[c("NHA_Join_ID","MAP_ID1")], by.x="NHA_JOIN_ID", by.y="NHA_Join_ID")
nha_list$MAP_ID <- nha_list$MAP_ID1

# make a list of the NHAs in the county extract add data!
ListJoinID <- nha_list$NHA_JOIN_ID
ListJoinID <- paste(toString(sQuote(ListJoinID)), collapse = ",")

#################################
# species lists

# get a list of SUSNs
SUSN <- arc.open("E:/NHA_SUSN/NHA_SUSN.gdb/SUSN_multipart")
SUSN <- arc.select(SUSN, c("ELCODE","ELSUBID","SNAME","SCOMNAME"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
SUSN <- unique(SUSN)
SUSN <- SUSN[order(SUSN$SNAME),]
SUSN_type <- data.frame("SNAME"=c("Crotalus horridus","Glyptemys insculpta","Myotis sodalis","Terrapene carolina carolina","Nocomis biguttatus","Alosa chrysochloris"),"ELEMENT_TYPE"=c("AR","AR","AM","AR","AF","AF"))
SUSN <- merge(SUSN,SUSN_type, by="SNAME")
SUSN <- SUSN[c("ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE")]

# NHA species
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
nha_relatedSpecies <- arc.select(nha_relatedSpecies, where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ")")) 
nha_relatedSpecies <- nha_relatedSpecies[c("ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE")]
nha_relatedSpecies <- unique(nha_relatedSpecies)

nha_relatedSpecies <- nha_relatedSpecies[which(!is.na(nha_relatedSpecies$ELEMENT_TYPE)),]  # temp to remove issues !!!!!!!!!!!!!!!!!!!!!!!!!

# merge in the SUSNs
nha_relatedSpecies <- rbind(nha_relatedSpecies, SUSN)
nha_relatedSpecies <- unique(nha_relatedSpecies)

# join to the ET
ET <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/ET")
ET <- arc.select(ET, c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")) 

speciestable <- merge(nha_relatedSpecies, ET, by="ELCODE", all.x=TRUE)
names(speciestable)[names(speciestable)=="SENSITV_SP"] <- c("SENSITIVE")

# replace values where there are multiple taxa groups
speciestable[which(speciestable$ELEMENT_TYPE=="AAAA"),"ELEMENT_TYPE"] <- "AA"
speciestable[which(speciestable$ELEMENT_TYPE=="AAAB"),"ELEMENT_TYPE"] <- "AA"
speciestable[which(speciestable$ELEMENT_TYPE=="O"),"ELEMENT_TYPE"] <- "CGH"


TaxOrder <- c("AM","AB","AA","AR","AF","IMBIV","P","N","IZSPN","IMGAS","IIODO","IILEP","IILEY","IICOL02","IICOL","IIORT","IIPLE","IITRI","ILARA","ICMAL","CGH","S")
speciestable$OrderVec <- speciestable$ELEMENT_TYPE
#speciestable <- within(speciestable, OrderVec[SENSITIVE =="Y"| SENSITIVE_EO =="Y"] <- "S")    
speciestable$OrderVec <- factor(speciestable$OrderVec, levels=TaxOrder)
speciestable <- speciestable[order(speciestable$OrderVec, speciestable$SNAME),]

species <- speciestable$SNAME
taxa <- unique(speciestable$ELEMENT_TYPE)

# get a count of PX species for the report
EThistoricextipated <- nrow(ET[which(ET$SRANK=="SX"|ET$SRANK=="SH"),])
ETextipated <- nrow(ET[which(ET$SRANK=="SX"),])

# get a count of the total EOs in Biotics
eo_ptrep <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/eo_ptreps")
eo_ptrep <- arc.select(eo_ptrep) # , c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")
eo_count <- length(unique(eo_ptrep$EO_ID))

Round <- function(x,y) {
  if((y - x %% y) <= x %% y) { x + (y - x %% y)}
  else { x - (x %% y)}
}
eo_countrnd <- Round(eo_count, 1000)
eo_count <- paste(ifelse(eo_count<=eo_countrnd, "almost", "more than"), format(round(as.numeric(eo_countrnd)), big.mark=","), sep=" ")


 

#################################################################################################################
# Background GIS Data for the County

# phys provinces
CountyPhysProv <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyPhysProv")
CountyPhysProv <- arc.select(CountyPhysProv, c("COUNTY_NAM","PROVINCE","PROpSect"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep=""))  # 
CountyPhysProv$PROpSect <- as.numeric(CountyPhysProv$PROpSect)
CountyPhysProv <- CountyPhysProv[order(-CountyPhysProv$PROpSect),] 
CountyPhysSect <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyPhysSect")
CountyPhysSect <- arc.select(CountyPhysSect, c("COUNTY_NAM","SECTION","propSect"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
CountyPhysSect$propSect <- as.numeric(CountyPhysSect$propSect)
CountyPhysSect <- CountyPhysSect[order(-CountyPhysSect$propSect),] 
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
PhysSectDesc <- dbGetQuery(db_nha, "SELECT * FROM IntroData_PhysSect" )
dbDisconnect(db_nha)

# watersheds
CountyHUC4 <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyHUC04")
CountyHUC4 <- arc.select(CountyHUC4, c("COUNTY_NAM","HUC4","NAME","HUC2","NAME_1","propHUC4"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
CountyHUC4$propHUC4 <- as.numeric(CountyHUC4$propHUC4)
CountyHUC4 <- CountyHUC4[order(-CountyHUC4$propHUC4),]

#landcover
CountyNLCD16 <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyNLCD16")
CountyNLCD16 <- arc.select(CountyNLCD16, c("COUNTY_NAM","NLCD_Land_Cover_Class","Count","Area"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
NLCDgroup <- data.frame(c("Open Water","Developed, Open Space","Developed, Low Intensity","Developed, Medium Intensity","Developed, High Intensity","Barren Land","Deciduous Forest","Evergreen Forest","Mixed Forest","Shrub/Scrub","Herbaceuous","Hay/Pasture","Cultivated Crops","Woody Wetlands","Emergent Herbaceuous Wetlands"), c("Water","Developed","Developed","Developed","Developed","Other","Forest","Forest","Forest","Other","Other","Agriculture","Agriculture","Wetland","Wetland"))
names(NLCDgroup) <- c("NLCD_Land_Cover_Class","group")
CountyNLCD16 <- merge(CountyNLCD16,NLCDgroup)
CountyNLCD16$NLCD_Land_Cover_Class <- factor(CountyNLCD16$NLCD_Land_Cover_Class, levels = c("Open Water","Developed, Open Space","Developed, Low Intensity","Developed, Medium Intensity","Developed, High Intensity","Barren Land","Deciduous Forest","Evergreen Forest","Mixed Forest","Shrub/Scrub","Herbaceuous","Hay/Pasture","Cultivated Crops","Woody Wetlands","Emergent Herbaceuous Wetlands"))
CountyNLCD16$group <- factor(CountyNLCD16$group, levels=c("Forest","Developed","Agriculture","Water","Wetland","Other"))

CountyNLCD16$Acres <- CountyNLCD16$Area * 0.000247105 # convert to acres

CountyNLCD16sumgroup <- CountyNLCD16 %>% group_by(group) %>% summarize(sum=sum(Acres))
CountyNLCD16sumgroup$percent <- round((CountyNLCD16sumgroup$sum / sum(CountyNLCD16sumgroup$sum))*100,1)
CountyNLCD16sumgroup <- CountyNLCD16sumgroup[order(-CountyNLCD16sumgroup$sum),]

# make graph for land cover
p <- ggplot(CountyNLCD16, aes(fill=NLCD_Land_Cover_Class, y=Acres, x=group)) + 
  geom_bar(position="stack", stat="identity") +
  scale_fill_manual(values = c("Open Water"="#466B9F","Developed, Open Space"="#DEC5C5","Developed, Low Intensity"="#D99282","Developed, Medium Intensity"="#EB0000","Developed, High Intensity"="#AB0000","Barren Land"="#B3AC9F","Deciduous Forest"="#68AB5F","Evergreen Forest"="#1C5F2C","Mixed Forest"="#B5C58F","Shrub/Scrub"="#CCB879","Herbaceuous"="#DFDFC2","Herbaceuous"="#AB6C28","Hay/Pasture"="#DCD939","Cultivated Crops"="#AB6C28","Woody Wetlands"="#B8D9EB","Emergent Herbaceuous Wetlands"="#6C9FB8") ) +
  theme_classic() +
  #theme(legend.position=c(.9,.55)) +
  scale_y_continuous(labels = comma) +
  xlab("Landcover Group")
  png(paste(NHAdest,"/z_BaseImages/introMaps/",paste("Landcovergraph_", nameCounty,".png",sep=""), sep=""), width=8, height=5, units="in", res=200)
  print(p)
  dev.off()

# protected amounts
nha_area <- sum(nha_list$ACRES)
nha_arearnd <- Round(nha_area, 100)
nha_area <- paste(ifelse(nha_area<=nha_arearnd, "almost", "more than"), format(round(as.numeric(nha_arearnd)), big.mark=","), sep=" ")
  
NHA_ProtectedLands <- arc.open(paste(serverPath,"PNHP.DBO.NHA_ProtectedLands", sep=""))
NHA_ProtectedLands <- arc.select(NHA_ProtectedLands, where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ")")) 
NHA_ProtectedLands  <- NHA_ProtectedLands[c("PROTECTED_LANDS","PERCENT_","NHA_JOIN_ID")]

NHA_ProtectedLands_sum <- NHA_ProtectedLands %>%
  group_by(NHA_JOIN_ID) %>%
  summarise(Percent=sum(PERCENT_), n = n())
NHA_ProtectedLands_sum <- merge(NHA_ProtectedLands_sum, nha_list[c("SITE_NAME","NHA_JOIN_ID","ACRES")])
NHA_ProtectedLands_sum$ACRESprotected <- NHA_ProtectedLands_sum$ACRES *(NHA_ProtectedLands_sum$Percent/100)
  
# land trust service areas for the conclusions
CountyLandTrust <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyLandTrustServiceArea ")
CountyLandTrust <- arc.select(CountyLandTrust , c("COUNTY_NAM","ORG_NAME","ORG_PROFIL","ORG_WEB"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
    
# watershed service areas for the conclusions
CountyWatershed <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyWatershedServiceArea ")
CountyWatershed <- arc.select(CountyWatershed , c("COUNTY_NAM","Name","Profile","Weblink"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 

###################################################################################################################

# get some county inventory background information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  infoCNHI <- dbGetQuery(db_nha, paste("SELECT * FROM CNHI_data WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 
  
# get some Natural History background information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
 NatHistOverview <- dbGetQuery(db_nha, paste("SELECT * FROM IntroData_NatHistOverview WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 

# get watershed examples
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  WatershedsExamples <- dbGetQuery(db_nha, paste("SELECT * FROM IntroData_Watersheds WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 

# get a count of the different ranks of the NHAs
sigcount <- as.data.frame(table(nha_list$SIG_RANK))
names(sigcount) <- c("sig","count")

# editor formatting for citation
editor1a <- paste(word(editor1,-1),", ", gsub("\\s*\\w*$", "", editor1), sep="")

#advisory committee
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_AdvisComm <- dbGetQuery(db_nha, paste("SELECT * FROM AdvisoryCommittees WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha)

# SUSN data
SUSNJoinID <- paste(toString(sQuote(SUSN$SNAME)), collapse = ",")
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
SUSN_data <- dbGetQuery(db_nha, paste("SELECT * FROM SUSN WHERE SNAME IN (" , SUSNJoinID,")", sep="") )
dbDisconnect(db_nha)
SUSN <- merge(SUSN, SUSN_data, by="SNAME")
rm(SUSN_data)

# sources and funding
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_Sources <- dbGetQuery(db_nha, paste("SELECT * FROM nha_SourcesFunding WHERE SOURCE_REPORT = " , sQuote(projectCode), sep="") )
dbDisconnect(db_nha)

# images
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
IntroPhotos <- dbGetQuery(db_nha, paste("SELECT * FROM IntroData_Photos WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 

##############################################################################################################
## Write the output document for the intro ###############
setwd(paste(NHAdest,"CountyIntros", nameCounty, sep="/")) #, "countyIntros", nameCounty, sep="/")
pdf_filename <- paste(nameCounty,"_",YearUpdate,"_Intro",sep="") # ,gsub("[^0-9]", "", Sys.time() )
makePDF("template_Formatted_Intro_PDF.rnw", pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd
beepr::beep(sound=10, expr=NULL)

#############################################################################
# String all the NHAs PDFs together
library(pdftools)

includedNHAs <- as.data.frame(nha_list$SITE_NAME)
names(includedNHAs) <- "SITE_NAME"
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

setdiff(includedNHAs$filename, filelist_new$filelist_stripped) # make sure this is ZERO!!!!

setwd("P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/FinalSiteAccounts")  
pdf_combine(filelist_new$filelist, output=paste(NHAdest,"CountyIntros", nameCounty, paste(nameCounty,"NHAs","joined.pdf",sep="_"), sep="/"))
setwd(here::here())

#pdf_compress(input=paste(NHAdest,"CountyIntros", nameCounty, paste("NHA",nameCounty,"joined.pdf",sep="_"), sep="/"), output=paste(NHAdest,"CountyIntros", nameCounty, paste("NHA",nameCounty,"joined_compress.pdf",sep="_"), sep="/"))


###############
# string all the NHI parts together
f_Cover <- paste(NHAdest,"CountyIntros", nameCounty, paste(nameCounty,"Cover.pdf",sep="_"), sep="/")  
f_Intro <- paste(NHAdest,"CountyIntros", nameCounty,paste(nameCounty,"_",YearUpdate,"_Intro.pdf",sep=""), sep="/")
f_NHA <- paste(NHAdest,"CountyIntros", nameCounty, paste(nameCounty,"NHAs","joined.pdf",sep="_"), sep="/")

pdf_combine(c(f_Cover, f_Intro, f_NHA), output=paste(NHAdest,"CountyIntros", nameCounty, paste(nameCounty,"NHI.pdf",sep="_"), sep="/"))




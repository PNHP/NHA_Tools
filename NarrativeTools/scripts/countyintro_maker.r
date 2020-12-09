
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
nameCounty <- "Fayette"
YearUpdate <- 2020

editor1 <- "Anna Johnson"
editor1title <- "Connservation Planner"
editor1email <- "ajohnson@paconserve.org"
editor1phone <- ""
editor2 <- "Christopher Tracey"
editor2title <- "Conservation Planning Manager"
editor2email <- "ctracey@paconserve.org"
editor2phone <- "412-586-2326"

staffPNHP <- "JoAnn Albert, Charlie Eichelberger, Kierstin Carlson, Rocky Gleason, Steve Grund, Amy Jewitt, Anna Johnson, Susan Klugman, John Kunsman, Betsy Leppo, Jessica McPherson, Molly Moore, Ryan Miller, Megan Pulver, Erika Schoen, Scott Schuette, Emily Szoszorek, Christopher Tracey, Jeff Wagner, Denise Watts, Joe Wisgo, Pete Woods, David Yeany, and Ephraim Zimmerman."

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


ListJoinID <- nha_list$NHA_JOIN_ID
ListJoinID <- paste(toString(sQuote(ListJoinID)), collapse = ",")

# species lists
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
nha_relatedSpecies <- arc.select(nha_relatedSpecies, where_clause=paste("NHA_JOIN_ID IN (", ListJoinID, ")")) 
nha_relatedSpecies <- nha_relatedSpecies[c("ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE")]
nha_relatedSpecies <- unique(nha_relatedSpecies)

nha_relatedSpecies <- nha_relatedSpecies[which(!is.na(nha_relatedSpecies$ELEMENT_TYPE)),]  # temp to remove issues !!!!!!!!!!!!!!!!!!!!!!!!!

ET <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/ET")
ET <- arc.select(ET, c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")) 

speciestable <- merge(nha_relatedSpecies, ET, by="ELCODE", all.x=TRUE)
names(speciestable)[names(speciestable)=="SENSITV_SP"] <- c("SENSITIVE")


TaxOrder <- c("AM","AB","AAAA","AAAB","AR","AF","IMBIV","P","N","IZSPN","IMGAS","IIODO","IILEP","IILEY","IICOL02","IIORT","IIPLE","ILARA","ICMAL","CGH","S")
speciestable$OrderVec <- speciestable$ELEMENT_TYPE
#speciestable <- within(speciestable, OrderVec[SENSITIVE =="Y"| SENSITIVE_EO =="Y"] <- "S")    
speciestable$OrderVec <- factor(speciestable$OrderVec, levels=TaxOrder)
speciestable <- speciestable[order(speciestable$OrderVec, speciestable$SNAME),]

# speciestable <- merge(speciestable, taxaicon, by="ELEMENT_TYPE", all.x=TRUE)  # join the taxa icons

species <- speciestable$SNAME
taxa <- unique(speciestable$ELEMENT_TYPE)
 taxa[is.na(taxa)] <- "P"
# taxa[taxa=="O"] <- "CGH"
 taxa <- unique(taxa)

# get a count of PX species for the report
EThistoricextipated <- nrow(ET[which(ET$SRANK=="SX"|ET$SRANK=="SH"),])
ETextipated <- nrow(ET[which(ET$SRANK=="SX"),])

# get a count of the total EOs in Biotics
eo_ptrep <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/eo_ptreps")
eo_ptrep <- arc.select(eo_ptrep) # , c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")
eo_count <- nrow(eo_ptrep)
eo_ptrep <- NULL
eo_count <- ceiling(eo_count/1000)*1000
eo_count <- format(round(as.numeric(eo_count)), big.mark=",")  # 1,000.6

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

# land trust service areas for the conclusions
CountyLandTrust <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyLandTrustServiceArea ")
CountyLandTrust <- arc.select(CountyLandTrust , c("COUNTY_NAM","ORG_NAME","ORG_PROFIL","ORG_WEB"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
    
# watershed service areas for the conclusions
CountyWatershed <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyWatershedServiceArea ")
CountyWatershed <- arc.select(CountyWatershed , c("COUNTY_NAM","Name","Profile","Weblink"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 

###################################################################################################################

# get some county background information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  infoCNHI <- dbGetQuery(db_nha, paste("SELECT * FROM CNHI_data WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 
  
# get some Natural History background information
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
 NatHistOverview <- dbGetQuery(db_nha, paste("SELECT * FROM IntroData_NatHistOverview WHERE nameCounty = " , sQuote(nameCounty), sep="") )
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

# sources and funding
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
nha_Sources <- dbGetQuery(db_nha, paste("SELECT * FROM nha_SourcesFunding WHERE SOURCE_REPORT = " , sQuote(projectCode), sep="") )
dbDisconnect(db_nha)

# images
db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
IntroPhotos <- dbGetQuery(db_nha, paste("SELECT * FROM IntroData_Photos WHERE nameCounty = " , sQuote(nameCounty), sep="") )
dbDisconnect(db_nha) 

##############################################################################################################
## Write the output document for the site ###############
setwd(paste(NHAdest,"CountyIntros", nameCounty, sep="/")) #, "countyIntros", nameCounty, sep="/")
pdf_filename <- paste(nameCounty,"_Intro_",gsub("[^0-9]", "", Sys.time() ),sep="")
makePDF("template_Formatted_Intro_PDF.rnw", pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd

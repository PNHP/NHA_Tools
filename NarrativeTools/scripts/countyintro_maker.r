
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

library(english)
require(scales)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

nameCounty <- "Allegheny"
YearUpdate <- 2020
YearPrevious <- 

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
ET <- arc.select(ET, c("ELCODE","GRANK","SRANK","USESA","SPROT","PBSSTATUS","SENSITV_SP")) 

speciestable <- merge(nha_relatedSpecies, ET, by="ELCODE", all.x=TRUE)
names(speciestable)[names(speciestable)=="SENSITV_SP"] <- c("SENSITIVE")
#################################################################################################################
# Background GIS Data for the County

CountyPhysProv <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyPhysProv")
CountyPhysProv <- arc.select(CountyPhysProv, c("COUNTY_NAM","PROVINCE","PROpSect"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep=""))  # 

CountyPhysSect <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyPhysSect")
CountyPhysSect <- arc.select(CountyPhysSect, c("COUNTY_NAM","SECTION","propSect"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 


#landcover
CountyNLCD16 <- arc.open("E:/NHA_CountyIntroMaps/NHA_CountyIntroMaps.gdb/tmp_CountyNLCD16")
CountyNLCD16 <- arc.select(CountyNLCD16, c("COUNTY_NAM","NLCD_Land_Cover_Class","Count","Area"), where_clause = paste("COUNTY_NAM=",toupper(sQuote(nameCounty)), sep="")) 
NLCDgroup <- data.frame(c("Open Water","Developed, Open Space","Developed, Low Intensity","Developed, Medium Intensity","Developed, High Intensity","Barren Land","Deciduous Forest","Evergreen Forest","Mixed Forest","Shrub/Scrub","Herbaceuous","Hay/Pasture","Cultivated Crops","Woody Wetlands","Emergent Herbaceuous Wetlands"), c("Water","Developed","Developed","Developed","Developed","Other","Forest","Forest","Forest","Other","Other","Agriculture","Agriculture","Wetland","Wetland"))
names(NLCDgroup) <- c("NLCD_Land_Cover_Class","group")
CountyNLCD16 <- merge(CountyNLCD16,NLCDgroup)
CountyNLCD16$NLCD_Land_Cover_Class <- factor(CountyNLCD16$NLCD_Land_Cover_Class, levels = c("Open Water","Developed, Open Space","Developed, Low Intensity","Developed, Medium Intensity","Developed, High Intensity","Barren Land","Deciduous Forest","Evergreen Forest","Mixed Forest","Shrub/Scrub","Herbaceuous","Hay/Pasture","Cultivated Crops","Woody Wetlands","Emergent Herbaceuous Wetlands"))
CountyNLCD16$group <- factor(CountyNLCD16$group, levels=c("Forest","Developed","Agriculture","Water","Wetland","Other"))

CountyNLCD16$Acres <- CountyNLCD16$Area * 0.000247105


# make graph for landcover
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

  

###################################################################################################################

# get a count of the different ranks of the NHAs

sigcount <- as.data.frame(table(nha_list$SIG_RANK))
names(sigcount) <- c("sig","count")



##############################################################################################################
## Write the output document for the site ###############
setwd(paste(NHAdest,"CountyIntros", nameCounty, sep="/")) #, "countyIntros", nameCounty, sep="/")
pdf_filename <- paste(nameCounty,"_Intro_",gsub("[^0-9]", "", Sys.time() ),sep="")
makePDF("template_Formatted_Intro_PDF.rnw", pdf_filename) # user created function
deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
setwd(here::here()) # return to the main wd

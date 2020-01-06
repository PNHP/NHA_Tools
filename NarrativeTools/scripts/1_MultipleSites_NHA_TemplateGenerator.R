#-------------------------------------------------------------------------------
# Name:        NHA_TemplateGenerator.r
# Purpose:     Create a Word template for NHA content for multiple sites at once
# Author:      Anna Johnson
# Created:     2019-10-16
# Updated:     
#
# Updates:
# 
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------
####################################################
#Set up libraries, paths, and settings

# check and load required libraries
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)

# if (!requireNamespace("odbc", quietly = TRUE)) install.packages("odbc")
#   require(odbc)

# note: we need to install 64bit java: https://www.java.com/en/download/manual.jsp

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

####################################################
# Select focal NHAs

#Load list of NHAs that you wish to generate site reports for
NHA_list <- read.csv(here("_data", "sourcefiles", "NHAs_SWCounties.csv")) #download list that includes site names and/or (preferably) NHA Join ID

#if you are just running a few sites, you can select individual site by name or NHA join id:
#selected_nhas <- arc.select(nha, where_clause="SITE_NAME='White's Woods' AND STATUS = 'NP'")
#selected_nhas <- arc.select(nha, where_clause="NHA_JOIN_ID IN('alj82942')") 

#Select larger number of sites

#Method A) If using site names (but this gets hung up on apostrophes)
NHA_list <- NHA_list[order(NHA_list$Site.Name),] #order alphabetically
Site_Name_List <- as.vector(NHA_list$Site.Name)
Site_Name_List <- as.list(Site_Name_List)
SQLquery_Sites <- paste("SITE_NAME IN(",paste(toString(sQuote(Site_Name_List)),collapse=", "), ") AND STATUS IN('NP','NR')") #use this to input vector of site names to select from into select clause.

#Method B) Or use NHA join ID 
#Site_NHAJoinID_List <-as.character(NHA_list$NHA.Join.ID)
#SQLquery_Sites <- paste("NHA_Join_ID IN(",paste(toString(sQuote(Site_NHAJoinID_List)),collapse=", "), ") AND STATUS IN('NP','NR')")

serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")

nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))
selected_nhas <- arc.select(nha, where_clause=SQLquery_Sites)
dim(selected_nhas) #check how many records are returned to ensure it meets expectations

selected_nhas <- selected_nhas[order(selected_nhas$SITE_NAME),]#order alphabetically

####
#manual check to ensure that your original list of NHAs and the selected NHA data frame both have sites in the same order
identical(selected_nhas$SITE_NAME, as.character(NHA_list$Site.Name))
####

####################################################
## Build the Species Table #########################

# open the related species table and get the rows that match the NHA join ids from the selected NHAs
nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep=""))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies) 
Site_ID_list <- as.list(unique(selected_nhas$NHA_JOIN_ID)) #added in unique for occasions where a site might be in the import list multiple times (e.g. when it crosses county lines and we want to talk about it for all intersecting counties)

#open linked species tables and select based on list of selected NHAs
species_table_select <- list()
for (i in 1:length(Site_ID_list)) {
  species_table_select[[i]] <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==Site_ID_list[i]),]
}

species_table_select #list of species tables

#merge species lists w/ EO information from Point Reps database

#create one big data frame first of all the EOIDs across all the selected NHAs
speciestable <- bind_rows(species_table_select, .id = "column_label")

SQLquery_pointreps <- paste("EO_ID IN(",paste(toString(speciestable$EO_ID),collapse=", "), ")") #don't use quotes around numbers

pointreps <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/eo_ptreps")
selected_pointreps <- arc.select(pointreps, c('EO_ID', 'EORANK', 'GRANK', 'SRANK', 'SPROT', 'PBSSTATUS', 'LASTOBS', 'SENSITV_SP', 'SENSITV_EO'), where_clause=SQLquery_pointreps) #select subset of columns from EO pointrep database

#if this select command does not work (which sometimes happens to me?), try this method, which will work
#selected_pointreps <- arc.select(pointreps, c('EO_ID', 'EORANK', 'GRANK', 'SRANK', 'SPROT', 'PBSSTATUS', 'LASTOBS', 'SENSITV_SP', 'SENSITV_EO'))
#selected_pointreps <- subset(selected_pointreps, selected_pointreps$EO_ID %in% speciestable$EO_ID)

dim(selected_pointreps)

speciestable <- merge(speciestable,selected_pointreps, by="EO_ID")

names(speciestable)[c(15:22)] <- c("EORANK","GRANK","SRANK","SPROT","PBSSTATUS","LASTOBS","SENSITIVE","SENSITIVE_EO") #should rewrite this to be resilient to changing order of data frames

species_table_select<- split(speciestable, speciestable$column_label) #split back into a list of species tables

namevec <- NULL #name species tables so that you can tell if they end up in a weird order
for (i in seq_along(species_table_select)){
  namevec[i] <- species_table_select[[i]]$NHA_JOIN_ID[1]}
names(species_table_select) <- namevec

#Make a list of all the ELCODES within all the species tables, to pull further info out from databases
SD_specieslist <- lapply(seq_along(species_table_select),
                         function(x) species_table_select[[x]][,c("ELCODE")])
SD_specieslist <- unlist(SD_specieslist)

#Connect to database and merge ElSubID into species tables
TRdb <- dbConnect(SQLite(), dbname=TRdatabasename) #connect to SQLite DB
Join_ElSubID <- dbGetQuery(TRdb, paste0("SELECT ELSubID, ELCODE FROM ET"," WHERE ELCODE IN (", paste(toString(sQuote(SD_specieslist)), collapse = ", "), ");"))
dbDisconnect(TRdb)

SD_speciesTable <- lapply(seq_along(species_table_select),
                          function(x) merge(species_table_select[[x]], Join_ElSubID, by="ELCODE"))# merge in the ELSubID until we get it fixed in the GIS layer
names(SD_speciesTable) <- namevec #keep names associated with list of tables

#add a column in each selected NHA species table for the image path, and assign image. 
#Note: this uses the EO_ImSelect function, which I modified in the source script to work with a list of species tables
for (i in 1:length(SD_speciesTable)) {
    for(j in 1:nrow(SD_speciesTable[[i]])){
  SD_speciesTable[[i]]$Images <- EO_ImSelect(SD_speciesTable[[i]][j,])
    }
}

# modify image assignments to account for finer groupings of the inverts--this part is not working right, come back to later
#for (i in 1:length(SD_speciesTable)) {
#  for(j in 1:nrow(SD_speciesTable[[i]])){
#    SD_speciesTable[[i]]$Images <- EO_ImFix(SD_speciesTable[[i]][j,])
#  }
#}

############################################
# write species table to the SQLite database
speciesTable4db <- SD_speciesTable

for (i in 1:length(speciesTable4db)){
  speciesTable4db[[i]] <- cbind(selected_nhas$NHA_JOIN_ID[i], speciesTable4db[[i]])
}

for (i in 1:length(speciesTable4db)){
 names(speciesTable4db[[i]])[1] <- "NHA_JOIN_ID"
 speciesTable4db[[i]]$NHA_JOIN_ID <- as.character(speciesTable4db[[i]]$NHA_JOIN_ID) 
}

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
# delete existing threats and recs for this site if they exist
for (i in 1:length(selected_nhas$NHA_JOIN_ID)){
  dbExecute(db_nha, paste("DELETE FROM nha_species WHERE NHA_JOIN_ID = ", sQuote(selected_nhas$NHA_JOIN_ID[i]), sep=""))
}

# add in the new data
for (i in 1:length(speciesTable4db)){  
dbAppendTable(db_nha, "nha_species", speciesTable4db[[i]])
}
dbDisconnect(db_nha)

#################################################
### Pull out info from Biotics for each site

eoid_list <- list() #list of EOIDs to pull Biotics records with
for (i in 1: length(SD_speciesTable)){
eoid_list[[i]] <- paste(toString(SD_speciesTable[[i]]$EO_ID), collapse = ",")
} # make a list of EOIDs to get data from

ptreps <- arc.open(paste(biotics_gdb,"eo_ptreps",sep="/"))

ptreps_selected <- list() #list of EO records for each selected NHA
for (i in 1:length(eoid_list)){
ptreps_selected[[i]] <- arc.select(ptreps, fields=c("EO_ID", "SNAME", "EO_DATA", "GEN_DESC","MGMT_COM","GENERL_COM"), where_clause=paste("EO_ID IN (", eoid_list[[i]], ")",sep="") )
}

################################################
# calculate the site significance rank based on the species present at the site 

source(here::here("scripts","nha_ThreatsRecDatabase","2_loadSpeciesWeights.r"))

#check whether there are multiple EOs in the species table for the same species, and only keep one record for each species, the most recently observed entry
for (i in 1:length(SD_speciesTable)) {
  duplic_Spp <- SD_speciesTable[[i]]
  duplic_Spp <- duplic_Spp[order(duplic_Spp$LASTOBS, decreasing=TRUE),]
  SD_speciesTable[[i]] <- duplic_Spp[!duplicated(duplic_Spp[1]),]
}

sigrankspecieslist <- SD_speciesTable #so if things get weird, you only have to come back to this step

#remove species which are not included in thesite ranking matrices--GNR, SNR, SH/Eo Rank H, etc. 
sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$GRANK!="GNR"&!is.na(sigrankspecieslist[[x]]$EORANK)),]) #remove EOs which are GNR

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$GRANK!="GNA"&!is.na(sigrankspecieslist[[x]]$EORANK)),]) #remove EOs which are GNA

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$SRANK!="SNR"&!is.na(sigrankspecieslist[[x]]$EORANK)),]) #remove EOs which are SNR

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$SRANK!="SH"&!is.na(sigrankspecieslist[[x]]$EORANK)),]) #remove EOs which are SH

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$EORANK!="H"),]) #remove EOs w/ an H quality rank

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$SRANK!="SU"&!is.na(sigrankspecieslist[[x]]$EORANK)),]) #remove EOs which are SU


#Merge rounded S, G, and EO ranks into individual species tables
sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) merge(sigrankspecieslist[[x]], rounded_grank, by="GRANK"))

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) merge(sigrankspecieslist[[x]], rounded_srank, by="SRANK"))

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) merge(sigrankspecieslist[[x]], nha_EORANKweights, by="EORANK"))

#Calculate rarity scores for each species within each table
RarityScore <- function(x, matt) {
  matt <- nha_gsrankMatrix
  if (nrow(x) > 0) {
    for(i in 1:nrow(x)) {
      x$rarityscore[i] <- matt[x$GRANK_rounded[i],x$SRANK_rounded[i]] }}
  else {
    "NA"
  }
  x$rarityscore
}

res <- lapply(sigrankspecieslist, RarityScore) #calculate rarity score for each species table
sigrankspecieslist <- Map(cbind, sigrankspecieslist, RarityScore=res) #bind rarity score into each species table
names(sigrankspecieslist) <- namevec #reassign the names

#Adjust site significance rankings based on presence of G1, G2, and G3 EOs

#create flags for sites with a G3 species (which should automatically be at least regional)
G3_regional <- lapply(seq_along(sigrankspecieslist),
                      function(x) "G3" %in% sigrankspecieslist[[x]]$GRANK_rounded)

#create flags for sites with a G1 or G2 species (which should automatically be a global site)
G1_global <- lapply(seq_along(sigrankspecieslist),
                      function(x) "G1" %in% sigrankspecieslist[[x]]$GRANK_rounded)
G2_global <- lapply(seq_along(sigrankspecieslist),
                    function(x) "G2" %in% sigrankspecieslist[[x]]$GRANK_rounded)

#Calculate scores for each site, aggregating across all species and assign significance rank category. Skip any remaining NA values in the rarity scores      
TotalScore  <- lapply(seq_along(sigrankspecieslist), 
                      function(x) sigrankspecieslist[[x]]$RarityScore[!is.na(sigrankspecieslist[[x]]$RarityScore)] * sigrankspecieslist[[x]]$Weight) # calculate the total score for each species
SummedTotalScore <- lapply(TotalScore, sum) 
SummedTotalScore <- lapply(SummedTotalScore, as.numeric)

SiteRank <- list() #create empty list object to write into

for (i in seq_along(SummedTotalScore)) {
  if(SummedTotalScore[[i]]==0|is.na(SummedTotalScore[[i]])){
    SiteRank[[i]] <- "Local"
  } else if(is.na(SummedTotalScore[[i]])){
    SiteRank[[i]] <- "Local"
  } else if(SummedTotalScore[[i]]>0 & SummedTotalScore[[i]]<=152) {
    SiteRank[[i]] <- "State"
  } else if(SummedTotalScore[i]>152 & SummedTotalScore[[i]]<=457) {
    SiteRank[[i]] <- "Regional"
  }  else if (SummedTotalScore[[i]]>457) {
    SiteRank[[i]] <- "Global"
  }
}

#manual check step, take a look if you want to see where things are mismatched--do any sites need to have ranks overriden?
check <- as.data.frame(cbind(SiteRank, SummedTotalScore, G3_regional, G2_global, G1_global, namevec, selected_nhas$NHA_JOIN_ID))

#Do the site ranking overrides automatically

for (i in seq_along(SiteRank)) {
  if(G3_regional[[i]]=="TRUE") {
    SiteRank[[i]] <-"Regional"
  } else if(G2_global[[i]]=="TRUE"){
    SiteRank[[i]] <- "Global"
  } else if(G1_global[[i]]=="TRUE"){
    SiteRank[[i]] <- "Global"
    }
}

#reorder the sites
selected_nhas <- selected_nhas[match(namevec, selected_nhas$NHA_JOIN_ID),]#order to match order of species tables

#ensure that both data frames have sites in the same order
identical(selected_nhas$NHA_JOIN_ID, namevec)


#merge significance data into NHA table
selected_nhas$site_score <- unlist(SiteRank) #add site significance rankings to NHA data frame
selected_nhas$site_rank <- unlist(SummedTotalScore) #add site significance score to NHA data frame

summary(as.factor(selected_nhas$site_score)) #manual check step: take a look at distribution of significance ranks


#########################################################
#Build pieces needed for each site report

#generate list of folder paths and file names for selected NHAs
nha_foldername_list <- list()
for (i in 1:length(Site_Name_List)) {
  nha_foldername_list[[i]] <- gsub(" ", "", Site_Name_List[i], fixed=TRUE)
  nha_foldername_list[[i]] <- gsub("#", "", nha_foldername_list[i], fixed=TRUE)
  nha_foldername_list[[i]] <- gsub("'", "", nha_foldername_list[i], fixed=TRUE)
}
nha_foldername_list <- unlist(nha_foldername_list) #list of folder names

nha_filename_list <- list()
for (i in 1:length(nha_foldername_list)) {
  nha_filename_list[i] <- paste(nha_foldername_list[i],"_",gsub("[^0-9]", "", Sys.Date() ),".docx",sep="")
}
nha_filename_list <- unlist(nha_filename_list) #list of file names

#generate URLs for each EO at site
URL_EOs <- list()
for (i in 1:length(ptreps_selected)){
URL_EOs[[i]] <- lapply(seq_along(ptreps_selected[[i]]$EO_ID), function(x)  paste("https://bioticspa.natureserve.org/biotics/services/page/Eo/",ptreps_selected[[i]]$EO_ID[x],".html", sep=""))
URL_EOs[[i]] <- sapply(seq_along(URL_EOs[[i]]), function(x) paste("(",URL_EOs[[i]][x],")", sep=""))
}

Sname_link <- list()
for (i in 1:length(ptreps_selected)){
Sname_link[[i]] <- sapply(seq_along(ptreps_selected[[i]]$SNAME), function(x) paste("[",ptreps_selected[[i]]$SNAME[x],"]", sep=""))
}

Links <- mapply(paste, Sname_link, URL_EOs, sep="") #for R markdown, list of text plus hyperlinks to create links to biotics page for each EO at each site

# set up the directory folders where site account pieces go
NHAdest1 <- sapply(seq_along(nha_foldername_list), function(x) paste(NHAdest,"DraftSiteAccounts",nha_foldername_list[x],sep="/"))
sapply(seq_along(NHAdest1), function(x) dir.create(NHAdest1[x], showWarnings=FALSE)) # make a folder for each site, if those folders do not exist already
sapply(seq_along(NHAdest1), function(x) dir.create(paste(NHAdest1[x],"photos", sep="/"), showWarnings = F)) # make a folder for each site, for photos

#######################################################################
#Pull out species-specific threats/recs from the database for each site

TRdb <- dbConnect(SQLite(), dbname=TRdatabasename) #connect to SQLite DB

ElementTR <- list() #
ThreatRecTable <- list()
ET <- list()

for (i in 1:length(SD_speciesTable)){
ElementTR[[i]] <- dbGetQuery(TRdb, paste0("SELECT * FROM ElementThreatRecs"," WHERE ELSubID IN (", paste(toString(sQuote(SD_speciesTable[[i]]$ELSubID)), collapse = ", "), ");"))
ThreatRecTable[[i]]  <- dbGetQuery(TRdb, paste0("SELECT * FROM ThreatRecTable"," WHERE TRID IN (", paste(toString(sQuote(ElementTR[[i]]$TRID)), collapse = ", "), ");"))
ET[[i]] <- dbGetQuery(TRdb, paste0("SELECT SNAME, ELSubID FROM ET"," WHERE ELSubID IN (", paste(toString(sQuote(ElementTR[[i]]$ELSubID)), collapse = ", "), ");"))
}

#join general threats/recs table with the element table 
ELCODE_TR <- list() #create list of threat rec info to print for each site, to call in R Markdown
for (i in 1:length(ElementTR)){
ELCODE_TR[[i]] <- ElementTR[[i]] %>%
  inner_join(ET[[i]]) %>%
  inner_join(ThreatRecTable[[i]])
}


######################################################
# make the maps

#convert geometry to simple features for the map
slnha <- list()
nha_sf_list <- list()

nha_sf_list <- arc.data2sf(selected_nhas)

a <- st_area(nha_sf_list) #calculate area
a <- a*0.000247105 #convert m2 to acres
selected_nhas$Acres <- as.numeric(a)

mtype <- 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}?'
basetiles <- sapply(seq_along(nha_sf_list$geom), function(x) tmaptools::read_osm(nha_sf_list$geom[x], type=mtype, ext=1.5, use.colortable=FALSE))

# plot the maps
nha_map <- list()
for (i in 1:length(nha_sf_list$geom)) {
tmap_mode("plot")
nha_map[[i]] <- tm_shape(basetiles[[i]], unit="m") +
  tm_rgb() +
  tm_shape(nha_sf_list[i,]) +
  tm_borders("red", lwd=1.5)+
  tm_legend(show=FALSE) + 
  tm_layout(attr.color="white") +
  tm_compass(type="arrow", position=c("left","bottom")) +
  tm_scale_bar(position=c("center","bottom"))
tmap_save(nha_map[[i]], filename=paste(NHAdest1[i], "/", nha_foldername_list[[i]],"_tempmap.png",sep=""), units="in", width=7) 
}

###################################################################
#Write the output R markdown document for each site, all at once 

for (i in 1:length(nha_filename_list)) {
  NHAdest2 <- NHAdest1[i]
  selectedNhas <- selected_nhas[i,]
  speciesTable <- SD_speciesTable[[i]]
  ptrepsSelected <- ptreps_selected[[i]]
  ELCODETR <- ELCODE_TR[[i]]
  nhaFoldername <- nha_foldername_list[[i]]
  LinksSelect <- Links[[i]]
  SiteRank1 <- SiteRank[[i]]

rmarkdown::render(input=here::here("scripts","template_NHAREport_part1v2.Rmd"), output_format="word_document", 
                  output_file=nha_filename_list[[i]],
                  output_dir=NHAdest1[i])
}  

# delete the map, after its included in the markdown

for (i in 1:length(nha_filename_list)){
fn <- paste(NHAdest1[i], "/", nha_foldername_list[i],"_tempmap.png",sep="")
if (file.exists(fn)) #Delete file if it exists
  file.remove(fn)
}

####################################################
#output data about NHAs with completed templates to database and summary sheets

# insert the NHA data into a sqlite database
nha_data <- NULL

nha_data <- selected_nhas[,c("SITE_NAME","SITE_TYPE","NHA_JOIN_ID","site_rank","site_score","BRIEF_DESC","COUNTY","Muni","USGS_QUAD","ASSOC_NHA","PROTECTED_LANDS")]
nha_data$nha_filename <- unlist(nha_filename_list)
nha_data$nha_folderpath <- NHAdest1
nha_data$nha_foldername <- unlist(nha_foldername_list)

db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database

dbAppendTable(db_nha, "nha_main", nha_data)
dbDisconnect(db_nha)

#Create record of NHA creation for organizing writing and editing tasks

#create some summary stats describing EOs at each site by taxa group, to help with determining who should write site accounts
#build functions
plantperc <- function(x) {
  p <- nrow(species_table_select[[x]][species_table_select[[x]]$ELEMENT_TYPE == 'P',])
  pt <- nrow(species_table_select[[x]])
  p/pt
}

musselperc <- function(x){
  u <- nrow(species_table_select[[x]][species_table_select[[x]]$ELEMENT_TYPE == 'U',])
  ut <- nrow(species_table_select[[x]])
  u/ut
}

insectperc <- function(x){
  i <- nrow(species_table_select[[x]][species_table_select[[x]]$ELEMENT_TYPE %in%  c('IM','IB','IA','ID','IT'),])
  it <- nrow(species_table_select[[x]])
  i/it
}
  
herpperc <- function(x){
  h <- nrow(species_table_select[[x]][species_table_select[[x]]$ELEMENT_TYPE %in%  c('R','A'),])
  ht <- nrow(species_table_select[[x]])
  h/ht
}

#calculate for each spp table, using functions
PlantEO_percent <- unlist(lapply(seq_along(species_table_select),
       function(x) plantperc(x)))
MusselEO_percent <- unlist(lapply(seq_along(species_table_select),
                                 function(x) musselperc(x)))
InsectEO_percent <- unlist(lapply(seq_along(species_table_select),
                                 function(x) insectperc(x)))
HerpEO_percent <- unlist(lapply(seq_along(species_table_select),
                                 function(x) herpperc(x)))
nEOs <- unlist(lapply(seq_along(species_table_select),
                      function(x) nrow(species_table_select[[x]]))) #number of total EOs at site

EO_sumtable <- as.data.frame(cbind(nEOs, PlantEO_percent,MusselEO_percent,InsectEO_percent,HerpEO_percent)) #bind summary stats into one table together

db_nha <- dbConnect(SQLite(), dbname=nha_databasename)
nha_data$Template_Created <- as.character(Sys.Date()) 
nha_sum <- nha_data[,c("NHA_JOIN_ID","SITE_NAME","COUNTY","nha_folderpath", "site_score")]
nha_sum <- cbind(nha_sum, EO_sumtable)
dbAppendTable(db_nha, "nha_sitesummary", nha_sum) 


dbDisconnect(db_nha) #disconnect

## For now, you should hand copy and paste the new rows into the NHA site summary Excel worksheet. I created an exports folder within the database folder where .csv versions can periodically be sent, as batches of NHA templates are created. 
########################


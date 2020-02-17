# Calculate Site Significance Ranks for a list of sites

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
require(RSQLite)

# load the arcgis license
arc.check_product() 

#Pull in significance rank calculator matrices
nha_gsrankMatrix <- read.csv(here("sourcefiles","nha_gsrankMatrix.csv"), row.names=1, stringsAsFactors=FALSE)
nha_gsrankMatrix <- as.matrix(nha_gsrankMatrix)

nha_EORANKweights <- read.csv(here("sourcefiles","nha_EORANKweights.csv"), stringsAsFactors=FALSE)

rounded_srank <- read.csv(here("sourcefiles","rounded_srank.csv"), stringsAsFactors=FALSE)
rounded_grank <- read.csv(here("sourcefiles","rounded_grank.csv"), stringsAsFactors=FALSE)

names(rounded_grank)[1] <- "G_RANK"
names(rounded_srank)[1] <- "S_RANK"
names(nha_EORANKweights)[1] <- "BASIC_EO_R"

#Load list of NHAs missing sig ranks
NHA_list <- read.csv(here("sourcefiles", "NHA_missing_SigRank.csv"))
NHA_list <- NHA_list[NHA_list$Species_Table=="Yes",]
Site_ID_List <- NHA_list$NHA_JOIN_ID #get list of NHA join ids to pull out species tables



# open the NHA feature class and select and NHAs
serverPath <- paste("C:/Users/",Sys.getenv("USERNAME"),"/AppData/Roaming/ESRI/ArcGISPro/Favorites/PNHP.PGH-gis0.sde/",sep="")
nha <- arc.open(paste(serverPath,"PNHP.DBO.NHA_Core", sep=""))

nha_relatedSpecies <- arc.open(paste(serverPath,"PNHP.DBO.NHA_SpeciesTable", sep="")) #(here::here("_data", "NHA_newTemplate.gdb",""))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies) 

#open linked species tables and select based on list of selected NHAs
species_table_select <- list()
for (i in 1:length(Site_ID_List)) {
  species_table_select[[i]] <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==Site_ID_List[i]),]
}

species_table_select #list of 124 species tables

#only retain columns of interest in species tables  
sigrankspecieslist <- lapply(seq_along(species_table_select),
         function(x) subset(species_table_select[[x]], select=c("SNAME","G_RANK","S_RANK","BASIC_EO_R")))
        
#remove species which are not relevant to site rankings--GNR, SNR, SH/Eo Rank H 
sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                                 function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$G_RANK!="GNR"&!is.na(sigrankspecieslist[[x]]$BASIC_EO_R)),]) #remove EOs which are GNR

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$S_RANK!="SNR"&!is.na(sigrankspecieslist[[x]]$BASIC_EO_R)),]) #remove EOs which are SNR

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$S_RANK!="SH"&!is.na(sigrankspecieslist[[x]]$BASIC_EO_R)),]) #remove EOs which are SH

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                             function(x) sigrankspecieslist[[x]][which(sigrankspecieslist[[x]]$BASIC_EO_R!="H"),]) #remove EOs w/ an H quality rank

#Merge rounded S, G, and EO ranks into individual species tables
sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                              function(x) merge(sigrankspecieslist[[x]], rounded_grank, by="G_RANK"))

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                              function(x) merge(sigrankspecieslist[[x]], rounded_srank, by="S_RANK"))

sigrankspecieslist <- lapply(seq_along(sigrankspecieslist), 
                              function(x) merge(sigrankspecieslist[[x]], nha_EORANKweights, by="BASIC_EO_R"))

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
sigrankspecieslist2 <- Map(cbind, sigrankspecieslist, RarityScore=res) #bind rarity score into each species table

#Calculate scores for each site, aggregating across all species and assign significance rank category      
TotalScore  <- lapply(seq_along(sigrankspecieslist2), 
         function(x) sigrankspecieslist2[[x]]$RarityScore * sigrankspecieslist2[[x]]$Weight) # calculate the total score for each species
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

#Export results as CSV by merging site ranks into original list of NHAs
NHA_list$SiteRank <- SiteRank
NHA_list$SiteScore <- SummedTotalScore
output <- apply(NHA_list,2, as.character) #this was still in list format somehow/this command fixes that issue for export
write.csv(output, file="SiteRanks.csv")

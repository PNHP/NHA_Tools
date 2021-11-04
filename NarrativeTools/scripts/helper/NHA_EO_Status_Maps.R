# check and load required libraries
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

if (!requireNamespace("ggmap", quietly = TRUE)) install.packages("ggmap")
require(ggmap)
if (!requireNamespace("RColorBrewer", quietly = TRUE)) install.packages("RColorBrewer")
require(RColorBrewer)
if (!requireNamespace("viridis", quietly = TRUE)) install.packages("viridis")
require(viridis)


# load in the paths and settings file (which contains the rest of the libraries needed)
source(here::here("scripts", "0_PathsAndSettings.r"))

#set data output folder

datadest <- "H:/Github_NHA/NHA_Tools/NarrativeTools/_data/output/NHA_EO_Status/"

#data source file locations (any extra shapefiles, .csv files etc)
datasource <- "H:/Github_NHA/NHA_Tools/NarrativeTools/_data/sourcefiles/"

#######################################################
#Import Biotics data (EO Point Reps from Biotics)  ####
#######################################################

pointreps <- arc.open("W:/Heritage/Heritage_Data/Biotics_datasets.gdb/eo_ptreps")
selected_pointreps <- arc.select(pointreps , c('EO_ID', 'ELCODE', 'EORANK','GRANK', 'SRANK', 'SPROT', 'PBSSTATUS', 'LASTOBS_YR', 'SENSITV_SP', 'SENSITV_EO'))
#assign taxa groups for splitting out dataset (can be further refined as desired)

selected_pointreps$TAXA <- ifelse(grepl('^AA', selected_pointreps$ELCODE), "Amphibians", 
    ifelse(grepl('^AB', selected_pointreps$ELCODE), "Birds",
    ifelse(grepl('^AR', selected_pointreps$ELCODE), "Reptiles",          
    ifelse(grepl('^AM', selected_pointreps$ELCODE), "Mammals",          
    ifelse(grepl('^AF', selected_pointreps$ELCODE), "Fish",          
    ifelse(grepl('^P', selected_pointreps$ELCODE), "Vascular Plants",   
    ifelse(grepl('^N', selected_pointreps$ELCODE), "Nonvascular Plants",
    ifelse(grepl('^IIODO', selected_pointreps$ELCODE), "Odonates",
    ifelse(grepl('^IILE', selected_pointreps$ELCODE), "Lepidopterans",
    ifelse(grepl('^IMBIV', selected_pointreps$ELCODE), "Freshwater Mussels",
    ifelse(grepl('^C', selected_pointreps$ELCODE), "Natural Community", "Other"
                                                     )))))))))))
taxalist <- unique(selected_pointreps$TAXA)

#and a broader grouping, basically just botany vs. zoology vs. ecology
#I suspect that a good bit of the "other" group should actually also be zoology--I think I missed some inverts in the taxa coding...

selected_pointreps$BROAD_TAXA <- ifelse(selected_pointreps$TAXA %in% c("Vascular Plants", "Nonvascular Plants"), "Botany",
                                 ifelse(selected_pointreps$TAXA %in% c("Amphibians","Birds","Reptiles","Mammals","Fish","Odonates","Lepidopterans","Freshwater Mussels"), "Zoology",
                                 ifelse(selected_pointreps$TAXA == "Natural Community", "Ecology", "Other")))
taxalist2 <- unique(selected_pointreps$BROAD_TAXA)

selected_pointreps_sf <- arc.data2sf(selected_pointreps)    

#create factor that codes for EOs that are more or less than 25 years old (based on 2021 as the current year)
selected_pointreps_sf$include <- factor(ifelse(selected_pointreps_sf$LASTOBS_YR>=1994,"less than 25 years","older than 25 years"))
levels(selected_pointreps_sf$include) <- c("less than 25 years","older than 25 years")

#Can do some additional filtering/selecting, based on EO Rank
selected_pointreps_sf$EORANK <- as.factor(selected_pointreps_sf$EORANK)

#select just H/F/X records or just extant records

selected_pointreps_sf_LOST <- selected_pointreps_sf[(selected_pointreps_sf$EORANK %in% c("F","F?","H","H?","X","X?")),]
selected_pointreps_sf_EXTANT <- selected_pointreps_sf[!(selected_pointreps_sf$EORANK %in% c("F","F?","H","H?","X","X?")),]
selected_pointreps_sf_EXTANT <- selected_pointreps_sf[(selected_pointreps_sf$LASTOBS_YR >1979),] #further filter extant records to also correspond only to EOs that have been visited since 1980, since we do not automatically retire EOs from E to H after some time goes by

#######################################
## Import spatial data   ##############
#######################################
arc.check_portal() #ensure you are logged in to feature services

#get a county layer for PA
county_shp <- arc.open("W:/LYRS/Boundaries_Political/County Hollow.lyr")
county_shp <- arc.select(county_shp)
county_sf <- arc.data2sf(county_shp)

#municipalities layer for PA
muni_shp<- arc.open("W:/LYRS/Boundaries_Political/Municipalities Hollow.lyr")
muni_shp <- arc.select(muni_shp)
muni_sf <- arc.data2sf(muni_shp)

#couldn't figure out how to pull out a nested feature class from the .lyr file so I downloaded the shapefile for PA boundary
PA_shp <- read_sf(paste(datasource, "PA State Boundary.shp", sep=""))
PA_shp <- st_as_sf(PA_shp)

#layer for fishnet polygon within PA state boundary, to create heatmap grid
PA_grid <- read_sf(paste(datasource, "PA_samplinggrid_3.shp", sep="")) #grid is squares of 7500 x 7500 meters
PA_grid <- st_as_sf(PA_grid)

#Current NHAs layer (core habitat), from feature service. Just make sure you are logged in to WPC feature services via ArcGis Portal
NHA_core_curr <- arc.open("https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHA/FeatureServer/2")
NHA_core_curr <- arc.select(NHA_core_curr)
NHA_core_curr <- arc.data2sf(NHA_core_curr)
NHA_core_curr <- subset(NHA_core_curr, NHA_core_curr$STATUS=="C") #just current sites

#check geometries for NHAs
(is.na(st_is_valid(NHA_core_curr))) #some geometries are invalid
any(is.na(st_dimension(NHA_core_curr))) #no geometries lack dimension
invalid_geo <- subset(NHA_core_curr, st_is_valid(NHA_core_curr)=="FALSE")
#invalid_geodf <- as.data.frame(cbind(invalid_geo$SITE_NAME, invalid_geo$created_user, invalid_geo$SOURCE_REPORT, invalid_geo$NHA_JOIN_ID))
#write.csv(invalid_geodf, file="NHAs_invalid_geo.csv")

#for now, remove invalid geometries from this dataset so that you can proceed
NHA_core_curr <- subset(NHA_core_curr, st_is_valid(NHA_core_curr)=="TRUE")
#future geometry tidying could be done to reduce SF sensitivities to apparently "unclosed" polygons


###################################################################################################################################
# making the figures   ############################################################################################################
###############################################

### 1. make histogram of number of EOs, by taxa, over time

#choose which set of EO records to use

EO_sel <- selected_pointreps_sf_EXTANT

  for(i in 1:length(taxalist)){
    selected_pointreps_sub <- EO_sel[which(EO_sel$TAXA==taxalist[i]),]
    h <- ggplot(data=selected_pointreps_sub , aes(LASTOBS_YR, fill=include)) +
      geom_histogram(binwidth=1) +
      scale_fill_manual(values=c("dodgerblue3","red4"), drop=FALSE) +
      scale_x_continuous(breaks=seq(1980, 2020, by=5), labels=waiver(), limits=c(1980, 2020)) +
      xlab("Observation Date") +
      ylab("Number of Records") +
      theme_minimal() +
      theme(legend.position="top") +
      theme(legend.title=element_blank()) +
      theme(legend.text=element_text(size=15)) +
      theme(axis.text=element_text(size=14), axis.title=element_text(size=15)) +
      theme(axis.text.x=element_text(angle=60, hjust=1)) + 
      theme(aspect.ratio=1)
    png(filename = paste(datadest,"figuresReporting","/","lastobs_",taxalist[i],".png",sep=""), width=600, height=600, units = "px")
    print(h)
    dev.off()
  }

### 2. Make map of same points, color coded by age (more than/less than 25 years old)

    for(i in 1:length(taxalist)){
      selected_pointreps_sub <- EO_sel[which(EO_sel$TAXA==taxalist[i]),]
selected_pointreps_sub <- st_buffer(selected_pointreps_sub, 1000)
    #counties <- us_counties(map_date = NULL, resolution = c("high"), states="PA")
    #counties <- st_transform(counties, st_crs(SGCN_sf_sub))
    p <- ggplot() +
      geom_sf(data=selected_pointreps_sub, mapping=aes(fill=include), alpha=0.9, color=NA) +
      scale_fill_manual(values=c("dodgerblue3","red4"), drop=FALSE) +
      geom_sf(data=county_sf, aes(), colour="black", fill=NA)  +
      scale_x_continuous(limits=c(-215999, 279249)) +
      scale_y_continuous(limits=c(80036, 364574)) +
      theme_void() +
      theme(legend.position="top") +
      theme(legend.title=element_blank()) +
      theme(legend.text=element_text(size=15)) +
      theme(axis.text=element_blank(), axis.title=element_text(size=15)) 
    png(filename = paste(datadest,"figuresReporting","/","lastobsmap_justExtant",taxalist[i],".png",sep=""), width=800, height=600, units = "px", )
    print(p)
    dev.off()
    
    #ggsave(file=paste(here::here("_data/output",updateName,"figuresReporting"),"/","sp_",taxalist[i],".png",sep=""), g) #saves 
    }

### 3. Create maps of numbers of EOs per county, across taxa
  
#spatial join points to county layer

EO_pts_joined <- st_join(selected_pointreps_sf, county_sf["COUNTY_NAM"]) #all points
EO_pts_joined_HFX <- st_join(selected_pointreps_sf_LOST, county_sf["COUNTY_NAM"]) #points graded H, F, X
EO_pts_joined_EXTANT <- st_join(selected_pointreps_sf_EXTANT, county_sf["COUNTY_NAM"]) #extant points, since 1980

EO_pts_joined_df <- as.data.frame(EO_pts_joined)
EO_pts_joined_df_HFX <- as.data.frame(EO_pts_joined_HFX)
EO_pts_joined_df_EXTANT <- as.data.frame(EO_pts_joined_EXTANT)

#get a count of points per county
#when you do this by the finer taxa divisions, you get a lot of NA counties, and the maps fail, so using the broader divisions here

#all points
All_EOs_byCounty <- EO_pts_joined_df %>% count(COUNTY_NAM, BROAD_TAXA, include, .drop=FALSE)

#HFX points
All_EOs_byCounty_HFX <- EO_pts_joined_df_HFX %>% count(COUNTY_NAM, BROAD_TAXA, include, .drop=FALSE)

#Extant points
All_EOs_byCounty_EXTANT <- EO_pts_joined_df_EXTANT %>% count(COUNTY_NAM, BROAD_TAXA, include, .drop=FALSE)


# fill counties by pt number, and then overlay point reps on top
for(i in 1:length(taxalist2)){
  All_EOs_byCounty_EXTANT_sub <- All_EOs_byCounty_EXTANT[which(All_EOs_byCounty_EXTANT$BROAD_TAXA==taxalist2[i] & All_EOs_byCounty_EXTANT$include=="less than 25 years"),]
  selected_pointreps_sub <- selected_pointreps_sf_EXTANT[which(selected_pointreps_sf_EXTANT$BROAD_TAXA==taxalist2[i]),]
  selected_pointreps_sub <- st_buffer(selected_pointreps_sub, 1000)
  
  #join EO summary data to counties layer
  county_sf_sub <- left_join(county_sf, All_EOs_byCounty_EXTANT_sub)
  
  # get quantile breaks. Add .00001 offset to catch the lowest value
  breaks_qt <- classIntervals(c(min(county_sf_sub$n) - .00001, county_sf_sub$n), n=5, style = "quantile")
  county_sf_sub <- mutate(county_sf_sub, EO_n_cat = cut(n, breaks_qt$brks))
  
  p <- ggplot() +
    geom_sf(data=county_sf_sub, aes(fill=EO_n_cat), colour="black")  +
    geom_sf(data=selected_pointreps_sub, alpha=0.9, colour="black", fill="black", shape=20) +
    scale_fill_brewer(palette = "OrRd") +
    scale_x_continuous(limits=c(-215999, 279249)) +
    scale_y_continuous(limits=c(80036, 364574)) +
    theme_void() +
    theme(legend.position="right") +
    theme(legend.title=element_blank()) +
    theme(legend.text=element_text(size=15)) +
    theme(axis.text=element_blank(), axis.title=element_text(size=15)) +
    ggtitle("Number of Element Ocurrences per County")
  png(filename = paste(datadest,"figuresReporting","/","lastobsmap_fill_justExtant",taxalist2[i],".png",sep=""), width=800, height=600, units = "px", )
  print(p)
  dev.off()
  
  #ggsave(file=paste(here::here("_data/output",updateName,"figuresReporting"),"/","sp_",taxalist[i],".png",sep=""), g) #saves 
}

# 4. make this same plot across all taxa

selected_pointreps_sub <- st_buffer(selected_pointreps_sf_EXTANT, 1000)

#join EO summary data to counties layer
county_sf_sub <- left_join(county_sf, All_EOs_byCounty_EXTANT)


# get quantile breaks. Add .00001 offset to catch the lowest value
breaks_qt <- classIntervals(c(min(county_sf_sub$n) - .00001, county_sf_sub$n), n = 8, style = "quantile")
county_sf_sub <- mutate(county_sf_sub, EO_n_cat = cut(n, breaks_qt$brks))
levels(county_sf_sub$EO_n_cat)[8] <- "(602,1095]"

#make plot
ggplot() +
  geom_sf(data=county_sf_sub, aes(fill=EO_n_cat), colour="black")  +
  geom_sf(data=selected_pointreps_sub, alpha=0.9, colour="black", fill="black", shape=20) +
  scale_fill_viridis(discrete = TRUE, direction=-1) +
  scale_x_continuous(limits=c(-215999, 279249)) +
  scale_y_continuous(limits=c(80036, 364574)) +
  theme_void() +
  theme(legend.position="right") +
  theme(legend.title=element_blank()) +
  theme(legend.text=element_text(size=15)) +
  theme(axis.text=element_blank(), axis.title=element_text(size=15)) +
  ggtitle("Number of Element Ocurrences per County, since 1980")

#5. Maps showing differential btwn EO update age and when the county was last updated

County_update_Yr <- here::here("_data","sourcefiles","NHI_updateyr.csv") #this is a .csv file of county update years
County_update_Yr <- read.csv(County_update_Yr)

EO_pts_joined <- left_join(EO_pts_joined,County_update_Yr, by=c("COUNTY_NAM" ="County"))
EO_pts_joined$Yrs_since_NHA_Update <- EO_pts_joined$LASTOBS_YR - EO_pts_joined$UpdateYear

EO_pts_joined$Post_NHI_Update <- ifelse(EO_pts_joined$Yrs_since_NHA_Update > 0, "Post NHI Update", "Prior to NHI Update")
EO_pts_joined <-EO_pts_joined[!is.na(EO_pts_joined$Post_NHI_Update),] #remove EOs which don't have a coding for when they were collected relative to a county update

EO_pts_joined_EXTANT <- left_join(EO_pts_joined_EXTANT,County_update_Yr, by=c("COUNTY_NAM" ="County"))
EO_pts_joined_EXTANT$Yrs_since_NHA_Update <- EO_pts_joined_EXTANT$LASTOBS_YR - EO_pts_joined_EXTANT$UpdateYear

EO_pts_joined_EXTANT$Post_NHI_Update <- ifelse(EO_pts_joined_EXTANT$Yrs_since_NHA_Update > 0, "Post NHI Update", "Prior to NHI Update")
EO_pts_joined_EXTANT <-EO_pts_joined[!is.na(EO_pts_joined_EXTANT$Post_NHI_Update),] #remove EOs which don't have a coding for when they were collected relative to a county update

#6. make maps showing EOs updated since the last NHI

# make the map
for(i in 1:length(taxalist2)){
  selected_pointreps_sub <- EO_pts_joined_EXTANT[which(EO_pts_joined_EXTANT$BROAD_TAXA==taxalist2[i]),]
  selected_pointreps_sub <- st_buffer(selected_pointreps_sub, 1000)
  #counties <- us_counties(map_date = NULL, resolution = c("high"), states="PA")
  #counties <- st_transform(counties, st_crs(SGCN_sf_sub))
  p <- ggplot() +
    geom_sf(data=selected_pointreps_sub, mapping=aes(fill=Post_NHI_Update), alpha=0.9, color=NA) +
    scale_fill_manual(values=c("dodgerblue3","red4"), drop=FALSE) +
    geom_sf(data=county_sf, aes(), colour="black", fill=NA)  +
    scale_x_continuous(limits=c(-215999, 279249)) +
    scale_y_continuous(limits=c(80036, 364574)) +
    theme_void() +
    theme(legend.position="top") +
    theme(legend.title=element_blank()) +
    theme(legend.text=element_text(size=15)) +
    theme(axis.text=element_blank(), axis.title=element_text(size=15)) 
  png(filename = paste(datadest,"figuresReporting","/","EOs_updated_after_NHI_EXTANT",taxalist2[i],".png",sep=""), width=800, height=600, units = "px", )
  print(p)
  dev.off()
  
  #ggsave(file=paste(here::here("_data/output",updateName,"figuresReporting"),"/","sp_",taxalist[i],".png",sep=""), g) #saves 
}

#7. make map of density of all EOs, collected post NHI update

EO_pts_joined_postNHIs <- EO_pts_joined_EXTANT[(EO_pts_joined_EXTANT$Post_NHI_Update == "Post NHI Update"),]
coords <- st_coordinates(EO_pts_joined_postNHIs)
EO_pts_joined_postNHIs <- cbind(EO_pts_joined_postNHIs, coords)
EO_pts_joined_postNHIs$TimeSinceUpdate <- 2021 - EO_pts_joined_postNHIs$LASTOBS_YR

#heat map showing density of EOs that were updated post County NHIs
ggplot() +
geom_density_2d_filled(data=EO_pts_joined_postNHIs, aes(x=X, y=Y, alpha=0.5)) +
geom_sf(data=county_sf,  colour="black", fill=NA) +
  theme_void()

#8 Make heatmap by municipalities of time since extant EO update

#extract to municipalities to show the distribution and density of extant EOs weighted by time since update
EO_pts_joined_EXTANT$TimeSinceUpdate <- 2021 - EO_pts_joined_EXTANT$LASTOBS_YR
EO_pts_joined_EXTANT <- EO_pts_joined_EXTANT[(EO_pts_joined_EXTANT$LASTOBS_YR >1979),] #only look at extant EOs collected since 1980

muni_sf2 <- muni_sf %>% st_join(EO_pts_joined_EXTANT["TimeSinceUpdate"]) %>% group_by(MUNICIPAL_) %>% summarize(AVG_Years_since_Update = mean(TimeSinceUpdate, na.rm = TRUE))

muni_sf2_narm <-muni_sf2[!is.na(muni_sf2$AVG_Years_since_Update),]

# get quantile breaks. Add .00001 offset to catch the lowest value
breaks_qt <- classIntervals(c(min(muni_sf2_narm$AVG_Years_since_Update) - .00001, muni_sf2_narm$AVG_Years_since_Update), n = 7, style = "quantile")
muni_sf2_narm <- mutate(muni_sf2_narm, EO_n_cat = cut(AVG_Years_since_Update, breaks_qt$brks))

p <- ggplot(muni_sf2_narm, aes(fill=EO_n_cat)) +
  geom_sf() +
  scale_fill_brewer(palette = "OrRd")

#9 use a grid to make a heatmap of time since extant EO update

#make a grid of small cells to better represent distribution of EO age

PA_grid$unique_id <- row.names(PA_grid)
PA_grid_ex <- PA_grid %>% st_join(EO_pts_joined_EXTANT["TimeSinceUpdate"]) 

PA_grid_ex_narm <- PA_grid_ex[!is.na(PA_grid_ex$TimeSinceUpdate),]

PA_grid_ex_narm<- PA_grid_ex_narm %>% group_by(unique_id) %>% summarize(AVG_Years_since_Update = mean(TimeSinceUpdate))

# get quantile breaks. Add .00001 offset to catch the lowest value
breaks_qt <- classIntervals(c(min(PA_grid_ex_narm$AVG_Years_since_Update) - .00001, PA_grid_ex_narm$AVG_Years_since_Update), n = 7, style = "quantile")
PA_grid_ex_narm <- mutate(PA_grid_ex_narm, EO_n_cat = cut(AVG_Years_since_Update, breaks_qt$brks))

p <- ggplot(PA_grid_ex_narm, aes(fill=EO_n_cat)) +
  geom_sf(colour=NA) +
  geom_sf(data=county_sf,  colour="black", fill=NA) +
  scale_fill_brewer(palette = "OrRd") +
  theme_void() +
  ggtitle("Average Year since Update for EOs, collected post 1979")
  
### Look at overlap btwn NHAs and EOs ###
#this part is not yet done.
EO_pts_joined_NHAs <- st_join(selected_pointreps_sf, NHA_core_curr["NHA_JOIN_ID"])


 

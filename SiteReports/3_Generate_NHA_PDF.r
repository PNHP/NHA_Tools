#-------------------------------------------------------------------------------
# Name: Create_NHA_Site_Account_PDF.r
# Purpose: Works with the LaTeX .rnw file to produce the formatted NHA Site
# Account PDF. There are a couple steps that need to be run in Python
# prior to running this R script
# Author: Originally created by Anna Johnson in 2019, major updates completed
# by Molly Moore in 2025
# Created: 2019-03-28
# Updated: 2025-03-13 - MAJOR updates to accommodate new NHA database system.
#
#-------------------------------------------------------------------------------

# PASTE LIST OF NHA SITE NAMES FOR WHICH TO CREATE SITE REPORTS HERE - USE THE
# SITE NAME LISTER TOOL IN ARCGIS TO GET LIST OF SITE NAMES FROM SELECTED NHAS.
nha_list <- c('Chestnut Ridge at Limestone Run','Jumonville','Middle Morgan Run')


if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
require(arcgisbinding)
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
require(dplyr)
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
require(stringr)
if (!requireNamespace("beepr", quietly = TRUE)) install.packages("beepr")
require(beepr)
if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr")
require(knitr)
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
require(sf)
if (!requireNamespace("units", quietly = TRUE)) install.packages("units")
require(units)

nha_url = "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/0"
site_account_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/5"
boundaries_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/2"
protected_lands_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/3"
species_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/6"
tr_bullets_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/7"
reference_url <- "https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/4"

rounded_srank_url <- "https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/4"
rounded_grank_url <- "https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/3"

# load the arcgis license
arc.check_product() 

# start loop to create site report for each NHA in site name list
for (nha_name in nha_list){

  # Pull in the selected NHA data ################################################
  nha_name <- nha_name
  #nha_name <- "Jumonville" # use this for testing a single site
  print(paste0("Creating site report for: ",nha_name))
  nha_nameSQL <- paste("'", nha_name, "'", sep='')
  nha_nameLatex <- gsub("#","\\\\#", nha_name) # escapes our octothorpes
  
  # open nha cores and make selection based on nha_name
  nha <- arc.open(nha_url)
  selected_nha <- arc.select(nha, where_clause=paste("SITE_NAME=", nha_nameSQL, sep="")) # need to add statement or loop for multiple NHAs
  nha_sf <- arc.data2sf(selected_nha)
  
  # get acreage of selected NHA
  area <- st_area(nha_sf)
  area_acres <- set_units(area, "acre")
  
  # get nha_join_id of selected nha to use for future selections
  nha_join_id <- selected_nha$nha_join_id
  nha_join_id_SQL <- paste("'", nha_join_id, "'", sep='')
  
  # open the nha site accounts and select those that match the nha_join_id. keep only record of most recent written date.
  site_account <- arc.open(site_account_url)
  site_account <- arc.select(site_account, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep="")) # need to add statement or loop for multiple NHAs
  site_account <- site_account %>%
    group_by(nha_join_id) %>% 
    filter(written_date == max(written_date))
  
  # open protected lands records for selected nha
  protected_lands <- arc.open(protected_lands_url)
  protected_lands <- arc.select(protected_lands, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep=""))
  
  if(nrow(protected_lands)==0){
    site_account$protected_lands <- paste("This site is not documented as overlapping with any Federal, state, or locally protected land or conservation easements.")
  } else {
    site_account$protected_lands <- paste(protected_lands$protected_land, collapse=', ')
  }
  
  # open political boundary records for selected nha
  political_boundaries <- arc.open(boundaries_url)
  political_boundaries <- arc.select(political_boundaries, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep="")) 
  
  PBs <- split(political_boundaries, political_boundaries$county)
  munil <- list()
  for(i in 1:length(PBs)){
    munil[[i]] <- unique(PBs[[i]]$municipality)  
  }
  
  printCounty <- list()
  for (i in 1:length(PBs)){
    printCounty[[i]]  <- paste0(PBs[[i]]$county[1], " County",": ", paste(munil[[i]], collapse=', '))  
  }
  
  site_account$CountyMuni <- paste(printCounty, collapse='; ')
  
  # species table
  # open the related species table and get the rows that match the NHA join ids from the selected NHAs
  species_table <- arc.open(species_url)
  species_table <- arc.select(species_table, where_clause=paste("nha_join_id=", nha_join_id_SQL, "AND exclude = 'N'", sep="")) 
  
  # replace missing values with NA
  species_table$EORANK[is.na(species_table$EORANK)] <- "E"
  
  # merge the species table with the taxonomic icons
  # taxaicon lookup
  taxaicon <- data.frame(c("Amphibians.png","Amphibians.png","Arachnids.png","Birds.png","Butterflies.png","Caddisflies.png","Communities.png","Craneflies.png","Crustacean.png","Earwigscorpionfly.png","Fish.png","Liverworts.png","Mammals.png","Mosses.png","Moths.png","Mussels.png","Odonates.png","OtherInverts.png","Plants.png","Sensitive.png","Snails.png","Sponges.png","TigerBeetles.png","Reptile.png","OtherInverts.png"),
                         c("Salamander","Frog","Invertebrate - Spiders","Bird","Invertebrate - Butterflies and Skippers","Invertebrate - Caddisflies","Community","","Invertebrate - Crayfishes","","Fish","","Mammal","","Invertebrate - Moths","Invertebrate - Mussels","Invertebrate - Dragonflies and Damselflies","Invertebrate - Other Beetles","Vascular Plant","","Invertebrate - Gastropods","Invertebrate - Sponges","Invertebrate - Tiger Beetles","Reptile","Invertebrate - Stoneflies"), stringsAsFactors = FALSE)
  names(taxaicon) <- c("icon","ELEMENT_TYPE")
  species_table <- merge(species_table, taxaicon, by.x="taxa", by.y="ELEMENT_TYPE")
  # do a check here if it results in a zero length table and will break the script
  ifelse(nrow(species_table)==0,print("ERROR: Bad join with Taxa Icons"), print("All is well with this join"))
  
  ######## DEAL WITH SPECIES WITH MULTIPLE EOs WITHIN NHA SITE
  # take one value from multiple species
  dupspecies <- sort(species_table[which(duplicated(species_table$SNAME)),]$SNAME)
  ifelse(length(dupspecies)>0, print(paste("The following species have multiple EOs: ", paste(dupspecies, collapse=", "), sep="")), print("No duplicate species in the table."))
  
  # get df with species with duplicate records
  speciestable_dup <- species_table[which(species_table$SNAME %in% dupspecies),]
  # get df with species without duplicate records
  speciestable_nodup <- species_table[which(!species_table$SNAME %in% dupspecies),]
  # exclude F and X eoranks from duplicate record table
  speciestable_dup <- speciestable_dup[which(speciestable_dup$EORANK!="F"&speciestable_dup$EORANK!="X"),]
  # for duplicate species within a site, keep species with most recent lastobs date and highest eorank
  if(nrow(speciestable_dup)>0){
  speciestable_dup <- speciestable_dup %>%
    group_by(ELSUBID) %>% 
    filter(LASTOBS_YR == max(LASTOBS_YR)) %>%
    filter(EORANK == min(EORANK)) %>%
    distinct(ELSUBID, .keep_all = TRUE)
  }
  # merge duplicates back in
  species_table <- rbind(speciestable_dup,speciestable_nodup)
  
  # manually change the sensitivity if the the EO is sensitive
  species_table[which(species_table$SENSITV_SP=="N" & species_table$SENSITV_EO=="Y"),"SENSITV_SP"] <- "Y"
  
  # open grank/srank reference data
  rounded_srank <- arc.open(rounded_srank_url)
  rounded_srank <- arc.select(rounded_srank)
  
  # open grank/srank reference data
  rounded_grank <- arc.open(rounded_grank_url)
  rounded_grank <- arc.select(rounded_grank)
  
  granklist <- merge(rounded_grank, species_table[c("SNAME","SCOMNAME","GRANK","SENSITV_SP")], by.x="grank", by.y="GRANK")
  
  # secure species
  a <- nrow(granklist[which((granklist$grank_rounded=="G4"|granklist$grank_rounded=="G5"|granklist$grank_rounded=="GNR"|granklist$grank_rounded=="GNA")&granklist$SENSITV_SP!="Y"),])
  if(a>0){
    spExample_GSecure <- sample_n(granklist[which(granklist$SENSITV_SP!="Y"),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
  }
  spCount_GSecure <- ifelse(length(a)==0, 0, a)
  spCount_GSecureSens <- ifelse(any(((granklist$grank_rounded=="G4"|granklist$grank_rounded=="G5"|granklist$grank_rounded=="GNR"|granklist$grank_rounded=="GNA")&granklist$SENSITV_SP=="Y")), "yes", "no")
  rm(a)
  
  # G3G4 but has state significance
  
  # vulnerable species
  a <- nrow(granklist[which((granklist$grank_rounded=="G3")&granklist$SENSITIVE!="Y"),])
  if(a>0){
    spExample_GVulnerable <- sample_n(granklist[which(granklist$SENSITV_SP!="Y" & granklist$grank_rounded=="G3"),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
  }
  spCount_GVulnerable <- ifelse(length(a)==0, 0, a)
  spCount_GVulnerableSens <- ifelse(any(((granklist$grank_rounded=="G3")&granklist$SENSITV_SP=="Y")), "yes", "no")
  rm(a)
  
  # imperiled species
  a <- nrow(granklist[which((granklist$grank_rounded=="G2"|granklist$grank_rounded=="G1")&granklist$SENSITV_SP!="Y"),])
  if(a>0){
    spExample_GImperiled <- sample_n(granklist[which(granklist$SENSITV_SP!="Y" & (granklist$grank_rounded=="G2"|granklist$grank_rounded=="G1")),c("SNAME","SCOMNAME")], 1, replace=FALSE, prob=NULL) 
  }
  spCount_GImperiled <- ifelse(length(a)==0, 0, a)
  spCount_GImperiledSens <- ifelse(any(((granklist$grank_rounded=="G2"|granklist$grank_rounded=="G1")&granklist$SENSITV_SP=="Y")), "yes", "no")
  rm(a)
  
  # open threats and recommendations bullets for selected nha
  tr_bullets <- arc.open(tr_bullets_url)
  tr_bullets <- arc.select(tr_bullets, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep=""))
  
  # get photo path - MUST RUN PYTHON SCRIPT TO DOWNLOAD ALL PHOTOS FIRST
  photo_path <- here::here("_data","photos")
  photo_file <- list.files(photo_path, pattern=nha_join_id, full.names=FALSE)
  
  # get photo caption/credit string
  selected_nha$photo_name <- paste(selected_nha$photo_credit, selected_nha$photo_affil, sep=" ")
  selected_nha$photo_name <- gsub("NA","",selected_nha$photo_name)
  
  # Get site rank
  nha_siterank <- NA
  if(selected_nha$sig_rank=="G"){
    nha_siterank <- "Global"
  } else if(selected_nha$sig_rank=="R"){
    nha_siterank <- "Regional"
  } else if(selected_nha$sig_rank=="S"){
    nha_siterank <- "State"
  } else if(selected_nha$sig_rank=="L"){
    nha_siterank <- "Local"
  } else {
    nha_siterank <- NA
  }
  
  # sources and funding - we're not going to do this right now
  # db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  # nha_Sources <- dbGetQuery(db_nha, paste("SELECT * FROM nha_SourcesFunding WHERE SOURCE_REPORT = " , sQuote(selected_nha$SOURCE_REPORT), sep="") )
  # dbDisconnect(db_nha)
  
  ###############################################################
  ## format various blocks of text to be formatted in terms of italics and bold font
  # italicize all SNAMEs in the descriptive text.
  ETitalics <- read.csv(here::here("SNAMEitalics.csv"))
  ETitalics <- ETitalics$ETitalics # turn into a vector
  ETitalics <- ETitalics[ETitalics!="Alle"] # remove some problematic names
  vecnames <- ETitalics 
  ETitalics <- paste0("\\\\textit{",ETitalics,"}") 
  names(ETitalics) <- vecnames
  rm(vecnames)
  
  # italicize all SNAMEs in the site description
  site_account$site_desc <- str_replace_all(site_account$site_desc, ETitalics)
  # italicize all SNAMEs in the threats and recommendations text. 
  site_account$tr_summary <- str_replace_all(site_account$tr_summary, ETitalics) # for the paragraph
  # italicize all SNAMEs in the threats and recommendations bullets
  for(j in 1:nrow(tr_bullets)){
    tr_bullets$threat_text[j] <- str_replace_all(tr_bullets$threat_text[j], ETitalics)
  }
  
  
  # italicize SNAMEs in photo caption
  if(!is.na(selected_nha$photo_caption)) {
    selected_nha$photo_caption <- str_replace_all(selected_nha$photo_caption, ETitalics)
  } else {
    print("No Photo 1 caption, moving on...")
  }
  
  
  # replace apostrophes in the description paragraph
  site_account$tr_summary <- str_replace_all(site_account$tr_summary, c("â€™"="'"))
  site_account$tr_summary <- str_replace_all(site_account$tr_summary, c("â€™"="'"))
  for(j in 1:nrow(tr_bullets)){
    tr_bullets$threat_text[j] <- str_replace_all(tr_bullets$threat_text[j], c("â€™"="'"))
  }
  
  
  # bold tracked species names
  namesbold <- species_table$SCOMNAME
  namesbold <- namesbold[!is.na(namesbold)]
  namesbold_lower <- tolower(namesbold)
  namesbold_first <- namesbold_lower
  substr(namesbold_first, 1, 1) <- toupper(substr(namesbold_first, 1, 1))
  namesbold <- c(namesbold, namesbold_first, namesbold_lower)
  
  vecnames <- namesbold 
  namesbold <- paste0("\\\\textbf{",namesbold,"}") 
  names(namesbold) <- vecnames
  rm(vecnames)
  
  site_account$site_desc <- str_replace_all(site_account$site_desc, namesbold)
  site_account$tr_summary <- str_replace_all(site_account$tr_summary, namesbold)
  for(j in 1:nrow(tr_bullets)){
    tr_bullets$threat_text[j] <- str_replace_all(tr_bullets$threat_text[j], namesbold)
  }
  
  
  # replace <br><br> html page breaks with latex page breaks
  site_account$site_desc <- gsub("<br><br>","\\\\newline\\\\newline",site_account$site_desc)
  site_account$tr_summary <- gsub("<br><br>","\\\\newline\\\\newline",site_account$tr_summary)
  
  
  # build references to print in report
  # get list of tr bullet ids
  reference_ids <- as.vector(tr_bullets$threat_desc)
  reference_ids <- append(reference_ids, nha_join_id)
  
  # bring in references
  references <- arc.open(reference_url)
  where_clause <- paste("source_id in (", paste(shQuote(reference_ids, type = "sh"), collapse = ', '), ")")
  references <- arc.select(references, where_clause=where_clause) # need to add statement or loop for multiple NHAs
  
  # format citations
  if(nrow(references)>0){
  references$latex_citation <-  gsub('<div class="csl-entry">', "", references$full_cite)
  references$latex_citation <-  gsub('</div>', "", references$latex_citation)
  references$latex_citation <-  gsub('&amp;', "\\\\&", references$latex_citation)
  references$latex_citation <-  gsub('<i>', "\\\\textit{", references$latex_citation)
  references$latex_citation <-  gsub('</i>', "}", references$latex_citation)
  
  # the below formatting is to get the url wrapped in the latex \url{} to make sure it wraps appropriately
  url_pattern <- "http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"
  references$url <- str_extract(references$latex_citation, url_pattern)
  references$updated_url <- paste0("\\\\url{",str_extract(references$latex_citation, url_pattern),"}")
  
  references$latex_citation <- str_replace(references$latex_citation, references$url, references$updated_url)
  }  

  # get the output folder and the file name
  output_folder <- here::here("_data","output")
  # function to create the folder name
  nha_filename <- function(x){
    nha_foldername <- gsub(" ", "", nha_name, fixed=TRUE)
    nha_foldername <- gsub("#", "", nha_foldername, fixed=TRUE)
    nha_foldername <- gsub("''", "", nha_foldername, fixed=TRUE)
    nha_foldername <- gsub("'", "", nha_foldername, fixed=TRUE)
  }
  
  nha_filename <- nha_filename(selected_nha$site_name)
  
  # urls for the template
  url_PNHPrank <- "http://www.naturalheritage.state.pa.us/rank.aspx"
  url_NSrank <- "http://www.natureserve.org/explorer/eorankguide.htm"
  url_NHApage <- "http://www.naturalheritage.state.pa.us/inventories.aspx"
  
  ##############################################################################################################
  ## Write the output document for the site ###############
  setwd(output_folder)
  pdf_filename <- paste(nha_filename,"_",gsub("[^0-9]", "", Sys.Date()), "_", nha_join_id ,sep="")
  
  # function to generate the pdf
  #knit2pdf(here::here("scripts","template_Formatted_NHA_PDF.rnw"), output=paste(pdf_filename, ".tex", sep=""))
  makePDF <- function(rnw_template, pdf_filename) {
    knit(here::here(rnw_template), output=paste(pdf_filename, ".tex",sep=""))
    call <- paste0("xelatex -interaction=nonstopmode ", pdf_filename , ".tex")
    system(call)
    system(paste0("biber ",pdf_filename))
    system(call) # 2nd run to apply citation numbers
  }
  
  # function to delete .txt, .log etc if pdf is created successfully.
  deletepdfjunk <- function(pdf_filename){
    fn_ext <- c(".aux",".out",".run.xml",".bcf",".blg",".tex",".log",".bbl",".toc") #
    if (file.exists(paste(pdf_filename, ".pdf",sep=""))){
      for(i in 1:NROW(fn_ext)){
        fn <- paste(pdf_filename, fn_ext[i],sep="")
        if (file.exists(fn)){
          file.remove(fn)
        }
      }
    }
  }
  
  # RNW file to use
  rnw_template <- "template_Formatted_NHA_PDF.rnw"
  makePDF(rnw_template, pdf_filename) # user created function
  deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
  beepr::beep(sound=10, expr=NULL)
} # this is to end the for loop
  

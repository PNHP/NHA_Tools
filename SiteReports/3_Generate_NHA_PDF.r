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
nha_list <- c('Accomac, Marietta, Wrightsville Rivershore', 'Adams County Winery Site',
              'Alpine Road Site', 'Andersontown Woods', 'Antietam West Branch',
              'Apollo Park, Susquehanna River', 'Arendtsville Narrows Ravine',
              'Arendtsville Narrows Woods and Seeps', 'Atom Road Woods', 'Back Creek',
              'Bakers Knob Slopes', 'Bandana Woods', 'Barlow Woods', 'Barnitz Woods',
              'Bear Valley', 'Beartown Woods', 'Beaver Creek ROW', 'Beaver Creek-York Co',
              'Bendersville Road', 'Bermudian Creek', 'Bermudian Creek at T809',
              'Big Pine Flat Barrens', 'Big Spring-Cumberland Co', 'Black Swamp',
              'Bloserville', 'Bloserville Hill', 'Blymire and Rehmeyer Hollow Woods',
              'Boiling Springs', 'Bonny Brook', 'Boyds Run Ravine', 'Brunner (Lows) Island', 
              'Brushtown Woods', 'Bryansville Station Seep', 'Buck Run at Mercersburg', 
              'Bullfrog Road Quarry', 'Burd Run Caves', 'Bushy Hill', 'Butterfield Farm', 
              'CCC Dam Site', 'Cabin Creek', 'Cactus Hill Site', 'Camp Tuckahoe', 
              'Canodochly Valley', 'Carbaugh Run State Forest Natural Area', 'Cavalry Woods', 
              'Cave Hill Nature Center', 'Center Road', 'Central Great Valley', 
              'Central Great Valley - Eshelman Drive', 'Charlestown Ponds', 
              'Chestnut Hill Woods', 'Chimney Rock', 'Chimney Rocks', 'Church Hill', 
              'Clarks Knob', 'Claylick Mountain', 'Codorus Creek at Arsenal Road', 
              'Codorus State Park Site', 'Cold Spring Seeps', 'Colonel Denning State Park', 
              'Concord Narrows', 'Concrete Bottom at Licking Creek', 'Conejohela Flats', 
              'Conewago Creek at Kunkle Mill Road', 'Conewago Creek at Peepytown Road', 
              'Conewago Creek-Newchester', 'Conewago Creek-Plainview', 
              'Conococheague Creek Floodplain at Caledonia Park', 
              'Conococheague Creek at Highland School', 'Conococheague Creek at Rt 16', 
              'Conococheague Creek near Marion', 'Conodoguinet Creek East of Newville', 
              'Conodoguinet Creek at Bernheisel Bridge', 'Conodoguinet Creek at Carlisle', 
              'Conodoguinet Creek at Creekview Road', 'Conodoguinet Creek at Ebenezer Road', 
              'Conodoguinet Creek at Mt Rock Spring Creek', 
              'Conodoguinet Creek at Mt Zion School Road', 'Conodoguinet Creek at Orrstown', 
              'Conodoguinet Creek at Rich Valley Road', 'Conodoguinet Creek at Wolf Bridge', 
              'Conodoguinet Macrosite', 'Conowingo Islands', 'Counselman Run', 'Cranberry Valley', 
              'Crystal Pit Cave', 'Dead Woman Hollow', 'Deer Creek Woods', 'East Berlin Meadow', 
              'Ebaughs Creek', 'Edenville Meadows', 'Eisenhower National Historic Site', 
              'Erney Cliff', 'Falling Spring', 'Felton and Fenmore Outcrops', 
              'Fishing Creek - Susquehanna River Site', 'Fort Loudon Floodplain', 
              'Gettysburg Battlefield Site - Confederate Avenue', 'Gettysburg Grasslands', 
              'Gifford Pinchot State Park Site', 'Glen Forney Vernals', 'Grave Ridge', 
              'Green Ridge Bend', 'Hammonds Rocks', "Happel's Meadow", 'Harpers Hill', 
              'High Rock', 'Highland School Fields', 'Highrock Outcrops', 'Hoover Spring', 
              'Hopewell Recreation Area', 'Horse Valley', 'Hunters Run - Cumberland County', 
              'Huntsdale Floodplain, Kings Gap Ponds', 'Huntsdale Grasslands', 
              'Huntsdale Hatchery Springs', 'Hykes Swamp', 'Indian Rock Floodplain','Indian Steps Woods', 'Irishtown Gap Hollow', 'Iron Run', 'Keasey Run Wetlands', 
              "King's Pasture", 'Kings Gap Hollow', 'Kiwanis Lake', 'Knoxlyn Road and Marsh Creek', 
              'Kreutz Creek', 'Lake Meade', 'Lake Redman Site', 'Laurel Road Swamp', 
              'Laurel Run-York Co', 'Leibs Creek Hollow', 'Letort Spring Run', 'Letterkenny Army Depot', 
              'Letterkenny Reservoir', 'Lewis Rocks', 'Licking Creek Woods', 'Little Cove Creek Cliff', 
              'Locust Creek-Cumberland Co', 'Logan School Fossil Site', 'Long Arm Creek Reservoir', 
              'Lower Conococheague Creek', 'Lower Susquehanna River', 'Mains Run & Gum Run Ponds', 
              'Makey Run Ponds', 'Marsh Run', 'Martins Mill Bridge', 'McCormicks Island Archipelago', 
              'McPherson Ridge', 'Meadow Brook Lane Woods', 'Mercersburg Woods', 'Metal Church Spring', 
              'Michael Run', 'Michaux Road Site', 'Middle Spring Creek Watershed', 
              'Miney Branch', 'Mont Alto Mountain', 'Monument Rock', 'Mount Cydonia', 
              'Mount Holly Marsh', 'Mount Newman Roadcut', 'Mountain Creek Seeps, Sage Run', 
              'Mountain Lake', 'Mountain Run, Stillhouse Hollow Ponds', 'Mt Olivet Marsh', 
              'Muddy Creek At Woodbine', 'Muddy Creek Gorge', 'Muddy Run Spring', 
              'Mudlevel Road Site', 'Muskrat Fen', 'Needy Cave', 'Neeleyton Ridgetop', 
              'Nells Hill Swamp', 'North Branch Muddy Creek - Collins School Road ROW', 
              'North Harpers Hill', 'North York Cave', 'Nunnery Spring', 'Oakland Run', 
              'Oakland Run Woods', 'Old Baltimore Road Site', 'Otter Creek ROW', 'Otter Creek Woods', 
              'PECO Brandon Shores', 'Peach Bottom Woods', 'Peach Orchard Hollow Ponds', 
              'Peebles Run', 'Pine Run Ponds', 'Piney Mountain Seeps', 'Pitzar School Site', 
              'Plainfield Rivershore, Hill Island Rapids', 'Plum Run Upland', 'Prices Church Road', 
              'Quarry Gap Ponds', 'Ram Hill Seep', 'Rambo Run Woods', 'Rattlesnake Ridge', 
              'River Farm Road ROW', 'Rock Creek Hills', 'Rock Ridge Woods', 'Rocky Ridge Park', 
              'Round Top Hills', 'Route 997 North of Roxbury', 'Roxbury Floodplain', 
              'Running Pump Road Woods', 'Samuel S Lewis State Park', 'Sand Spring Seep', 
              'Sawmill Run Woods', 'Second Narrows Slopes', 'Seitzland Marsh', 
              'Seven Stars Floodplain Forest', 'Shady Lane Woods', 'Shaffers Hollow', 
              'Shenks Ferry York Woods', 'Sheppard Myers Reservoir', 'Siberia', 'Southside Woods', 
              'Sportsmans Road Shale Bank', 'Spring Grove', 'Spring Hill School Grasslands', 
              'Spring Valley Park', 'St Thomas Barren', 'State Game Lands 169 - Barrens', 
              'State Game Lands 169 - Conodoguinet Creek', 'State Game Lands 181', 
              'State Game Lands 243', 'Stewartstown Ravine', 'Sthromes Hollow', 'Stony Run Lane', 
              'Storm Store Bridge Woods', 'Straight Hill Woods', 'Strawberry Hill Preserve', 
              'Sunnyburn Run Woods', 'Susquehanna River Shoreline at Codorus Creek', 
              'Susquehanna River Shoreline at Wrightsville', 'Susquehanna River at Fort Hunter, Rockville', 
              'Susquehanna River at Harrisburg', 'Susquehanna River at Middletown', 'Tagg Run', 
              'Taxville Quarry', 'Thomson Hollow Ponds', 'Three Square Hollow East', 'Toms Creek Tributary', 
              'Toms Run at Michaux Road', 'Trout Run Nature Preserve, Upper Allen Marsh', 
              'Tuscarora Ridgetop', 'Tuscarora Trail', 'Tuscarora Trail - SGL 124', 
              'Tuscarora Trail Site', 'Upper Mill Woods', 'Upper West Branch Conococheague Creek', 
              'Waggoners Gap', 'Waynecastle Old Field Habitat', 'Weise, Urey, Bair, Duncan Islands', 
              'Wenksville Road ROW', 'West Branch Conococheague', 'West Bridgeton Woods', 'White Rocks', 
              'White Run Road', 'Wildcat Run Cliffs', 'Wildcat Run Gorge', 'Williamson Red-cedar-Redbud Shrubland', 'Willoughby Run Woodland', 'Winding Hill Park', 
              'Winterstown Station Woods', 'Yellow Breeches Creek - Market Street Bridge', 
              'Yellow Breeches Creek at Craighead', 'Yellow Breeches Creek at Quarry Hill Road', 
              'Yellow Breeches Creek-Leidighs to Williams Grove', 'Yellow Breeches-Rabold Site', 
              'York Furnace Woods', 'Zora Woods', 'Zullinger Spring')

nha_list <- c('Michaux Road Site')

nha_name <- 'Michaux Road Site'



nha_list <- c('Stockton Mountain Barrens', 'Dreck Creek Watershed')


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

clean_text <- function(x) {
  x <- as.character(x)
  # two or more consecutive <br> -> paragraph break
  x <- gsub("(?i)(<br\\s*/?>\\s*){2,}", "\n\n", x, perl = TRUE)
  # a single <br> -> space
  x <- gsub("(?i)<br\\s*/?>", " ", x, perl = TRUE)
  # any other stray tags
  x <- gsub("<[^>]+>", "", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  x <- gsub("&amp;",  "&", x, fixed = TRUE)
  # collapse horizontal whitespace ONLY — do not touch the \n\n breaks
  x <- gsub("[ \t\f\v]+", " ", x, perl = TRUE)
  x <- gsub(" *\n *", "\n", x)      # trim spaces hugging newlines
  x <- gsub("\n{3,}", "\n\n", x)    # cap at one blank line
  trimws(x)
}

sanitize_latex <- function(x) {
  if (length(x) == 0) return(x)
  # protect backslashes first so later brace-escaping doesn't re-hit them
  x <- str_replace_all(x, fixed("\\"), "\uFFFFbs\uFFFF")
  x <- str_replace_all(x, fixed("&"), "\\&")
  x <- str_replace_all(x, fixed("%"), "\\%")
  x <- str_replace_all(x, fixed("$"), "\\$")
  x <- str_replace_all(x, fixed("#"), "\\#")
  x <- str_replace_all(x, fixed("_"), "\\_")
  x <- str_replace_all(x, fixed("{"), "\\{")
  x <- str_replace_all(x, fixed("}"), "\\}")
  x <- str_replace_all(x, fixed("~"), "\\textasciitilde{}")
  x <- str_replace_all(x, fixed("^"), "\\textasciicircum{}")
  x <- str_replace_all(x, fixed("\uFFFFbs\uFFFF"), "\\textbackslash{}")
  x
}

###############################################################
## MARKUP HELPERS + SCIENTIFIC-NAME DICTIONARY (one-time setup)
## Place this BEFORE the per-site loop.
###############################################################

## --- generic helpers ----------------------------------------------------
build_term_pattern <- function(terms){
  terms <- unique(trimws(terms))
  terms <- terms[!is.na(terms) & nzchar(terms)]
  if (length(terms) == 0) return(NULL)
  terms <- terms[order(nchar(terms), decreasing = TRUE)]
  esc <- str_replace_all(terms, "([.^$*+?(){}\\[\\]|\\\\])", "\\\\\\1")
  regex(paste0("(?<![A-Za-z])(", paste(esc, collapse = "|"), ")(?![A-Za-z])"))
}

wrap_markup <- function(x, pattern, cmd){
  if (is.null(pattern) || length(x) == 0) return(x)
  ok <- !is.na(x) & nzchar(x)
  x[ok] <- str_replace_all(x[ok], pattern, paste0("\\\\", cmd, "{\\1}"))
  x
}

# Retry wrapper for transient arcgisbinding / COM failures. Takes a FUNCTION
# (a thunk), not an expression, so it actually re-runs on each attempt.
fetch_with_retry <- function(fn, what, max_tries = 3, pause = 5){
  for (attempt in seq_len(max_tries)){
    result <- tryCatch(fn(), error = function(e) e)
    if (!inherits(result, "error")) return(result)
    warning(sprintf("%s failed (attempt %d/%d): %s",
                    what, attempt, max_tries, conditionMessage(result)))
    if (attempt < max_tries) Sys.sleep(pause)
  }
  NULL
}

# TRUE only for Latin-looking names: a capitalized genus, an optional
# (Subgenus), then lowercase epithets / sp. / ssp. / numbers / hybrid marks.
# Secondary net behind the ELCODE filter (catches NA-ELCODE rows, etc.).
is_sciname <- function(x){
  x <- str_squish(x)
  grepl("^[A-Z][a-z]+( \\([A-Z][a-z]+\\))?(\\s+([a-z][a-z-]*\\.?|[0-9]+|\u00D7))*$", x)
}

## --- CONFIG: ET layer ---------------------------------------------------
et_path      <- "https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/5"  # ArcGIS feature service / layer
sname_field  <- "SNAME"                            # confirmed
elcode_field <- "ELCODE"                           # <-- confirm this field name
elcode_drop  <- "^[CHG]"                            # exclude ELCODEs starting C, H, or G

## --- 1. curated CSV (trusted as-is) -------------------------------------
curated <- read.csv(here::here("_data","SNAMEitalics.csv"),
                    stringsAsFactors = FALSE)$ETitalics
curated <- unique(trimws(curated))
curated <- curated[!is.na(curated) & nzchar(curated)]

## --- 2. live pull from the ET layer (with retry + graceful fallback) ----
et_df <- fetch_with_retry(function(){
  lyr <- arc.open(et_path)
  arc.select(lyr, fields = c(sname_field, elcode_field))
}, what = "ET layer pull")

if (is.null(et_df)) {
  warning("ET layer unavailable after retries; using curated CSV only.")
  et_sname  <- character(0)
  et_elcode <- character(0)
} else {
  et_sname  <- as.character(et_df[[sname_field]])
  et_elcode <- as.character(et_df[[elcode_field]])
}

## --- 2b. drop communities / other by ELCODE prefix (C, H, G) ------------
# grepl() returns FALSE for NA, so NA-ELCODE rows are KEPT and left to
# is_sciname below -- we'd rather over-keep than silently lose a species.
drop_el  <- grepl(elcode_drop, trimws(et_elcode), ignore.case = TRUE)
n_drop   <- sum(drop_el)
et_sname <- et_sname[!drop_el]
message(sprintf("ET layer: %d rows pulled, %d dropped by ELCODE prefix C/H/G.",
                length(drop_el), n_drop))

et_sname <- unique(trimws(et_sname))
et_sname <- et_sname[!is.na(et_sname) & nzchar(et_sname)]

# secondary safety net: keep only Latin-looking SNAMEs, and report any
# post-ELCODE rejects so you can audit for false drops.
et_sci      <- et_sname[is_sciname(et_sname)]
et_nonlatin <- setdiff(et_sname, et_sci)
if (length(et_nonlatin) > 0) {
  message(sprintf("ET layer: %d post-ELCODE names rejected by is_sciname; sample: %s",
                  length(et_nonlatin), paste(head(et_nonlatin, 5), collapse = " | ")))
}

## --- 3. union of full scientific names ----------------------------------
ETitalics <- unique(c(curated, et_sci))

## --- 4. derive genus names from every Latin name (full names + genus) ---
genus <- str_extract(ETitalics[is_sciname(ETitalics)], "^[A-Z][a-z]+")
genus <- unique(genus[!is.na(genus)])
ETitalics <- unique(c(ETitalics, genus))

## --- 5. drop genus homographs that collide with English words -----------
sci_stop <- c("Alle","Chen","Cota","Inga","Iris","Isa","Iva","Lynx",
              "Mus","Nola","Poa","Puma","Rosa","Sida","Viola")
ETitalics <- ETitalics[!ETitalics %in% sci_stop]

## --- 6. generate abbreviated genus forms ("Quercus alba" -> "Q. alba") ---
binom     <- ETitalics[grepl("^[A-Z][a-z]+ ", ETitalics)]
abbr      <- sub("^([A-Z])[a-z]+ ", "\\1. ", binom)
ETitalics <- unique(c(ETitalics, abbr))

## --- 7. build the compiled pattern --------------------------------------
sci_pattern <- build_term_pattern(ETitalics)
message(sprintf("Italic dictionary: %d total terms.", length(ETitalics)))

# start loop to create site report for each NHA in site name list
for (nha_name in nha_list){
  
  # Pull in the selected NHA data ################################################
  nha_name <- nha_name
  #nha_name <- "Haycock Mountain (State Game Lands 157) & Nockamixon State Park" # use this for testing a single site
  print(paste0("Creating site report for: ",nha_name))
  
  nha_nameSQL <- paste("'", gsub("'", "''", nha_name), "'", sep='')
  if(grepl("'", nha_name)){
    warning(paste0("Site name '", nha_name, "' contains an apostrophe. This has been escaped for the SQL query, but consider cleaning up the site name in the database."))
  }
  
  # escape all LaTeX special characters in the site name used for the report
  # title/header (e.g. the "&" in "Mains Run & Gum Run Ponds"). Note: nha_name
  # itself is left untouched and is still used for the SQL query and filename.
  nha_nameLatex <- sanitize_latex(nha_name)
  
  
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
  # keep most recent written date
  site_account <- site_account %>%
    group_by(nha_join_id) %>% 
    filter(written_date == max(written_date))
  
  # if there are multiple on the same written date, keep the one with the most recent created date
  if(nrow(site_account) > 1){
    warning(paste0("Multiple site accounts found with the same written_date for ", nha_name, ". Keeping the most recently created record."))
    site_account <- site_account %>%
      filter(created_date == max(created_date)) %>%
      slice(1)
  }
  
  # open protected lands records for selected nha
  protected_lands <- arc.open(protected_lands_url)
  protected_lands <- arc.select(protected_lands, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep=""))
  
  if(nrow(protected_lands)==0){
    selected_nha$protected_lands <- paste("This site is not documented as overlapping with any Federal, state, or locally protected land or conservation easements.")
  } else {
    selected_nha$protected_lands <- paste(protected_lands$protected_land, collapse=', ')
  }
  
  # open political boundary records for selected nha
  political_boundaries <- arc.open(boundaries_url)
  political_boundaries <- arc.select(political_boundaries, where_clause=paste("nha_join_id=", nha_join_id_SQL, sep="")) 
  
  PBs <- split(political_boundaries, political_boundaries$county)
  if(length(PBs) > 0){
    munil <- list()
    for(i in 1:length(PBs)){
      munil[[i]] <- unique(PBs[[i]]$municipality)  
    }
    
    printCounty <- list()
    for (i in 1:length(PBs)){
      printCounty[[i]]  <- paste0(PBs[[i]]$county[1], " County",": ", paste(munil[[i]], collapse=', '))  
    }
    
    selected_nha$CountyMuni <- paste(printCounty, collapse='; ')
  } else {
    selected_nha$CountyMuni <- "None recorded"
  }
  
  # species table
  # open the related species table and get the rows that match the NHA join ids from the selected NHAs
  species_table <- arc.open(species_url)
  species_table <- arc.select(species_table, where_clause=paste("nha_join_id=", nha_join_id_SQL, "AND exclude = 'N'", sep="")) 
  
  
  # replace missing values with NA
  species_table$EORANK[is.na(species_table$EORANK)] <- "E"
  
  # merge the species table with the taxonomic icons
  # taxaicon lookup
  taxaicon <- data.frame(c("Amphibians.png","Amphibians.png","Arachnids.png","Birds.png","Butterflies.png","Caddisflies.png","Communities.png","Craneflies.png","Crustacean.png","Earwigscorpionfly.png","Fish.png","Liverworts.png","Mammals.png","Mosses.png","Moths.png","Mussels.png","Odonates.png","OtherInverts.png","Plants.png","Sensitive.png","Snails.png","Sponges.png","TigerBeetles.png","Reptile.png","OtherInverts.png", "Communities.png"),
                         c("Salamander","Frog","Invertebrate - Spiders","Bird","Invertebrate - Butterflies and Skippers","Invertebrate - Caddisflies","Community","","Invertebrate - Crayfishes","","Fish","","Mammal","","Invertebrate - Moths","Invertebrate - Mussels","Invertebrate - Dragonflies and Damselflies","Invertebrate - Other Beetles","Vascular Plant","","Invertebrate - Gastropods","Invertebrate - Sponges","Invertebrate - Tiger Beetles","Reptile","Invertebrate - Stoneflies", "Other"), stringsAsFactors = FALSE)
  names(taxaicon) <- c("icon","ELEMENT_TYPE")
  
  # LEFT join so species with no matching icon are kept rather than dropped
  species_table <- merge(species_table, taxaicon, by.x="taxa", by.y="ELEMENT_TYPE", all.x = TRUE)
  
  # warn about any taxa that didn't match an icon (so the lookup can be updated later)
  missing_icon <- unique(species_table$taxa[is.na(species_table$icon) | species_table$icon == ""])
  if(length(missing_icon) > 0){
    warning(paste0("No matching icon for taxa: ", paste(missing_icon, collapse=", "),
                   ". These species will print with a blank icon."))
  }
  
  # backfill unmatched icons with a blank placeholder so the row still renders
  species_table$icon[is.na(species_table$icon)] <- "Blank.png"
  
  # this check now only fires if the species table was empty to begin with
  ifelse(nrow(species_table)==0, print("No species in table"), print("Species table populated"))
  
  
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
  a <- nrow(granklist[which((granklist$grank_rounded=="G3")&granklist$SENSITV_SP!="Y"),])
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
  if(selected_nha$site_type=="hist"){
    nha_siterank <- "Historic"
  }
  
  # sources and funding - we're not going to do this right now
  # db_nha <- dbConnect(SQLite(), dbname=nha_databasename) # connect to the database
  # nha_Sources <- dbGetQuery(db_nha, paste("SELECT * FROM nha_SourcesFunding WHERE SOURCE_REPORT = " , sQuote(selected_nha$SOURCE_REPORT), sep="") )
  # dbDisconnect(db_nha)
  
  ###############################################################
  ## CLEAN AND SANITIZE RAW TEXT --------------------------------------------
  ## IMPORTANT: this must all happen BEFORE any LaTeX markup (\textit{}, \textbf{})
  ## is added below. The per-field pipeline is:
  ##   1. fix encoding artifacts (smart-quote mojibake)
  ##   2. clean_text()      -> strip HTML, resolve &amp; -> &, normalize spaces
  ##   3. sanitize_latex()  -> escape % & _ # $ { } ~ ^ \  so stray DB characters
  ##                           can't break the layout (e.g. a "%" commenting out
  ##                           the rest of a line and swallowing an \end{itemize})
  ##   4. italic/bold markup (added further below)
  ## If we sanitized AFTER adding markup, sanitize_latex() would escape the
  ## backslashes/braces of our own \textit{} and \textbf{} commands.
  
  # 1. fix smart-quote mojibake
  site_account$tr_summary <- str_replace_all(site_account$tr_summary, c("â€™"="'"))
  site_account$site_desc  <- str_replace_all(site_account$site_desc,  c("â€™"="'"))
  if(nrow(tr_bullets)>0){
    for(j in 1:nrow(tr_bullets)){
      tr_bullets$threat_text[j] <- str_replace_all(tr_bullets$threat_text[j], c("â€™"="'"))
    }
  }
  
  # 2. strip HTML / normalize whitespace
  site_account$site_desc  <- clean_text(site_account$site_desc)
  site_account$tr_summary <- clean_text(site_account$tr_summary)
  if(nrow(tr_bullets)>0){
    for(j in 1:nrow(tr_bullets)){
      tr_bullets$threat_text[j] <- clean_text(tr_bullets$threat_text[j])
    }
  }
  
  # 3. escape LaTeX special characters in the free-text fields
  site_account$site_desc  <- sanitize_latex(site_account$site_desc)
  site_account$tr_summary <- sanitize_latex(site_account$tr_summary)
  if(nrow(tr_bullets)>0){
    for(j in 1:nrow(tr_bullets)){
      tr_bullets$threat_text[j] <- sanitize_latex(tr_bullets$threat_text[j])
    }
  }
  if(!is.na(selected_nha$photo_caption)){
    selected_nha$photo_caption <- sanitize_latex(selected_nha$photo_caption)
  }
  
  # also escape the short metadata fields that get dropped into the template.
  # these never receive italic/bold markup, so they can be escaped here directly.
  selected_nha$protected_lands <- sanitize_latex(selected_nha$protected_lands)
  selected_nha$CountyMuni      <- sanitize_latex(selected_nha$CountyMuni)
  selected_nha$photo_name      <- sanitize_latex(selected_nha$photo_name)
  
  ###############################################################
  ## ADD ITALIC / BOLD MARKUP -----------------------------------------------
  ## Runs AFTER sanitize_latex() (this is the final text step). If it ran
  ## before sanitization, the { } \ we insert here would get escaped.
  ###############################################################
  
  ## --- italicize scientific names (uses the global sci_pattern) -----------
  site_account$site_desc  <- wrap_markup(site_account$site_desc,  sci_pattern, "textit")
  site_account$tr_summary <- wrap_markup(site_account$tr_summary, sci_pattern, "textit")
  
  if (nrow(tr_bullets) > 0) {
    tr_bullets$threat_text <- wrap_markup(tr_bullets$threat_text, sci_pattern, "textit")
  }
  
  if (!is.na(selected_nha$photo_caption)) {
    selected_nha$photo_caption <- wrap_markup(selected_nha$photo_caption, sci_pattern, "textit")
  } else {
    print("No Photo 1 caption, moving on...")
  }
  
  ## --- bold tracked-species common names (per-site, from species_table) ---
  # Built per site because the names come from species_table$SCOMNAME. An empty
  # species_table (e.g. historic sites) yields a NULL pattern, which wrap_markup
  # passes through untouched.
  namesbold <- character(0)
  if (nrow(species_table) > 0) {
    namesbold <- species_table$SCOMNAME
    namesbold <- namesbold[!is.na(namesbold) & nzchar(namesbold)]
  }
  
  bold_pattern <- NULL
  if (length(namesbold) > 0) {
    lower   <- tolower(namesbold)
    firstup <- lower
    substr(firstup, 1, 1) <- toupper(substr(firstup, 1, 1))
    bold_pattern <- build_term_pattern(c(namesbold, firstup, lower))
  }
  
  site_account$site_desc  <- wrap_markup(site_account$site_desc,  bold_pattern, "textbf")
  site_account$tr_summary <- wrap_markup(site_account$tr_summary, bold_pattern, "textbf")
  
  if (nrow(tr_bullets) > 0) {
    tr_bullets$threat_text <- wrap_markup(tr_bullets$threat_text, bold_pattern, "textbf")
  }
  
  
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
    
    # drop references whose citation is null/empty (blank entries in the database).
    # done AFTER the <div> wrappers are stripped, so an empty "<div class='csl-entry'></div>"
    # row collapses to "" and gets caught here too.
    references <- references[!is.na(references$latex_citation) & trimws(references$latex_citation) != "", ]
    
    references <- references[!duplicated(references$latex_citation), ]
    
    # the below formatting is to get the url wrapped in the latex \url{} to make sure it wraps appropriately
    url_pattern <- "http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"
    references$url <- str_extract(references$latex_citation, url_pattern)
    has_url <- !is.na(references$url)
    references$updated_url <- NA_character_
    references$updated_url[has_url] <- paste0("\\\\url{", references$url[has_url], "}")
    references$latex_citation[has_url] <- str_replace(
      references$latex_citation[has_url],
      references$url[has_url],
      references$updated_url[has_url]
    )
  }
  
  # get the output folder and the file name
  output_folder <- here::here("_data","output","FourCountyPDFs_20260608")
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
  url_NHApage <- "https://wpcgis.maps.arcgis.com/home/item.html?id=3e5870e8951e489988fc258eda49a685"
  
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
  rnw_template <- "3_template_Formatted_NHA_PDF.rnw"
  makePDF(rnw_template, pdf_filename) # user created function
  deletepdfjunk(pdf_filename) # user created function # delete .txt, .log etc if pdf is created successfully.
  beepr::beep(sound=10, expr=NULL)
} # this is to end the for loop


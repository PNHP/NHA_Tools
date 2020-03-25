#-------------------------------------------------------------------------------
# Name:        0_PathsAndSettings.r
# Purpose:     settings and paths for the NHA report creation tool.
# Author:      Christopher Tracey
# Created:     2019-03-21
# Updated:     2019-05-22
#
# Updates:
# 
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------
#Set up libraries, paths, and settings

# check and load required libraries
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
require(RSQLite)
if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr")
require(knitr)
if (!requireNamespace("xtable", quietly = TRUE)) install.packages("xtable")
require(xtable)
if (!requireNamespace("flextable", quietly = TRUE)) install.packages("flextable")
require(flextable)
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
require(dplyr)
if (!requireNamespace("dbplyr", quietly = TRUE)) install.packages("dbplyr")
require(dbplyr)
if (!requireNamespace("rmarkdown", quietly = TRUE)) install.packages("rmarkdown")
require(rmarkdown)
if (!requireNamespace("tmap", quietly = TRUE)) install.packages("tmap")
require(tmap)
if (!requireNamespace("OpenStreetMap", quietly = TRUE)) install.packages("OpenStreetMap")
require(OpenStreetMap)
if (!requireNamespace("openxlsx", quietly = TRUE)) install.packages("openxlsx")
require(openxlsx)
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
require(sf)
if (!requireNamespace("readtext", quietly = TRUE)) install.packages("readtext")
require(readtext)
if (!requireNamespace("qdapRegex", quietly = TRUE)) install.packages("qdapRegex")
require(qdapRegex)
if (!requireNamespace("textreadr", quietly = TRUE)) install.packages("textreadr")
require(textreadr)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
require(arcgisbinding)
if (!requireNamespace("plyr", quietly = TRUE)) install.packages("plyr")
require(plyr)
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
require(stringr)
if (!requireNamespace("DBI", quietly = TRUE)) install.packages("DBI")
require(DBI)
if (!requireNamespace("tinytex", quietly = TRUE)) install.packages("tinytex")
require(tinytex)
if (!requireNamespace("english", quietly = TRUE)) install.packages("english")
require(english)
# options
options(useFancyQuotes=FALSE)

# load the arcgis license
arc.check_product() 

## Biotics Geodatabase
biotics_gdb <- "W:/Heritage/Heritage_Data/Biotics_datasets.gdb"

# NHA Databases and such
NHA_path <- "P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NHA_ToolsV3"

# NHA database name
nha_databasepath <- "P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/z_Databases"
nha_databasename <- "NaturalHeritageAreas.sqlite" 
nha_databasename <- paste(nha_databasepath,nha_databasename,sep="/")
# threat recc database name
TRdatabasepath <- "P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA/z_Databases"
TRdatabasename <- "nha_recs.sqlite" 
TRdatabasename <- paste(TRdatabasepath,TRdatabasename,sep="/")

# Second, set up an ODBC connection. You only need to do this once, if you continue to connect to the db with the same name
# 1. click magnifier (search) in lower left, type "ODBC" in search window, open "ODBC Data Sources (64 bit)"
# 2. On User DSN tab, choose "Add", then choose "Microsoft Access Driver (.mdb,.accdb)", click on Finish
# 3. In Data Source Name, put "mobi_spp_tracking", then select the DB using the Select button. "OK", then close out.
#https://support.microsoft.com/en-us/help/2721825/unable-to-create-dsn-for-microsoft-office-system-driver-on-64-bit-vers


# custom albers projection
customalbers <- "+proj=aea +lat_1=40 +lat_2=42 +lat_0=39 +lon_0=-78 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs "

# NHA folders on the p-drive
NHAdest <- "P:/Conservation Programs/Natural Heritage Program/ConservationPlanning/NaturalHeritageAreas/_NHA"

# RNW file to use
rnw_template <- "template_Formatted_NHA_PDF.rnw"

# taxaicon lookup
taxaicon <- data.frame(c("Amphibians.png","Arachnids.png","Birds.png","Butterflies.png","Caddisflies.png","Communities.png","Craneflies.png","Earwigscorpionfly.png","Fish.png","Liverworts.png","Mammals.png","Mosses.png","Moths.png","Mussels.png","Odonates.png","OtherInverts.png","Plants.png","Sensitive.png","Snails.png","Sponges.png","TigerBeetles.png","Reptile.png"), c("AAAA","ILARA","AB","IILEP","IITRI","CGH","","","AF","","AM","","IILEY","IMBIV","IIODO","","P","","IMGAS","IZSPN","IICOL02","AR"), stringsAsFactors = FALSE)
names(taxaicon) <- c("icon","ELEMENT_TYPE")

# urls for the template
url_PNHPrank <- "http://www.naturalheritage.state.pa.us/rank.aspx"
url_NSrank <- "http://www.natureserve.org/explorer/eorankguide.htm"
url_NHApage <- "http://www.naturalheritage.state.pa.us/inventories.aspx"

# load italicized names from database to italicize other species names in threats and stressors and description
db <- dbConnect(SQLite(), dbname=TRdatabasename) # connect to the database
ETitalics <- dbGetQuery(db, paste("SELECT * FROM SNAMEitalics") )
dbDisconnect(db) # disconnect the db
ETitalics <- ETitalics$ETitalics # turn into a vector
ETitalics <- ETitalics[ETitalics!="Alle"] # remove some problematic names
vecnames <- ETitalics 
ETitalics <- paste0("\\\\textit{",ETitalics,"}") 
names(ETitalics) <- vecnames
rm(vecnames)




###########################################################################################################################
# FUNCTIONS
###########################################################################################################################

# function to create the folder name
foldername <- function(x){
  nha_foldername <- gsub(" ", "", nha_name, fixed=TRUE)
  nha_foldername <- gsub("#", "", nha_foldername, fixed=TRUE)
  nha_foldername <- gsub("''", "", nha_foldername, fixed=TRUE)
}

# function to generate the pdf
#knit2pdf(here::here("scripts","template_Formatted_NHA_PDF.rnw"), output=paste(pdf_filename, ".tex", sep=""))
makePDF <- function(rnw_template, pdf_filename) {
  knit(here::here("scripts", rnw_template), output=paste(pdf_filename, ".tex",sep=""))
  call <- paste0("xelatex -interaction=nonstopmode ",pdf_filename , ".tex")
  system(call)
  system(paste0("biber ",pdf_filename))
  system(call) # 2nd run to apply citation numbers
}

# function to delete .txt, .log etc if pdf is created successfully.
deletepdfjunk <- function(pdf_filename){
  fn_ext <- c(".aux",".out",".run.xml",".bcf",".blg",".tex",".log",".bbl") #
  if (file.exists(paste(pdf_filename, ".pdf",sep=""))){
    for(i in 1:NROW(fn_ext)){
      fn <- paste(pdf_filename, fn_ext[i],sep="")
      if (file.exists(fn)){
        file.remove(fn)
      }
    }
  }
}

#Function to assign images to each species in table, based on element type; modified to work through a loop of multiple species tables
EO_ImSelect <- function(x) {
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AAAA', "Salamanders.png", 
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AAAB', "Frogs.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AB', "Birds.png", 
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='CGH', "Communities.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AF', "Fish.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AR', "Reptile.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='ICMAL', "Crayfish.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IICOL', "OtherInvert.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IIEPH', "OtherInvert.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IIHYM', "Bees.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IIORT', "Grasshoppers.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IIPLE', "Stoneflies.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IITRI', "Caddisflies.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='ILARA', "Spiders.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IZSPN', "Sponges.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='N', "NonvascularPlants.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IMGAS', "Snails.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IIODO', "Odonates.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IILEP', "Butterflies.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IILEY', "Moths.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='IICOL02', "TigerBeetles.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE=='AM', "Mammals.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE == 'IMBIV', "Mussels.png",
  ifelse(SD_speciesTable[[i]]$ELEMENT_TYPE == 'P', "Plants.png", "Other.png")
                                                                              )))))))))))))))))))))))
} 



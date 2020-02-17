#-------------------------------------------------------------------------------
# Name:        0_COAdb_creator.r
# Purpose:     Create an empty, new COA databases
# Author:      Christopher Tracey
# Created:     2019-02-14
# Updated:     2019-02-20
#
# Updates:
# * 2019-02-20 - minor cleanup and documentation
# To Do List/Future ideas:
#
#-------------------------------------------------------------------------------

#tool_exec <- function(in_params, out_params)  #
#{

# check and load required libraries  
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
require(arcgisbinding)
if (!requireNamespace("RSQLite", quietly = TRUE)) install.packages("RSQLite")
require(RSQLite)
if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr")
require(knitr)
library(xtable)

arc.check_product()

## Network Paths and such
biotics_gdb <- "W:/Heritage/Heritage_Data/Biotics_datasets.gdb"

# open the NHA feature class and select and NHA
nha <- arc.open(here("NHA_newTemplate.gdb","NHA_Core"))
### nha <- arc.open("COA.pgh-GIS0.sde/PNHP.DBO.NHA_Core") # closer to opening over SDE
selected_nha <- arc.select(nha, where_clause="SITE_NAME='Town Hill Barren'")
nha_siteName <- selected_nha$SITE_NAME
nha_filename <- gsub(" ", "", nha_siteName, fixed=TRUE)

## Build the Species Table #########################
# open the related species table and get the rows that match the NHA join id from above
nha_relatedSpecies <- arc.open(here("NHA_newTemplate.gdb","NHA_SpeciesTable"))
selected_nha_relatedSpecies <- arc.select(nha_relatedSpecies) # , where_clause=paste("\"NHD_JOIN_ID\"","=",sQuote(selected_nha$NHA_JOIN_ID),sep=" ")  
selected_nha_relatedSpecies <- selected_nha_relatedSpecies[which(selected_nha_relatedSpecies$NHA_JOIN_ID==selected_nha$NHA_JOIN_ID),] #! consider integrating with the previous line the select statement

SD_speciesTable <- selected_nha_relatedSpecies[c("EO_ID","ELCODE","SNAME","SCOMNAME","ELEMENT_TYPE","G_RANK","S_RANK","S_PROTECTI","PBSSTATUS","LAST_OBS_D","BASIC_EO_R")] # subset to columns that are needed.

eoid_list <- paste(toString(SD_speciesTable$EO_ID), collapse = ",")  # make a list of EOIDs to get data from later
ELCODE_list <- paste(toString(sQuote(unique(SD_speciesTable$ELCODE))), collapse = ",")  # make a list of EOIDs to get data from later

## Get the EO data from Biotics data ####################
#
ptreps <- arc.open(paste(biotics_gdb,"eo_ptreps",sep="/"))
ptreps_selected <- arc.select(ptreps, fields=c("EO_ID", "SNAME", "EO_DATA", "GEN_DESC","MGMT_COM","GENERL_COM"), where_clause=paste("EO_ID IN (", eoid_list, ")",sep="") )

SD_eodata <- ptreps_selected
#SD_eodata <- merge(ptreps_selected,SD_speciesTable[c("ELCODE","SNAME")],all.x=TRUE)

## Write the output document for the site ###############
setwd(here("output"))
# knit2pdf errors for some reason...just knit then call directly
knit(here("NHA_SiteTemplate.rnw"), output=paste(nha_filename, ".tex",sep=""))
call <- paste0("pdflatex -interaction=nonstopmode ", nha_filename , ".tex")
# call <- paste0("pdflatex -halt-on-error -interaction=nonstopmode ",model_run_name , ".tex") # this stops execution if there is an error. Not really necessary
system(call)
system(call) # 2nd run to apply citation numbers

# delete .txt, .log etc if pdf is created successfully.
fn_ext <- c(".log",".aux",".out",".tex") 
if (file.exists(paste(nha_filename, ".pdf",sep=""))){
  #setInternet2(TRUE)
  #download.file(fileURL ,destfile,method="auto")
  for(i in 1:NROW(fn_ext)){
    fn <- paste(nha_filename, fn_ext[i],sep="")
    if (file.exists(fn)){ 
      file.remove(fn)
    }
  }
}



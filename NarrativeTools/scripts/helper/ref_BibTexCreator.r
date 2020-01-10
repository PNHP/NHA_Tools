if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)
if (!requireNamespace("arcgisbinding", quietly = TRUE)) install.packages("arcgisbinding")
  require(arcgisbinding)
if (!requireNamespace("RefManageR", quietly=TRUE)) install.packages("RefManageR")
  require(RefManageR)

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))

# need to create a private key (https://www.zotero.org/settings/keys/new) and add to the "zotero_APIkey.csv" text file. Not saved in the script for security. 
keycode <- paste(readLines(here::here("scripts","helper","zotero_APIkey.csv")), collapse=" ")

NHArefs <- ReadZotero(group="2166223", .params=list(key=keycode, limit=2000) ) # note, this is currenty limited to 2000 references. 

# rename the old bib file for a backup
file.rename(paste(NHAdest,"citations","PNHP_refs.bib", sep="/"), paste(NHAdest,"/citations","/PNHP_refs","_",gsub("[^0-9]", "", Sys.time() ),".bib",sep=""))

# make a bib file
fileConn<-file(paste(NHAdest,"citations","PNHP_refs.bib", sep="/"))
writeLines(toBiblatex(NHArefs), fileConn)
close(fileConn)

# cleanup
rm(list=ls())
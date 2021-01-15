# script to run sites through in a more efficient manner
rm(list=ls()) # clear the environment
source(here::here("scripts", "0_PathsAndSettings.r")) # load in the paths and settings file
################################################################
# Enter the name of your NHA into the script to run step 2 and 3
LauncherNHA <- "Linn Run State Park"
FinalSwitch <- "Final" # "Draft"
# Run the Template Databaser
source(here::here("scripts","2_NHA_TemplateReader.r"))
# Run the pdf Maker
source(here::here("scripts","3_Generate_NHA_PDF.r"))


################################################################
## LOOP VERSION 
t <- read.csv(here::here("scripts","looplist.csv"), stringsAsFactors=FALSE)
names(t) <- "SiteName"
t <- unique(t)
for(q in 1:nrow(t)){
  print(t$SiteName[q])
  #
  rm(list=setdiff(ls(), c("t","q"))) # clear the environment
  source(here::here("scripts", "0_PathsAndSettings.r")) # load in the paths and settings file
  ################################################################
  # Enter the name of your NHA into the script to run step 2 and 3
  LauncherNHA <- t$SiteName[q]
  FinalSwitch <- "Final" # "Draft"
  # Run the Template Databaser
  source(here::here("scripts","2_NHA_TemplateReader.r"))
  # Run the pdf Maker
  source(here::here("scripts","3_Generate_NHA_PDF.r"))
}
################################################################




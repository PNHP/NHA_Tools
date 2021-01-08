 # script to run sites through in a more efficient manner
rm(list=ls()) # clear the environment
source(here::here("scripts", "0_PathsAndSettings.r")) # load in the paths and settings file
################################################################
# Enter the name of your NHA into the script to run step 2 and 3
LauncherNHA <- "Beaver River near Fallston"
FinalSwitch <- "Final" # "Draft"
# Run the Template Databaser
source(here::here("scripts","2_NHA_TemplateReader.r"))
# Run the pdf Maker
source(here::here("scripts","3_Generate_NHA_PDF.r"))







Brady's Run County Park
Brush Creek at Glen Eden Road
Brush Creek at the Pennsylvania Turnpike
Brush Creek Park
Brush Run






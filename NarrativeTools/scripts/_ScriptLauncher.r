 # script to run sites through in a more efficient manner

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)

# clear the environment
rm(list = ls())

# load in the paths and settings file
source(here::here("scripts", "0_PathsAndSettings.r"))
################################################################
# Enter the name of your NHA into the script to run step 2 and 3
LauncherNHA <- "McIntire Run Slope"
FinalSwitch <- "Final" # "Draft"

# Run the Template Databaser
source(here::here("scripts","2_NHA_TemplateReader.r"))
# Run the pdf Maker
source(here::here("scripts","3_Generate_NHA_PDF.r"))


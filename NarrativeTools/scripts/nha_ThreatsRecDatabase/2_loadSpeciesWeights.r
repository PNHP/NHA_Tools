# 2_loadSpeciesWeights.r

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  require(here)

nha_gsrankMatrix <- read.csv(here("_data","databases","sourcefiles","nha_gsrankMatrix.csv"), row.names=1, stringsAsFactors=FALSE)
nha_gsrankMatrix <- as.matrix(nha_gsrankMatrix)

nha_EORANKweights <- read.csv(here("_data","databases","sourcefiles","nha_EORANKweights.csv"), stringsAsFactors=FALSE)

rounded_srank <- read.csv(here("_data","databases","sourcefiles","rounded_srank.csv"), stringsAsFactors=FALSE)
rounded_grank <- read.csv(here("_data","databases","sourcefiles","rounded_grank.csv"), stringsAsFactors=FALSE)

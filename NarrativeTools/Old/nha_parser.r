if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
require(here)
if (!requireNamespace("readtext", quietly = TRUE)) install.packages("readtext")
require(readtext)
if (!requireNamespace("qdapRegex", quietly = TRUE)) install.packages("qdapRegex")
require(qdapRegex)

nha_template <- "NHAReport_part1.docx"


a <- readtext(nha_template)


a1 <- a[2]



b <- rm_between(a1, '<<DESC_B>>', '<<DESC_E>>', extract=TRUE)[[1]]

   
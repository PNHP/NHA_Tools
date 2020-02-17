

library(magick)

p1_path <- paste(NHAdest, "DraftSiteAccounts", nha_foldername, "photos", nha_photos$P1F, sep="/")
p1_pathout <- paste(NHAdest, "DraftSiteAccounts", nha_foldername, "photos", "nha_photo2.jpg", sep="/")

a <- image_read(p1_path)
a1 <- image_scale(a, "900")

image_write(a1, p1_pathout)

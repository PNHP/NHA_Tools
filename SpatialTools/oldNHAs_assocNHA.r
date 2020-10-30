a <- read.csv("C:/Users/CTracey/Desktop/purgatory/OldNHAs.csv", stringsAsFactors=FALSE)

b <- a %>% 
  group_by(NHA_JOIN_I, SITE_NAME) %>% 
  arrange(SITE_NAME, NewName) %>%
  #mutate(NewName1 = paste0(NewName, collapse = "; ")) %>%
  summarise(NewName1 = toString(NewName)) %>%
  ungroup()

write.csv(b, "C:/Users/CTracey/Desktop/purgatory/OldNHAs_summed.csv")





  
c <- read.csv("C:/Users/CTracey/Desktop/purgatory/assocNHA.csv", stringsAsFactors=FALSE)

d <- c %>% 
  group_by(src_NHA_JO, src_SITE_N) %>% 
  arrange(src_SITE_N, nbr_SITE_N) %>%
  #mutate(NewName1 = paste0(NewName, collapse = "; ")) %>%
  summarise(AssociatedNHA = toString(nbr_SITE_N)) %>%
  ungroup()

write.csv(d, "C:/Users/CTracey/Desktop/purgatory/assocNHA_summed.csv")

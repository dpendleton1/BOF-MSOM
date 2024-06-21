#BOF DATA PREP

rm(list = ls())
library(tidyverse)

## inputs
#years
begYEAR = 2005
endYEAR = 2010

#months
begMONTH = 8
endMONTH = 9

#seasons
source('~/Documents/WorkDocuments/Projects/Fundy/makeSeasons.r')
# MONTHLY SEASONS
#   ssn_beg=rbind(c(8,1), c(9,1))
#   ssn_end=rbind(c(8,31),c(9,30))
# 2-MONTH SEASONS
ssn_beg=rbind(c(8,1))
ssn_end=rbind(c(9,30))

## 1. import data
dat <- read_csv(file = "~/Documents/WorkDocuments/Projects/Fundy/Dan & Kelsey All FUNDY data 05-19-2023.CSV", 
                col_types = cols(FILEID = col_character(),
                                 EVENTNO = col_double(),
                                 MONTH = col_double(),
                                 DAY = col_double(),
                                 YEAR = col_double(),
                                 GMT = col_double(),
                                 LATITUDE = col_double(),
                                 LONGITUDE = col_double(),
                                 LEGTYPE = col_double(),
                                 LEGSTAGE = col_double(),
                                 ALT = col_double(),
                                 HEADING = col_double(),
                                 WX = col_character(),
                                 CLOUD = col_double(),
                                 VISIBLTY = col_double(),
                                 BEAUFORT = col_double(),
                                 SPECCODE = col_character(),
                                 IDREL = col_double(),
                                 NUMBER = col_double(),
                                 CONFIDNC = col_double())
)

#drop come columns
dat <- dat %>%
  dplyr::select(-starts_with("BEHAV", ignore.case = FALSE, vars = NULL))
#dplyr::select(-c(WX, CLOUD, HEADING, NUMCALF, ANHEAD, PHOTOS))

#restrict to Nereid
dat <- dat %>%
  filter(PLATFORM == 99)

# discard opportunistic surveys
dat <- dat %>%
  mutate(fileid = str_sub(FILEID, start = 1, end = 1)) %>% 
  filter(fileid == "P" | fileid == "p") %>%
  dplyr::select(-fileid)

#add date column
dat$date_ymd <- as.Date(with(dat,paste(YEAR,MONTH,DAY,sep="-")),"%Y-%m-%d")
dat$date_jday = format(dat$date_ymd,"%j")

# keep only desired years and months
dat <- dat %>%
  filter(YEAR >= begYEAR & YEAR <= endYEAR)

dat <- dat %>%
  filter(MONTH == begMONTH | MONTH == endMONTH)

# create seasons matrix
season <- makeSeasons(begYEAR,endYEAR,ssn_beg,ssn_end)
ssn_beg_date <- as.Date(paste(season[,1],season[,2],season[,3],sep="-"),"%Y-%m-%d")
ssn_end_date <- as.Date(paste(season[,1],season[,4],season[,5],sep="-"),"%Y-%m-%d")
ssn_no = season$SSN_NO
num_ssn = max(ssn_no)
ssn_no_grpd = season$SSN_GRPD_NO
# insert columns with season and season_grpd
dat$season = NA
dat$season_grpd = NA
for (i in 1:length(ssn_beg_date)){
  I = which(dat$date_ymd >= ssn_beg_date[i] & dat$date_ymd <= ssn_end_date[i])
  dat$season[I] = ssn_no[i]
  dat$season_grpd[I] = ssn_no_grpd[i]
}

#I am not sure if we should do this. See user guide. "NUMBER is the number of animals (or vessels, etc.) counted at a sighting.
#  NUMBER is required for all sightings for all data types, and not allowed for non-sighting
#  records. If the number of animals is not known (or for many pollution/human activity 
#  sightings where a number is neither logical nor practical), the field may be left blank,
#  however in those cases the value for CONFIDNC must be “11.” For field efforts where
#  counts are collected in a high/low/best format, it would be “best” that would be put in here."
#find rows where there dat$number is NA, and dat$SPECCODE is not empty
# dat <- dat %>%
#   mutate(number = if_else(condition = is.na(number) & SPECCODE != "" , 1, number))

#----
dat <- dat %>%
  mutate(on.off.eff = if_else((BEAUFORT < 4 & #sea state 0-3
                                 (
                                   (LEGTYPE == 5 & (LEGSTAGE == 1 | LEGSTAGE == 2 | LEGSTAGE == 5)) | #start, continue, end watch while ship not underway
                                     (LEGTYPE == 6 & (LEGSTAGE == 1 | LEGSTAGE == 2 | LEGSTAGE == 5)) #legtype = 6 indicates ship not underway (listening station)
                                 ) & 
                                 (VISIBLTY >=2) & #VISIBLTY >=2 indicates visibility of at least 2 nautical miles
                                 (IDREL == 3 | is.na(IDREL)) # if there is a sighting, IDREL must = 3. If no sightings, then IDREL should be NA
  ), 
  1, 0)) %>%
  #now replace all NA with 0 because those are off-effort
  mutate(on.off.eff = ifelse(is.na(on.off.eff), 0, on.off.eff)
  )


# compute point2point effort for each survey
# source function
fn.grcirclkm <- function(lat1,lon1,lat2,lon2) {
  R <- pi/180      #angle in radians = angle in degrees * R
  D <- 180/pi      #angle in degrees = angle in radains * D
  dist <- 0
  
  NAcheck <- sum(is.na(c(lat1,lon1,lat2,lon2)))
  if (NAcheck==0) {             #only continue if no NA positions
    if ((lat1!=lat2) | (lon1!=lon2))  {
      dlat1 <- lat1 * R              # convert to radian values:
      dlng1 <- lon1 * R
      dlat2 <- lat2 * R
      dlng2 <- lon2 * R
      las <- sin(dlat1) * sin(dlat2);   # compute distance
      lac <- cos(dlat1) * cos(dlat2) * cos(dlng1 - dlng2)
      laf <- las + lac
      if (laf < -1) {
        laf <- -1
        dacos <- (pi/2) - atan(laf/sqrt(1-(laf*laf)))
      } else if (laf < 1) {
        dacos <- (pi/2) - atan(laf/sqrt(1-(laf*laf)));
      } else {
        error ('laf value out of bounds')
      }
      dist <- (dacos * D * 60) * 1.852           #calculate distance in km
    }
  }
  dist <- dist
}

dat$pt2pt.effort <- NA # initialize column to hold distance values between consecutive points
dat$Effort <- NA # initialize column to hold total distance, "Effort", for each survey (higher level effort calculation)
ufid <- unique(dat$FILEID) # unique FILEIDs needed for looping about each survey

## IF DISTANCE BETWEEN POINTS IS >X, THEN WE NEED TO FILL IN USING LINSPACE OR SIMILAR FUNCTION.
# DON'T KNOW HOW TO DO THIS YET

## sum effort for each survey
# loop through each FILEID, each LEGNO2 within each FILEID
for (i in 1:length(ufid)) {
  # for each FILEID ...
  I <- which(dat$FILEID == ufid[i]) # get indices for dat$FILEID[i]
  tmp.dat <- dat[I,] # temporary dataset for only this FILEID
  numRecs <- nrow(tmp.dat) - 1 # count number of records in this temporary dataset
  for (k in 1:numRecs) {
    # for each record in this FILEID
    if (tmp.dat$on.off.eff[k] == 1 &
        tmp.dat$on.off.eff[k + 1] == 1) {
      # if on-effort at two consecutive records
      # apply distance function to calculate distance between on-effort records
      
      # calculated distance and store in every record for this fileid in the original dataset
      dat$pt2pt.effort[I[k]] <-
        fn.grcirclkm(
          tmp.dat$LATITUDE[k],
          tmp.dat$LONGITUDE[k],
          tmp.dat$LATITUDE[k + 1],
          tmp.dat$LONGITUDE[k + 1]
        )
    }
    # store effort value (same for each record of each survey)
    dat$Effort[I] <- sum(dat$pt2pt.effort[I], na.rm = T)
  }
}

## REDUCE SIZE OF THE DATASET
keep.cols <- c("FILEID", "EVENTNO", "YEAR", "MONTH", "DAY", "BEAUFORT", "LEGTYPE", "LEGSTAGE", 
               "LATITUDE", "LONGITUDE", "SPECCODE", "NUMBER", "date_ymd", "date_jday", 
               "on.off.eff", "pt2pt.effort", "season", "season_grpd")
tmpdat <- dat %>%
  dplyr::select(all_of(keep.cols)) #%>%

# cleanup before moving to next script
rm(tmp.dat, i, I, k, numRecs, ufid)

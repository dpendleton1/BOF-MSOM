#BOF DATA PREP
library(tidyverse)

## 0. run bof_param_specification.R

## 1. import data
dat <- read_csv(file = file_loc, 
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
#rm(begYEAR, endYEAR, begMONTH, endMONTH)
#rm(ssn_beg, ssn_end, ssn_no_grpd, ssn_beg_date, ssn_end_date)

#----
dat <- dat %>%
  mutate(on.off.eff = if_else((BEAUFORT <= 6 & # normally require sea state 0-3, but sea state will be covariate on detection in this model
                                 (
                                   (LEGTYPE == 5 & (LEGSTAGE == 1 | LEGSTAGE == 2 | LEGSTAGE == 5)) | #start, continue, end watch while ship not underway
                                     (LEGTYPE == 6 & (LEGSTAGE == 1 | LEGSTAGE == 2 | LEGSTAGE == 5)) #legtype = 6 indicates ship not underway (listening station)
                                 ) & 
                                 (VISIBLTY >=2 | VISIBLTY == -1) & #pre-2020 changes to NARWC Sightings Database, VISIBLTY >=2 or -1 indicates visibility of at least 2 nautical miles. Negative numbers are no longer used, however this dataset was obtained in 2019 before the change.
                                 (IDREL == 3 | is.na(IDREL)) # if there is a sighting, IDREL must = 3. If no sightings, then IDREL should be NA
  ), 
  1, 0)) %>%
  #now replace all NA with 0 because those are off-effort
  mutate(on.off.eff = ifelse(is.na(on.off.eff), 0, on.off.eff)
  )

## REDUCE SIZE OF THE DATASET
keep.cols <- c("FILEID", 
               "EVENTNO", 
               "YEAR", "MONTH", "DAY", 
               "BEAUFORT", 
               "LEGTYPE", "LEGSTAGE", 
               "LATITUDE", "LONGITUDE", 
               "SPECCODE", "IDREL", "NUMBER", 
               "date_ymd", "date_jday", 
               "on.off.eff", 
               "season", "season_grpd")
tmpdat <- dat %>%
  dplyr::select(all_of(keep.cols)) #%>%
rm(keep.cols)

#write.csv(dat, file = "dat_with_dist.csv")
#write.csv(tmpdat, file = "tmpdat.csv")
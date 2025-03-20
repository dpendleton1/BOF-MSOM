# bof_specify_parmams.r
# specify parameters for bof_data_prep and bof_real_deal_xxx codes

rm(list = ls())

#find current directory, setwd to current directory
curr_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
setwd(curr_dir)

## inputs
#years
begYEAR = 1988
endYEAR = 1988

#months
begMONTH = 8
endMONTH = 9

#seasons
#source('~/Documents/WorkDocuments/Projects/Fundy/makeSeasons.R')
source('makeSeasons.R')
# MONTHLY SEASONS
    ssn_beg=rbind(c(8,1), c(9,1))
    ssn_end=rbind(c(8,31),c(9,30))
# 2-MONTH SEASONS
    # ssn_beg=rbind(c(8,1))
    # ssn_end=rbind(c(9,30))
# 2-WEEK SEASONS
#    ssn_beg=rbind(c(8,1), c(8,16), c(9,1), c(9,16))
#    ssn_end=rbind(c(8,15), c(8,31), c(9,15), c(9,30))
# SEASON FOR TESTING
#ssn_beg = rbind(c(8,1), c(8,16))
#ssn_end = rbind(c(8,15), c(8,31))

#file_loc = "~/Documents/WorkDocuments/Projects/Fundy/Dan & Kelsey All FUNDY data 05-19-2023.CSV"


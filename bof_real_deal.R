# run bof_data_prep.R
# source('bof_data_prep.R')

## LOAD LIBRARIES
library(tidyverse)
library(sf)
library(dplyr)
library(mapview)
library(tmap)

## ADD GEOMETRY AND MAKE INTO SF OBJECT
#matrix of lat and long
locs = cbind(tmpdat$LONGITUDE, tmpdat$LATITUDE) #raw long/lat points
#convert locations to sfg object of points or linestrings
locs_pts = sfheaders::sf_point(obj = locs) #sfg object
#locs_pts = sfheaders::sf_linestring(obj = locs) #sfg object
#convert to sfc object
locs_sfc = st_as_sfc(locs_pts, crs = "EPSG:4326") #sfc object, but CRS doesn't stick. should work though.
st_crs(locs_sfc) = "EPSG:4326" #this sets CRS and it sticks

#convert data to sf object, appending original dataset
tmpdat_sf = st_sf(tmpdat, geometry = locs_sfc)    # sf object
rm(locs, locs_pts, locs_sfc)

## CREATE A GRID WITH SPATIAL INFORMATION AND GRID_IDS
cell_size = 0.05
area_grid = st_make_grid(tmpdat_sf, c(cell_size, cell_size), what = "polygons", square = FALSE)

# define study area as a polygon
#bof polygon from a file that i had on my computer
polygon_matrix = cbind(
  lon = c(-66.45, -66.28, -66.28, -66.37, -66.50, -66.62, -66.62, -66.45),
  lat = c(44.82, 44.78, 44.67, 44.55, 44.48, 44.48, 44.70, 44.82)
)
polygon_sfc = st_sfc(st_polygon(list(polygon_matrix))) #create sfc object
st_crs(polygon_sfc) = "EPSG:4326" #insert crs
in_pts <- st_intersects(area_grid, polygon_sfc, sparse = FALSE) #find cells inside of polygon
area_grid <- area_grid[in_pts] #reduce to list of cells only inside of polygon

# To sf and add grid ID
#area_grid_sf = vector("list", num_fids)
area_grid_sf = st_sf(area_grid) %>%
  # add grid ID
  mutate(grid_id = 1:length(lengths(area_grid)))
num_cells = dim(area_grid_sf)[1] #number of cells in the grid
#rm(area_grid)

## SIMPLE PLOT OF SURVEY DATA
# mapview_survey_points = mapview(tmpdat_sf, cex = 3, alpha = .5, popup = NULL)
# mapview_survey_points

## count number of surveys in each season. use maximum as number of columns in final occupancy matrix
num_survs = tibble(
  ssn = ssn_no,
  num = NA)
for (i in 1:num_ssn){
  tmpdat_sf_ssn = tmpdat_sf |> filter(season == ssn_no[i])
  num_survs[i,2] = length(unique(tmpdat_sf_ssn$FILEID))
}
rm(tmpdat_sf_ssn)
max_survs = max(num_survs[,2])

## CREATE EFFORT AND JDAY LISTS. ONE LIST ELEMENT FOR EACH YEAR / SEASON
# need to produce one effort grid for each year. Each year will be one element of effort_list
effort_drop_NA_list = vector("list", num_ssn)
# NOT SURE WE NEED THESE LISTS
#effort_list = vector("list", num_ssn)
#jday_list = vector("list", num_ssn)
#bft_list = vector("list", num_ssn)

# enumerate species and count them
spp = unique(dat$SPECCODE[!is.na(dat$SPECCODE)]) #need array for each species in each year (primary period)
num_spp = length(spp) #number of species

# initialize 3d array for each species. this 'spp3d' will be a template to be copied and values stored in it for each species.
spp3d = array(dim = c(num_cells, max_survs+1, num_ssn))
for (j in 1:num_spp){
  # print(spp[j])
  # generate 3d array to hold detections / non-detections. initialize 3d array
  cmd = paste(spp[j], "3d = spp3d", sep = "")
  # print(cmd)
  eval(parse(text = cmd))
}

# 3d matrices for effort and jday, and others
effort3d = spp3d
jday3d = spp3d
bft3d = spp3d
reps = matrix(data = NA, nrow = num_ssn, ncol = num_cells)

#loop about season
for (i in 1:num_ssn){ 
  
  # isolate season
  #-tmptmpdat_sf = tmpdat_sf |> filter(season == i)
  tmpdat_sf_season = tmpdat_sf |> filter(season == i)
  
  # find survey identifiers (FILEIDs) within the season[i]
  #-tmp_ufids = unique(tmptmpdat_sf$FILEID)
  season_ufids = unique(tmpdat_sf_season$FILEID)
  num_season_ufids = length(season_ufids)
  
  # temporary spatial arrays needed for intersecting within loop about surveys/ufids
  effort = area_grid_sf #create 'effort' by copying area_grid_sf
  jday = area_grid_sf #create 'jday' by copying area_grid_sf
  bft = area_grid_sf #create 'bft' by copying area_grid_sf
  
  #fill out columns to the maximum number of surveys, add two columns at the beginning to account for geometry and grid_id
  effort[,3:(max_survs+2)] = NA
  jday[,3:(max_survs+2)] = NA  
  bft[,3:(max_survs+2)] = NA
  
  for (j in 1:max_survs){ #loop about individual surveys (FILEID)
    
    # if we run out of fileids for this season, fill remaining columns with NA
    if (j > num_season_ufids){ 
      effort[,j+2] = NA
      jday[,j+2] = NA
      bft[,j+2] = NA
    } else { # otherwise, insert the real data
      
      # filter tmpdat_sf for each fileid. store as tmptmpdat_sf
      # example: a = tmptmpdat_sf |> filter(FILEID =='p116214')
      # RENAME SEASON_SURVEY_DAT
      cmd = paste("tmpdat_sf_season_survey = tmpdat_sf_season |> filter(FILEID == '", season_ufids[j], "')", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      # at this point, 'tmpdat_sf_season_survey' has all records from season[i] and survey[j]
      
      # within the survey and season, find all records inside of each cell defined by the grid
      tmpdat_sf_season_survey_grid = st_intersects(area_grid_sf, tmpdat_sf_season_survey)
      # at this point, 'tmpdat_sf_season_survey_grid' holds indices for each grid cell, within season[i] and survey[j]
      
      
      # loop about grid cells to populate effort variable
      for (k in 1:num_cells){
        # sum pt2pt.effort for each grid cell. loop about each grid cell / polygon
        eff_calc = sum(tmpdat_sf_season_survey$pt2pt.effort[tmpdat_sf_season_survey_grid[[k]]], na.rm = T)
        if (eff_calc == 0){
          effort[k,j+2] = NA
        } else {
          effort[k,j+2] = eff_calc
        }
      }
      
      # fill jday array. no need to loop about grid cells:
      #   jday should be the same for all grid cells within a survey, so fill all rows with jday value and NA-out grid cells not surveyed below
      if (length(unique(tmpdat_sf_season_survey$date_jday)) == 1){
        jday[,j+2] = as.numeric(unique(tmpdat_sf_season_survey$date_jday))
      } else {
        jday[,j+2] = -99 #there should only be one value of DAY
      }
      
      # fill bft array. NA-out grid cells not surveyed below
      for (k in 1:num_cells){
        # compute mean of beaufort values
        bft[k,j+2] = mean(tmpdat_sf_season_survey$BEAUFORT[tmpdat_sf_season_survey_grid[[k]]], na.rm = T)
      }
      
      rm(tmpdat_sf_season_survey_grid)
    }
  }
  rm(tmpdat_sf_season_survey)
 
  #name columns
  names(effort)[3:(num_season_ufids+2)] = season_ufids
  names(jday)[3:(num_season_ufids+2)] = season_ufids
  names(bft)[3:(num_season_ufids+2)] = season_ufids
  
  # NA-out cells with no effort within jday, bft, other matricies
  # then get indices, then ask jday matrix (includes geom) to NA-out row/col elements where the non-geom effort matrix has NAs. That NA's out the correct spots in jday matrix.
  effort_drop = st_drop_geometry(effort) # remove geom from effort
  effort_drop_NA = which(is.na(effort_drop), arr.ind = T) # get row and column indices where effort matrix = NA
  effort_drop_NA[,2] = effort_drop_NA[,2]+1 # advance the column by one, to correct for the geom column present in matrices
  effort_drop_NA_list[[i]] = effort_drop_NA # insert into a list object. do not delete - needed in spp section
  jday[effort_drop_NA_list[[i]]] = NA # use list element to NA-out elements of matrix
  bft[effort_drop_NA_list[[i]]] = NA # use list element to NA-out elements of matrix
  rm(effort_drop, effort_drop_NA) #do not delete effort_drop_NA_list[[]], as it is needed to NA-out cells in spp arrays below

  ## now we would like to know, for each site, how many repeat visits do we have within the season?
  repeatVisits = st_drop_geometry(effort) #drop geom
  repeatVisits = repeatVisits[,-1] #remove first column (grid_id)
  repeatVisits[is.na(repeatVisits)] = 0 #change NA to zero
  repeatVisits[repeatVisits>0] = 1 #change effort>0 to 1
  repeatVisits = rowSums(repeatVisits) #sum number of visits to each site
  print(repeatVisits)
  reps[i,] = repeatVisits
  
  # # plot repeat visits to each grid cell within each season
  # plot(repeatVisits,
  #      main = paste("Repeats within season ", i, sep = ""),
  #      xlab = "grid cell",
  #      ylab = "number repeat visits")
  
  # fill 3d effort matrix
  cmd = paste("effort3d[,,", i, "] = as.matrix(st_drop_geometry(effort))", sep = "")
  print(cmd)
  eval(parse(text = cmd))
  
  # fill 3d jday matrix
  cmd = paste("jday3d[,,", i, "] = as.matrix(st_drop_geometry(jday))", sep = "")
  print(cmd)
  eval(parse(text = cmd))
  
  # fill 3d bft matrix
  cmd = paste("bft3d[,,", i, "] = as.matrix(st_drop_geometry(bft))", sep = "")
  print(cmd)
  eval(parse(text = cmd))

  ### # optional: produce lists for each detection variable
  # # spatialize effort_list and jday_list, for uyear[i]
  # effort_list[[i]] = area_grid_sf 
  # jday_list[[i]] = area_grid_sf
  # bft_list[[i]] = area_grid_sf
  
  # effort_list[[i]] = effort  
  # jday_list[[i]] = jday
  # bft_list[[i]] = bft
  ###
  
  rm(effort, jday, bft)
  
  for (j in 1:num_spp){
    print(spp[j])
    
    # temporary dataset for spp[j]
    # example: HAPO = tmpdat_sf |> filter(SPECCODE == "HAPO")
    cmd = paste(spp[j], " = tmpdat_sf_season |> filter(SPECCODE == '", spp[j], "')", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # grid for spp[j]
    # initialize sf object with grid cells for each species, by copying area_grid_sf
    # example: HAPO_grid_sf_ssn1 = area_grid_sf, note that it is season specific
    cmd = paste(spp[j], "_ssn", i, "_grid_sf = area_grid_sf", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    
    ##************ DO THIS ABOVE FOR EFFORT. THIS FILLS NA COLUMNS AT END OF ARRAY *************##
    # make the species grid have max_survs, that is fill out columns to accommodate maximum number of surveys
    # example: HAPO_ssn1_grid_sf[,3:max_survs] = NA
    cmd = paste(spp[j], "_ssn", i, "_grid_sf[,3:(max_survs+2)] = NA", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # loop about surveys
    for (k in 1:num_season_ufids){
      
      print(season_ufids[k]) #display the fileid/survey
      
      # spp[j] for season[i] and survey[k]
      # example: HAPO_tmp = HAPO |> filter(FILEID == fids[j])
      cmd = paste(spp[j], "_survey = ", spp[j], " |> filter(FILEID == '", season_ufids[k], "')", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      
      # within season[i] and survey[k], for spp[j], count number of sightings (not number of animals) in each grid cell
      # example: HAPO_grid_sf$p116214 = lengths(st_intersects(area_grid_sf, HAPO_tmp))
      cmd = paste(spp[j], "_ssn", i, "_grid_sf[,k+2]", " = lengths(st_intersects(area_grid_sf,", spp[j], "_survey))", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      
      cmd = paste("rm(", spp[j], "_survey)", sep = "")
      eval(parse(text = cmd))
    }
    
    # NA-out grid cells that were not visited
    cmd = paste(spp[j], "_ssn", i, "_grid_sf[effort_drop_NA_list[[", i, "]]] = NA", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    spp_ssn_name = paste(spp[j], "_ssn", i, "_grid_sf", sep = "") #generate variable name for easy deleting later
    
    # add column names
    cmd = paste("names(", spp[j], "_ssn", i, "_grid_sf)[3:(num_season_ufids+2)] = season_ufids", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # fill 3d species matrix from the species list
    cmd = paste(spp[j], "3d[,,", i, "] = as.matrix(st_drop_geometry(", spp[j], "_ssn", i, "_grid_sf))", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # remove unnecessary matrices
    # cmd = paste("rm(", spp[j], ", ", spp[j], "_survey, ", spp_ssn_name, ")", sep = "")
    # print(cmd)
    # eval(parse(text = cmd))
    
  }
  rm(tmpdat_sf_season, num_season_ufids)
}

#save output
fn1 = paste("realdeal", "_", begYEAR, "_", endYEAR, "_", cell_size, ".RData", sep = "")
fn2 = paste("save(list = ls(), file = '", fn1, "')", sep = "")
eval(parse(text = fn2))
           
# # Plot effort for one survey
# voi = HUWH_ssn1_grid_sf
# col_name = names(voi)[3]
# 
# tmap_mode("view") #interactive viewing mode, e.g., for web
# map_fishnet = tm_shape(voi) +
#   tm_fill(
#     col = col_name,
#     palette = "Reds",
#     style = "cont",
#     #title = paste("RIWH sightings ", col_name),
#     title = "test",
#     id = "grid_id",
#     showNA = FALSE,
#     alpha = 0.5,
#     #popup.vars = c("voi " = col_name),
#     #popup.format = list(
#     col_name = list(format = "f", digits = 0)
#     #)
#   ) +
#   tm_borders(col = "grey40", lwd = 0.7)
# map_fishnet

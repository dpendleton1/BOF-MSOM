## clear memory
rm(list = ls())

## LOAD LIBRARIES
library(tidyverse)
library(sf)
library(dplyr)
library(mapview)
library(tmap)

# run bof_data_prep.R
source('bof_data_prep.R')

## ADD GEOMETRY AND MAKE INTO SF OBJECT
#matrix of lat and long
locs = cbind(tmpdat$LONGITUDE, tmpdat$LATITUDE) #raw long/lat points

#convert locations to sfg object of points or linestrings
locs_pts = sfheaders::sf_point(obj = locs) #sfg object
#locs_pts = sfheaders::sf_linestring(obj = locs) #sfg object

#convert to sfc object
locs_sfc = st_as_sfc(locs_pts, crs = "EPSG:4326") #sfc object, but CRS doesn't stick. should work though.
st_crs(locs_sfc) = "EPSG:4326" #this sets CRS and it sticks

#convert to sf object, appending original dataset
tmpdat_sf = st_sf(tmpdat, geometry = locs_sfc)    # sf object
rm(locs, locs_pts, locs_sfc)

## CREATE A GRID WITH SPATIAL INFORMATION AND GRID_IDS
area_grid = st_make_grid(tmpdat_sf, c(0.2, 0.2), what = "polygons", square = FALSE)

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
effort_list = vector("list", num_ssn)
effort_drop_NA_list = vector("list", num_ssn)
jday_list = vector("list", num_ssn)
bft_list = vector("list", num_ssn)

# needed for loop about species
# need to make spp array in order to do intersecting
spp = unique(dat$SPECCODE) #need array for each species in each year (primary period)
spp = spp[!is.na(spp)] #comprehensive list of all species in the entire dataset
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
for (i in 1:num_ssn){ #loop about season number, effort_list[[i]]
  
  # spatialize effort_list and jday_list, for uyear[i]
  effort_list[[i]] = area_grid_sf 
  jday_list[[i]] = area_grid_sf
  bft_list[[i]] = area_grid_sf
  
  # isolate season
  tmptmpdat_sf = tmpdat_sf |> filter(season == i)
  # find survey identifiers (FILEIDs) within uyear[i]
  tmp_ufids = unique(tmptmpdat_sf$FILEID)
  # # count number of FILEIDs
  num_fids = length(tmp_ufids) #also "#num_fids = num_survs[i,2]", however that is a tibble
  
  # temporary arrays needed for loop about fids
  effort = area_grid_sf #create 'effort' by copying area_grid_sf
  jday = area_grid_sf #create 'jday' by copying area_grid_sf
  bft = area_grid_sf #create 'bft' by copying area_grid_sf
  
  #fill out columns to the maximum number of surveys, add two columns at the beginning to account for geometry and grid_id
  effort[,3:(max_survs+2)] = NA
  jday[,3:(max_survs+2)] = NA  
  bft[,3:(max_survs+2)] = NA
  
  for (j in 1:max_survs){ #loop about individual surveys (FILEID)
    
    # if we run out of fileids for this season, fill remaining columns with NA
    if (j > num_fids){ 
      effort[,j+2] = NA
      jday[,j+2] = NA
      bft[,j+2] = NA
    } else { # otherwise, insert the real data
      
      # filter tmpdat_sf for each fileid. store as tmptmpdat_sf
      # example: a = tmptmpdat_sf |> filter(FILEID =='p116214')
      cmd = paste("a = tmptmpdat_sf |> filter(FILEID == '", tmp_ufids[j], "')", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      # at this point, 'a' has all records from year[i] and fileid[j]
      
      # find all records inside of each cell defined by the grid, call this tmp_effort
      tmp_effort = st_intersects(area_grid_sf, a) #intersecting 'a' with 'area_grid_sf' provides the rows of 'a' that are in each grid cell in 'area_grid_sf'
      
      # sum pt2pt.effort for each grid cell. loop about each grid cell / polygon
      # store results in 'effort'
      for (k in 1:num_cells){
        eff_calc = sum(a$pt2pt.effort[tmp_effort[[k]]], na.rm = T)
        if (eff_calc == 0){
          effort[k,j+2] = NA
        } else {
          effort[k,j+2] = eff_calc
        }
      }
      
      # fill jday array. this array will not have NAs in the right places
      # jday must be unique. no missing values or multiple values on the same day
      if (length(unique(a$date_jday)) == 1){
        jday[,j+2] = as.numeric(unique(a$date_jday))
      } else {
        jday[,j+2] = -99 #there should only be one value of DAY
      }
      
      # fill bft array. this array will not have NAs in the right places
      # compute mean of beaufort values
      for (k in 1:num_cells){
        bft[k,j+2] = mean(a$BEAUFORT[tmp_effort[[k]]], na.rm = T)
      }
      
      rm(tmp_effort)
      
    }
  }
  
  # NA-out cells with no effort within jday matrix. 
  # I am not sure how this works. First remove geom from effort, then get indices, then ask jday matrix (includes geom) to NA-out row/col elements where the non-geom effort matrix has NAs. That NA's out the correct spots in jday matrix.
  effort_drop = st_drop_geometry(effort) #drop geom
  effort_drop_NA = which(is.na(effort_drop), arr.ind = T) #get row and column indices
  effort_drop_NA[,2] = effort_drop_NA[,2]+1 #advance the column by one, to correct for the geom column present in jday
  effort_drop_NA_list[[i]] = effort_drop_NA
  jday[effort_drop_NA_list[[i]]] = NA
  bft[effort_drop_NA_list[[i]]] = NA
  rm(effort_drop, effort_drop_NA)
  
  #name columns
  names(effort)[3:(num_fids+2)] = tmp_ufids
  effort_list[[i]] = effort  
  rm(effort)
  
  # names(jday)[3:(num_fids+2)] = tmp_ufids
  names(jday)[3:(num_fids+2)] = tmp_ufids
  jday_list[[i]] = jday
  bft_list[[i]] = bft
  rm(bft)
  
  # fill 3d effort matrix
  cmd = paste("effort3d[,,", i, "] = as.matrix(st_drop_geometry(effort_list[[", i, "]]))", sep = "")
  print(cmd)
  eval(parse(text = cmd))
  
  # fill 3d jday matrix
  cmd = paste("jday3d[,,", i, "] = as.matrix(st_drop_geometry(jday_list[[", i, "]]))", sep = "")
  print(cmd)
  eval(parse(text = cmd))
  
  cmd = paste("bft3d[,,", i, "] = as.matrix(st_drop_geometry(bft_list[[", i, "]]))", sep = "")
  print(cmd)
  eval(parse(text = cmd))
  
  for (j in 1:num_spp){
    print(spp[j])
    
    # temporary dataset for spp[j]
    # example: HAPO = tmpdat_sf |> filter(SPECCODE == "HAPO")
    cmd = paste(spp[j], " = tmptmpdat_sf |> filter(SPECCODE == '", spp[j], "')", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # grid for spp[j]
    # create sf object with grid polygons and grid_ids for each species, by copying area_grid_sf
    # example: HAPO_grid_sf_ssn1 = area_grid_sf, note that it is season specific
    cmd = paste(spp[j], "_ssn", i, "_grid_sf = area_grid_sf", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # make the species grid have max_survs, that is fill out columns to accommodate maximum number of surveys
    # example: HAPO_ssn1_grid_sf[,3:max_survs] = NA
    cmd = paste(spp[j], "_ssn", i, "_grid_sf[,3:(max_survs+2)] = NA", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    for (k in 1:num_fids){
      
      print(tmp_ufids[k])
      
      # spp[j] for season[i] and survey[k]
      # example: HAPO_tmp = HAPO |> filter(FILEID == fids[j])
      cmd = paste(spp[j], "_tmp = ", spp[j], " |> filter(FILEID == '", tmp_ufids[k], "')", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      
      # count number of sightings (not number of animals) in each grid cell for survey tmp_ufids[k]
      # example: HAPO_grid_sf$p116214 = lengths(st_intersects(area_grid_sf, HAPO_tmp))
      cmd = paste(spp[j], "_ssn", i, "_grid_sf[,k+2]", " = lengths(st_intersects(area_grid_sf,", spp[j], "_tmp))", sep = "")
      print(cmd)
      eval(parse(text = cmd))
      
    }
    
    # NA-out grid cells that were not visited
    cmd = paste(spp[j], "_ssn", i, "_grid_sf[effort_drop_NA_list[[", i, "]]] = NA", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # add column names
    cmd = paste("names(", spp[j], "_ssn", i, "_grid_sf)[3:(num_fids+2)] = tmp_ufids", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # fill 3d species matrix from the species list
    cmd = paste(spp[j], "3d[,,", i, "] = as.matrix(st_drop_geometry(", spp[j], "_ssn", i, "_grid_sf))", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
    # remove unnecessary matrices
    cmd = paste("rm(", spp[j], ", ", spp[j], "_tmp)", sep = "")
    print(cmd)
    eval(parse(text = cmd))
    
  }
  rm(tmptmpdat_sf, tmp_ufids, num_fids, a)
  
  ## now we would like to know, for each site, how many repeat visits do we have within the season?
  # we should be able to learn this directly from the effort matrix
  repeatVisits = st_drop_geometry(effort_list[[i]]) #drop geom
  repeatVisits = repeatVisits[,-1] #remove first column (grid_id)
  repeatVisits[is.na(repeatVisits)] = 0 #change NA to zero
  repeatVisits[repeatVisits>0] = 1 #change effort>0 to 1
  repeatVisits = rowSums(repeatVisits) #sum number of visits to each site
  plot(repeatVisits,
       main = paste("Repeats within season ", i, sep = ""),
       xlab = "grid_id",
       ylab = "number repeat visits")
  # hist(repeatVisits,
  #      breaks = c(0,1,2,3,5,10,15,20),
  #      main = "number of repeats within this season",
  #      xlab = "grid_id",
  #      ylab = "number repeat visits")
  
}


# Plot effort and save plots
# ALSO DO THIS FOR # REPEATS
# for (i in 1:(dim(num_survs)[1])){
i=2
voi = effort_list[[i]]
col_name = names(voi)[3] #FILEID (could also be date)

tmap_mode("view") #interactive viewing mode, e.g., for web
map_fishnet = tm_shape(voi) +
  tm_fill(
    col = col_name, 
    palette = "Reds",
    style = "cont",
    title = paste("survey effort (km) ", col_name),
    id = "grid_id",
    showNA = FALSE,
    alpha = 0.5,
    #popup.vars = c("voi " = col_name),
    #popup.format = list(
    #  col_name = list(format = "f", digits = 0)
    #)
  ) +
  tm_borders(col = "grey40", lwd = 0.7)
map_fishnet
# tmap_save(map_fishnet, filename = paste0(col_name, ".png", sep = ""))
# }


# # now we would like to make a plot of some sightings.
# dat_map = HAPO_grid_sf
# tmap_mode("view")
# map_fishnet = tm_shape(dat_map) +
#   tm_fill(
#     col = "p116214",
#     palette = "Reds",
#     style = "cont",
#     title = "# sightings",
#     id = "grid_id",
#     showNA = FALSE,
#     alpha = 0.5,
#     popup.vars = c(
#       "HAPOs " = "p116214"
#     ),
#     popup.format = list(
#       p116214 = list(format = "f", digits = 0)
#     )
#   ) +
#   tm_borders(col = "grey40", lwd = 0.7)
# map_fishnet
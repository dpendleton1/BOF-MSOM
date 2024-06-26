# Import
import geopandas as gpd
import glob
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
import rasterstats
import rioxarray as rxr
import shapely
from shapely import wkt
import xarray as xr

#####
data_folder = 'C:/Users/jsyme/My Drive/JSBigelow/Data/'  # set the data folder
crs_local = 32619  # set the CRS

#####
# Temporal
tm_years = (2005, 2010)  # set the year range
tm_months = (8, 10)  # set the month range
tm_season = 'month'  # set the season
tm_name = (str(tm_years[0]) + '-' + str(tm_years[1]) +
           '_x_' + str(tm_months[0]) + '-' + str(tm_months[1]) +
           '_x_' + tm_season)

#####
# Spatial
sp_extent_name = 'bof'  # set the spatial extent name
sp_extent = gpd.read_file(data_folder + 'BOF_MSOM/BOF_sptm/__input/' + sp_extent_name + '.gpkg').to_crs(crs_local)  # input the spatial extent file
sp_size = (10000, 10000)  # set the size (height, width) of spatial samples (i.e., grid cells)
sp_name = sp_extent_name + '_' + str(sp_size[0]) + 'x' + str(sp_size[1])  # the name of the spatial extent x size combination

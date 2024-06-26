# Imports
from BOF_MSOM.BOF_sesienv.__setup import *


#####
# Input sighting data
sightings = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_ON_si.csv')

#####
# Geometries

# Create list for sightings geometries
geometries_si = []

for lat_si, lon_si in zip(sightings['lat'], sightings['lon']):
    geometry_si = shapely.Point([lon_si, lat_si])  # create a geometry (point) for each sighting
    geometries_si.append(geometry_si)  # add each sighting geometry to the list of geometries

# Add the geometries as a column
sightings['geometry'] = geometries_si


#####
# Output
sightings.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_si_geoms.csv', index=False)

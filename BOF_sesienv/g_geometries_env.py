# Imports
from BOF_MSOM.BOF_sesienv.__setup import *


#####
# Input environmental data (survey effort data)
env = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_ON_se.csv')

#####
# Geometries

# Create list for environmental geometries
geometries_env = []

for lat_env, lon_env in zip(env['lat'], env['lon']):
    geometry_env = shapely.Point([lon_env, lat_env])  # create a geometry (point) for each environmental point
    geometries_env.append(geometry_env)  # add each environmental geometry to the list of geometries

# Add the geometries as a column
env['geometry'] = geometries_env


#####
# Output
env.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_env_geoms.csv', index=False)

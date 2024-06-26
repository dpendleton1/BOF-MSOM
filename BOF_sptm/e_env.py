from BOF_MSOM.BOF_sptm.__setup import *
from BOF_MSOM.BOF_sptm.__functions import *

#####
# Input

# Input the grid
grid = gpd.read_file(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '.gpkg')

# Input the spatiotemporal template
sptm = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '__' + tm_name + '.csv')

# Input the environmental points
env = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_env_geoms.csv', parse_dates=['datetime'])
env = env[['year', 'month', 'sn_id', 'sv_id', 'bss', 'geometry']]  # keep only necessary columns

#####
# Extents

# Create a copy to apply extents to
env_sub = env.copy()

# Apply temporal extents
env_sub = env_sub.loc[(env_sub['year'] >= tm_years[0]) & (env_sub['year'] <= tm_years[1])]
env_sub = env_sub.loc[(env_sub['month'] >= tm_months[0]) & (env_sub['month'] <= tm_months[1])]

# Apply spatial extents
env_sub['geometry'] = env_sub['geometry'].apply(wkt.loads)  # load geometries of the environmental points
env_sub = gpd.GeoDataFrame(env_sub, geometry='geometry', crs=4326).to_crs(crs_local)  # convert environmental points to GeoDataFrame
env_sub = env_sub[env_sub.intersects(grid.dissolve().geometry.iloc[0])]  # keep only environmental points that intersect with the grid

#####
# Resampling

# Spatial - determine which environmental points are in which grid cells
env_sub = gpd.sjoin(env_sub, grid, how='left')

# Temporal - group environmental points by temporal periods
env_sub = (env_sub.groupby(['sp_id', 'year', 'sn_id', 'sv_id']).agg({
    'bss': 'mean',  # get the mean of the BSS values
})).reset_index()

#####
# Output
env_sub['year'] = env_sub['year'].apply(lambda y: 'y' + str(y))
env_sptm = pd.merge(sptm, env_sub, on=['year', 'sp_id', 'sn_id', 'sv_id'], how='left')  # merge with the spatiotemporal template
# env_sptm.fillna(0, inplace=True)  # replace NaN values (i.e., spatiotemporal periods with no environmental points) with 0
env_sptm.to_csv(data_folder + 'BOF_MSOM/BOF_sptm/e_env/' + sp_name + '__' + tm_name + '_env.csv', index=False)  # output

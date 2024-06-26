from BOF_MSOM.BOF_sptm.__setup import *
from BOF_MSOM.BOF_sptm.__functions import *

#####
# Input

# Input the grid
grid = gpd.read_file(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '.gpkg')
grid['grid_geometry'] = grid.geometry  # duplicate grid geometry, necessary for spatial join later

# Input the spatiotemporal template
sptm = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '__' + tm_name + '.csv')

# Input the survey effort
se = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_se_geoms.csv', parse_dates=['datetime_beg', 'datetime_end'])
se = se[['year', 'month', 'sn_id', 'sv_id', 'geometry']]  # keep only necessary columns
se.rename(columns={'geometry': 'line_geometry'}, inplace=True)  # rename geometry column, useful for spatial join later

#####
# Extents

# Create a copy to apply extents to
se_sub = se.copy()

# Apply temporal extents
se_sub = se_sub.loc[(se_sub['year'] >= tm_years[0]) & (se_sub['year'] <= tm_years[1])]
se_sub = se_sub.loc[(se_sub['month'] >= tm_months[0]) & (se_sub['month'] <= tm_months[1])]

# Apply spatial extents
se_sub['line_geometry'] = se_sub['line_geometry'].apply(wkt.loads)  # load geometries of the SE tracklines
se_sub = gpd.GeoDataFrame(se_sub, geometry='line_geometry', crs=4326).to_crs(crs_local)  # convert SE to GeoDataFrame
se_sub = se_sub[se_sub.intersects(grid.dissolve().geometry.iloc[0])]  # keep only SE that intersects with the grid

#####
# Resampling

# Spatial - determine which SE is in which grid cell
se_sub = gpd.sjoin(se_sub, grid, how='inner')  # spatial join the SE to the grid (each row is a pair of SE and grid cell that interact)
se_sub['line_grid_geometry'] = se_sub.apply(lambda r: r['line_geometry'].intersection(r['grid_geometry']), axis=1)   # cut each section of SE by its corresponding grid cell

# Get values
se_sub['se_yn'] = 1  # add column of SE occurrence
se_sub['se_length'] = se_sub['line_grid_geometry'].length  # add column of the length of the SE cut by grid cell

# Temporal - group SE by spatial, season, and survey IDs
se_sub = (se_sub.groupby(['sp_id', 'year', 'sn_id', 'sv_id']).agg({
    'se_yn': 'first',  # keep the first SE occurrence value, i.e., 1
    'se_length': 'sum'  # sum the lengths of SE
})).reset_index()  # result is a dataframe of spatiotemporal periods (grid cells at a given time) that have SE and the length of that SE

#####
# Output
se_sub['year'] = se_sub['year'].apply(lambda y: 'y' + str(y))
se_sptm = pd.merge(sptm, se_sub, on=['year', 'sp_id', 'sn_id', 'sv_id'], how='left')  # merge with the spatiotemporal template
se_sptm.fillna(0, inplace=True)  # replace NaN values (i.e., spatiotemporal periods with no SE) with 0
se_sptm.to_csv(data_folder + 'BOF_MSOM/BOF_sptm/c_se/' + sp_name + '__' + tm_name + '_se.csv', index=False)  # output

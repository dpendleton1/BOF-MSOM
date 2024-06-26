from BOF_MSOM.BOF_sptm.__setup import *
from BOF_MSOM.BOF_sptm.__functions import *

#####
# Input

# Input the grid
grid = gpd.read_file(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '.gpkg')

# Input the spatiotemporal template
sptm = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '__' + tm_name + '.csv')

# Input the sightings
si = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_si_geoms.csv', parse_dates=['datetime'])
si = si[['year', 'month', 'sn_id', 'sv_id', 'sp_code', 'no', 'geometry']]  # keep only necessary columns
si.rename(columns={'no': 'si_count'}, inplace=True)  # rename number column, useful for analysis later

#####
# Extents

# Create a copy to apply extents to
si_sub = si.copy()

# Apply temporal extents
si_sub = si_sub.loc[(si_sub['year'] >= tm_years[0]) & (si_sub['year'] <= tm_years[1])]
si_sub = si_sub.loc[(si_sub['month'] >= tm_months[0]) & (si_sub['month'] <= tm_months[1])]

# Apply spatial extents
si_sub['geometry'] = si_sub['geometry'].apply(wkt.loads)  # load geometries of the sightings
si_sub = gpd.GeoDataFrame(si_sub, geometry='geometry', crs=4326).to_crs(crs_local)  # convert sightings to GeoDataFrame
si_sub = si_sub[si_sub.intersects(grid.dissolve().geometry.iloc[0])]  # keep only sightings that intersect with the grid

#####
# Species
for sp in si_sub['sp_code'].unique():
    si_sub_sp = si_sub.copy()[si_sub['sp_code'] == sp]

    #####
    # Resampling

    # Spatial - determine which sightings are in which grid cells
    si_sub_sp = gpd.sjoin(si_sub_sp, grid, how='left')

    # Get values
    si_sub_sp['si_pa'] = 1  # add column of sighting presence/absence
    si_sub_sp['ind_count'] = si_sub_sp['si_count']  # add column of the number of individuals

    # Temporal - group sightings by temporal periods
    si_sub_sp = (si_sub_sp.groupby(['sp_id', 'year', 'sn_id', 'sv_id']).agg({
        'si_pa': 'first',  # keep the first sighting presence/absence value, i.e., 1
        'si_count': 'count',  # count the number of sightings
        'ind_count': 'sum',  # sum the number of individuals
    })).reset_index()

    #####
    # Output
    si_sub_sp['year'] = si_sub_sp['year'].apply(lambda y: 'y' + str(y))
    si_sptm = pd.merge(sptm, si_sub_sp, on=['year', 'sp_id', 'sn_id', 'sv_id'], how='left')  # merge with the spatiotemporal template
    si_sptm.fillna(0, inplace=True)  # replace NaN values (i.e., spatiotemporal periods with no sightings) with 0
    si_sptm.to_csv(data_folder + 'BOF_MSOM/BOF_sptm/d_si/' + sp_name + '__' + tm_name + '_si_' + sp + '.csv', index=False)  # output

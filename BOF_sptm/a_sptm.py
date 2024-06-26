from BOF_MSOM.BOF_sptm.__setup import *
from BOF_MSOM.BOF_sptm.__functions import *


# Load survey effort
se = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_se_geoms.csv', parse_dates=['datetime_beg', 'datetime_end'])

#####
# Temporal

# Apply temporal extents
se = se.loc[(se['year'] >= tm_years[0]) & (se['year'] <= tm_years[1])]
se = se.loc[(se['month'] >= tm_months[0]) & (se['month'] <= tm_months[1])]

# Create labels
yr_labels = ['y' + str(y) for y in se['year'].unique()]
sn_labels = se['sn_id'].unique().tolist()
sv_labels = se['sv_id'].unique().tolist()

#####
# Spatial
grid = gridder(sp_extent, sp_size[0], sp_size[1], crs_local)  # create grid

se['geometry'] = se['geometry'].apply(wkt.loads)  # load geometries of the SE tracklines
se = gpd.GeoDataFrame(se, geometry='geometry', crs=4326).to_crs(crs_local)  # convert SE to GeoDataFrame
grid = grid.copy()[grid.intersects(se.dissolve().geometry.iloc[0])]  # keep only grid cells that intersect with the SE

grid.reset_index(inplace=True, drop=True)  # reset index and drop former index column as index is no longer continuous as certain cells were removed
grid.reset_index(inplace=True)  # reset index again...
grid.rename(columns={'index': 'sp_id'}, inplace=True)  # ...and use second former index to...
grid['sp_id'] = grid['sp_id'].apply(lambda gc: 'g' + str(gc).zfill(5))  # ...create spatial IDs for each grid cell, e.g., g00024

base = sp_extent.plot(alpha=0.2)
grid.plot(ax=base, facecolor='none', edgecolor='#707070')
se.plot(ax=base)

grid.to_file(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '.gpkg')  # output to GeoPackage

#####
# Spatiotemporal template
sptm = pd.DataFrame(grid['sp_id'], columns=['sp_id'])  # create a dataframe with the spatial IDs
sptm['year'] = [yr_labels for i in sptm.index]  # add the temporal IDs as a list to each row then...
sptm = sptm.assign(year=sptm['year']).explode('year')  # ...explode so that the rows contain all combinations of spatial and temporal IDs, i.e., all spatiotemporal periods
sptm['sn_id'] = [sn_labels for i in sptm.index]  # add the temporal IDs as a list to each row then...
sptm = sptm.assign(sn_id=sptm['sn_id']).explode('sn_id')  # ...explode so that the rows contain all combinations of spatial and temporal IDs, i.e., all spatiotemporal periods
sptm['sv_id'] = [sv_labels for j in sptm.index]  # add the temporal IDs as a list to each row then...
sptm = sptm.assign(sv_id=sptm['sv_id']).explode('sv_id')  # ...explode so that the rows contain all combinations of spatial and temporal IDs, i.e., all spatiotemporal periods
sptm.to_csv(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '__' + tm_name + '.csv', index=False)  # output to CSV

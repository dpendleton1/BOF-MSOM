# Imports
from BOF_MSOM.BOF_sesienv.__setup import *


#####
# Input and preparation

# Input
se = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_ON_se.csv')

# Print extent
print(se['lon'].max(), se['lat'].max(), se['lon'].min(), se['lat'].min())


#####
# Group by sections

# Create/rename columns before grouping
se['datetime_end'] = se['datetime']  # create datetime column for end time
se.rename(columns={'datetime': 'datetime_beg'}, inplace=True)  # rename datetime column to datetime_beg
se['time_end'] = se['time']  # create time column for end time
se.rename(columns={'time': 'time_beg'}, inplace=True)  # rename time column to time_beg

# Group survey effort waypoints by section ID
se = se.groupby(['section_id']).agg({
    'file_id': 'first',
    'survey_type': 'first',
    'platform': 'first',
    'dd_source': 'first',
    'id_source': 'first',
    'event_no': list,
    'on_off': 'first',
    'datetime_beg': 'first',
    'datetime_end': 'last',
    'date': 'first',
    'year': 'first',
    'month': 'first',
    'day': 'first',
    'time_beg': 'first',
    'time_end': 'last',
    'season': 'first',
    'sn_id': 'first',
    'sv_id': 'first',
    'lat': list,
    'lon': list,
    'leg_type': 'first',
    'leg_stage': list,
    # Environmental conditions
    # 'heading':
    # 'alt':
    # 'wx':
    # 'cloud':
    # 'vis':
    # 'bss': list
    # Sighting info
    # 'si_no': list,
    # 'sp_code': list,
    # 'sp_rel': list,
    # 'no': list,
    # 'no_conf': list,
    # 'no_calves': list
})
se.reset_index(inplace=True)
se.insert(5, 'section_id', se.pop('section_id'))  # relocate section ID column


#####
# Geometries

# Create lists for the geometries
sections_geometries = []
sections_lengths = []

# For each section
for section_lats, section_lons in zip(se['lat'], se['lon']):
    section_latlons = []  # create an empty list for the lat-lon tuples
    for lat, lon in zip(section_lats, section_lons):  # for each lat-lon pair...
        section_latlons.append((lon, lat))  # ...append the pair as a tuple to the list

    # If there is more than 1 point
    if len(section_latlons) > 1:
        section_geometry = shapely.LineString(section_latlons)  # create a geometry (linestring) for each section
        sections_geometries.append(section_geometry)  # add each section geometry to the list of geometries

        # Measure the length of each section
        section_geoseries_3857 = gpd.GeoSeries(section_geometry, crs=4326).to_crs('ESRI:102008')
        section_length = round(section_geoseries_3857.geometry.length.sum() / 1000, 3)
        sections_lengths.append(section_length)

    # Else, if the section contains only one point
    else:
        sections_geometries.append('ERROR_SP')
        sections_lengths.append('ERROR_SP')

# Add the geometries as a column
se['geometry'] = sections_geometries
se['length'] = sections_lengths


#####
# Clean up
se = se[se['geometry'] != 'ERROR_SP']  # remove sections that contain only one point
se.drop(['lat', 'lon'], axis=1, inplace=True)  # drop latitude and longitude columns


#####
# Output
se.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/g_geometries/BOF_ON_se_geoms.csv', index=False)

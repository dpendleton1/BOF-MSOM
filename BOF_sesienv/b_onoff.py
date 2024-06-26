#####
# Imports
from BOF_MSOM.BOF_sesienv.__setup import *


#####
# Input data
data = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/a_downsized/BOF_all.csv')

#####
# ON/OFF: determine if each point is ON or OFF
data.insert(7, 'on_off', 'OFF')  # create ON/OFF column with all entries set as ON (as default)
data.loc[(
    (data['bss'] < 4)
    & (data['vis'] >= 2)
    & (data['leg_type'].isin([5, 6]) & ((data['leg_stage'] == 1) | (data['leg_stage'] == 2) | (data['leg_stage'] == 5)))
    & ((data['sp_rel'] == 3) | data['sp_rel'].isna())
), 'on_off'] = 'ON'


# Process ON/OFF
data['on_off_same'] = data['on_off'].eq(data['on_off'].shift())  # determine changes from ON to OFF or vv
data_OFF = data.copy()[data['on_off'] == 'OFF']  # create a dataframe of only OFF entries
data_OFF.drop(['on_off_same'], axis=1, inplace=True)
data_OFF.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_OFF_se.csv', index=False)  # output OFF
data = data.copy()[data['on_off'] == 'ON'].reset_index(drop=True)  # keep only points that are ON


#####
# Datetimes

# Create datetimes
data.insert(8, 'datetime', '')
data['year'] = data['year'].astype(int).astype(str)  # reformat
data['month'] = data['month'].astype(int).astype(str).str.zfill(2)
data['day'] = data['day'].astype(int).astype(str).str.zfill(2)
data['time'] = data['time'].astype(int).astype(str).str.zfill(6)
data['datetime'] = (data['year'] + '-' + data['month'] + '-' + data['day'] + ' ' + data['time'])  # str in UTC
data['datetime'] = data['datetime'].apply(lambda d: datetime.strptime(d, '%Y-%m-%d %H%M%S'))  # datetime in UTC
data['datetime'] = data['datetime'].apply(lambda d: d - timedelta(hours=5))  # datetime in EST

# Create date, year, and month columns as strings in EST
data.drop(['year', 'month', 'day', 'time'], axis=1, inplace=True)  # remove columns in UTC
data.insert(9, 'date', '')
data.insert(10, 'year', '')
data.insert(11, 'month', '')
data.insert(12, 'day', '')
data.insert(13, 'time', '')
data['date'] = data['datetime'].apply(lambda d: d.strftime('%Y-%m-%d'))  # string in EST
data['year'] = data['datetime'].apply(lambda d: d.strftime('%Y'))
data['month'] = data['datetime'].apply(lambda d: d.strftime('%m'))
data['day'] = data['datetime'].apply(lambda d: d.strftime('%d'))
data['time'] = data['datetime'].apply(lambda d: d.strftime('%H:%M:%S'))


#####
# Seasons
data.insert(14, 'season', '')
data['season'] = data['month']  # <><>get Dan's season making function
data.insert(15, 'sn_id', '')
data['sn_id'] = data.apply(lambda r: 'sn' + str(r['season']).zfill(2), axis=1)


#####
# Surveys
sv_ids = data.copy().groupby(['year', 'sn_id']).agg({'file_id': 'unique'})
sv_ids['sv_id'] = sv_ids.apply(lambda r: ['sv' + str(i).zfill(2) for i in range(1, len(r['file_id']) + 1)], axis=1)
sv_ids = sv_ids.explode(['file_id', 'sv_id']).reset_index()
sv_ids = pd.merge(data[['sn_id', 'file_id']], sv_ids, on=['sn_id', 'file_id'])
data.insert(16, 'sv_id', sv_ids['sv_id'])


#####
# Sections

# Reformat for creating section ID
data['event_no'] = data['event_no'].astype(int).astype(str).str.zfill(4)

# Determine if each point is a change from...
data['date_same'] = data['date'].eq(data['date'].shift())  # ...one day to the next
data['leg_type_same'] = data['leg_type'].eq(data['leg_type'].shift())  # ...one leg type to another

# Create section IDs
data.loc[(  # entries where...
        ~data['date_same']  # ...the date changes...
        | ~data['leg_type_same']  # ...or the leg type changes...
        | data['leg_stage'].isin([1, 4])  # ...or a line begins or resumes...
        | ~data['on_off_same']  # ...or the survey changes from ON to OFF or vice versa...
),  # ...mark a new section and so...
    'section_id'] = data['file_id'] + '_' + data['date'] + '_' + data['event_no']  # ...get a section ID
data['section_id'] = data['section_id'].ffill()  # remaining entries get the section ID of the first entry
data.insert(5, 'section_id', data.pop('section_id'))  # relocate section ID column

# Remove same columns
data.drop(['date_same', 'leg_type_same', 'on_off_same'], axis=1, inplace=True)

# Reformat data types
data['leg_stage'] = data['leg_stage'].fillna(0)
for col in ['platform', 'leg_type', 'leg_stage', 'vis', 'bss']:
    data[col] = data[col].astype(int)
data.insert(6, 'leg_ts', '')
data['leg_ts'] = 'T' + data['leg_type'].astype(str) + 'S' + data['leg_stage'].astype(str)


#####
# Output
data.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_ON_se.csv', index=False)


#####
# Sightings

# Keep only sightings
sightings = data.copy().dropna(subset='sp_code')

# Output
sightings.to_csv(data_folder + 'BOF_MSOM/BOF_sesienv/b_onoff/BOF_ON_si.csv', index=False)

#####
# Imports
from BOF_MSOM.BOF_sesienv.__setup import *

#####
# Input data
data = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sesienv/__raw/BOF_data.csv',
                   usecols=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9,  # only load the necessary columns
                            10, 11, 12, 13, 14, 15, 18, 19,
                            20, 21, 22,
                            42, 43, 44, 45],
                   na_values=('.', ' .', '  .', '   .', '    .', '     .'),
                   # header=None,
                   # on_bad_lines='skip',
                   engine='python'
                   )

# Remove dud last row
# print(data.iloc[-1:])
# data = data.iloc[:-1]

# Downcast float and integer columns to most efficient data type
float_cols = data.select_dtypes('float').columns
integer_cols = data.select_dtypes('integer').columns
data.loc[:, float_cols] = data[float_cols].apply(pd.to_numeric, downcast='float')
data.loc[:, integer_cols] = data[integer_cols].apply(pd.to_numeric, downcast='integer')

#####
# Rename, reformat, rearrange

# Rename columns
data.columns = ['file_id', 'event_no', 'month', 'day', 'year', 'time', 'lat', 'lon',
                'leg_type', 'leg_stage',
                'alt', 'heading', 'wx', 'cloud', 'vis', 'bss',
                'si_no', 'sp_code', 'sp_rel', 'no', 'no_conf',
                # 'beh01', 'beh02', 'beh03', 'beh04', 'beh05',
                # 'beh06', 'beh07', 'beh08', 'beh09', 'beh10',
                # 'beh11', 'beh12', 'beh13', 'beh14', 'beh15',
                'survey_type', 'platform', 'dd_source', 'id_source']

# # Concatenate behaviour columns into one
# data['beh'] = [[str(int(b)).zfill(2) for b in row if b == b]
#                for row in data[['beh01', 'beh02', 'beh03']].values.tolist()]
# data['beh'] = [';'.join(map(str, i)) for i in data['beh']]

# Rearrange columns
data = data[['file_id', 'survey_type', 'platform', 'dd_source', 'id_source',  # source
             'leg_type', 'leg_stage',  # survey
             'year', 'month', 'day', 'time',  # datetime
             'lat', 'lon',  # location
             'event_no', 'si_no',  # event identifiers
             'sp_code', 'sp_rel',  # sighting data (species)
             'no', 'no_conf',  # 'no_calves', 'beh',  # sighting data (number and behaviour)
             'heading', 'alt', 'wx', 'cloud', 'vis', 'bss',  # environmental data
             ]]

# Restrict to shipboard surveys (remove opportunistic data)
data = data[data['survey_type'] == 'shipbd']

# Restrict to Nereid
data = data[data['platform'] == 99]

#####
# Output
output_path = data_folder + 'BOF_MSOM/BOF_sesienv/a_downsized/BOF_all.csv'
data.to_csv(output_path, index=False)

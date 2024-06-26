from BOF_MSOM.BOF_sptm.__setup import *
from BOF_MSOM.BOF_sptm.__functions import *

#####
# Merge together various extracted data

# Get the spatiotemporal template
sptm = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/a_sptm/' + sp_name + '__' + tm_name + '.csv')

# Merge the survey effort
se = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/c_se/' + sp_name + '__' + tm_name + '_se.csv')
sptm = pd.merge(sptm, se[['year', 'sp_id', 'sn_id', 'sv_id', 'se_length']],
                on=['year', 'sp_id', 'sn_id', 'sv_id'],
                how='left')

# Merge the sightings
for si_fp in glob.glob(data_folder + 'BOF_MSOM/BOF_sptm/d_si/' + sp_name + '__' + tm_name + '_si_*.csv'):  # glob the file paths of the satellite data CSVs and loop through
    si = pd.read_csv(si_fp)
    sp = si_fp[-8:-4]
    si.rename(columns={'si_pa': sp}, inplace=True)
    sptm = pd.merge(sptm, si[['year', 'sp_id', 'sn_id', 'sv_id', sp]],
                    on=['year', 'sp_id', 'sn_id', 'sv_id'],
                    how='left')

# Merge the environmental data
env = pd.read_csv(data_folder + 'BOF_MSOM/BOF_sptm/e_env/' + sp_name + '__' + tm_name + '_env.csv')
sptm = pd.merge(sptm, env[['year', 'sp_id', 'sn_id', 'sv_id', 'bss']],
                on=['year', 'sp_id', 'sn_id', 'sv_id'],
                how='left')

# Output
sptm.to_csv(data_folder + 'BOF_MSOM/BOF_sptm/m_SDM/' + sp_name + '__' + tm_name + '.csv', index=False)

select
    {{ hash_key(['station_id']) }} as station_hk,
    station_id,
    min(dbt_valid_from) as load_ts,
    'irail.stations' as record_source
from {{ ref('snp_stations') }}
group by station_id

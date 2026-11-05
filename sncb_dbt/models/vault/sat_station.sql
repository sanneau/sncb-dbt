select
    {{ hash_key(['station_id']) }} as station_hk,
    station_name,
    longitude,
    latitude,
    dbt_valid_from as load_ts,
    'irail.stations' as record_source,
    {{ hash_key(['station_name', 'longitude', 'latitude']) }} as hash_diff
from {{ ref('snp_stations') }}

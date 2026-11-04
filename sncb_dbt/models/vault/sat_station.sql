SELECT
    {{ hash_key(['station_id']) }} AS station_hk,
    station_name,
    longitude,
    latitude,
    dbt_valid_from AS load_ts,
    'irail.stations' AS record_source,
    {{ hash_key(['station_name', 'longitude', 'latitude']) }} AS hash_diff
FROM {{ ref('snp_stations') }}
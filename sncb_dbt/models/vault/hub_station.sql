SELECT 
    {{ hash_key(['station_id']) }} AS station_hk,
    station_id,
    min(dbt_valid_from) AS load_ts,
    'irail.stations' AS record_source
FROM {{ ref('snp_stations') }}
GROUP BY station_id
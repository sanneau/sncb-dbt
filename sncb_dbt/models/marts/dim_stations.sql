{{ config(materialized='table') }}
SELECT 
    {{ dbt_utils.generate_surrogate_key(['station_id']) }} AS station_key,
    station_id,
    station_name,
    longitude,
    latitude
FROM {{ ref('stg_stations') }}
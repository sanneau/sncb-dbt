{{
    config(
        materialized='incremental',
        unique_key=['departure_station_id', 'vehicle_id', 'scheduled_at'],
        incremental_strategy='delete+insert'
    )
}}
SELECT 
    {{ dbt_utils.generate_surrogate_key(['departure_station_id']) }} AS departure_station_key,
    {{ dbt_utils.generate_surrogate_key(['destination_station_id']) }} AS destination_station_key,
    departure_station_id, 
    vehicle_id, 
    scheduled_at, 
    destination_station_id,
    delay_seconds,
    delay_minutes,
    train_type,
    platform,
    platform_changed,
    canceled,
    collected_at,
    collection_date_utc
FROM {{ ref('stg_departures') }}
{% if is_incremental() %}
WHERE collection_date_utc >= (SELECT MAX(collection_date_utc) FROM {{ this }})
{% endif %}
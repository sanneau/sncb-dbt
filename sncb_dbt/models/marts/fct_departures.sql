{{
    config(
        materialized='incremental',
        unique_key=['departure_station_id', 'vehicle_id', 'scheduled_at'],
        incremental_strategy='delete+insert'
    )
}}
SELECT 
    dep_st.station_key AS departure_station_key,
    dest_st.station_key AS destination_station_key,
    d.departure_station_id, 
    d.vehicle_id, 
    d.scheduled_at AS scheduled_at, 
    d.destination_station_id,
    d.delay_seconds,
    d.delay_minutes,
    d.train_type,
    d.platform,
    d.platform_changed,
    d.canceled,
    d.collected_at,
    d.collection_date_utc
FROM {{ ref('stg_departures') }} AS d
LEFT JOIN {{ ref('dim_stations') }} AS dep_st
    ON d.departure_station_id = dep_st.station_id AND  dep_st.valid_from <= d.scheduled_at AND d.scheduled_at < dep_st.valid_to
LEFT JOIN {{ ref('dim_stations') }} AS dest_st
    ON d.destination_station_id = dest_st.station_id AND dest_st.valid_from <= d.scheduled_at AND d.scheduled_at < dest_st.valid_to
{% if is_incremental() %}
WHERE d.collection_date_utc >= (SELECT MAX(collection_date_utc) FROM {{ this }})
{% endif %}
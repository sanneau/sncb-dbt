{{
    config(
        materialized='incremental',
        unique_key=['departure_station_id', 'vehicle_id', 'scheduled_at'],
        incremental_strategy='delete+insert'
    )
}}
select
    dep_st.station_key as departure_station_key,
    dest_st.station_key as destination_station_key,
    d.departure_station_id,
    d.vehicle_id,
    d.scheduled_at as scheduled_at,
    d.destination_station_id,
    d.delay_seconds,
    d.delay_minutes,
    d.train_type,
    d.platform,
    d.platform_changed,
    d.canceled,
    d.collected_at,
    d.collection_date_utc
from {{ ref('stg_departures') }} as d
left join
    {{ ref('dim_stations') }} as dep_st
    on d.departure_station_id = dep_st.station_id
    and dep_st.valid_from <= d.scheduled_at
    and d.scheduled_at < dep_st.valid_to
left join
    {{ ref('dim_stations') }} as dest_st
    on d.destination_station_id = dest_st.station_id
    and dest_st.valid_from <= d.scheduled_at
    and d.scheduled_at < dest_st.valid_to
{% if is_incremental() %}
    where
        d.collection_date_utc
        >= (select max(collection_date_utc) from {{ this }}) - interval '3 days'
{% endif %}

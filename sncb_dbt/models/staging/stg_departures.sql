-- Station names are not kept: they come from stg_stations (single source of truth, no duplicated data)
-- occupancy is not kept: not useful for the analyses
-- The first 3 columns are the grain (one row = one departure)
SELECT
    departure_station_id,
    vehicle_id,
    scheduled_at,
    destination_station_id,
    snapshot_at AS collected_at,
    delay_s AS delay_seconds,
    delay_s / 60.0 as delay_minutes,
    train_type,
    platform,
    platform_changed,
    canceled,
    is_extra, 
    source_file,
    date AS collection_date_utc
FROM {{ source('silver', 'departures') }}
-- The silver job works one day at a time: a departure collected just before and just after
-- midnight UTC is in 2 partitions. Keep only its latest collection (most up-to-date delay). See ADR 002.
QUALIFY row_number() OVER (
    PARTITION BY departure_station_id, vehicle_id, scheduled_at
    ORDER BY snapshot_at DESC
) = 1
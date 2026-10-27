{{ config(materialized='table') }}

SELECT 
    sta.station_name AS station_name,
    dep.departure_station_key AS station_key, 
    count(*) AS number_of_departures, 
    ROUND(AVG(delay_minutes) FILTER (WHERE dep.canceled = false) , 2) AS avg_delay_minutes,
    ROUND(
        100 * count(*) FILTER (WHERE dep.delay_seconds = 0 AND NOT dep.canceled)
            / NULLIF(count(*) FILTER (WHERE NOT dep.canceled), 0),
        2
    ) AS on_time_percentage,
    count(*) FILTER (WHERE dep.canceled = true ) AS number_of_cancellations
FROM {{ ref('fct_departures') }} AS dep
JOIN {{ ref('dim_stations') }} as sta
ON  dep.departure_station_key = sta.station_key
GROUP BY dep.departure_station_key, station_name
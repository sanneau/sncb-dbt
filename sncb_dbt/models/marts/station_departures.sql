{{ config(materialized='table',enabled=false) }}
SELECT s.station_id as station_id,
	   count(*) as number_departures,
	   s.station_name as station_name
FROM {{ source('irail', 'fact_departure') }} AS f
JOIN {{ source('irail', 'dim_station') }} AS d ON f.departure_station_key = d.station_key
JOIN {{ ref('stg_stations') }} AS s ON d.station_id = s.station_id
GROUP BY s.station_id, s.station_name
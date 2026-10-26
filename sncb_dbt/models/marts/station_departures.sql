{{ config(materialized='table') }}

SELECT d.station_id as station_id,
	   count(*) as number_departures,
	   d.station_name as station_name
FROM {{ ref('fct_departures') }} AS f
JOIN {{ ref('dim_stations') }} AS d ON f.departure_station_key = d.station_key
GROUP BY d.station_id, d.station_name
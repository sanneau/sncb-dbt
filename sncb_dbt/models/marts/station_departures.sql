SELECT f.departure_station_id as station_id,
	   count(*) as number_departures,
	   d.station_name as station_name
FROM {{ ref('fct_departures') }} AS f
JOIN {{ ref('dim_stations') }} AS d ON f.departure_station_id = d.station_id AND d.is_current
GROUP BY f.departure_station_id, d.station_name

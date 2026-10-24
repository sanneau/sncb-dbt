SELECT  station_id, standard_name AS station_name, longitude, latitude
FROM {{ source('irail', 'stg_station') }}
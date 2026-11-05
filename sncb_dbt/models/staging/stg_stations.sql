select station_id, standard_name as station_name, longitude, latitude
from {{ source('silver', 'stations') }}

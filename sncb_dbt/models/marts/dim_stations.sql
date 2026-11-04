WITH versions AS (
    SELECT
        *,
        row_number() OVER (PARTITION BY station_id ORDER BY dbt_valid_from ASC) AS version_number
    FROM {{ ref('snp_stations') }}
)
SELECT 
    {{ dbt_utils.generate_surrogate_key(['station_id','dbt_valid_from']) }} AS station_key,
    station_id,
    station_name,
    longitude,
    latitude,
    CASE
        WHEN version_number = 1 THEN '1900-01-01 00:00:00'::timestamp
        ELSE dbt_valid_from 
    END AS valid_from,
    dbt_valid_to AS valid_to,
    CASE
        WHEN dbt_valid_to = '9999-12-31 00:00:00'::timestamp THEN TRUE
        ELSE FALSE
    END AS is_current
FROM versions
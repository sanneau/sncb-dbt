-- The hole in the night are artefacts because collected at is equal to the last collect of each departures. for the real stops, check the bronze.
WITH time_table AS (
    SELECT DISTINCT collected_at::timestamptz AS collected_at FROM {{ ref('stg_departures') }}
)
, previous_time AS (
    SELECT  collected_at , LAG(collected_at) OVER (ORDER BY collected_at) AS previous_at FROM time_table
)
SELECT  collected_at - previous_at AS gap, previous_at, collected_at FROM previous_time
where collected_at - previous_at > '00:15:00'::interval and previous_at >= TIMESTAMPTZ '2026-10-23 00:00:00+00'
ORDER BY gap DESC
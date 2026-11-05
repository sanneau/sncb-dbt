-- The hole in the night are artefacts because collected at is equal to the last
-- collect of each departures. for the real stops, check the bronze.
with
    time_table as (
        select distinct collected_at::timestamptz as collected_at
        from {{ ref('stg_departures') }}
    ),
    previous_time as (
        select
            collected_at, lag(collected_at) over (order by collected_at) as previous_at
        from time_table
    )
select collected_at - previous_at as gap, previous_at, collected_at
from previous_time
where
    collected_at - previous_at > '00:15:00'::interval
    and previous_at >= timestamptz '2026-10-23 00:00:00+00'
order by gap desc

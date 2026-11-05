select
    sta.station_name as station_name,
    dep.departure_station_id as station_id,
    count(*) as number_of_departures,
    round(
        avg(delay_minutes) filter (where dep.canceled = false), 2
    ) as avg_delay_minutes,
    round(
        100
        * count(*) filter (where dep.delay_seconds = 0 and not dep.canceled)
        / nullif(count(*) filter (where not dep.canceled), 0),
        2
    ) as on_time_percentage,
    count(*) filter (where dep.canceled = true) as number_of_cancellations
from {{ ref('fct_departures') }} as dep
join
    {{ ref('dim_stations') }} as sta
    on dep.departure_station_id = sta.station_id
    and sta.is_current
group by dep.departure_station_id, sta.station_name

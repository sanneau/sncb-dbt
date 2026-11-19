select
    hour(scheduled_at at time zone 'Europe/Brussels') as local_hour,
    count(*) filter (where not canceled) as departures_not_canceled,
    round(avg(delay_minutes) filter (where not canceled), 1) as moy_retard_minutes,
    round(
        100.0 * (
            count(*) filter (where not canceled and delay_seconds = 0)
            / nullif(count(*) filter (where not canceled), 0)
        ),
        2
    ) as on_time_percentage,
    count(*) filter (where canceled) as number_of_cancellations
from {{ ref('fct_departures') }}
group by hour(scheduled_at at time zone 'Europe/Brussels')
order by local_hour

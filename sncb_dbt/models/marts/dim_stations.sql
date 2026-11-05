with
    versions as (
        select
            *,
            row_number() over (
                partition by station_id order by dbt_valid_from asc
            ) as version_number
        from {{ ref('snp_stations') }}
    )
select
    {{ dbt_utils.generate_surrogate_key(['station_id','dbt_valid_from']) }}
    as station_key,
    station_id,
    station_name,
    longitude,
    latitude,
    case
        when version_number = 1
        then '1900-01-01 00:00:00'::timestamp
        else dbt_valid_from
    end as valid_from,
    dbt_valid_to as valid_to,
    case
        when dbt_valid_to = '9999-12-31 00:00:00'::timestamp then true else false
    end as is_current
from versions

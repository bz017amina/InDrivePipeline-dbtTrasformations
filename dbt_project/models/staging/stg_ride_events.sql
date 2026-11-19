-- var('start_date') est défini dans dbt_project.yml et peut être surchargé à la volée :
-- dbt run --vars '{"start_date": "2026-09-01"}'

select
    event_id,
    ride_id,
    driver_id,
    vehicle_id,
    pickup_zone_id,
    dropoff_zone_id,
    lower(trim(event_type)) as event_type,
    proposed_fare_mad::numeric(10, 2) as proposed_fare_mad,
    agreed_fare_mad::numeric(10, 2) as agreed_fare_mad,
    (agreed_fare_mad - proposed_fare_mad)::numeric(10, 2) as fare_negotiation_diff_mad,
    distance_km::numeric(6, 2) as distance_km,
    event_timestamp::timestamp as event_timestamp,
    event_timestamp::date as event_date
from {{ source('raw', 'raw_ride_events') }}
where event_timestamp >= '{{ var("start_date") }}'
{{ config(materialized='table') }}

with events as (
    select * from {{ ref('int_ride_events_enriched') }}
)

select
    ride_id,
    max(driver_id) as driver_id,
    max(driver_sk) as driver_sk,
    max(driver_name) as driver_name,
    max(vehicle_id) as vehicle_id,
    max(pickup_zone_id) as pickup_zone_id,
    max(dropoff_zone_id) as dropoff_zone_id,
    max(event_date) as ride_date,
    min(event_timestamp) as requested_at,
    max(event_timestamp) as last_event_at,
    max(proposed_fare_mad) as proposed_fare_mad,
    max(agreed_fare_mad) as agreed_fare_mad,
    max(fare_negotiation_diff_mad) as fare_negotiation_diff_mad,
    max(distance_km) as distance_km,
    case
        when bool_or(event_type = 'completed') then 'completed'
        when bool_or(event_type = 'cancelled') then 'cancelled'
        else 'in_progress'
    end as final_status
from events
group by ride_id
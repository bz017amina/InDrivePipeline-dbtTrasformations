{{ config(materialized='ephemeral') }}

with events as (
    select * from {{ ref('stg_ride_events') }}
),

current_drivers as (
    select *
    from {{ ref('snap_drivers') }}
    where dbt_valid_to is null
),

vehicles as (
    select * from {{ ref('stg_vehicles') }}
)

select
    e.event_id,
    e.ride_id,
    e.driver_id,
    d.dbt_scd_id as driver_sk,
    d.driver_name,
    d.rating as current_driver_rating,
    e.vehicle_id,
    v.make as vehicle_make,
    v.model as vehicle_model,
    v.vehicle_type,
    e.pickup_zone_id,
    e.dropoff_zone_id,
    e.event_type,
    e.proposed_fare_mad,
    e.agreed_fare_mad,
    e.fare_negotiation_diff_mad,
    e.distance_km,
    e.event_timestamp,
    e.event_date
from events e
left join current_drivers d
    on e.driver_id = d.driver_id
left join vehicles v
    on e.vehicle_id = v.vehicle_id
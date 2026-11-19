{{ config(materialized='table') }}

with daily_driver_earnings as (
    select
        driver_id,
        driver_name,
        ride_date,
        count(ride_id) as total_completed_rides,
        coalesce(sum(agreed_fare_mad), 0) as daily_revenue_mad
    from {{ ref('fact_rides') }}
    where final_status = 'completed'
    group by 1, 2, 3
)

select
    driver_id,
    driver_name,
    ride_date,
    total_completed_rides,
    daily_revenue_mad,
    sum(daily_revenue_mad) over (
        partition by driver_id
        order by ride_date
        rows between unbounded preceding and current row
    ) as cumulative_revenue_mad,
    dense_rank() over (
        partition by ride_date
        order by daily_revenue_mad desc
    ) as daily_revenue_rank
from daily_driver_earnings
order by ride_date, daily_revenue_rank
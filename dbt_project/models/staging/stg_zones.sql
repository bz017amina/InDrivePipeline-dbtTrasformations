select
    zone_id::integer as zone_id,
    zone_name,
    city
from {{ source('raw', 'raw_zones') }}
select
    customer_id,
    customer_natural_key,
    first_name,
    last_name,
    email,
    phone,
    country_code,
    created_at,
    marketing_opt_in,
    loyalty_tier,
    lifetime_value
from {{ source('raw', 'customers') }}

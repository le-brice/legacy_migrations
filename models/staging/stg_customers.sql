with source as (
    select * from {{ ref('raw_customer') }}
),

renamed as (
    select
        cast(customer_id as string) as customer_id,
        cast(first_name as string) as first_name,
        cast(last_name as string) as last_name,
        cast(email as string) as email,
        upper(cast(country as string)) as country,
        lower(cast(signup_channel as string)) as signup_channel,
        cast(signup_date as date) as signup_date,
        cast(is_active as bool) as is_active
    from source
)

select *
from renamed

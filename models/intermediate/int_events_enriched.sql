with events as (
    select * from {{ ref('raw_events') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

joined as (
    select
        cast(events.event_id as string) as event_id,
        cast(events.customer_id as string) as customer_id,
        case lower(cast(events.event_type as string))
            when 'page_view' then 'browse'
            when 'add_to_cart' then 'conversion_intent'
            when 'checkout_start' then 'checkout'
            when 'purchase' then 'purchase'
            when 'signup' then 'acquisition'
            else 'other'
        end as normalized_event_type,
        lower(cast(events.event_type as string)) as event_type,
        cast(events.event_timestamp as timestamp) as event_timestamp,
        cast(events.channel as string) as event_channel,
        cast(events.category as string) as product_category,
        cast(events.device as string) as device,
        customers.email as customer_email,
        customers.country as customer_country,
        customers.signup_channel,
        customers.signup_date,
        customers.is_active as customer_is_active
    from events
    left join customers
        on cast(events.customer_id as string) = customers.customer_id
)

select *
from joined

{{ config(materialized='table') }}

with orders_standardized as (
    select
        order_id,
        customer_id,
        cast(order_date as date) as order_day,
        order_date,
        order_status,
        case
            when trim(currency_code) is null or trim(currency_code) = '' then 'USD'
            when upper(trim(currency_code)) in ('USD', 'US$') then 'USD'
            when upper(trim(currency_code)) = 'EUR' then 'EUR'
            when upper(trim(currency_code)) = 'GBP' then 'GBP'
            when upper(trim(currency_code)) = 'MXN' then 'MXN'
            else upper(trim(currency_code))
        end as latest_currency_code,
        total_amount,
        discount_amount
    from {{ ref('stg_orders') }}
), joined as (
    select
        c.canonical_customer_id,
        c.customer_natural_key,
        c.full_name_clean,
        c.email_clean,
        c.country_code,
        c.loyalty_tier_clean,
        c.customer_segment,
        o.order_id,
        o.order_day,
        o.order_date,
        o.order_status,
        o.latest_currency_code,
        o.total_amount,
        o.discount_amount
    from {{ ref('customer_clean') }} c
    inner join orders_standardized o
        on c.canonical_customer_id = o.customer_id
), latest_currency as (
    select
        canonical_customer_id,
        order_day,
        latest_currency_code,
        row_number() over (
            partition by canonical_customer_id, order_day
            order by order_date desc, order_id desc
        ) as rn
    from joined
)
select
    j.canonical_customer_id,
    j.customer_natural_key,
    j.full_name_clean,
    j.email_clean,
    j.country_code,
    j.loyalty_tier_clean,
    j.customer_segment,
    j.order_day,
    count(*) as order_count,
    count_if(j.order_status = 'completed') as completed_order_count,
    count_if(j.order_status = 'cancelled') as cancelled_order_count,
    count_if(j.order_status = 'returned') as returned_order_count,
    count_if(j.order_status = 'pending') as pending_order_count,
    sum(j.total_amount) as gross_revenue_amount,
    sum(case when j.order_status = 'completed' then j.total_amount else 0 end) as completed_revenue_amount,
    sum(j.discount_amount) as discount_amount,
    max(case when lc.rn = 1 then lc.latest_currency_code end) as latest_currency_code
from joined j
left join latest_currency lc
    on j.canonical_customer_id = lc.canonical_customer_id
   and j.order_day = lc.order_day
group by 1,2,3,4,5,6,7,8

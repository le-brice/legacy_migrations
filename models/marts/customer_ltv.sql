{{ config(materialized='table') }}

with customer_rollup as (
    select
        canonical_customer_id,
        min(customer_natural_key) as customer_natural_key,
        min(full_name_clean) as full_name_clean,
        min(email_clean) as email_clean,
        min(country_code) as country_code,
        min(loyalty_tier_clean) as loyalty_tier_clean,
        min(customer_segment) as customer_segment,
        count(distinct order_day) as active_days,
        sum(order_count) as lifetime_order_count,
        sum(completed_order_count) as lifetime_completed_order_count,
        sum(gross_revenue_amount) as lifetime_gross_revenue,
        sum(completed_revenue_amount) as lifetime_completed_revenue,
        sum(discount_amount) as lifetime_discount_amount,
        avg(completed_revenue_amount) as avg_daily_completed_revenue
    from {{ ref('daily_order_summary') }}
    group by 1
)

select
    r.canonical_customer_id,
    r.customer_natural_key,
    r.full_name_clean,
    r.email_clean,
    r.country_code,
    r.loyalty_tier_clean,
    r.customer_segment,
    m.multiplier as applied_multiplier,
    r.active_days,
    r.lifetime_order_count,
    r.lifetime_completed_order_count,
    r.lifetime_gross_revenue,
    r.lifetime_completed_revenue,
    r.lifetime_discount_amount,
    r.avg_daily_completed_revenue,
    round(r.lifetime_completed_revenue * m.multiplier, 2) as ltv_score,
    case
        when round(r.lifetime_completed_revenue * m.multiplier, 2) >= 1000 then 'platinum'
        when round(r.lifetime_completed_revenue * m.multiplier, 2) >= 500 then 'gold'
        when round(r.lifetime_completed_revenue * m.multiplier, 2) >= 150 then 'silver'
        else 'bronze'
    end as ltv_band
from customer_rollup r
left join {{ ref('ltv_multiplier_ref') }} m
    on r.customer_segment = m.customer_segment

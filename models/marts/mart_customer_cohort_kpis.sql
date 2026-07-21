{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('raw_orders') }}
),

valid_orders as (
    select
        cast(order_id as string) as order_id,
        cast(customer_id as string) as customer_id,
        cast(order_date as date) as order_date,
        lower(cast(status as string)) as order_status,
        cast(category as string) as category,
        cast(amount_eur as numeric) as amount_eur,
        cast(discount_eur as numeric) as discount_eur,
        cast(amount_eur as numeric) - cast(discount_eur as numeric) as net_amount_eur
    from orders
    where lower(cast(status as string)) not in ('cancelled', 'refunded')
),

cohort_customers as (
    select
        customer_id,
        date_trunc(signup_date, month) as signup_cohort_month,
        country
    from customers
),

cohort_sizes as (
    select
        signup_cohort_month,
        country,
        count(distinct customer_id) as customers_in_cohort
    from cohort_customers
    group by 1, 2
),

cohort_orders as (
    select
        cohort_customers.signup_cohort_month,
        cohort_customers.country,
        count(distinct valid_orders.order_id) as order_count,
        count(distinct valid_orders.customer_id) as customers_with_orders,
        sum(valid_orders.net_amount_eur) as total_revenue_eur
    from cohort_customers
    left join valid_orders
        on cohort_customers.customer_id = valid_orders.customer_id
    group by 1, 2
)

select
    cohort_sizes.signup_cohort_month,
    cohort_sizes.country,
    cohort_sizes.customers_in_cohort,
    coalesce(cohort_orders.customers_with_orders, 0) as customers_with_orders,
    coalesce(cohort_orders.order_count, 0) as order_count,
    coalesce(cohort_orders.total_revenue_eur, 0) as total_revenue_eur,
    safe_divide(coalesce(cohort_orders.total_revenue_eur, 0), cohort_sizes.customers_in_cohort) as ltv_eur,
    safe_divide(coalesce(cohort_orders.order_count, 0), cohort_sizes.customers_in_cohort) as orders_per_customer
from cohort_sizes
left join cohort_orders
    on cohort_sizes.signup_cohort_month = cohort_orders.signup_cohort_month
   and cohort_sizes.country = cohort_orders.country

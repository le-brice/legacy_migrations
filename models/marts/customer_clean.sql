{{ config(materialized='table') }}

with normalized as (
    select
        customer_id,
        customer_natural_key,
        initcap(trim(first_name)) as first_name_clean,
        initcap(trim(last_name)) as last_name_clean,
        case
            when trim(first_name) is not null and trim(last_name) is not null
                then initcap(trim(first_name)) || ' ' || initcap(trim(last_name))
            else null
        end as full_name_clean,
        lower(trim(email)) as email_clean,
        trim(phone) as phone_clean,
        upper(trim(country_code)) as country_code,
        created_at,
        marketing_opt_in,
        coalesce(nullif(lower(trim(loyalty_tier)), ''), 'bronze') as loyalty_tier_clean,
        coalesce(lifetime_value, 0) as lifetime_value,
        case
            when coalesce(lifetime_value, 0) >= 1000 then 'vip'
            when coalesce(lifetime_value, 0) >= 300 then 'growth'
            else 'standard'
        end as customer_segment,
        case
            when nullif(lower(trim(email)), '') is not null then lower(trim(email))
            else soundex(initcap(trim(first_name))) || '_' || soundex(initcap(trim(last_name)))
        end as dedupe_key
    from {{ ref('stg_customers') }}
), ranked as (
    select
        *,
        count(*) over (partition by dedupe_key) as duplicate_record_count,
        row_number() over (
            partition by dedupe_key
            order by lifetime_value desc, created_at asc, customer_id asc
        ) as dedupe_rank
    from normalized
)
select
    customer_id as canonical_customer_id,
    customer_natural_key,
    first_name_clean,
    last_name_clean,
    full_name_clean,
    email_clean,
    phone_clean,
    country_code,
    created_at,
    marketing_opt_in,
    loyalty_tier_clean,
    lifetime_value,
    customer_segment,
    duplicate_record_count
from ranked
where dedupe_rank = 1

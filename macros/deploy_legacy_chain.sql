{% macro deploy_legacy_chain() %}
  {% set sql %}
    create schema if not exists DBT_SANDBOX_BRICE.LEGACY_PROD;

    create or replace procedure DBT_SANDBOX_BRICE.LEGACY_PROD.run_legacy_chain()
    returns varchar
    language sql
    execute as caller
    as
    $$
    declare
      v_customer_clean_rows number;
      v_daily_summary_rows number;
      v_customer_ltv_rows number;
    begin
      create or replace table DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean as
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
          coalesce(lifetime_value, 0) as lifetime_value_clean,
          case
            when coalesce(lifetime_value, 0) >= 1000 then 'vip'
            when coalesce(lifetime_value, 0) >= 300 then 'growth'
            else 'standard'
          end as customer_segment,
          case
            when nullif(lower(trim(email)), '') is not null then lower(trim(email))
            else soundex(initcap(trim(first_name))) || '_' || soundex(initcap(trim(last_name)))
          end as dedupe_key
        from dbt_blepoutre_RAW.customers
      ), ranked as (
        select
          *,
          count(*) over (partition by dedupe_key) as duplicate_record_count,
          row_number() over (
            partition by dedupe_key
            order by lifetime_value_clean desc, created_at asc, customer_id asc
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
        lifetime_value_clean as lifetime_value,
        customer_segment,
        duplicate_record_count
      from ranked
      where dedupe_rank = 1
      ;

      create or replace table DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary as
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
          end as currency_code_standardized,
          total_amount,
          discount_amount
        from dbt_blepoutre_RAW.orders
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
          o.currency_code_standardized,
          o.total_amount,
          o.discount_amount
        from DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean c
        inner join orders_standardized o
          on c.canonical_customer_id = o.customer_id
      ), latest_currency as (
        select
          canonical_customer_id,
          order_day,
          currency_code_standardized,
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
        max(case when lc.rn = 1 then lc.currency_code_standardized end) as latest_currency_code
      from joined j
      left join latest_currency lc
        on j.canonical_customer_id = lc.canonical_customer_id
       and j.order_day = lc.order_day
      group by 1,2,3,4,5,6,7,8
      ;

      create or replace table DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref (
        customer_segment varchar,
        multiplier number(10,2)
      );

      insert overwrite into DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref
      select 'standard', 1.00
      union all
      select 'growth', 1.15
      union all
      select 'vip', 1.35
      ;

      create or replace table DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv as
      with customer_rollup as (
        select
          canonical_customer_id,
          any_value(customer_natural_key) as customer_natural_key,
          any_value(full_name_clean) as full_name_clean,
          any_value(email_clean) as email_clean,
          any_value(country_code) as country_code,
          any_value(loyalty_tier_clean) as loyalty_tier_clean,
          any_value(customer_segment) as customer_segment,
          count(distinct order_day) as active_days,
          sum(order_count) as lifetime_order_count,
          sum(completed_order_count) as lifetime_completed_order_count,
          sum(gross_revenue_amount) as lifetime_gross_revenue,
          sum(completed_revenue_amount) as lifetime_completed_revenue,
          sum(discount_amount) as lifetime_discount_amount,
          avg(completed_revenue_amount) as avg_daily_completed_revenue
        from DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary
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
      left join DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref m
        on r.customer_segment = m.customer_segment
      ;

      select count(*) into :v_customer_clean_rows from DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean;
      select count(*) into :v_daily_summary_rows from DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary;
      select count(*) into :v_customer_ltv_rows from DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv;

      return 'SUCCESS customer_clean=' || v_customer_clean_rows || ', daily_order_summary=' || v_daily_summary_rows || ', customer_ltv=' || v_customer_ltv_rows;
    end;
    $$;
  {% endset %}

  {% do run_query(sql) %}
  {{ return('deployed') }}
{% endmacro %}


with customer_clean_status as (
    select
        'customer_clean' as comparison_name,
        'DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean' as legacy_relation,
        'customer_clean' as dbt_model,
        'row_level' as compare_mode,
        identical::varchar as status
    from (
        {{ audit_helper.quick_are_relations_identical(
            a_relation=ref('customer_clean'),
            b_relation=source('legacy_prod', 'customer_clean')
        ) }}
    )
), daily_order_summary_status as (
    select
        'daily_order_summary' as comparison_name,
        'DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary' as legacy_relation,
        'daily_order_summary' as dbt_model,
        'row_level' as compare_mode,
        identical::varchar as status
    from (
        {{ audit_helper.quick_are_relations_identical(
            a_relation=ref('daily_order_summary'),
            b_relation=source('legacy_prod', 'daily_order_summary')
        ) }}
    )
), customer_ltv_status as (
    select
        'customer_ltv' as comparison_name,
        'DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv' as legacy_relation,
        'customer_ltv' as dbt_model,
        'row_level' as compare_mode,
        identical::varchar as status
    from (
        {{ audit_helper.quick_are_relations_identical(
            a_relation=ref('customer_ltv'),
            b_relation=source('legacy_prod', 'customer_ltv')
        ) }}
    )
)

select * from customer_clean_status
union all
select * from daily_order_summary_status
union all
select * from customer_ltv_status

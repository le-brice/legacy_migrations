{% macro investigate_migration_validation(dbt_model, validation_schema=none, mapping_model='migration_comparison_mapping') %}

  {% if validation_schema is none %}
    {% set validation_schema = target.schema ~ '_validation' %}
  {% endif %}

  {% set mapping_query %}
    select
      legacy_relation,
      dbt_model,
      grain_key,
      coalesce(compare_mode, 'row_level') as compare_mode,
      coalesce(notes, '') as notes
    from {{ ref(mapping_model) }}
    where dbt_model = '{{ dbt_model }}'
  {% endset %}

  {% set mapping_result = run_query(mapping_query) %}

  {% if execute and mapping_result is not none and (mapping_result.rows | length) == 0 %}
    {% do exceptions.raise_compiler_error('No mapping found for dbt_model=' ~ dbt_model) %}
  {% endif %}

  {% set legacy_relation = mapping_result.rows[0][0] %}
  {% set grain_key = mapping_result.rows[0][2] %}
  {% set grain_columns = grain_key.split('|') %}
  {% set grain_csv = grain_columns | join(', ') %}

  {% set create_schema_sql %}
    create schema if not exists {{ target.database }}.{{ validation_schema }}
  {% endset %}
  {% do run_query(create_schema_sql) %}

  {% set create_detail_sql %}
    create or replace table {{ target.database }}.{{ validation_schema }}.validation_details_{{ dbt_model }} as
    with legacy_base as (
      select * from {{ legacy_relation }}
    ),
    dbt_base as (
      select * from {{ ref(dbt_model) }}
    ),
    legacy_grain as (
      select {{ grain_csv }}, count(*) as grain_count
      from legacy_base
      group by {{ grain_csv }}
    ),
    dbt_grain as (
      select {{ grain_csv }}, count(*) as grain_count
      from dbt_base
      group by {{ grain_csv }}
    ),
    grain_comparison as (
      select
        '{{ dbt_model }}' as dbt_model,
        '{{ legacy_relation }}' as legacy_relation,
        '{{ grain_key }}' as grain_key,
        {% for col in grain_columns %}
        coalesce(legacy_grain.{{ col }}, dbt_grain.{{ col }}) as {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %},
        legacy_grain.grain_count as legacy_grain_count,
        dbt_grain.grain_count as dbt_grain_count,
        case
          when legacy_grain.grain_count is null then 'missing_in_legacy'
          when dbt_grain.grain_count is null then 'missing_in_dbt'
          when legacy_grain.grain_count != dbt_grain.grain_count then 'grain_count_mismatch'
          else 'matched_grain'
        end as grain_status
      from legacy_grain
      full outer join dbt_grain
        on {% for col in grain_columns %}legacy_grain.{{ col }} = dbt_grain.{{ col }}{% if not loop.last %} and {% endif %}{% endfor %}
    )
    select * from grain_comparison
  {% endset %}
  {% do run_query(create_detail_sql) %}

  {% set summary_query %}
    with legacy_base as (
      select * from {{ legacy_relation }}
    ),
    dbt_base as (
      select * from {{ ref(dbt_model) }}
    ),
    legacy_grain as (
      select {{ grain_csv }}, count(*) as grain_count
      from legacy_base
      group by {{ grain_csv }}
    ),
    dbt_grain as (
      select {{ grain_csv }}, count(*) as grain_count
      from dbt_base
      group by {{ grain_csv }}
    )
    select
      '{{ dbt_model }}' as dbt_model,
      '{{ legacy_relation }}' as legacy_relation,
      '{{ grain_key }}' as grain_key,
      (select count(*) from legacy_base) as legacy_row_count,
      (select count(*) from dbt_base) as dbt_row_count,
      (select count(*) from legacy_grain) as legacy_distinct_grain_count,
      (select count(*) from dbt_grain) as dbt_distinct_grain_count,
      (select count(*) from legacy_grain where grain_count > 1) as legacy_duplicate_grain_count,
      (select count(*) from dbt_grain where grain_count > 1) as dbt_duplicate_grain_count,
      (select count(*) from {{ target.database }}.{{ validation_schema }}.validation_details_{{ dbt_model }} where grain_status != 'matched_grain') as non_matching_grain_rows
  {% endset %}

  {% set summary_result = run_query(summary_query) %}

  {% if execute and summary_result is not none %}
    {% set row = summary_result.rows[0] %}
    {% do log(dbt_model ~ ' investigation summary', info=True) %}
    {% do log('legacy_row_count=' ~ row[3] ~ ' | dbt_row_count=' ~ row[4], info=True) %}
    {% do log('legacy_distinct_grain_count=' ~ row[5] ~ ' | dbt_distinct_grain_count=' ~ row[6], info=True) %}
    {% do log('legacy_duplicate_grain_count=' ~ row[7] ~ ' | dbt_duplicate_grain_count=' ~ row[8], info=True) %}
    {% do log('non_matching_grain_rows=' ~ row[9], info=True) %}
    {% do log('detail rows written to ' ~ target.database ~ '.' ~ validation_schema ~ '.validation_details_' ~ dbt_model, info=True) %}
  {% endif %}

{% endmacro %}

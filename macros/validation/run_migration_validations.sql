{% macro run_migration_validations(validation_schema=none, mapping_model='migration_comparison_mapping') %}

  {% if validation_schema is none %}
    {% set validation_schema = target.schema ~ '_validation' %}
  {% endif %}

  {% set create_schema_sql %}
    create schema if not exists {{ target.database }}.{{ validation_schema }}
  {% endset %}
  {% do run_query(create_schema_sql) %}

  {% set create_table_sql %}
    create or replace table {{ target.database }}.{{ validation_schema }}.validation_summary (
      comparison_name varchar,
      legacy_relation varchar,
      dbt_model varchar,
      grain_key varchar,
      compare_mode varchar,
      legacy_row_count number,
      dbt_row_count number,
      row_count_match boolean,
      identical_flag boolean,
      status varchar,
      compared_at timestamp_ntz,
      notes varchar
    )
  {% endset %}
  {% do run_query(create_table_sql) %}

  {% set mappings_query %}
    select
      legacy_relation,
      dbt_model,
      grain_key,
      coalesce(compare_mode, 'row_level') as compare_mode,
      coalesce(notes, '') as notes
    from {{ ref(mapping_model) }}
  {% endset %}

  {% set mappings = run_query(mappings_query) %}

  {% if execute and mappings is not none and (mappings.rows | length) == 0 %}
    {% do exceptions.raise_compiler_error(
      'The validation mapping seed is empty. Populate seeds/' ~ mapping_model ~ '.csv before running validation.'
    ) %}
  {% endif %}

  {% if execute %}
    {% for row in mappings.rows %}
      {% set legacy_relation = row[0] %}
      {% set dbt_model = row[1] %}
      {% set grain_key = row[2] %}
      {% set compare_mode = row[3] %}
      {% set notes = row[4] %}
      {% set comparison_name = dbt_model %}

      {% set relation_parts = legacy_relation.split('.') %}
      {% if relation_parts | length != 3 %}
        {% do exceptions.raise_compiler_error('legacy_relation must be fully qualified as DATABASE.SCHEMA.IDENTIFIER. Got: ' ~ legacy_relation) %}
      {% endif %}

      {% set legacy_rel = api.Relation.create(
        database=relation_parts[0],
        schema=relation_parts[1],
        identifier=relation_parts[2]
      ) %}

      {% set identical_sql %}
        select are_tables_identical
        from (
          {{ audit_helper.quick_are_relations_identical(
              a_relation=ref(dbt_model),
              b_relation=legacy_rel
          ) }}
        ) audit_helper_result
      {% endset %}
      {% set identical_result = run_query(identical_sql) %}
      {% set identical_flag = identical_result.rows[0][0] %}

      {% set insert_sql %}
        insert into {{ target.database }}.{{ validation_schema }}.validation_summary (
          comparison_name,
          legacy_relation,
          dbt_model,
          grain_key,
          compare_mode,
          legacy_row_count,
          dbt_row_count,
          row_count_match,
          identical_flag,
          status,
          compared_at,
          notes
        )
        select
          '{{ comparison_name }}',
          '{{ legacy_relation }}',
          '{{ dbt_model }}',
          '{{ grain_key }}',
          '{{ compare_mode }}',
          legacy_counts.row_count,
          dbt_counts.row_count,
          legacy_counts.row_count = dbt_counts.row_count,
          {{ 'true' if identical_flag else 'false' }},
          '{{ 'identical' if identical_flag else 'different' }}',
          current_timestamp(),
          '{{ notes }}'
        from (
          select count(*) as row_count from {{ legacy_relation }}
        ) legacy_counts
        cross join (
          select count(*) as row_count from {{ ref(dbt_model) }}
        ) dbt_counts
      {% endset %}
      {% do run_query(insert_sql) %}
    {% endfor %}
  {% endif %}

  {% do log('Validation summary written to ' ~ target.database ~ '.' ~ validation_schema ~ '.validation_summary', info=True) %}

{% endmacro %}

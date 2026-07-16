{% macro run_migration_validations(mappings=none, validation_schema=none) %}

  {% if validation_schema is none %}
    {% set validation_schema = target.schema ~ '_validation' %}
  {% endif %}

  {% if mappings is none %}
    {% set mappings = var('migration_validation_mappings', []) %}
  {% endif %}

  {% if mappings | length == 0 %}
    {% do exceptions.raise_compiler_error(
      "No validation mappings were provided. Pass a `mappings` argument to run-operation or define `vars: migration_validation_mappings:` in dbt_project.yml."
    ) %}
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
      compare_mode varchar,
      legacy_row_count number,
      dbt_row_count number,
      row_count_match boolean,
      compared_at timestamp_ntz,
      notes varchar
    )
  {% endset %}
  {% do run_query(create_table_sql) %}

  {% for mapping in mappings %}
    {% set comparison_name = mapping.get('comparison_name', mapping['dbt_model']) %}
    {% set compare_mode = mapping.get('compare_mode', 'row_level') %}
    {% set notes = mapping.get('notes', '') %}

    {% set insert_sql %}
      insert into {{ target.database }}.{{ validation_schema }}.validation_summary (
        comparison_name,
        legacy_relation,
        dbt_model,
        compare_mode,
        legacy_row_count,
        dbt_row_count,
        row_count_match,
        compared_at,
        notes
      )
      select
        '{{ comparison_name }}',
        '{{ mapping['legacy_relation'] }}',
        '{{ mapping['dbt_model'] }}',
        '{{ compare_mode }}',
        legacy_counts.row_count,
        dbt_counts.row_count,
        legacy_counts.row_count = dbt_counts.row_count,
        current_timestamp(),
        '{{ notes }}'
      from (
        select count(*) as row_count from {{ mapping['legacy_relation'] }}
      ) legacy_counts
      cross join (
        select count(*) as row_count from {{ ref(mapping['dbt_model']) }}
      ) dbt_counts
    {% endset %}
    {% do run_query(insert_sql) %}
  {% endfor %}

  {% do log('Validation summary written to ' ~ target.database ~ '.' ~ validation_schema ~ '.validation_summary', info=True) %}

{% endmacro %}

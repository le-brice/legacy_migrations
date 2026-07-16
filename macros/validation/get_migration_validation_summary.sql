{% macro get_migration_validation_summary(validation_schema=none) %}

  {% if validation_schema is none %}
    {% set validation_schema = target.schema ~ '_validation' %}
  {% endif %}

  {% set query %}
    select
      comparison_name,
      legacy_relation,
      dbt_model,
      compare_mode,
      legacy_row_count,
      dbt_row_count,
      row_count_match,
      compared_at,
      notes
    from {{ target.database }}.{{ validation_schema }}.validation_summary
    order by comparison_name
  {% endset %}

  {% set results = run_query(query) %}

  {% if execute and results is not none %}
    {% for row in results.rows %}
      {% do log(
        row[0] ~ ' | legacy=' ~ row[4] ~ ' | dbt=' ~ row[5] ~ ' | row_count_match=' ~ row[6],
        info=True
      ) %}
    {% endfor %}
  {% endif %}

{% endmacro %}

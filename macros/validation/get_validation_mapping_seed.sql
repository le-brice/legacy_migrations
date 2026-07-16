{% macro get_validation_mapping_seed(mapping_model='migration_comparison_mapping') %}

  {% set query %}
    select
      legacy_relation,
      dbt_model,
      grain_key,
      compare_mode,
      notes
    from {{ ref(mapping_model) }}
    order by dbt_model
  {% endset %}

  {% set results = run_query(query) %}

  {% if execute and results is not none %}
    {% for row in results.rows %}
      {% do log(
        row[1] ~ ' | legacy_relation=' ~ row[0] ~ ' | grain_key=' ~ row[2] ~ ' | compare_mode=' ~ row[3],
        info=True
      ) %}
    {% endfor %}
  {% endif %}

{% endmacro %}

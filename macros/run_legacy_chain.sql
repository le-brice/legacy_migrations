{% macro run_legacy_chain() %}
  {% set sql %}
    call DBT_SANDBOX_BRICE.LEGACY_PROD.run_legacy_chain();
  {% endset %}

  {% set res = run_query(sql) %}
  {{ return(res) }}
{% endmacro %}


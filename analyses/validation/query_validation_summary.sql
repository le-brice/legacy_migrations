select *
from {{ target.database }}.{{ target.schema }}_validation.validation_summary
order by comparison_name

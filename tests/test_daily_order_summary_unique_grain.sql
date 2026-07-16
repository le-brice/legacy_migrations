select
    canonical_customer_id,
    order_day,
    count(*) as row_count
from {{ ref('daily_order_summary') }}
group by 1, 2
having count(*) > 1

select
    order_id,
    customer_id,
    order_date,
    order_status,
    currency_code,
    total_amount,
    discount_amount
from {{ source('raw', 'orders') }}

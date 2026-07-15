# Talend job mapping to legacy production tables

These Talend-like job exports mirror the stored procedure logic currently implemented for the demo.

| Job file | Source tables | Output table | Join key | Upstream dependency |
|---|---|---|---|---|
| `job_customer_dedup_and_clean.item` | `dbt_blepoutre_RAW.customers` | `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean` | Dedupe key = `email_clean` when present, else `soundex(initcap(trim(first_name))) || '_' || soundex(initcap(trim(last_name)))` | none |
| `job_daily_order_aggregation.item` | `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`, `dbt_blepoutre_RAW.orders` | `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary` | `customer_clean.canonical_customer_id = orders.customer_id` | `job_customer_dedup_and_clean.item` |
| `job_customer_ltv_scoring.item` | `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`, embedded lookup rows for multiplier creation | `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv` and `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref` | `customer_rollup.customer_segment = ltv_multiplier_ref.customer_segment` | `job_daily_order_aggregation.item` |

## Final legacy production tables

- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv`

## Notes

- The raw source references match the tables that were actually loaded in this environment: `dbt_blepoutre_RAW.*`.
- The final targets match the production-style schema created by the procedure: `DBT_SANDBOX_BRICE.LEGACY_PROD.*`.
- The LTV multiplier logic is intentionally embedded inline in the third job to keep that legacy smell visible for later migration discussions.

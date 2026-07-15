# Talend job mapping to legacy production tables

These Talend job exports now follow a governed migration convention: each job is described as a declarative component graph that can be translated into dbt staging models, intermediate models, marts, snapshots, macros, and seed-backed reference data.

## Conventions

- Treat each `.item` file as a metadata export of the Talend component graph, not as an executable SQL container.
- Preserve parity with the stored procedure business logic and target grains.
- Keep transformation intent in component metadata: inputs, expressions, filters, sorts, joins, ranking rules, aggregates, and outputs.
- Do not embed SQL in Talend components.
- Model reusable reference data, such as multipliers, as fixed-flow inputs that become dbt seeds.

## Job mapping

| Job file | Source tables | Output table | Component pattern | dbt projection |
|---|---|---|---|---|
| `job_customer_dedup_and_clean.item` | `dbt_blepoutre_RAW.customers` | `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean` | `tSnowflakeInput -> tMap -> tAggregateRow -> tSortRow -> tUniqRow -> tMap -> tSnowflakeOutput` | `stg_customers`, `int_customer_normalized`, `int_customer_duplicate_counts`, `int_customer_dedupe_ranked`, `customer_clean` |
| `job_daily_order_aggregation.item` | `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`, `dbt_blepoutre_RAW.orders` | `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary` | `tSnowflakeInput -> tMap -> tMap(join) -> tSortRow -> tUniqRow + tAggregateRow -> tMap -> tSnowflakeOutput` | `stg_orders`, `int_orders_standardized`, `int_customer_orders_joined`, `int_customer_day_latest_currency`, `daily_order_summary` |
| `job_customer_ltv_scoring.item` | `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`, fixed multiplier reference rows | `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref`, `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv` | `tSnowflakeInput -> tAggregateRow -> tMap(join lookup) -> tMap -> tSnowflakeOutput` plus `tFixedFlowInput -> tSnowflakeOutput` | `ltv_multiplier_ref` seed, `int_customer_ltv_rollup`, `customer_ltv` |

## Final legacy production tables

- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv`

## Notes

- The raw source references match the tables loaded in this environment: `dbt_blepoutre_RAW.*`.
- The final targets still match the production-style schema created by the legacy procedure: `DBT_SANDBOX_BRICE.LEGACY_PROD.*`.
- The old inline SQL implementation has been removed from the Talend exports; the files now describe graph structure and transformation intent only.
- The multiplier reference remains explicit, but it is represented as governed reference data suitable for a dbt seed.

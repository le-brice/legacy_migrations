# Legacy migration spec: synthetic e-commerce chain

This document is the exact business specification that the legacy Talend-style job must replicate.

## Source tables

The chained process reads from:

- `DBT_SANDBOX_BRICE.RAW.customers`
- `DBT_SANDBOX_BRICE.RAW.orders`

It writes to:

- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref`
- `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv`

## Step 1: `job_customer_dedup_and_clean`

Purpose: create one cleaned customer row per logical person from raw customer records that may contain nulls, inconsistent casing, and near-duplicate spellings.

Exact logic:

1. Read all rows from `DBT_SANDBOX_BRICE.RAW.customers`.
2. Normalize customer names:
   - Trim leading and trailing whitespace.
   - Convert `first_name` and `last_name` to proper case using init-cap style casing.
   - Build `full_name_clean` as `first_name_clean || ' ' || last_name_clean` when both are present.
3. Normalize email and phone:
   - Lowercase and trim `email` into `email_clean`.
   - Trim `phone` into `phone_clean`.
4. Normalize loyalty tier:
   - Lowercase and trim the raw `loyalty_tier`.
   - If null or blank, replace with `bronze`.
5. Derive customer segment from lifetime value:
   - If `lifetime_value >= 1000`, segment = `vip`.
   - Else if `lifetime_value >= 300`, segment = `growth`.
   - Else segment = `standard`.
   - If `lifetime_value` is null, treat it as `0` for segmentation.
6. Collapse duplicates using a fuzzy name + email rule:
   - Define a dedupe key as:
     - `email_clean` when email is present.
     - Otherwise, `soundex(first_name_clean) || '_' || soundex(last_name_clean)`.
   - Records with the same dedupe key are considered the same logical customer.
   - Within each dedupe group, keep exactly one survivor row using this priority:
     1. highest non-null `lifetime_value`
     2. earliest `created_at`
     3. lowest `customer_id`
7. For the surviving row, carry these canonical values:
   - `canonical_customer_id`: the kept `customer_id`
   - `customer_natural_key`: the kept `customer_natural_key`
   - `first_name_clean`, `last_name_clean`, `full_name_clean`
   - `email_clean`
   - `phone_clean`
   - `country_code` uppercased
   - `created_at`
   - `marketing_opt_in`
   - `loyalty_tier_clean`
   - `lifetime_value` with nulls converted to `0`
   - `customer_segment`
   - `duplicate_record_count`: count of raw records collapsed into that survivor
8. Write the result by replacing `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean`.

Expected grain: one row per deduplicated logical customer.

## Step 2: `job_daily_order_aggregation`

Purpose: aggregate order activity per cleaned customer per day.

Exact logic:

1. Read `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_clean` and `DBT_SANDBOX_BRICE.RAW.orders`.
2. Standardize raw order currency codes before aggregation:
   - `USD`, `usd`, `US$` -> `USD`
   - `EUR`, `eur` -> `EUR`
   - `GBP` -> `GBP`
   - `MXN` -> `MXN`
   - null or blank -> `USD`
   - any other value -> uppercase(trim(value))
3. Join orders to customers using `orders.customer_id = customer_clean.canonical_customer_id`.
   - Only orders that match a cleaned customer are included.
4. Derive `order_day` as `cast(order_date as date)`.
5. Aggregate at grain `canonical_customer_id, order_day`.
6. Produce these measures:
   - `order_count`: count of all orders
   - `completed_order_count`: count where `order_status = 'completed'`
   - `cancelled_order_count`: count where `order_status = 'cancelled'`
   - `returned_order_count`: count where `order_status = 'returned'`
   - `pending_order_count`: count where `order_status = 'pending'`
   - `gross_revenue_amount`: sum of `total_amount` across all orders
   - `completed_revenue_amount`: sum of `total_amount` only for completed orders
   - `discount_amount`: sum of `discount_amount`
   - `latest_currency_code`: the standardized currency code from the most recent order in that customer-day group
7. Carry through these customer attributes from `customer_clean`:
   - `customer_natural_key`
   - `full_name_clean`
   - `email_clean`
   - `country_code`
   - `loyalty_tier_clean`
   - `customer_segment`
8. Write the result by replacing `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`.

Expected grain: one row per customer per order day.

## Step 3: `job_customer_ltv_scoring`

Purpose: calculate customer lifetime value outputs using a reference-table multiplier keyed by customer segment.

Exact logic:

1. Create or replace reference table `DBT_SANDBOX_BRICE.LEGACY_PROD.ltv_multiplier_ref` with exactly these rows:
   - `standard`, `1.00`
   - `growth`, `1.15`
   - `vip`, `1.35`
2. Read `DBT_SANDBOX_BRICE.LEGACY_PROD.daily_order_summary`.
3. Aggregate to customer grain (`canonical_customer_id`).
4. For each customer compute:
   - `active_days`: count of distinct `order_day`
   - `lifetime_order_count`: sum of `order_count`
   - `lifetime_completed_order_count`: sum of `completed_order_count`
   - `lifetime_gross_revenue`: sum of `gross_revenue_amount`
   - `lifetime_completed_revenue`: sum of `completed_revenue_amount`
   - `lifetime_discount_amount`: sum of `discount_amount`
   - `avg_daily_completed_revenue`: average of `completed_revenue_amount` across active order days
5. Join to `ltv_multiplier_ref` using `customer_segment`.
6. Compute `ltv_score` as:
   - `lifetime_completed_revenue * multiplier`
7. Compute `ltv_band` as:
   - `platinum` when `ltv_score >= 1000`
   - `gold` when `ltv_score >= 500 and < 1000`
   - `silver` when `ltv_score >= 150 and < 500`
   - `bronze` otherwise
8. Carry through descriptive fields:
   - `customer_natural_key`
   - `full_name_clean`
   - `email_clean`
   - `country_code`
   - `loyalty_tier_clean`
   - `customer_segment`
   - `applied_multiplier`
9. Write the result by replacing `DBT_SANDBOX_BRICE.LEGACY_PROD.customer_ltv`.

Expected grain: one row per deduplicated logical customer.

## Processing order

The chained execution order is mandatory:

1. `job_customer_dedup_and_clean`
2. `job_daily_order_aggregation`
3. `job_customer_ltv_scoring`

Each step must fully replace its target table before the next step begins.


# dbt migration validation toolkit


## What this is

This repo is a lightweight way to show **how migration validation would work in dbt**.

It helps teams compare a legacy output to the dbt model replacing it and capture the result in a simple, repeatable summary. That makes migration work easier to explain to prospects, easier to run with a delivery team, and easier to trust before cutover.

## Why it matters

Most migration projects do not stall because SQL cannot be rewritten. They stall because teams need confidence that the new dbt output matches what the legacy process produced.

This toolkit is built to answer that question clearly:

- what legacy output are we replacing?
- which dbt model replaces it?
- what grain are we validating at?
- do the outputs match?
- where can we review the result?

## What it helps with

This toolkit is designed for migration conversations and delivery work involving things like:

- stored procedures
- Matillion
- Talend
- Informatica
- SQL-based legacy pipelines
- Python-driven SQL workflows

It is best thought of as a **migration validation foundation**.

It does **not** claim to fully automate every migration pattern. What it gives you is a shared validation workflow that is simple to explain and straightforward to run.

## What a user needs to do

The user workflow is simple:

1. identify the legacy table or view to compare
2. identify the dbt model that should replace it
3. define the business grain for the comparison
4. add that mapping to the seed file
5. run the validation macro
6. review the summary table

## What the toolkit needs as input

For each comparison, the user only needs to populate a few fields in `seeds/migration_comparison_mapping.csv`:

- `legacy_relation` — fully qualified legacy relation in `DATABASE.SCHEMA.IDENTIFIER` format
- `dbt_model` — dbt model name to compare against
- `grain_key` — business key or composite grain used for comparison context

Optional:

- `compare_mode`
- `notes`

Example:

```csv
legacy_relation,dbt_model,grain_key,compare_mode,notes
LEGACY.SCHEMA.customer_clean,customer_clean,canonical_customer_id,row_level,
LEGACY.SCHEMA.daily_order_summary,daily_order_summary,canonical_customer_id|order_day,row_level,composite grain
LEGACY.SCHEMA.customer_ltv,customer_ltv,canonical_customer_id,row_level,
```

## What happens when you run it

When the validation macro runs, the toolkit:

1. creates a validation schema if it does not already exist
2. creates or replaces a `validation_summary` table in that schema
3. reads the mapping seed
4. compares each dbt model to the mapped legacy relation using `dbt-labs/audit_helper`
5. writes one summary row per comparison

The summary captures:

- legacy row count
- dbt row count
- whether row counts match
- whether the two relations are identical
- overall status
- timestamp
- notes

## What the user gets back

The output is a simple validation summary that can be reviewed in logs or queried directly in Snowflake.

That gives you a clear artifact to use in a migration discussion:

- a record of what was compared
- a record of whether the outputs matched
- a lightweight audit trail for migration signoff

## Sample validation output

A typical summary table would look something like this:

```text
comparison_name     legacy_relation                        dbt_model            grain_key                          legacy_row_count  dbt_row_count  row_count_match  identical_flag  status      notes
customer_clean      LEGACY.SCHEMA.customer_clean           customer_clean       canonical_customer_id              125430            125430         true             true            identical
order_summary       LEGACY.SCHEMA.daily_order_summary      daily_order_summary  canonical_customer_id|order_day    8421              8421           true             false           different  composite grain
customer_ltv        LEGACY.SCHEMA.customer_ltv             customer_ltv         canonical_customer_id              125430            125430         true             true            identical
```

How to read it:

- `row_count_match = true` means the legacy relation and dbt model returned the same number of rows
- `identical_flag = true` means `audit_helper` found the two relations to be identical
- `status` gives a quick summary for each comparison
- `notes` lets you document expected context such as composite grain or known differences

This is the core artifact a user can review with a delivery team or prospect to show what was validated and what still needs follow-up.


## What this repo is best for

This repo is a good fit if you want to:

- show a prospect or internal team how migration validation will work
- stand up a lightweight migration validation framework quickly
- compare legacy outputs to dbt models in a consistent way
- create an auditable validation summary during migration

## Current scope

This repo currently provides **summary validation**.

Today, it writes a comparison summary table with row counts and an identical/not-identical status using `audit_helper`.

If you want richer diagnostics like row-level diff breakdowns, accepted tolerances, or grouped mismatch categories, those would be the next layer to add on top of this foundation.

## Repo layout

### Inputs you edit

- `seeds/migration_comparison_mapping.csv` — the mapping file the macros actually use
- `seeds/migration_comparison_mapping.yml` — seed tests for required columns

### Reference files

- `.agents/references/migration_comparison_mapping.csv` — human-facing template
- `.agents/references/data_validation.md` — shared validation guidance

### Validation macros

- `macros/validation/run_migration_validations.sql` — runs the comparisons and writes the summary table
- `macros/validation/get_migration_validation_summary.sql` — prints the summary rows to the logs

### Migration-specific guidance

- `.agents/talend-migration/skill/skill.md` — example migration-specific methodology aligned to the shared validation framework

## Before you start

Make sure:

1. your dbt profile can connect to the target warehouse
2. the legacy relations you want to compare already exist and are queryable
3. the dbt models you want to validate can build successfully
4. package dependencies are installed

This repo depends on `dbt-labs/audit_helper`, defined in `packages.yml`.

## Quick start

### 1. Install packages

Run:

```bash
dbt deps
```

### 2. Update the mapping seed

Edit:

```text
seeds/migration_comparison_mapping.csv
```

Add one row for each legacy-to-dbt comparison you want to validate.

### 3. Load the mapping into the warehouse

Run:

```bash
dbt seed --select migration_comparison_mapping
```

### 4. Build the dbt models you want to compare

Run the relevant models before validating. For example:

```bash
dbt build --select customer_clean daily_order_summary customer_ltv
```

### 5. Run the validation macro

Run:

```bash
dbt run-operation run_migration_validations
```

By default, the macro writes results to:

```text
<TARGET_DATABASE>.<TARGET_SCHEMA>_validation.validation_summary
```

You can also override the schema:

```bash
dbt run-operation run_migration_validations --args '{"validation_schema": "migration_validation"}'
```

### 6. Review the validation results

To print the results in the logs:

```bash
dbt run-operation get_migration_validation_summary
```

Or query the summary table directly in Snowflake.

## What success looks like

A successful run gives you a summary row for each mapped comparison with fields like:

- `comparison_name`
- `legacy_relation`
- `dbt_model`
- `grain_key`
- `legacy_row_count`
- `dbt_row_count`
- `row_count_match`
- `identical_flag`
- `status`
- `compared_at`
- `notes`

In practice, you are looking for:

- matching row counts where expected
- `identical_flag = true` where strict parity is required
- clear notes for any known or accepted differences

## Common gotchas

### `legacy_relation` must be fully qualified

Use this format:

```text
DATABASE.SCHEMA.IDENTIFIER
```

If you pass anything else, the macro will fail.

### Empty mapping seed

If `seeds/migration_comparison_mapping.csv` is empty, the macro will stop and tell you to populate it first.

### The macro compares built relations

This toolkit does not build your models for you during validation. Build the dbt models first, then run the validation macro.

## Recommended way to use this repo

Use this repo in two phases:

### Phase 1: toolkit setup

Keep the reusable framework here:

- mapping template
- seed-backed mapping pattern
- validation macros
- methodology docs
- migration guidance

### Phase 2: migration execution

Use a separate branch or implementation layer for:

- actual migrated dbt assets
- populated mappings for a real migration
- validation runs against real legacy outputs
- migration reporting and signoff

That keeps the toolkit reusable while still letting you apply it to real migrations.

## Next step

If you are picking this repo up fresh, do this first:

1. run `dbt deps`
2. open `seeds/migration_comparison_mapping.csv`
3. replace the sample rows with your real legacy-to-dbt mappings
4. run `dbt seed --select migration_comparison_mapping`
5. build the dbt models you want to validate
6. run `dbt run-operation run_migration_validations`
7. review the summary table

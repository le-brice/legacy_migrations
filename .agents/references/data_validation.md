# Data validation: legacy outputs vs dbt outputs

Compilation success is not correctness. This step proves the migrated dbt models produce the same business output as the legacy system by comparing the legacy output relation against the dbt output relation in dev.

This validation flow is migration-agnostic. It works for Talend migrations, Matillion migrations, stored procedure migrations, and other legacy-to-dbt rewrites.

## Required inputs

Use the shared mapping template at `.agents/references/migration_comparison_mapping.csv`.

Minimum required fields:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional fields:

- `compare_mode`
- `notes`

Default behavior:

- compare same-named columns
- use row-level validation unless `compare_mode` says otherwise
- ask follow-up questions only when renamed columns, tolerances, exclusions, or non-standard comparison rules are required

## Validation method decision

Before parity validation, ask one explicit question:

> Can I use `dbt-labs/audit_helper` for validation?

If yes:

1. add `dbt-labs/audit_helper` to `packages.yml`
2. run `dbt deps`
3. use `audit_helper` macros as the comparison engine

If no:

1. use the fallback SQL validation pattern in this document

## Validation artifacts

The validation flow should create these artifacts:

- one shared mapping file: `.agents/references/migration_comparison_mapping.csv`
- one validation entry-point analysis: `analyses/validation/run_migration_validations.sql`
- one validation summary output file: `analyses/validation/validation_summary.csv`

The validation SQL should be driven by the mapping file. Do not rely on ad hoc one-off comparison queries.

## Validation flow

1. `dbt compile`
2. `dbt build` for the migrated scope into dev
3. confirm or update `.agents/references/migration_comparison_mapping.csv`
4. choose validation method: `audit_helper` or fallback SQL
5. run the shared validation entry point
6. write the comparison result summary into `analyses/validation/validation_summary.csv`
7. roll the result into `migration_changes.md`

## Set up the comparison: legacy vs dbt

You are comparing two outputs produced in different environments, so control the inputs first.

1. Identify the legacy output relation. This is the source of truth and must be queried read-only.
2. Build the dbt model in dev from the same source data, or from an aligned snapshot of that source data.
3. Align the time window and the comparison grain before checking for differences.
4. Record run timestamps for both the legacy output and the dbt dev run.

Only after inputs are aligned does a remaining difference indicate a transformation issue.

## Preferred engine: audit_helper

If external packages are allowed, use `audit_helper` as the comparison engine.

Recommended pattern:

- the shared validation entry point should call project validation logic that loops through the mapping rows
- for each row, it should compare `ref(dbt_model)` to the mapped `legacy_relation`
- use the declared `grain_key` as the primary key set
- summarize results per mapping row

Useful `audit_helper` macros include:

- `quick_are_relations_identical`
- `compare_and_classify_relation_rows`
- `compare_which_relation_columns_differ`
- `compare_relation_columns`

Use `audit_helper` for the comparison mechanics. The mapping file provides the relation pairing and grain.

## Fallback pattern: SQL comparison

If `audit_helper` is not allowed, use SQL fallback logic.

### Row-level mode

Use a full outer join on the declared grain and return only mismatches.

Typical mismatch classes:

- missing in dbt
- missing in legacy
- value mismatch

### Aggregate mode

Use this when row-level comparison is not appropriate or too large.

Compare:

- row count
- distinct grain count
- key metric totals
- important grouped distributions

## What to compare

For each mapped output:

- row count
- distinct grain count
- duplicate grain detection
- same-named column values when row-level comparison is used
- metric totals and grouped distributions when aggregate comparison is used

## Explaining differences

Every difference must be classified as one of:

- environment or freshness difference
- accepted platform or representation difference
- real migration bug
- mapping issue that needs correction
- legacy output issue

Do not leave differences unexplained.

## Output summary file

Write one summary row per mapping into `analyses/validation/validation_summary.csv`.

Recommended columns:

```csv
comparison_name,legacy_relation,dbt_model,compare_mode,status,row_count_match,grain_match,differences_found,accepted_differences,fixed_differences,notes
```

Example:

```csv
comparison_name,legacy_relation,dbt_model,compare_mode,status,row_count_match,grain_match,differences_found,accepted_differences,fixed_differences,notes
customer_clean,LEGACY.SCHEMA.customer_clean,customer_clean,row_level,pass,true,true,0,0,0,
daily_order_summary,LEGACY.SCHEMA.daily_order_summary,daily_order_summary,row_level,pass,true,true,2,2,0,2 rounding differences accepted
customer_ltv,LEGACY.SCHEMA.customer_ltv,customer_ltv,row_level,fail,true,true,15,0,0,ltv_score mismatch requires investigation
```

## Recommended implementation shape

Use a generic validation framework:

- a shared mapping file in `.agents/references/`
- a shared validation macro that loops through mapped outputs
- a shared validation analysis entry point
- a shared summary output file

This framework should be migration-agnostic. Migration-specific skills should only be responsible for producing or confirming the mapping.

# Data validation: legacy outputs vs dbt outputs

Compilation success is not correctness. This step proves the migrated dbt models produce the same business output as the legacy system by comparing the legacy output relation against the dbt output relation in dev.

This validation flow is migration-agnostic. It works for Talend migrations, Matillion migrations, stored procedure migrations, and other legacy-to-dbt rewrites.

## Required inputs

Use the shared mapping template at `.agents/references/migration_comparison_mapping.csv`, then copy its contents into the executable seed at `seeds/migration_comparison_mapping.csv`.

The validation macros read from the seed-backed mapping, not directly from the `.agents/` reference file.

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
3. use `audit_helper` macros where appropriate for deeper comparison patterns

If no:

1. use the fallback SQL validation pattern in this document

## Validation artifacts

The validation flow should create these artifacts:

- one shared mapping template: `.agents/references/migration_comparison_mapping.csv`
- one executable mapping seed: `seeds/migration_comparison_mapping.csv`
- one validation macro entry point: `macros/validation/run_migration_validations.sql`
- one validation summary retrieval macro: `macros/validation/get_migration_validation_summary.sql`
- one targeted investigation macro: `macros/validation/investigate_migration_validation.sql`
- one validation summary output file: `analyses/validation/validation_summary.csv`

The validation logic should be driven by the seed-backed mapping. Do not rely on ad hoc one-off comparison queries.

## Validation flow

1. `dbt seed --select migration_comparison_mapping`
2. `dbt compile`
3. `dbt build` for the migrated scope into dev
4. choose validation method: `audit_helper` or fallback SQL
5. run `dbt run-operation run_migration_validations`
6. retrieve results with `dbt run-operation get_migration_validation_summary`
7. if one output is flagged, run `dbt run-operation investigate_migration_validation --args '{"dbt_model": "<model_name>"}'`
8. write the comparison result summary into `analyses/validation/validation_summary.csv`
9. roll the result into `migration_changes.md`

## Set up the comparison: legacy vs dbt

You are comparing two outputs produced in different environments, so control the inputs first.

1. Identify the legacy output relation. This is the source of truth and must be queried read-only.
2. Build the dbt model in dev from the same source data, or from an aligned snapshot of that source data.
3. Align the time window and the comparison grain before checking for differences.
4. Record run timestamps for both the legacy output and the dbt dev run.

Only after inputs are aligned does a remaining difference indicate a transformation issue.

## Preferred engine: audit_helper

If external packages are allowed, use `audit_helper` as the comparison engine for deeper comparison patterns.

The shared validation macro can produce a lightweight Snowflake-backed summary using the executable mapping seed. Use `audit_helper` inside that framework for relation identity checks and for deeper comparison patterns when you investigate a flagged output.

Useful `audit_helper` macros include:

- `quick_are_relations_identical`
- `compare_and_classify_relation_rows`
- `compare_which_relation_columns_differ`
- `compare_relation_columns`

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

## Investigation pattern

When an output is flagged as different, use the investigation macro to inspect:

- row counts
- distinct grain counts
- duplicate grain counts
- non-matching grain rows
- a model-specific detail table written to the validation schema

The investigation macro writes detail rows to:

```text
<target_schema>_validation.validation_details_<dbt_model>
```

This keeps investigation outputs reusable and prevents one model's drilldown from overwriting another.

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
comparison_name,legacy_relation,dbt_model,grain_key,compare_mode,status,row_count_match,grain_match,differences_found,accepted_differences,fixed_differences,notes
```

## Recommended implementation shape

Use a generic validation framework:

- a shared mapping template in `.agents/references/`
- an executable seed-backed mapping in `seeds/`
- a shared validation macro that reads the mapping seed
- a shared summary output table in Snowflake
- a retrieval macro for reporting
- a targeted investigation macro for flagged outputs

This framework should be migration-agnostic. Migration-specific skills should only be responsible for producing or confirming the mapping.

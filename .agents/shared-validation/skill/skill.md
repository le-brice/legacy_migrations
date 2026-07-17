---
name: shared-migration-validation
description: Use when validating migrated dbt outputs against legacy outputs for any legacy-to-dbt migration. Runs the shared seed-driven validation workflow, retrieves summaries, and investigates mismatches.
allowed-tools: "Read, Write, Edit, Glob, Grep"
metadata:
  author: hicham-babahmed
  compatibility: dbt Fusion
---

# Shared migration validation

Use this skill when migrated dbt outputs need to be validated against legacy outputs, regardless of the migration source.

This skill is migration-agnostic. It should be reused by Talend migrations, stored-procedure migrations, Matillion migrations, and any other legacy-to-dbt workflow.

## What this skill owns

This skill is responsible for:

1. confirming the validation mapping is populated in `seeds/migration_comparison_mapping.csv`
2. confirming the dbt outputs in scope exist and are ready to validate
3. confirming the legacy outputs in scope are available for comparison
4. deciding whether `dbt-labs/audit_helper` is available for validation
5. running the shared validation macros
6. retrieving the validation summary
7. investigating flagged outputs
8. classifying and explaining differences

## What this skill does not own

This skill does not translate Talend, stored procedure, or other legacy logic into dbt. Migration-specific skills own:

- interpreting legacy logic
- creating dbt assets
- identifying final legacy outputs
- producing or confirming validation mappings

This skill begins once those mappings and outputs exist.

## Required inputs

The executable mapping lives at:

- `seeds/migration_comparison_mapping.csv`

Minimum required columns:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional columns:

- `compare_mode`
- `notes`

Default behavior:

- compare same-named columns
- use row-level validation unless `compare_mode` says otherwise
- ask follow-up questions only when renamed columns, tolerances, exclusions, or non-standard comparison rules are required

## Operational workflow

Work through these phases in order.

### Phase 0 — Confirm validation prerequisites

Before running validation, confirm that:

1. migrated dbt outputs exist for the scope being validated
2. legacy outputs exist or can be queried for the same scope
3. `seeds/migration_comparison_mapping.csv` exists and is populated
4. the comparison grain is defined clearly for each output
5. package dependencies are installed if `audit_helper` will be used

Wizard should trigger:
- inspect `seeds/migration_comparison_mapping.csv`
- confirm the mapped dbt models are expected to exist
- confirm the mapped legacy relations are expected to exist
- identify missing prerequisites before running validation

Deliverables:
- validation-ready scope
- explicit blockers if prerequisites are missing

### Phase 1 — Decide the validation engine

Before parity validation, ask one explicit question:

> Can I use `dbt-labs/audit_helper` for validation?

If yes:

1. confirm `dbt-labs/audit_helper` is in `packages.yml`
2. run `dbt deps`
3. use the shared validation macros with `audit_helper` available for deeper comparison patterns

If no:

1. use the fallback SQL comparison approach inside the shared validation framework

Wizard should trigger:
- inspect `packages.yml`
- confirm whether `audit_helper` is available or allowed
- choose the engine and state that choice clearly

Deliverables:
- chosen validation engine
- dependency status confirmed

### Phase 2 — Seed and build the validation scope

The validation mapping should be seeded before validation runs.

Core execution order:

1. seed `migration_comparison_mapping`
2. build the migrated dbt scope in dev
3. ensure the legacy comparison relations are aligned to the same inputs and time window where possible

Wizard should trigger:
- run the mapping seed
- run a scoped `dbt build` for the migrated outputs in scope
- confirm build success before parity checks

Deliverables:
- executable mapping loaded
- migrated scope built successfully

### Phase 3 — Run the shared validation entry point

The shared validation macros are the core execution layer.

Use:

- `macros/validation/run_migration_validations.sql`
- `macros/validation/get_migration_validation_summary.sql`
- `macros/validation/investigate_migration_validation.sql`
- `macros/validation/get_validation_mapping_seed.sql`

Wizard should trigger:
- run `get_validation_mapping_seed` when the mapping needs confirmation
- run `run_migration_validations`
- run `get_migration_validation_summary`

Deliverables:
- validation summary table populated
- human-readable validation summary retrieved

### Phase 4 — Investigate flagged outputs

When an output is flagged as different, investigate it at the declared grain.

Investigation should inspect:

- row counts
- distinct grain counts
- duplicate grain counts
- non-matching grain rows
- detail tables written to the validation schema

The investigation macro writes detail rows to:

```text
<target_schema>_validation.validation_details_<dbt_model>
```

Wizard should trigger:
- run `investigate_migration_validation --args '{"dbt_model": "<model_name>"}'`
- inspect the investigation summary
- distinguish structural issues from value-level issues

Deliverables:
- investigation summary for each flagged output
- narrowed root-cause category

### Phase 5 — Classify and explain differences

Every difference should be classified as one of:

- environment or freshness difference
- accepted platform or representation difference
- real migration bug
- mapping issue that needs correction
- legacy output issue

Wizard should trigger:
- classify each mismatch explicitly
- avoid leaving differences unexplained
- note whether the next action belongs in migration logic, validation mapping, or source alignment

Deliverables:
- explained mismatch list
- next actions by category

### Phase 6 — Write the validation outcome back into project artifacts

The validation result should not stay implicit.

Expected artifacts:

- seeded mapping in `seeds/migration_comparison_mapping.csv`
- validation summary in Snowflake
- optional project summary file in `analyses/validation/validation_summary.csv`
- migration notes or change log updated with parity status where the project uses one

Wizard should trigger:
- summarize the final validation outcome clearly
- note which outputs matched, which differed, and which still need work
- write or update summary artifacts when the project maintains them

Deliverables:
- reusable validation outputs
- clear final status for the validated scope

## What to compare

For each mapped output, compare:

- row count
- distinct grain count
- duplicate grain detection
- same-named column values when row-level comparison is used
- key metric totals and grouped distributions when aggregate comparison is used

## Good execution pattern

A strong validation run usually follows this sequence:

1. confirm mapping is populated
2. seed the mapping
3. build the migrated dbt scope
4. confirm legacy relations are ready
5. run validation
6. retrieve the summary
7. investigate flagged outputs
8. classify differences
9. record the outcome

## Don’t do these things

1. Don’t rely on compile alone.
2. Don’t skip seeding the executable mapping.
3. Don’t run ad hoc one-off compare queries as the main validation method when the shared framework exists.
4. Don’t investigate mismatches before confirming the build is green.
5. Don’t leave flagged differences unexplained.
6. Don’t force migration-specific interpretation logic into this shared skill.

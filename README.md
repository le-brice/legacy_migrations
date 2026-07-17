# Generic migration toolkit for dbt

This repository provides a reusable workflow for migrating legacy data transformations into dbt and validating dbt outputs against legacy outputs.

It is designed to support the full migration lifecycle:

- understand the legacy workflow
- identify the dbt assets needed to reproduce it
- build or refine migrated dbt assets
- make legacy outputs available for comparison
- validate dbt outputs against legacy outputs
- investigate and explain mismatches

This README focuses on the toolkit itself. The Talend assets and stored-procedure macros left in this repo are example inputs to the toolkit, not the definition of the toolkit.

## What this repository provides

This repo includes reusable pieces for each phase of a migration.

### Legacy analysis inputs

Use these files to understand what is being migrated:

- `legacy_source/talend/` — example Talend exports and mapping notes
- `legacy_source/README.md` — example business specification for a legacy workflow

In another project, this layer could contain exports from Talend, Matillion, Informatica, stored procedures, scheduled SQL jobs, or process documentation.

### Standard dbt project areas

These are the standard locations where migrated dbt assets should live:

- `models/staging/`
- `models/intermediate/`
- `models/marts/`
- `tests/`
- `snapshots/`

The toolkit does not assume those migrated models already exist. Early in the workflow, the wizard should help define and create them.

### Executable validation inputs

These drive validation once a migrated dbt output and a corresponding legacy output both exist:

- `seeds/migration_comparison_mapping.csv` — executable mapping between legacy outputs and dbt models
- `seeds/migration_comparison_mapping.yml` — metadata and tests for the mapping seed

The mapping seed is intentionally minimal. It is the handoff between migration work and validation work.

### Shared validation framework

These macros are the reusable core of the toolkit:

- `macros/validation/run_migration_validations.sql`
- `macros/validation/get_migration_validation_summary.sql`
- `macros/validation/investigate_migration_validation.sql`
- `macros/validation/get_validation_mapping_seed.sql`

Validation currently relies on `dbt-labs/audit_helper`, configured in `packages.yml`.

### Example legacy recreation helpers

These macros are example implementations of a pattern you may use in a migration project:

- `macros/deploy_legacy_chain.sql`
- `macros/run_legacy_chain.sql`

Use them as reference when a project needs to recreate legacy outputs in the warehouse before running comparison checks.

## Core migration workflow

Use the toolkit in this order:

1. inspect the legacy workflow
2. identify the dbt assets needed
3. create or refine migrated dbt assets
4. prepare dependencies and inputs
5. build the migrated dbt workflow
6. make legacy outputs available for comparison
7. run validation
8. investigate differences
9. extend validation scope as more outputs are migrated

## Example wizard prompts by phase

These prompts are examples. Adjust the wording to fit your migration, the assets already present in the repo, and the specific step you want the wizard to handle.

### 1. Understand the legacy workflow

Wizard should trigger:
- read the relevant files under the legacy input directories
- identify processing order, transformation logic, outputs, and business grain
- summarize what must be preserved in dbt

```text
Walk me through the legacy assets in this repository and explain the workflow step by step, including the processing order, outputs, and expected grain.
```

Expected result:
- summary of legacy business logic
- list of outputs produced by the legacy workflow
- clear description of grain and key transformations

### 2. Plan the dbt migration

Wizard should trigger:
- inspect the legacy workflow inputs
- inspect the existing dbt project structure
- propose the staging, intermediate, mart, seed, test, and macro assets needed

```text
Read the legacy workflow and propose the dbt staging models, intermediate models, marts, seeds, tests, and macros needed to migrate it.
```

Expected result:
- recommended dbt asset structure
- suggested grains and dependencies
- notes on what should be a seed, source, staging model, intermediate model, or mart

### 3. Build the first migrated assets

Wizard should trigger:
- read the relevant SQL and YAML files first
- create or edit dbt SQL and properties files
- validate changes with targeted dbt commands

```text
Help me build the first migrated dbt assets for this legacy workflow, following the conventions already used in this repository.
```

Expected result:
- new or updated dbt assets
- alignment with the repo structure and existing conventions
- targeted validation of the changed assets

### 4. Prepare the project to run

Wizard should trigger:
- install or verify package dependencies
- load required seeds or reference data if the project uses them
- load or confirm the validation mapping seed if validation is in scope

```text
Prepare this repository to run the migration workflow. Install packages, load required seeds or reference data, and confirm any validation inputs are available.
```

Expected result:
- package dependency setup
- seed loading where applicable
- confirmation that validation inputs are ready when needed

### 5. Build the dbt workflow

Wizard should trigger:
- identify the relevant migrated models and dependencies
- run a scoped `dbt build`
- summarize model and test results

```text
Build the migrated dbt workflow for this legacy process and tell me whether the models and tests pass.
```

Expected result:
- scoped build of the migrated chain
- test outcomes
- clear explanation of failures if anything breaks

### 6. Make legacy outputs available for comparison

Wizard should trigger:
- determine whether legacy outputs already exist in a comparison environment
- if not, run project-specific recreation helpers when available
- confirm which legacy relations are ready for comparison

```text
Make the legacy outputs available for comparison, using any recreation scripts in this repository if needed, and confirm which legacy tables are ready to validate against.
```

Expected result:
- available legacy comparison relations
- legacy recreation run if needed
- confirmation of comparison readiness

### 7. Validate dbt vs legacy

Wizard should trigger:
- confirm the validation mapping seed is in place
- run the shared validation macro
- read back the validation summary

```text
Run the migration validation workflow for the migrated outputs that currently exist and summarize which dbt outputs match legacy and which do not.
```

Expected result:
- execution of the validation macros
- row-count and identical/non-identical summary
- list of outputs that need investigation

### 8. Investigate differences

Wizard should trigger:
- run the investigation macro for the mismatched model
- inspect grain-level mismatch outputs
- summarize whether the issue is structural or value-level

```text
Investigate the mismatched migrated model and tell me whether the issue is caused by grain mismatches, duplicates, missing rows, or value-level differences.
```

Expected result:
- grain-level investigation summary
- indication of whether the issue is caused by joins, filtering, deduping, aggregation, or field-level logic
- guidance on where to inspect the SQL next

### 9. Extend the validation scope

Wizard should trigger:
- update the validation mapping seed if needed
- update supporting legacy source definitions if needed
- build the new model and run targeted validation

```text
I added a new migrated output. Update the validation mapping and any supporting source definitions if needed, then run the validation workflow for the new model.
```

Expected result:
- updated validation inputs
- targeted build and validation for the new output
- summary of whether the new output matches legacy

## When validation becomes relevant

Validation starts after two things exist:

1. the migrated dbt output is materialized
2. the corresponding legacy output is available for comparison

The comparison is driven by `seeds/migration_comparison_mapping.csv`, which maps:

- `legacy_relation`
- `dbt_model`
- `grain_key`
- `compare_mode`
- `notes`

Once both sides exist, the validation workflow is:

1. load or refresh the mapping seed
2. build the migrated dbt models
3. make legacy outputs available
4. run `run_migration_validations`
5. review the summary
6. investigate any mismatches

## Where things live

### Generic toolkit pieces

- `macros/validation/`
- `seeds/migration_comparison_mapping.csv`
- `seeds/migration_comparison_mapping.yml`
- `packages.yml`

### Standard implementation areas for migrated dbt assets

- `models/staging/`
- `models/intermediate/`
- `models/marts/`
- `tests/`
- `snapshots/`

### Example inputs still included in this repo

- `legacy_source/talend/`
- `legacy_source/README.md`
- `macros/deploy_legacy_chain.sql`
- `macros/run_legacy_chain.sql`

## What you should get from this repository

By the end of using this toolkit, you should be able to:

- explain a legacy workflow in business terms
- identify the dbt assets needed to reproduce it
- build and test migrated dbt assets
- compare dbt outputs to legacy outputs in a repeatable way
- investigate mismatches systematically instead of manually
- reuse the same validation pattern across migration projects

## Notes

- This repository supports both migration work and post-migration validation.
- Reseed `migration_comparison_mapping` any time you change `seeds/migration_comparison_mapping.csv`.
- The example recreation macros are project-specific reference assets; the validation macros are the generic toolkit core.

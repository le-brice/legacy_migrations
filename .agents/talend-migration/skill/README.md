# Talend migration skill

This folder contains the Talend-specific migration skill used by the generic migration toolkit.

Its purpose is to guide the operational workflow for migrating Talend jobs into dbt while handing off validation to the shared migration-agnostic validation framework.

## What this skill is responsible for

- inventory Talend job logic from `.item` exports
- translate Talend transformations into dbt models, seeds, snapshots, macros, tests, and documentation
- identify the final legacy outputs produced by Talend jobs
- map those outputs to migrated dbt models
- populate or confirm the executable validation mapping at `seeds/migration_comparison_mapping.csv`
- prepare the migration for the shared validation workflow

## What this skill does not own

This skill does not define its own validation methodology.

Validation is delegated to the shared framework described in:

- `.agents/references/data_validation.md`

## Minimal validation inputs

The shared framework only requires:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional:

- `compare_mode`
- `notes`

## Position in the toolkit

Talend is one migration source feeding a generic validation framework.
That same validation framework is intended to be reusable for other migration types as well.

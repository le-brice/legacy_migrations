# Shared migration references

This folder contains the shared, migration-agnostic reference material used by the migration confidence toolkit.

These files are intended to be reused across migration types, including Talend, Matillion, stored procedures, and other legacy-to-dbt rewrites.

## Files in this folder

- `data_validation.md`
  - the shared validation methodology
  - explains the minimal required mapping input
  - explains the `audit_helper` yes/no decision
  - explains the fallback SQL path
  - defines the expected validation artifacts and summary output

- `migration_comparison_mapping.csv`
  - the canonical minimal mapping template
  - used to pair legacy output relations with dbt models
  - asks only for the least amount of information needed

## Required input model

Required fields:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional fields:

- `compare_mode`
- `notes`

Default behavior:

- compare same-named columns
- use row-level comparison by default
- ask follow-up questions only when renamed columns, tolerances, exclusions, or aggregate comparison are needed

## Planned framework outputs

The shared validation framework is designed to produce:

- `analyses/validation/run_migration_validations.sql`
- `analyses/validation/validation_summary.csv`

## Position in the toolkit

Migration-specific skills should identify and map legacy outputs.
The shared validation framework should execute comparison and summarize results.

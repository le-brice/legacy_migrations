# Migration confidence toolkit for dbt

This repository contains the foundation of a migration confidence toolkit designed to help prospects feel confident going into a migration to dbt.

The goal is not only to say that a migration can be done. The goal is to provide a lightweight, repeatable, auditable framework that explains:

- how legacy logic is inventoried and translated into dbt
- what minimal input is required from the prospect
- how legacy outputs are validated against dbt outputs
- how differences are summarized and explained
- which artifacts the migration process should produce

## Design principles

### 1. Validation is migration-agnostic

The validation framework is shared across migration types. It should work for Talend migrations, Matillion migrations, stored procedure migrations, and other legacy-to-dbt rewrites.

Migration-specific skills are responsible for identifying legacy outputs and mapping them to dbt models. The shared validation framework is responsible for comparison and parity reporting.

### 2. Ask for the least amount of information needed

The framework intentionally keeps the required mapping input minimal.

Required fields:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional fields:

- `compare_mode`
- `notes`

The framework also asks one explicit validation decision:

- can `dbt-labs/audit_helper` be used for validation?

### 3. Use executable mapping inputs

The toolkit keeps a human-facing mapping template under `.agents/references/`, but validation is driven by an executable dbt seed:

- reference template: `.agents/references/migration_comparison_mapping.csv`
- executable input: `seeds/migration_comparison_mapping.csv`

## Toolkit contents

### Shared references

Under `.agents/references/`:

- `data_validation.md` — generic validation methodology for comparing legacy outputs to dbt outputs
- `migration_comparison_mapping.csv` — minimal human-facing mapping template for pairing legacy outputs to dbt models

### Executable validation inputs

Under `seeds/`:

- `migration_comparison_mapping.csv` — executable seed-backed mapping used by the validation macros
- `migration_comparison_mapping.yml` — seed properties for the executable mapping

### Migration-specific skills

Under `.agents/talend-migration/skill/`:

- `skill.md` — Talend migration methodology, including how Talend outputs feed the shared validation framework

## Validation framework

The shared validation framework is built around these artifacts:

### Required input

- `.agents/references/migration_comparison_mapping.csv` as the template
- `seeds/migration_comparison_mapping.csv` as the executable mapping input

Example:

```csv
legacy_relation,dbt_model,grain_key,compare_mode,notes
LEGACY.SCHEMA.customer_clean,customer_clean,canonical_customer_id,row_level,
LEGACY.SCHEMA.daily_order_summary,daily_order_summary,canonical_customer_id|order_day,row_level,composite grain
LEGACY.SCHEMA.customer_ltv,customer_ltv,canonical_customer_id,row_level,
```

### Shared execution artifacts

- `macros/validation/run_migration_validations.sql`
- `macros/validation/get_migration_validation_summary.sql`
- `macros/validation/investigate_migration_validation.sql`

### Planned summary output

- `analyses/validation/validation_summary.csv`

Recommended schema:

```csv
comparison_name,legacy_relation,dbt_model,grain_key,compare_mode,status,row_count_match,grain_match,differences_found,accepted_differences,fixed_differences,notes
```

## Validation method

### Preferred path

If allowed, use `dbt-labs/audit_helper` as the comparison engine for deeper comparison patterns.

### Fallback path

If `audit_helper` is not allowed, use fallback SQL patterns.

Both paths should follow the same shared mapping and produce the same summary output shape.

## What migration-specific skills should do

Migration-specific skills should:

- inventory legacy logic
- translate legacy logic into dbt assets
- identify final legacy outputs
- map legacy outputs to dbt models
- populate or confirm the shared comparison mapping
- update the executable mapping seed
- hand off validation to the shared framework

They should not create their own separate validation methodology.

## What is already included

This repository currently includes:

- a shared validation reference
- a shared minimal mapping template
- an executable seed-backed mapping pattern
- generalized validation macros
- a targeted investigation macro for flagged outputs
- a Talend migration skill aligned to the shared validation framework

## Suggested workflow

### Branch 1: toolkit foundation

Use one branch for setup and toolkit only:

- references
- templates
- skills
- reusable validation macros
- methodology docs

### Branch 2: toolkit applied to a real migration

Create a second branch from the toolkit branch for:

- actual migrated dbt assets
- actual populated mappings
- actual validation analyses
- actual comparison outputs
- actual migration reporting

This keeps the toolkit reusable and keeps migration execution separate from the framework itself.

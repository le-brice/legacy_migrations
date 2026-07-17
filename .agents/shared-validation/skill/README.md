# Shared migration validation skill

This folder contains the migration-agnostic validation skill used by the generic migration toolkit.

Its purpose is to execute the shared parity workflow for comparing migrated dbt outputs to legacy outputs once the migration-specific mapping is ready.

## What this skill is responsible for

- confirm the executable validation mapping at `seeds/migration_comparison_mapping.csv`
- confirm the validation scope is ready
- choose the validation engine (`audit_helper` or fallback SQL)
- run the shared validation macros
- retrieve the validation summary
- investigate mismatches
- classify and summarize differences

## What this skill does not own

This skill does not translate legacy logic into dbt or decide how Talend, stored procedures, or other source systems should be modeled.

Migration-specific skills should produce or confirm the mapping and the migrated outputs first.

## Position in the toolkit

This validation skill is intended to be reused by Talend migrations and any other legacy-to-dbt migration workflow that can produce the required mapping and output relations.

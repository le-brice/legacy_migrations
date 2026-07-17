---
name: migrating-talend-to-dbt
description: Use when migrating Talend ETL jobs (.item XML exports) to a dbt project. Guides the full operational workflow from Talend inventory through dbt asset planning, model implementation, validation mapping, and handoff to the shared validation framework.
allowed-tools: "Read, Write, Edit, Glob, Grep"
metadata:
  author: hicham-babahmed
  compatibility: dbt Fusion
---

# Migrating Talend to dbt

Use this skill when the migration source is Talend and the main artifacts are `.item` XML exports, Talend job documentation, or related mapping notes.

This skill is operational. It is meant to guide the workflow from first inspection of Talend jobs through migrated dbt assets and into the shared validation handoff.

It does **not** own a Talend-specific validation methodology. Validation should be handed off to the reusable shared validation skill under `.agents/shared-validation/skill/`, with `.agents/references/data_validation.md` remaining the reference methodology.


## What this skill owns

This skill is responsible for:

1. inventorying Talend job logic from `.item` exports
2. translating Talend transformations into dbt models, seeds, snapshots, macros, tests, and documentation
3. identifying final legacy outputs produced by Talend jobs
4. mapping those outputs to migrated dbt models
5. populating or confirming the executable validation mapping in `seeds/migration_comparison_mapping.csv`
6. preparing the migration so the shared validation workflow can run cleanly

## What this skill does not own
Validation is delegated to:

- `.agents/shared-validation/skill/skill.md`
- `.agents/references/data_validation.md`

The shared validation skill is the execution layer. The reference markdown is the methodology layer.

That shared workflow is reusable for Talend, Matillion, stored procedure, and other legacy-to-dbt migrations.

## Success criteria

A Talend migration is complete when all of the following are true:

1. the Talend jobs and components in scope are inventoried
2. migrated dbt assets are created or a clear asset plan is documented
3. important tests, docs, and contracts are added where they matter
4. final legacy outputs are mapped to dbt outputs in `seeds/migration_comparison_mapping.csv`
5. the migrated scope builds successfully and attached tests pass
6. validation is handed off and run through the shared framework
7. residual non-dbt work is explicitly listed

## Core principles

### 1. Migrate from the Talend graph, not generated code

Treat the `.item` XML export as the primary artifact. Read component types, wiring, schemas, expressions, joins, filters, sorting rules, dedupe logic, and outputs from the job metadata itself.

### 2. Preserve business logic, not Talend runtime noise

Reproduce the transformation semantics faithfully, but do not port Talend-specific mechanics when dbt has a cleaner representation.

### 3. Keep the migration explainable

Every major dbt model should have a clear role in the DAG, a clear grain, and a reason for its materialization.

### 4. Validate outputs, not just syntax

A clean parse or compile is necessary, but proof comes from `dbt build` plus shared parity validation against legacy outputs.

### 5. Track residual work explicitly

File movement, email sending, FTP, shell execution, Java routines, and orchestration-only steps usually do not belong in dbt. Record them as residual work instead of forcing them into fake models.

## Operational workflow

Work through these phases in order.

### Phase 0 — Confirm migration decisions

Before building anything substantial, confirm the high-level migration defaults.

Decisions to capture:

1. **Target architecture**
   - layered dbt project
   - Kimball-style model
   - star-schema marts
   - faithful Talend-to-dbt layered port

2. **Landing spot**
   - new dbt project
   - existing project
   - domain subfolder inside an existing project

3. **Reusable logic strategy**
   - package dependency
   - repo-local macro
   - model-only implementation

4. **Platform assumptions**
   - warehouse platform
   - target schema conventions
   - whether legacy outputs already exist for direct comparison

5. **Validation assumptions**
   - whether `dbt-labs/audit_helper` can be used
   - whether `seeds/migration_comparison_mapping.csv` already exists
   - whether legacy relations are already queryable or need recreation helpers

Wizard should trigger:
- inspect the project structure and legacy input folders
- capture the decisions above in plain language
- recommend practical defaults when the user has not chosen them

Deliverables:
- agreed migration defaults
- clear scope boundary for what is in dbt vs residual work

### Phase 1 — Inventory the Talend workload

Parse each `.item` file and build a component-level inventory.

Capture at minimum:

- job name
- job purpose
- source systems and target outputs
- every component name and type
- selected columns and schemas
- join conditions
- lookup behavior
- filter rules
- aggregation rules
- sort priority
- dedupe rules
- context variables
- `tRunJob` dependencies
- final outputs written by each job

Also count the total number of Talend components. This becomes the denominator for coverage reporting.

Use an inventory table shape like:

```markdown
| job | component | type | role | upstream | downstream | migration target | status |
|-----|-----------|------|------|----------|------------|------------------|--------|
```

Wizard should trigger:
- read all relevant `.item` files
- summarize component graphs and job order
- produce an inventory table or equivalent structured notes

Deliverables:
- Talend inventory
- list of final outputs
- initial coverage denominator

### Phase 2 — Map Talend components into dbt layers

Translate each Talend component into the simplest dbt layer that preserves clarity.

Practical defaults:

- **sources**: raw input systems and imported tables
- **staging (`stg_`)**: renaming, typing, normalization, source-conformed fields
- **intermediate (`int_`)**: joins, dedupe prep, ranking, reusable scoped transformations
- **marts**: final business outputs
- **snapshots**: history-preserving records when the legacy workflow encodes change over time
- **seeds**: fixed reference data, code mappings, static lookup rows
- **macros**: repeated SQL logic or repeated expression patterns

Wizard should trigger:
- classify each Talend step into a dbt destination
- identify assets that should stay outside dbt
- recommend naming and DAG shape

Deliverables:
- proposed dbt DAG
- mapping from Talend components to dbt assets
- residual-work list started

### Phase 3 — Translate Talend patterns into dbt patterns

Use these practical mappings:

#### Input and output components

- `tDBInput`, `tSnowflakeInput`
  - map to `source()` plus usually a staging model
- `tDBOutput`, `tSnowflakeOutput`
  - map to final dbt models or business-facing intermediate outputs
- `tFixedFlowInput`
  - usually becomes a seed or tiny reference model
- `tRunJob`
  - usually becomes DAG dependency structure or orchestration sequencing

#### Row-level transformation components

- `tMap`
  - usually becomes a `select` with renamed columns, derived fields, joins, and `case` logic
- `tFilterRow`
  - map to `where` clauses or filtered intermediate models
- cleanup/normalization logic
  - usually belongs in staging or early intermediate models

#### Set-based logic components

- `tJoin`
  - map to explicit SQL joins; preserve join type exactly
- `tAggregateRow`
  - map to grouped models with explicit grain and measures
- `tSortRow`
  - often supports ranking, latest-row selection, or deterministic survivor logic
- `tUniqRow`
  - usually maps to `row_number()` plus a final filter

#### Non-dbt components

- FTP, file movement, shell execution, email, APIs, custom Java, orchestration-only steps
  - classify as residual work or move into orchestration/platform tooling

Common expression translations:

- `StringHandling.TRIM(x)` → `trim(x)`
- `StringHandling.UPCASE(x)` → `upper(x)`
- `StringHandling.LOWER(x)` → `lower(x)`
- `TalendString.initCap(x)` → `initcap(x)`
- ternary logic → `case when`
- null/default logic → `coalesce(...)` or `nullif(trim(...), '')`
- sort + uniq patterns → window functions plus final filtering

Wizard should trigger:
- translate Talend expressions into readable SQL
- keep transformations explainable, not mechanically one-to-one
- split logic into multiple dbt assets when readability or reuse warrants it

Deliverables:
- translated SQL logic plan
- identified seeds/macros/snapshots where needed

### Phase 4 — Build migrated dbt assets

Create or refine the dbt implementation.

Typical outputs:

- source YAML
- staging models
- intermediate models
- marts
- seed files for stable lookups
- snapshots where history matters
- macros for repeated logic
- model YAML with descriptions and tests

Materialization defaults:

- **view** for light staging
- **table** for reused intermediate models and stable marts
- **incremental** only when the business logic and source behavior truly support incremental correctness
- **snapshot** when the legacy workflow preserves change history

Wizard should trigger:
- read the target directories and current files first
- create or update SQL and YAML files
- keep grain and materialization decisions explicit

Deliverables:
- migrated dbt assets in the right project locations
- model and source metadata

### Phase 5 — Add governance

Every migration should add enough structure that the result is maintainable.

Add where appropriate:

- `not_null` on keys and required business columns
- `unique` on declared model grain
- `relationships` where foreign keys are expected
- `accepted_values` for controlled enums
- contracts on stable public-facing marts
- explicit grain documentation

Wizard should trigger:
- inspect YAML coverage
- add the minimum useful tests and documentation
- note any remaining gaps

Deliverables:
- tests and docs for important assets
- contracts where appropriate

### Phase 6 — Validate the migrated dbt build

Before parity validation, confirm the migrated scope actually builds.

Wizard should trigger:
- run scoped `dbt build` for the migrated assets
- fix build or test failures before moving on
- summarize what passed and what still blocks parity validation

Deliverables:
- successful build of migrated scope
- clear failure list if not yet green

### Phase 7 — Prepare the validation handoff

This is the Talend skill’s boundary with the shared validation framework.

The Talend skill must:

1. identify each final legacy output relation
2. identify the matching dbt output model
3. define the comparison grain
4. populate or confirm `seeds/migration_comparison_mapping.csv`
5. note any outputs that cannot yet be validated and why

Minimum mapping fields:

- `legacy_relation`
- `dbt_model`
- `grain_key`

Optional:

- `compare_mode`
- `notes`

Wizard should trigger:
- update or confirm the mapping seed at `seeds/migration_comparison_mapping.csv`
- confirm the legacy relations needed for comparison are available or note the gap
- stop and ask for clarification if the mapping is ambiguous

Deliverables:
- executable mapping seed ready for validation
- list of outputs ready for parity checks

### Phase 8 — Hand off to the shared validation workflow

At this point, switch to `.agents/references/data_validation.md`.

The shared validation workflow owns:

- validation method choice (`audit_helper` or SQL fallback)
- seeding the executable mapping
- running `run_migration_validations`
- retrieving the summary with `get_migration_validation_summary`
- running `investigate_migration_validation` for flagged outputs
- writing the validation summary output

The Talend skill should stay responsible for explaining Talend logic and fixing migration logic when validation exposes a bug.

Wizard should trigger:
- explicitly reference `.agents/references/data_validation.md`
- run the shared validation flow instead of inventing a Talend-specific comparison process
- return to this skill only when mismatches require Talend-specific logic interpretation

Deliverables:
- validation run through shared framework
- mismatch list ready for debugging if needed

### Phase 9 — Explain mismatches and report coverage

When validation finds differences, classify them clearly:

- logic bug in dbt
- source or freshness difference
- accepted platform difference
- mapping issue
- legacy output issue

Coverage should be reported as:

```text
migrated_or_residual_components / total_inventoried_components
```

Count a component as covered only when it is:

- represented in the dbt solution, or
- intentionally classified as residual with a clear reason

Wizard should trigger:
- update the inventory status
- list uncovered or partially handled components explicitly
- summarize validation status and remaining gaps

Deliverables:
- coverage status
- residual-work list
- migration summary suitable for handoff

## What good output from this skill looks like

A solid Talend migration should leave behind:

- migrated dbt SQL models
- source YAML and model YAML
- tests and contracts where appropriate
- seeds for fixed reference data
- snapshots where history matters
- a residual-work list for non-dbt components
- a populated `seeds/migration_comparison_mapping.csv`
- a clean handoff into the shared validation workflow

## Known gotchas

- `tMap` lookups can change row counts depending on unique-match vs all-match behavior.
- `tSortRow` plus `tUniqRow` usually encodes real survivor logic, not cosmetic ordering.
- Talend context variables often map to dbt vars or environment variables and should not be hardcoded.
- cross-job `tRunJob` chains may signal orchestration boundaries instead of model boundaries.
- custom Java routines may need manual redesign instead of direct SQL translation.
- generated Talend code is usually a worse migration source than the `.item` graph.

## Don’t do these things

1. Don’t skip inventory.
2. Don’t declare success on parse or compile alone.
3. Don’t force non-dbt runtime components into fake dbt models.
4. Don’t silently change join semantics or dedupe rules.
5. Don’t leave final outputs unmapped for validation.
6. Don’t invent a Talend-only validation workflow when the shared one already exists.
7. Don’t leave residual work undocumented.

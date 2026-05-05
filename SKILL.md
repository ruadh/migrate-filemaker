---
name: migrate-filemaker
description: >
  Guide a full migration from FileMaker Pro to an Oracle APEX application. Includes a built-in DDR
  parser that extracts structured specs from FileMaker Database Design Report XML exports.
  Parses the DDR, discovers requirements, and generates a detailed rebuild plan including SQL schema.
argument-hint: [path-to-ddr-xml-or-directory]
---

# FileMaker Migration Planner

Orchestrate a complete migration from a FileMaker Pro solution to a modern open-source stack. This skill runs in four phases, each producing a checkpoint file so work can be resumed across sessions.

**Reference documents** (consult these during analysis):
- [FileMaker Concepts → Modern Equivalents](reference/filemaker-concepts.md)
- [Schema Translation Guide](reference/schema-translation-guide.md)
- [Script Translation Patterns](reference/script-translation-patterns.md)
- [Tech Stack Decision Matrix](reference/tech-stack-decision-matrix.md)
- [DDR XML Structure Reference](reference/ddr-xml-reference.md)

**Output templates** (use these structures for all generated documents):
- [templates/00_app_summary.md](templates/00_app_summary.md)
- [templates/01_discovery_answers.md](templates/01_discovery_answers.md)
- [templates/02_recommendations.md](templates/02_recommendations.md)
- [templates/03_migration_plan.md](templates/03_migration_plan.md)
- [templates/04_database_schema.sql](templates/04_database_schema.sql)
- [templates/05_data_operations_design.md](templates/05_data_operations_design.md)
- [templates/06_ui_spec.md](templates/06_ui_spec.md)

---

## Before Starting: Check for Previous Progress

Before running any phase, check which checkpoint files already exist:

```
migration/
  00_app_summary.md        ← Phase 1 output
  01_discovery_answers.md  ← Phase 2 output
  02_recommendations.md    ← Phase 3 output
  03_migration_plan.md     ← Phase 4 output
  04_database_schema.sql   ← Phase 4 output
  05_data_operations_design.md         ← Phase 4 output
  06_ui_spec.md            ← Phase 4 output
```

If a phase's output file exists, ask:
> "Phase N (description) appears complete — I found `migration/NN_filename.md`. Would you like to review it, redo it, or continue to Phase N+1?"

Resume from the earliest incomplete phase.

---

## Phase 1: Parse & Understand

### Step 1.1: Run the DDR Parser

First, verify Python is available:

```bash
python3 --version 2>/dev/null || python --version 2>/dev/null
```

If neither command succeeds, stop and tell the user:
> "The DDR parser requires Python (3.6+). Please install Python and try again — on macOS: `brew install python3`, on Ubuntu/Debian: `sudo apt install python3`."

Run the built-in DDR parser to extract specs from the DDR XML. The parser auto-detects multi-file solutions — if the directory contains multiple `FMPReport type="Report"` XMLs, all are parsed and merged:

```bash
python3 ~/.claude/skills/migrate-filemaker/scripts/parse_ddr.py $ARGUMENTS
```

If the script is not at the personal skills path, try the project-local path:

```bash
python3 .claude/skills/migrate-filemaker/scripts/parse_ddr.py $ARGUMENTS
```

If `specs/` already exists with all 9 JSON files (including `00_topology.json`), skip parsing and use the existing specs. Confirm with the user: "Found existing specs — using those. Re-run the parser if you want fresh extraction."

### Step 1.2: Verify Extraction Quality

Verify the parser output before proceeding:
1. **Topology** (`00_topology.json`): Confirm file count matches expectations. For multi-file solutions, verify cross-file references are resolved (check `unresolved_references` is empty or only has expected missing files)
2. Tables have fields properly separated into `fields`, `calculated`, `summary`, `globals`
3. Table occurrences all have a non-null `base_table`. For multi-file solutions, TOs with `external_file_reference` should have `resolved_source_file`
4. Relationships have join predicates with both left and right field names
5. Major layouts have populated fields/portals/buttons arrays
6. Scripts have parsed steps with params (not just step names). Cross-file script calls should have `external_file` in params
7. Value lists have their entries or source fields
8. Custom functions have calculation text

If any check fails, report the issue and ask whether to continue or fix first.

### Step 1.3: Analyze & Produce App Summary

Read all 8 spec files and produce `migration/00_app_summary.md` using the template structure. The analysis must include:

**Application Profile:**
- Derive the app name from the DDR filename or table naming patterns
- For multi-file solutions: note the file structure (e.g., "UI + Data separation file") and which tables belong to which file
- Infer the domain/purpose from table names, field names, and script names
- Calculate a complexity score using these thresholds:
  - **Simple:** <5 real tables, <10 scripts, <5 layouts
  - **Medium:** 5–15 real tables, 10–50 scripts, 5–20 layouts
  - **Complex:** 15–30 real tables, 50–150 scripts, 20–50 layouts
  - **Enterprise:** >30 real tables, >150 scripts, >50 layouts
- Count "real tables" as those with at least one schema field (not globals-only tables)

**Data Model Summary:**
- List each real table with its schema field count, calculated field count, and record count
- Identify the core entity tables vs. junction/lookup tables
- Note any tables that are globals-only (app-state tables, not real data)
- Summarize relationship graph: key joins, one-to-many patterns, self-joins

**Feature Map:**
- Group scripts by their `group` path to identify functional domains
- Map each domain to likely application features (e.g., "Invoice Scripts" → invoicing)
- Note scripts that are clearly UI-only (navigation, dialog) vs. business logic
- Identify any script patterns suggesting integrations (email, export, API calls)

**UI Summary:**
- Count layouts by table assignment
- Identify list/detail layout pairs
- Note layouts with portals (master-detail patterns)
- Flag layouts with many buttons (complex user workflows)

**Security Model:**
- List privilege sets and their access levels
- Note any extended privileges
- Count active vs. inactive accounts

**Red Flags** (items that will need special attention during migration):
- Complex unstored calculations that reference related data
- Heavy use of global fields for state management
- Container fields (file storage)
- Cross-file script calls (scripts calling into other FM files — tightly coupled multi-file logic)
- Unresolved external file references (DDR missing for a referenced file)

**Specialized Business Logic Detection:**

Most scripts in a FileMaker solution are generic app plumbing (navigation, CRUD, dialogs, simple approval flows) that can be recreated from the app type and data model alone. But some scripts contain domain-specific logic that is unique to the business — pricing algorithms, compliance rules, custom allocation engines, etc. These need special attention during migration because they can't be inferred.

Detect specialized business logic scripts using these signals (in priority order):

1. **Custom function calls in script calculations** — Cross-reference the custom functions spec (`08_custom_functions.json`) against script step calculations. If a script's Set Variable or Set Field calculations reference custom functions by name, flag it. Custom functions are almost always purpose-built domain logic.
2. **ExecuteSQL steps** — Any script containing an ExecuteSQL step is doing hand-crafted data operations beyond standard FileMaker. Always flag.
3. **Multi-table writes** — If a script does Set Field against 3+ different base tables (resolve table occurrences to base tables), it's orchestrating a multi-entity transaction. Flag it.
4. **Calculation density** — If >40% of a script's steps are Set Variable/Set Field with non-trivial calculations (containing math operators like `+`, `-`, `*`, `/`, or functions like `Round`, `Case` with multiple branches, nested function calls), it's implementing an algorithm, not plumbing.

**Filter out plumbing before scoring** — exclude scripts matching these patterns:
- Script groups named: Navigation, Nav, UI, Utility, Debug, Startup, Triggers, or similar
- Script names matching: "Go To", "Navigate", "Open", "Close", "Toggle", "Show", "Hide", "Refresh"
- Scripts that are only Perform Script calls (dispatchers/routers)
- Scripts where all steps are navigation + one dialog

**Group flagged scripts by functional domain** (using script group paths and table targets) and present them in the app summary as a dedicated section:

> **Specialized Business Logic**
>
> Found N scripts across M functional areas that contain domain-specific logic requiring careful migration:
>
> 1. **[Domain name]** — N scripts, references custom functions `FuncA`, `FuncB`. [Brief description of what the logic appears to do based on function names, field targets, and calculation content.]
> 2. **[Domain name]** — N scripts with ExecuteSQL-based [operation]. Writes across tables: X, Y, Z.
> 3. ...
>
> These will be explored in detail during Discovery.

If no specialized business logic is detected, note: "No specialized business logic detected — all scripts appear to be standard app plumbing that can be recreated from the data model and app type."

Present the summary to the user before proceeding.

---

## Phase 2: Discovery

This phase is interactive. Ask questions in small conversational groups (2–3 questions at a time), not as a survey dump. Adapt follow-up groups based on earlier answers. Skip questions that become irrelevant.

Use the AskUserQuestion tool for each group with appropriate options. Allow "You decide" / "No preference" as valid answers.

### Group 1 — Goals & Scope

Ask about:
1. **Migration driver:** What's motivating the move away from FileMaker? (Licensing costs, scalability limits, web/mobile access, team growth, vendor lock-in, other)
2. **Rebuild scope:** Full rebuild of all features, or partial? Any features to drop or simplify?
3. **Priority:** What's the single most important thing the new system must do well?

### Group 2 — Users & Scale

Ask about:
1. **Current users:** How many concurrent users today? Expected growth?
2. **Access patterns:** Desktop only, or also mobile/tablet? Need offline capability?
3. **User roles:** How many distinct roles/permission levels? (Reference the privilege sets found in Phase 1)

### Group 3 — UI Style & Design

Ask about:
1. **Screenshots of current FM app:** Ask the user to provide screenshots of their current FileMaker layouts — especially the most-used screens. Use the Read tool to view any provided image files. Note what works and what doesn't about the current UI from the user's perspective.
2. **Desired UI style:** What visual direction do they want? Options:
   - **Clean & minimal** — lots of whitespace, simple forms, modern SaaS look
   - **Data-dense & dashboard-heavy** — tables, charts, dense information display
   - **Match current FM look** — keep it familiar, minimize user retraining
   - **Something different entirely** — ask them to describe or provide references
3. **Reference apps or sites:** Ask for screenshots or links to any apps, websites, or products whose look and feel they admire. These become the design north star for the frontend build.

Record which screenshots were provided and note key observations: layout density, color usage, navigation patterns, form complexity. These feed directly into the Frontend and CSS/Component Library recommendations in Phase 3 and the UI Spec in Phase 4.

### Group 4 — Technical Preferences

Ask about:
1. **Team skills:** What languages/frameworks does your team know? (Python, JavaScript/TypeScript, Go, etc.)
2. **Stack preferences:** Any strong preferences or requirements? (e.g., must use PostgreSQL, prefer React, need Docker)
3. **Deployment target:** Cloud (which provider?), on-premise, or hybrid?

### Group 5 — Constraints

Ask about:
1. **Timeline:** When do you need this running? Is there a hard deadline?
2. **Budget:** Any budget constraints for hosting/infrastructure?
3. **Parallel operation:** Will the FM system run alongside the new one during transition?

*Skip Group 5 if the user indicated in Group 1 that this is exploratory / no timeline pressure.*

### Group 6 — Data & Integrations

Ask about:
1. **Data migration:** Need to migrate existing records? How many records in the largest table? (Reference record counts from Phase 1)
2. **External integrations:** Any connections to external systems (email, payment, other databases, APIs)?
3. **Reporting:** Any critical reports that must be replicated?

*Skip if Phase 1 shows a simple app with <1000 total records and no integration scripts.*

### Group 7 — Specialized Business Logic

*Only ask this group if Phase 1 detected specialized business logic scripts.*

Present the flagged script groups from the App Summary and ask about each domain:

> "I found [N] areas with specialized business logic that can't be inferred from the app type:
>
> 1. **[Domain]** — [brief description from Phase 1 detection]
> 2. **[Domain]** — [brief description]
> ...
>
> For each of these, can you describe the business rules? Specifically:
> - What is this logic supposed to accomplish?
> - Are the rules fixed, or do they change (e.g., pricing tiers updated annually)?
> - Must the rules be preserved exactly, or is this an opportunity to simplify?"

After discussing the flagged scripts, ask:

> "Are there any other scripts or business rules in the system that are critical to how your business operates — things that wouldn't be obvious from the data model? For example, custom calculations, compliance rules, or specialized workflows that took significant effort to build."

Record the answers with enough detail to drive the Phase 4 business logic mapping — capture the *why* behind the logic, not just the *what*.

*Skip if Phase 1 found no specialized business logic AND the app complexity is Simple or Medium.*

### Save Discovery Results

Write all answers to `migration/01_discovery_answers.md` using the template structure. Include the raw answers and any inferences drawn from the conversation.

---

## Phase 3: Recommend

Analyze the specs (Phase 1) and discovery answers (Phase 2) together. Consult the [Tech Stack Decision Matrix](reference/tech-stack-decision-matrix.md) for scoring guidance.

Produce `migration/02_recommendations.md` using the template structure:

### 3.1: Tech Stack Selection

For each layer, recommend a **primary** choice and one **alternative**, with reasoning:

- **Database:** PostgreSQL vs. MySQL vs. SQLite — based on complexity, scale, feature needs
- **Backend Framework:** Based on team skills, complexity, ecosystem
- **Frontend Framework:** Based on UI complexity, mobile needs, team skills
- **Authentication:** Based on security model complexity, user count
- **Deployment:** Based on budget, scale, team ops experience

### 3.2: Architecture Pattern

Choose one with justification:
- **Monolith:** Simple apps, small teams, fast to build
- **Modular Monolith:** Medium complexity, clear domain boundaries, easy to split later
- **Microservices:** Only if genuinely needed (high scale, multiple teams, independent deployment)

Default recommendation should be **modular monolith** for most FileMaker migrations — they are typically single-team applications with clear domain boundaries.

### 3.3: Migration Strategy

Recommend one:
- **Phased:** Build core features first, migrate data, add remaining features iteratively. Lower risk. Preferred for most FM migrations.
- **Big Bang:** Build everything, switch over at once. Only for very simple apps or hard deadlines.

### 3.4: Feature Priority

Order the functional domains identified in Phase 1 by migration priority:
1. Core data management (CRUD for main entities)
2. Business logic (scripts that enforce rules)
3. Reporting and views
4. User management and auth
5. Integrations
6. Nice-to-have features

### Present & Adjust

Present the full recommendation document to the user. Ask:
> "Do these recommendations look right? Anything you'd like me to adjust before I generate the detailed migration plan?"

Incorporate any feedback before proceeding to Phase 4.

---

## Phase 4: Plan

Generate the detailed rebuild artifacts. Consult the reference documents for translation patterns:
- [Schema Translation Guide](reference/schema-translation-guide.md) for data types and patterns
- [Script Translation Patterns](reference/script-translation-patterns.md) for business logic mapping
- [FileMaker Concepts](reference/filemaker-concepts.md) for concept mapping

### 4.1: Migration Plan (`migration/03_migration_plan.md`)

Using the template, produce:
- **Phase breakdown** with clear milestones and dependencies
- **Effort estimates** per phase (relative sizing: S/M/L/XL, not hours)
- **Risk register** with mitigations
- **Data migration plan** (if applicable): extraction approach, transformation rules, validation strategy
- **Testing strategy** per phase
- **Rollback plan** if the new system has issues

### 4.2: Database Schema (`migration/04_database_schema.sql`)

Generate production-ready SQL DDL:
- For multi-file solutions, unify tables from all source files into a single database schema (use `source_file` to understand table ownership, but the target DB is one schema)
- Use the schema translation guide for type mapping
- Convert FM naming conventions (camelCase/spaces) to snake_case
- Add proper primary keys (`id SERIAL PRIMARY KEY` or `id UUID ...`)
- Add `created_at` and `updated_at` timestamps to all tables
- Create foreign key constraints from the relationships spec
- Create indexes for foreign keys and commonly-queried fields
- Add ENUM types or reference tables for value lists
- Include comments on columns derived from FM calculated fields (noting they become app logic)
- Skip globals-only tables (note them as application config)

### 4.3: API Design (`migration/05_data_operations_design.md`)

Using the template, produce:
- **RESTful endpoints** for each real table (standard CRUD)
- **Custom endpoints** derived from business-logic scripts
- **Authentication endpoints** based on the security model
- **Batch/import endpoints** if data migration is needed
- Group endpoints by domain (matching the feature map from Phase 1)

### 4.4: Business Logic Mapping

Within the migration plan, categorize every script (or script group) as one of:
- **Drop:** Navigation-only scripts, UI helpers that the new framework handles
- **API Endpoint:** Scripts that perform data operations triggered by user action
- **Service Function:** Background logic, validation rules, calculations
- **UI Handler:** Client-side logic (form validation, conditional visibility)

**Specialized business logic scripts** (flagged in Phase 1, explored in Phase 2 Group 7) get additional treatment beyond categorization. For each flagged domain:

1. **Document the business rules** in plain language using the user's descriptions from Discovery
2. **Trace the script logic** — walk through the actual parsed steps and calculations to produce pseudocode or a logic flowchart that captures the algorithm
3. **Map custom functions** used by these scripts — include the function's calculation text and translate it to a modern equivalent (e.g., a utility function signature with documented inputs/outputs)
4. **Specify the implementation target** — where this logic lives in the new system (database function, service layer function, API middleware, etc.) with enough detail that a developer can implement it without referencing the original FileMaker scripts
5. **Flag any ambiguity** — if the parsed script logic doesn't fully match the user's description from Discovery, or if calculations are too opaque to confidently translate, note it as requiring manual verification during implementation

### 4.5: Auth & Roles Mapping

Map FileMaker privilege sets to the new system's role model:
- Each privilege set → a role with defined permissions
- Map record-level access rules to row-level security or middleware checks
- Map layout access to route/page permissions

### 4.6: UI Spec (`migration/06_ui_spec.md`)

Using the template, produce a complete frontend specification that a developer can build from without referencing any other document. Draw from:
- **Discovery Group 3** (UI Style & Design) for design direction, screenshots, and reference apps
- **Phase 1 layout analysis** for the page inventory and component mapping
- **Phase 1 script analysis** for UI handlers and conditional logic
- [FileMaker Concepts](reference/filemaker-concepts.md) for FM-to-modern UI element mapping

The spec must include:
- **Design direction** summarizing the target visual style, referencing any screenshots or apps the user provided
- **Navigation structure** derived from FM menu layouts and script navigation patterns
- **Page inventory** mapping every user-facing FM layout to a route, component name, and page type
- **Component mapping** translating FM UI elements (portals, tab controls, slide controls, pop-overs, value lists) to their modern equivalents with notes on behavior
- **Form specs** for each data-entry layout: field-by-field with input type, validation rules, source (FM field or calculation), and any conditional visibility logic
- **Responsive requirements** based on the access patterns from Discovery Group 2

### Present Final Deliverables

Summarize what was generated and where to find each file:

```
migration/
  00_app_summary.md        ← Application analysis
  01_discovery_answers.md  ← Requirements gathered
  02_recommendations.md    ← Tech stack & architecture
  03_migration_plan.md     ← Phased rebuild plan
  04_database_schema.sql   ← Database DDL
  05_data_operations_design.md         ← API endpoint design
  06_ui_spec.md            ← Frontend UI specification
```

Suggest next steps:
1. Review all documents with the team
2. Set up the development environment with the recommended stack
3. Begin Phase 1 of the migration plan (core data model + CRUD)

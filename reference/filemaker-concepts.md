# FileMaker Concepts → Modern Equivalents

Use this reference when analyzing a FileMaker solution to understand what each FM construct maps to in a modern web stack.

## Core Concepts

| FileMaker Concept | What It Is | Modern Equivalent | Notes |
|---|---|---|---|
| Base Table | Physical data store | Database table | Direct 1:1 mapping |
| Table Occurrence (TO) | Named reference to a base table on the relationship graph | Query context / join alias | Multiple TOs can point to the same base table. In SQL, this is like table aliases in JOINs. TOs exist only in FM — they do not need a separate structure in the new system. |
| Field (Normal, stored) | Column in a table | Database column | Direct mapping. Convert FM data types per schema-translation-guide. |
| Field (Calculated, stored) | Column whose value is computed and stored | Computed/generated column or trigger | Use DB generated columns if the calculation is simple SQL. Otherwise, compute in the application layer. |
| Field (Calculated, unstored) | Value computed on access, not stored | Virtual column, view, or app-level getter | These are NOT stored in the database. Implement as a computed property or database view. |
| Summary Field | Aggregate (SUM, COUNT, AVG, etc.) | SQL aggregate query | Never a column. Implement as a query with GROUP BY. |
| Global Field | Single-value variable shared across sessions | App config, environment variable, session state, or Redis key | NOT a database column. Globals are used for many purposes in FM — analyze each one individually. |
| Repeating Field | Array of values in a single field | Normalize into a child table or use array column | Repeating fields are an anti-pattern. Prefer normalization. PostgreSQL supports array types if truly needed. |
| Container Field | Binary data (files, images, PDFs) | File storage (S3, local filesystem) + URL/path column | Store files externally, store the path/URL in the database. |

## Relationships & Graph

| FileMaker Concept | Modern Equivalent | Notes |
|---|---|---|
| Relationship (equi-join) | Foreign key constraint | `parent.id = child.parent_id` |
| Relationship (inequality join) | WHERE clause / filtered query | FM allows `>=`, `!=`, Cartesian joins. These become query filters, not FK constraints. |
| Relationship with "Allow creation" | Cascade insert behavior | Implement in app logic — inserting a child record from a parent context. |
| Relationship with "Delete related" | `ON DELETE CASCADE` | Map directly to FK constraint option. |
| Multi-predicate relationship | Compound join / composite key | Multiple join conditions become compound WHERE clauses or composite foreign keys. |
| Self-join relationship | Self-referencing foreign key | Same table, different alias. Common for hierarchies (parent-child). |

## User Interface

| FileMaker Concept | Modern Equivalent | Notes |
|---|---|---|
| Layout | Page / View / Route | Each layout typically maps to a route or page component. |
| Layout (Form View) | Detail/edit page | Single-record view → form component. |
| Layout (List View) | List/table page | Multi-record view → data table component with pagination. |
| Layout (Table View) | Spreadsheet-style grid | Rarely used. Map to a data grid component if needed. |
| Portal | Related records component / sub-table | Inline display of child records. Becomes a nested list/table component. |
| Tab Control | Tab component / tabbed interface | Direct UI component mapping. |
| Slide Control | Carousel / stepper / wizard | Multi-step form or content slider. |
| Button | Button / link / action trigger | Map to a UI button that calls an API endpoint or triggers client-side logic. |
| Pop-over | Popover / dropdown / modal | Small overlay UI. |
| Web Viewer | Iframe / embedded component | Rarely needs migration — evaluate if the embedded content is still needed. |
| Value List (on a field) | Dropdown / select / radio group | Custom value list → hardcoded options or ENUM. Field-based → dynamic query. |
| Conditional Formatting | CSS conditional classes / dynamic styles | Implement with conditional CSS classes in the component. |

## Scripts & Logic

| FileMaker Concept | Modern Equivalent | Notes |
|---|---|---|
| Script (data operation) | API endpoint / service function | Scripts that create/update/delete records become backend operations. |
| Script (navigation) | Client-side routing | Scripts that just go to layouts/records → router navigation. Usually dropped. |
| Script (UI interaction) | Event handler / UI logic | Show dialogs, set field values in the UI → client-side JavaScript. |
| Script (integration) | Service function / worker | Scripts that send email, call APIs, export data → backend service or job queue. |
| Script Trigger | Event listener / hook | On-entry, on-commit triggers → lifecycle hooks (beforeSave, afterLoad, etc.) |
| Script Parameter | Function parameter / API request body | FM passes a single text parameter (often JSON). Map to typed function args or request body. |
| Custom Function | Utility function / helper | Reusable calculation logic → shared utility module. |

## Security & Access

| FileMaker Concept | Modern Equivalent | Notes |
|---|---|---|
| Account | User record | Map to a users table with hashed password. |
| Privilege Set | Role | Each privilege set becomes a named role (admin, editor, viewer, etc.) |
| Record-level access | Row-level security (RLS) / authorization middleware | PostgreSQL has built-in RLS. Otherwise, implement in middleware. |
| Layout access | Route guards / page permissions | Control which pages/routes each role can access. |
| Script access | API endpoint authorization | Control which endpoints each role can call. |
| Extended Privilege | Feature flag / capability | Fine-grained permissions (e.g., "can export", "can use API"). |
| External Authentication | OAuth / LDAP / SSO integration | If FM used Active Directory or OAuth, map to the same provider. |

## Data Patterns

| FileMaker Pattern | What It Does | Modern Implementation |
|---|---|---|
| Audit trail via auto-enter | Creation/modification tracking | `created_at`, `updated_at`, `created_by`, `updated_by` columns + triggers or ORM hooks |
| Serial number auto-enter | Auto-incrementing ID | `SERIAL` / `IDENTITY` column or UUID primary key |
| Looked-up value | Copy value from related record | Denormalization — query the related table instead, or use a trigger if denorm is intentional |
| Auto-enter calculation | Set a default value | Column `DEFAULT` expression or application-layer default |
| Validation rule | Input constraint | Database `CHECK` constraint + frontend validation + API validation |
| Unique value validation | Uniqueness constraint | `UNIQUE` constraint on the column |
| Not empty validation | Required field | `NOT NULL` constraint + frontend required attribute |

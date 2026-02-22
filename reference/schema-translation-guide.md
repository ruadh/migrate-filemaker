# Schema Translation Guide

Rules and patterns for converting a FileMaker data model to a relational database schema.

## Data Type Mapping

### PostgreSQL (Recommended)

| FM Data Type | PostgreSQL Type | Notes |
|---|---|---|
| Text | `TEXT` or `VARCHAR(n)` | Use `TEXT` unless a max length is enforced by validation. Use `VARCHAR(n)` if FM has a max character validation. |
| Number | `INTEGER` | If the field has no decimal values and is used for IDs, counts, or flags. |
| Number | `NUMERIC(p,s)` or `DECIMAL(p,s)` | If the field stores money or precise decimals. Check FM field formatting for decimal places. |
| Number | `BIGINT` | If values may exceed 2 billion (rare in FM). |
| Number | `BOOLEAN` | If the field only contains 0/1 and is used as a flag. Check value lists and usage. |
| Date | `DATE` | Direct mapping. |
| Time | `TIME` | Direct mapping. FM stores time as seconds since midnight; PostgreSQL uses HH:MM:SS. |
| Timestamp | `TIMESTAMPTZ` | Always use timezone-aware timestamps. |
| Container | `TEXT` | Store the file URL/path, not the binary data. Use external file storage (S3, local disk). |

### MySQL Alternative

| FM Data Type | MySQL Type | Notes |
|---|---|---|
| Text | `VARCHAR(255)` or `TEXT` | MySQL requires length for VARCHAR. Use TEXT for long content. |
| Number | `INT` / `DECIMAL(p,s)` / `BIGINT` / `TINYINT(1)` | Same logic as PostgreSQL. |
| Date | `DATE` | Direct mapping. |
| Time | `TIME` | Direct mapping. |
| Timestamp | `DATETIME` | MySQL's DATETIME is timezone-naive. Use application-level TZ handling. |
| Container | `VARCHAR(500)` | File path/URL reference. |

### SQLite Alternative

| FM Data Type | SQLite Type | Notes |
|---|---|---|
| Text | `TEXT` | SQLite has flexible typing. |
| Number | `INTEGER` or `REAL` | Use INTEGER for whole numbers, REAL for decimals. |
| Date / Time / Timestamp | `TEXT` | Store as ISO 8601 strings. SQLite has no native date type. |
| Container | `TEXT` | File path/URL reference. |

## Naming Convention Translation

FileMaker uses varied naming (camelCase, spaces, prefixes). Convert to `snake_case` for the database.

### Rules

1. **Table names:** Lowercase, plural, snake_case
   - `InvoiceLineItems` → `invoice_line_items`
   - `The Sitting Room` → `sitting_rooms` (drop articles)
   - `tbl_Customers` → `customers` (drop Hungarian prefixes)

2. **Column names:** Lowercase, snake_case
   - `FirstName` → `first_name`
   - `Date Created` → `date_created` (but prefer `created_at`)
   - `fk_CustomerID` → `customer_id` (drop prefixes, keep the reference clear)
   - `z_SortOrder` → `sort_order` (drop utility prefixes)
   - `_pk_ID` → `id` (simplify primary key names)

3. **Foreign keys:** `{referenced_table_singular}_id`
   - `CustomerID` on Invoices → `customer_id`
   - `InvoiceID` on LineItems → `invoice_id`

4. **Boolean columns:** Prefix with `is_` or `has_`
   - `Active` → `is_active`
   - `Paid` → `is_paid`

## Primary Key Strategy

FileMaker often uses its internal record ID or a serial number field. Choose one approach:

### Option A: Serial Integer (Simple, Fast)
```sql
id SERIAL PRIMARY KEY  -- PostgreSQL
id INT AUTO_INCREMENT PRIMARY KEY  -- MySQL
```
Best for: Simple apps, small scale, no distributed systems.

### Option B: UUID (Distributed-Safe)
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()  -- PostgreSQL
id CHAR(36) PRIMARY KEY  -- MySQL (use app-generated UUIDs)
```
Best for: Apps that may sync data, have multiple write sources, or need globally unique IDs.

**Recommendation:** Use serial integers unless there's a specific need for UUIDs. FM's serial numbers map cleanly to `SERIAL`.

## Standard Columns

Add these to every table:

```sql
id          SERIAL PRIMARY KEY,
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

If the FM solution tracks created/modified by:
```sql
created_by  INTEGER REFERENCES users(id),
updated_by  INTEGER REFERENCES users(id)
```

## Pattern: Audit Fields

FM commonly has auto-enter fields for creation/modification tracking. These map directly:

| FM Field | SQL Column | Implementation |
|---|---|---|
| `CreationTimestamp` | `created_at TIMESTAMPTZ DEFAULT NOW()` | Database default |
| `ModificationTimestamp` | `updated_at TIMESTAMPTZ DEFAULT NOW()` | Update via trigger or ORM hook |
| `CreatedBy` / `AccountName (creation)` | `created_by INTEGER REFERENCES users(id)` | Set by application on insert |
| `ModifiedBy` / `AccountName (modification)` | `updated_by INTEGER REFERENCES users(id)` | Set by application on update |

## Pattern: Value Lists → ENUMs or Reference Tables

### Custom Value Lists (Static Options)

**Option A: PostgreSQL ENUM**
```sql
CREATE TYPE status_type AS ENUM ('Draft', 'Active', 'Archived');

ALTER TABLE documents ADD COLUMN status status_type NOT NULL DEFAULT 'Draft';
```
Use for: Short, stable lists that rarely change.

**Option B: CHECK Constraint**
```sql
ALTER TABLE documents
  ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'Draft'
  CHECK (status IN ('Draft', 'Active', 'Archived'));
```
Use for: Lists that may evolve but are still small.

**Option C: Reference Table**
```sql
CREATE TABLE statuses (
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(50) NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);
```
Use for: Lists managed by users, or lists with additional metadata.

### Field-Based Value Lists (Dynamic Lookups)

These are just queries against the source table:
```sql
-- FM: Value list showing CustomerName from Customers table
SELECT DISTINCT name FROM customers ORDER BY name;
```

No special schema needed — implement as a query in the API.

## Pattern: Repeating Fields → Normalization

FM repeating fields store multiple values in one field (an anti-pattern). Normalize into a child table:

**FM:** `PhoneNumber` (repeating, 3 reps) on `Contacts`

**SQL:**
```sql
CREATE TABLE contact_phones (
  id          SERIAL PRIMARY KEY,
  contact_id  INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  phone       VARCHAR(20) NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0
);
```

If there are only 2–3 fixed repetitions with known meanings, consider separate columns instead:
```sql
ALTER TABLE contacts ADD COLUMN phone_home VARCHAR(20);
ALTER TABLE contacts ADD COLUMN phone_work VARCHAR(20);
ALTER TABLE contacts ADD COLUMN phone_mobile VARCHAR(20);
```

## Pattern: Global Fields → Application Config

FM globals are NOT database columns. Map them by usage:

| Global Usage | Modern Implementation |
|---|---|
| App settings (company name, defaults) | Config table (key-value) or environment variables |
| Session state (current user, filter) | Session/cookie data or frontend state |
| Temporary variables (dialog inputs) | Frontend component state |
| Report parameters (date range, filter) | API query parameters |
| Constants (tax rate, version) | Application constants or config file |

## Pattern: Calculated Fields

| Calc Type | Implementation |
|---|---|
| Simple formula (field1 + field2) | Database generated column: `total NUMERIC GENERATED ALWAYS AS (quantity * unit_price) STORED` |
| Formula referencing related data | Application-layer computed property or database view |
| Conditional logic (Case/If) | Application layer or CASE expression in a view |
| Text formatting (concatenation) | Application layer — full name, display strings, etc. |
| Aggregate (Sum of related) | SQL query with JOIN and aggregate function |

## Pattern: Relationships → Foreign Keys

### Simple Equi-Join
```
FM:  Customers::CustomerID = Invoices::CustomerID
SQL: invoices.customer_id REFERENCES customers(id)
```

### With Delete Related
```
FM:  Delete related records in Invoices when Customer deleted
SQL: ON DELETE CASCADE
```

### With Allow Creation
```
FM:  Allow creation of related Invoices from Customers
SQL: No schema impact — this is application behavior (UI allows adding child records)
```

### Inequality / Cartesian Join
```
FM:  Table1::Date >= Table2::StartDate
SQL: Not a foreign key. Implement as a query JOIN with WHERE clause.
```

## Index Strategy

Create indexes for:
1. **All foreign keys** — essential for JOIN performance
2. **Fields used in FM finds/searches** — identify from script steps and layout search fields
3. **Unique fields** — any field with unique validation
4. **Sort fields** — fields commonly used for sorting (check script sort steps)

```sql
CREATE INDEX idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
CREATE UNIQUE INDEX idx_customers_email ON customers(email);
```

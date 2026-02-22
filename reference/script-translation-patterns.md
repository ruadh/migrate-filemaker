# Script Translation Patterns

Patterns for converting FileMaker script steps into modern code. Use this reference when categorizing scripts and generating the business logic mapping in Phase 4.

## Script Step → Code Mapping

### Data Operations

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `Set Field [table::field; value]` | `UPDATE table SET field = value WHERE id = ?` | Backend: SQL update. Frontend: form field binding. |
| `New Record/Request` | `INSERT INTO table (...) VALUES (...)` | API: POST endpoint. |
| `Delete Record/Request` | `DELETE FROM table WHERE id = ?` | API: DELETE endpoint. Confirm before executing. |
| `Delete All Records` | `DELETE FROM table` or `TRUNCATE` | Rare. Add confirmation and authorization check. |
| `Commit Records/Requests` | Transaction commit / save | FM auto-saves unless scripted. In web apps, this is the POST/PUT request. |
| `Revert Record/Request` | Discard form changes | Frontend: reset form to original values. |
| `Duplicate Record/Request` | `INSERT INTO ... SELECT ... FROM ...` | API: POST endpoint that copies from an existing record. |
| `Set Field By Name [field; value]` | Dynamic property assignment | Backend: parameterized update. Use with caution — validate field names. |
| `Replace Field Contents` | `UPDATE table SET field = value` (no WHERE) | Bulk update. Implement as a batch API endpoint with authorization. |

### Navigation

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `Go to Layout [name]` | `router.push('/route')` | Client-side navigation. Often dropped — the new app's routing handles this. |
| `Go to Record [First/Last/Next/Previous]` | Pagination / record navigation | Implement with query params: `?page=1&limit=20`. |
| `Go to Related Record [table; layout]` | Navigate to filtered list | `router.push('/related-items?parent_id=123')`. |
| `Go to Field [field]` | Focus input | `document.getElementById('field').focus()` — usually dropped. |
| `Close Window` / `Close File` | Close tab/modal | Usually dropped or becomes `router.back()`. |
| `New Window` | Open new tab/modal | Modal dialog or `window.open()`. Evaluate if truly needed. |
| `Select Window` | Focus window/tab | Usually dropped. |

### Find/Query Operations

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `Enter Find Mode` | Build query parameters | Frontend: open search form. |
| `Set Field [in find mode]` | Add WHERE clause | Each Set Field in find mode adds a search criterion. |
| `Perform Find` | `SELECT ... WHERE ...` | API: GET endpoint with query parameters. |
| `Extend Found Set` | `OR` clause | Append additional WHERE conditions with OR. |
| `Constrain Found Set` | `AND` clause | Append additional WHERE conditions with AND. |
| `Show All Records` | Remove WHERE clause | API: GET without filters. |
| `Sort Records` | `ORDER BY` clause | API: query parameter `?sort=field&order=asc`. |
| `Omit Record` | `NOT` in WHERE | Exclude specific records from results. |
| `Show Omitted Only` | Invert selection | Rarely needed. Implement as an inverted query. |

### Control Flow

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `If [condition]` / `Else If` / `Else` / `End If` | `if/else if/else` | Direct mapping to any language's conditional. |
| `Loop` / `Exit Loop If [condition]` / `End Loop` | `for`/`while` loop with `break` | Direct mapping. In modern code, prefer `for...of` or `array.forEach`. |
| `Perform Script [name; parameter]` | Function call or API call | If same module: direct function call. If different service: API call. |
| `Perform Script on Server` | Backend service call / job queue | This was already a server-side operation. Map to an API endpoint or background job. |
| `Exit Script [result]` | `return value` | Function return statement. |
| `Halt Script` | `return` (stop all execution) | Exit current operation. In web apps, stop the request handler. |
| `Set Variable [$var; value]` | `const var = value` | Local variable assignment. |
| `Set Variable [$$var; value]` | Application/session state | `$$` globals → session storage, app state, or module-level variable. |

### User Interface

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `Show Custom Dialog [title; message]` | Modal dialog / alert / confirm | Frontend: modal component with buttons. |
| `Show/Hide Toolbars` | Toggle UI elements | Usually dropped. Implement with CSS/component visibility. |
| `Freeze Window` / `Refresh Window` | Loading state | Show spinner or loading overlay while processing. |
| `Scroll Window` | `window.scrollTo()` | Rarely needed. |
| `Beep` | Notification sound | Usually dropped. Use toast notifications instead. |
| `Set Zoom Level` | CSS zoom/scale | Usually dropped. |
| `Allow User Abort` | Cancellation support | Implement with AbortController or cancel button. |
| `Set Error Capture` | Try/catch | Error handling wrapper. |

### Integrations

| FM Script Step | Modern Equivalent | Context |
|---|---|---|
| `Send Mail [To; Subject; Body]` | Email service (SMTP, SendGrid, etc.) | Backend: email sending service/function. |
| `Export Records` | Data export endpoint | API: GET endpoint returning CSV/Excel. |
| `Import Records` | Data import endpoint | API: POST endpoint accepting CSV/Excel upload. |
| `Insert from URL` | HTTP client request (`fetch`, `axios`) | Backend: call external API. |
| `Open URL` | `window.open(url)` or redirect | Frontend: external link. |
| `Execute SQL` | Direct SQL query | Already using SQL — map the query directly. Check for injection risks. |
| `Print Setup` / `Print` | Print stylesheet / PDF generation | Frontend: CSS `@media print`. Backend: PDF generation library. |
| `Save Records as PDF` | PDF generation | Backend: use a PDF library (Puppeteer, wkhtmltopdf, etc.) |
| `Save Records as Excel` | Excel export | Backend: use an Excel library (ExcelJS, openpyxl, etc.) |

## Multi-Step FM Idioms

These are common patterns in FM scripts that combine multiple steps into a single logical operation.

### Find Related Records
```
FM Pattern:
  Go to Layout ["InvoiceLines"]
  Enter Find Mode
  Set Field [InvoiceLines::InvoiceID; $invoiceId]
  Perform Find

Modern Equivalent:
  GET /api/invoice-lines?invoice_id=123

  // Backend
  async function getInvoiceLines(invoiceId) {
    return db.query('SELECT * FROM invoice_lines WHERE invoice_id = $1', [invoiceId]);
  }
```

### Create Record with Fields
```
FM Pattern:
  Go to Layout ["Invoices"]
  New Record/Request
  Set Field [Invoices::CustomerID; $customerId]
  Set Field [Invoices::Date; Get(CurrentDate)]
  Set Field [Invoices::Status; "Draft"]
  Commit Records/Requests

Modern Equivalent:
  POST /api/invoices
  Body: { "customer_id": 123, "status": "Draft" }

  // Backend
  async function createInvoice(data) {
    // date defaults to NOW() via database default
    return db.query(
      'INSERT INTO invoices (customer_id, status) VALUES ($1, $2) RETURNING *',
      [data.customer_id, data.status ?? 'Draft']
    );
  }
```

### Loop Through Found Set
```
FM Pattern:
  Go to Record [First]
  Loop
    Set Field [Records::Processed; 1]
    Go to Record [Next; Exit after last]
  End Loop

Modern Equivalent:
  // Batch update — single query, no loop needed
  async function markAllProcessed(recordIds) {
    return db.query(
      'UPDATE records SET is_processed = true WHERE id = ANY($1)',
      [recordIds]
    );
  }
```

### Scripted Find with Multiple Criteria
```
FM Pattern:
  Enter Find Mode
  Set Field [Orders::Status; "Open"]
  Set Field [Orders::Date; ">" & $startDate]
  New Record/Request  (extends found set)
  Set Field [Orders::Status; "Pending"]
  Perform Find
  Sort Records [Orders::Date; ascending]

Modern Equivalent:
  GET /api/orders?status=Open,Pending&date_after=2024-01-01&sort=date&order=asc

  // Backend
  async function findOrders({ statuses, dateAfter, sort, order }) {
    return db.query(
      `SELECT * FROM orders
       WHERE status = ANY($1)
         AND order_date > $2
       ORDER BY ${sort} ${order}`,
      [statuses, dateAfter]
    );
  }
```

### Conditional Navigation with Dialog
```
FM Pattern:
  Show Custom Dialog ["Confirm"; "Delete this record?"]
  If [Get(LastMessageChoice) = 1]
    Delete Record/Request
    Go to Layout ["RecordList"]
  End If

Modern Equivalent:
  // Frontend
  async function handleDelete(recordId) {
    const confirmed = await showConfirmDialog('Delete this record?');
    if (confirmed) {
      await api.delete(`/records/${recordId}`);
      router.push('/records');
    }
  }
```

### Transaction Pattern (Set Error Capture + Commit)
```
FM Pattern:
  Set Error Capture [On]
  Set Field [Account::Balance; Account::Balance - $amount]
  Set Field [Transaction::Amount; $amount]
  Commit Records/Requests
  If [Get(LastError) ≠ 0]
    Revert Record/Request
    Show Custom Dialog ["Error"; "Transaction failed"]
  End If

Modern Equivalent:
  async function processTransaction(accountId, amount) {
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'UPDATE accounts SET balance = balance - $1 WHERE id = $2',
        [amount, accountId]
      );
      await client.query(
        'INSERT INTO transactions (account_id, amount) VALUES ($1, $2)',
        [accountId, amount]
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw new Error('Transaction failed');
    } finally {
      client.release();
    }
  }
```

## Script Categorization Guide

When analyzing scripts for the business logic mapping, categorize each script or script group:

### Drop
Scripts that only do navigation or UI manipulation that the new framework handles automatically:
- Go to Layout (routing)
- Go to Record First/Last/Next/Previous (pagination)
- Freeze/Refresh Window (loading states)
- Show/Hide toolbars
- Close Window
- Scripts with only navigation steps

### API Endpoint
Scripts that perform data operations triggered by user action:
- Create/Update/Delete record workflows
- Search/filter operations
- Export operations
- Any script called by a button that changes data

### Service Function
Backend logic that enforces rules or performs background work:
- Validation scripts
- Calculation/aggregation scripts
- Email sending
- Scheduled operations
- Data synchronization
- Any script called by "Perform Script on Server"

### UI Handler
Client-side logic for form behavior and user interaction:
- Form field validation before submit
- Conditional field visibility
- Auto-fill based on selection
- Dialog/modal flows
- Any script attached to a script trigger (OnObjectEnter, OnObjectModify, etc.)

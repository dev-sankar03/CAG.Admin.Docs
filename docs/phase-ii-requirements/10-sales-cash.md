# 10 — Sales Cash Module: Payment Type, Print Receipt, Audit (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Sales Cash Module (Milestone 1)*
> Modules touched: Sales Cash (`api/salescashentry`, `api/salescashdetails`).
> Related docs: [sales cash](../implementation-impact-analysis.md),
> [audit convention](../database-access-layer.md),
> [file/export headers](../authentication-authorization.md).

## 1. Requirement (as specified)

- Add **Payment Type**: Cash / Online.
- Include **Payment Type in the Export** report.
- Add a **Print Receipt** option for each Sales Cash entry.
- Show **last 6 months** data.
- Created-by + time already exist; also record **Updated By** and **Updated Date/Time** on edit.
- **Receipt contents:** Name, Mobile Number, Company Code, Rider ID, Client ID, Payment Method,
  Received By (supervisor who entered it), plus **company logo + name** ("Captainasad Group of
  Companies").

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **Sales Cash page** (`(pages)/Sales-Cash/**`) — add a **Payment Type** field (Cash/Online) on the
  entry form and as a grid column; add a **Print Receipt** action per row; default the list to
  **last 6 months**.
- **Receipt** — a printable view/component (logo + company name + the listed fields). Print via
  browser print or a generated PDF.
- Show Updated By/time in the row detail.

### API / DB (`CAG.Admin.API`)
- **`SalesCashEntry`** — add a `PaymentType` column (Cash/Online). ⚠️ **Verified against code:** this
  table has **only `CreatedBy` / `CreatedAt` / `ExportedAt`** — it does **not** have `UpdatedBy` /
  `UpdatedAt`. So the audit requirement means **adding** `UpdatedBy` + `UpdatedAt` columns here (not
  merely writing existing ones), plus populating them on edit. (`CreatedBy`/`CreatedAt` already
  exist, matching the doc's "created by + time already there".)
- **Export** (`api/salescashentry/export`) — add the Payment Type column.
- **Receipt data** — an endpoint (or reuse the entry GET) returning the receipt fields; Received-By =
  the entry's `CreatedBy` resolved to a user name.
- **Last-6-months** — a date filter on the list query (default window).

### Cross-cutting
- Audit (Updated By/time) is the same pattern as [09](09-vacation-management.md), [12](12-company-expenses.md),
  [13](13-mandoob-activities.md) — one shared approach. Note the audit columns are **inconsistent
  across tables** today (e.g. `SalesCashEntry` lacks `UpdatedBy/At`), so "add if missing" is part of
  each of these tickets, not a safe assumption.
- Receipt branding (logo + name) — reuse the company logo asset flow if per-company, or a static
  app logo for the group.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Print Receipt — browser print of an HTML receipt, or a downloadable PDF?
  💡 HTML print view (fast, no new dependency); offer PDF later if they need to email receipts.
  Note: a browser print component is simplest and needs no server render.
- **Q:** Receipt logo — the **group** logo (static) or the **partner company** logo (per entry)?
  💡 The doc says "our company logo… Captainasad Group of Companies" → use the **static group logo +
  name**, not the per-company logo. Confirm.
- **Q:** Is Payment Type required on every entry (including historical rows with none)?
  💡 Required for new entries; default historical rows to "Cash" (or "Unknown") via migration.
  Confirm the backfill value.

### API / Data-side
- **Q:** "Received By (supervisor name who entered the payment)" — is that `CreatedBy` resolved to a
  name, or a separate field?
  💡 Resolve `CreatedBy` (already stored) to the user's name — no new field needed.
- **Q:** Where do Name / Mobile / Company Code / Rider ID / Client ID on the receipt come from — the
  entry, or joined from the rider/client?
  💡 Join from the rider/client at print time by the entry's rider reference; don't denormalise onto
  the entry (keeps the receipt current if the rider's details change — confirm that's desired vs a
  point-in-time snapshot).
- **Q:** "Last 6 months" — is that a hard cap on the query, or just the default view with an option to
  see more?
  💡 Default view = last 6 months, with a date-range filter to widen — avoids hiding older data
  entirely.
- **Q:** Export — CSV (current) plus the new column, or also add Payment Type-based totals?
  💡 Add the column now; a Cash-vs-Online summary can follow if asked.

### Business / Product
- **Q:** Exact receipt layout — provide the sample referenced in the doc.
  💡 Client to share the sample image; we match it. Fields are already enumerated above.
- **Q:** Are receipts numbered (a sequential receipt no.) for accounting?
  💡 Suggest a receipt number (reuse the `IdGenerator` pattern, e.g. `SCR{yy}{0000}`) for
  traceability; confirm need.

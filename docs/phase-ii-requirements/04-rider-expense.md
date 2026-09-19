# 04 — Rider Expense: History, Bulk Import, Table View, +/- (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Rider Expense (Milestone 1)*
> Modules touched: Rider Expense (`api/rider-expense`), Rider detail (Expense tab), Payroll,
> Performance page ([03](03-rider-performance-page.md)).
> Related docs: [expense migration](../database-access-layer.md),
> [rider-management §6 expenses](../rider-management.md),
> [modules index — rider expense](../implementation-impact-analysis.md).

## 1. Requirement (as specified)

- Add **Rider Expense History**.
- Add a **Bulk Import** option.
- Change UI to a **Table View**.
- Add **'Add'** and **'Import'** buttons.
- Support **+ / −** operations in Rider Expense.

## 2. Impact & Changes

> ✅ **Good news: the backend is already partly scaffolded.** The committed migration
> `Database/Migrations/2026-09-06_ExpenseModule.sql` already created `RiderExpense` (a per-rider
> **ledger** with a **signed** `Amount DECIMAL(12,2)` — the "+/−" requirement), `RiderExpenseCategory`
> (master, seeded with the 12 legacy categories), and `RiderExpenseImportLog` (bulk-import batches).
> The API already exposes `api/rider-expense` (`category/getall`, `getall/{riderId}`, `{id}`,
> `import`). See [data-model](../database-access-layer.md) and
> [modules index](../implementation-impact-analysis.md). Much of this requirement is UI + wiring,
> not greenfield.

### UI (`CAG.Admin.UI`)
- **Expense tab → Table View** (`components/details/rider/expense-tab.tsx`,
  `rider-expense-import.tsx` already exist). Render `RiderExpense` rows as a table (date, category,
  amount ±, reference, remarks, source, added-by).
- **Add button** → a create-expense modal (category dropdown from `RiderExpenseCategory`, signed
  amount, date, reference, remarks, attachment).
- **Import button** → bulk upload (CSV/XLSX), showing the `RiderExpenseImportLog` result
  (total/success/failure/errors).
- **History** = the ledger itself (immutable rows over time), distinct from the legacy flat expense
  fields.

### API / DB (`CAG.Admin.API`)
- Verify/finish `RiderExpenseService` + `RiderExpenseRepository` CRUD (add, list, update, delete)
  and the `import` path against the existing tables.
- **Bulk import** parser → validate rows → insert `RiderExpense` → write `RiderExpenseImportLog`.
- **+/−**: already native (`Amount` is signed) — enforce the convention (positive = deduction owed,
  negative = credit/incentive) in validation.

### Cross-cutting
- ⚠️ **Two expense concepts coexist** — the legacy flat `int` columns on `Rider`
  (`PUT api/rider/{id}/expense`) and this new ledger. The migration's own note plans to backfill and
  **retire the flat columns**. This requirement is the trigger to do that cutover.
- **Feeds** [03](03-rider-performance-page.md) (Expense Ledger + Incentive sections read this table)
  and the Payroll deduction calc.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** History — show all-time, or paged/filtered by month + category?
  💡 Table with month + category filters, newest first; reuse `GenericPage` server pagination.
- **Q:** Are ledger rows editable/deletable after creation, or append-only (a true ledger)?
  💡 Append-only for imported rows; allow edit/delete only for manual entries by privileged roles,
  and record the audit. A true ledger is safer for payroll integrity.
- **Q:** Add-expense form — which fields are mandatory? (Category, Amount, Date at minimum.)
  💡 Mandatory: Category, Amount (signed), Entry Date. Optional: Reference, Remarks, Attachment.
- **Q:** How is +/− entered — a sign toggle, or a "type" (Charge/Credit) that sets the sign?
  💡 A Type toggle (Charge = +, Credit = −) that writes the signed `Amount` — clearer than raw
  negative numbers for data-entry staff.

### API / Data-side
- **Q:** Bulk-import file format & columns — what template? Keyed by Rider ID or Civil ID?
  💡 XLSX template: RiderId, EntryDate, Category, Amount(±), ReferenceNo, Remarks. Match rider by
  `RiderId`; report unmatched rows in `RiderExpenseImportLog.ErrorDetails`. Provide a downloadable
  template.
- **Q:** Is the flat-column → ledger **backfill** in scope for this milestone, or deferred?
  💡 Do the backfill now (the migration already specifies it: one row per non-zero flat column, dated
  `Rider.UpdatedAt`, category matched by name, `Source='Manual'`) so Performance/Payroll read one
  source. Then stop writing the flat columns.
- **Q:** `CompanyId` is `NOT NULL` on `RiderExpense` — where does it come from for a rider with a null
  company?
  💡 Snapshot the rider's current company at entry time; if the rider has none, block the entry or
  require selecting one (the FK is NOT NULL).
- **Q:** Attachment storage — reuse the FTP `Document`/`FileService` flow, or the
  `RiderExpense.AttachmentPath` column directly?
  💡 Reuse `FileService` (FTP) and store the returned path in `AttachmentPath`; don't invent a second
  upload path.

### Business / Product
- **Q:** Who can add/import/delete expenses (role gating)?
  💡 Supervisors can add manual entries; import + delete restricted to Admin/Ops (ties to
  [14 #7](14-misc-changes.md) status-restriction work — build the permission check once).
- **Q:** Does an imported Incentive automatically surface in the Performance page's Incentive section?
  💡 Yes — the "Incentive" category filter drives [03](03-rider-performance-page.md) §6; confirm the
  category name matches the seed exactly.

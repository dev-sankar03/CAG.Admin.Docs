# 12 — Company Expenses Module (Milestone 2)

> Source: `CAG_Phase_II.docx` → *Company Expenses Module (Milestone 2)*
> Modules touched: **New Company Expenses module**, Dashboard/Finance Summary
> ([01](01-main-dashboard.md)).
> Related docs: [expense migration (rider)](../database-access-layer.md),
> [data-access masters](../database-access-layer.md), [dataviz](../implementation-impact-analysis.md).

## 1. Requirement (as specified)

A new **Expense module** with three areas: **Expense Entry**, **Expense List**, **Analysis
Dashboard**.

**Expense Entry screen fields:**
1. Date (enterable) · 2. Company (dropdown) · 3. Expense Category (dropdown) · 4. Amount (manual) ·
5. Payment Method (Cash / Bank / Online) · 6. Reference No (optional) · 7. Remarks (text) ·
8. Attachment (upload bill) · 9. Added By (name) · 10. Modified By (name, date, time) · 11. Save.

**Categories** (examples): Office Rent, Electricity, Internet, Vehicle Maintenance, Fuel, Mobile
Bills, Office Supplies, Staff Welfare, Marketing, Visa Expenses, Municipality, Government Fees,
Software Subscription, Insurance, Bank Charges, Miscellaneous.

- **Do not hardcode categories** — create an **Expense Categories master**; new categories added
  there appear automatically in the entry dropdown.

**Analysis Dashboard** — auto-calculated cards: Total Expenses (Today), Total Expenses (This Month),
Company-wise Expenses, Category-wise Expenses; charts: Company-wise Monthly Expenses, Category-wise
Expenses, Monthly Expense Trend. **Use company code, not company name.**

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **New module** (`(pages)/Finance/Company-Expenses/**` or a top-level Expenses area): Entry form,
  List (table, filters, export), Analysis Dashboard (cards + charts).
- **Expense Categories master** admin screen (add/edit categories).
- Charts follow [dataviz](../implementation-impact-analysis.md) conventions; company **code** as the axis/legend label.

### API / DB (`CAG.Admin.API`)
- **New tables:**
  - `CompanyExpenseCategory` — master (`Id`, `Name`, `IsActive`, audit). Mirrors the existing
    `RiderExpenseCategory` pattern from the [expense migration](../database-access-layer.md).
  - `CompanyExpense` — `Id`, `CompanyId`, `ExpenseCategoryId`, `EntryDate`, `Amount DECIMAL(12,2)`,
    `PaymentMethod`, `ReferenceNo`, `Remarks`, `AttachmentPath`, audit (`CreatedBy/At`, `UpdatedBy/At`).
- **New endpoints** `api/company-expense/*` (CRUD + list + import-optional) and
  `api/company-expense/category/*` (master), plus analysis-aggregation endpoints (company-wise,
  category-wise, monthly trend) — all **company-scoped**.
- **Attachment** via `FileService` (FTP), path in `AttachmentPath` — reuse, don't reinvent.

### Cross-cutting
- **Feeds [01](01-main-dashboard.md) Finance Summary** — Total Company Expenses, the category pie,
  and Net Profit all depend on this module. Sequence 12 before finishing 01's finance cards.
- Reuses the **master + dropdown** pattern shared with [13](13-mandoob-activities.md) (activity
  types) and [06](06-order-values.md) (order value types) — build one reusable master UI.
- Follows the exact **shape** of the rider expense ledger ([04](04-rider-expense.md)) — align column
  names and the signed/positive convention (company expenses are positive costs).

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Analysis Dashboard — a section of the main dashboard ([01](01-main-dashboard.md)) or a
  standalone page inside the Expenses module?
  💡 Standalone page in the module (detailed view), with the **summary** rolled into the main
  dashboard's Finance Summary. Avoids duplicating heavy charts.
- **Q:** Category-wise pie on the main dashboard vs here — same component?
  💡 Same chart component, different scope (main dashboard = roll-up, module = drill-down).
- **Q:** Is the entry form per-company (Company dropdown) always required?
  💡 Yes — `CompanyId` is required (expenses are company-attributed and drive per-company Net Profit).

### API / Data-side
- **Q:** Reuse `RiderExpenseCategory`/`RiderExpense` tables, or separate company tables?
  💡 **Separate** `CompanyExpense*` tables — different owner (company vs rider), different categories,
  different reporting. Reuse the *pattern*, not the tables.
- **Q:** Payment Method here is Cash/**Bank**/Online (Sales Cash [10](10-sales-cash.md) is
  Cash/Online). Keep them as separate enums?
  💡 Keep separate — the domains differ (Bank is meaningful for company expenses, not sales cash).
- **Q:** Should company expenses feed **Net Profit** exactly as `Revenue − Payroll − CompanyExpenses`
  ([01](01-main-dashboard.md))?
  💡 Yes; this module is the CompanyExpenses term. Confirm the revenue/payroll terms with 01.
- **Q:** Is bulk import needed (like rider expense), or manual entry only?
  💡 Manual entry per the doc; add import later if volume grows (reuse the `ImportLog` pattern).

### Business / Product
- **Q:** Seed the `CompanyExpenseCategory` master with the 16 example categories?
  💡 Yes, seed those, but mark them editable/deactivatable (master, not hardcoded — the doc insists).
- **Q:** Who can enter/approve company expenses (role gating)?
  💡 Restrict to Admin/Ops/Finance roles; supervisors view-only. Confirm.

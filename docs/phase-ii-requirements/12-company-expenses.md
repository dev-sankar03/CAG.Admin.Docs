# 12 — Company Expenses Module (Milestone 2)

> Source: `CAG_Phase_II.docx` → *Company Expenses Module (Milestone 2)*
> Modules touched: **New Company Expenses module**, Dashboard/Finance Summary
> ([01](01-main-dashboard.md)).
> **Status: built 2026-10-06 as a module of its own (`CAG_COMPANY_EXPENSE`) — see [§4](#4-decisions--implementation-2026-10-06). DB script on Dev only; UI not yet browser-tested.**
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

## 4. Decisions & implementation (2026-10-06)

A first version of this module was built on 2026-09-29 as a screen under Finance (entry form, list,
category table without a screen, and the category pie on the main dashboard). On 2026-10-06 it was
completed against the requirement and made **a module of its own**, as decided for Mandoob
Activities the same day. Tracker rows CE-01 … CE-09.

### 4.1 Decisions

| Question | What was built |
|---|---|
| Where it lives | **Its own module `CAG_COMPANY_EXPENSE`** — own sidebar group, own row in Admin → Permissions — no longer part of Finance. The old link `/Finance/Company-Expense` redirects to `/Company-Expenses`. |
| Who has access | Each role starts with **the level it had on Finance** (the migration copies it), so nobody gained or lost access by the move: on Dev that is Admin, Operational Manager, Coordinator = Edit; HR, Reporter = View; the rest No Access. Editable in Admin → Permissions. |
| Date (CE-01) | One required **Date** on the entry screen (defaults to today, any date can be entered). The month an expense counts in is always that date's month (`expenseMonth`, set by the API). The first version asked for a month and an optional bill date instead; the separate month picker is gone. |
| Payment Method (CE-02) | Cash / Bank / Online, required. A separate enum from Sales Cash's Cash / Online. Expenses entered before the column existed have none and show "—"; editing one asks for it. |
| Attachment (CE-03) | "Upload bill" through the existing **Document pipeline** (`api/document/*`), `source = "CompanyExpense"`, `sourceId = <expense id>`, `documentTypeId = 43`; files under `CAG_Admin/{env}/CompanyExpense/{id}/`. Several files per expense. Deleting an expense also removes its bills (best effort — see §4.3). |
| Added By / Modified By (CE-04) | Name, date and time of both are shown when an expense is opened; Added By is a list column, Modified By / Modified At are hidden columns. |
| Categories master (CE-05) | Screen to add, rename and activate / deactivate. A category in use is deactivated, never removed. All 16 categories from the client's list are seeded. |
| Analysis Dashboard (CE-07, CE-08) | A page inside the module; the main dashboard's Finance Summary is unchanged and reads the same table. |
| Company code (CE-09) | Lists, filters and the dashboard show the company **code**; a company without a code (one inactive company on Dev) shows its name. |
| Amounts | KWD with 2 decimals, as everywhere else in this system (`DECIMAL(12,2)`); the API rounds to 2. |
| Bulk import, approval | Not built (not in the requirement). |

### 4.2 Database — `CAG.Admin.API/Database/Migrations/2026-10-06_CompanyExpenseModule.sql`

Builds on `2026-09-29_DashboardRevamp.sql` (which created the two tables).

- `CompanyExpense.paymentMethod` VARCHAR(10), nullable, stored **by name** (`CompanyExpensePaymentMethod`).
- Every expense gets a date: rows without one are set to the first day of their `expenseMonth`.
  The column **stays nullable** on purpose — the script is additive, so the API build that is live
  when it runs keeps working until the new build is deployed. The API requires the date.
- Index `IX_CompanyExpense_Date`.
- The 7 categories of the client's list that were not seeded (Mobile Bills, Staff Welfare, Visa
  Expenses, Municipality, Software Subscription, Insurance, Bank Charges).
- `PageModule` `CAG_COMPANY_EXPENSE` and one `RolePermission` row per role that has a Finance row,
  with the same level.
- Re-runnable. **Applied to Dev (`CAG_Admin_Dev`) on 2026-10-06; not yet on QA or PROD.** Users only
  get the new module at their next sign-in.

### 4.3 API — `api/company-expense` (`CompanyExpenseController` → `CompanyExpenseService`)

| Method & route | Purpose | Needs |
|---|---|---|
| `GET category/getall?includeInactive=` | Categories by name, each with its expense count | View |
| `POST category` · `PUT category/{id}` | Add / rename / activate-deactivate (duplicate name → 409) | Edit |
| `GET getall?companyIds=&fromMonth=&toMonth=` | Expenses, newest date first, with bill count and both audit names | View |
| `GET analysis?companyIds=&year=&today=` | One year summed per company × month × category, plus the totals for `today` and its month | View |
| `POST` · `PUT {id}` · `DELETE {id}` | Create / update / delete an expense | Edit |

- **Access is enforced in the service** (View / Edit on `CAG_COMPANY_EXPENSE`, read live from
  `RolePermission`; rider users always refused) and every query is limited to the caller's
  `CompanyIds` — the first version only required a signed-in user.
- `today` comes from the browser because the server only knows UTC; "today" counts expenses dated
  that day, "this month" the ones booked in that month.
- The analysis groups by `expenseMonth`, the same month the main dashboard uses, so both agree.
- On update, an unchanged category that has since been deactivated is not re-validated.
- Deleting an expense first removes its bills through the document service. That is best effort:
  the file server is not transactional with the database, so a bill that cannot be removed is left
  behind as an orphan `Document` row and the expense is still deleted.
- Config: `FilePath:CompanyExpenseFiles` in `appsettings.json`.

### 4.4 UI — `CAG.Admin.UI`

| Route | What it is |
|---|---|
| `/Company-Expenses` | Expense List: month picker, search, Filter (Company, Category, Payment Method), entries count and total, CSV export, **Add Expense**. Columns: Date, Company (code), Category, Amount, Payment Method, Reference No, Remarks, Added By, Bill; Modified By / At and Added At are hidden but available. The bill count opens the files. |
| Add / Edit Expense | Date, Company, Expense Category, Amount, Payment Method, Reference No, Remarks, bill upload, and — when editing — Added by / Modified by with date and time. |
| `/Company-Expenses/Categories` | Expense Categories master. |
| `/Company-Expenses/Analysis` | Analysis Dashboard. Cards: Total Expenses (Today), Total Expenses (This Month, with the change against last month), Company-wise and Category-wise (the highest of the selected period). Below: **Company-wise Monthly Expenses** (table, company code × month with totals), **Category-wise Expenses** (ranked bars with amount and share) and **Monthly Expense Trend** (line). Filters: Company, Month, Year. |

The category breakdown is a ranked bar list rather than the sample's donut: with sixteen categories
a pie cannot be read, and the list shows the same amounts and percentages as the sample's table.

Wiring: `ModuleCodes.companyExpenses`, three `RolePageCode` entries, the sidebar group, a **Company
Expenses** row in Admin → Permissions (`ModulePermissionModel.CompanyExpenses`), and the redirect in
`next.config.ts`. The Categories screen and Mandoob's Activity Types screen share one component,
`components/master/name-master-page.tsx`. Code: `(pages)/Company-Expenses/**`,
`components/company-expense/expense-bills.tsx`, `constants/grid-props/company-expense.tsx`,
`hooks/react-query/company-expense.tsx`, `http-client/company-expense.api.ts`.

The entry form converts the picked date to `YYYY-MM-DD` before saving. The first version sent the
date picker's `DD/MM/YYYY` text, which the API cannot read.

### 4.5 Verified / not verified

- API: 60 service-level checks against Dev with fake callers per role (access per role and company,
  category master, validation, rounding, month derived from the date, bill counts, a row saved
  without date or payment method, the analysis figures, delete with and without a reachable file
  server) — all passed, and the test rows were removed. The API boots with the new routes and
  answers 401 without a token.
- UI: `tsc`, ESLint and `next build` pass, and the old link answers with a redirect to the new
  route. **Not exercised in a browser** (needs a login) — the screens, the bill upload and the
  charts still need a manual pass.

### 4.6 Still open

- Client confirmation of the single Date (instead of month + bill date) and of the starting
  permission levels.
- The sample shows Export buttons on the dashboard tables; only the Expense List exports today.
- Net Profit on the main dashboard still comes from `api/dashboard/finance/overview` — unchanged.

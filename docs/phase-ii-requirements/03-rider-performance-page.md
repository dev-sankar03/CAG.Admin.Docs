# 03 — Rider Performance Page & Export (Milestone 2)

> Source: `CAG_Phase_II.docx` → *Rider Performance Tab Export (Milestone 2)*
> Modules touched: Rider (performance), Dashboard, Payroll, Expense, Attendance, Orders,
> Properties, Vehicle, Documents.
> Related docs: [rider-management §9 performance](../rider-management.md),
> [rider performance repo](../rider-management.md).

## 1. Requirement (as specified)

- Performance should also be available in the **Dashboard**.
- Clicking a rider name opens a **separate Performance page** (use the shared sample image as
  layout reference). Sections:
  1. **Rider Information** — Selfie (from Documents), Rider ID, Name, Civil ID, Mobile, Company Code,
     Company Status.
  2. **Client Information** — Client Name, Joining Date, Salary Type, Client Status, Client Contract
     Expiry, Zone.
  3. **Finance Summary cards** — Total Earnings, Total Deductions, Net Payable, Pending Deductions.
  4. **Earnings Ledger** — data source: Client Sheet (Payroll Upload).
  5. **Expense Ledger (transaction-wise)** — data source: Expense Module; all expense transactions
     for the rider.
  6. **Incentive Management** — data source: Expense Module; incentives added there appear here.
  7. **Orders** — keep the existing table, no UI change.
  8. **Attendance** — keep the existing table from the Performance module.
  9. **Performance** — likely redundant with the Earnings Ledger; review whether to remove.
  10. **Company Assets** — assigned assets from Properties + Vehicle modules.
  11. **Payroll Calculation** — Earnings (Orders Revenue, Incentives, Bonus, Other) − Deductions
      (Traffic Fines, Advances, Mobile Bills, Other) = Net Payable.
  12. **Finance Dashboard** — remove (not required here).

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **New Performance page** (likely `(details)/Rider/[riderId]/performance` or a dedicated route)
  — a multi-section scrolling layout, not a tab. Reuses existing pieces:
  `components/details/rider/performance-tab.tsx`, `expense-tab.tsx`, and the Orders/Attendance
  tables.
- Rider name in grids becomes a link to this page.
- Dashboard gets a performance entry point.
- Selfie image loads from Documents (`useGetDocumentImage`, already exists — object-URL pattern,
  [ui-data-layer](../frontend-application-shell.md)). ✅ **Verified:** a
  selfie-finder already exists in `components/details/rider/rider-page-header.tsx`
  (`findSelfieDocument`), which matches the document **type** by keyword
  (`/selfie|photo|profile/i` against its code/description) rather than a fixed "Selfie" type — reuse
  it here.

### API / DB (`CAG.Admin.API`)
- Aggregating endpoint(s) for the page — Rider info, Client info (needs Client Status from
  [02](02-rider-management-status.md)), finance summary, ledgers.
- **Earnings Ledger** ← payroll upload (client sheet); needs a per-rider earnings query from
  `PayrollRepository` / the payroll upload data.
- **Expense + Incentive Ledgers** ← the **Rider Expense ledger** from
  [04](04-rider-expense.md) / the [expense migration](../database-access-layer.md)
  (`RiderExpense`, signed amounts, categories incl. Incentive).
- **Company Assets** ← `RiderPropertyRepository` (properties) + `RiderVehicleConfig`/`Vehicle`
  (assigned vehicle).
- **Payroll Calculation** ← `PayrollService`.
- Existing `RiderPerformanceRepository.GetMonthlyRiderPerformance` and `GetRiderPerformace` are the
  starting point.

### Cross-cutting
- **Depends on** [02](02-rider-management-status.md) (Company/Client Status), [04](04-rider-expense.md)
  (expense ledger + incentives), and [06](06-order-values.md) (order values feed payroll/earnings).
- Selfie fetch depends on a rider document whose **type name contains "selfie"/"photo"/"profile"**
  (keyword-matched, per `rider-page-header.tsx`), under `RAIDER_DOC`
  ([documents](../document-management.md)) — not a hardcoded "Selfie" type.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Section 9 (Performance) — the doc itself asks whether to remove it. Decision?
  💡 Remove it; the Earnings Ledger + Orders table already cover it. Saves vertical space (the doc's
  own preference).
- **Q:** Is this page read-only, or editable (e.g. add an expense/incentive inline)?
  💡 Read-only aggregation; edits happen in their own modules (Expense, Payroll) and reflect here.
- **Q:** Layout — one long scroll, or scroll + a sticky finance-summary header (cards top-right per
  the sample)?
  💡 Sticky top row (Rider + Client info left, Finance cards right), then scrolling ledgers below —
  matches the sample and the [08](08-rider-more-details.md) "scrolling layout" direction.
- **Q:** Where does the rider-name link live — Rider grid only, or also Part-Time/Vacation/Dashboard
  lists?
  💡 Everywhere a rider name is shown; centralise as a `<RiderNameLink>` component.

### API / Data-side
- **Q:** "Earnings Ledger — Client Sheet (Payroll Upload)": what is the storage shape of the payroll
  upload today, and is it queryable per rider per month?
  💡 Confirm the payroll-upload table; if it only stores aggregates, add a line-item table so the
  ledger can be rendered transaction-wise.
- **Q:** "Salary Type" and "Zone" (Client Information) — do these exist anywhere today?
  💡 Neither appears in the current models — new fields on `ClientUserId`/`ClientRiderConfig`.
  Confirm and add.
- **Q:** Incentives appearing "automatically" from the Expense Module — is Incentive a category in
  the `RiderExpenseCategory` seed? (It is: "Incentive".)
  💡 Yes — filter the expense ledger by the Incentive category for section 6; single source of truth.
- **Q:** Finance Summary cards (Total Earnings/Deductions/Net Payable/Pending) — computed for which
  period (selected month vs all-time)?
  💡 Add a month filter; default to current payroll month, matching the Payroll Calculation section.
- **Q:** "Company Assets" from Properties + Vehicle — include historical (released) assets or only
  currently-assigned?
  💡 Currently-assigned only (active `RiderProperty` + active `RiderVehicleConfig`); a "history" toggle
  can come later.

### Business / Product
- **Q:** Should the dashboard "performance" entry be a summary widget or just a link into these pages?
  💡 A "Top performers / low performers" widget (already exists) linking into the per-rider page —
  avoids duplicating the heavy page on the dashboard.
- **Q:** Milestone: this is M2 but depends on M1 items (02, 04, 06). Confirm sequencing.
  💡 Build the page shell + read-only sections in M2 once the M1 data sources exist; don't start
  before 04's ledger lands.

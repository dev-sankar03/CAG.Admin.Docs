# 01 — Main Dashboard Revamp (Milestone 2)

> Source: `CAG_Phase_II.docx` → *Main Dashboard (Milestone 2)*
> Modules touched: Dashboard (UI + `api/dashboard`), Partner Company (new quota fields), Finance,
> Vehicle.
> Related docs: [dashboard endpoints](../implementation-impact-analysis.md),
> [cross-cutting scoping](../authentication-authorization.md).

## 1. Requirement (as specified)

1. **Free ID count mismatch** — Free ID count differs between Dashboard and Rider Management;
   onboarding count needs checking.
2. **Total Companies card** — add Active vs Inactive company counts.
3. **Total Vehicles card** — add Assigned vs Unassigned counts.
4. **Remove the Total Orders card** — monthly order count is too high to be useful.
5. **Total Riders card** — show counts split by status:
   - **Company Status:** Active, Onboarding, Visa Process, Local Transfer, Suspended, Terminated,
     Cancelled, Akama Transfer, Free ID
   - **Client Status:** Active, Client Suspended, Churn, Clearance Completed, Part-Time Ready,
     Working Part-Time
6. **Keep as-is:** Vacation Status, Workforce, Total Pending EMI, Traffic Fines.
7. **Top riders & low performers** are currently the same — no change.
8. **Orders Completed card** — new format: filters (Company, Month, last 6 months), KPI cards
   (Total Completed Orders, Total Order Revenue, Average Orders per Rider), and a Monthly Completed
   Orders trend chart.
9. **Merge Company Summary + Finance Summary → one "Finance Summary" section** with filters
   (Company, Month, Year) containing: top KPI cards (Total Revenue, Total Payroll, Total Company
   Expenses, Net Profit, Pending EMIs, Pending Traffic Fines); a monthly financial trend chart
   (Revenue / Payroll / Expenses / Net Profit); a company-wise financial table; a company-expense
   pie chart (category-wise); and a pending-payments block.
10. **Expiring cars card** — keep the existing expiry list, but add **quota info** at the top of
    each Car/Bike card: Total Quota, Assigned, Expiry Count, Pending/Available. Requires new
    **Car Quota / Bike Quota** fields on Partner Company.
    - `Pending/Available = Total Quota − Assigned + Expiry Count`.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- `components/dashboard/**` — the biggest UI surface in the phase. New/changed cards:
  company-summary (split counts), vehicle counts, rider-status breakdown, remove orders card, new
  Orders-Completed section with a trend chart, merged Finance Summary section with pie + table +
  trend, quota headers on the expiring-car cards.
- New chart types needed (monthly trend line/bar, category pie). Confirm the charting lib in use;
  `dataviz` conventions apply.
- Partner Company add/edit forms (`components/details/partner-company/**`) gain **Car Quota** and
  **Bike Quota** inputs.
- New filters (Company / Month / Year) wired to the dashboard queries.

### API / DB (`CAG.Admin.API`)
- **New Partner Company columns:** `CarQuota`, `BikeQuota` on `Company` — plus request-model and
  `PartnerCompanyService` write path. See [data-model](../database-access-layer.md).
- **Dashboard aggregation endpoints** (`DashboardController`, `DashboardService`) — new/changed:
  - company active/inactive counts, vehicle assigned/unassigned (VehicleService already has
    `GetAssignedUnassignedCountsAsync` — reuse), rider counts grouped by **both** company status and
    the **new client status** (depends on [02](02-rider-management-status.md)).
  - Orders-Completed KPIs + 6-month trend (from `RiderOrder`).
  - Finance Summary: revenue, payroll (`PayrollRepository`), company expenses (**depends on the new
    Company Expenses module** [12](12-company-expenses.md)), net profit, pending EMI (`CarEmi`),
    pending traffic fines (`RiderRepository.GetTrafficFineSummaryAsync`), plus company-wise table and
    category pie (from Company Expenses).
  - Expiring-car quota: quota (from Company) − assigned (Vehicle) + expiry count
    (`GetExpiringVehicleDtosAsync`).
- All aggregates must stay **company-scoped** (`IReadOnlyCollection<string>? companyIds`).

### Cross-cutting
- ⚠️ The **Free ID count mismatch** is likely rooted in status being counted differently in two
  places. This phase **splits company vs client status** ([02](02-rider-management-status.md)), which
  redefines what "Free ID" even means — resolve 02 first, then this card follows.
- The **Finance Summary** depends on the **Company Expenses module** ([12](12-company-expenses.md))
  for expense totals and the category pie — sequence 12 before finishing 09-style finance cards.
- Rider status breakdown depends on the **client-status field** existing.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Total Riders card — one card with a breakdown, or separate cards per status group (Company
  vs Client)?
  💡 Two grouped mini-tables inside one "Total Riders" card: a Company-Status column and a
  Client-Status column, each status a clickable row that deep-links to a filtered Rider grid (the
  grid already supports status filters via `useServerGridState`).
- **Q:** Orders-Completed "last 6 months" — rolling 6 months from today, or 6 calendar months of the
  selected year?
  💡 Rolling 6 months ending at the selected Month; label each bar `MMM YYYY`.
- **Q:** Which charting library? (Recharts is already implied by the dashboard components.)
  💡 Reuse the existing dashboard chart components; follow [dataviz](../implementation-impact-analysis.md) palette
  rules for the pie/trend.
- **Q:** Should removing the Total Orders card also remove its backing query, or keep it for the new
  Orders-Completed section?
  💡 Keep the query, repurpose it; only the card is removed.

### API / Data-side
- **Q:** Is "Company Status" for the rider-count card the existing `RiderStatus` set, and is "Client
  Status" the brand-new field from [02](02-rider-management-status.md)?
  💡 Yes — this card cannot be finished until 02 lands the client-status field and its value list.
- **Q:** Net Profit definition = Revenue − Payroll − Company Expenses? Are EMIs/traffic-fines part of
  it or shown only as "pending"?
  💡 `Net Profit = Total Revenue − Total Payroll − Total Company Expenses`; pending EMI and pending
  traffic fines are shown separately (not deducted), matching the doc's card list.
- **Q:** Where do "Total Revenue" and "Total Order Revenue" come from — payroll upload (client
  sheet), order values, or sales cash? These may double-count.
  💡 Define one revenue source (order revenue via Order Values × completed orders) and document it;
  flag double-count risk with Sales Cash to the client.
- **Q:** Quota is per company — should the dashboard show per-company quota cards, or an
  organisation-wide roll-up across the caller's scoped companies?
  💡 Roll-up across scoped companies by default, with the Company filter narrowing to one company's
  quota. Store quota on `Company`, sum across scope.
- **Q:** The quota formula `Total − Assigned + Expiry` can exceed Total when expiry is high — is that
  intended? (The doc's own example yields 18 > unused 10.)
  💡 It is intended (expiring/expired vehicles free up quota); keep the formula but label the card
  "Available incl. expiring" to avoid confusion.

### Business / Product
- **Q:** "Company Summary" and "Finance Summary" merge — does any existing Company Summary content
  get dropped, or all folded in?
  💡 Fold all in; confirm no orphaned metric. Requires a walk-through of the current Company Summary.
- **Q:** Finance Summary depends on Company Expenses (M2) — acceptable that this card is partial
  until [12](12-company-expenses.md) ships?
  💡 Ship Finance Summary with Revenue/Payroll/EMI/Fines first; add Expenses/Net-Profit/pie when 12
  lands. Sequence explicitly.

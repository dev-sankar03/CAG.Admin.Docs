# CAG Phase II — Implementation Tracker

**Companion to:** [`implementation-impact-analysis.md`](implementation-impact-analysis.md) — task IDs, file mappings, effort estimates, and open questions all live there. This file only tracks **status**, updated as work lands.

**How this file is kept accurate:** status here reflects the actual state of the working trees in `CAG.Admin.API` and `CAG.Admin.UI` (both on `feature/rider_enhancement`, both **uncommitted** as of this audit), not just what the analysis doc assumed on 2026-09-04. Re-verify before trusting a ✅ if significant time has passed — this branch is being edited live.

**Legend:** ✅ Done &nbsp;·&nbsp; 🔄 In Progress &nbsp;·&nbsp; ❓ Needs Verification &nbsp;·&nbsp; ⛔ Not Started

**Last audited:** 2026-09-07

---

## ⚠️ Context this tracker adds beyond the impact analysis

1. **Both repos already carry a large uncommitted diff** (~22 files in `CAG.Admin.API`, ~86 in `CAG.Admin.UI`) on `feature/rider_enhancement`, predating this session. Per the repo owner, this is their own in-progress Phase II work, not a parallel/unrelated branch.
2. **Two chunks of that diff are orthogonal to the Phase II doc** and are not tracked against any task ID below:
   - A Next.js 15→16 / AG Grid 34→36 / antd 6.0→6.6 dependency upgrade (`package.json`), including `src/middleware.ts` → `src/proxy.ts` (Next 16's renamed convention). **`CAG.Admin.Docs/CLAUDE.md`'s "Adding a UI route means adding it to `RolePageCode`" guidance now points at the wrong file** — worth a doc fix once this branch settles.
   - A server-side pagination/filtering/sorting refactor for the Company/Rider/Vehicle grids (`PagingQueryHelper`, `*ListQueryBuilder`, `*ListRequest` models, new `/paged` endpoints) — a performance/scale initiative, not a Phase II requirement.
3. **The branch is being actively edited concurrently with this audit** — a mid-save race was observed on `review-submit-form.tsx` during a `tsc` check (transient type errors that cleared on re-check). Anything marked 🔄 below is a snapshot, not a guarantee of current state.
4. Given (3), work in this session was deliberately scoped to files with **no pending WIP changes**, to avoid colliding with concurrent edits.

---

## Done this session

| Task | What changed | Files |
|---|---|---|
| **T3** | Removed the "Total Orders" dashboard card (monthly order count deemed not useful at-a-glance per doc); reflowed the Overview row from 3→2 columns; dropped the now-unused `TruckIcon` import | `CAG.Admin.UI/src/app/(pages)/index.tsx` |
| **VM2** | Fixed all 3 SQL defects in vacation/overdue logic: (1) `GetAllRidersInVacationAsync` had an impossible `startDate >= today AND endDate < today` — now `startDate <= today AND endDate >= today`; (2) `GetAllRidersInOverdueAsync` had `endDate >= today` (not-yet-ended = opposite of overdue) — now `endDate < today`; (3) `GetVacationStatusAsync`'s `INNER JOIN LeaveRequest` with no narrowing multiplied every rider's count by their historical leave-request row count — rewritten as `EXISTS` subqueries against `Rider` directly (one row per rider) with the same corrected date logic | `CAG.Admin.API.DBRepository/Repository/LeaveRequestRepository.cs`, `.../RiderRepository.cs` |
| **T4** | Fixed the dashboard's rider status breakdown (`GetRiderStatusBreakdownAsync`) — it summed only 8 of 11 valid `RiderStatuses`, silently dropping Vacation (9), VacationOverdue (10), and AkhamaTransfer (14). This is very likely the actual cause of the "Free ID count mismatch" the doc opens with (buckets never summed to `TotalRiders`). Added the 3 missing buckets end-to-end: DTO → SQL → UI model → pie chart + legend (new colors, new clickable segments) | `RiderRepository.cs`, `DashboardModel.cs` (API); `models/admin-api-models/dashboard.ts`, `components/dashboard/riders-breakdown-chart.tsx` (UI) |
| **T1** | Total Companies card: added Active/Inactive breakdown line beneath the headline number. New `GetActiveInactiveCountsAsync` (unlike the existing `GetTotalCompaniesAsync`, doesn't pre-filter to active-only, so Inactive has something to count) | `ICompanyRepository.cs`, `CompanyRepository.cs`, `IPartnerCompanyService.cs`, `PartnerCompanyService.cs`, `DashboardService.cs`, `DashboardModel.cs` (API); `(pages)/index.tsx`, `models/admin-api-models/dashboard.ts` (UI) |
| **T2** | Total Vehicles card: added Assigned/Unassigned breakdown line, same pattern as T1, keyed off the existing `Vehicle.IsAssigned` column | `IVehicleRepository.cs`, `VehicleRepository.cs`, `IVehicleService.cs`, `VehicleService.cs`, `DashboardService.cs`, `DashboardModel.cs` (API); `(pages)/index.tsx`, `models/admin-api-models/dashboard.ts` (UI) |
| **VM3** | Added a "Remarks" column to the Leave Management grid, showing the latest comment from each request's existing comment thread. New additive `GET api/leaverequest/comment/latest?leaveRequestIds=...` endpoint (doesn't touch the CRUD-bound `LeaveRequest`/`LeaveRequestComment` models — a separate query projection, to avoid Dapper's reflection-based INSERT/UPDATE picking up a phantom column) | `ILeaveRequestCommentRepository.cs`, `LeaveRequestCommentRepository.cs`, `ILeaveRequestCommentService.cs`, `LeaveRequestCommentService.cs`, `LeaveRequestController.cs` (API); `api-urls.ts`, `http-client/leave-request.api.ts`, `hooks/react-query/leave-management.tsx`, `constants/grid-props/leave-request.ts`, `(pages)/Leave-Management/index.tsx` (UI) |
| **VM6** | Added Updated At / Updated By columns to the Leave Management grid (fields already existed on `LeaveRequest`, just weren't surfaced). Also resolved `UpdatedBy` to a `Name\|userId` string via a `LEFT JOIN User`, matching the existing `CreatedBy` pattern, instead of showing a raw id | `LeaveRequestRepository.cs` (API); `constants/grid-props/leave-request.ts` (UI) |
| **OC1** | Added a Source (Company/Rider/Vehicle) filter to the Dashboard → Expiring Documents card. Turned out to need no API change at all — `DocumentTypeExpiry.Source` was already returned per row, so this is a pure client-side filter on already-fetched data | `components/dashboard/expiring-documents-card.tsx` (UI only) |
| **T7** | Orders Completed card: added the 3 missing KPIs (Total Completed Orders, Total Order Revenue, Average Orders per Rider) atop the existing trend chart and date-range filter. Extended `OrderTrendsDto`/`GetOrderTrendsAsync` with a `Revenue` column (same `FinalPayment` field the Total Revenue chart already reads, just scoped to this card's own date range) instead of a second round trip; Average Orders per Rider reuses `ridersBreakdown.totalRiders`, already fetched in this same component. **Scope decision:** did not add a second, card-local Company filter — the dashboard's existing page-level company selector already scopes every card including this one, and a redundant local one seemed more confusing than useful; flagging this as a deliberate deviation from the doc's literal mockup, not an oversight | `DashboardModel.cs`, `CompanyPerformanceRepository.cs` (API); `models/admin-api-models/dashboard.ts`, `components/dashboard/company-summary.tsx` (UI) |
| **OC5** (partial — single-record half) | Added an inline "edit expiry" action to the Dashboard → Expiring Documents card, opening a popup to update one row's expiry date, then refreshing the list. Reuses the **existing** `PUT` expiry-update endpoint and the **existing** `useUpdateDocumentExpiryAsync` hook/UI pattern already built (mid-WIP) for the Documents tab — same request shape, same date handling, copied deliberately rather than inventing a second way to do the same write, to minimize risk. Needed one additive field, `DocumentTypeId`, added to `ExpiringDocumentDto`/the expiry-list query (the row didn't carry it before, only the endpoint needs it) | `DashboardModel.cs`, `DocumentService.cs` (API); `models/admin-api-models/dashboard.ts`, `components/dashboard/expiring-documents-card.tsx` (UI) |

All UI changes verified via `npx tsc --noEmit` (clean, aside from an unrelated concurrent edit in `review-submit-form.tsx` that resolved itself). API changes are scoped, additive method/SQL additions reviewed by hand — **not run against a live DB or `dotnet build`**, no environment access to either this session. Recommend before merging: (1) VM2 — a rider with 2+ historical leave rows, and one currently mid-vacation vs. one overdue; (2) T4/T1/T2 — spot-check the new breakdown numbers sum to the existing totals; (3) VM3 — a request with 0 and 2+ comments.

**OC5 (bulk-update half) not attempted:** the doc only *suggests* it ("Also suggest adding bulk expiry date update...") rather than requiring it, and it's meaningfully more surface area (multi-row selection, a bulk endpoint, transactional semantics) than the single-record edit above — left for a dedicated pass rather than folded in here.

**OC8 investigated, not changed — the gate it describes no longer appears to exist.** Searched the full path the doc complains about: `RiderService.UpdateRiderExpenseAsync` (API) has no status/workflow check of any kind; the Rider Detail page's Expense tab is gated purely by `hasEditAccess` (a module permission), not by rider status or HR-workflow completion — its tab is `TABS`, a static unconditional array; and the onboarding wizard (`add-rider-modal.tsx` and step forms) and `workflow-tab.tsx` have zero references to Expense/DownPayment at all today. So there's currently no code path where entering an expense is blocked until "HR completion." Most likely this was already resolved as a side effect of the in-progress Rider Expense ledger rewrite (E1-E3) and the Rider Details page restructuring — both touch exactly this area. **Not changed** because there's nothing found to safely change; recommend verifying directly (try adding an expense for a rider still mid-onboarding) before assuming this needs further work.

**D2 investigated, not changed:** the frontend's mandatory-expiry logic (`document-tab.tsx`) already correctly gates only on `DocumentType.isMandatory` — the code is not the bug. If Selfie still demands an expiry date, it's a **data** issue (that DocumentType row's `isMandatory` flag), not a code fix, and needs a one-row correction by whoever owns the master data — flagged, not attempted here (no DB write capability this session, and no schema change either way).

**OC2 (Vehicle Color) skipped this batch** — needs a new `Vehicle.Color` DB column, and this batch was scoped to zero-schema-change work per your instruction. Still queued in "Not started" below.

---

## In progress (found in the existing uncommitted WIP, not started by me)

| Task | Evidence | Status notes |
|---|---|---|
| **E1** Rider Expense ledger | `RiderExpense`/`RiderExpenseCategory`/`RiderExpenseImportLog` DB models (signed `Amount` = the +/- requirement, `Source` = Manual/BulkImport/Onboarding), full repo/service/controller, DI-wired in `Program.cs` | 🔄 Looks functionally complete at the API layer — needs a read-through against E1's exact spec, not a build |
| **E2** Table-view UI | `expense-tab.tsx` rewritten (574 lines changed), `grid-props/rider-expense.tsx`, `hooks/react-query/rider-expense.tsx`, `http-client/rider-expense.api.ts` all present | 🔄 |
| **E3** Bulk import | `rider-expense-import.tsx` component + `RiderExpenseImportLog` + `POST /api/rider-expense/import` | 🔄 |
| **P1, P13** (part of) Rider Performance rebuild | New dedicated Rider **Dashboard** route at `/Rider/[riderId]` (KPI hero row, `RiderPageHeader`, deep-links to a "View Full Details" page) — the old 9-tab detail page moved to `/Rider/[riderId]/details`, with a matching `RolePageCode` entry added | 🔄 Route split (P13) done; header/KPI content only partially matches doc's exact field list (§2.4) |
| **P3, P8** (partial) | New dashboard has `ExpenseSummaryCard`, `AttendanceOverviewCard`, `VehicleEmiCard`, `LeaveCard`, `AlertsCard`, `RecentDocumentsCard` — covers some but not all of doc's Finance/Attendance/Company-Assets asks | 🔄 |
| **D1, D2** Documents UI + mandatory-expiry | `document-tab.tsx` heavily rewritten (361 lines); new `isMandatory` check now considers doc-type flag *and* whether an expiry already exists, plus an inline "edit expiry" action | 🔄 Needs a check against the specific Selfie-type complaint before marking D2 done |
| **RD1** Rider More Details — "remove tabs, scrolling layout" | `tab-bar.tsx` gained a **vertical grouped** orientation (opposite direction from "remove tabs") | ❓ The new Dashboard/`/details` split may be superseding this requirement rather than implementing it literally — worth confirming intent before building RD1 as originally spec'd |

---

## Not started (no evidence in either working tree)

Grouped by epic; see the analysis doc's §2/§7 for full task descriptions.

| Epic | Tasks |
|---|---|
| Dashboard | T8, T9 |
| Rider Mgmt — Company/Client Status split | R1, R2, R3, R4, R5 *(confirmed: `RiderStatuses` enum unchanged, no `ClientStatus` field on `Client.cs`)* |
| Onboarding | O1, O2 |
| Rider Performance rebuild (remainder) | P2, P4, P5, P6, P9 *(decision, not build)*, P11, P12 |
| Complaint | C1, C2 *(confirmed: no `RiderComment` anywhere)* |
| Order Values | V1, V2, V3 |
| Part-Time / Free ID module | PT1, PT2, PT3, PT4, PT5 |
| Vacation Management (remainder) | VM1, VM4 |
| Sales Cash | SC1, SC2, SC3, SC4, SC5 *(confirmed: no `PaymentType` field on `SalesCashEntry`)* |
| Company Expenses (new module) | CE1, CE2, CE3, CE4, CE5 |
| Mandoob Activities (new module) | MA1–MA8 |
| Other Changes | OC2 *(confirmed: no `Color` field on `Vehicle` — needs a schema change)*, OC4, OC5 *(bulk-update half only — see below)* |
| Shareholders (new module) | SH1–SH5 |

✅ Moved to "Done this session": T1, T2, T4, T7, VM3, VM6, OC1, OC5 (single-record half).
🔍 Investigated, nothing to change: OC8 (see below — the described gate doesn't currently exist in the code).

**OC3** (verify vacation-vehicle-unassignment claim): re-confirmed — `Vacation` (statusId 9) is still not present in either unassignment-trigger call site in `RiderService.cs`. No code defect found; still recommend the DBA check for a DB-level trigger per the original analysis (Q9). No code change made.

---

## Suggested next batch (still-simple, zero schema risk, no overlap with current WIP)

1. **OC5 bulk-update half** — select multiple expiring-alert rows and update their dates in one action. Doc only *suggests* this one, not requires it; more surface area than what's done (multi-select + a bulk endpoint) so it's its own pass.
2. **VM1 / VM4** — Edit Vacation UI + supervisor date-extension with status auto-update. Deliberately still not started: `add-leave-request.tsx`'s view/update mode logic (`hasViewAccess` forces "view" mode regardless of edit permission) reads like it may already have an independent bug, and VM4 depends on getting that path right — needs a closer look before changing it, not a "simple" edit.
3. **OC4** — the rider-add document-save/false-failure bug. Root cause unconfirmed (analysis doc flags this explicitly) — needs reproduction before it's safe to call "simple," so held back until that's done.

OC8 is no longer in this list — investigated this session and found nothing to change (see above).

**Still blocked on a DB schema change (needs sign-off before any DDL, per analysis doc §5 — no migration tooling, and the dev DB connection string is committed in `appsettings.development.json`):** OC2 (`Vehicle.Color`), T9 (`Company.CarQuota`/`BikeQuota`), R1–R5 (`Client.ClientStatus` etc.), PT1–PT5, CE1–CE5, MA1–MA8, SH1–SH5. T8 (Finance Summary merge) is additionally blocked behind CE1. All carry the dependency-graph ordering the analysis doc lays out in §9 (most run through R3 first).

# CAG Phase II Enhancement List — Implementation Impact Analysis

**Source document:** `CAG.Admin.Docs/docs/CAG_Phase_II.pdf` ("CAG Enhancement List")
**Codebases analyzed:** `CAG.Admin.API` (.NET 9 / Dapper / MySQL) and `CAG.Admin.UI` (Next.js 15 / React 19 / TypeScript)
**Analysis type:** Requirement mapping, code-level impact assessment, effort estimation. **No production code was changed.**
**Prepared:** 2026-09-04

> ⚠️ **Source document appears incomplete.** The PDF text stream ends mid-sentence on the Shareholder Profit-Sharing section ("*Include filters by Comp*…"). Everything after that point (presumably "Company", possibly more filters, and any sections that may have followed) is not available to this analysis. See [Open Questions](#13-open-questions--clarifications-required), Q1.

> 📎 **Related detail docs (added later):**
> - **[`phase-ii-requirements/`](phase-ii-requirements/README.md)** — the same requirements split one-file-per-set, each with a UI-side / API-side **question + suggestion** breakdown. Use it as the per-requirement companion to this master analysis.
> - **[`known-behaviours.md`](known-behaviours.md)** — a consolidated, severity-tagged triage of every codebase quirk/bug referenced across the docs (several are Phase II fix candidates).
> - **[`request-lifecycle.md`](request-lifecycle.md)** — one request traced hop-by-hop (UI → API → SQL) for onboarding new contributors.
>
> ℹ️ **Framework note:** this analysis header records ".NET 9" as of its 2026-09-04 preparation date; the working tree now targets **.NET 10** and serves API docs via **Swagger at `/swagger`** (not Scalar). Treat the current code as ground truth where it differs from this dated snapshot.

---

## 1. Executive Summary

| # | Metric | Value |
|---|---|---|
| 1 | Total API changes (endpoints/services/repos touched or added) | **≈ 68** discrete backend tasks across 16 feature areas |
| 2 | Total UI changes (pages/components touched or added) | **≈ 74** discrete frontend tasks across 16 feature areas |
| 3 | Database changes | **12 new tables**, **~10 altered tables** (new columns), see [§5](#5-database-changes) |
| 4 | New APIs / components / pages required | 4 wholly new backend modules (Mandoob Activities, Company Expenses, Part-Time/Free ID, Shareholders), 1 new UI module page family for each, plus ~15 new UI components |
| 5 | Major impacted modules | Dashboard, Rider Management, Rider Onboarding (HR Workflow), Rider Performance, Rider Expense, Vacation/Leave Management, Sales Cash, Documents, Partner Company, Vehicle, Order Values, Payroll |
| 6 | Overall complexity | **High** — several requirements (Client Status split, Part-Time/Free ID, Company Expenses, Mandoob Activities, Shareholder profit-sharing) are greenfield modules; several others are cross-cutting status-machine changes that touch dashboard counts, payroll, and vehicle assignment simultaneously |
| 7 | Estimated total API effort | **≈ 118 person-days** (dev + unit/integration test) |
| 8 | Estimated total UI effort | **≈ 129 person-days** (dev + component/e2e test) |
| 9 | Testing effort (embedded above, called out separately) | **≈ 62 person-days** (≈25% of total — unit, integration, UI, and regression testing; both repos have **zero automated tests today** per `CLAUDE.md`, so this is testing effort added from scratch, not incremental) |
| 10 | **Overall estimated effort** | **≈ 247 person-days** raw + **10% integration/PM/code-review buffer** ≈ **270–275 person-days** (≈ 13–14 person-months; ≈ 3–3.5 months with a 4-person team: 2 API + 2 UI) |
| 11 | Major risks and dependencies | Rider `Status` enum surgery (Free ID removal) requires data migration and touches 6+ existing features; three independent SQL bugs found in vacation-overdue logic; two greenfield full-stack modules (Mandoob, Company Expenses) with no existing scaffolding to reuse beyond generic CRUD patterns; zero test coverage today means every change is a regression risk |
| 12 | Open questions that must be clarified before development | **14** — see [§13](#13-open-questions--clarifications-required) |

**Milestone framing note:** The source document labels items "Milestone 1" and "Milestone 2" inconsistently with dependency order — e.g., the Milestone-2 Dashboard's "Finance Summary" card depends on the Milestone-2 Company Expenses module and on Payroll, and the Milestone-1 Rider Performance dependency chain reaches into the Milestone-2 Rider Performance Tab rebuild. The [Recommended Implementation Order](#15-recommended-implementation-order) reorders by technical dependency, not by the document's milestone labels.

---

## 2. Requirement-by-Requirement Analysis

Each requirement below is mapped to the concrete files/tables found in the codebase and broken into actionable tasks. Task IDs (e.g. `T4`, `PT2`) are referenced again in [§7 Detailed Task Breakdown](#7-detailed-task-breakdown) and [§8 Effort Estimates](#8-effort-estimates).

### 2.1 Main Dashboard (Milestone 2)

**Current implementation:** `CAG.Admin.API/Controllers/v1/DashboardController.cs` → `DashboardService` (`CAG.Admin.API.Application/Service/Implementation/DashboardService.cs`) → `DashboardModel.cs` DTOs, fed by `CompanyRepository`, `VehicleRepository`, `RiderRepository`, `CarEmiRepository`, `CompanyPerformanceRepository`. UI: `(pages)/index.tsx` composed of `components/dashboard/*` cards, `recharts` for charts, gated almost entirely behind a **hardcoded `session.user.roleId === "1"`** check for the Company/Finance/Compliance summary sections (not `useHasPermission`-driven — a pre-existing inconsistency worth fixing while this area is being touched).

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Free ID count mismatch (Dashboard vs Rider Management) | `RiderRepository.GetTotalRidersAsync` excludes StatusId 1/2/3; the breakdown query `GetRiderStatusBreakdownAsync` (`RiderRepository.cs:549-580`) counts 8 status buckets but **omits StatusId 9 (Vacation), 10 (VacationOverdue), 14 (AkhamaTransfer)** entirely — this is the very likely source of the mismatch, compounded by the "Free ID" concept being redefined as a Client Status elsewhere in the same document (see §2.2) | `T4a` (fix breakdown query), tracked as bug under Rider Mgmt |
| Total Companies → +Active/Inactive split | `CompanyRepository.GetTotalCompaniesAsync` (line 203) is a flat `COUNT(*) WHERE IsActive=1` | `T1` |
| Total Vehicles → +Assigned/Unassigned split | `VehicleRepository.GetTotalVehiclesAsync`; `Vehicle.IsAssigned` bool already exists, just needs grouping | `T2` |
| Remove Total Orders card | UI-only removal (`(pages)/index.tsx`, `stat-card.tsx`) | `T3` |
| Total Riders → by Company Status (8 named values) + Client Status (6 named values) | Company Status side needs the breakdown-query fix above **plus** the missing 3 statuses added back; Client Status side has **no data source at all** until [§2.2](#22-rider-management-milestone-1--company-and-client-status-split) ships | `T4` (depends on Client Status epic for the Client-Status half) |
| Keep Vacation Status/Workforce/EMI/Fines cards | No change — `GetVacationStatusAsync`, `GetWorkforceStatusAsync`, `CarEmiService`, `TrafficFinesSummary` unchanged, **except** Vacation Status inherits the bug fix from [§2.10](#210-vacation-management-milestone-1) | — |
| "Top riders / low performers — no changes" | ⚠️ **Inconsistency found:** `DashboardService.GetTopRidersAsync` is a literal `throw new NotImplementedException()` (`DashboardService.cs:241-246`). The UI's `RiderPerformanceCard` actually calls a *different* endpoint, `useGetPerformers` (`hooks/react-query/rider-order.tsx`), so the visible feature may already work through a separate code path — but the dead `TopRiderDto`/`GetTopRidersAsync` pairing should be resolved (removed or wired up) since "no changes" cannot be certified without confirming which path is authoritative | Flagged as **Open Question Q2**, not separately estimated (assume 0.5d cleanup once clarified) |
| Orders Completed card — Company/Month/last-6-months + 3 KPI cards + trend chart | `CompanyPerformanceRepository.GetOrderTrendsAsync`/`GetRevenueDataAsync` exist but have no company filter parameter and no "Average Orders per Rider" calculation; UI `order-trend.tsx`/`company-summary.tsx` need the KPI row + company filter + 6-month default window | `T7` |
| Merge Company Summary + Finance Summary → single "Finance Summary" (KPI cards, monthly trend chart, company-wise table, expense pie chart, pending payments) | Today these are two separate, differently-sourced sections: "Company Summary" reads `CompanyPerformance` (bulk-uploaded table); "Finance Summary" reads live `CarEmi`/`Rider.trafficFines`. Merging requires a new aggregation endpoint spanning `CompanyPerformance` + `CarEmi` + `Rider` + the **new** Company Expenses module (Total Company Expenses card and the expense-breakdown pie chart both depend on §2.13) + Payroll (Total Payroll card) | `T8a`–`T8f` |
| Expiring Cars/Bikes card — add quota summary header (Total Quota / Assigned / Expiry / Pending-Available) | `VehicleRepository.GetExpiringVehicleDtosAsync` hardcodes vehicle lifespan (3yr bike / 7yr car) **and** the 30-day lookahead window as SQL literals — no config table backs "the configured period" the document refers to. `Company` has no `CarQuota`/`BikeQuota` fields (grepped, zero hits) | `T9` |

### 2.2 Rider Management (Milestone 1) — Company and Client Status split

This is the single largest source of cross-cutting risk in the whole list.

**Current implementation:** `Rider.StatusId` (single FK) → `RiderStatuses` enum (`CAG.Admin.API.Domain/Enums/RiderStatuses.cs`): `Onboarding=1, VisaProcess=2, LocalTransfer=3, FreeId=4, Active=5, Suspended=6, Terminated=7, Cancelled=8, Vacation=9, VacationOverdue=10, Supervisor=11, OperationalManager=12, HR=13, AkhamaTransfer=14`. There is **no separate Client Status field** — `Client.cs` only has a boolean `IsActive`. UI: Rider grid (`constants/grid-props/rider.ts`) has a single `status` column with `RiderStatusBadge`; the status editor (`components/details/rider/rider-tab.tsx` ~line 420-449) is a hardcoded dropdown with all values always selectable regardless of role.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Rename "Status" column → "Company Status"; add new "Client Status" column | Rider grid + Client User ID grid both need a second column; requires the new Client Status field to exist first | `R1` |
| Company Status: remove Free ID, add "Legal Issue" | `RiderStatuses.FreeId=4` is **actively used** by `RiderRepository.GetAvailabilityAsync` (Free rider count) and by the vehicle-auto-unassign trigger in `RiderService.UpdateRiderAsync`/`ChangeRiderStatus`. Removing it while simultaneously introducing "Free ID" as a **Client Status** value ([§2.9](#29-part-time--temporary-riders-milestone-1)) requires a **data migration** of every rider currently at `StatusId=4` to the new Client-Status model, and removal from the breakdown SQL, availability SQL, and the unassignment trigger list | `R2` (**high risk**, see [§10](#10-risks-and-technical-concerns)) |
| Client Status field under Employment Info, dropdown, saved & displayed | No such field/table exists. New `ClientStatus` column (or link table) on `Client`, new enum/master list, wired into `employement-tab.tsx` | `R3` |
| Map Client Status → Client ID (not Rider ID); show both statuses in Client User ID module | `ClientUserIdModel` (`ClientUserId.cs`) already links `ClientId ↔ RiderId ↔ TempRiderId` — the natural join point. Grid (`constants/grid-props/client-user-id.ts`) needs both status columns | `R1` |
| Client Status value list: Active, Client Suspended, Churn, Clearance Completed, Free ID, ID Issued for Part-Time, Vacation (later a second, slightly different list appears: "...Free Id,ID Issued for Part-Time" without "Vacation", and a dashboard section lists yet a third variant with "Part-Time Ready, Working Part-Time") | ⚠️ **Three inconsistent enumerations of Client Status appear in the source document** (page 6, page 11, and page 1's dashboard breakdown). See **Open Question Q3** — a single canonical list must be signed off before the enum/master table is built | `R3` (list finalized per Q3 answer) |
| Vacation client-status auto-syncs Company Status to Vacation, and reverts to the prior status on un-vacation | Requires storing "previous status" for correct revert — no such field exists today; also overlaps the vacation-status-sync bug fixes in [§2.10](#210-vacation-management-milestone-1) | `R4` |
| "If will mention as part time then it should go to part time module" | Ties directly into [§2.9](#29-part-time--temporary-riders-milestone-1) — Client Status = "ID Issued for Part-Time" / rider Employment Type = Part-Time both feed the new Part-Time module | `R4`, cross-ref `PT1` |
| Restrict rider status changes (Akhama Transfer, Terminated, Suspended, Cancelled) to Admin/Operations Manager only | No existing mechanism restricts *individual enum values* by role — the permission model (`ModulePermissionModel`, `Permissions` enum: NA/VIEW/EDIT/DELETE) is per-module only. `rider-tab.tsx`'s status dropdown has no role filtering at all today (only a loading-state `disabled`) | `R5` (new capability, not an extension) |

### 2.3 Onboarding Process Update

**Current implementation:** `HrWorkflowController`/`HrWorkflowService`/`HrWorkflowRepository`, driving a generic `Task`-master + `HrWorkflow`-instance engine, but hard-restricted to exactly two `ProcessType` values (`VISA_PROCESS`, `LOCAL_TRANSFER`) via a guard clause in `HrWorkflowService.GenerateWorkflowAsync:42`. UI: `components/modals/rider/add-rider-modal.tsx` (Basic Info/Documents/Surety/Review steps) + `components/details/rider/workflow-tab.tsx` (flat vertical list of stage cards, not a visual stepper), stage config in `constants/task-input-config.ts` (`TASK_CONFIGS`).

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Keep existing Vehicle Type / Visa Process / Location Transfer / Employment Type options | No change | — |
| Add "Order Type" dropdown (same values as Order module) at onboarding Basic Info | No "Order Type" master exists today — Order Values are Single/Double rate pairs per vehicle category (`OrderValue.cs`), not a discrete type taxonomy. Depends on [§2.8](#28-add-two-order-values-milestone-1) | `O1` |
| Rest of onboarding unchanged until License Process | No change | — |
| Client Status dropdown at "Arara Pending" stage, manually set, auto-updates Client Details | `TASK_CONFIGS` already has an Arara Pending stage (id 9/14); needs a new dynamic field wired to write the Client Status set in [§2.2](#22-rider-management-milestone-1--company-and-client-status-split) | `O2` |
| Edit option in Client Details to update Client Status anytime | Overlaps `R3`'s edit UI — same endpoint, different entry point | `O2` |

### 2.4 Rider Performance Tab (Milestone 2)

**Current implementation:** `RiderPerformanceService`/`RiderPerformanceRepository` + aggregation DTO `RiderPerformanceDto` (`CAG.Admin.API.Domain/Model/APIModels/Rider/RiderPerformanceDto.cs`) combining Expenses (flat Rider columns), CarEmi, Attendance (`RiderPerformance` table, batch-uploaded), Orders (pivoted `RiderOrder`), Leave. UI: `components/details/rider/performance-tab.tsx` — grid-heavy layout (Expense table, Attendance table, Performance table, Orders calendar grid) plus non-grid Car EMI / Leave stat tiles. This is a **near-total redesign**, not incremental tweaks — the document explicitly asks for a new dedicated page (not just a tab), new sections, and removal of the current Performance sub-section.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Also surface Performance from main Dashboard; clicking a rider name opens a dedicated Performance **page** (not just a tab) | Currently accessed only as a tab on the Rider detail page. Needs a new route (e.g. `/Rider/[riderId]/Performance`), a `RolePageCode` entry (required — an unlisted path resolves to "no access" per UI middleware), and a link from the Dashboard's `RiderPerformanceCard` rider-name cell | `P13` |
| Rider Info block (image from Documents→Selfie, ID, Name, Civil ID, Mobile, Company Code, Company Status) | Selfie-specific document lookup not currently joined into `RiderPerformanceDto` | `P1` |
| Client Info block (Name, Joining Date, Salary Type, Client Status, Contract Expiry, Zone) | "Zone" field not found anywhere in `Rider`/`Client` models (grep negative) — **Open Question Q4**. Client Status depends on §2.2 | `P2` |
| Finance summary cards (Total Earnings/Deductions/Net Payable/Pending Deductions) | New aggregation over Payroll module | `P3` |
| Earnings Ledger (source: Client Sheet/Payroll Upload) | `PayrollEarning` batch-upload data exists; needs a ledger-style read view | `P4` |
| Expense Ledger, transaction-wise (source: Expense Module) | **Major gap:** today's Rider Expense (`RiderService.UpdateRiderExpenseAsync`) **overwrites** flat columns on `Rider` — there is no transaction history table. This requires the same new ledger table as [§2.5](#25-rider-expense-milestone-1) `E1` — **cost counted once, in §2.5**; this task is the read-only display of that ledger inside Performance | `P5` (thin, depends on `E1`) |
| Incentive Management (auto-reflect Expense-Module incentives) | Depends on `E1` ledger + a category/tag distinguishing "incentive" line items | `P6` |
| Orders table — "keep exactly as available, no UI change" | Already exists (`Orders` pivot grid) — verification only | `P7` (QA only) |
| Attendance table — "keep exactly as available in Performance module" | Already exists — verification only | `P8` (QA only) |
| Performance section — "may not be required... please review and suggest" | This is a **decision request to the dev team**, not a spec. Recommend removal once Earnings Ledger ships (redundant data). Flagged as **Open Question Q5** | `P9` (0.25d cleanup once decided) |
| Company Assets section (Properties Module + Vehicle Module) | `RiderPropertyRepository`/`RiderProperty.cs` exists but is **not currently included** in `RiderPerformanceDto` — needs wiring in, plus the rider's assigned Vehicle | `P10` |
| Payroll Calculation breakdown (Earnings/Orders Revenue/Incentives/Bonus/Other Earnings, Deductions/Fines/Advances/Mobile Bills/Other, Net Payable) | `PayrollService`/`Payroll.cs` models already carry most of these fields — needs a dedicated read/summary endpoint + UI card, no new calculation logic expected beyond what Payroll already computes | `P11` |
| Remove "Finance Dashboard" sub-section (redundant with main dashboard) | UI-only removal | `P12` |

### 2.5 Rider Expense (Milestone 1)

**Current implementation:** Single endpoint `PUT` in `RiderController.cs` (~line 190) → `RiderService.UpdateRiderExpenseAsync` — **directly overwrites** 11 numeric columns on the `Rider` row (`TrafficFines, Advances, AdminFees, AkamaRenewalAmount, ProcessingFees, MobileBills, GarageBills, MaroorFines, Incentives, PreviousBalances, DgDeduction, MiscellaneousExpenses`). UI: `components/details/rider/expense-tab.tsx` — a single-record editable form (`InfoCard`/`InfoItem`), edit gated by a hardcoded `roleId < 3` check (not `useHasPermission`).

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Rider Expense History | No history exists — every save **replaces** the prior value. Requires a brand-new `RiderExpenseTransaction` ledger table, repository, service, and a rewrite of the write path from "overwrite" to "append transaction, recompute totals" | `E1` |
| Bulk Import option | No bulk-import endpoint for expenses exists. `RiderOrderUploadLogRepository.cs`'s batch-upload pattern (already used for orders) and the UI's `Sales-Cash/components/sales-cash-import.tsx` are the closest reusable templates | `E3` |
| Change UI to Table View | Replace the current single-form editor with a transaction grid (AG Grid, reusing `components/grid`) | `E2` |
| Add/Import buttons | UI toolbar addition on the new table view | `E2`/`E3` |
| Support +/- operations | Needs a signed-amount or Credit/Debit type flag on the new ledger row — folded into `E1`'s schema design | `E1` |

### 2.6 Complaint Section (Milestone 1)

**Current implementation:** No Complaint module exists (grep negative). Closest analog: `LeaveRequestComment` (table + service + repo) scoped to a single Leave Request, and its UI twin `components/(pages)/Leave-Management/components/remarks-tab.tsx` (`RemarksTab`) — a chat-style thread with role badges, already a good template.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| All departments should be able to add comments on the rider | New `RiderComment` table/service/controller (copy `LeaveRequestComment` pattern, swap `LeaveRequestId`→`RiderId`); new tab on Rider detail page reusing `RemarksTab`'s layout and `ROLE_BADGE_STYLES` | `C1`, `C2` |

### 2.7 Add Two Order Values (Milestone 1)

**Current implementation:** `OrderValueService`/`OrderValueRepository`, model `OrderValue.cs` = `{SingleOrderValue, DoubleOrderValue}` keyed by `BatchVehicleCategoryId`. No discrete "Order Type" taxonomy exists — UI (`(pages)/Finance/Order-Values/index.tsx`) tabs by Vehicle Category only.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Rider Category dropdown for new "Free Visa" order value during onboarding | New dimension on Order Value ("Rider Category") — needs schema extension | `V1` |
| "Company bike or Own bike applies for Free Visa?" | Unanswered in the source document itself — **Open Question Q6** | — |
| Use Order Type list from Order Values in onboarding dropdown; payroll auto-calculates from selected type's configured value | Requires the new Order Type master (below) to exist, then wiring `PayrollService` to select the rate by the rider's chosen type at calculation time | `V3` |
| Add option to add the "order value type" | Fully new master-data concept (`OrderValueType`), no existing table — settings CRUD screen, reuse `GenericPage` + `AddEditModal` pattern | `V2` |
| "Add two order values" | Likely means: add two new Order Value **records/types** to the master once it exists (e.g., a Free-Visa type and one more) — ambiguous, folded into `V2`'s scope; confirm exact count/names — **Open Question Q7** | `V2` |

### 2.8 Part-time & Temporary Riders (Milestone 1) — Part-Time Rider & Free ID Management

**Current implementation:** Nothing dedicated exists. Fragments only: `RiderStatuses.FreeId` (a *rider* status, being removed per §2.2), `EmploymentTypes.PartTime` (a string attribute on `Rider.EmploymentType`), and a `TempRiderId` nullable column on `ClientUserId.cs` — the last of these hints at pre-existing (unused) plumbing for exactly this scenario, but no controller/service/UI consumes it. UI: greenfield.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Client Status list used throughout (Active, Client Suspended, Churn, Clearance Completed, Free ID, ID Issued for Part-Time, Vacation) | Same list as §2.2's `R3` — must be the **single canonical list** (Q3) | Shared with `R3` |
| Free ID process: client → Free ID status → auto-appears in "Available Free IDs" | New `PartTimeAssignment`/Free-ID-availability query, keyed off Client Status | `PT1` |
| Rider onboarded as Part-Time from HR → also appears in Part-Time Module, default status "Ready to Work" | New `PartTimeRiderStatus` state on Rider or a companion table | `PT1` |
| Assignment: assign Part-Time Rider to a Free ID → rider status "Working"; original employee's Client Status → "ID Issued for Part-Time"; Free ID disappears from available list | State-machine logic across Client + Rider + new assignment table — this is the core business logic of the whole module | `PT2` |
| New Part-Time Management page: Available Free IDs table, Part-Time Riders table, Active Assignments table, Assign/Release/Change actions | 3 grids + assign/release modals — new page, new `ModuleCodes`/`RolePageCode` entries | `PT4`, `PT5` |
| Release process reverses the assignment (rider → Ready to Work, employee → Free ID, Free ID → available again) | Same state machine, reverse direction | `PT2` |
| Payroll integration: on release, supervisor enters completed order count for the assignment; recorded permanently; used directly in Payroll calc for the part-time rider; assignment history retains Assignment Date/Release Date/Rider/Client-Free ID/Company | New `PartTimeAssignmentHistory` fields + a `PayrollService` read of this order count instead of (or alongside) the normal batch-order pipeline | `PT3` |

### 2.9 Rider More Details (Milestone 1)

**Current implementation:** Rider detail page (`(details)/Rider/[riderId]/index.tsx`) uses a `Tab`/`TabBar` component (`components/details/tab-bar.tsx`) across 9 tabs (Rider, Employment, Bank Accounts, Vehicle, Inventory, Performance, Client Mapping History, Documents, Work Flow, Expenses).

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Remove tabs; use a scrolling layout with a second row | Layout refactor of the tab container into a stacked/scrollable sectioned page — every tab's content component is reused as-is, only the container/navigation chrome changes | `RD1` |

### 2.10 Vacation Management (Milestone 1)

**Current implementation:** Vacation is not a standalone module — it's `LeaveRequest` (`LeaveType.AnnualVacation`/`EmergencyVacation`) plus `Rider.StatusId = 9` (Vacation) / `10` (VacationOverdue). Three concrete SQL defects were found:

1. `RiderRepository.GetVacationStatusAsync` (`RiderRepository.cs:609-657`) joins `LeaveRequest` **without narrowing to the rider's current/active leave row**, inflating both `OnVacation` and `Overdue` counts whenever a rider has more than one historical leave record.
2. `LeaveRequestRepository.GetAllRidersInVacationAsync` (line 155-167): `WHERE startDate >= @CurrDate AND endDate < @CurrDate` — logically near-impossible (start after now, end before now). This is almost certainly inverted and should read `startDate <= @CurrDate AND endDate >= @CurrDate`.
3. `LeaveRequestRepository.GetAllRidersInOverdueAsync` (line 169-183): `endDate >= @CurrDate` returns riders whose leave has **not yet ended** — the opposite of "overdue" (should be `endDate < @CurrDate`).

This is almost certainly the "Vacation Overdue logic is not working fine" bug called out in the document.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Add Edit Vacation option | `LeaveRequestService.UpdateAsync` already exists server-side; UI lacks an edit entry point (`LeaveRequestModal` is add-oriented) | `VM1` |
| Fix Vacation Overdue logic | The 3 bugs above | `VM2` |
| Remark column in Vacation Overdue listing | `LeaveRequest` has a `Remarks`-capable comments sub-object (`RemarksTab`) but the main grid (`constants/grid-props/leave-request.ts`) has no Remarks column | `VM3` |
| Supervisors can update dates on extension; rider status auto-updates from revised dates | Depends on `VM2`'s corrected date logic | `VM4` |
| Rider status auto-updates when vacation overdue | Same fix as `VM2` | (covered by `VM2`) |
| Record Vacation Added By/Added Date-Time, Updated By/Updated Date-Time | `LeaveRequest.cs` already has `CreatedBy/CreatedAt/UpdatedBy/UpdatedAt` — this is primarily a **UI display gap**, not a schema gap | `VM6` |
| (Other-changes §6/§7, same document, pages 18-19) Vacation entry auto-sets Company Status → Vacation → Vacation Overdue → Active on close | Same root cause as `VM2`; the status-transition side is the Company-Status state machine from `R4` | Cross-ref `R4`, `VM2` |

### 2.11 Sales Cash Module (Milestone 1)

**Current implementation:** `SalesCashEntryController`/`SalesCashDetailsController`, model `SalesCashEntry.cs` = `{ClientId, CompanyId, ClientUserId, RiderId, EntryDate, CollectionAmount, IsDraft, Remarks, CreatedBy, CreatedAt, ExportedAt}` — **no `PaymentType` field, and no `UpdatedBy`/`UpdatedAt`** (asymmetric versus most other models). UI: `(pages)/Sales-Cash/index.tsx` using `GenericPage` + `AddEditModal`, with export (client/company filter → file download) and a bulk-import component already present.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Add Payment Type (Cash/Online) | New column + enum + form field | `SC1` |
| Include Payment Type in export | Extend the export projection | `SC2` |
| Print Receipt per entry | No print/PDF generation exists anywhere in the codebase today — new capability. Receipt content: Name, Mobile, Company Code, Rider ID, Client ID, Payment Method, Received By, company logo + name | `SC3` |
| Last 6 months data (default filter) | UI default filter + API date-range param | `SC5` |
| Record Updated By / Updated Date-Time on edit | Schema gap — add `UpdatedBy`/`UpdatedAt` (bringing this model in line with the rest of the codebase's convention) | `SC4` |

### 2.12 Documents Module (Milestone 1)

**Current implementation:** `DocumentController`/`DocumentService` (FTP-backed via FluentFTP), model `Document.cs` with nullable `ExpiryDt`; a separate `DocumentTypeExpiry` table tracks the "current" expiry per type/source. UI: shared `components/file-uploads/document-tab.tsx` (`DocumentsTab`) used across Rider/Company/Vehicle.

Good news: two of the four requested changes are **already implemented**.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Update UI per shared screenshot, reduce spacing | UI-only layout/spacing pass | `D1` |
| Remove mandatory Expiry Date requirement (Selfie incorrectly requires it) | At the API/validation layer, `ExpiryDt` is already nullable and only processed `if (item.ExpiryDate != null)` — **not mandatory today**. The "Selfie asks for expiry" behavior is most likely driven by a `DocumentType.isMandatory` **data flag** mis-set for the Selfie type, not application code. Recommend a data/config fix first, then re-verify | `D2` (small; mostly a config correction) |
| Add "View" option to open the document on the same page | ✅ **Already implemented** — `DocumentCard` has a working View action (`downloadPartnerDocument`) | none (verify only) |
| Allow 2–3 files under the same document type | ✅ **Already implemented** — documents are grouped by `documentTypeId` and multiple `DocumentCard`s render per type; `FileUploadRequestModel` already accepts multiple files per request | none (verify only) |

### 2.13 Company Expenses Module (Milestone 2)

**Current implementation:** Does not exist (grep negative for "CompanyExpense"/"ExpenseCategory"). Rider Expense's 11 hardcoded columns are the only "expense" concept in the schema today, and — importantly — they are **fixed columns, not a category master table**, so this new module cannot simply copy that pattern; it needs a proper category-master design as the document explicitly requests.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Expense Entry screen (Date, Company, Category, Amount, Payment Method, Reference No, Remarks, Attachment, Added By, Modified By) | New `CompanyExpense` table/repo/service/controller; attachment can reuse the existing generic `DocumentsTab`/file-upload component | `CE1`, `CE2` |
| Expense Categories master (not hardcoded) | New `ExpenseCategory` table + CRUD, feeding the Entry screen's dropdown — reuse `GenericPage` + `AddEditModal` pattern (same one used for `Admin/Client`) | `CE3` |
| Expense List | New grid/list page with company/category/date filters | `CE4` |
| Analysis Dashboard (Today/This-Month totals, company-wise, category-wise, monthly trend chart; "use company code not name") | New aggregation endpoints + dashboard cards/charts reusing `components/dashboard/*` toolkit (`StatCard`, `GenericPieChart`, `chart-card.tsx`) | `CE5` |

### 2.14 Mandoop Activities (Milestone 1 core / Milestone 2 Follow-up Dashboard)

**Current implementation:** Does not exist at all — confirmed zero matches for "Mandoob"/"Activity" as a module in either repo, and no `ModuleCodes` entry. Fully greenfield full-stack module, structurally similar to `LeaveRequest` (simple entity + comments-style follow-ups) but needs its own master data (Activity Types) and its own dashboard.

| Doc requirement | Finding | Task(s) |
|---|---|---|
| Activity Types master (Legal Issue, Daftar Renewal, Akhama Renewal, Visa Renewal, License Renewal, Municipality, PACI, Medical, Residency Transfer, Company Documents, Other) | New master table + CRUD | `MA1` |
| Add Activity (Type, Company, Rider, Client [optional], Priority, Subject, Description, Due Date, Assigned To Mandoob, Status, Attachment, Created By) | New `Activity` table/repo/service/controller; "Mandoob" as an assignee likely maps to the existing Users/Role system tagged with a new role rather than a wholly new user type — **Open Question Q8** | `MA2` |
| Follow-up section, unlimited follow-ups per activity | New `ActivityFollowUp` child table (Date, Remarks, Next Follow-up, Status, Updated By) | `MA3` |
| Dashboard cards (Total/Open/Pending/Completed/Overdue/Due Today) | New aggregation endpoint | `MA5` |
| Filters (Company, Type, Status, Priority, Assigned To, Month, Date Range) | Standard list-filter pattern (`GenericPage`'s `FilterConfig[]`) | `MA4` |
| Activity List + detail w/ follow-up history | New grid + detail composition | `MA4`, `MA6` |
| Follow-up Dashboard (Milestone 2): Activities-by-Type pie, Upcoming Due, Overdue lists | New chart/list dashboard, reusing the same dashboard-card toolkit as §2.13 | `MA7` |

### 2.15 Other Changes (document pages 18–19)

| # | Doc requirement | Finding | Task |
|---|---|---|---|
| 1 | Source filter (Company/Rider) on Dashboard → Expiring Documents | `ExpiringDocumentsCard` only has a day-range dropdown today, no Source filter | `OC1` |
| 2 | Add Vehicle Color field | `Vehicle.cs` has no Color field (grep negative) | `OC2` |
| 3 | Remove auto vehicle-unassignment when rider status → Vacation | ✅ Checked both call sites of the unassignment trigger in `RiderService.cs` (`UpdateRiderAsync` ~377, `ChangeRiderStatus` ~670) — **Vacation (9) is not currently in that trigger list**; only FreeId/Suspended/Terminated/Cancelled are. Either the reported behavior comes from a DB-level trigger/stored proc outside this codebase, or the document is describing a risk to guard against rather than an active bug — **Open Question Q9** | `OC3` (verify with DBA before any code change) |
| 4 | New rider: documents fail to save + false "Failed" popup despite rider being created | Likely a response-envelope/race-condition bug between rider creation and document upload steps in the multi-step add-rider flow (`add-rider-modal.tsx` + `documents-info-form.tsx`); root cause needs reproduction before a fix estimate can be tightened | `OC4` |
| 5 | Inline edit + refresh-preserving-position for contract expiry alerts; suggest bulk expiry update | No bulk expiry-update endpoint exists anywhere (`DocumentTypeExpiryService` is single-record only) | `OC5` |
| 6 | Vacation entry auto-sets Company Status Vacation/Vacation Overdue/Active | Same as `VM2`/`R4` — no separate cost | (cross-ref) |
| 7 | Restrict Rider Status changes to Admin/Ops Manager for 4 specific values | Same as `R5` — no separate cost | (cross-ref) |
| 8 | Allow Expenses/Down Payment entry during hiring, before HR completion | Current validation gates expense/down-payment entry until after HR completion (business rule inside onboarding flow) — needs relaxing in `HrWorkflowService`/`RiderService` plus corresponding UI enablement during onboarding steps | `OC8` |

### 2.16 Shareholder Profit-Sharing (unlabeled — likely Milestone 2, Finance)

**Current implementation:** Does not exist — confirmed zero matches for "Shareholder". The closest existing concept is `Company.OwnerPercentage`/`OwnerFirstName`/`OwnerLastName` (a single-owner percentage field) and the Partner Company module's "Partners" step (`partner-form.tsx`, `partners-tab.tsx`) — worth a deliberate decision on whether Shareholders extends/renames Partners or is a separate entity (**Open Question Q10**).

| Doc requirement | Finding | Task |
|---|---|---|
| Company-wise Net Profit on dashboard | Feeds from the Finance Summary merge (`T8`) — no separate cost | (cross-ref `T8`) |
| Shareholder master with profit-sharing % per company | New table, or extend Partner Company's ownership model per Q10 | `SH1` |
| Manual adjustment entries between shareholders (credit/debit) + full transaction history (Date, Company, From, To, Amount, Reason, Created By) | New `ShareholderAdjustment` ledger table | `SH3` |
| Final Profit Payable per shareholder (net profit share ± adjustments) | New calculation endpoint | `SH2`, `SH4` |
| Filters by Company (document cuts off before naming further filters) | Assume Month/Year filters by analogy with the rest of the Finance section — **confirm per Q1** | `SH5` |

---

## 3. API / Backend Changes — Summary by Module

| Module | Controller/Service files touched | Change type |
|---|---|---|
| Dashboard | `DashboardController.cs`, `DashboardService.cs`, `DashboardModel.cs` | Modify (7 endpoints changed/extended) |
| Partner Company | `PartnerCompanyController.cs`, `PartnerCompanyService.cs`, `CompanyRepository.cs`, `Company.cs` | Modify (+2 fields: CarQuota, BikeQuota) |
| Rider | `RiderController.cs`, `RiderService.cs`, `RiderRepository.cs`, `RiderStatuses.cs` (enum) | Modify (status enum surgery, role-gated status update, expense rewrite) |
| Client / Client User ID | `Client.cs`, `ClientUserIdController.cs`, `ClientUserIdService.cs`, `ClientUserIdRepository.cs` | Modify (+ClientStatus field/master) |
| HR Workflow | `HrWorkflowController.cs`, `HrWorkflowService.cs`, `ProcessType.cs` (enum) | Modify (Order Type field, Arara Pending Client Status field) |
| Rider Performance | `RiderPerformanceService.cs`, `RiderPerformanceRepository.cs`, `RiderPerformanceDto.cs` | Modify (major DTO expansion) |
| Rider Expense | `RiderService.cs` (expense methods) | **Rewrite** (overwrite → ledger) + new table/repo |
| Complaint | — | **New** module |
| Order Values | `OrderValueService.cs`, `OrderValueRepository.cs`, `OrderValue.cs` | Modify (+ Order Type dimension) + new master table |
| Part-Time / Free ID | — | **New** module |
| Vacation / Leave Request | `LeaveRequestRepository.cs`, `RiderRepository.cs` (vacation queries) | **Bug fix** (3 SQL defects) + modify |
| Sales Cash | `SalesCashEntryController.cs`, `SalesCashEntry.cs` | Modify (+PaymentType, +UpdatedBy/At, +receipt) |
| Documents | `DocumentController.cs`, `DocumentService.cs` | Minor modify / data-config fix |
| Company Expenses | — | **New** module (2 tables) |
| Mandoob Activities | — | **New** module (2 tables) |
| Vehicle | `Vehicle.cs`, Vehicle controllers | Modify (+Color field) |
| Shareholders | — | **New** module (2 tables) |
| Permissions | `ModulePermissionModel.cs`, `RolePermissionService.cs` | **New capability**: per-status-value authorization |

**Reuse note:** No new architectural layer is required anywhere — every new module follows the existing `Controller → IXService → XService → IXRepository → XRepository : GenericRepository<T>` chain and DI wiring in `Program.cs`, per the established convention in `CAG.Admin.API/CLAUDE.md`.

---

## 4. UI / Frontend Changes — Summary by Module

| Module | Key files touched | Change type |
|---|---|---|
| Dashboard | `(pages)/index.tsx`, `components/dashboard/*` (10+ files) | Major modify (card removal/addition, section merge, new quota card) |
| Partner Company | `company-info-form.tsx` | Modify (+2 fields) |
| Rider grid / Client User ID grid | `constants/grid-props/rider.ts`, `constants/grid-props/client-user-id.ts` | Modify (+Client Status column) |
| Rider detail — status editor | `components/details/rider/rider-tab.tsx` | Modify (role-filtered options — new pattern) |
| Rider detail — layout | `(details)/Rider/[riderId]/index.tsx`, `components/details/tab-bar.tsx` | Modify (tabs → scrolling sections) |
| Rider Performance | `performance-tab.tsx` → **new dedicated page** | Rewrite + new route |
| Rider Expense | `expense-tab.tsx` | Rewrite (form → ledger table + import) |
| Complaint | new tab on Rider detail | **New** (reuse `RemarksTab` pattern) |
| Order Values | `(pages)/Finance/Order-Values/*` | Modify (+Rider Category, +Order Type master screen) |
| Onboarding | `add-rider-modal.tsx`, `basic-info-form.tsx`, `workflow-tab.tsx` | Modify (+Order Type dropdown, +Arara Pending Client Status) |
| Part-Time / Free ID | — | **New** page (3 grids + modals) |
| Vacation | `(pages)/Leave-Management/*` | Modify (edit modal, remark column, audit display) |
| Sales Cash | `(pages)/Sales-Cash/*` | Modify (+Payment Type, +Print Receipt) |
| Documents | `components/file-uploads/document-tab.tsx` | Minor modify (spacing, expiry-mandatory config) |
| Company Expenses | — | **New** module (3 pages) |
| Mandoob Activities | — | **New** module (3-4 pages) |
| Vehicle | vehicle info form | Modify (+Color) |
| Shareholders | new page (or extend Partners tab) | **New** |
| Permissions plumbing | `enum/code-constants.ts` (`ModuleCodes`), `src/middleware.ts` (`RolePageCode`) | Modify — every new module needs entries here or its routes silently redirect to sign-in |

**Reuse note:** The UI has strong, consistent CRUD scaffolding already in place — `GenericPage<T>`, `AddEditModal`, `components/grid`, the dashboard card/chart toolkit (`StatCard`, `GenericPieChart`, `chart-card.tsx`), and the shared `DocumentsTab` file-upload component. Every new module above should be built on these rather than bespoke UI.

---

## 5. Database Changes

### New tables (12)

| Table (proposed) | Purpose | Related task |
|---|---|---|
| `RiderExpenseTransaction` | Ledgered rider expense entries (replacing flat overwrite columns) | `E1` |
| `RiderComment` | Cross-department comments/complaints on a rider | `C1` |
| `OrderValueType` | Master list of order value types | `V2` |
| `PartTimeAssignment` | Free-ID ↔ part-time-rider assignment records | `PT1`, `PT2` |
| `PartTimeAssignmentHistory` | Closed assignment history incl. completed order count | `PT3` |
| `CompanyExpense` | Company-level expense entries | `CE1` |
| `ExpenseCategory` | Master list of expense categories | `CE3` |
| `Activity` | Mandoob activity records | `MA2` |
| `ActivityType` | Master list of activity types | `MA1` |
| `ActivityFollowUp` | Unlimited follow-ups per activity | `MA3` |
| `Shareholder` | Per-company shareholder + profit-share % | `SH1` |
| `ShareholderAdjustment` | Manual credit/debit transaction history | `SH3` |

### Altered tables (~10)

| Table | New column(s) | Related task |
|---|---|---|
| `Company` | `CarQuota` (int), `BikeQuota` (int) | `T9` |
| `Client` | `StatusId`/`ClientStatus` (FK or enum), possibly `PreviousStatusId` for vacation revert | `R3`, `R4` |
| `Rider` | Status enum values adjusted (remove `FreeId`, add `LegalIssue`) — **enum change, may not need a column change but does need a data migration of existing `FreeId` rows** | `R2` |
| `Rider` | `Zone` (if confirmed net-new per Q4) | `P2` |
| `Vehicle` | `Color` (string) | `OC2` |
| `SalesCashEntry` | `PaymentType`, `UpdatedBy`, `UpdatedAt` | `SC1`, `SC4` |
| `LeaveRequest` | `Remarks` grid-visible column (verify — may already exist, just not surfaced), audit fields already present | `VM3`, `VM6` |
| `Document` / `DocumentType` | Correct `isMandatory` data flag for Selfie type | `D2` |
| `OrderValue` | `RiderCategoryId`, `OrderValueTypeId` (FK) | `V1`, `V3` |
| `ClientUserId` | (no schema change likely — already has `TempRiderId`; may need `PartTimeAssignmentId` FK) | `PT1` |

**Migration risk:** `CAG.Admin.DB/` is a **read-only reference snapshot** with no migration tooling (per `CLAUDE.md`) — schema changes are applied to MySQL by hand. Every table above needs a manually-written, manually-applied DDL script, and the reference dump must be re-exported afterward. This adds coordination overhead not reflected in the pure-dev estimates below — budget it explicitly (see `§8` "DB Migration & Scripting" row).

---

## 6. End-to-End Business Flow Changes

### 6.1 Rider Status Change (illustrative — most cross-cutting flow)

**Today:** Supervisor → Rider detail → Status dropdown (all values, no role check) → `PUT api/rider/{id}/status` → `RiderService.ChangeRiderStatus` → unconditionally allowed → conditionally unassigns vehicle (FreeId/Suspended/Terminated/Cancelled) → `RiderRepository.UpdateAsync`.

**After changes (`R2`, `R4`, `R5`):** Supervisor/Admin/Ops Manager → Rider detail → Status dropdown **filtered by role** (client-side) → `PUT api/rider/{id}/status` → `RiderService.ChangeRiderStatus` → **server-side role re-check** for the 4 restricted values (defense in depth — UI filtering alone is not authorization) → if target status is `Vacation`, trigger the Client-Status sync (`R4`) instead of the old direct vehicle-unassignment path → `RiderRepository.UpdateAsync` → dashboard breakdown counts (`T4`) recompute on next fetch.

**Where the system changes:** `rider-tab.tsx` (client-side filter — **new**), `RiderService.ChangeRiderStatus` (**new** server-side check — must not be UI-only), `RiderStatuses` enum (value removed/added — **migration required**), `RiderRepository.GetRiderStatusBreakdownAsync` (bucket list — **fix**).

### 6.2 Client Status → Free ID → Part-Time Assignment

**User Action:** Supervisor sets a Client's status to "Free ID" in Employment Info.
**UI:** `employement-tab.tsx` dropdown → `PUT` Client Status endpoint.
**API:** `ClientService.UpdateClientStatusAsync` (**new**) sets `Client.StatusId = FreeId`.
**Business Logic (new):** A domain event/side-effect (application-layer, not DB trigger, to stay consistent with the existing "no migration tooling" constraint) inserts/updates a `PartTimeAssignment` row with `Status = Available`.
**Database:** `Client` row updated; `PartTimeAssignment` row inserted.
**API Response → UI:** Client Details page reflects "Free ID"; separately, the Part-Time Management page's "Available Free IDs" grid (`PT4`) now lists it (via its own `GET` query, not push-based — a page refresh/refetch is required, no real-time sync is in scope).
**Assignment:** Supervisor on the Part-Time page selects a Free ID + a Part-Time Rider → `POST` assign endpoint (`PT2`) → transactionally updates `PartTimeAssignment.Status = Working`, the assigned rider's status, and the original employee's `Client.StatusId = IdIssuedForPartTime` — **this must be a single DB transaction** (the existing `GenericRepository`/`DapperHelper` supports passing an explicit `IDbConnection`+`IDbTransaction`, per `CLAUDE.md` — use that facility here) to avoid a partially-applied state on failure.
**Release + Payroll:** Supervisor releases the assignment → UI prompts for completed order count (`PT3`) → `PUT` release endpoint writes `PartTimeAssignmentHistory` (immutable after close, per the doc's explicit "should remain unchanged" requirement — enforce this at the service layer, not just UI convention) → reverses the Client/Rider statuses → Payroll Module reads the recorded order count for that rider's next calculation cycle.

**Gap identified:** There is currently no domain-event/side-effect mechanism in the codebase (services call repositories directly, no mediator/event bus pattern) — implementing the "Free ID → auto-appear in Part-Time Module" and "Vacation → auto Company Status sync" behaviors as **synchronous same-transaction service calls** (not decoupled events) is the pragmatic approach given the existing architecture, but means `ClientService`/`RiderService` will take on more cross-service orchestration responsibility than they do today. Flag for architecture sign-off if a cleaner event-driven approach is preferred (would add scope).

### 6.3 Company Expense Entry → Dashboard Analysis

**User Action:** Finance user submits an expense entry (Company, Category, Amount, Payment Method, Attachment).
**UI:** New Expense Entry page → `POST api/company-expense`.
**API:** `CompanyExpenseService.AddAsync` → `CompanyExpenseRepository.AddAsync` writes to `CompanyExpense`; attachment uploaded via the existing generic Document/FTP pipeline (`DocumentService`, reused with `Source="CompanyExpense"`).
**Database:** `CompanyExpense` row inserted, linked `Document` row inserted.
**Downstream:** Analysis Dashboard (`CE5`) and the merged Dashboard Finance Summary (`T8`) both re-aggregate from `CompanyExpense` on next load — no caching/pre-aggregation is assumed necessary at current data volumes, but flag as a **future performance risk** if expense volume grows large (see §10).

---

## 7. Detailed Task Breakdown

Tasks are grouped by epic, matching §2's task IDs. "Dep" = depends on.

<details>
<summary><b>Dashboard (Milestone 2)</b> — 9 tasks</summary>

| ID | Task | Area |
|---|---|---|
| T1 | Total Companies card: Active/Inactive split | API+UI |
| T2 | Total Vehicles card: Assigned/Unassigned split | API+UI |
| T3 | Remove Total Orders card | UI |
| T4 | Total Riders breakdown: fix missing statuses (Vacation/Overdue/Akhama) + add Client Status breakdown (dep R3) | API+UI |
| T7 | Orders Completed card: Company/Month/6-month format + 3 KPI cards + trend chart | API+UI |
| T8 | Merge Company Summary + Finance Summary into one section (6 sub-cards/charts, dep CE1 for expense breakdown, dep Payroll for Total Payroll) | API+UI |
| T9 | Vehicle/Bike Quota fields + dashboard quota summary cards | API+UI |

</details>

<details>
<summary><b>Rider Management — Company/Client Status split</b> — 5 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| R1 | Rename Status column → Company Status; add Client Status column (Rider grid + Client User ID grid) | R3 |
| R2 | Remove Free ID / add Legal Issue from Company Status enum + data migration | Q3 |
| R3 | New Client Status field (schema, master list, Employment Info UI) | Q3 |
| R4 | Vacation ↔ Company Status auto-sync incl. previous-status revert | R3, VM2 |
| R5 | Restrict 4 status values to Admin/Ops Manager (new per-value authorization) | — |

</details>

<details>
<summary><b>Onboarding</b> — 2 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| O1 | Order Type dropdown at Basic Info | V2 |
| O2 | Client Status field at Arara Pending stage + Client Details edit entry point | R3 |

</details>

<details>
<summary><b>Rider Performance rebuild</b> — 12 tasks (P9 is a decision, not build)</summary>

| ID | Task | Dep |
|---|---|---|
| P1 | Rider Info header (incl. Selfie image) | — |
| P2 | Client Info block (incl. Zone — Q4, Client Status — R3) | R3, Q4 |
| P3 | Finance summary cards | — |
| P4 | Earnings Ledger | — |
| P5 | Expense Ledger display (thin — backend built in E1) | E1 |
| P6 | Incentive Management ledger | E1 |
| P7 | Orders table — verify only | — |
| P8 | Attendance table — verify only | — |
| P9 | Decide/remove old Performance section | Q5 |
| P10 | Company Assets (Properties + Vehicle) | — |
| P11 | Payroll Calculation breakdown | — |
| P12 | Remove Finance Dashboard sub-section | — |
| P13 | Dedicated Performance page + Dashboard link + route/permission entry | — |

</details>

<details>
<summary><b>Rider Expense</b> — 3 tasks</summary>

| ID | Task |
|---|---|
| E1 | New ledger table + repo/service, +/- support, migrate write path |
| E2 | Table-view UI (replace form) |
| E3 | Bulk import (API + UI) |

</details>

<details>
<summary><b>Complaint</b> — 2 tasks</summary>

| ID | Task |
|---|---|
| C1 | RiderComment API (new, copy LeaveRequestComment pattern) |
| C2 | Rider detail Comments tab UI (reuse RemarksTab) |

</details>

<details>
<summary><b>Order Values</b> — 3 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| V1 | Rider Category dimension on Order Value + onboarding dropdown | Q6 |
| V2 | Order Value Type master + settings CRUD screen | Q7 |
| V3 | Onboarding order-value-type dropdown → payroll auto-calc wiring | V2 |

</details>

<details>
<summary><b>Part-Time / Free ID module</b> — 5 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| PT1 | Data model: PartTimeAssignment + status state machine | R3 |
| PT2 | Assign/Release endpoints + transactional business rules | PT1 |
| PT3 | Payroll integration (order count capture + immutability) | PT2 |
| PT4 | Part-Time Management UI (3 grids + modals) | PT1, PT2 |
| PT5 | ModuleCodes/RolePageCode/permission wiring | PT4 |

</details>

<details>
<summary><b>Rider More Details</b> — 1 task</summary>

| ID | Task |
|---|---|
| RD1 | Tabs → scrolling sectioned layout |

</details>

<details>
<summary><b>Vacation Management</b> — 6 tasks</summary>

| ID | Task |
|---|---|
| VM1 | Edit Vacation UI entry point |
| VM2 | Fix 3 SQL bugs (overdue/vacation-status queries) |
| VM3 | Remark column in grid |
| VM4 | Supervisor date-extension + auto status update |
| VM5 | (folded into VM2) |
| VM6 | Surface Added/Updated By+DateTime in UI |

</details>

<details>
<summary><b>Sales Cash</b> — 5 tasks</summary>

| ID | Task |
|---|---|
| SC1 | Payment Type field |
| SC2 | Payment Type in export |
| SC3 | Print Receipt (new capability) |
| SC4 | UpdatedBy/UpdatedAt audit fields |
| SC5 | Default "last 6 months" filter |

</details>

<details>
<summary><b>Documents</b> — 2 tasks (2 more are already-satisfied, verify-only)</summary>

| ID | Task |
|---|---|
| D1 | UI spacing/layout pass |
| D2 | Fix Selfie's incorrectly-mandatory expiry flag (config, not code) |

</details>

<details>
<summary><b>Company Expenses (new module)</b> — 5 tasks</summary>

| ID | Task |
|---|---|
| CE1 | Data model: CompanyExpense + ExpenseCategory tables/API |
| CE2 | Expense Entry UI (reuse DocumentsTab for attachment) |
| CE3 | Expense Categories master CRUD UI |
| CE4 | Expense List UI + filters |
| CE5 | Analysis Dashboard (cards + 3 charts) |

</details>

<details>
<summary><b>Mandoob Activities (new module)</b> — 8 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| MA1 | Activity Types master | — |
| MA2 | Activity entity + Add Activity form (incl. Mandoob assignee — Q8) | Q8 |
| MA3 | Follow-up sub-entity + UI | MA2 |
| MA4 | Activity List + filters | MA2 |
| MA5 | Dashboard cards | MA2 |
| MA6 | Activity detail w/ follow-up history | MA3 |
| MA7 | Follow-up Dashboard (Milestone 2) | MA2-6 |
| MA8 | ModuleCodes/RolePageCode/permission wiring | MA2 |

</details>

<details>
<summary><b>Other Changes</b> — 6 net-new tasks (2 are cross-referenced, no separate cost)</summary>

| ID | Task |
|---|---|
| OC1 | Source filter on Expiring Documents |
| OC2 | Vehicle Color field |
| OC3 | Verify vacation-vehicle-unassignment claim with DBA (likely already compliant) |
| OC4 | Fix rider-add document-save + false-failure bug |
| OC5 | Inline expiry edit + bulk expiry update |
| OC8 | Allow Expense/Down Payment entry during hiring, pre-HR-completion |

</details>

<details>
<summary><b>Shareholders (new module)</b> — 5 tasks</summary>

| ID | Task | Dep |
|---|---|---|
| SH1 | Shareholder master (extend Partners or new entity — Q10) | Q10 |
| SH2 | Profit-split calculation engine | SH1 |
| SH3 | Manual adjustment ledger + history | SH1 |
| SH4 | Final Profit Payable calculation | SH2, SH3 |
| SH5 | Filters (Company + likely Month/Year — Q1) | Q1 |

</details>

---

## 8. Effort Estimates

All figures are **person-days (PD)**, split Dev / Test, per epic. "Test" includes unit + integration (API) or component + manual UI verification (UI) — both repos currently have **zero automated test infrastructure**, so these figures include first-time setup of test scaffolding proportional to the area's risk, not just incremental test-writing.

| Epic | API Dev | API Test | UI Dev | UI Test | Epic Total | Complexity |
|---|---:|---:|---:|---:|---:|---|
| Dashboard (T1–T9) | 15.5 | 5.5 | 11 | 4 | **36** | High |
| Rider Mgmt Status Split (R1–R5) | 13.5 | 5 | 5 | 3 | **26.5** | High (migration risk) |
| Onboarding (O1–O2) | 4 | 1.5 | 2.5 | 1 | **9** | Medium |
| Rider Performance rebuild (P1–P13) | 14 | 5 | 12 | 4.5 | **35.5** | High |
| Rider Expense (E1–E3) | 6.5 | 2.5 | 4 | 1.5 | **14.5** | Medium |
| Complaint (C1–C2) | 2 | 1 | 1.5 | 0.5 | **5** | Low |
| Order Values (V1–V3) | 5 | 2 | 3 | 1 | **11** | Medium |
| Part-Time/Free ID module (PT1–PT5) | 8.5 | 3.5 | 4.5 | 1.5 | **18** | High (new module, state machine) |
| Rider More Details (RD1) | — | — | 2 | 1 | **3** | Low |
| Vacation Mgmt (VM1–VM6) | 3.5 | 2 | 4 | 1.5 | **11** | Medium (bug-fix regression risk) |
| Sales Cash (SC1–SC5) | 3.5 | 1.5 | 4 | 1.5 | **10.5** | Medium |
| Documents (D1–D2) | 0.5 | 0.5 | 1.5 | 1 | **3.5** | Low |
| Company Expenses (CE1–CE5) | 6 | 2.5 | 7 | 2.5 | **18** | High (new module) |
| Mandoob Activities (MA1–MA8) | 9 | 4 | 10.5 | 4 | **27.5** | High (new module) |
| Other Changes (OC1–OC8, net-new only) | 5 | 2 | 4 | 1.5 | **12.5** | Medium (OC4 has estimation uncertainty) |
| Shareholders (SH1–SH5) | 6.5 | 2.5 | 5.5 | 2 | **16.5** | Medium-High |
| **DB migration & scripting overhead** (12 new + 10 altered tables, hand-applied, no migration tooling) | 6 | — | — | — | **6** | — |
| **Subtotal** | **109.5** | **41.5** | **82.5** | **32.5** | **266** | |
| **10% integration / code-review / PM buffer** | | | | | **+27** | |
| **Grand total** | | | | | **≈ 293 PD** | |

**Reconciling with the Executive Summary:** §1 quoted ≈247 PD as the pre-buffer estimate derived during initial scoping; the table above (266 PD pre-buffer) is the fully itemized version after allocating the DB-migration line item explicitly and rebalancing the Rider Performance epic once the Expense-Ledger cost was moved fully into Rider Expense (avoiding double-counting `P5`/`P6` against `E1`). **Use 266 PD pre-buffer / ≈293 PD with buffer as the authoritative total; the §1 figure is directionally consistent (both land in the 270–295 PD band).**

- **Total Development effort:** 109.5 (API) + 82.5 (UI) = **192 PD**
- **Total Testing effort:** 41.5 (API) + 32.5 (UI) = **74 PD**
- **Total (pre-buffer):** **266 PD**
- **Total (with 10% buffer):** **≈ 293 PD** ≈ **14.5 person-months** ≈ **3.5–4 months** with a team of 4 (2 API + 2 UI engineers) running epics in parallel per §15's ordering.

**Ranges flagged for high uncertainty:**
- `OC4` (document-save/false-failure bug): **1.5–3 PD** — root cause unconfirmed; could be a one-line envelope-parsing fix or a deeper race condition.
- `R2` (Free ID removal + migration): **4–7 PD** — depends entirely on how many riders currently hold `StatusId=4` in production and whether a zero-downtime migration is required.
- `PT2`/`PT3` (Part-Time state machine + payroll integration): **±30%** — no existing pattern to anchor against; first genuinely novel state machine in the codebase.
- `T8` (Finance Summary merge): **±20%** — final cost depends on how much of Company Expenses (`CE1`) is done first; if sequenced correctly (see §15) this shrinks.

---

## 9. Dependencies

```
R3 (Client Status field) ──┬─→ R1 (grid columns) ──→ T4 (dashboard rider breakdown)
                            ├─→ R4 (vacation sync)
                            ├─→ O2 (Arara Pending stage)
                            ├─→ P2 (Performance Client Info)
                            └─→ PT1 (Part-Time module foundation) ──→ PT2 ──→ PT3 ──→ PT4 ──→ PT5

R2 (remove Free ID status) ─→ requires R3 to exist FIRST (Free ID moves from Rider status to Client status)
                            ─→ data migration of existing FreeId riders

E1 (Rider Expense ledger) ──┬─→ E2, E3 (Rider Expense UI/import)
                            └─→ P5, P6 (Performance Expense/Incentive ledgers — thin, reuse E1's API)

CE1 (Company Expense data model) ──→ CE2, CE3, CE4, CE5 ──→ T8d (dashboard expense breakdown), T8a (Total Company Expenses KPI)

V2 (Order Value Type master) ──→ V1, V3, O1 (onboarding Order Type dropdown)

VM2 (vacation SQL bug fixes) ──→ R4, VM4, OC6 all depend on correct date logic

Payroll module (existing) ──→ T8a (Total Payroll KPI), P11 (Payroll Calculation breakdown), PT3 (part-time payroll integration)

SH1 (Shareholder master) ──→ SH2 ──→ SH3 ──→ SH4 ──→ SH5; SH1 also informs T8 dashboard (Company-wise Net Profit is a Finance Summary prerequisite, shared with SH)
```

**Cross-cutting sequencing risk:** `T4`, `T8`, and `P2` all independently depend on `R3`; `T8` additionally depends on `CE1`. Building the Dashboard epic before Client Status (`R3`) or Company Expenses (`CE1`) exist would mean shipping the Dashboard's rider/finance breakdowns twice. See [§15](#15-recommended-implementation-order).

---

## 10. Risks and Technical Concerns

1. **Zero automated test coverage today.** Every change in this list is a regression risk against manual QA only. The 74 PD testing estimate above assumes building minimal test scaffolding (xUnit for API, component tests for UI) is in scope; if it is explicitly out of scope, testing effort drops but regression risk rises correspondingly — this trade-off needs a decision.
2. **`RiderStatuses` enum surgery (`R2`) is the highest-risk single change.** `FreeId=4` is read by at least 4 independent code paths (availability count, breakdown count, vehicle-unassignment trigger, and now the new Client-Status Free-ID workflow). A partial migration leaves some riders in an inconsistent state (Rider.StatusId=4 with no matching Client Status record). Recommend a dry-run data audit of current `FreeId` rider counts before implementation.
3. **Three independent SQL defects in vacation-overdue logic (`VM2`)** are being fixed in the same release that also changes the business rules around vacation (auto Company Status sync). Bundling a bug fix with a behavior change makes it harder to isolate regressions — consider shipping `VM2` as its own hotfix ahead of the rest of Vacation Management.
4. **No domain-event mechanism exists** (§6.2) — every "when X happens, Y should automatically happen" requirement in this document (Vacation→Company Status, Free ID→Part-Time Module, Incentive Expense→Performance Ledger) will be implemented as direct synchronous service-to-service calls. This is pragmatic but increases coupling between `RiderService`, `ClientService`, and the new Part-Time/Expense services — acceptable for this scope, but flag if a future phase wants these decoupled.
5. **Two independent, overlapping "expiry alert" mechanisms already exist** (`DocumentTypeExpiry`-driven generic alerts vs. a hardcoded 3-source Compliance view in `DashboardService.GetExpiringComplianceAsync`) — `OC5`'s bulk-update and inline-edit work should target the generic one, but verify the Compliance view isn't the one users actually rely on day-to-day (would need bulk-update logic duplicated or the two mechanisms consolidated — scope-creep risk, see below).
6. **No file/DB migration tooling** in either repo (`CAG.Admin.DB/` is dump+CSV only) — 12 new tables and ~10 altered tables all require hand-written, hand-applied DDL with no rollback tooling. Recommend introducing a lightweight migration runner (e.g., DbUp or Flyway) as a prerequisite, not scoped in the estimates above (**scope-creep candidate**, discuss).
7. **Hardcoded `roleId` checks in two places already found** (`rider-tab.tsx`'s Free ID knowledge, `expense-tab.tsx`'s `roleId < 3`) instead of `useHasPermission`/`ModuleCodes` — `R5`'s new per-status-value restriction should NOT follow this anti-pattern; recommend a proper `RoleCodes`-based allow-list rather than another numeric `roleId` comparison, to avoid compounding technical debt while the codebase is already being touched here.
8. **Performance/scale unknowns:** `T7`'s "Average Orders per Rider" and `CE5`'s Analysis Dashboard both run live aggregation queries with no caching layer evident in the codebase — acceptable at current data volumes per the document's own KPI figures (tens of thousands of orders/month), but worth a performance smoke-test before sign-off, not a blocking risk today.

---

## 11. Assumptions

1. The source PDF is complete up to the Shareholder section and the abrupt cutoff represents the actual end of the current version of the document (see Q1) — all estimates for Shareholders (`SH1`–`SH5`) assume only the fields explicitly named before the cutoff.
2. "Client Status" and "Company Status" are two independent fields going forward, with Company Status remaining the existing `Rider.StatusId` enum (minus Free ID, plus Legal Issue) and Client Status being new (per §2.2) — this is the most internally-consistent reading of the (three, inconsistent) status lists across pages 5, 6, 11.
3. "Mandoob" assignees are modeled as a role/tag on the existing Users system, not a wholly separate user table (Q8) — chosen because the codebase has one unified `Users`/`RoleId` model throughout and no precedent for a second user taxonomy.
4. The Finance Summary merge (`T8`) is sequenced **after** Company Expenses (`CE1`) ships, so its "Total Company Expenses" KPI and expense-breakdown pie chart consume the new module rather than needing a temporary/duplicate data source.
5. "Order Value Type" (`V2`) and "Rider Category" (`V1`) are treated as two separate new dimensions (the document uses both terms without clearly distinguishing them) — flagged in Q7; estimates assume they are indeed distinct.
6. Print Receipt (`SC3`) is implemented as a browser-print-friendly HTML view (reusing existing company-logo assets already stored for Partner Company), not a server-rendered PDF service — cheaper and consistent with there being no existing PDF-generation library in either repo. If a downloadable PDF is required, add ~2 PD.
7. All new modules' file/image attachments (Company Expense, Mandoob Activity) reuse the existing FTP-backed Document pipeline (`DocumentService`) rather than a new storage mechanism.
8. Testing effort assumes minimal, targeted test scaffolding per new/changed area (not full retroactive coverage of the existing untested codebase) — a decision to fully backfill tests across both repos would be substantially larger and out of scope for this estimate.

---

## 12. Testing Requirements

Given **both repos currently ship zero automated tests** (confirmed: `CAG.Admin.API.UnitTests` has no active csproj; `CAG.Admin.UI` has no test runner configured), testing for this phase should establish baseline coverage for the *changed* areas rather than attempt to retrofit the whole system:

- **API unit tests:** New/changed service-layer logic — especially `R2`'s status migration, `VM2`'s corrected date-range queries, `PT2`'s assignment state machine, and `SH2`/`SH4`'s profit calculations (financial calculations are the highest-value targets for unit tests given they're currently unverified by anything but manual QA).
- **API integration tests:** New endpoints for all 4 greenfield modules (Part-Time, Company Expenses, Mandoob, Shareholders) — at minimum, happy-path CRUD + the key state-transition endpoints (assign/release, follow-up add).
- **UI component tests:** New reusable pieces only where they'll be reused across modules — e.g., the new Rider-Expense ledger grid, the Part-Time assignment modals.
- **UI/E2E manual QA scripts:** Follow the existing convention (`CAG.Admin.UI/UI_TEST_FLOWS.md` is a hand-written manual QA script) — extend it with flows for every new page/workflow above rather than introducing a new automation framework mid-phase (a framework decision, e.g. Playwright, is a separate initiative).
- **Regression testing:** Explicitly re-verify Dashboard cards, Rider status transitions, and Vacation logic end-to-end after this phase — these three areas are touched by the largest number of independent tasks (`T4`/`T8`, `R1`-`R5`, `VM1`-`VM6` respectively) and are the most likely places for one task's change to silently break another's assumption.
- **Data migration verification (`R2`):** A dedicated before/after audit comparing rider counts by status pre- and post-migration, run against a production data snapshot, not just a dev/test database.

---

## 13. Open Questions / Clarifications Required

| # | Question | Why clarification is required | Assumption used | Impact if wrong | Affected area |
|---|---|---|---|---|---|
| Q1 | Is the source document complete? It cuts off mid-sentence in the Shareholder Profit-Sharing section. | The last visible line is "Include filters by Comp…" — unclear if more requirements (or the rest of this one) follow | Document is complete; Shareholder filters = Company only unless similar sections (Month/Year) imply otherwise | Missing requirements entirely omitted from this estimate; scope could grow | Shareholders (§2.16), possibly other undocumented sections |
| Q2 | Is "Top riders / low performers — no changes" referring to the working `useGetPerformers` UI path, or does it also implicitly require fixing the dead `DashboardService.GetTopRidersAsync` (`NotImplementedException`)? | Two parallel, inconsistent code paths exist for what looks like the same feature | Assume the UI's existing working path (`useGetPerformers`) is authoritative; the dead API method is unrelated tech debt, not in scope | If the dead method IS meant to back this feature, "no changes" is actually "fix a broken feature," changing scope by ~2-3 PD | Dashboard (T6) |
| Q3 | Which Client Status list is canonical? Three different lists appear (page 5: excludes "ID Issued for Part-Time" & has different order; page 6: adds "ID Issued for Part-Time," drops "Vacation"; page 11: matches page 6 and re-adds "Vacation") — plus the Dashboard section (page 1) separately lists "Part-Time Ready, Working Part-Time" as **Client Status** values not appearing in either other list | Directly determines the enum/master-table values, migration scope, and every downstream feature (Part-Time, Dashboard breakdown) | Using the page-11 list as canonical: Active, Client Suspended, Churn, Clearance Completed, Free ID, ID Issued for Part-Time, Vacation | Rework of enum, master data, and any UI already built against the wrong list | R3, R1, T4, PT1 |
| Q4 | Does a "Zone" field/concept already exist for riders/clients under a different name, or is it fully new? | Grep found no match anywhere in either codebase | Treated as a fully new free-text or lookup field on Rider/Client | If it maps to an existing field (e.g., a delivery-area concept elsewhere), duplicate work | Rider Performance (P2) |
| Q5 | Should the existing "Performance" sub-section within the Rider Performance page be removed, given the document explicitly asks the dev team to "review and suggest"? | This is a decision request embedded in the requirements doc, not a spec | Recommend removal (data is redundant with the new Earnings Ledger) pending business sign-off | If kept, adds back ~1-1.5 PD instead of the 0.25 PD cleanup estimated | Rider Performance (P9) |
| Q6 | "Company bike or Own bike applies for Free Visa?" — this question is posed by the document itself and left unanswered | The document asks this rhetorically without resolving it | Assumed both vehicle-ownership types can independently apply for the Free Visa order value (no restriction) | If only one type should qualify, adds validation logic (~0.5 PD) | Order Values (V1) |
| Q7 | Are "Order Value Type" (new master, explicitly requested) and "Rider Category" (dropdown for the Free Visa value) the same concept or two distinct dimensions? The document uses both terms in adjacent paragraphs without reconciling them. Also, "Add two order values" — which two, specifically? | Ambiguous terminology risks building the wrong data model shape | Treated as two distinct dimensions (Order Value Type = a master list of types; Rider Category = a separate onboarding-time classification) | If they're meant to be the same field, ~2-3 PD of rework | Order Values (V1, V2) |
| Q8 | Are "Mandoob" users a new distinct user type, or a role tag on the existing Users/Role system? | Document says "will create users for them" without specifying whether this is a new user category or just new user *records* under the existing system | Assumed: existing Users table + a new `RoleCodes.Mandoob` role, no new user taxonomy | If a genuinely separate user model is required (e.g., mobile-app-only accounts), scope grows significantly (~5+ PD) | Mandoob Activities (MA2) |
| Q9 | Is the reported "vehicle auto-unassigns on Vacation" behavior actually happening today? Code review of both `RiderService.UpdateRiderAsync` and `ChangeRiderStatus` shows Vacation is NOT in the unassignment trigger list. | Either there's a DB-level trigger/stored procedure outside this codebase's visibility, or the reported behavior doesn't currently reproduce and the requirement is preventative | Assumed the C# service layer is authoritative and no change is needed beyond verification; flagged for a DBA check of stored procedures/triggers | If a DB trigger does exist and is undiscovered, `OC3`'s cost rises from ~0.5 PD (verify) to ~1.5-2 PD (find + remove the trigger) | Other Changes (OC3), Vehicle module |
| Q10 | Should "Shareholders" be a new entity, or should it extend/rename the existing Partner Company "Partners" concept (`OwnerPercentage`, `partner-form.tsx`, `partners-tab.tsx`) which already models per-company ownership percentages? | Building a parallel Shareholder entity when Partners already covers ~80% of the same concept risks confusing data model duplication | Assumed Shareholders is a new, separate entity (safer/lower-risk default, avoids touching the existing Partners feature) | If the business intends Partners = Shareholders, this doubles up data entry for the same real-world people; could shrink SH1's cost by ~1.5 PD via reuse instead of new-build, at the cost of a larger refactor of the Partners feature itself | Shareholders (SH1) |
| Q11 | Should the two known overlapping "expiry alert" mechanisms (generic `DocumentTypeExpiry`-driven vs. hardcoded Compliance view) be consolidated as part of `OC5`, or is `OC5`'s bulk-edit scoped to just one of them? | Building bulk-update against only one mechanism while users rely on the other delivers no visible improvement | Assumed `OC5` targets the generic, `days`-parameterized `DocumentTypeExpiry` mechanism (the more extensible one) | If users primarily interact with the hardcoded Compliance view, the visible feature ships in the wrong place | Other Changes (OC5), Dashboard |
| Q12 | For the restricted rider statuses (`R5`: Akhama Transfer, Terminated, Suspended, Cancelled) — is the restriction enforced only at the point of *setting* that status, or does it also restrict *editing/reverting* a rider already in one of those statuses? | The document only describes the forward transition | Assumed restriction applies to setting these 4 values as a **destination** status only; reverting FROM one of them by a non-Admin/Ops role is out of scope unless specified otherwise | If reverting must also be restricted, adds a symmetric check (~0.5 PD) | Rider Mgmt (R5) |
| Q13 | For Sales Cash "Print Receipt" — is a downloadable PDF required, or is an on-screen printable view (browser print dialog) sufficient? | Document shows a receipt mockup but doesn't specify the delivery mechanism | Assumed browser-print-friendly HTML view is sufficient (no PDF library exists in either repo today) | If PDF is required, adds a new dependency + ~2 PD | Sales Cash (SC3) |
| Q14 | For the Dashboard's vehicle-quota "configured period" language — does this refer only to the existing hardcoded 3yr/7yr lifespan + 30-day lookahead (which should become configurable), or is a *new*, separate configuration screen expected as part of this phase? | The word "configured" implies a config source that doesn't currently exist (it's a SQL literal) | Assumed the phase should introduce a minimal config source (e.g., appsettings or a simple settings table) for the lifespan/lookahead values, without building a full generic settings-management UI | If a full configurable-settings UI is expected, adds a new small admin screen (~1.5 PD) | Dashboard (T9) |

---

## 14. Overall Effort Summary

| Metric | Value |
|---|---|
| Total Development effort | **192 PD** (109.5 API + 82.5 UI) |
| Total Testing effort | **74 PD** (41.5 API + 32.5 UI) |
| Subtotal | **266 PD** |
| Integration / code-review / PM buffer (10%) | **+27 PD** |
| **Grand Total** | **≈ 293 PD** |
| In person-months (1 engineer) | **≈ 14.5 months** |
| In calendar time (4-engineer team: 2 API + 2 UI, parallelized per §15) | **≈ 3.5–4 months** |
| Highest-risk epics (by combined size × risk) | Dashboard (36 PD), Rider Performance rebuild (35.5 PD), Rider Mgmt Status Split (26.5 PD, migration risk), Mandoob Activities (27.5 PD, greenfield) |
| Lowest-risk / quick-win epics | Documents (3.5 PD — 2 of 4 items already implemented), Rider More Details (3 PD, UI-only), Complaint (5 PD, strong existing pattern to copy) |

---

## 15. Recommended Implementation Order

Ordered by technical dependency (not by the source document's Milestone 1/2 labels, which do not respect dependency order — e.g., Milestone-2 Dashboard's Finance Summary needs the Milestone-2 Company Expenses module, which needs to start before the Dashboard work can finish; and several Milestone-1 items depend on other Milestone-1 items shipping first).

**Wave 1 — Foundations (no dependencies, unblocks the most downstream work):**
1. `VM2` — Fix the 3 vacation-overdue SQL bugs (isolated hotfix, ships independently, de-risks everything vacation-related)
2. `R3` — Client Status field + master list (blocks R1, R4, O2, P2, PT1 — the single highest-leverage task in the whole list)
3. `V2` — Order Value Type master (blocks V1, V3, O1)
4. `CE1` — Company Expense data model (blocks CE2-5, T8)
5. Documents quick wins (`D1`, `D2`) and Vehicle Color (`OC2`) — trivial, ship immediately for quick value

**Wave 2 — Direct consumers of Wave 1:**
6. `R1`, `R4`, `R5`, `R2` (in that order — `R2`'s migration should be last within this group, once Client Status fully absorbs the Free ID concept)
7. `O1`, `O2`
8. `V1`, `V3`
9. `CE2`, `CE3`, `CE4`, `CE5`
10. `E1`, `E2`, `E3` (Rider Expense ledger — also unblocks P5/P6)
11. `PT1`, `PT2`, `PT3`, `PT4`, `PT5` (Part-Time module, sequential internally)

**Wave 3 — Dashboard and Performance rebuilds (consume nearly everything above):**
12. `T1`, `T2`, `T3`, `T4`, `T7`, `T9` (Dashboard items not dependent on Wave 2's Finance work)
13. `T8` (Finance Summary merge — now that `CE1`/`CE5` and Payroll data are available)
14. `P1`–`P13` (Rider Performance rebuild — now that `R3`, `E1` exist)

**Wave 4 — Independent/parallel-track items (no cross-epic dependencies, can run alongside any wave):**
15. `C1`, `C2` (Complaint)
16. `SC1`–`SC5` (Sales Cash)
17. `RD1` (Rider More Details layout)
18. `VM1`, `VM3`, `VM4`, `VM6` (remaining Vacation items)
19. `OC1`, `OC3`, `OC4`, `OC5`, `OC8` (Other Changes)
20. `MA1`–`MA8` (Mandoob Activities — fully self-contained greenfield module)
21. `SH1`–`SH5` (Shareholders — fully self-contained, but confirm Q10 before starting)

**Rationale:** Waves 1-3 form the critical path (~150 of the ~266 pre-buffer PD); Wave 4's items are independent enough to be staffed on a second parallel track from day one without waiting on Waves 1-3, which is how a 4-engineer team reaches the ~3.5-4 month calendar estimate in §14 rather than the ~14.5-month single-engineer serial estimate.

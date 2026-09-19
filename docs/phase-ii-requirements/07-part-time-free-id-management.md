# 07 — Part-Time & Free ID Management (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Part-time & Temporary Riders* + *Part-Time Rider & Free ID
> Management*
> Modules touched: **New Part-Time module**, Rider, Client User ID, Client Status
> ([02](02-rider-management-status.md)), HR Workflow, Payroll.
> Related docs: [rider status](../rider-management.md),
> [client-user-id](../implementation-impact-analysis.md),
> [id generation](../authentication-authorization.md).

## 1. Requirement (as specified)

Create a **separate Part-Time module** with its own workflow from onboarding to payroll.

**Canonical Client Status list** (to be used system-wide): Active, Client Suspended, Churn,
Clearance Completed, Free ID, ID Issued for Part-Time, Vacation.

**Free ID process:**
- Client status → **Free ID** ⇒ client status auto-updates to Free ID **and** the client appears in
  the Part-Time module under **Available Free IDs**.
- A rider onboarded as **Part-Time** (from HR) appears in the Part-Time module with default status
  **Ready to Work**.

**Assignment process:**
- Part-Time module allows assigning a Part-Time rider to any available Free ID.
- On assign: Part-Time rider → **Working**; the original employee (whose client ID is used) → client
  status **ID Issued for Part-Time**; the Free ID leaves the available list until released.

**Part-Time module UI** — a separate page with:
- **Available Free IDs:** Client ID, Rider ID, Employee Name, Company Code, Current Company Status,
  Action (Assign).
- **Part-Time Riders:** Rider Name, Rider ID, Mobile Number, Employment Type, Status (Ready to Work /
  Working), Assigned Free ID (= permanent rider id, client id, rider name).
- **Active Assignments:** Free ID, Original Employee Name, Assigned Part-Time Rider (id+name),
  Assignment Date, Current Status, Action (Release / Change Assignment).

**Release process:**
- On release: Part-Time rider → **Ready to Work**; original employee client status → **Free ID**
  (from ID Issued for Part-Time); the Free ID becomes available again.

**Payroll integration:**
- On taking a Free ID back, the system asks the supervisor for the **total completed order count**
  for that assignment.
- On submit: order count saved against the assignment; assignment history records Assignment Date,
  Release Date, Part-Time Rider, Client ID/Free ID, Company; the order count is used directly in
  Payroll to calculate the Part-Time rider's salary; and it stays **unchanged** after the assignment
  is closed.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **New Part-Time Management page** (`(pages)/Part-Time/**`) with the three sections above, each a
  grid (`GenericPage`), plus Assign / Release / Change-Assignment actions and the
  order-count-entry modal on release.
- Rider onboarding (Part-Time employment type) already exists; ensure it drops the rider into the
  Part-Time list with **Ready to Work**.

### API / DB (`CAG.Admin.API`)
- **New tables:**
  - `PartTimeAssignment` — `Id`, `FreeId`(=ClientId), `OriginalRiderId`, `PartTimeRiderId`,
    `CompanyId`, `AssignmentDate`, `ReleaseDate`, `CompletedOrderCount`, `Status`, audit.
  - Part-Time rider **status** (Ready to Work / Working) — a field on the rider or a small state on
    the assignment.
- **New endpoints** (`api/part-time/*`): available free IDs, part-time riders, active assignments,
  assign, release, change-assignment, submit-order-count.
- **Client Status is the backbone** — this module reads/writes the Client Status introduced in
  [02](02-rider-management-status.md) (Free ID ⇄ ID Issued for Part-Time). It cannot be built before
  02 lands.
- **Payroll** consumes `PartTimeAssignment.CompletedOrderCount` for part-time salary.

### Cross-cutting
- ⚠️ **Depends hard on [02](02-rider-management-status.md)** (client status list + Free ID semantics)
  and [06](06-order-values.md) (order value × order count = salary).
- **Free ID** moved out of company status into client status (see 02) — this module is *why*.
- The "original employee" and "part-time rider" are both `Rider` rows; the assignment links them via
  a Client ID. Reuse `ClientRiderConfig` history where possible rather than duplicating it.
- Order count "remains unchanged after close" → the assignment row is **frozen** on release; payroll
  reads the snapshot, not a live count.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** "Change Assignment" action — reassign a Free ID to a different part-time rider in one step,
  or release-then-assign?
  💡 One modal that internally does release (capturing order count for the outgoing rider) + assign,
  so no order count is lost.
- **Q:** On release, the order-count modal — is it mandatory before the release completes?
  💡 Yes, mandatory and blocking; the release isn't committed until the count is entered (payroll
  depends on it).
- **Q:** "Assigned Free ID means permanent rider id, client id and rider name" — show all three in
  the Part-Time Riders row?
  💡 Show a compound cell: `ClientId · RiderId · Name` of the original employee whose ID is in use.

### API / Data-side
- **Q:** Is a "Free ID" a **Client User ID** whose client status = Free ID, tied to an original
  rider — confirming the assignment key is the Client ID, not the rider?
  💡 Yes. The Free ID = a `ClientUserId` row with client status `Free ID`; assignment links it to a
  part-time `Rider`. This is exactly why [02](02-rider-management-status.md) must map client status to
  the Client ID.
- **Q:** Part-Time rider "Ready to Work / Working" — a new enum, a client status, or an assignment-derived state?
  💡 A dedicated part-time state (not a client status) — the part-time rider *holds* someone else's
  client id; their own status shouldn't be a client status. Store on the assignment / a rider field.
- **Q:** Where is `CompletedOrderCount` sourced — manual supervisor entry only, or reconciled against
  the Orders/RiderOrder data?
  💡 Manual entry per the requirement ("ask the supervisor"), stored immutably on the assignment;
  optionally show the system's order tally as a hint but let the supervisor override.
- **Q:** Payroll for a part-time rider = `CompletedOrderCount × order value (by Order Type)` —
  confirm the formula and which order value applies (the original employee's or the part-timer's)?
  💡 Use the **assignment's** order type/value snapshot; confirm whether it follows the Free ID's
  configured type or the part-timer's. Freeze it at release.
- **Q:** Vacation interaction — the status list includes Vacation; if an original employee goes on
  Vacation while their ID is issued part-time, what happens?
  💡 Define precedence: "ID Issued for Part-Time" should hold until release regardless of a Vacation
  toggle; flag this edge case (the doc's own comment notes "issue if part time user start at end of
  the month").

### Business / Product
- **Q:** End-to-end workflow diagram — the doc asks for one. Confirm the exact state machine:
  Free ID → Assigned → (Working) → Released → Free ID, with company-status side effects.
  💡 We'll draft a state diagram from this file for sign-off before build.
- **Q:** Month-boundary handling — the doc's comment flags "issue if part time user start at end of
  the month". How is a mid-month assignment/release split across payroll periods?
  💡 Record `AssignmentDate`/`ReleaseDate`; payroll attributes the order count to the release month by
  default. Confirm whether it should be pro-rated across months.
- **Q:** Can one part-time rider hold multiple Free IDs at once?
  💡 Suggest one active assignment per part-time rider at a time (mirrors the one-active-vehicle rule);
  confirm.

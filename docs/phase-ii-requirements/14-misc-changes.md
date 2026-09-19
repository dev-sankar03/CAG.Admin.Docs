# 14 — Miscellaneous Changes (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Other changes* (8 numbered items)
> Modules touched: Documents/Dashboard, Vehicle, Rider status, Onboarding, Contract-expiry alerts,
> Vacation, Permissions.
> Related docs: [known-behaviours](../known-behaviours.md),
> [rider-vehicle-assignment](../rider-management.md),
> [cross-cutting permissions](../authentication-authorization.md).

Each sub-item is small but several map **directly onto documented bugs** — noted with ✅ where the
codebase analysis already pinpoints the cause.

---

## #1 — Source filter on Expiring Documents

**Requirement:** On *Dashboard → Expiring Documents*, add a filter for the **Source** field (filter
by Company or Rider).

- **UI:** add a Source filter (Company / Rider / Vehicle) to the expiring-documents list.
- **API:** `DocumentService.GetExpiringDocumentsAsync` already returns `Source`; add a source filter
  param. ⚠️ Note `api/document/all` is **not company-scoped** today
  ([known-behaviours 🔴](../known-behaviours.md)) — add scoping while
  here.
- **Q (API):** filter client-side on the returned set, or push into the query? 💡 Push into the query
  and add company scoping in the same change.

## #2 — Vehicle Color field

**Requirement:** Add a **vehicle color** field, available when adding/editing a vehicle.

- **UI:** color input on the vehicle add/edit form.
- **API/DB:** add `Color` column to `Vehicle`; extend `VehicleAddRequestModel`/`VehicleUpdateRequestModel`
  and the mapping ([vehicle-management](../vehicle-management.md)).
- **Q:** free text or a preset color list? 💡 Free text (varied vehicle colors); optional preset later.

## #3 — Stop auto-unassigning vehicle on Vacation

**Requirement:** When a rider goes to **Vacation**, the vehicle is currently auto-unassigned —
**remove** that. The vehicle stays linked; unassign manually if needed. Payroll still uses Vehicle
Type.

- ✅ **Codebase note:** the auto-unassign lives in `RiderService.ChangeRiderStatus` /
  `UpdateRiderAsync` and currently fires for **FreeId/Suspended/Terminated/Cancelled**
  ([rider-vehicle-assignment](../rider-management.md)).
  ⚠️ **Discrepancy:** the doc says Vacation currently auto-unassigns, but the documented code does
  **not** list Vacation among the exit statuses. Verify the running branch — either there's another
  path, or the premise differs.
- **API:** ensure **Vacation** is not in the auto-unassign set (and confirm it wasn't added
  elsewhere).
- **Q (API):** is the fix "confirm Vacation is excluded", or is Vacation genuinely triggering it via
  another code path? 💡 Reproduce first; the documented logic already excludes Vacation, so this may
  be a branch difference or a status-mapping bug from [02](02-rider-management-status.md).

## #4 — Rider documents not saved on add + false "Failed" popup

**Requirement:** Adding a rider creates the record, but **uploaded documents aren't saved**, and a
**"Failed" popup** shows despite success.

- ✅ **Codebase note:** exactly matches the documented flow — the wizard creates the rider, then
  uploads documents / client mapping / workflow in **separate, non-transactional** calls
  ([rider-onboarding](../hr-workflow-onboarding.md)); the modal closes
  on a timer and error handling is confused by the
  [200-with-error-body](../known-behaviours.md) and
  [non-transactional upload](../known-behaviours.md)
  behaviours.
- **UI:** await the document upload result properly; only show success/failure based on the real
  outcome; don't close on a fixed timer.
- **API:** ensure the document-upload response is unambiguous (real status codes, not 200-with-error);
  consider tying document save into the rider-create flow or a clear retry.
- **Q (UI):** should rider-create block until documents upload, or create-then-upload with a visible
  retry? 💡 Create the rider, then upload with an explicit progress + retry; surface partial failures
  per file (the endpoint can report per-file). Fix the false popup regardless.

## #5 — Contract-expiry alert: inline edit + bulk update

**Requirement:** Contract-expiry alerts need many navigation steps to update. Add an **inline edit**
(popup) in the alert list; after save, **refresh the list and keep position**. Also suggest **bulk
expiry-date update** for multiple riders.

- **UI:** edit button in the alert row → popup to update the expiry → refresh in place (the grid keeps
  scroll/position; the shared grid already avoids remount on refetch,
  [ui-data-layer](../frontend-application-shell.md)). Add multi-select + bulk-update.
- **API:** expiry update already exists (`PUT api/document/expiry-date`) — ⚠️ but it **can't add** an
  expiry, only edit ([document-expiry](../document-management.md));
  fix that (`AddIfnotfound`) so inline edits work for docs without an existing expiry. Add a
  **bulk** endpoint.
- **Q (API):** bulk update — one endpoint taking a list of `(sourceId, documentTypeId, expiry)`? 💡
  Yes; batch in one transaction, return per-row results.

## #6 — Vacation → status automation

**Requirement:** Creating a vacation ⇒ Company Status = **Vacation**; overdue & still open ⇒
**Vacation Overdue**; closed ⇒ back to **Active**.

- **Overlaps [09](09-vacation-management.md)** — build together. The reliability issue is the
  list-side-effect pattern; move to write-time + a daily job
  ([known-behaviours](../known-behaviours.md)).
- **Q:** "back to Active" vs "back to previous status"? 💡 Prefer previous status (needs history from
  [02](02-rider-management-status.md)); the doc says Active — confirm which.

## #7 — Restrict rider status changes by role

**Requirement:** Only **Admin** and **Operations Manager** can set **Akhama Transfer, Terminated,
Suspended, Cancelled**. Other statuses stay with Supervisors.

- ✅ **Codebase note:** ⚠️ there is **no server-side permission enforcement** today — controllers use
  `[Authorize]` (authenticated only), and module permissions are UI-only
  ([known-behaviours 🔴](../known-behaviours.md)). This requirement
  **forces building real server-side authorisation** for the first time.
- **API:** add a server-side check in the rider status-change path (role ∈ {Admin, Ops Manager} for
  the restricted set). This is the reusable permission check that [04](04-rider-expense.md) and
  [12](12-company-expenses.md) also want.
- **UI:** hide/disable the restricted statuses for non-privileged roles (`useHasPermission`), but
  **the server must enforce it** — UI gating alone is bypassable.
- **Q (API):** enforce via a role check in the service, or introduce a proper permission
  (`CAG_RIDER.STATUS_ADMIN`)? 💡 Add a focused server-side role/permission check now; consider it the
  seed of real API-side authorisation across the app.

## #8 — Expenses & Down Payment during hiring

**Requirement:** Currently expenses/additions can only be updated **after** HR completion. Allow
updating **Expenses and Down Payments during onboarding** (e.g. Admin Fees collected during hiring,
company-paid onboarding costs recorded before HR completion).

- ✅ **Codebase note:** the onboarding **access gate** blocks the rider detail (and thus expense
  editing) until the workflow completes — `GetRiderByIdAsync` throws 403 for
  Onboarding/VisaProcess/LocalTransfer unless `skipStatusCheck=true`
  ([rider-onboarding](../hr-workflow-onboarding.md)). That
  gate is why expenses can't be entered during hiring.
- **API/UI:** allow expense/down-payment entry during onboarding — either relax the gate for the
  expense path (use `skipStatusCheck`) or expose expense entry in the HR Workflow screens.
- **Depends on [04](04-rider-expense.md)** (the expense ledger is where these entries land, with
  `Source='Onboarding'` already anticipated in the [migration](../database-access-layer.md)).
- **Q (API):** should onboarding expenses use the new ledger with `Source='Onboarding'`? 💡 Yes —
  the migration already defines that source value; wire the onboarding expense entry to it.

---

## Suggested sequencing for this file

1. Quick wins: **#2** (vehicle color), **#1** (source filter).
2. Bug fixes with known causes: **#4** (doc save/false popup), **#5** (inline expiry edit + the
   add-expiry API fix).
3. Vacation package: **#3 + #6** with [09](09-vacation-management.md).
4. Foundational: **#7** (first real server-side authorisation) and **#8** (onboarding expenses, with
   [04](04-rider-expense.md)).

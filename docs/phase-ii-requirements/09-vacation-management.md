# 09 — Vacation Management: Edit, Overdue Logic, Audit (Milestone 1)

> Source: `CAG_Phase_II.docx` → *Vacation Management (Milestone 1)* (+ related item
> [14 #6](14-misc-changes.md) status automation)
> Modules touched: Leave/Vacation (`api/leaverequest`), Rider status, audit.
> Related docs: [leave request](../implementation-impact-analysis.md),
> [rider status side-effect](../known-behaviours.md),
> [audit convention](../database-access-layer.md).

## 1. Requirement (as specified)

- Add an **Edit Vacation** option.
- **Vacation Overdue logic is not working** — fix it.
- Add a **Remark column** in Vacation Overdue.
- If vacation is **extended**, supervisors can **update the dates**.
- **Rider status auto-updates** based on revised vacation dates.
- **Update rider status when vacation period is overdue.**
- **Audit:** record Vacation *Added By* and *Added Date/Time*; on edit, record *Updated By* and
  *Updated Date/Time* — to track who created/modified a vacation record.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **Leave/Vacation UI** (`(pages)/Leave-Management/**`, `components/…/riders-tab.tsx`) — add an
  **Edit** action opening a modal to update vacation dates + a **Remark** field; add a Remark column
  to the Overdue view; surface Added/Updated By + timestamps.

### API / DB (`CAG.Admin.API`)
- **`LeaveRequest`** — ensure `CreatedBy/At` + `UpdatedBy/At` are populated on edit (columns exist
  per the audit convention; verify they're written). Add a **Remark** field if not present.
- **Update endpoint** — `api/leaverequest/update` must recompute rider status from the revised dates.
- **Overdue logic fix** — the rule "vacation end date passed & entry still open ⇒ Vacation Overdue"
  is currently unreliable. There are **two contributing causes**:
  1. ✅ **Precise (from the master analysis, code-verified):** three SQL defects in the vacation
     queries — `RiderRepository.GetVacationStatusAsync` doesn't narrow to the active leave row;
     `LeaveRequestRepository.GetAllRidersInVacationAsync` has an **inverted `WHERE`**
     (`startDate >= @CurrDate AND endDate < @CurrDate`, near-impossible); and
     `GetAllRidersInOverdueAsync` uses `endDate >= @CurrDate` (returns not-yet-overdue riders). See
     [implementation-impact-analysis.md](../implementation-impact-analysis.md) §2.10 (`VM2`) for the
     exact line numbers — **this is the authoritative root cause; fix these first.**
  2. Additionally, leave-driven status is applied as a **side effect of listing riders**
     (`RiderService.GetAllRidersAsync`/`GetRidersPagedAsync` bulk-update Vacation / VacationOverdue)
     — see ⚠️ [known-behaviours](../known-behaviours.md) — so even correct queries only run when a
     rider list is opened, not on a schedule.

### Cross-cutting
- **Overlaps [14 #6](14-misc-changes.md)** (vacation → Company Status = Vacation; overdue →
  Vacation Overdue; close → Active) and **[14 #3](14-misc-changes.md)** (stop auto-unassigning the
  vehicle on Vacation). Treat 09 + 14#3 + 14#6 as one vacation work-package.
- Status revert on return depends on knowing the **previous status** — see the
  `PreviousStatusId`/history suggestion in [02](02-rider-management-status.md).

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Edit Vacation — can both start and end dates be changed, or only extend the end date?
  💡 Allow editing both, with validation (end ≥ start, and a warning if shortening below days already
  taken); the doc emphasises extension but "update the dates" is broader.
- **Q:** Is the Remark mandatory on Overdue, or optional?
  💡 Optional in general, **mandatory when editing an overdue vacation** (so there's a reason on
  record for the change).
- **Q:** Show the audit (Added/Updated By + time) inline in the row, or in a detail/hover?
  💡 Added-by inline; full audit (added + updated) in the edit modal / row detail.

### API / Data-side
- **Q:** Overdue detection — should it move from the list-side-effect to a **scheduled job / on-read
  recompute per rider**?
  💡 Yes — this is the root cause. Compute overdue **on write and on a daily job**, not only when a
  rider list is fetched. A small scheduled task (or computing status on the vacation record's own
  read) makes it reliable. This also decouples it from the non-idempotent GET.
- **Q:** On date edit, exactly which statuses transition, and back to what on close?
  💡 `open & today ≤ end` → Vacation; `open & today > end` → Vacation Overdue; `closed` → previous
  status (needs history from [02](02-rider-management-status.md)). Confirm the matrix.
- **Q:** Does editing dates re-open a closed vacation, or only apply to open ones?
  💡 Only open vacations are editable; a closed one requires a new entry. Confirm.
- **Q:** "Vacation" here is Company Status; with client status added ([02](02-rider-management-status.md)),
  does client Vacation also drive this?
  💡 Per 02, client Vacation → company Vacation; this module should react to the **company** status
  transition regardless of which side triggered it. Centralise in one status-sync service.

### Business / Product
- **Q:** Who can edit vacations — supervisors only, or Admin/Ops too?
  💡 Supervisors can edit dates/remarks; keep it consistent with the role model being introduced in
  [14 #7](14-misc-changes.md).
- **Q:** Is there a maximum vacation length / overdue grace period? (A doc comment mentions "24
  days".)
  💡 Confirm the 24-day figure — if it's a policy cap or grace period, encode it in the overdue rule.

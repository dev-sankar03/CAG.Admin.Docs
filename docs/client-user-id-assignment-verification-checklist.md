# Client User ID Assignment Rework — Verification Checklist

Companion to [client-user-id-assignment-rework.md](plans/client-user-id-assignment-rework.md) §8. Automated checks (`dotnet build`, `npx tsc --noEmit`, `npm run lint`) are already clean on both `feature/rider_enhancement` branches. Everything below needs a live Dev environment (DB + running API/UI) and human judgment, so it wasn't run as part of implementation — work through it before merging.

## 0. Still outstanding from the DB migration pass

- [ ] **Run `Database/Migrations/2026-09-28_ClientUserIdAssignment_06_VerifyReadQueries.sql` against `CAG_Admin_Dev`** and confirm `activeRiderCount` equals `joinedRowCount`. This was asked for once already but the results were never reported back — it verifies the Rider-list join fix (§6.5) actually eliminated the double-counted-rider bug, not just that the SQL is syntactically fine.
- [ ] If any manual test below writes real assignment data, re-run the invariant checks in `2026-09-28_ClientUserIdAssignment_04b_Verify.sql` (I1–I4, hire type, status distribution) afterward — they should still all come back clean.

## 1. Build/type-check sanity (already done, listed for completeness)

- [x] `dotnet build CAG.Admin.API/CAG.Admin.API.sln` → 0 errors
- [x] `npx tsc --noEmit` (CAG.Admin.UI) → 0 errors
- [x] `npm run lint` (CAG.Admin.UI) → 0 new errors/warnings vs. baseline

## 2. Manual flows (API via Swagger, or the UI, against Dev)

Work through in order — several build on the state left by the previous one.

1. **Create a Client User ID with no rider.**
   `POST api/client-user-id` `{ "clientUserId": <new>, "clientId": "<existing>", "contractExpiry": "2027-01-01" }` (no `riderId`/`startDate`).
   Expect: 200, slot created, `statusId = 5` (FreeId).

2. **Assign a Full Time rider as PERMANENT from the Rider page.**
   Rider page → "Assign Client User ID" → Permanent → pick the slot from step 1 → today's date.
   Expect: slot → Active, `ClientRiderConfig` row `assignmentType = PERMANENT`, rider status → Active.

3. **Suspend the slot** (Client User ID module → row action menu → Suspend).
   Expect: the CRC from step 2 ends with `endReason = ClientSuspended`, rider → FreeId, slot → Client Suspended.

4. **Assign the same Full Time rider as TEMP on another FreeId slot.**
   Rider page → Assign → Temporary. This should be **allowed** because their home slot (step 3) is suspended.
   Expect: 200, the other slot → ID Issued for Part-Time.

5. **Try assigning a Full Time rider whose home slot is *not* suspended as TEMP.** ✅ PASS (Session A, 2026-09-29)
   Pick a different Full Time rider whose home slot (if any) is Active/FreeId, attempt a Temp assign.
   Expect: 400, with a message about eligibility (not a 500 or a silent success).

6. **Resume the step-3 slot, choose "Return holder."** ✅ PASS (Session A, 2026-09-29)
   Client User ID module → the suspended slot → Resume → preview should show the rider and that they're currently on the step-4 slot → confirm "Return holder."
   Expect: the step-4 TEMP assignment ends (`endReason = ReturnedToHome`), that slot → FreeId, the step-3 slot → Active with the rider back as PERMANENT.

7. **Suspend a different slot, Resume with "Just free the ID."** ✅ PASS (Session A, 2026-09-29)
   Expect: slot → FreeId; the (if any) holder is untouched — no rider-status or CRC change for them.

8. [x] **Assign a Part Time rider as TEMP, then End.** — PASS, see `test-run/results-B.md`.
   Expect: slot → ID Issued for Part-Time → (End) → FreeId; rider → Active → FreeId.

9. [x] **Churn → Clearance Completed → assign a new Full Time rider as PERMANENT.** — PASS, see `test-run/results-B.md`.
   Mark Churn on a slot with an active assignment (ends it, rider → FreeId, slot → Churn) → Clearance Completed → then Assign Permanent a *different* Full Time rider to that same slot.
   Expect: the UI shows the "replaces former holder" warning before submit; after submit, slot → Active with the new rider as `riderId`.

10. [x] **Delete a slot with history → rejected. Delete a brand-new slot → OK.** — PASS, see `test-run/results-B.md`.
    Try deleting the slot from step 9 (has CRC history) — expect 400 ("Use Churn / Clearance Completed instead"). Create a fresh slot with no assignment ever and delete it — expect success.

11. [x] **Run an HR Workflow to its final step with client fields filled in.** — PASS, see `test-run/results-B.md`.
    Expect: slot created Active with a PERMANENT CRC, exactly as before the rework — this path (`POST api/client-user-id` with `riderId`+`startDate`) is untouched HR code hitting the rewritten `CreateClientUserIdAsync`.

12. [x] **Add Rider as Part Time, picking a Client User ID in the Documents step.** — PASS, see `test-run/results-B.md`.
    Expect: TEMP CRC created, slot → ID Issued for Part-Time, and the slot's `contractExpiry` is **unchanged** by this flow (it only sets the assignment, not the contract).

13. **Order import for a month where a slot changed rider mid-month.**
    Upload a rider-order file for a `clientUserId` that had two different riders holding it (one after the other) during the target month.
    Expect: orders attributed to whichever rider held it more days that month, plus a warning line in the import log naming the other rider(s) — not the old "RiderId mismatch" error.

14. **Rider list and paged total counts equal the active rider count.**
    Compare `GET api/rider/all`'s row count and `GET api/rider/paged`'s `totalCount` against `SELECT COUNT(*) FROM Rider WHERE isActive = 1` (company-scoped) — see §0 above, this is the same check as the SQL script, just from the API/UI side.

15. [x] **New rider → `hireTypeId` set; `PUT api/rider/{id}` with `hireTypeId` in the body → no-op.** — PASS, see `test-run/results-B.md`.
    Create a new Full Time rider, confirm `hireTypeId = 1` in the DB. Then `PUT api/rider/{id}` with `hireTypeId: 2` in the payload — confirm the stored value doesn't change (the field was removed from `RiderUpdateRequest`, so the API should silently ignore it rather than erroring).

## 3. UI spot-checks not covered by the flows above

- [x] Client User ID grid: Status badge colors are readable and distinct; Current Type column shows "—" for a FreeId/Churn/Clearance-Completed slot with no active assignment. — PASS (Session A; clearance badge text clipped, see results-A.md 3c)
- [x] Client User ID grid: Rider ID cells link to `/Rider/{riderId}` and open the correct rider. — PASS (Session A)
- [x] Client User ID grid: Delete action is hidden (not just disabled) on a slot with history. — PASS (Session B, see test-run/results-B.md)
- [x] Rider page "Current client" card: type badge (Permanent/Temporary) and slot status render correctly for both an Active and a ID Issued for Part-Time assignment. — PASS (Session A, see test-run/results-A.md)
- [x] Rider page client history list: newly-added Type and End reason details show up correctly on ended rows. — PASS (Session A, see test-run/results-A.md)
- [~] Permission gating: a user without `CAG_RIDER.EDIT` sees no Assign/Switch/End/Suspend/Resume/Churn/Clearance/Delete actions anywhere in this flow, only read access. — UI PASS; API does NOT enforce EDIT on client-user-id create/suspend (Session A, see results-A.md 3e)

# Results - Session B (Cowork). Data prefix ZT-B-

Owner: steps 8, 9, 10, 11, 12, 15, + two §3 grid items (Current Type "—" for Churn/Clearance-Completed; Delete hidden on slot with history). Update after EVERY step.

Numeric Client User ID test-data block reserved for this session: 99910001–99910099 (to avoid colliding with steps 1–4's 999000xx block or Session A's IDs). Free-text fields (reasons, remarks, names) are prefixed `ZT-B-` where the UI allows free text.

## Step 8 — Assign Part Time rider TEMP, then End — PASS

Test data: rider `RD261087` (Shiva kumar maggid, Part Time, pre-existing, no active assignment), slot `99910001` (ZT-B block, client `CLT2601` Talabat).

- Created slot `99910001` via `POST api/client-user-id` (no rider) → `statusId=5` (FreeId).
- UI: Rider page → Employment tab → "Assign Client User ID" → Temporary → `99910001` → today's date → Save.
  - Result: slot `statusId=6` (Working Part-Time), `ClientRiderConfig` row 1672 `assignmentType=TEMP`, `isActive=1`, `tempRiderId=RD261087`. Rider `statusId` 4→5 (FreeId→Active). Matches expected.
- UI: Rider page → Current client card → "End assignment" → today's date → confirm.
  - Result: slot back to `statusId=5` (FreeId), CRC 1672 ended (`isActive=0`, `endDate`=today, `endReason='Ended'`). Rider `statusId` 5→4 (Active→FreeId). Matches expected exactly.

Verified via: API (`GET api/client-user-id/{id}`) and direct DB query on `ClientRiderConfig`/`Rider`.

## Step 9 — Churn → Clearance Completed → assign new Full Time rider PERMANENT — PASS

Test data: slot `99910002` (ZT-B block, client `CLT2601` Talabat); former holder `RD260054` (MOHAMED AZARUDIN DOWLATH KHAN, Full Time); new holder `RD260055` (Anoud Khaled Eid Al-Anzi, Full Time). Reason text `ZT-B- step9 churn` / `ZT-B- step9 clearance` used on the status-change modals.

1. Assigned `RD260054` PERMANENT to `99910002` via Rider page (baseline state) → slot `statusId=1` (Active).
2. UI: Client User ID grid → row action menu → Mark Churn → today's date, reason `ZT-B- step9 churn`.
   - Result: slot `statusId=3` (Churn), CRC 1673 ended `isActive=0`, `endReason='Churn'`. Rider `RD260054` → `statusId=4` (FreeId). Matches expected.
3. UI: same row → Clearance Completed → today's date, reason `ZT-B- step9 clearance`.
   - API response: `PUT api/client-user-id/99910002/clearance-completed` → 200, toast "Clearance marked as completed!". Slot `statusId=4` (ClearanceCompleted).
4. UI: Rider page for `RD260055` → Assign Client User ID → Permanent → typed `99910002` in the dropdown.
   - **Confirmed the "replaces former holder" warning renders**: "This Client User ID's former holder MOHAMED AZARUDIN DOWLATH KHAN completed clearance. Assigning it here replaces t[heir CRC as PERMANENT holder]" (banner text truncated in captured body, but present and names the correct former holder).
   - Submitted → slot `99910002` `statusId=1` (Active), `riderId=RD260055`. New CRC row 1674 (`PERMANENT`, `isActive=1`). Old CRC row 1673 stays `isActive=0`/`Churn`. Rider `RD260055` → `statusId=5` (Active); `RD260054` remains `statusId=4` (FreeId, untouched by the replacement). Matches expected exactly.

Verified via: API (`GET api/client-user-id/{id}`), direct DB query on `ClientRiderConfig`/`Rider`, and the UI body text captured after each step (confirms the warning banner actually rendered, not just that the API call succeeded).

## Step 10 — Delete slot with history rejected; delete brand-new slot OK — PASS

Test data: slot `99910002` (has history — used in step 9), slot `99910003` (ZT-B block, created fresh with no assignment ever).

- `DELETE api/client-user-id/99910002` → **400** `{"error":"ValidationFailed","message":"This Client User Id has assignment history. Use Churn / Clearance Completed instead."}`. Row confirmed still present in DB afterward.
- `DELETE api/client-user-id/99910003` → **200**, `{"data":null}`. Row confirmed gone from `ClientUserId` table afterward.

Matches expected exactly.

**Note for whoever reads this (not a finding against these steps, just a gotcha I hit):** the `{id}` route parameter on every `ClientUserIdController` endpoint (`GetById`, `Update`, `Delete`, `Suspend`, `Resume`, etc.) is actually the **`clientUserId` business key**, not the internal auto-increment `id` column that `GetById`'s response body confusingly also happens to expose as a field named `"id"`. Passing that internal `id` value into `DELETE /api/client-user-id/{id}` 500s with a misleading "not found" (it's a `KeyNotFoundException` surfacing as 500 instead of 404 — arguably worth a `NotFound` mapping, but that's a pre-existing pattern, not something steps 8–15 touched). Not filing this as a checklist failure since the checklist's own examples use the `clientUserId` value throughout — just flagging so nobody else loses time on it.

## Step 11 — Run an HR Workflow to its final step with client fields filled in — PASS

Test data: pre-existing dev rider `RD261024` (Vamshi kayapati, Full Time, already sitting at the final "Arara Pending" task, `taskOrder=9`, `IN_PROGRESS`, tasks 1–8 already completed by earlier dev-seeded data — not created by this session). Target slot `99910005` (ZT-B block, created fresh by the HR Workflow submission itself, not pre-created — this path calls the same `POST api/client-user-id` used by the HR flow, which creates a brand-new row, so pre-creating the slot would have collided on the unique `clientUserId` constraint).

- UI: HR Workflow page → searched `RD261024` → "Take Task" → final "Arara Pending" step form:
  - Arara Completed → Yes
  - Rider Status → Active
  - Client → typed "TLBT", selected first match (resolved to `CLT2602`)
  - Client Contract Expiry → `01/06/2027`
  - Client User Id → `99910005`
  - Task Status → Completed
  - Submit.
- Result: `PUT api/rider/RD261024/status` (200) → `PUT api/hrworkflow/task/update` (200, task `taskStatusId=2` COMPLETED) → `POST api/client-user-id` (client assignment created).
- Verified: slot `99910005` `statusId=1` (Active), `riderId=RD261024`, `clientId=CLT2602`, `contractExpiry=2027-06-01`. New `ClientRiderConfig` row 1679, `assignmentType=PERMANENT`, `isActive=1`. Rider `RD261024` `statusId` 2→5 (VisaProcess→Active). Matches expected exactly — "slot created Active with a PERMANENT CRC, exactly as before the rework."

**Minor non-blocking observation, not something the client-user-id rework touched:** the persisted `HrWorkflow.taskDetails` for this task still shows `"araraCompleted":false` even though the UI form had "Arara Completed: Yes" selected at submit time (confirmed via screenshot). Every other field submitted correctly (`documentsCollected`, `hiringStatus`, the new client assignment). This looks like a pre-existing quirk in the generic task-details field serialization on the HR Workflow module itself, unrelated to `CreateClientUserIdAsync`/`RiderAssignmentService` — flagging for awareness, not filing as a checklist failure since it's outside the scope of what step 11 is checking (the client-assignment side-effect, which worked correctly).

**Automation gotcha for whoever else drives this UI with Playwright:** the two Ant Design `<Select>` fields in this modal (`#riderStatus`, `#client-dropdown`, likely `#taskStatus` too) must be driven by clicking the field, typing the search text, then `ArrowDown` + `Enter` — clicking the rendered `.ant-select-item-option` div directly is unreliable (a stale/zero-size DOM node can silently no-op or, worse, land the click on an unrelated element underneath at its last-known coordinates). Cost me a couple of failed attempts before switching approach; leaving this here so it doesn't bite session A too if they hit the same modal.

## Step 12 — Add Rider as Part Time, picking a Client User ID in Documents step — PASS

Test data: new rider `RD261688` ("ZT-B- Step12 Test Rider", created by this flow), target slot `99910006` (ZT-B block, pre-created as FreeId so it showed up in the Documents step's free-IDs dropdown).

- UI: Riders page → "Add Rider" → 4-step wizard:
  - Basic Info: name `ZT-B- Step12 Test Rider`, DOB `15/05/1996`, nationality India, phone, email, Profession=Car, **Employment Type=Part Time** (Rider Status radio correctly disabled/skipped for Part Time).
  - Documents Info (Part Time reveals the extra fields): passport/license/civil ID + expiries, **Client User ID dropdown → selected `99910006`**, Client User ID Start Date → today, Civil ID document upload.
  - Surety Person: left blank (all optional).
  - Review & Confirm: confirmed all values including `Client User Id: 99910006` and `Start Date: 29/09/2026` before submit.
- Result: new rider `RD261688` created, `hireTypeId=2` (Part Time), `statusId=5` (Active). Slot `99910006` → `statusId=6` (Working Part-Time), `tempRiderId=RD261688`. New `ClientRiderConfig` row 1680, `assignmentType=TEMP`, `isActive=1`, `startDate=`today. **`contractExpiry` on the slot is unchanged** (`2027-06-01`, the value set when the slot was created — this flow only sets the assignment, not the contract, exactly as expected). Matches expected exactly.

**Two UI gotchas hit along the way, both pre-existing and outside this rework's scope, noted for whoever else drives this wizard:**
1. The `react-international-phone` widget (used for Mobile Number and Surety Person Phone) can never be made truly empty — it always keeps at least the dial-code prefix (e.g. `+971`). The Surety Person Phone field is optional and its validation rule is `if (!v) return true`, but since the field's value is never falsy, submitting with it "empty" fails "Enter a valid phone number" and blocks the wizard. Worked around by entering a valid, rider-distinct number instead of leaving it blank.
2. Both Ant Design `<Select>` fields on this wizard (Nationality, Client User ID) and the two on the HR Workflow modal (step 11) share the same automation quirk noted there — drive them with click → type-to-search → `ArrowDown` → `Enter`, not by clicking the rendered option div.

## Step 15 — New rider hireTypeId set; PUT with hireTypeId in body is a no-op — PASS

Test data: new Full Time rider `RD261689` ("ZT-B- Step15 FullTime Rider"), created via the Add Rider UI wizard (Employment Type=Full Time, Rider Status=Visa Process; Documents step for Full Time has no civil-ID/client-user-id fields, matching `isPartimer` gating).

- Confirmed `Rider.hireTypeId = 1` in the DB immediately after creation (Full Time → 1, per the Phase 3 backfill mapping).
- `PUT api/rider/RD261689` with body `{"riderName": "...", "hireTypeId": 2}` → **200 OK**, no error.
- Re-queried DB: `hireTypeId` still `1` — the field was silently ignored, not overwritten.
- Confirmed by reading `RiderUpdateRequest` (`CAG.Admin.API.Domain/Model/APIModels/Rider/RiderAPIModel.cs:34-64`): the class genuinely has no `HireTypeId` property, so ASP.NET's model binder drops the unmatched JSON key — this is why it silently no-ops instead of erroring. Matches expected exactly.

## §3 grid item — Delete action hidden (not just disabled) on a slot with history — PASS

(Session A confirmed the "Current Type shows '—'" grid item already covers this session's assignment too, per `test-run/results-A.md` §3c — not repeated here. Session A explicitly left "Delete hidden" for this session.)

Test data: slot `99910002` (has history: Churn → Clearance Completed → reassigned, from step 9) vs. slot `99910007` (freshly created via API, zero history, ZT-B block).

- UI: Client User ID grid → row action "⋮" menu for each:
  - `99910002` (has history): menu shows **`Suspend`, `Mark Churn`, `Edit`** — no Delete item at all (confirmed via screenshot — genuinely absent from the DOM, not a greyed-out disabled entry).
  - `99910007` (no history): menu shows **`Suspend`, `Mark Churn`, `Edit`, `Delete`**.
- Matches the `ClientUserIdActionMenu` code path exactly (`if (!props.data.hasHistory) addItem("delete", ...)`), and matches expected UI behavior.

**Separate tangential observation, also not in scope for steps 8–15:** `GET api/client-user-id/all` (no `details`/`free` query param — i.e. `GetAllClientUserIdsAsync`/`GetAllClientUserIdsWithOutFilter`) returned a stale row for `99910002` (wrong `statusId`, `createdAt`, `createdBy` from before today's test writes; `99910001`/`99910003` missing entirely) while `GET api/client-user-id/99910002` (single-item `GetById`) and the UI grid (`details=true` → `GetAllClientUserIdsWithDetailsAsync`, used by the actual Client User ID page) both showed correct live data. The UI's main grid page doesn't call the plain `/all` endpoint (only `GetAllClientUserIdsAsync` hook exists in `hooks/react-query/client-user-id.tsx`, no page wired to it that I found), so this likely doesn't affect any user-facing flow — flagging only in case it's used elsewhere or by another consumer.



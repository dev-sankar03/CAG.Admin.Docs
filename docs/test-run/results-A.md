# Results - Session A (Cowork). Data prefix ZT-A-
Owner: steps 5,6,7,13(skipped: no file),+ section 3 items. Update after EVERY step.

## Step 5 - Ineligible Full Time rider TEMP assign -> 400 - PASS
Test data: rider RD260764 (Full Time, active permanent assignment) and RD260054 (Full Time, FreeId, no active assignment); target slot 99920001 (ZT-A block, created via POST api/client-user-id -> 200, FreeId).
- RD260764: POST rider/{id}/client-assignment TEMP -> 400 "Rider already has an active client assignment." (different guard, blocked first).
- RD260054: same call -> 400 "Only Part Time riders, or Full Time riders whose home Client User Id is suspended, can be assigned temporarily." Rider status stayed 4, slot 99920001 stayed FreeId, tempRiderId null. No 500, no silent success.
Note (to review): GET api/client-user-id/all returns rows that disagree with GET api/client-user-id/{clientUserId} (e.g. 99900001 shows statusId 5 and createdAt 2026-01-29 in /all vs statusId 2 and createdAt 2026-09-28 by id; 99900002 missing from /all). Check whether the grid uses /all in the section 3 UI checks.
Note: route {id} is the clientUserId number, not the internal id.
Verified via: API only (no direct DB access from Session A).

## Step 6 - Resume step-3 slot with "Return holder" - PASS
Test data: slot 99900001 (home, was Client Suspended), slot 99900002 (TEMP), rider RD260053.
- GET client-user-id/99900001/resume-preview -> holder RD260053, holderActiveClientUserId 99900002, holderActiveAssignmentType TEMP (preview shows rider and current temp slot).
- PUT client-user-id/99900001/resume {date:2026-09-29, returnHolder:true} -> 200.
- Result: TEMP CRC on 99900002 ended (endDate 2026-09-29, endReason=ReturnedToHome); 99900002 statusId 5 (FreeId), tempRiderId null; 99900001 statusId 1 (Active), riderId RD260053, new PERMANENT CRC (start 2026-09-29, open); rider status 5 (Active).
Verified via: API only.

## Step 7 - Suspend a different slot, Resume with "Just free the ID" - PASS
Test data: slots 99920001 and 99920002 (ZT-A block), rider RD260054 (Full Time; NOTE: this rider was also used by Session B in step 9 - its 99910002 CRC ended with Churn - so B should not assume RD260054 is untouched).
- Setup: assign RD260054 PERMANENT to 99920001 -> 200; suspend 99920001 -> 200; assign RD260054 TEMP to 99920002 (allowed, home suspended) -> 200. Snapshot: rider status 5, 99920001 status 2, 99920002 status 6, TEMP CRC open.
- resume-preview -> holder RD260054 currently on 99920002 TEMP.
- PUT client-user-id/99920001/resume {returnHolder:false} -> 200.
- Result: 99920001 statusId 5 (FreeId). Holder untouched: rider status still 5, TEMP CRC on 99920002 still open (no endDate/endReason), 99920002 still status 6, no new CRC rows. Slot keeps riderId RD260054 as former-holder link with isAssigned=false.
- Cleanup: PUT rider/RD260054/client-assignment/end -> 200; rider status 4 (FreeId), 99920002 FreeId (extra confirmation of TEMP End).
Verified via: API only.

## Section 3 UI checks (Claude in Chrome, logged in as testacc@getnada.com, TEST001, CAG_RIDER.EDIT)
### 3a Rider page "Current client" card - PASS
Rider Employment tab (/Rider/{id}/details). RD260053 (Active PERMANENT on 99900001): TYPE badge "Permanent", SLOT STATUS "Active". RD261180 (Part Time, TEMP on 99920002): TYPE "Temporary" (blue badge), SLOT STATUS "Working Part-Time" (grey badge). Both readable; Switch / End assignment buttons visible for edit user.
### 3b Rider page client history - PASS
RD260053 shows 3 mappings, each with Type (Permanent/Temporary) and "Ended: ClientSuspended" / "Ended: ReturnedToHome" on ended rows; open row shows "present". Cosmetic observations: end reasons render as raw enum text (ClientSuspended, ReturnedToHome), not spaced/friendly; legacy rows (e.g. 798859, ended 01/06/2026) show no "Ended:" line because endReason is null - expected.
Screenshots: Chrome tmp folder only (not saved to repo).
Test data: RD261180 assigned TEMP to 99920002 (to be ended after grid checks).

### 3c Client User ID grid (/Rider/Client-User-Id): status badges + Current Type - PASS (with 2 findings)
Test slots (ZT-A block, created/moved via API): 99920001 Client Suspended, 99920002 FreeId, 99920003 Churn, 99920004 Clearance Completed. Searching "999200" shows all four together: Client Suspended = amber, FreeId = blue, Churn = red, Clearance Completed = grey, Active = green, Working Part-Time = green/teal. Distinct and readable. Current Type shows "-" for all of Client Suspended/FreeId/Churn/Clearance Completed (no active assignment); Permanent/Temporary for active ones. (This also covers Session B's "Current Type -" item.)
FINDING 1 (minor/cosmetic): the "Clearance Completed" badge text is clipped ("Clearance Comple...") because the Status column is too narrow.
FINDING 2 (likely bug): Status filter chip "Free ID" returns "No Rows To Show" although FreeId slots exist (99920002 is FreeId and listed when unfiltered). Other status chips (Churn, Client Suspended, Clearance Completed) filter correctly. Hypothesis (not confirmed in code): grid badge text comes from API statusName "FreeId" while the filter option/enum label is "Free ID" (app/enum/client-user-id-status.ts), so the string match fails. Worth checking the filter matching in the grid.
### 3d Grid Rider ID links - PASS
Rider ID cell renders <a href="/Rider/{riderId}">; clicking RD260054 opened /Rider/RD260054 with the correct rider (name/ID match).
### 3e Permission gating - NOT DONE (no read-only user available yet)
### Not done by Session A: Delete hidden on slot with history (owned by Session B), step 13 (no order file), 04b_Verify.sql (needs DB access)
### Cleanup note: all Session A test rows use client user IDs 99920001-99920004, riders RD260054/RD261180/RD261182 were only touched via assignments that were ended. Slots with history cannot be deleted (by design), so they remain in Dev.

### 3e Permission gating - PASS in the UI, FAIL on the API (two findings)
User: testacc@yopmail.com (works with the password Welcome@123; the earlier Welcome3! was wrong). JWT ModulePermissions contains CAG_RIDER.VIEW only (no CAG_RIDER.EDIT).
UI (all hidden as expected):
- Rider page /Rider/RD260053/details Employment tab (active PERMANENT): no Switch, End assignment, Assign, Change company or Edit details buttons; Current client card still renders read-only. "More actions" menu only contains "Copy rider ID".
- Rider page RD260054 (no active assignment): card says "This rider isn't mapped to a client." with no Assign Client User ID button.
- Client User ID grid: no row action column or per-row menu (Suspend/Resume/Churn/Clearance/Delete all absent). Export, Filter, Columns visible (read-only, fine).
FINDING 3 (UI gap): the "Add Client User Id" button is still visible to the view-only user on the grid. It is not in the checklist's list of actions, but it is a write action.
FINDING 4 (SECURITY / server-side gap, high): with the view-only token the API accepted writes. POST api/client-user-id {clientUserId:99920005,...} -> 200, row created (id 4138, GET afterwards 200). PUT api/client-user-id/99920005/suspend -> 200, statusId became 2. So CAG_RIDER.EDIT is enforced only in the UI, not by these API endpoints (CLAUDE.md says the API re-checks via ICurrentUserService, but that does not appear to gate these). Not tested for the rider assign/switch/end endpoints, so check those too.
Test data left in Dev: slot 99920005 (Client Suspended, created by the view-only user). 99920001-99920005 are all Session A slots.
Edit user testacc@getnada.com session was restored afterwards.

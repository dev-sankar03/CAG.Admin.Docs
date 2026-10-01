# Implementation Plan — Client User ID Assignment Rework

> **Audience:** the implementing agent (Sonnet). Read this whole file before touching code.
> **Repos:** `CAG.Admin.API` (branch `feature/rider_enhancement`), `CAG.Admin.UI`, `CAG.Admin.Docs`. Each is its own git repo — commit separately.
> **Background reading (skim, don't re-derive):** `docs/client-clientuserid-mapping.md`. Where it disagrees with this plan, **this plan wins** — that doc's temp-rider state diagram is wrong (see §1.3).

---

## 0. Ground rules

1. **Never write to `CAG_Admin_PROD`.** Apply migrations to `CAG_Admin_Dev` first, then `CAG_Admin_QA` only when the user says so. Read-only `SELECT`s against QA are fine.
2. **Do not touch:**
   - HR Workflow (`CAG.Admin.UI/src/app/(pages)/HR/Workflow/**`, `HrWorkflowService`). Its final step keeps calling `POST api/client-user-id` with a rider — that endpoint must keep working for it (§4.4).
   - Payroll `RiderOrderService.GetClientUserIDs` — leave its logic exactly as is.
3. **There are no automated tests in either repo.** Verification = `dotnet build`, `npx tsc --noEmit`, `npm run lint`, the SQL checks in §8, and the manual flows in §8.
4. **Stop and ask the user** (don't guess) when: a cleanup row needs a judgement call (§3.2), a query you're changing returns different row counts than before for reasons not explained here, or any rule in §1 seems to contradict existing behaviour you find.
5. Match the surrounding code style (primary-constructor services, Dapper via `GenericRepository`, `AdminAPIException` for errors, `APIResponseModel` via `Success(...)`).
6. **Generated DB columns must NOT be added to C# DB models.** `DapperHelper.BuildInsert/BuildUpdate` write every public property, and MariaDB rejects writes to generated columns.

---

## 1. Target model (locked decisions)

### 1.1 Entities

| Table | Role after this change |
|---|---|
| `Rider.hireTypeId` | Employment type **at onboarding**. Set once in `AddRiderAsync`; never updated afterwards. `employmentType` stays as the *current* type. |
| `ClientUserId` | The client-issued account ("slot"). `riderId` = **permanent holder** (home slot). New `statusId`. `tempRiderId` and `isAssigned` remain as denormalised fields, written **only** by the new assignment service. |
| `ClientRiderConfig` (CRC) | Assignment history and the **source of truth** for "who is working on which ID, as what, when". New `assignmentType` (PERMANENT/TEMP at time of use) and `endReason`. |
| `ClientUserIdStatusHistory` (new) | Log of every slot status change. |

### 1.2 Lookup values (insert with fixed IDs)

`HireType`: 1 = `Full Time`, 2 = `Part Time`

`ClientUserIdStatus`:

| id | name | Set by | Meaning |
|---|---|---|---|
| 1 | Active | auto | Permanent holder is working on it (active CRC, type PERMANENT) |
| 2 | Client Suspended | manual | Client suspended the account; nobody works on it |
| 3 | Churn | manual | Permanent holder left |
| 4 | Clearance Completed | manual | Clearance done after churn (from Churn only) |
| 5 | FreeId | auto | No active CRC; available |
| 6 | Working Part-Time | auto | Temporary rider working on it (active CRC, type TEMP) |

> **Update 2026-10-01:** displayed as **ID Issued for Part-Time** (the client's wording; status 5 as **Free ID**) — see `2026-10-01_ClientUserIdStatus_Names.sql`. Vacation is deliberately not a Client rider status. The rest of this plan keeps the original names.

`assignmentType`: `ENUM('PERMANENT','TEMP')`
`endReason` (VARCHAR(30)): `Ended`, `Switched`, `ClientSuspended`, `Churn`, `ReturnedToHome`, `Vacation`, `SlotDeleted`

### 1.3 Invariants (enforce in service AND DB where noted)

- I1 (DB): a rider has **at most one active CRC**.
- I2 (DB): a slot has **at most one active CRC**. (Temp cover happens only when the permanent holder is *not* working — there is never a permanent and a temp active at the same time.)
- I3 (DB): a rider is the permanent holder (`ClientUserId.riderId`) of **at most one** slot whose status is not Churn/Clearance Completed.
- I4 (service): status ∈ {Active, Working Part-Time} ⇔ slot has an active CRC ⇔ `isAssigned = 1`. `tempRiderId` is non-null ⇔ status = Working Part-Time.
- I5 (service): CRC periods on the same slot, and for the same rider, must not overlap for new writes: new `startDate` ≥ the latest `endDate` on that slot and for that rider.
- I6 (service): dates are ≤ today; `endDate` ≥ `startDate` (DB already has a CHECK).

### 1.4 Operations & transitions

**Rider-side (Rider page):**

| Op | Preconditions | Effects |
|---|---|---|
| **Assign PERMANENT** | Slot status = FreeId **and** (`slot.riderId` is null **or** = this rider); **or** slot status = Clearance Completed (replaces former holder — UI must confirm). Rider `employmentType = 'Full Time'`. Rider has no active CRC. Rider is not holder of another live slot (I3). | Insert CRC (PERMANENT, active). Slot: `riderId = rider`, `statusId = Active`, `isAssigned = 1`, `tempRiderId = NULL`. Rider status → Active. |
| **Assign TEMP** | Slot status = FreeId and `slot.riderId ≠ rider`. Rider has no active CRC. Rider is **Part Time**, **or** Full Time whose home slot (`riderId = rider`, status not Churn/Clearance) has status **Client Suspended**. | Insert CRC (TEMP, active). Slot: `tempRiderId = rider`, `statusId = Working Part-Time`, `isAssigned = 1`. Rider status → Active. |
| **End** | Rider has an active CRC. | CRC: `endDate`, `isActive = 0`, `endReason = Ended`. Slot: `statusId = FreeId`, `isAssigned = 0`, `tempRiderId = NULL`. Rider status → FreeId. |
| **Switch** | = End (reason `Switched`) + Assign on the same date, one transaction. | |

**Slot-side (Client User ID module):**

| Op | From | Effects |
|---|---|---|
| **Suspend** | Active, FreeId, Working Part-Time | End active CRC if any (reason `ClientSuspended`; that rider → FreeId). Slot → Client Suspended, `isAssigned = 0`, `tempRiderId = NULL`. |
| **Resume** | Client Suspended | Two-step, **user confirms first** (decision 3). `GET …/resume-preview` returns the holder, the holder's rider status, and the holder's current active CRC elsewhere (if any). UI shows a confirm dialog: "Return RDxxx to this ID as permanent rider? (ends their temporary assignment on 123456)". **Yes** → end the holder's other CRC (reason `ReturnedToHome`, the other slot → FreeId), then Assign PERMANENT here → Active. **No** → slot → FreeId; holder untouched. If there's no holder → straight to FreeId. |
| **Mark Churn** | any except Churn / Clearance Completed | End active CRC if any (reason `Churn`, rider → FreeId). Slot → Churn, `isAssigned = 0`, `tempRiderId = NULL`. |
| **Clearance Completed** | Churn only | Slot → Clearance Completed. |
| **Edit** | any | Only `contractExpiry` and `clientId`. No rider fields. |
| **Delete** | slot has **no** CRC rows at all | Hard delete. Otherwise reject with "Use Churn / Clearance Completed instead" (the FK in §2.5 would block it anyway). |

Every status change writes a `ClientUserIdStatusHistory` row (`fromStatusId`, `toStatusId`, `changedAt`, `effectiveDate`, `reason`, `changedBy`).

Rider status side effects keep using the existing `RiderService.ChangeRiderStatus` (START → Active, END → FreeId — it also auto-unassigns the vehicle on FreeId; keep that behaviour).

---

## 2. Phase 1 — Schema migration (additive, re-runnable)

File: `CAG.Admin.API/Database/Migrations/2026-09-28_ClientUserIdAssignment_01_Schema.sql`. Follow the header-comment style of `2026-09-27_RiderProfilePhoto.sql` (purpose, used-by, "run against target DB, no USE", "Re-runnable", "Applied to:"). MariaDB is 10.11 → `IF NOT EXISTS` works on tables, columns, indexes and FKs.

2.1 `HireType` table (`hireTypeId INT PK`, `hireTypeName VARCHAR(30)`, `isActive`), then `INSERT IGNORE` rows 1 and 2.
2.2 `ClientUserIdStatus` table (`statusId INT PK`, `statusName VARCHAR(40)`, `statusOrder INT`, `isActive`), then `INSERT IGNORE` rows 1–6.
2.3 `ClientUserId`: `ADD COLUMN IF NOT EXISTS statusId INT NULL`.
2.4 `ClientRiderConfig`: `ADD COLUMN IF NOT EXISTS assignmentType ENUM('PERMANENT','TEMP') NULL`, `ADD COLUMN IF NOT EXISTS endReason VARCHAR(30) NULL`.
2.5 `ClientUserIdStatusHistory` table: `id` PK auto-increment, `clientUserId INT NOT NULL`, `fromStatusId INT NULL`, `toStatusId INT NOT NULL`, `effectiveDate DATE NOT NULL`, `reason VARCHAR(200) NULL`, `changedAt DATETIME NOT NULL DEFAULT UTC_TIMESTAMP()`, `changedBy VARCHAR(20) NULL`, index on `clientUserId`.
2.6 `Rider.hireTypeId` is already `INT NULL` (every row is 0 today). No column change needed.

Everything is nullable in this phase so the running app keeps working. NOT NULL, unique keys and FKs come in Phase 4 (§5).

---

## 3. Phase 2 — Anomaly report → user decisions → cleanup

### 3.1 Report (read-only)

File: `…_02_Report.sql`. Run it against QA and Dev and put the output into a markdown table in your reply to the user. The QA counts as of 2026-09-28 are shown so you can sanity-check:

| # | Check | QA count |
|---|---|---|
| R1 | Slots with >1 active CRC (list clientUserId, riderId, startDate, crc id) | 4 slots (2088962 = exact duplicate; 4617568 and 4726292 = same rider twice; 4331738 = two different riders) |
| R2 | Riders with >1 active CRC | 4 riders (3 Full Time) |
| R3 | Slots `isAssigned = 0` with an active CRC | 3 |
| R4 | Active CRC whose rider is neither `riderId` nor `tempRiderId` of the slot | 1 |
| R5 | CRC rows whose `clientUserId` has no `ClientUserId` row | 6 |
| R6 | Riders who are `riderId` on >1 slot | 8 (RD260182, RD260221, RD260518, RD260611, RD260619, RD260716, RD260756, RD260947) |
| R7 | Slots whose `riderId` has no `Rider` row | 1 |
| R8 | CRC rows where the assignment type can't be inferred (Full Time rider who is neither the slot's holder nor its temp) | 5 |
| R9 | Overlapping CRC periods on the same slot | 34 pairs (report only; historical) |

### 3.2 Cleanup (write only after the user answers)

File: `…_03_Cleanup.sql`. The only rule you may apply **without asking**:
- R1 **exact duplicates** (same slot, rider and `startDate`, both active): delete the higher `clientRiderConfigId`.

For everything else (the rest of R1, R2, R3, R4, R5, R6, R7, R8) propose a per-row fix in your reply and **wait for the user to choose**. Suggested defaults to offer:
- Same rider active twice on one slot → keep the earliest row, delete the later one.
- Two different riders active → end the earlier row at the later row's `startDate`.
- R3 → end the CRC at the slot's `updatedAt`.
- R5 → delete.
- R6 → the user picks which slot the rider keeps; set `riderId = NULL` on the other.
- R7 → set `riderId = NULL`.

R9 is left as is.

---

## 4. Phase 3 — Backfill

File: `…_04_Backfill.sql`, run in one transaction, in this order:

1. **Hire type:** `UPDATE Rider SET hireTypeId = IF(employmentType = 'Full Time', 1, 2)` for all rows (approved: backfill from current `employmentType`).
2. **CRC assignment type:** `PERMANENT` where the rider's `employmentType = 'Full Time'`, else `TEMP`. R8 rows get whatever the user decided in §3.2 (default PERMANENT).
3. **Vacation holders (decision 2):** for slots with `isAssigned = 1 AND tempRiderId IS NULL` whose holder's `Rider.statusId IN (9, 10)` (Vacation, Vacation Overdue) — 60 in QA:
   - End the holder's active CRC: `endDate = GREATEST(latest LeaveRequest.startDate WHERE status = 'Approved' AND startDate <= CURDATE(), crc.startDate)`, falling back to `CURDATE()` when there's no approved leave. Set `isActive = 0`, `endReason = 'Vacation'`.
   - Slot: `isAssigned = 0`.
   - Do **not** change the rider's own status.
4. **Slot status:**
   - `isAssigned = 1 AND tempRiderId IS NOT NULL` → 6 Working Part-Time. This deliberately includes the 79 slots whose holder is Cancelled (decision 1).
   - `isAssigned = 1 AND tempRiderId IS NULL` → 1 Active.
   - `isAssigned = 0` → 5 FreeId. Also set `tempRiderId = NULL` here, to satisfy I4.
5. **History:** insert one `ClientUserIdStatusHistory` row per slot (`fromStatusId = NULL`, `reason = 'Backfill 2026-09-28'`).

Expected QA result, give or take the cleanup: Active ≈ 817, Working Part-Time = 111, FreeId ≈ 151.

---

## 5. Phase 4 — Constraints

File: `…_05_Constraints.sql`. Run only after Phases 2 and 3 are clean.

```sql
ALTER TABLE ClientUserId      MODIFY statusId INT NOT NULL DEFAULT 5;
ALTER TABLE ClientRiderConfig MODIFY assignmentType ENUM('PERMANENT','TEMP') NOT NULL;

-- I1 / I2
ALTER TABLE ClientRiderConfig
  ADD COLUMN IF NOT EXISTS activeRiderKey VARCHAR(20) AS (IF(isActive = 1, riderId, NULL)) PERSISTENT,
  ADD COLUMN IF NOT EXISTS activeSlotKey  INT         AS (IF(isActive = 1, clientUserId, NULL)) PERSISTENT,
  ADD UNIQUE INDEX IF NOT EXISTS UX_CRC_ActiveRider (activeRiderKey),
  ADD UNIQUE INDEX IF NOT EXISTS UX_CRC_ActiveSlot  (activeSlotKey);

-- I3
ALTER TABLE ClientUserId
  ADD COLUMN IF NOT EXISTS liveHolderKey VARCHAR(20) AS (IF(statusId IN (3,4), NULL, riderId)) PERSISTENT,
  ADD UNIQUE INDEX IF NOT EXISTS UX_CUI_LiveHolder (liveHolderKey);

-- FKs
ALTER TABLE ClientUserId      ADD CONSTRAINT fk_clientuserid_status   FOREIGN KEY IF NOT EXISTS (statusId)     REFERENCES ClientUserIdStatus(statusId);
ALTER TABLE ClientUserId      ADD CONSTRAINT fk_clientuserid_rider    FOREIGN KEY IF NOT EXISTS (riderId)      REFERENCES Rider(riderId);
ALTER TABLE ClientRiderConfig ADD CONSTRAINT fk_crc_clientuserid      FOREIGN KEY IF NOT EXISTS (clientUserId) REFERENCES ClientUserId(clientUserId);
ALTER TABLE Rider             ADD CONSTRAINT fk_rider_hiretype        FOREIGN KEY IF NOT EXISTS (hireTypeId)   REFERENCES HireType(hireTypeId);
```

(Check the exact MariaDB syntax for `FOREIGN KEY IF NOT EXISTS` when you write the file. The generated columns stay out of the C# models — see §0.6.)

---

## 6. Phase 5 — API

### 6.1 Domain

- `Domain/Model/Enums/ClientUserIdStatuses.cs` — enum with values 1–6.
- `Domain/Model/Enums/AssignmentType.cs` — `Permanent`, `Temp`. Map it to the DB strings `PERMANENT` and `TEMP`. Dapper won't map a C# enum to a MySQL ENUM string on its own: either store the column as `string` on the DB model with constants, or add a Dapper type handler. **Prefer the `string` property plus constants** — it's the simplest option that matches the codebase.
- `ClientUserIdModel`: add `int StatusId`. `ClientRiderConfig`: add `string AssignmentType` and `string? EndReason`. Do **not** add the generated columns.
- `Rider.HireTypeId`: change `int` to `int?`. **Remove `HireTypeId` from `RiderUpdateRequest`** (`APIModels/Rider/RiderAPIModel.cs:55`) so updates can't change it.
- New DTOs:
  - `RiderClientAssignRequest { int ClientUserId; string Type; string StartDate }`
  - `RiderClientEndRequest { string EndDate }`
  - `RiderClientSwitchRequest { int ClientUserId; string Type; string Date }`
  - `ClientUserIdStatusChangeRequest { string Date; string? Reason }`
  - `ClientUserIdResumeRequest { string Date; bool ReturnHolder }`
  - `ClientUserIdResumePreview { string? HolderRiderId; string? HolderName; int? HolderStatusId; int? HolderActiveClientUserId; string? HolderActiveAssignmentType }`
  - `EligibleClientUserIdDto` (clientUserId, client, holder, status, plus `ReplacesFormerHolder` for Clearance Completed slots)
- Parse all dates with `DateTime.TryParse` and return 400 on failure (never `DateTime.Parse`).

### 6.2 Service — rewrite `RiderAssignmentService`

Replace its body. Keep the class name, because DI registration already exists in `Program.cs`. Public surface:

```
AssignAsync(riderId, clientUserId, AssignmentType, startDate)
EndAsync(riderId, endDate, endReason = "Ended")
SwitchAsync(riderId, newClientUserId, AssignmentType, date)
SuspendAsync(clientUserId, date, reason)
GetResumePreviewAsync(clientUserId)
ResumeAsync(clientUserId, date, returnHolder)
MarkChurnAsync(clientUserId, date, reason)
MarkClearanceCompletedAsync(clientUserId, date, reason)
GetEligibleClientUserIdsAsync(riderId, AssignmentType)
CreateClientUserIdAsync(...)   // the old AssignClientUserToRiderAsync — see 6.4
```

- **One transaction per public method.** Follow the `RiderService.AddRiderAsync` pattern (`_factory.Create()`, `BeginTransaction`, commit/rollback). Pass `connection` and `transaction` into the `GenericRepository` `AddAsync`/`UpdateAsync` overloads, which already accept them. `RiderRepository.ChangeRiderStatus` and `RiderService.ChangeRiderStatus` need optional `IDbConnection?`/`IDbTransaction?` parameters added. Do the same for the vehicle-unassign call inside it if it's reachable.
- Enforce every precondition in §1.4 and §1.3 (I4–I6) with `AdminAPIException(ValidationFailed, "<clear message>", 400)`. Also catch MySQL duplicate-key errors (1062) from the unique indexes and turn them into a 400 with a readable message ("Rider already has an active client assignment", "Client User ID already has an active rider", "Rider is already permanent holder of another Client User ID").
- Every status change goes through a single private `SetStatusAsync(slot, toStatus, effectiveDate, reason, conn, tx)` that updates the slot and writes the history row.
- `GetEligibleClientUserIdsAsync` filters exactly by the §1.4 preconditions. It's company-scoped the same way `ClientUserIdRepository.GetAllFreeClientUserIdsAsync` is.

### 6.3 Clean up the old write paths

- `ClientUserIdService.Update` → only `contractExpiry` and `clientId`. Remove all rider/CRC logic.
- Delete `ClientUserIdService.UpdateClientUserIdAsync` (no callers remain after the rewrite).
- Rewrite `ClientUserIdService.DeleteClientUserIdAsync` to the §1.4 rule (reject if any CRC exists).
- Delete `ClientRiderConfigService.UpdateClientUserIdAsync` and `AddClientUserId`, and `RiderService.UpdateClientUserIdAsync`, plus their interface members.
- `ClientRiderConfigService.AddAsync` gains an `assignmentType` parameter. It's then only used by `RiderAssignmentService`.

### 6.4 Endpoints

**Add to `RiderController`:**
- `GET  api/rider/{riderId}/eligible-client-user-ids?type=PERMANENT|TEMP`
- `POST api/rider/{riderId}/client-assignment` → `AssignAsync`
- `PUT  api/rider/{riderId}/client-assignment/end` → `EndAsync`
- `PUT  api/rider/{riderId}/client-assignment/switch` → `SwitchAsync`

Put these literal routes **above** `[HttpGet("{riderId}")]`-style catch-alls, or constrain them. A route conflict here has bitten this project before.

**Add to `ClientUserIdController`:**
- `PUT api/client-user-id/{id}/suspend`
- `GET api/client-user-id/{id}/resume-preview`
- `PUT api/client-user-id/{id}/resume`
- `PUT api/client-user-id/{id}/churn`
- `PUT api/client-user-id/{id}/clearance-completed`
- `GET api/client-user-id/statuses` (lookup list for the UI)

**Remove:**
- `PUT api/client-user-id/update-rider-assignment`
- the commented-out old PUT block
- `POST api/rider/{riderId}/client`

**Keep, changed:**
- `POST api/client-user-id` (create). The Client User ID module no longer sends a rider. **HR Workflow still sends `riderId` + `startDate`** and must keep working. So: create the slot with status FreeId; then, if `riderId` and `startDate` are present, call the PERMANENT assign logic inside the same transaction. If an `endDate` is also present, write the CRC already ended and leave the slot FreeId. Keep the "Duplicate client user id" check.
- `PUT api/client-user-id` → expiry/client only.
- `GET api/client-user-id/all?free=true` → filter `statusId = 5` instead of `isAssigned = 0`.
- `GET …/all?details=true` → also return `statusId`, `statusName`, and the active CRC's `assignmentType`.

### 6.5 Read queries that must not duplicate rows

A Full Time rider can now be the `riderId` of one slot and the `tempRiderId` of another. That makes `LEFT JOIN ClientUserId cui ON (cui.riderId = r.riderId OR cui.tempRiderId = r.riderId)` return 2 rows per rider (it already does today for the 8 R6 riders). Replace that join in:
- `RiderRepository.cs` ~line 39 (`GetAllRidersAsync`)
- `RiderRepository.cs` ~line 121
- `RiderListQueryBuilder.BaseFromSql` (line 25; also used for paged count and sort)

with "the rider's current slot = their active CRC slot, else their live home slot":

```sql
LEFT JOIN ClientRiderConfig crcA ON crcA.riderId = r.riderId AND crcA.isActive = 1
LEFT JOIN ClientUserId cui ON cui.clientUserId = COALESCE(
    crcA.clientUserId,
    (SELECT h.clientUserId FROM ClientUserId h WHERE h.riderId = r.riderId AND h.statusId NOT IN (3,4) LIMIT 1))
```

**Verify:** the row count from `GetAllRidersAsync` and from the paged total must equal `SELECT COUNT(*) FROM Rider WHERE isActive = 1` (company-scoped) — before the change it may be higher. Report the before/after numbers to the user.

Also check `GetRiderExportAsync` (`RiderRepository.cs` ~line 256), `VehicleRepository.cs` lines 149/255, `VehicleListQueryBuilder.cs` line 24 and `AttendanceRepository.cs` line 63. They join the active CRC, which I1 now guarantees is unique — confirm and leave them alone if so.

### 6.6 Downstream

- **Order import** (`RiderOrderService.ImportRiderOrdersFile` / `ParseRiderOrderWorksheet`, ~lines 257–530). The upload has no per-row date (the "Rider ID" column is the Client User ID), so attribution is monthly:
  - Replace `GetAllClientRiderConfigsAsync()` with `ClientRiderConfigRepository.GetAllMappings(monthStart, monthEnd)`, which already filters CRC periods by overlap.
  - For each row's `clientUserId`: if exactly one CRC overlaps the month, use its rider. If several overlap, pick the one with **the most days inside the month** and add a warning line listing the others. If none, keep today's error ("No ClientRiderConfig found for ClientUserId X for MM-yyyy").
  - Remove the "RiderId mismatch … (using config value)" warning — the holder differing from the worker is now normal (temp cover).
- **Add Rider, Part Time** (`CAG.Admin.UI/src/app/components/modals/rider/add-rider-modal.tsx` ~line 127): replace `updateClientUserId(...)` with a call to the new `POST api/rider/{riderId}/client-assignment` (type `TEMP`, `startDate` = `documentsInfo.startDate` if set, else today). The picker in `documents-info-form.tsx` keeps using `…/all?free=true`, which now means status FreeId.
- **`AddRiderAsync`**: set `rider.HireTypeId = rider.EmploymentType == "Full Time" ? 1 : 2` next to the existing server-side overrides.
- **Payroll `GetClientUserIDs`**: do not change.

---

## 7. Phase 6 — UI (`CAG.Admin.UI`)

### 7.1 Data layer

- `models/admin-api-models/client-user-id.ts`: add `statusId` and `statusName` to `ClientUserIdGrid` and `ClientUserId`; remove `ClientUserIdAssignmentDto`. Add a `ClientUserIdStatus` enum in `enum/client-user-id-status.ts` (1–6) with a label map, in the same style as `enum/rider-status.ts`.
- `models/admin-api-models/rider.ts`: add `assignmentType` and `endReason` to `ClientRiderMapping`.
- `http-client/client-user-id.api.ts`: remove `UpdateRiderClientUserIdAssignmentAsync`. Add suspend, resume-preview, resume, churn, clearance-completed and statuses.
- `http-client/rider.api.ts`: remove `UpdateRiderClientAsync`. Add eligible IDs, assign, end and switch.
- `constants/api-urls.ts`: matching URLs; drop `updateRiderAssignment` and `rider.updateClient`.
- Hooks (`hooks/react-query/client-user-id.tsx` and `rider.tsx`): the mutations must invalidate `["client-user-ids"]`, the rider detail query, the rider list, and `useGetClientRiderConfig(riderId)`.

### 7.2 Rider page (#4) — `components/details/rider/employement-tab.tsx`, "Current client" card

Replace the two `router.push("/Rider/Client-User-Id")` buttons (~lines 222 and 286) with:
- **No active assignment → "Assign Client User ID"** modal (use the existing `Modal` + `AddEditModal` pattern from `(pages)/Rider/Client-User-Id/index.tsx`):
  - Type: Permanent / Temporary. Show only the types the rider is eligible for.
  - Client User ID select, filled from `eligible-client-user-ids?type=`. Label each option `clientUserId · clientCode · holder`.
  - Start date (max today).
  - For a Clearance Completed slot, show an inline warning that it replaces the former holder.
- **Active assignment → "End assignment"** (end date, min = assignment start, max today) and **"Switch"** (type, new ID, date).
- The card shows the Client User ID, client, type badge (Permanent/Temporary), start date and slot status.
- The history table (`useGetClientRiderConfig`) gains **Type** and **End reason** columns.
- Gate every action with `useHasPermission(ModuleCodes.rider, PermissionCodes.edit)`, as the Client User ID page does.

### 7.3 Client User ID module (#5) — `(pages)/Rider/Client-User-Id/index.tsx`, `constants/grid-props/client-user-id.ts`, `components/grid/col-action-button.tsx` (`ClientUserIdActionMenu`)

- **Add form:** remove the whole "Rider Information" section (rider select, start/end dates, auto-populate). It keeps Client and Client User ID + contract expiry.
- **Edit form:** remove "Full Time Rider Information". It keeps contract expiry, plus Client if you add it.
- Delete the assignment modal, `assignmentContext`, `handleUpdateAssignment*`, `tempAvailableRiders`, `permanentEligibleRiders` and the `RiderType`/`AssignmentAction` exports. **Check importers first:** `models/admin-api-models/client-user-id.ts` and `components/grid/col-action-button.tsx` import these types.
- **Grid:**
  - Add a **Status** column (badge; follow `docs/status-badge-design-system.md` in Docs) and a **Current Type** column (Permanent/Temporary/—).
  - Rider ID cells link to `/Rider/{riderId}`.
  - Replace the derived `assignmentStatus` filter with a Status filter built from the lookup.
- **Actions menu** (by status):
  - Active / FreeId / Working Part-Time → Suspend, Mark Churn, Edit, Delete*
  - Client Suspended → Resume, Mark Churn, Edit
  - Churn → Clearance Completed, Edit
  - Clearance Completed → Edit, Delete*
  - (*Delete appears only when the slot has no history. Either the API tells you, e.g. a `hasHistory` flag on the details DTO, or you show it and let the API reject. Prefer the flag.)
- **Suspend / Churn / Clearance modals:** date (max today) plus an optional reason.
- **Resume modal (decision 3):** load `resume-preview`. If there's a holder, show the confirm text from §1.4 with two buttons: **"Return holder"** (`returnHolder: true`) and **"Just free the ID"** (`returnHolder: false`). With no holder, a single confirm.

### 7.4 Leave alone

`(pages)/HR/Workflow/**` — don't edit it. After the API change, verify that its final step still creates the slot and assignment (§8).

---

## 8. Verification

**Build:** `dotnet build CAG.Admin.API/CAG.Admin.API.sln` → 0 errors. In the UI: `npx tsc --noEmit` and `npm run lint` → clean.

**SQL (run on Dev after the migration and again after the manual flows):**

```sql
-- I1, I2 (must be 0)
SELECT riderId FROM ClientRiderConfig WHERE isActive=1 GROUP BY riderId HAVING COUNT(*)>1;
SELECT clientUserId FROM ClientRiderConfig WHERE isActive=1 GROUP BY clientUserId HAVING COUNT(*)>1;
-- I4 (must be 0)
SELECT c.clientUserId FROM ClientUserId c
LEFT JOIN ClientRiderConfig x ON x.clientUserId=c.clientUserId AND x.isActive=1
WHERE (c.statusId IN (1,6)) <> (x.clientRiderConfigId IS NOT NULL)
   OR (c.statusId IN (1,6)) <> (c.isAssigned=1)
   OR (c.statusId=6) <> (c.tempRiderId IS NOT NULL)
   OR (c.statusId=1 AND x.assignmentType<>'PERMANENT')
   OR (c.statusId=6 AND x.assignmentType<>'TEMP');
-- hire type (must be 0)
SELECT COUNT(*) FROM Rider WHERE hireTypeId IS NULL OR hireTypeId=0;
```

**Manual flows (API via Swagger or UI, on Dev):**
1. Create a Client User ID with no rider → status FreeId.
2. Assign a Full Time rider as PERMANENT from the Rider page → slot Active, CRC PERMANENT, rider Active.
3. Suspend the slot → CRC ended (`ClientSuspended`), rider FreeId, slot Client Suspended.
4. Assign the same Full Time rider as TEMP on another FreeId slot → allowed (home slot suspended). The other slot shows Working Part-Time.
5. Try assigning a Full Time rider whose home slot is **not** suspended as TEMP → 400.
6. Resume the first slot, answer "Return holder" → the TEMP CRC ends (`ReturnedToHome`), the other slot goes FreeId, the home slot goes Active.
7. Resume again on a different suspended slot, answer "Just free the ID" → FreeId; holder untouched.
8. Assign a Part Time rider as TEMP, then End → slot FreeId, rider FreeId.
9. Churn → Clearance Completed → assign a new Full Time rider as PERMANENT (with the replace warning) → Active, `riderId` replaced.
10. Try to delete a slot with history → rejected. Delete a brand-new slot → OK.
11. Run an HR Workflow to its final step with client fields → slot created Active with a PERMANENT CRC (HR code unchanged).
12. Add Rider as Part Time with a Client User ID picked → TEMP CRC, slot Working Part-Time, `contractExpiry` **unchanged**.
13. Order import for a month in which a slot changed rider mid-month → orders go to the rider with more days, plus a warning line.
14. Rider list and paged total counts equal the active rider count (§6.5).
15. New rider → `hireTypeId` set. `PUT api/rider/{id}` with `hireTypeId` in the body → the value doesn't change.

---

## 9. Docs (`CAG.Admin.Docs`)

- Rewrite §2.3–§2.4 and §3.4–§3.5 of `docs/client-clientuserid-mapping.md` to describe this model: statuses, state machine, endpoints, ER diagram with the new columns and tables.
- Add a short note in `docs/rider-management.md` pointing to the Rider-page assignment and to `hireTypeId`.
- Add a row to `docs/implementation-tracker.md` if it tracks work items.

---

## 10. Suggested commit sequence

**API:**
1. Migrations 01–02 (+ 03–05 once approved)
2. Domain models and enums
3. `RiderAssignmentService` rewrite and old-path removal
4. Controllers
5. Read-query dedupe (§6.5)
6. Order import

**UI:**
1. Data layer
2. Rider page
3. Client User ID module
4. Add Rider part-time path

**Docs:** one commit.

Stop after **API commit 1** and **after running the report (§3.1)** to get the user's cleanup decisions before going further.

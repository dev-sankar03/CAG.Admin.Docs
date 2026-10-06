# 13 — Mandoob Activities Module (Milestone 1 / Follow-up Dashboard M2)

> Source: `CAG_Phase_II.docx` → *Mandoop Activities (Milestone 1)* ("Mandoob" = government-liaison
> representative)
> Modules touched: **New Activities module**, Users (Mandoob users), Rider, Client, Company.
> **Status: built 2026-10-06 (Milestone 1 and the M2 dashboard) — see [§4](#4-decisions--implementation-2026-10-06). DB script on Dev only; UI not yet browser-tested.**
> Related docs: [users/roles](../authentication-authorization.md),
> [id generation](../authentication-authorization.md), [dataviz](../implementation-impact-analysis.md).

## 1. Requirement (as specified)

A new module: **Activity Types (master)**, **Add Activity**, **Activity List** (all M1) and a
**Follow-up Dashboard** (M2).

- **Activity Types master** — not hardcoded; add new types anytime. Examples: Legal Issue, Daftar
  Renewal, Akhama Renewal, Visa Renewal, License Renewal, Municipality, PACI, Medical, Residency
  Transfer, Company Documents, Other.
- **Add Activity** fields: Activity Type (dropdown), Company Code (dropdown), Rider (dropdown),
  Client (optional, dropdown), Priority (Low/Medium/High/Urgent), Subject (text), Description (text
  area), Due Date, Assigned To Mandoob (users to be created), Status (Open/In Progress/Pending/
  Completed/Cancelled), Attachment, Created By (name, date, time).
- **Follow-up section** — every activity supports **unlimited follow-ups**.
- **Dashboard cards:** Total Activities, Open, Pending, Completed, Overdue, Due Today.
- **Filters:** Company, Activity Type, Status, Priority, Assigned To, Month, Date Range.
- **Activity List columns:** Activity ID, Company, Type, Subject, Due Date, Priority, Status,
  Assigned To. Clicking an activity opens full details + follow-up history.

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- **New module** (`(pages)/Mandoob-Activities/**`): Activity List (grid + filters), Add/Edit
  Activity form, Activity detail page with a follow-up thread, Activity Types master admin, and a
  Follow-up Dashboard (cards + charts, M2).
- Dropdowns reuse existing lookups: Company (code), Rider, Client; plus the new Activity Type master
  and Mandoob users.

### API / DB (`CAG.Admin.API`)
- **New tables:**
  - `ActivityType` — master (`Id`, `Name`, `IsActive`, audit).
  - `Activity` — `ActivityId` (business id, e.g. `ACT{yy}{0000}` via `IdGenerator`), `ActivityTypeId`,
    `CompanyId`, `RiderId`, `ClientId?`, `Priority`, `Subject`, `Description`, `DueDate`,
    `AssignedToUserId`, `Status`, `AttachmentPath`, audit.
  - `ActivityFollowUp` — `Id`, `ActivityId`, `Note`, `AttachmentPath?`, `CreatedBy`, `CreatedAt`
    (unlimited follow-ups per activity).
- **New endpoints** `api/activity/*` (CRUD, list w/ filters), `api/activity/{id}/followup` (list/add),
  `api/activity/type/*` (master), dashboard aggregates (counts + overdue/due-today), all
  **company-scoped**.
- **Mandoob users** — new users assigned a Mandoob role (extend `Role`/`RoleCodes`); "Assigned To"
  references a user.

### Cross-cutting
- **Master + dropdown** pattern shared with [12](12-company-expenses.md) and [06](06-order-values.md).
- **Follow-up thread** pattern shared with [05](05-complaint-section.md) comments and the existing
  `LeaveRequestComment` — reuse.
- New **Mandoob role** ties into the role/permission model
  ([cross-cutting](../authentication-authorization.md)); a new
  `ModuleCode` (`CAG_MANDOOB`?) may be needed for gating.
- "Legal Issue" appears here as an activity type **and** as a new company status in
  [02](02-rider-management-status.md) — clarify the relationship (status vs activity).

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Activity detail + follow-up — one page with an inline follow-up composer, or a modal?
  💡 A detail page with a follow-up timeline + composer (like a lightweight ticket). Reuse the
  comment-thread UX from `LeaveRequestComment`.
- **Q:** "Due Today" / "Overdue" cards — clickable to a filtered list?
  💡 Yes — each card deep-links to the Activity List with the matching filter preset.
- **Q:** Assigned-To dropdown — only Mandoob-role users, or any user?
  💡 Only Mandoob-role users; that's the point of creating them.

### API / Data-side
- **Q:** New **Mandoob role** — add to `RoleCodes`/`Role` and a new `ModuleCode` for permissions?
  💡 Yes — add `Mandoob` role and `CAG_MANDOOB` module code so the module can be permission-gated
  like the rest.
- **Q:** Business id for activities (`ACT{yy}{0000}`) — add to `IdGeneratorService`?
  💡 Yes, if a human-readable Activity ID is wanted (the list shows "Activity ID"); add an
  `IdSequence` entity type "ACTIVITY". Otherwise an int id is fine.
- **Q:** Overdue = `Status != Completed/Cancelled AND DueDate < today` — confirm.
  💡 Yes; "Due Today" = same but `DueDate = today`. Compute on read or a small daily job (avoid the
  list-side-effect anti-pattern from [09](09-vacation-management.md)).
- **Q:** Are follow-ups editable/deletable?
  💡 Append-only (audit trail); allow delete only by Admin/Ops.
- **Q:** Attachments on both activity and each follow-up — via `FileService` (FTP)?
  💡 Yes, reuse `FileService`; store paths in `AttachmentPath`.

### Business / Product
- **Q:** Seed the `ActivityType` master with the 11 example types?
  💡 Yes, seed + keep editable (master, per the doc).
- **Q:** "Legal Issue" — activity type only, or also the new company status from
  [02](02-rider-management-status.md)? Do they interlink (setting the status opens an activity)?
  💡 Keep them distinct but allow an activity of type "Legal Issue" to reference the rider whose
  company status is Legal Issue. Confirm whether one should auto-create the other.
- **Q:** Confirm the Follow-up Dashboard is M2 while the rest is M1.
  💡 Yes per the doc; build List/Add/Types/Follow-ups in M1, the dashboard in M2.

## 4. Decisions & implementation (2026-10-06)

Built in one pass: Milestone 1 (Activity Types, Add Activity, Activity List with cards and filters,
follow-ups) **and** the Milestone 2 Follow-up Dashboard. The open questions in §3 were settled with
the suggestions marked 💡 unless noted below — none of them has been confirmed by the client yet.

### 4.1 Decisions

| Question (§3) | What was built |
|---|---|
| Mandoob users | A new **role `Mandoob` (roleId 9)** on the existing `User` table — no second user model. Created like any other user in Admin → Users, with the companies they should see. |
| Who can be assigned | Only **active Mandoob users who have access to the activity's company** (`UserCompany`). The API rejects anyone else, because a Mandoob only sees their own companies. Assignment is optional at creation ("Create Activity → Assign to Mandoob"). |
| Module / permissions | **Its own module (confirmed 2026-10-06: "keep it as a separate module")** — not part of HR, Rider or Admin: new module **`CAG_MANDOOB`** with its own row in Admin → Permissions for every role. Someone with only this module can use all of it; the one link out of it (the rider's name on the activity page) is plain text unless they also have the Rider module. Starting levels: Admin, Operational Manager, HR, Mandoob = Edit; Reporter = View; Supervisor, Team Leader, Coordinator = No Access; Rider = none. Editable in Admin → Permissions. |
| Activity ID | The table's auto-increment id, shown as **`ACT-<id>`** (as in the mock-up). `IdGeneratorService` is not used. |
| Rider field | **Optional**, although the requirement only marks Client as optional: Company Documents, Municipality and similar types have no rider. ⚠️ Deviation — confirm with the client. |
| Detail view | A **page** (`/Mandoob-Activities/{id}`) with the follow-up history, the add-follow-up form and attachments, like the Passport Request ticket page. |
| Follow-ups | Fields from the client's sample: Follow-up Date, Remarks, Next Follow-up, Status, Updated By. **Append-only** — no edit, no delete, no void. Saving one sets the activity's status to the follow-up's status, in one transaction. |
| Deleting an activity | Not possible — set it to **Cancelled**. |
| Overdue / Due Today | Not stored. Overdue = status is not Completed/Cancelled and due date < today; Due Today = same with due date = today. Worked out in the browser (the user's local date). |
| Attachments | The existing **Document pipeline** (`api/document/*`), `source = "MandoobActivity"`, `sourceId = <activity id>`, `documentTypeId = 42`; files under `CAG_Admin/{env}/MandoobActivity/{id}/` on the FTP server. Several files per activity. Follow-ups have no attachments of their own. |
| "Legal Issue" | Only an activity type here. It is **not linked** to the Legal Issue company rider status ([02](02-rider-management-status.md)); neither creates the other. |
| Table names | `MandoobActivity*` rather than the bare `Activity*` suggested in §2 — "Activity" alone is ambiguous in this schema. |

### 4.2 Database — `CAG.Admin.API/Database/Migrations/2026-10-06_MandoobActivities.sql`

- `MandoobActivityType` (`name` unique, `isActive`) — seeded once with the 11 types the client listed.
- `MandoobActivity` — type, company (required), rider / client (optional), `priority`, `subject` (200),
  `description`, `dueDate`, `assignedTo` (userId, nullable), `status`, audit columns. `priority` and
  `status` are stored **by name** and must match the API enums `MandoobActivityPriority`
  (Low, Medium, High, Urgent) and `MandoobActivityStatus` (Open, InProgress, Pending, Completed, Cancelled).
- `MandoobActivityFollowUp` — `followUpDate`, `remarks` (1000), `nextFollowUpDate`, `status`, `createdBy`, `createdAt`.
- `Role` 9 `Mandoob`; `PageModule` `CAG_MANDOOB`; `RolePermission` rows for the new module (every role
  except Rider) and, for the Mandoob role, a No Access row on every other top-level module so the
  Permissions screen can edit them.
- Company / rider / client are foreign keys with RESTRICT: a rider or company that has activities
  cannot be hard-deleted. `createdBy` / `updatedBy` / `assignedTo` are deliberately not foreign keys.
- Re-runnable. **Applied to Dev (`CAG_Admin_Dev`) on 2026-10-06; not yet on QA or PROD.** Run it
  before deploying the API build, and note that users only get the new module at their next sign-in.

### 4.3 API — `api/mandoob-activity` (`MandoobActivityController` → `MandoobActivityService`)

| Method & route | Purpose | Needs |
|---|---|---|
| `GET type/getall?includeInactive=` | Types by name, each with its activity count | View |
| `POST type` · `PUT type/{id}` | Add / rename / activate-deactivate a type (duplicate name → 409) | Edit |
| `GET assignees` | Active Mandoob users with the companies they share with the caller | View |
| `GET getall?companyIds=&mandoobActivityTypeId=&status=&priority=&assignedTo=&fromDate=&toDate=` | Activities, newest first; the date range is on the due date, inclusive | View |
| `GET {id}` | One activity with its follow-ups (oldest first) | View |
| `POST` · `PUT {id}` | Create / update an activity | Edit |
| `POST {id}/followup` | Add a follow-up and move the activity to its status | Edit |

- **Access is enforced in the service**, not only in the UI: the caller's role needs View / Edit on
  `CAG_MANDOOB` (read from `RolePermission`, so a change applies without a new sign-in), and rider
  users are always refused. Every query is limited to the caller's `CompanyIds`; an activity in
  another company answers 404.
- On update, a value that is not being changed (type, rider, client, assignee) is not re-validated,
  so an activity whose type was deactivated or whose Mandoob was moved can still be edited.
- Config: `FilePath:MandoobActivityFiles` in `appsettings.json` (FTP folder name for attachments).
- Attachments go through the generic document endpoints, which — like for every other source — only
  require a signed-in user.

### 4.4 UI — `CAG.Admin.UI`

| Route | What it is |
|---|---|
| `/Mandoob-Activities` | Activity List: six cards (Total, Open, Pending, Completed, Overdue, Due Today) that also act as quick filters, search, Filter (Company, Activity Type, Status, Priority, Assigned To), a due-date range with month presets (the "Month" and "Date Range" filters), CSV export, **Add Activity**. Columns: Activity ID, Company (code), Type, Subject, Due Date, Priority, Status, Assigned To; Rider, Client, Follow-ups, Next follow-up, Created by / at are hidden but available. `?bucket=overdue` (etc.) preselects a card. |
| `/Mandoob-Activities/{id}` | Details, follow-up history table, **Add follow-up**, attachments, **Edit**. |
| `/Mandoob-Activities/Types` | Activity Types master: add, rename, activate / deactivate. A type in use is deactivated, never removed. |
| `/Mandoob-Activities/Dashboard` | Follow-up Dashboard (M2): the six cards, **Follow-ups due** (next follow-up date is today or earlier), **Overdue**, **Upcoming due** (next 14 days) and **Activities by type**, with a company filter. Read-only; built from the same list endpoint. |

Wiring: `ModuleCodes.mandoobActivities`, four `RolePageCode` entries, `RoleCodes.Mandoob = 9` (so the
role appears in Admin → Users), the sidebar group, and a **Mandoob Activities** row in Admin →
Permissions (`ModulePermissionModel.MandoobActivities`). The Activity Types screen shares
`components/master/name-master-page.tsx` with the Expense Categories screen. Code: `components/mandoob/*`,
`(pages)/Mandoob-Activities/**`, `(details)/Mandoob-Activities/[activityId]`,
`hooks/react-query/mandoob-activity.tsx`, `http-client/mandoob-activity.api.ts`.

A user whose only module is Mandoob Activities (the default for the Mandoob role) lands on the
Activity List after signing in.

### 4.5 Verified / not verified

- API: 70 service-level checks against Dev with fake callers per role (access per role and company,
  type master, validation, create / update, list filters, follow-ups moving the status, names and
  Arabic text mapping) — all passed, and the test rows were removed. The API boots with the new
  routes and answers 401 without a token.
- UI: `tsc`, ESLint and `next build` pass. **Not exercised in a browser** (needs a login) — the
  screens, the attachment upload and the permission screen row still need a manual pass.

### 4.6 Still open

- Client confirmation of the defaults in §4.1 — above all the optional Rider and the starting
  permission levels.
- Whether a Mandoob should see only the activities assigned to them (today: every activity of their
  companies, with an Assigned To filter).
- No notifications or reminders for due dates and follow-ups (not in the requirement).

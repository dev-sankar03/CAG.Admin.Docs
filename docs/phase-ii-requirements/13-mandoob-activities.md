# 13 — Mandoob Activities Module (Milestone 1 / Follow-up Dashboard M2)

> Source: `CAG_Phase_II.docx` → *Mandoop Activities (Milestone 1)* ("Mandoob" = government-liaison
> representative)
> Modules touched: **New Activities module**, Users (Mandoob users), Rider, Client, Company.
> **Status: built 2026-10-06 (Milestone 1 and the M2 dashboard) — see [§4](#4-decisions--implementation-2026-10-06). Merged to `develop` and the DB script applied to Dev and QA on 2026-10-06; PROD pending (`CAG.Admin.API/Database/Migrations/RELEASE_RUNBOOK.md`, #20).**
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
- Re-runnable. **Applied to Dev and QA on 2026-10-06; not yet on PROD** — it is #20 in
  `CAG.Admin.API/Database/Migrations/RELEASE_RUNBOOK.md`. Run it before deploying the API build,
  and note that users only get the new module at their next sign-in.

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
| `/Mandoob-Activities/{id}` | Activity page, laid out like the Rider details page: back button, identity card (subject, `ACT-n`, type / company / due / assignee, status and priority, **Add follow-up**, **Edit details**) and three sections on a left rail — **Overview** (the record, description, latest follow-up), **Follow-ups** (history table + the add form) and **Attachments**. `?tab=FollowUps` / `?tab=Attachments` opens on that section. |
| `/Mandoob-Activities/Types` | Activity Types master: add, rename, activate / deactivate. A type in use is deactivated, never removed. |
| `/Mandoob-Activities/Dashboard` | Follow-up Dashboard (M2): the six cards, **Follow-ups due** (next follow-up date is today or earlier; each row opens the activity on its Follow-ups section), **Overdue**, **Upcoming due** (next 14 days) and **Activities by type**, with a company filter. Read-only; built from the same list endpoint. |

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
- UI: `tsc`, ESLint and `next build` pass. The developer build was not exercised in a browser
  (needs a login).
- QA (checked read-only on 2026-10-11): the build is in use — a Mandoob user was created, and five
  activities, ten follow-ups (two activities taken to Completed) and two attachments were entered
  there after the release. The Follow-up Dashboard and the Permissions row were not specifically
  checked.

### 4.6 Still open

- Client confirmation of the defaults in §4.1 — above all the optional Rider and the starting
  permission levels.
- Whether a Mandoob should see only the activities assigned to them (today: every activity of their
  companies, with an Assigned To filter).
- No notifications or reminders for due dates and follow-ups (not in the requirement).

## Changes 2026-10-12 (bug sheet 13–33)

- **New status `Reopened`** (bug sheet #26): added to `MandoobActivityStatus` (API) and the UI status list / pills. It behaves as an open status (can be overdue or due today) and is offered wherever a status is picked — the activity form, a follow-up, the list filter — so a Completed or Cancelled activity can be taken up again on the same entry. Stored by name in `VARCHAR(20)`; no script.

## UI review and local end-to-end test — 2026-10-12

Done on a developer build (`localhost`, Dev database) signed in as a temporary test admin; this
replaces "not exercised in a browser" in §4.5.

**Fixed**

- **Add / Edit Activity Type modal** — the *Active* tick box sat beside the middle of its
  two-line text. `components/checkbox.tsx` now lines the box up with the label's first line when a
  description is given (label-only uses, e.g. Sign-in "Remember me", are unchanged). Same component
  as Company Expenses → Categories.
- **Activity Types list** — *Status* showed AG Grid's greyed-out checkbox (the column was bound to
  the boolean); it is now the word Active / Inactive.
- **Follow-up Dashboard** — the two cards of a row are the same height and an empty card centres
  its message (was: a strip of text at the top of a tall box next to a long list). *Total
  Activities* is no longer drawn as "selected" — only a card that is narrowing the list is
  highlighted. *Activities by type*: the bar is the type's share of all activities, the same
  percentage printed beside it (was: relative to the largest type, so a 25% row had a full bar).
- **Activity list** — the eight visible columns fit a 1280px screen without horizontal scrolling,
  and *Due Date* is wide enough for "7 Oct 2026 · 5 days overdue".
- **Activity form** — *Company* shows its "Select..." placeholder when empty (was a blank box) and
  *Due Date* says "Select date".
- **Activity page** — a follow-up error is shown under the field it is about (date, next date or
  remarks) and disappears as soon as anything is changed; the follow-up card no longer stretches to
  the height of the right-hand column.
- **Date pickers in forms** — pressing Enter to confirm a typed date also submitted the form
  around it. `keepEnterInDatePicker` (`components/form/app-date-picker.tsx`) on the form's
  `onKeyDown` stops that; used by the activity form, the follow-up form and the expense form. Other
  forms in the app still have the old behaviour.

**Exercised by hand** — Admin → Users: a user with the Mandoob role; Add Activity with an
attachment (assignee list follows the company); required-field messages; follow-ups (with and
without a next date, one to Completed) and the status / history they produce; Edit; the six cards
as quick filters; the Follow-up Dashboard panels with an overdue, a due-today and an upcoming
activity; Activity Types add / duplicate name / deactivate. The Mandoob and Company Expenses rows
of the permission matrix were read from `permissions/getall`; the Admin → Permissions screen
itself was not opened.

**Left on Dev** — activities ACT-1…ACT-4 (subjects start "E2E test"), their follow-ups, one
attachment, and the user *E2E Test Mandoob* (deactivated after the test).

## Activity page matched to the Rider details page — 2026-10-13

Requested on 2026-10-13 ("needs to match rider more details"). The activity page was
modelled on the Help-Desk ticket page (bare title, two columns); it now uses the Rider / Vehicle
details pages' own parts, so the three look and behave alike:

- `components/details/back-button.tsx` ("Back to Mandoob activities").
- `components/mandoob/activity-header.tsx` — the identity card (same card shell as
  `rider-header.tsx`, no photo tile because an activity has no picture) plus a loading skeleton of
  the same shape.
- `TabBar` (vertical rail on desktop, one row on phones) + `TabPanel` with **Overview**,
  **Follow-ups** (count badge) and **Attachments** (count badge).
- `SideCard`, `Field`, `KeyValueRow` from `components/details/vehicle/**` for every card.

Behaviour that changed with it:

- Follow-ups are one click away (the **Follow-ups** section) instead of on the landing view. To keep
  the main job quick, the header's **Add follow-up** opens that section with the cursor in
  *Remarks*, and the dashboard's *Follow-ups due* rows link to `?tab=FollowUps`.
- What is typed in the follow-up form survives moving between sections.
- *Record* shows *Last updated* only when the activity was changed after it was created (the API
  stamps both at creation).
- The page uses the details layout's full width (it was capped at 1180px).

No API or data change. Checked on a developer build at 1366px and at phone width (sections, header
button, `?tab=`, no sideways page scroll). Not re-checked: adding a follow-up and uploading a file
from the new layout — the handlers are unchanged from the version tested on 2026-10-12.

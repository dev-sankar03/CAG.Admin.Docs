# 13 — Mandoob Activities Module (Milestone 1 / Follow-up Dashboard M2)

> Source: `CAG_Phase_II.docx` → *Mandoop Activities (Milestone 1)* ("Mandoob" = government-liaison
> representative)
> Modules touched: **New Activities module**, Users (Mandoob users), Rider, Client, Company.
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

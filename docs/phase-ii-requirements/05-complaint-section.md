# 05 — Complaint Section (Milestone 1)

> **Status: implemented 2026-10-01** (tracker row CS-01) — see [§4 Decisions & implementation](#4-decisions--implementation-2026-10-01). Sections 1–3 are the original analysis, kept for the reasoning.

> Source: `CAG_Phase_II.docx` → *Complaint Section (Milestone 1)*
> Modules touched: Rider detail, (possibly) Helpdesk, a new comments/notes store.
> Related docs: [helpdesk](../implementation-impact-analysis.md),
> [leave-request comments](../implementation-impact-analysis.md) (an existing comment pattern),
> [cross-cutting audit](../authentication-authorization.md).

## 1. Requirement (as specified)

- **All departments** should be able to **add comments on the rider**.

(One line in the source — deliberately open. The questions below exist to turn it into a spec.)

## 2. Impact & Changes

### UI (`CAG.Admin.UI`)
- A **Comments/Complaints panel** on the rider detail page (a section in the
  [08](08-rider-more-details.md) scrolling layout, or a dedicated tab): a timeline of comments with
  author, department, timestamp, and an "Add comment" box.

### API / DB (`CAG.Admin.API`)
- **New table** `RiderComment` (or `RiderComplaint`): `Id`, `RiderId`, `Comment`, `Department`/`Category`,
  `CreatedBy`, `CreatedAt` (+ `UpdatedBy/At` if edits allowed). Follows the platform audit convention
  ([data-model](../database-access-layer.md)).
- **New endpoints** `api/rider/{riderId}/comments` (GET list, POST add) — or a standalone
  `api/rider-comment` controller/service/repository trio, matching the existing pattern.
- **Reuse candidate:** `LeaveRequestComment` already implements a rider-adjacent comment thread
  (`LeaveRequestCommentService`/`Repository`, `api/leaverequest/comment/*`) — mirror its shape rather
  than inventing a new one.

### Cross-cutting
- "All departments" = every authenticated role can **add**; consider whether all can **view** and
  whether any can **delete** (ties to the role-gating work in [14 #7](14-misc-changes.md)).
- Company scoping still applies — a user should only comment on riders within their `CompanyIds`.

## 3. Open Questions & Suggestions

### UI-side
- **Q:** Where does the panel live — a tab, or a section in the new scrolling rider layout
  ([08](08-rider-more-details.md))?
  💡 A section in the scrolling layout titled "Complaints / Comments", pinned near the top so it's
  visible without hunting.
- **Q:** Threaded replies, or a flat comment list?
  💡 Flat, newest-first, is enough for "add comments on the rider". `LeaveRequestComment` is flat —
  reuse that UX.
- **Q:** Should each comment show the author's **department**, and is department derived from role or
  chosen at post time?
  💡 Derive department from the author's role automatically; don't ask the user to pick it.
- **Q:** Attachments on a complaint (photo of an issue)?
  💡 Optional single attachment via `FileService`; confirm need before building.

### API / Data-side
- **Q:** New dedicated table/endpoints, or extend an existing comment mechanism?
  💡 New `RiderComment` table + `api/rider/{riderId}/comments`, **cloned from** the
  `LeaveRequestComment` implementation for consistency and speed.
- **Q:** Are comments editable/deletable, and by whom?
  💡 Immutable by default (append-only audit trail of complaints); allow delete only by Admin/Ops.
  This keeps it defensible as a record.
- **Q:** Is "complaint" a distinct type from a general "comment" (severity, status, resolution)?
  💡 Confirm — if complaints need a lifecycle (Open/Resolved), this becomes closer to a lightweight
  Helpdesk ticket scoped to a rider. Start with plain comments; add status only if required.

### Business / Product
- **Q:** Who can **view** rider complaints — all departments, or only HR/Ops?
  💡 All authenticated users within company scope can view; only Admin/Ops can delete. Confirm any
  confidentiality constraint.
- **Q:** Does a complaint need to notify anyone (HR, supervisor)?
  💡 Out of scope unless stated; note as a possible follow-up (no notification infra exists today).

## 4. Decisions & implementation (2026-10-01)

**The ask:** "create a complaint section under the rider more details page … and I need to maintain the history as well."

**Decisions** — the owner's answers to the questions above:

| Question | Decision |
|---|---|
| What is a complaint? | A **plain comment**: the text, the date and time, who wrote it and in which role. No status, category, severity or attachment. |
| What does "history" cover? | **The list itself.** Every complaint stays listed, newest first; nothing is edited or deleted. No per-change audit log (there is nothing to change). |
| Who can view / add / change? | **Anyone who can open the rider page** (module `CAG_RIDER`, at least View) can view and add. Only **Admin, Operational Manager and HR** can *void* a mistaken entry. Riders never see complaints — enforced on the API, not only hidden in the UI. |
| Where on the page? | A new **Complaints** tab on the More details page (`/Rider/{riderId}/details`) with a count badge. The page is still tabbed — the "remove tabs / scrolling layout" item ([08](08-rider-more-details.md)) hasn't been done — so this tab moves into the scrolling layout when that happens. |
| What is the "department"? | The author's **role at the moment of writing**, stored on the row (there is no department column anywhere). |

**Assumed, not asked** (say if any is wrong): no notifications, no attachments, no effect on rider status or payroll, nothing to import, text 1–2,000 characters, a void needs a reason (≤ 500 characters).

**What was built**

- **DB** — `RiderComplaint` ([`2026-10-01_RiderComplaint.sql`](../../../CAG.Admin.API/Database/Migrations/2026-10-01_RiderComplaint.sql), utf8mb4, FK to `Rider`). Applied to Dev 2026-10-01; QA and PROD still need the script, run **before** the API build.
- **API** — `RiderComplaintController` (`GET`/`POST api/rider/{riderId}/complaints`, `PUT …/{id}/void`) → `RiderComplaintService` → `RiderComplaintRepository`. Access rules are enforced in the service: Rider role and rider-linked users refused (403), `CAG_RIDER` ≥ View required, rider must be in the caller's companies (404 otherwise), void limited to Admin / Operational Manager / HR. Details in [rider-management.md](../rider-management.md) §2.3 and §3.11.
- **UI** — `components/details/rider/complaints-tab.tsx`: an add box, then newest-first rows (name · role · date and time, then the text). A voided entry stays visible, struck through, with who voided it, when and why. Reuses `SideCard`; colour is not used for anything.

**Where it differs from the suggestions in §2–§3**

- Named `RiderComplaint`, not `RiderComment`.
- It does **not** clone `LeaveRequestComment` wholesale: that module's delete endpoint has no owner or role check (any logged-in user can delete any comment by id) and its table is latin1. Here there is no delete at all — a wrong entry is voided.
- "All authenticated users can view" was tightened: riders are excluded and the module permission is required.
- No edit, status or category (the "start with plain comments" option in §3 was taken).

**Verification** — against the Dev database with a throw-away harness (not committed): 22 checks on the real service for role / permission / company access, validation and void rules, plus a rolled-back SQL test (insert, list, void, double-void guard, Arabic round trip). The API starts with dependency injection validated and the three routes answer 401 without a token. The UI was type-checked and linted; it has **not** been exercised in a browser (that needs a login).
